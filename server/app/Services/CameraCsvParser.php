<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\CameraType;
use InvalidArgumentException;

final class CameraCsvParser
{
    public const MAX_BYTES = 5 * 1024 * 1024;
    public const MAX_ROWS = 2000;

    private const REQUIRED = ['external_id', 'municipality_code', 'lat', 'lon', 'type'];
    private const OPTIONAL = ['name', 'direction', 'bearing', 'corridor', 'speed_limit', 'notes'];

    /**
     * Pure, read-only parser. Never accept lifecycle fields from a file.
     *
     * @return array{header:list<string>,rows:list<array{record:int,values:array<string,mixed>,errors:list<string>}>,valid_count:int,invalid_count:int}
     */
    public function parse(string $path): array
    {
        $size = is_file($path) && is_readable($path) ? filesize($path) : false;
        if ($size === false || $size > self::MAX_BYTES) {
            throw new InvalidArgumentException('CSV is unreadable or exceeds 5 MiB.');
        }
        $bytes = file_get_contents($path);
        if ($bytes === false) {
            throw new InvalidArgumentException('CSV is unreadable.');
        }

        return $this->parseBytes($bytes);
    }

    /**
     * Parse exactly the bytes that will be stored and hashed for this batch.
     * Never re-read an uploaded path between analysis and persistence.
     *
     * @return array{header:list<string>,rows:list<array{record:int,values:array<string,mixed>,errors:list<string>}>,valid_count:int,invalid_count:int}
     */
    public function parseBytes(string $bytes): array
    {
        if (strlen($bytes) > self::MAX_BYTES) {
            throw new InvalidArgumentException('CSV exceeds 5 MiB.');
        }
        if (! mb_check_encoding($bytes, 'UTF-8')) {
            throw new InvalidArgumentException('CSV must be valid UTF-8.');
        }
        if (preg_match('/[\x00-\x08\x0B\x0C\x0E-\x1F]/', $bytes)) {
            throw new InvalidArgumentException('CSV has prohibited control characters.');
        }

        $csv = str_starts_with($bytes, "\xEF\xBB\xBF") ? substr($bytes, 3) : $bytes;
        $this->assertRfc4180($csv);
        $stream = fopen('php://temp', 'w+');
        if ($stream === false) {
            throw new InvalidArgumentException('CSV temporary stream failed.');
        }

        try {
            fwrite($stream, $csv);
            rewind($stream);
            $header = fgetcsv($stream, null, ',', '"', '');
            if ($header === false || $header === [null]) {
                throw new InvalidArgumentException('CSV header missing.');
            }
            $header = array_map(static fn ($s): string => (string) $s, $header);
            if (count($header) !== count(array_unique($header))
                || array_diff(self::REQUIRED, $header) !== []
                || array_diff($header, array_merge(self::REQUIRED, self::OPTIONAL)) !== []) {
                throw new InvalidArgumentException('CSV header has missing, unknown, or repeated columns.');
            }
            $rows = [];
            $valid = 0;
            $invalid = 0;
            $number = 1;

            while (($cells = fgetcsv($stream, null, ',', '"', '')) !== false) {
                if ($cells === [null]) {
                    continue;
                }
                $number++;
                if ($number - 1 > self::MAX_ROWS) {
                    throw new InvalidArgumentException('CSV exceeds 2000 rows.');
                }
                if (count($cells) !== count($header)) {
                    $values = [];
                    $errors = ['CSV row has the wrong column count.'];
                } else {
                    [$values, $errors] = $this->normalize(array_combine($header, $cells));
                }
                $valid += $errors === [] ? 1 : 0;
                $invalid += $errors !== [] ? 1 : 0;
                $rows[] = ['record' => $number, 'values' => $values, 'errors' => $errors];
            }

            return ['header' => $header, 'rows' => $rows, 'valid_count' => $valid, 'invalid_count' => $invalid];
        } finally {
            fclose($stream);
        }
    }

    public static function spreadsheetSafe(string $value): string
    {
        return preg_match('/^[\s\x{FEFF}\x{200B}]*[=+\-@]/u', $value) ? "'".$value : $value;
    }

    /** @return array{array<string,mixed>,list<string>} */
    private function normalize(array $raw): array
    {
        $values = [];
        $errors = [];
        foreach (['external_id', 'municipality_code', 'type'] as $field) {
            $rawValue = (string) ($raw[$field] ?? '');
            $s = trim($rawValue);
            if ($field === 'external_id' && ($s === '' || mb_strlen($s) > 255
                || $s !== $rawValue || preg_match('/[\p{Cc}\p{Cf}]/u', $rawValue))) {
                $errors[] = 'external_id length is invalid.';
            } elseif ($field === 'municipality_code' && ! preg_match('/^\d{5}$/D', $s)) {
                $errors[] = 'municipality_code must be 5 digits.';
            } elseif ($field === 'type' && ! in_array($s, array_column(CameraType::cases(), 'value'), true)) {
                $errors[] = 'type is unsupported.';
            } else {
                $values[$field] = $s;
            }
        }
        foreach (['lat' => [-90, 90], 'lon' => [-180, 180]] as $field => [$low, $high]) {
            $s = trim((string) ($raw[$field] ?? ''));
            if (! preg_match('/^[+-]?(?:\d+(?:\.\d+)?|\.\d+)$/D', $s)
                || ! is_finite((float) $s) || (float) $s < $low || (float) $s > $high) {
                $errors[] = "{$field} must be a finite WGS84 decimal.";
            } else {
                $values[$field] = number_format((float) $s, 7, '.', '');
            }
        }
        foreach (['name' => 255, 'direction' => 255, 'corridor' => 255, 'notes' => 4000] as $field => $max) {
            $s = trim((string) ($raw[$field] ?? ''));
            if ($s !== '') {
                if (mb_strlen($s) > $max) {
                    $errors[] = "{$field} exceeds {$max} characters.";
                } else {
                    $values[$field] = $s;
                }
            }
        }
        foreach (['bearing' => [0, 359], 'speed_limit' => [1, 200]] as $field => [$low, $high]) {
            $s = trim((string) ($raw[$field] ?? ''));
            if ($s !== '') {
                if (! preg_match('/^\d+$/D', $s) || (float) $s < $low || (float) $s > $high) {
                    $errors[] = "{$field} is not an allowed integer.";
                } else {
                    $values[$field] = (int) $s;
                }
            }
        }

        return [$values, $errors];
    }

    /**
     * fgetcsv silently accepts some malformed quoting. Validate structure first.
     */
    private function assertRfc4180(string $csv): void
    {
        $quoted = false;
        $atStart = true;
        $closedQuote = false;
        $len = strlen($csv);
        for ($i = 0; $i < $len; $i++) {
            $ch = $csv[$i];
            $next = $csv[$i + 1] ?? '';
            if ($quoted) {
                if ($ch === '"') {
                    if ($next === '"') {
                        $i++;
                    } else {
                        $quoted = false;
                        $closedQuote = true;
                    }
                }
                continue;
            }
            if ($ch === ',' || $ch === "\n" || ($ch === "\r" && $next === "\n")) {
                if ($ch === "\r") {
                    $i++;
                }
                $atStart = true;
                $closedQuote = false;
                continue;
            }
            if ($closedQuote || $ch === "\r") {
                throw new InvalidArgumentException('Malformed CSV quote or newline.');
            }
            if ($ch === '"') {
                if (! $atStart) {
                    throw new InvalidArgumentException('Quote inside unquoted CSV cell.');
                }
                $quoted = true;
            }
            $atStart = false;
        }
        if ($quoted) {
            throw new InvalidArgumentException('CSV cell has unclosed quote.');
        }
    }
}
