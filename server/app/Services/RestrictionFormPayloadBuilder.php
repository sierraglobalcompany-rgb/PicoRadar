<?php

namespace App\Services;

use App\Models\Jurisdiction;
use Carbon\CarbonImmutable;
use DomainException;
use Throwable;

final class RestrictionFormPayloadBuilder
{
    /** @param array<string, mixed> $input @return array<string, mixed> */
    public function build(Jurisdiction $jurisdiction, array $input): array
    {
        $coverages = $input['coverages'] ?? null;
        if (! is_array($coverages) || $coverages === [] || count($coverages) > 8) {
            throw new DomainException('Agrega entre 1 y 8 coberturas de vehículo.');
        }

        $result = [];
        $seen = [];
        foreach (array_values($coverages) as $coverageIndex => $coverage) {
            if (! is_array($coverage)) {
                throw new DomainException('La cobertura no tiene un formato válido.');
            }
            $vehicleKind = $this->oneOf($coverage, 'vehicle_kind', ['car', 'motorcycle'], 'Tipo de vehículo');
            $serviceType = $this->oneOf($coverage, 'service_type', ['private', 'taxi'], 'Servicio');
            $coverageKey = "$vehicleKind:$serviceType";
            if (isset($seen[$coverageKey])) {
                throw new DomainException('No repitas la misma combinación de vehículo y servicio.');
            }
            $seen[$coverageKey] = true;
            $rules = $coverage['rules'] ?? [];
            if (! is_array($rules) || count($rules) > 1000) {
                throw new DomainException('Las reglas de la cobertura no tienen un formato válido.');
            }
            if ($rules === [] && ! $this->truthy($coverage['confirmed_no_rules'] ?? false)) {
                throw new DomainException('Una cobertura sin reglas exige confirmar explícitamente que la fuente no publica restricción.');
            }

            $result[] = [
                'vehicleKind' => $vehicleKind,
                'serviceType' => $serviceType,
                'verifiedAt' => $this->date($coverage, 'verified_at', 'Fecha de revisión'),
                'staleAfter' => $this->date($coverage, 'stale_after', 'Fecha de nueva revisión'),
                'sourceUrls' => $this->urls($coverage['source_urls'] ?? null),
                'rules' => array_map(
                    fn (mixed $rule, int $ruleIndex): array => $this->rule($rule, $coverageIndex, $ruleIndex),
                    array_values($rules),
                    array_keys(array_values($rules)),
                ),
            ];
        }

        return [
            'id' => $jurisdiction->key,
            'name' => $jurisdiction->name,
            'coverages' => $result,
        ];
    }

    /** @return array<string, mixed> */
    private function rule(mixed $value, int $coverageIndex, int $ruleIndex): array
    {
        if (! is_array($value)) {
            throw new DomainException('Una regla no tiene un formato válido.');
        }
        $id = $this->text($value, 'id', 'Identificador de regla', 160);
        if (! preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]*$/', $id)) {
            throw new DomainException('El identificador de regla solo admite letras, números, punto, guion y guion bajo.');
        }
        $priority = filter_var($value['priority'] ?? null, FILTER_VALIDATE_INT);
        if ($priority === false || $priority < 0 || $priority > 100000) {
            throw new DomainException('La prioridad debe ser un número entre 0 y 100000.');
        }

        $rule = [
            'id' => $id,
            'priority' => $priority,
            'effect' => $this->oneOf($value, 'effect', ['restrict', 'allow'], 'Efecto'),
            'validFrom' => $this->date($value, 'valid_from', 'Inicio de vigencia'),
            'timeWindows' => $this->timeWindows($value['time_windows'] ?? null),
            'appliesOnHolidays' => $this->truthy($value['applies_on_holidays'] ?? false),
            'sourceUrl' => $this->url($value['source_url'] ?? null, 'Fuente de la regla'),
            'verifiedAt' => $this->date($value, 'verified_at', 'Fecha de revisión de la regla'),
        ];
        $optionalDate = trim((string) ($value['valid_until'] ?? ''));
        if ($optionalDate !== '') {
            $rule['validUntil'] = $this->date($value, 'valid_until', 'Fin de vigencia');
        }
        $weekdays = $this->integers($value['weekdays'] ?? null, 1, 7, 'Día de semana');
        if ($weekdays !== []) {
            $rule['weekdays'] = $weekdays;
        }
        $parity = trim((string) ($value['date_parity'] ?? ''));
        if ($parity !== '') {
            if (! in_array($parity, ['odd', 'even'], true)) {
                throw new DomainException('La paridad de fecha no es válida.');
            }
            $rule['dateParity'] = $parity;
        }
        $digits = $this->integers($value['digits'] ?? null, 0, 9, 'Dígito');
        if ($digits !== []) {
            $rule['digitPosition'] = $this->oneOf($value, 'digit_position', ['firstNumeric', 'lastNumeric'], 'Posición del dígito');
            $rule['digits'] = $digits;
        }
        $origins = $this->words($value['registration_origins'] ?? null);
        if ($origins !== []) {
            foreach ($origins as $origin) {
                if (! in_array($origin, ['local', 'foreign', 'unknown'], true)) {
                    throw new DomainException('El origen de matrícula no es válido.');
                }
            }
            $rule['registrationOrigins'] = $origins;
        }

        return $rule;
    }

    /** @return list<array{startMinute:int,endMinute:int}> */
    private function timeWindows(mixed $value): array
    {
        $lines = preg_split('/[\r\n,;]+/', trim((string) $value), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        if ($lines === [] || count($lines) > 8) {
            throw new DomainException('Agrega entre 1 y 8 horarios en formato HH:MM-HH:MM.');
        }
        $windows = [];
        foreach ($lines as $line) {
            if (! preg_match('/^(\d{2}):(\d{2})\s*-\s*(\d{2}):(\d{2})$/', trim($line), $match)) {
                throw new DomainException('Horario inválido. Usa HH:MM-HH:MM, por ejemplo 06:00-20:00.');
            }
            [$startHour, $startMinute, $endHour, $endMinute] = array_map('intval', array_slice($match, 1));
            if ($startHour > 23 || $endHour > 23 || $startMinute > 59 || $endMinute > 59) {
                throw new DomainException('Horario inválido. Usa horas entre 00:00 y 23:59.');
            }
            $start = $startHour * 60 + $startMinute;
            $end = $endHour * 60 + $endMinute;
            if ($start === $end) {
                throw new DomainException('El inicio y el final del horario no pueden ser iguales.');
            }
            $windows[] = ['startMinute' => $start, 'endMinute' => $end];
        }

        return $windows;
    }

    /** @return list<int> */
    private function integers(mixed $value, int $min, int $max, string $label): array
    {
        $parts = preg_split('/[\s,;]+/', trim((string) $value), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $result = [];
        foreach ($parts as $part) {
            if (! preg_match('/^\d+$/', $part)) {
                throw new DomainException("$label inválido: $part.");
            }
            $number = (int) $part;
            if ($number < $min || $number > $max) {
                throw new DomainException("$label inválido: $part.");
            }
            $result[$number] = $number;
        }

        return array_values($result);
    }

    /** @return list<string> */
    private function words(mixed $value): array
    {
        return array_values(array_unique(preg_split('/[\s,;]+/', trim((string) $value), -1, PREG_SPLIT_NO_EMPTY) ?: []));
    }

    /** @return list<string> */
    private function urls(mixed $value): array
    {
        $urls = preg_split('/[\r\n,]+/', trim((string) $value), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        if ($urls === [] || count($urls) > 12) {
            throw new DomainException('Agrega entre 1 y 12 fuentes HTTPS.');
        }

        return array_map(fn (string $url): string => $this->url($url, 'Fuente'), $urls);
    }

    private function url(mixed $value, string $label): string
    {
        $url = trim((string) $value);
        if (strlen($url) > 2048 || filter_var($url, FILTER_VALIDATE_URL) === false || strtolower((string) parse_url($url, PHP_URL_SCHEME)) !== 'https') {
            throw new DomainException("$label debe ser una URL HTTPS válida.");
        }

        return $url;
    }

    /** @param array<string, mixed> $value */
    private function date(array $value, string $key, string $label): string
    {
        $raw = trim((string) ($value[$key] ?? ''));
        if (! preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:\d{2})?$/', $raw)) {
            throw new DomainException("$label no tiene una fecha y hora válida.");
        }
        try {
            $date = CarbonImmutable::parse($raw, 'America/Bogota');
        } catch (Throwable) {
            throw new DomainException("$label no tiene una fecha y hora válida.");
        }

        return $date->toAtomString();
    }

    /** @param array<string, mixed> $value @param list<string> $allowed */
    private function oneOf(array $value, string $key, array $allowed, string $label): string
    {
        $selected = trim((string) ($value[$key] ?? ''));
        if (! in_array($selected, $allowed, true)) {
            throw new DomainException("$label no es válido.");
        }

        return $selected;
    }

    /** @param array<string, mixed> $value */
    private function text(array $value, string $key, string $label, int $max): string
    {
        $text = trim((string) ($value[$key] ?? ''));
        if ($text === '' || mb_strlen($text) > $max) {
            throw new DomainException("$label es obligatorio y admite máximo $max caracteres.");
        }

        return $text;
    }

    private function truthy(mixed $value): bool
    {
        return in_array($value, [true, 1, '1', 'true', 'on', 'yes'], true);
    }
}
