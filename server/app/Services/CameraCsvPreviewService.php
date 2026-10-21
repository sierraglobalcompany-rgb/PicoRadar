<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\CameraStatus;
use App\Enums\GeographicUnitLevel;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\Jurisdiction;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

final class CameraCsvPreviewService
{
    private const MUTABLE = ['name', 'lat', 'lon', 'direction', 'bearing', 'corridor', 'speed_limit', 'notes'];

    public function __construct(private readonly CameraDuplicateDetector $duplicates) {}

    /**
     * Read-only assessment. Classification is not authority to mutate:
     * re-run all conditions with DB locks at apply time.
     *
     * @param array{rows:list<array{record:int,values:array<string,mixed>,errors:list<string>}>} $parsed
     * @return array{rows:list<array<string,mixed>>,counts:array<string,int>,missing_advisory:int}
     */
    public function preview(array $parsed, CameraSource $source, Jurisdiction $jurisdiction, string $mode): array
    {
        if (! in_array($mode, ['snapshot', 'delta'], true)) {
            throw new InvalidArgumentException('Import mode must be snapshot or delta.');
        }
        $coverage = $jurisdiction->geographicUnits()
            ->where('level', GeographicUnitLevel::Municipality->value)
            ->where('is_active', true)
            ->get()
            ->keyBy('code');

        $identities = [];
        $foldedIdentities = [];
        foreach ($parsed['rows'] as $row) {
            if ($row['errors'] === [] && isset($row['values']['external_id'])) {
                $key = $row['values']['external_id'];
                $identities[$key] = ($identities[$key] ?? 0) + 1;
                // MariaDB's default utf8mb4_unicode_ci UNIQUE index is case-insensitive.
                // Conservative case-folding prevents false "create_ready" rows on imports.
                $fold = mb_strtolower($key, 'UTF-8');
                $foldedIdentities[$fold] = ($foldedIdentities[$fold] ?? 0) + 1;
            }
        }

        $existing = collect();
        $usesCaseInsensitiveIndex = in_array(DB::getDriverName(), ['mysql', 'mariadb'], true);
        foreach (array_chunk(array_keys($identities), 400) as $keys) {
            // PHP converts canonical numeric array keys to integers. Always
            // bind camera identities as text: MariaDB could otherwise apply
            // numeric comparison to a VARCHAR external_id column.
            $chunk = array_map(static fn (int|string $key): string => (string) $key, $keys);
            $query = Camera::query()->where('source_id', $source->id);
            if ($usesCaseInsensitiveIndex) {
                // The existing source_id/external_id UNIQUE index is case-insensitive
                // under the configured MariaDB/MySQL utf8mb4_unicode_ci collation.
                $query->whereIn('external_id', $chunk);
            } else {
                // SQLite is case-sensitive by default. Its LOWER() supports
                // ASCII identifiers; unusual Unicode collisions still fail
                // closed at database UNIQUE/identity gates on MariaDB.
                $folded = array_map(static fn (string $id): string => mb_strtolower($id, 'UTF-8'), $chunk);
                $placeholders = implode(',', array_fill(0, count($folded), '?'));
                $query->whereRaw('LOWER(external_id) IN ('.$placeholders.')', $folded);
            }
            $existing = $existing->merge($query->get());
        }
        $byExternalId = $existing->keyBy('external_id');
        $byFoldedId = $existing->keyBy(static fn (Camera $camera): string => mb_strtolower($camera->external_id, 'UTF-8'));
        $available = $source->is_active && $source->verified_at !== null && $jurisdiction->enabled;

        $result = [];
        $counts = ['create_ready' => 0, 'update_ready' => 0, 'noop' => 0, 'invalid' => 0, 'blocked' => 0, 'duplicate' => 0];
        foreach ($parsed['rows'] as $row) {
            $values = $row['values'];
            $errors = $row['errors'];
            $status = 'invalid';
            $camera = null;
            $fingerprint = null;
            if ($errors === []) {
                $key = $values['external_id'];
                $unit = $coverage->get($values['municipality_code']);
                $camera = $byExternalId->get($key);
                $fold = mb_strtolower($key, 'UTF-8');
                $caseInsensitiveMatch = $byFoldedId->get($fold);
                if (($foldedIdentities[$fold] ?? 0) > 1) {
                    $status = 'duplicate';
                    $errors[] = 'external_id conflicts with another row ignoring letter case.';
                } elseif ($caseInsensitiveMatch !== null && $caseInsensitiveMatch->external_id !== $key) {
                    $status = 'blocked';
                    $errors[] = 'external_id conflicts with an existing source identity ignoring letter case.';
                } elseif (! $available) {
                    $status = 'blocked';
                    $errors[] = 'Source must be active and verified; jurisdiction must be enabled.';
                } elseif ($unit === null) {
                    $status = 'blocked';
                    $errors[] = 'Municipality is outside active jurisdiction coverage.';
                } elseif ($camera !== null && ($camera->jurisdiction_id !== $jurisdiction->id || $camera->geographic_unit_id !== $unit->id)) {
                    $status = 'blocked';
                    $errors[] = 'Existing external_id cannot move between jurisdictions or municipalities.';
                } elseif ($camera !== null && ! in_array($camera->status, [CameraStatus::Draft, CameraStatus::Rejected], true)) {
                    $status = 'blocked';
                    $errors[] = 'Only draft or rejected cameras can be updated by CSV.';
                } elseif ($camera !== null && $camera->type->value !== $values['type']) {
                    $status = 'blocked';
                    $errors[] = 'Camera type changes require manual review.';
                } else {
                    $fingerprint = $camera ? self::fingerprint($camera) : null;
                    $probe = new Camera;
                    $probe->forceFill([
                        'id' => -1, 'source_id' => $source->id,
                        'jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $unit->id,
                        'lat' => $values['lat'], 'lon' => $values['lon'], 'type' => $values['type'],
                    ]);
                    $scan = $this->duplicates->scan($probe, 25, 25);
                    $otherCandidates = array_filter($scan['candidates'], static fn (array $item): bool => $camera === null || $item['camera']->id !== $camera->id);
                    if ($scan['scanCapped'] || $otherCandidates !== []) {
                        $status = 'blocked';
                        $errors[] = $scan['scanCapped']
                            ? 'Duplicate scan capped; manual review required.'
                            : 'Another nearby camera requires manual review.';
                    } elseif ($camera !== null && self::distanceMeters((float) $values['lat'], (float) $values['lon'], (float) $camera->lat, (float) $camera->lon) > 25) {
                        $status = 'blocked';
                        $errors[] = 'Existing camera moved more than 25 metres.';
                    } elseif ($camera === null) {
                        $status = 'create_ready';
                    } else {
                        $status = self::hasChanges($camera, $values) ? 'update_ready' : 'noop';
                    }
                }
            }
            $counts[$status]++;
            $result[] = [
                'record' => $row['record'], 'status' => $status,
                'values' => $values, 'errors' => $errors,
                'camera_id' => $camera?->id, 'expected_fingerprint' => $fingerprint,
                'previous_values' => $camera ? array_intersect_key(
                    $camera->getAttributes(),
                    array_flip(['external_id', 'name', 'lat', 'lon', 'type', 'direction', 'bearing', 'corridor', 'speed_limit', 'notes'])
                ) : null,
            ];
        }

        // Compare file entries with each other. A bounded O(n^2) check of at
        // most 2000 rows prevents a second near-identical CSV row becoming safe.
        $len = count($result);
        $collisions = [];
        for ($i = 0; $i < $len; $i++) {
            $left = $result[$i];
            if (! in_array($left['status'], ['create_ready', 'update_ready', 'noop'], true)) {
                continue;
            }
            for ($j = $i + 1; $j < $len; $j++) {
                $right = $result[$j];
                // One jurisdiction may cover multiple municipalities: a pair
                // across their boundary is still a possible duplicate.
                if (! in_array($right['status'], ['create_ready', 'update_ready', 'noop'], true)) {
                    continue;
                }
                if (self::distanceMeters((float) $left['values']['lat'], (float) $left['values']['lon'], (float) $right['values']['lat'], (float) $right['values']['lon']) <= 25) {
                    $collisions[$i] = true;
                    $collisions[$j] = true;
                }
            }
        }
        foreach (array_keys($collisions) as $index) {
            $counts[$result[$index]['status']]--;
            $result[$index]['status'] = 'blocked';
            $result[$index]['errors'][] = 'Nearby CSV rows conflict; manual review required.';
            $counts['blocked']++;
        }

        $missing = 0;
        if ($mode === 'snapshot' && $available) {
            // Avoid up to 2000 bound placeholders in a WHERE NOT IN query:
            // older SQLite engines cap host variables below the file limit.
            // Compare bounded input keys against a lazy, ID-paginated scan.
            $inFile = array_fill_keys(array_keys($foldedIdentities), true);
            Camera::query()
                ->select(['id', 'external_id'])
                ->where('source_id', $source->id)
                ->where('jurisdiction_id', $jurisdiction->id)
                ->whereNotNull('external_id')
                ->lazyById(500)
                ->each(static function (Camera $existing) use ($inFile, &$missing): void {
                    if (! isset($inFile[mb_strtolower((string) $existing->external_id, 'UTF-8')])) {
                        $missing++;
                    }
                });
        }

        return ['rows' => $result, 'counts' => $counts, 'missing_advisory' => $missing];
    }

    public static function fingerprint(Camera $camera): string
    {
        return hash('sha256', json_encode([
            $camera->id, $camera->source_id, $camera->jurisdiction_id,
            $camera->geographic_unit_id, $camera->status->value, $camera->type->value,
            ...array_map(static fn (string $field): mixed => $camera->{$field}, self::MUTABLE),
            $camera->updated_at?->toISOString(),
        ], JSON_THROW_ON_ERROR));
    }

    private static function hasChanges(Camera $camera, array $values): bool
    {
        foreach (self::MUTABLE as $field) {
            if (array_key_exists($field, $values)) {
                if (in_array($field, ['lat', 'lon'], true)) {
                    if (number_format((float) $camera->{$field}, 7, '.', '') !== $values[$field]) {
                        return true;
                    }
                } elseif ((string) ($camera->{$field} ?? '') !== (string) $values[$field]) {
                    return true;
                }
            }
        }

        return false;
    }

    private static function distanceMeters(float $latA, float $lonA, float $latB, float $lonB): float
    {
        $a = sin(deg2rad(($latB - $latA) / 2)) ** 2
            + cos(deg2rad($latA)) * cos(deg2rad($latB)) * sin(deg2rad(($lonB - $lonA) / 2)) ** 2;

        return 2 * 6_371_000 * asin(min(1, sqrt($a)));
    }
}
