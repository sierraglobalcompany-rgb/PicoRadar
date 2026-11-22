<?php

namespace Tests\Unit;

use App\Services\RestrictionContractValidator;
use DomainException;
use PHPUnit\Framework\TestCase;

class RestrictionContractValidatorV2Test extends TestCase
{
    public function test_accepts_typed_v2_conditions_and_explicit_partial_coverage(): void
    {
        $summary = (new RestrictionContractValidator)->validateJurisdiction($this->jurisdiction());

        $this->assertSame(['truck'], $summary['vehicleKinds']);
    }

    public function test_schema2_coverage_toggle_is_optional_for_history_and_strictly_boolean_when_present(): void
    {
        $validator = new RestrictionContractValidator;
        $historical = $this->jurisdiction();
        $validator->validateJurisdiction($historical, null, 2);

        $disabled = $this->jurisdiction();
        $disabled['coverages'][0]['consultationEnabled'] = false;
        $validator->validateJurisdiction($disabled, null, 2);

        foreach (['false', 0, null] as $invalidValue) {
            $invalid = $this->jurisdiction();
            $invalid['coverages'][0]['consultationEnabled'] = $invalidValue;
            try {
                $validator->validateJurisdiction($invalid, null, 2);
                $this->fail('A non-boolean schema2 consultation toggle was accepted.');
            } catch (DomainException $error) {
                $this->assertStringContainsString('must be a boolean', $error->getMessage());
            }
        }

        $legacy = $this->jurisdiction();
        unset($legacy['schemaVersion'], $legacy['coverages'][0]['coverageCompleteness']);
        unset($legacy['coverages'][0]['rules'][0]['conditions']);
        $legacy['coverages'][0]['consultationEnabled'] = false;
        $this->expectException(DomainException::class);
        $validator->validateJurisdiction($legacy, null, 1);
    }

    public function test_rejects_unknown_duplicate_and_impossible_conditions(): void
    {
        foreach ([
            fn (array &$payload) => $payload['coverages'][0]['rules'][0]['conditions'][] = ['type' => 'future_operator', 'value' => true],
            fn (array &$payload) => $payload['coverages'][0]['rules'][0]['conditions'][] = ['type' => 'gross_weight_kg_gt', 'value' => 9000],
            fn (array &$payload) => $payload['coverages'][0]['rules'][0]['conditions'] = [
                ['type' => 'occupants_at_least', 'value' => 3],
                ['type' => 'occupants_below', 'value' => 3],
            ],
        ] as $mutate) {
            $payload = $this->jurisdiction();
            $mutate($payload);
            try {
                (new RestrictionContractValidator)->validateJurisdiction($payload, null, 2);
                $this->fail('Expected strict V2 condition validation to reject input.');
            } catch (DomainException) {
                $this->assertTrue(true);
            }
        }
    }

    public function test_rejects_v2_conditions_in_a_schema1_city(): void
    {
        $payload = $this->jurisdiction();
        $payload['schemaVersion'] = 1;

        $this->expectException(DomainException::class);
        (new RestrictionContractValidator)->validateJurisdiction($payload, null, 1);
    }

    public function test_schema2_full_day_windows_require_an_explicit_boolean_marker(): void
    {
        $valid = $this->jurisdiction();
        $valid['coverages'][0]['rules'][0]['timeWindows'] = [[
            'startMinute' => 360,
            'endMinute' => 360,
            'fullDay' => true,
        ]];
        (new RestrictionContractValidator)->validateJurisdiction($valid, null, 2);

        $invalidWindows = [
            ['startMinute' => 360, 'endMinute' => 360],
            ['startMinute' => 360, 'endMinute' => 360, 'fullDay' => false],
            ['startMinute' => 360, 'endMinute' => 360, 'fullDay' => null],
            ['startMinute' => 360, 'endMinute' => 360, 'fullDay' => 'true'],
            ['startMinute' => 360, 'endMinute' => 360, 'fullDay' => 1],
            ['startMinute' => 360, 'endMinute' => 420, 'fullDay' => true],
            ['startMinute' => 1440, 'endMinute' => 1440, 'fullDay' => true],
        ];

        foreach ($invalidWindows as $window) {
            $payload = $this->jurisdiction();
            $payload['coverages'][0]['rules'][0]['timeWindows'] = [$window];
            try {
                (new RestrictionContractValidator)->validateJurisdiction($payload, null, 2);
                $this->fail('Malformed full-day time window was accepted.');
            } catch (DomainException) {
                $this->assertTrue(true);
            }
        }
    }

    public function test_schema1_rejects_full_day_time_window_marker(): void
    {
        $legacy = $this->jurisdiction();
        unset($legacy['schemaVersion']);
        $legacy['coverages'][0]['vehicleKind'] = 'car';
        $legacy['coverages'][0]['serviceType'] = 'private';
        unset($legacy['coverages'][0]['coverageCompleteness']);
        unset($legacy['coverages'][0]['rules'][0]['conditions']);
        $legacy['coverages'][0]['rules'][0]['timeWindows'] = [[
            'startMinute' => 360,
            'endMinute' => 480,
        ]];
        (new RestrictionContractValidator)->validateJurisdiction($legacy, null, 1);

        $legacy['coverages'][0]['rules'][0]['timeWindows'] = [[
            'startMinute' => 360,
            'endMinute' => 360,
            'fullDay' => true,
        ]];

        $this->expectException(DomainException::class);
        (new RestrictionContractValidator)->validateJurisdiction($legacy, null, 1);
    }

    public function test_full_day_rules_still_participate_in_priority_conflict_checks(): void
    {
        $payload = $this->jurisdiction();
        $payload['coverages'][0]['rules'][0]['timeWindows'] = [[
            'startMinute' => 360,
            'endMinute' => 360,
            'fullDay' => true,
        ]];
        $duplicate = $payload['coverages'][0]['rules'][0];
        $duplicate['id'] = 'synthetic-full-day-conflict';
        $payload['coverages'][0]['rules'][] = $duplicate;

        $this->expectException(DomainException::class);
        (new RestrictionContractValidator)->validateJurisdiction($payload, null, 2);
    }

    public function test_accepts_availability_metadata_in_root_schema2_for_legacy_and_v2_cities(): void
    {
        $validator = new RestrictionContractValidator;
        $legacy = $this->jurisdiction();
        unset($legacy['schemaVersion']);
        $legacy['coverages'][0]['vehicleKind'] = 'car';
        $legacy['coverages'][0]['serviceType'] = 'private';
        unset($legacy['coverages'][0]['coverageCompleteness']);
        unset($legacy['coverages'][0]['rules'][0]['conditions']);
        $legacy['municipalityCodes'] = ['05001'];
        $legacy['consultationEnabled'] = false;

        $legacyResult = $validator->validateJurisdictionForEnvelope($legacy, 'co-g2-synthetic', 2);
        $this->assertSame(['car'], $legacyResult['vehicleKinds']);

        $schema2 = $this->jurisdiction();
        $schema2['municipalityCodes'] = ['05001', '05002'];
        $schema2['consultationEnabled'] = true;
        $schema2Result = $validator->validateJurisdictionForEnvelope($schema2, 'co-g2-synthetic', 2);
        $this->assertSame(['truck'], $schema2Result['vehicleKinds']);
    }

    public function test_root_schema1_rejects_availability_metadata(): void
    {
        $legacy = $this->jurisdiction();
        unset($legacy['schemaVersion']);
        $legacy['coverages'][0]['vehicleKind'] = 'car';
        $legacy['coverages'][0]['serviceType'] = 'private';
        unset($legacy['coverages'][0]['coverageCompleteness']);
        unset($legacy['coverages'][0]['rules'][0]['conditions']);
        $legacy['municipalityCodes'] = ['05001'];
        $legacy['consultationEnabled'] = true;

        $this->expectException(DomainException::class);
        (new RestrictionContractValidator)->validateJurisdictionForEnvelope($legacy, 'co-g2-synthetic', 1);
    }

    public function test_rejects_partial_malformed_and_noncanonical_availability_metadata(): void
    {
        $mutations = [
            static function (array &$payload): void {
                unset($payload['consultationEnabled']);
            },
            static fn (array &$payload) => $payload['municipalityCodes'] = [],
            static fn (array &$payload) => $payload['municipalityCodes'] = ['5001'],
            static fn (array &$payload) => $payload['municipalityCodes'] = ['05001', '05001'],
            static fn (array &$payload) => $payload['municipalityCodes'] = ['05002', '05001'],
            static fn (array &$payload) => $payload['consultationEnabled'] = 'true',
            static fn (array &$payload) => $payload['availabilityNote'] = 'unsupported',
        ];

        foreach ($mutations as $mutate) {
            $payload = $this->jurisdiction();
            $payload['municipalityCodes'] = ['05001'];
            $payload['consultationEnabled'] = true;
            $mutate($payload);
            try {
                (new RestrictionContractValidator)->validateJurisdictionForEnvelope($payload, 'co-g2-synthetic', 2);
                $this->fail('Invalid restriction availability metadata was accepted.');
            } catch (DomainException) {
                $this->assertTrue(true);
            }
        }
    }

    public function test_accepts_all_six_condition_types_at_their_boundaries(): void
    {
        $payload = $this->jurisdiction();
        $payload['coverages'][0]['rules'][0]['conditions'] = [
            ['type' => 'pillion_present', 'value' => false],
            ['type' => 'occupants_at_least', 'value' => 1],
            ['type' => 'occupants_below', 'value' => 99],
            ['type' => 'gross_weight_kg_gt', 'value' => 0],
            ['type' => 'axles_at_least', 'value' => 20],
            ['type' => 'inside_scope_ref', 'value' => 'zone-1@version-2'],
        ];

        $summary = (new RestrictionContractValidator)->validateJurisdiction($payload, null, 2);

        $this->assertSame(['truck'], $summary['vehicleKinds']);
    }

    public function test_rejects_invalid_condition_types_values_ranges_and_scope_ids(): void
    {
        foreach ([
            ['type' => 'pillion_present', 'value' => 1],
            ['type' => 'occupants_at_least', 'value' => 0],
            ['type' => 'occupants_below', 'value' => 100],
            ['type' => 'gross_weight_kg_gt', 'value' => 100001],
            ['type' => 'axles_at_least', 'value' => 21],
            ['type' => 'inside_scope_ref', 'value' => '@version'],
            ['type' => 'inside_scope_ref', 'value' => 'zone@version@extra'],
        ] as $invalidCondition) {
            $payload = $this->jurisdiction();
            $payload['coverages'][0]['rules'][0]['conditions'] = [$invalidCondition];
            try {
                (new RestrictionContractValidator)->validateJurisdiction($payload, null, 2);
                $this->fail('An invalid typed condition was accepted.');
            } catch (DomainException) {
                $this->assertTrue(true);
            }
        }
    }

    public function test_rejects_null_conditions_and_noncanonical_scope_references(): void
    {
        $nullConditions = $this->jurisdiction();
        $nullConditions['coverages'][0]['rules'][0]['conditions'] = null;
        try {
            (new RestrictionContractValidator)->validateJurisdiction($nullConditions, null, 2);
            $this->fail('Explicit null conditions must not be treated as an empty list.');
        } catch (DomainException) {
            $this->assertTrue(true);
        }

        $paddedScope = $this->jurisdiction();
        $paddedScope['coverages'][0]['rules'][0]['conditions'] = [
            ['type' => 'inside_scope_ref', 'value' => ' zone@v2 '],
        ];
        $this->expectException(DomainException::class);
        (new RestrictionContractValidator)->validateJurisdiction($paddedScope, null, 2);
    }

    public function test_accepts_only_the_nine_documented_vehicle_service_pairs(): void
    {
        $allowed = [
            ['car', 'private'], ['car', 'taxi'], ['motorcycle', 'private'],
            ['truck', 'private'], ['truck', 'public_cargo'],
            ['bus', 'public_passenger'], ['bus', 'special'],
            ['car', 'special'], ['motocarro', 'private'],
        ];
        $payload = $this->jurisdiction();
        $coverage = $payload['coverages'][0];
        $coverage['rules'] = [];
        $payload['coverages'] = [];
        foreach ($allowed as [$vehicleKind, $serviceType]) {
            $payload['coverages'][] = array_merge($coverage, [
                'vehicleKind' => $vehicleKind,
                'serviceType' => $serviceType,
            ]);
        }

        (new RestrictionContractValidator)->validateJurisdiction($payload, null, 2);

        foreach ([['truck', 'taxi'], ['bus', 'taxi'], ['motorcycle', 'public_cargo']] as [$vehicleKind, $serviceType]) {
            $invalid = $this->jurisdiction();
            $invalid['coverages'][0]['vehicleKind'] = $vehicleKind;
            $invalid['coverages'][0]['serviceType'] = $serviceType;
            try {
                (new RestrictionContractValidator)->validateJurisdiction($invalid, null, 2);
                $this->fail("Illegal pair $vehicleKind/$serviceType was accepted.");
            } catch (DomainException) {
                $this->assertTrue(true);
            }
        }
    }

    /** @return array<string,mixed> */
    private function jurisdiction(): array
    {
        return [
            'schemaVersion' => 2,
            'id' => 'co-g2-synthetic',
            'name' => 'SYNTHETIC_G2_ONLY',
            'coverages' => [[
                'vehicleKind' => 'truck',
                'serviceType' => 'public_cargo',
                'coverageCompleteness' => 'partial',
                'verifiedAt' => '2026-11-10T00:00:00Z',
                'staleAfter' => '2026-11-20T00:00:00Z',
                'sourceUrls' => ['https://example.test/synthetic'],
                'rules' => [[
                    'id' => 'synthetic-rule',
                    'priority' => 100,
                    'effect' => 'restrict',
                    'validFrom' => '2026-11-10T00:00:00Z',
                    'validUntil' => '2026-11-19T23:59:59Z',
                    'timeWindows' => [['startMinute' => 360, 'endMinute' => 480]],
                    'appliesOnHolidays' => false,
                    'sourceUrl' => 'https://example.test/synthetic',
                    'verifiedAt' => '2026-11-10T00:00:00Z',
                    'conditions' => [
                        ['type' => 'gross_weight_kg_gt', 'value' => 8500],
                        ['type' => 'inside_scope_ref', 'value' => 'zone-1@v2'],
                    ],
                ]],
            ]],
        ];
    }
}
