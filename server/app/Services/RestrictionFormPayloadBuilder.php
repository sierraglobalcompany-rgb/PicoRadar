<?php

namespace App\Services;

use App\Models\Jurisdiction;
use Carbon\CarbonImmutable;
use DomainException;
use JsonException;
use Throwable;

final class RestrictionFormPayloadBuilder
{
    private const SCHEMA2_PAIRS = [
        'car|private', 'car|taxi', 'car|special', 'motorcycle|private',
        'truck|private', 'truck|public_cargo', 'bus|public_passenger',
        'bus|special', 'motocarro|private',
    ];

    public function __construct(private readonly RestrictionContractValidator $validator = new RestrictionContractValidator) {}

    /** @param array<string, mixed> $input @return array<string, mixed> */
    public function build(Jurisdiction $jurisdiction, array $input, int $schemaVersion = 1, ?array $existingPayload = null): array
    {
        if (! in_array($schemaVersion, [1, 2], true)) {
            throw new DomainException('La versión del esquema de restricciones no es compatible.');
        }
        $coverages = $input['coverages'] ?? null;
        $maximumCoverages = $schemaVersion === 2 ? 9 : 8;
        if (! is_array($coverages) || $coverages === [] || count($coverages) > $maximumCoverages) {
            throw new DomainException("Agrega entre 1 y $maximumCoverages coberturas de vehículo.");
        }

        $existingCompleteness = [];
        $existingRules = [];
        foreach ($existingPayload['coverages'] ?? [] as $existingCoverage) {
            if (is_array($existingCoverage)) {
                $pair = ($existingCoverage['vehicleKind'] ?? '').'|'.($existingCoverage['serviceType'] ?? '');
                $existingCompleteness[$pair] = $existingCoverage['coverageCompleteness'] ?? null;
                foreach ($existingCoverage['rules'] ?? [] as $existingRule) {
                    if (is_array($existingRule) && is_string($existingRule['id'] ?? null)) {
                        $existingRules[$pair][$existingRule['id']] = $existingRule;
                    }
                }
            }
        }
        $result = [];
        $seen = [];
        foreach (array_values($coverages) as $coverageIndex => $coverage) {
            if (! is_array($coverage)) {
                throw new DomainException('La cobertura no tiene un formato válido.');
            }
            if ($schemaVersion === 2) {
                $pair = trim((string) ($coverage['pair'] ?? ''));
                if (! in_array($pair, self::SCHEMA2_PAIRS, true)) {
                    throw new DomainException('La combinación de vehículo y servicio no es válida para schema2.');
                }
                [$vehicleKind, $serviceType] = explode('|', $pair, 2);
            } else {
                $vehicleKind = $this->oneOf($coverage, 'vehicle_kind', ['car', 'motorcycle'], 'Tipo de vehículo');
                $serviceType = $this->oneOf($coverage, 'service_type', ['private', 'taxi'], 'Servicio');
            }
            $coverageKey = "$vehicleKind:$serviceType";
            if (isset($seen[$coverageKey])) {
                throw new DomainException('No repitas la misma combinación de vehículo y servicio.');
            }
            $seen[$coverageKey] = true;
            // Schema2: a safe, reversible *consultation* pause uses the existing
            // partial+empty-rules contract. It is NOT evidence of free circulation.
            // Preserve the coverage identity so publication cannot drop it.
            $pauseConsultation = $this->truthy($coverage['suspend_consultation'] ?? false);
            if ($pauseConsultation && ($schemaVersion !== 2 || ! array_key_exists("$vehicleKind|$serviceType", $existingCompleteness))) {
                throw new DomainException('Solo se puede suspender una cobertura schema2 que ya existe en el borrador de origen.');
            }
            if ($pauseConsultation && $this->truthy($coverage['confirmed_no_rules'] ?? false)) {
                throw new DomainException('Suspender consulta y confirmar ausencia de restricciones son decisiones distintas; elige solo una.');
            }
            $submittedRules = $coverage['rules'] ?? [];
            if (! is_array($submittedRules) || count($submittedRules) > 1000) {
                throw new DomainException('Las reglas de la cobertura no tienen un formato válido.');
            }
            $rules = $pauseConsultation ? [] : $submittedRules;
            if ($rules === [] && ! $pauseConsultation && ! $this->truthy($coverage['confirmed_no_rules'] ?? false)) {
                throw new DomainException('Una cobertura sin reglas exige confirmar explícitamente que la fuente no publica restricción.');
            }

            $normalizedCoverage = [
                'vehicleKind' => $vehicleKind,
                'serviceType' => $serviceType,
                'verifiedAt' => $this->date($coverage, 'verified_at', 'Fecha de revisión'),
                'staleAfter' => $this->date($coverage, 'stale_after', 'Fecha de nueva revisión'),
                'sourceUrls' => $this->urls($coverage['source_urls'] ?? null),
                'rules' => array_map(
                    fn (mixed $rule, int $ruleIndex): array => $this->rule(
                        $rule,
                        $coverageIndex,
                        $ruleIndex,
                        $schemaVersion,
                        $existingRules["$vehicleKind|$serviceType"] ?? [],
                    ),
                    array_values($rules),
                    array_keys(array_values($rules)),
                ),
            ];
            if ($schemaVersion === 2) {
                $completeness = $existingCompleteness["$vehicleKind|$serviceType"] ?? 'partial';
                if (! in_array($completeness, ['complete', 'partial'], true)) {
                    throw new DomainException('La cobertura existente tiene un estado de completitud no válido; no se modificó.');
                }
                // Pausing must never preserve "complete": otherwise an empty
                // coverage could be evaluated as ALLOWED by the client.
                $normalizedCoverage['coverageCompleteness'] = $pauseConsultation ? 'partial' : $completeness;
            }
            $result[] = $normalizedCoverage;
        }

        $payload = [
            'id' => $jurisdiction->key,
            'name' => $jurisdiction->name,
            'coverages' => $result,
        ];
        if ($schemaVersion === 2) {
            $payload['schemaVersion'] = 2;
            $municipalityCodes = $existingPayload['municipalityCodes'] ?? null;
            if ($municipalityCodes === null) {
                $unit = $jurisdiction->relationLoaded('primaryGeographicUnit')
                    ? $jurisdiction->getRelation('primaryGeographicUnit')
                    : ($jurisdiction->exists ? $jurisdiction->primaryGeographicUnit : null);
                $code = $unit?->code;
                if (is_string($code) && preg_match('/^\d{5}$/', $code)) {
                    $municipalityCodes = [$code];
                }
            }
            $hadAvailabilityMetadata = array_key_exists('municipalityCodes', $existingPayload ?? [])
                || array_key_exists('consultationEnabled', $existingPayload ?? []);
            if ($hadAvailabilityMetadata && (! is_array($municipalityCodes) || ! array_key_exists('consultationEnabled', $existingPayload ?? []))) {
                throw new DomainException('Los metadatos de consulta existentes están incompletos; no se modificaron.');
            }
            if (is_array($municipalityCodes)) {
                $payload['municipalityCodes'] = $municipalityCodes;
                $payload['consultationEnabled'] = array_key_exists('consultation_enabled', $input)
                    ? $this->truthy($input['consultation_enabled'])
                    : (bool) ($existingPayload['consultationEnabled'] ?? false);
            }
            $this->validator->validateJurisdiction($payload, $jurisdiction->key, 2, true);
        }

        return $payload;
    }

    /** @return array<string, mixed> */
    private function rule(mixed $value, int $coverageIndex, int $ruleIndex, int $schemaVersion, array $existingRules = []): array
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
            'timeWindows' => $this->timeWindows($value['time_windows'] ?? null, $schemaVersion),
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
        if ($schemaVersion === 2) {
            try {
                if (array_key_exists('conditions_json', $value)) {
                    $conditions = json_decode((string) $value['conditions_json'], true, 512, JSON_THROW_ON_ERROR);
                } elseif (isset($existingRules[$id]['conditions'])) {
                    $conditions = $existingRules[$id]['conditions'];
                } else {
                    foreach ($existingRules as $existingRule) {
                        if (($existingRule['conditions'] ?? []) !== []) {
                            throw new DomainException('La ficha no envió las condiciones existentes; vuelve a cargarla para evitar perderlas.');
                        }
                    }
                    $conditions = [];
                }
                $this->validator->validateRuleConditions($conditions);
            } catch (JsonException $error) {
                throw new DomainException("coverages.$coverageIndex.rules.$ruleIndex.conditions_json: El JSON de condiciones no es válido; usa una lista, por ejemplo [].", previous: $error);
            } catch (DomainException $error) {
                throw new DomainException("coverages.$coverageIndex.rules.$ruleIndex.conditions_json: Las condiciones no cumplen el contrato schema2: ".$error->getMessage(), previous: $error);
            }
            $rule['conditions'] = $conditions;
        }

        return $rule;
    }

    /** @return list<array{startMinute:int,endMinute:int,fullDay?:true}> */
    private function timeWindows(mixed $value, int $schemaVersion): array
    {
        $lines = preg_split('/[\r\n,;]+/', trim((string) $value), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        if ($lines === [] || count($lines) > 8) {
            throw new DomainException('Agrega entre 1 y 8 horarios en formato HH:MM-HH:MM.');
        }
        $windows = [];
        foreach ($lines as $line) {
            if (! preg_match('/^(\d{2}):(\d{2})\s*-\s*(\d{2}):(\d{2})(?:\s+(fullDay))?$/', trim($line), $match)) {
                throw new DomainException('Horario inválido. Usa HH:MM-HH:MM; para todo el día agrega el marcador fullDay en schema2.');
            }
            [$startHour, $startMinute, $endHour, $endMinute] = array_map('intval', array_slice($match, 1));
            if ($startHour > 23 || $endHour > 23 || $startMinute > 59 || $endMinute > 59) {
                throw new DomainException('Horario inválido. Usa horas entre 00:00 y 23:59.');
            }
            $start = $startHour * 60 + $startMinute;
            $end = $endHour * 60 + $endMinute;
            if ($start === $end) {
                if ($schemaVersion !== 2 || ($match[5] ?? '') !== 'fullDay') {
                    throw new DomainException('El inicio y el final iguales requieren el marcador fullDay en schema2.');
                }
            } elseif (($match[5] ?? '') !== '') {
                throw new DomainException('El marcador fullDay solo se permite cuando el inicio y el final son iguales.');
            }
            $window = ['startMinute' => $start, 'endMinute' => $end];
            if (($match[5] ?? '') === 'fullDay') {
                $window['fullDay'] = true;
            }
            $windows[] = $window;
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
