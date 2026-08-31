<?php

namespace App\Services;

use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Str;

class AnsvCameraRowNormalizer
{
    public const KNOWN_STATUSES = [
        'Autorizada instalar',
        'Operando',
        'Renovada - Expirada',
        'Vencida',
        'Prorrogada - Vencida',
        'Autorizada – Desistida',
        'Autorizada - Desistida',
    ];

    public const REQUIRED_COLUMNS = [
        'Código solicitud',
        'Código unico',
        'Estado operación',
        'Departamento',
        'Municipio',
        'Fecha aprobación',
        'Dirección',
        'Latitud',
        'Longitud',
        'Autoridad de tránsito',
        'Jurisdicción',
        'Infracciones',
        'Velocidad',
        'Tipo de tecnología',
        'Tipo de instalación',
        'Nombre equipo',
        'Fecha finalización de prórroga',
        'Fecha inicio de operación',
        'Fecha finalización inicial',
    ];

    /** @param array<string, string|null> $row */
    public function normalize(array $row, CarbonImmutable $today): array
    {
        $status = $this->text($row['Estado operación'] ?? null);
        $lat = $this->decimal($row['Latitud'] ?? null);
        $lon = $this->decimal($row['Longitud'] ?? null);
        $speed = $this->speed($row['Velocidad'] ?? null);
        $codes = $this->codes($row['Infracciones'] ?? null);
        $operationStarted = $this->date($row['Fecha inicio de operación'] ?? null);
        $initialEnds = $this->date($row['Fecha finalización inicial'] ?? null);
        $extensionEnds = $this->date($row['Fecha finalización de prórroga'] ?? null);
        $reasons = [];

        if ($status === '' || ! in_array($status, self::KNOWN_STATUSES, true)) {
            $reasons[] = 'UNKNOWN_OPERATION_STATUS';
        }
        if (! $this->validColombiaCoordinates($lat, $lon)) {
            $reasons[] = 'INVALID_COLOMBIA_COORDINATES';
        }
        if ($this->text($row['Dirección'] ?? null) === '' || $this->text($row['Nombre equipo'] ?? null) === '' || $this->text($row['Código solicitud'] ?? null) === '') {
            $reasons[] = 'MISSING_REQUIRED_IDENTITY';
        }
        if ($operationStarted !== null && $operationStarted->isAfter($today)) {
            $reasons[] = 'OPERATION_START_IN_FUTURE';
        }
        $effectiveEnd = $extensionEnds ?? $initialEnds;
        if ($effectiveEnd !== null && $effectiveEnd->isBefore($today)) {
            $reasons[] = 'OPERATION_WINDOW_EXPIRED';
        }

        $activeCandidate = $status === 'Operando'
            && $this->validColombiaCoordinates($lat, $lon)
            && $operationStarted !== null
            && ! $operationStarted->isAfter($today)
            && ($effectiveEnd === null || ! $effectiveEnd->isBefore($today))
            && ! in_array('MISSING_REQUIRED_IDENTITY', $reasons, true);

        $identity = $this->identity($row);

        return [
            'source_row_identity' => $identity,
            'codigo_solicitud' => $this->text($row['Código solicitud'] ?? null) ?: null,
            'codigo_unico' => $this->text($row['Código unico'] ?? null) ?: null,
            'operation_status' => $status,
            'department' => $this->text($row['Departamento'] ?? null),
            'municipality' => $this->text($row['Municipio'] ?? null),
            'address' => $this->text($row['Dirección'] ?? null),
            'lat' => $lat,
            'lon' => $lon,
            'traffic_authority' => $this->text($row['Autoridad de tránsito'] ?? null) ?: null,
            'jurisdiction_label' => $this->text($row['Jurisdicción'] ?? null) ?: null,
            'raw_infraction_codes' => $codes,
            'raw_speed' => $this->text($row['Velocidad'] ?? null) ?: null,
            'reported_speed_kmh' => $speed,
            'technology' => $this->text($row['Tipo de tecnología'] ?? null) ?: null,
            'installation_type' => $this->text($row['Tipo de instalación'] ?? null) ?: null,
            'equipment_name' => $this->text($row['Nombre equipo'] ?? null) ?: null,
            'approval_date' => $this->date($row['Fecha aprobación'] ?? null)?->toDateString(),
            'operation_started_on' => $operationStarted?->toDateString(),
            'operation_initial_ends_on' => $initialEnds?->toDateString(),
            'operation_extension_ends_on' => $extensionEnds?->toDateString(),
            'valid_colombia_coordinates' => $this->validColombiaCoordinates($lat, $lon),
            'active_public_candidate' => $activeCandidate,
            'review_state' => $reasons === [] ? 'OK' : 'REVIEW_REQUIRED',
            'review_reasons' => $reasons,
            'raw' => $row,
        ];
    }

    /** @param list<string> $headers */
    public function assertHeaders(array $headers): void
    {
        $available = array_flip($headers);
        $missing = array_values(array_filter(self::REQUIRED_COLUMNS, fn (string $column): bool => ! isset($available[$column])));
        if (in_array('Código unico', $missing, true) && isset($available['Código único'])) {
            $missing = array_values(array_diff($missing, ['Código unico']));
        }
        if ($missing !== []) {
            throw new DomainException('ANSV camera source is missing critical columns: '.implode(', ', $missing));
        }
    }

    public function speed(?string $value): ?int
    {
        $raw = $this->text($value);
        if (preg_match('/^(\d{1,3})\s*km\/h$/iu', $raw, $matches) !== 1) {
            return null;
        }
        $speed = (int) $matches[1];

        return $speed >= 1 && $speed <= 200 ? $speed : null;
    }

    /** @param array<string, string|null> $row */
    public function identity(array $row): string
    {
        $parts = [
            $this->text($row['Código único'] ?? $row['Código unico'] ?? null),
            $this->text($row['Código solicitud'] ?? null),
            $this->text($row['Nombre equipo'] ?? null),
            $this->text($row['Dirección'] ?? null),
            $this->text($row['Latitud'] ?? null),
            $this->text($row['Longitud'] ?? null),
            $this->text($row['_source_row_number'] ?? null),
        ];

        return hash('sha256', Str::lower(implode('|', $parts)));
    }

    public function validColombiaCoordinates(?float $lat, ?float $lon): bool
    {
        return $lat !== null && $lon !== null && $lat >= -4.5 && $lat <= 13.6 && $lon >= -82.5 && $lon <= -66.0;
    }

    private function text(?string $value): string
    {
        return trim(preg_replace('/\s+/u', ' ', (string) $value) ?? '');
    }

    private function decimal(?string $value): ?float
    {
        $text = str_replace(',', '.', $this->text($value));
        if ($text === '' || ! is_numeric($text)) {
            return null;
        }

        return (float) $text;
    }

    /** @return list<string> */
    private function codes(?string $value): array
    {
        $text = $this->text($value);
        if ($text === '') {
            return [];
        }

        return array_values(array_filter(array_map(
            fn (string $part): string => trim($part),
            preg_split('/[,;-]+/', $text) ?: [],
        )));
    }

    private function date(?string $value): ?CarbonImmutable
    {
        $text = $this->text($value);
        if ($text === '') {
            return null;
        }
        if (is_numeric($text)) {
            return CarbonImmutable::create(1899, 12, 30)->addDays((int) $text);
        }

        try {
            return CarbonImmutable::parse($text);
        } catch (\Throwable) {
            return null;
        }
    }
}
