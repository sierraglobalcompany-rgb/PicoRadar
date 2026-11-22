<?php

namespace App\Services;

use App\Enums\GeographicUnitLevel;
use App\Models\Jurisdiction;
use DateTimeImmutable;
use DomainException;

final class RestrictionContractValidator
{
    /** @param array<string,mixed> $payload */
    public function assertOffSchema2Payload(Jurisdiction $jurisdiction, array $payload): void
    {
        if (($payload['schemaVersion'] ?? null) !== 2 ||
            ($payload['id'] ?? null) !== $jurisdiction->key ||
            ($payload['consultationEnabled'] ?? null) !== false) {
            throw new DomainException('An OFF jurisdiction requires a schema2 payload with consultation disabled.');
        }

        $this->assertMunicipalityCodesBelongToJurisdiction($jurisdiction, $payload, true);
        $coverages = $payload['coverages'] ?? null;
        if (! is_array($coverages) || ! array_is_list($coverages) || $coverages === []) {
            throw new DomainException('An OFF jurisdiction requires at least one schema2 coverage.');
        }
        foreach ($coverages as $coverage) {
            if (! is_array($coverage) || ($coverage['consultationEnabled'] ?? null) !== false) {
                throw new DomainException('Every coverage of an OFF jurisdiction must disable consultation.');
            }
        }
    }

    /** @param array<string,mixed> $payload */
    public function assertMunicipalityCodesBelongToJurisdiction(Jurisdiction $jurisdiction, array $payload, bool $required = false): void
    {
        if (! array_key_exists('municipalityCodes', $payload)) {
            if ($required) {
                throw new DomainException('An OFF jurisdiction requires municipality DIVIPOLA codes.');
            }

            return;
        }

        $codes = $payload['municipalityCodes'];
        if (! is_array($codes) || ! array_is_list($codes) || $codes === []) {
            throw new DomainException('municipalityCodes must be a non-empty list of unique DIVIPOLA codes.');
        }
        foreach ($codes as $code) {
            if (! is_string($code) || preg_match('/^\d{5}$/D', $code) !== 1) {
                throw new DomainException('municipalityCodes must contain valid five-digit DIVIPOLA codes.');
            }
        }
        if (count(array_unique($codes)) !== count($codes)) {
            throw new DomainException('municipalityCodes must be a non-empty list of unique DIVIPOLA codes.');
        }

        $matched = $jurisdiction->geographicUnits()
            ->where('geographic_units.level', GeographicUnitLevel::Municipality->value)
            ->whereIn('geographic_units.code', $codes)
            ->distinct()
            ->count('geographic_units.id');
        if ($matched !== count($codes)) {
            throw new DomainException('municipalityCodes do not belong to the jurisdiction.');
        }
    }

    /**
     * @param  array<string,mixed>  $jurisdiction
     * @return array{vehicleKinds:list<string>,validFrom:?string,validUntil:?string,staleAfter:string,sourceCheckedAt:string}
     */
    public function validateJurisdictionForEnvelope(array $jurisdiction, string $expectedId, int $envelopeSchemaVersion): array
    {
        if (! in_array($envelopeSchemaVersion, [1, 2], true)) {
            throw new DomainException('Unsupported restrictions envelope schemaVersion.');
        }
        $citySchemaVersion = array_key_exists('schemaVersion', $jurisdiction)
            ? $jurisdiction['schemaVersion']
            : 1;
        if (! in_array($citySchemaVersion, [1, 2], true) ||
            ($envelopeSchemaVersion === 1 && $citySchemaVersion !== 1)) {
            throw new DomainException('Jurisdiction schemaVersion does not match the dataset envelope.');
        }

        return $this->validateJurisdiction(
            $jurisdiction,
            $expectedId,
            $citySchemaVersion,
            $envelopeSchemaVersion === 2,
        );
    }

    /**
     * @param  array<string,mixed>  $jurisdiction
     * @return array{vehicleKinds:list<string>,validFrom:?string,validUntil:?string,staleAfter:string,sourceCheckedAt:string}
     */
    public function validateJurisdiction(
        array $jurisdiction,
        ?string $expectedId = null,
        ?int $schemaVersion = null,
        bool $allowAvailabilityMetadata = false,
    ): array {
        if ($schemaVersion === null) {
            $declaredSchemaVersion = array_key_exists('schemaVersion', $jurisdiction)
                ? $jurisdiction['schemaVersion']
                : 1;
            if (! is_int($declaredSchemaVersion)) {
                throw new DomainException('Jurisdiction schemaVersion does not match the dataset contract.');
            }
            $schemaVersion = $declaredSchemaVersion;
        }
        if (! in_array($schemaVersion, [1, 2], true) ||
            (array_key_exists('schemaVersion', $jurisdiction) && $jurisdiction['schemaVersion'] !== $schemaVersion)) {
            throw new DomainException('Jurisdiction schemaVersion does not match the dataset contract.');
        }
        if ($schemaVersion === 2 && ($jurisdiction['schemaVersion'] ?? null) !== 2) {
            throw new DomainException('Schema2 requires schemaVersion 2 on each jurisdiction.');
        }
        $jurisdictionKeys = ['schemaVersion', 'id', 'name', 'coverages'];
        if ($allowAvailabilityMetadata) {
            $jurisdictionKeys = [...$jurisdictionKeys, 'municipalityCodes', 'consultationEnabled'];
            $this->validateAvailabilityMetadata($jurisdiction);
        }
        $this->knownKeys($jurisdiction, $jurisdictionKeys, 'jurisdiction');
        $id = $this->requiredString($jurisdiction, 'id');
        if ($expectedId !== null && $id !== $expectedId) {
            throw new DomainException('Jurisdiction id does not match the selected city.');
        }
        $this->requiredString($jurisdiction, 'name');
        $coverages = $this->requiredList($jurisdiction, 'coverages');
        $coverageKeys = [];
        $ruleIds = [];
        $vehicleKinds = [];
        $validFrom = null;
        $validUntil = null;
        $hasOpenEndedRule = false;
        $staleAfter = null;
        $sourceCheckedAt = null;

        foreach ($coverages as $coverageIndex => $coverageValue) {
            $coverage = $this->object($coverageValue, "coverages.$coverageIndex");
            $this->knownKeys($coverage, $schemaVersion === 1
                ? ['vehicleKind', 'serviceType', 'verifiedAt', 'staleAfter', 'sourceUrls', 'rules']
                : ['vehicleKind', 'serviceType', 'coverageCompleteness', 'consultationEnabled', 'verifiedAt', 'staleAfter', 'sourceUrls', 'rules'], 'coverage');
            $vehicleKind = $this->enum($coverage, 'vehicleKind', $schemaVersion === 1
                ? ['car', 'motorcycle']
                : ['car', 'motorcycle', 'truck', 'bus', 'motocarro']);
            $serviceType = $this->enum($coverage, 'serviceType', $schemaVersion === 1
                ? ['private', 'taxi']
                : ['private', 'taxi', 'public_passenger', 'special', 'public_cargo']);
            if (($schemaVersion === 1 && ! $this->isLegacyPair($vehicleKind, $serviceType)) ||
                ($schemaVersion === 2 && ! $this->isV2Pair($vehicleKind, $serviceType))) {
                throw new DomainException('Unsupported vehicleKind/serviceType pair.');
            }
            if ($schemaVersion === 2) {
                $this->enum($coverage, 'coverageCompleteness', ['complete', 'partial']);
                if (array_key_exists('consultationEnabled', $coverage) && ! is_bool($coverage['consultationEnabled'])) {
                    throw new DomainException('coverage consultationEnabled must be a boolean.');
                }
            }
            $coverageKey = "$vehicleKind:$serviceType";
            if (isset($coverageKeys[$coverageKey])) {
                throw new DomainException('Duplicate restriction coverage.');
            }
            $coverageKeys[$coverageKey] = true;
            $vehicleKinds[$vehicleKind] = true;
            $coverageVerifiedAt = $this->date($coverage, 'verifiedAt');
            $coverageStaleAfter = $this->date($coverage, 'staleAfter');
            if ($coverageStaleAfter <= $coverageVerifiedAt) {
                throw new DomainException('staleAfter must be later than verifiedAt.');
            }
            $staleAfter = $staleAfter === null || $coverageStaleAfter < $staleAfter ? $coverageStaleAfter : $staleAfter;
            $sourceCheckedAt = $sourceCheckedAt === null || $coverageVerifiedAt > $sourceCheckedAt ? $coverageVerifiedAt : $sourceCheckedAt;
            $sourceUrls = $this->requiredList($coverage, 'sourceUrls');
            if ($sourceUrls === []) {
                throw new DomainException('sourceUrls must not be empty.');
            }
            foreach ($sourceUrls as $url) {
                $this->httpsUrl($url, 'sourceUrls[]');
            }

            $conflicts = [];
            foreach ($this->requiredList($coverage, 'rules') as $ruleIndex => $ruleValue) {
                $rule = $this->object($ruleValue, "coverages.$coverageIndex.rules.$ruleIndex");
                $this->knownKeys($rule, $schemaVersion === 1
                    ? ['id', 'priority', 'effect', 'validFrom', 'validUntil', 'weekdays', 'dateParity', 'digitPosition', 'digits', 'registrationOrigins', 'timeWindows', 'appliesOnHolidays', 'sourceUrl', 'verifiedAt']
                    : ['id', 'priority', 'effect', 'validFrom', 'validUntil', 'weekdays', 'dateParity', 'digitPosition', 'digits', 'registrationOrigins', 'timeWindows', 'appliesOnHolidays', 'sourceUrl', 'verifiedAt', 'conditions'], 'rule');
                $ruleId = $this->requiredString($rule, 'id');
                if (isset($ruleIds[$ruleId])) {
                    throw new DomainException('Duplicate restriction rule id.');
                }
                $ruleIds[$ruleId] = true;
                if (! is_int($rule['priority'] ?? null)) {
                    throw new DomainException('priority must be an integer.');
                }
                $this->enum($rule, 'effect', ['restrict', 'allow']);
                $from = $this->date($rule, 'validFrom');
                $until = null;
                if (array_key_exists('validUntil', $rule) && $rule['validUntil'] !== null) {
                    $until = $this->date($rule, 'validUntil');
                    if ($until < $from) {
                        throw new DomainException('validUntil must not precede validFrom.');
                    }
                } else {
                    $hasOpenEndedRule = true;
                }
                $validFrom = $validFrom === null || $from < $validFrom ? $from : $validFrom;
                $validUntil = $until !== null && ($validUntil === null || $until > $validUntil) ? $until : $validUntil;

                $this->optionalIntList($rule, 'weekdays', 1, 7);
                $this->optionalEnum($rule, 'dateParity', ['odd', 'even']);
                $this->optionalEnum($rule, 'digitPosition', ['firstNumeric', 'lastNumeric']);
                $digits = $this->optionalIntList($rule, 'digits', 0, 9);
                if ($digits !== null && ! isset($rule['digitPosition'])) {
                    throw new DomainException('digitPosition is required with digits.');
                }
                $this->optionalEnumList($rule, 'registrationOrigins', ['local', 'foreign', 'unknown']);
                if ($schemaVersion === 2) {
                    $this->validateConditions(array_key_exists('conditions', $rule) ? $rule['conditions'] : []);
                }
                foreach ($this->requiredList($rule, 'timeWindows') as $windowIndex => $windowValue) {
                    $window = $this->object($windowValue, "timeWindows.$windowIndex");
                    $this->knownKeys($window, $schemaVersion === 2
                        ? ['startMinute', 'endMinute', 'fullDay']
                        : ['startMinute', 'endMinute'], 'timeWindow');
                    $start = $window['startMinute'] ?? null;
                    $end = $window['endMinute'] ?? null;
                    $hasFullDay = array_key_exists('fullDay', $window);
                    $validMinutes = is_int($start) && is_int($end)
                        && $start >= 0 && $start < 1440
                        && $end >= 0 && $end < 1440;
                    $validFullDay = $start !== $end || ($schemaVersion === 2
                        && $hasFullDay && $window['fullDay'] === true);
                    $markerMatchesWindow = $start === $end || ! $hasFullDay;
                    if (! $validMinutes || ! $validFullDay || ! $markerMatchesWindow) {
                        throw new DomainException('Invalid restriction timeWindow.');
                    }
                }
                if (! is_bool($rule['appliesOnHolidays'] ?? null)) {
                    throw new DomainException('appliesOnHolidays must be a boolean.');
                }
                $this->httpsUrl($rule['sourceUrl'] ?? null, 'sourceUrl');
                $this->date($rule, 'verifiedAt');

                $fingerprint = $this->conflictFingerprint($rule);
                foreach ($conflicts[$fingerprint] ?? [] as [$otherFrom, $otherUntil]) {
                    if ($this->dateRangesOverlap($from, $until, $otherFrom, $otherUntil)) {
                        throw new DomainException('Conflicting restriction rules share scope and priority.');
                    }
                }
                $conflicts[$fingerprint][] = [$from, $until];
            }
        }

        $vehicleKinds = array_keys($vehicleKinds);
        sort($vehicleKinds);

        return [
            'vehicleKinds' => $vehicleKinds,
            'validFrom' => $validFrom?->format('Y-m-d'),
            'validUntil' => $hasOpenEndedRule ? null : $validUntil?->format('Y-m-d'),
            'staleAfter' => $staleAfter?->format(DATE_ATOM) ?? throw new DomainException('At least one coverage is required.'),
            'sourceCheckedAt' => $sourceCheckedAt?->format(DATE_ATOM) ?? throw new DomainException('At least one coverage is required.'),
        ];
    }

    public function validateRuleConditions(mixed $conditions): void
    {
        $this->validateConditions($conditions);
    }

    /** @param array<string,mixed> $jurisdiction */
    private function validateAvailabilityMetadata(array $jurisdiction): void
    {
        $hasMunicipalityCodes = array_key_exists('municipalityCodes', $jurisdiction);
        $hasConsultationEnabled = array_key_exists('consultationEnabled', $jurisdiction);
        if ($hasMunicipalityCodes !== $hasConsultationEnabled) {
            throw new DomainException('municipalityCodes and consultationEnabled must be supplied together.');
        }
        if (! $hasMunicipalityCodes) {
            return;
        }

        if (! is_bool($jurisdiction['consultationEnabled'])) {
            throw new DomainException('consultationEnabled must be a boolean.');
        }
        $codes = $this->requiredList($jurisdiction, 'municipalityCodes');
        if ($codes === []) {
            throw new DomainException('municipalityCodes must not be empty.');
        }
        $previous = null;
        $seen = [];
        foreach ($codes as $code) {
            if (! is_string($code) || ! preg_match('/^\d{5}$/', $code)) {
                throw new DomainException('municipalityCodes must contain five-digit DIVIPOLA strings.');
            }
            if (isset($seen[$code])) {
                throw new DomainException('municipalityCodes must not contain duplicates.');
            }
            if ($previous !== null && strcmp($previous, $code) >= 0) {
                throw new DomainException('municipalityCodes must be sorted canonically.');
            }
            $seen[$code] = true;
            $previous = $code;
        }
    }

    /** @param array<string,mixed> $rule */
    private function conflictFingerprint(array $rule): string
    {
        $scope = [];
        foreach (['priority', 'weekdays', 'dateParity', 'digitPosition', 'digits', 'registrationOrigins', 'timeWindows', 'appliesOnHolidays', 'conditions'] as $key) {
            $scope[$key] = $rule[$key] ?? null;
        }

        return hash('sha256', json_encode($scope, JSON_THROW_ON_ERROR));
    }

    /** @param array<string,mixed> $rule */
    private function validateConditions(mixed $conditions): void
    {
        if (! is_array($conditions) || ! array_is_list($conditions)) {
            throw new DomainException('conditions must be a list.');
        }
        $types = [];
        $occupantsAtLeast = null;
        $occupantsBelow = null;
        foreach ($conditions as $conditionValue) {
            if (! is_array($conditionValue) || array_is_list($conditionValue)) {
                throw new DomainException('conditions[] must be an object.');
            }
            $this->knownKeys($conditionValue, ['type', 'value'], 'condition');
            $type = $this->enum($conditionValue, 'type', [
                'pillion_present', 'occupants_at_least', 'occupants_below',
                'gross_weight_kg_gt', 'axles_at_least', 'inside_scope_ref',
            ]);
            if (isset($types[$type])) {
                throw new DomainException('Duplicate condition type.');
            }
            $types[$type] = true;
            $value = $conditionValue['value'] ?? null;
            if ($type === 'pillion_present') {
                if (! is_bool($value)) {
                    throw new DomainException('pillion_present value must be boolean.');
                }
            } elseif ($type === 'inside_scope_ref') {
                if (! is_string($value) || trim($value) === '' || trim($value) !== $value) {
                    throw new DomainException('inside_scope_ref value must be a scopeId@scopeVersion string.');
                }
                $separator = strrpos($value, '@');
                if ($separator === false || $separator === 0 || $separator === strlen($value) - 1 || str_contains(substr($value, 0, $separator), '@')) {
                    throw new DomainException('inside_scope_ref value must be a scopeId@scopeVersion string.');
                }
            } else {
                [$minimum, $maximum] = match ($type) {
                    'occupants_at_least', 'occupants_below' => [1, 99],
                    'gross_weight_kg_gt' => [0, 100000],
                    'axles_at_least' => [1, 20],
                };
                if (! is_int($value) || $value < $minimum || $value > $maximum) {
                    throw new DomainException('BAD_CONDITION_VALUE: '.$type.' is outside its allowed range.');
                }
                if ($type === 'occupants_at_least') {
                    $occupantsAtLeast = $value;
                } elseif ($type === 'occupants_below') {
                    $occupantsBelow = $value;
                }
            }
        }
        if ($occupantsAtLeast !== null && $occupantsBelow !== null && $occupantsAtLeast >= $occupantsBelow) {
            throw new DomainException('BAD_CONDITION_VALUE: occupancy interval is impossible.');
        }
    }

    private function isLegacyPair(string $kind, string $service): bool
    {
        return ($kind === 'car' && in_array($service, ['private', 'taxi'], true)) ||
            ($kind === 'motorcycle' && $service === 'private');
    }

    private function isV2Pair(string $kind, string $service): bool
    {
        return $this->isLegacyPair($kind, $service) ||
            ($kind === 'truck' && in_array($service, ['private', 'public_cargo'], true)) ||
            ($kind === 'bus' && in_array($service, ['public_passenger', 'special'], true)) ||
            ($kind === 'car' && $service === 'special') ||
            ($kind === 'motocarro' && $service === 'private');
    }

    /** @param array<string,mixed> $value @param list<string> $allowed */
    private function knownKeys(array $value, array $allowed, string $label): void
    {
        $unknown = array_diff(array_keys($value), $allowed);
        if ($unknown !== []) {
            throw new DomainException($label.' contains unsupported key: '.reset($unknown).'.');
        }
    }

    private function dateRangesOverlap(DateTimeImmutable $leftFrom, ?DateTimeImmutable $leftUntil, DateTimeImmutable $rightFrom, ?DateTimeImmutable $rightUntil): bool
    {
        return ($leftUntil === null || $rightFrom <= $leftUntil) && ($rightUntil === null || $leftFrom <= $rightUntil);
    }

    /** @param array<string,mixed> $value */
    private function requiredString(array $value, string $key): string
    {
        if (! is_string($value[$key] ?? null) || trim($value[$key]) === '') {
            throw new DomainException("$key is required.");
        }

        return trim($value[$key]);
    }

    /** @param array<string,mixed> $value @return list<mixed> */
    private function requiredList(array $value, string $key): array
    {
        if (! is_array($value[$key] ?? null) || ! array_is_list($value[$key])) {
            throw new DomainException("$key must be a list.");
        }

        return $value[$key];
    }

    /** @return array<string,mixed> */
    private function object(mixed $value, string $key): array
    {
        if (! is_array($value) || array_is_list($value)) {
            throw new DomainException("$key must be an object.");
        }

        return $value;
    }

    /** @param array<string,mixed> $value @param list<string> $allowed */
    private function enum(array $value, string $key, array $allowed): string
    {
        $selected = $this->requiredString($value, $key);
        if (! in_array($selected, $allowed, true)) {
            throw new DomainException("$key is invalid.");
        }

        return $selected;
    }

    /** @param array<string,mixed> $value @param list<string> $allowed */
    private function optionalEnum(array $value, string $key, array $allowed): void
    {
        if (array_key_exists($key, $value) && $value[$key] !== null) {
            $this->enum($value, $key, $allowed);
        }
    }

    /** @param array<string,mixed> $value @param list<string> $allowed */
    private function optionalEnumList(array $value, string $key, array $allowed): void
    {
        if (! array_key_exists($key, $value) || $value[$key] === null) {
            return;
        }
        foreach ($this->requiredList($value, $key) as $item) {
            if (! is_string($item) || ! in_array($item, $allowed, true)) {
                throw new DomainException("$key contains an invalid value.");
            }
        }
    }

    /** @param array<string,mixed> $value @return list<int>|null */
    private function optionalIntList(array $value, string $key, int $min, int $max): ?array
    {
        if (! array_key_exists($key, $value) || $value[$key] === null) {
            return null;
        }
        $result = [];
        foreach ($this->requiredList($value, $key) as $item) {
            if (! is_int($item) || $item < $min || $item > $max || in_array($item, $result, true)) {
                throw new DomainException("$key contains an invalid value.");
            }
            $result[] = $item;
        }

        return $result;
    }

    /** @param array<string,mixed> $value */
    private function date(array $value, string $key): DateTimeImmutable
    {
        $date = $this->requiredString($value, $key);
        if (! preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?$/', $date)) {
            throw new DomainException("$key must be an ISO-8601 date.");
        }
        try {
            return new DateTimeImmutable($date);
        } catch (\Throwable) {
            throw new DomainException("$key must be a valid date.");
        }
    }

    private function httpsUrl(mixed $value, string $key): void
    {
        if (! is_string($value) || filter_var($value, FILTER_VALIDATE_URL) === false || strtolower((string) parse_url($value, PHP_URL_SCHEME)) !== 'https') {
            throw new DomainException("$key must be an HTTPS URL.");
        }
    }
}
