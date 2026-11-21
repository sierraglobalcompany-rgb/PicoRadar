<?php

declare(strict_types=1);

use App\Services\RestrictionContractValidator;

$root = dirname(__DIR__, 3);
require $root.'/server/app/Services/RestrictionContractValidator.php';

$cases = [
    [
        'file' => 'server/database/data/restrictions/lab/2026-11-cali-official-calendar-partial.json',
        'id' => 'co-vac-cali',
        'municipalityCode' => '76001',
        'pairs' => ['car:private'],
        'coverageRules' => [
            'car:private' => [
                'digitPosition' => 'lastNumeric',
                'startMinute' => 360,
                'endMinute' => 1140,
                'days' => [1 => [0, 9], 2 => [1, 2], 3 => [3, 4], 4 => [5, 6], 5 => [7, 8]],
            ],
        ],
        'scope' => 'co-vac-cali-calendar-unknown-scope@2026-s2',
    ],
    [
        'file' => 'server/database/data/restrictions/lab/2026-11-pereira-official-calendar-partial.json',
        'id' => 'co-ris-pereira',
        'municipalityCode' => '66001',
        'pairs' => ['car:private', 'motorcycle:private'],
        'coverageRules' => [
            'car:private' => [
                'digitPosition' => 'lastNumeric',
                'startMinute' => 360,
                'endMinute' => 1200,
                'days' => [1 => [0, 1], 2 => [2, 3], 3 => [4, 5], 4 => [6, 7], 5 => [8, 9]],
            ],
            'motorcycle:private' => [
                'digitPosition' => 'firstNumeric',
                'startMinute' => 360,
                'endMinute' => 1200,
                'days' => [1 => [0, 1], 2 => [2, 3], 3 => [4, 5], 4 => [6, 7], 5 => [8, 9]],
            ],
        ],
        'scope' => 'co-ris-pereira-calendar-unknown-scope@2026-retorno',
    ],
];

$validator = new RestrictionContractValidator;
$summary = ['status' => 'PASS', 'envelopes' => [], 'negativeCases' => []];
$allJurisdictions = [];
$allRuleIds = [];
$ruleCount = 0;

foreach ($cases as $case) {
    $path = $root.'/'.$case['file'];
    $envelope = json_decode(file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
    if (($envelope['schemaVersion'] ?? null) !== 2 ||
        ($envelope['datasetKey'] ?? null) !== 'restrictions' ||
        ! is_string($envelope['version'] ?? null) ||
        ! str_starts_with($envelope['version'], 'LAB-V3-') ||
        ! hasExplicitOffset($envelope['generatedAt'] ?? null) ||
        count($envelope['jurisdictions'] ?? []) !== 1) {
        throw new RuntimeException('Invalid schema2 LAB envelope root: '.$case['file']);
    }

    $jurisdiction = $envelope['jurisdictions'][0];
    if (($jurisdiction['id'] ?? null) !== $case['id'] ||
        ($jurisdiction['municipalityCodes'] ?? null) !== [$case['municipalityCode']] ||
        ($jurisdiction['consultationEnabled'] ?? null) !== true) {
        throw new RuntimeException('Jurisdiction identity or availability mismatch: '.$case['id']);
    }

    $actualPairs = [];
    foreach ($jurisdiction['coverages'] ?? [] as $coverage) {
        $pair = ($coverage['vehicleKind'] ?? '').':'.($coverage['serviceType'] ?? '');
        $actualPairs[] = $pair;
        $expectedSchedule = $case['coverageRules'][$pair] ?? null;
        if ($expectedSchedule === null) {
            throw new RuntimeException('No schedule expectation for coverage pair: '.$pair);
        }
        if (($coverage['coverageCompleteness'] ?? null) !== 'partial' ||
            ! hasExplicitOffset($coverage['verifiedAt'] ?? null) ||
            ! hasExplicitOffset($coverage['staleAfter'] ?? null) ||
            new DateTimeImmutable($coverage['verifiedAt']) > new DateTimeImmutable($envelope['generatedAt']) ||
            new DateTimeImmutable($coverage['staleAfter']) <= new DateTimeImmutable($coverage['verifiedAt'])) {
            throw new RuntimeException('Coverage completeness or timestamps invalid: '.$pair);
        }

        foreach ($coverage['sourceUrls'] ?? [] as $url) {
            if (! is_string($url) || filter_var($url, FILTER_VALIDATE_URL) === false || ! str_starts_with($url, 'https://')) {
                throw new RuntimeException('Source must be an HTTPS URL: '.$case['id']);
            }
        }

        if (count($coverage['rules'] ?? []) !== 5) {
            throw new RuntimeException('Expected five ordinary weekday rules per coverage: '.$pair);
        }
        $actualSchedule = [];
        foreach ($coverage['rules'] as $rule) {
            $ruleCount++;
            $ruleId = $rule['id'] ?? null;
            if (! is_string($ruleId) || isset($allRuleIds[$ruleId])) {
                throw new RuntimeException('Missing or colliding rule ID.');
            }
            $allRuleIds[$ruleId] = true;
            if (($rule['effect'] ?? null) !== 'restrict' ||
                ! hasExplicitOffset($rule['validFrom'] ?? null) ||
                (isset($rule['validUntil']) && $rule['validUntil'] !== null && ! hasExplicitOffset($rule['validUntil'])) ||
                ! hasExplicitOffset($rule['verifiedAt'] ?? null) ||
                ($rule['conditions'][0]['value'] ?? null) !== $case['scope']) {
                throw new RuntimeException('Rule semantics, timestamps, or scope reference invalid: '.$ruleId);
            }
            if (count($rule['weekdays'] ?? []) !== 1 ||
                ($rule['digitPosition'] ?? null) !== $expectedSchedule['digitPosition'] ||
                ($rule['appliesOnHolidays'] ?? null) !== false ||
                isset($rule['dateParity']) ||
                ! isset($rule['timeWindows'][0]) ||
                count($rule['timeWindows']) !== 1 ||
                ($rule['timeWindows'][0]['startMinute'] ?? null) !== $expectedSchedule['startMinute'] ||
                ($rule['timeWindows'][0]['endMinute'] ?? null) !== $expectedSchedule['endMinute'] ||
                ! in_array($rule['sourceUrl'] ?? null, $coverage['sourceUrls'], true)) {
                throw new RuntimeException('Rule schedule, source, or holiday policy mismatch: '.$ruleId);
            }
            $weekday = $rule['weekdays'][0];
            $digits = $rule['digits'] ?? [];
            sort($digits);
            $expectedDigits = $expectedSchedule['days'][$weekday] ?? null;
            if ($expectedDigits === null || $digits !== $expectedDigits || isset($actualSchedule[$weekday])) {
                throw new RuntimeException('Rule weekday or digits mismatch: '.$ruleId);
            }
            $actualSchedule[$weekday] = $digits;
        }
        ksort($actualSchedule);
        if ($actualSchedule !== $expectedSchedule['days']) {
            throw new RuntimeException('Incomplete or unexpected weekday calendar: '.$pair);
        }
    }
    sort($actualPairs);
    $expectedPairs = $case['pairs'];
    sort($expectedPairs);
    if ($actualPairs !== $expectedPairs) {
        throw new RuntimeException('Coverage pair mismatch: '.$case['id']);
    }

    $contractSummary = $validator->validateJurisdictionForEnvelope($jurisdiction, $case['id'], 2);
    $allJurisdictions[$case['id']] = $jurisdiction;
    $summary['envelopes'][] = [
        'file' => $case['file'],
        'id' => $case['id'],
        'municipalityCode' => $case['municipalityCode'],
        'coveragePairs' => $actualPairs,
        'ruleCount' => array_sum(array_map(static fn (array $coverage): int => count($coverage['rules']), $jurisdiction['coverages'])),
        'phpValidator' => $contractSummary,
    ];
}

if ($ruleCount !== 15) {
    throw new RuntimeException('Expected fifteen non-colliding rules; got '.$ruleCount.'.');
}

$cali = $allJurisdictions['co-vac-cali'];
$pereira = $allJurisdictions['co-ris-pereira'];
$negativeCases = [
    'singular coverage key' => static function (array $value): array {
        $value['coverage'] = $value['coverages'][0];
        unset($value['coverages']);
        return $value;
    },
    'weekday string' => static function (array $value): array {
        $value['coverages'][0]['rules'][0]['weekdays'] = 'monday';
        return $value;
    },
    'dateParity any' => static function (array $value): array {
        $value['coverages'][0]['rules'][0]['dateParity'] = 'any';
        return $value;
    },
    'malformed inside_scope_ref' => static function (array $value): array {
        $value['coverages'][0]['rules'][0]['conditions'][0]['value'] = 'scope-without-version';
        return $value;
    },
];

foreach ($negativeCases as $label => $mutate) {
    $base = str_contains($label, 'inside_scope_ref') ? $pereira : $cali;
    try {
        $validator->validateJurisdictionForEnvelope($mutate($base), $base['id'], 2);
    } catch (\DomainException $error) {
        $summary['negativeCases'][] = ['case' => $label, 'rejected' => true, 'reason' => $error->getMessage()];
        continue;
    }
    throw new RuntimeException('Validator unexpectedly accepted negative case: '.$label);
}

echo json_encode($summary, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR).PHP_EOL;

function hasExplicitOffset(mixed $value): bool
{
    return is_string($value) && preg_match('/(?:Z|[+-]\d{2}:\d{2})$/', $value) === 1;
}
