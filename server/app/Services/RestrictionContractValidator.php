<?php

namespace App\Services;

use DateTimeImmutable;
use DomainException;

final class RestrictionContractValidator
{
    /**
     * @param  array<string,mixed>  $jurisdiction
     * @return array{vehicleKinds:list<string>,validFrom:?string,validUntil:?string,staleAfter:string,sourceCheckedAt:string}
     */
    public function validateJurisdiction(array $jurisdiction, ?string $expectedId = null): array
    {
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
            $vehicleKind = $this->enum($coverage, 'vehicleKind', ['car', 'motorcycle']);
            $serviceType = $this->enum($coverage, 'serviceType', ['private', 'taxi']);
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
                foreach ($this->requiredList($rule, 'timeWindows') as $windowIndex => $windowValue) {
                    $window = $this->object($windowValue, "timeWindows.$windowIndex");
                    $start = $window['startMinute'] ?? null;
                    $end = $window['endMinute'] ?? null;
                    if (! is_int($start) || ! is_int($end) || $start < 0 || $start >= 1440 || $end < 0 || $end >= 1440 || $start === $end) {
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

    /** @param array<string,mixed> $rule */
    private function conflictFingerprint(array $rule): string
    {
        $scope = [];
        foreach (['priority', 'weekdays', 'dateParity', 'digitPosition', 'digits', 'registrationOrigins', 'timeWindows', 'appliesOnHolidays'] as $key) {
            $scope[$key] = $rule[$key] ?? null;
        }

        return hash('sha256', json_encode($scope, JSON_THROW_ON_ERROR));
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
