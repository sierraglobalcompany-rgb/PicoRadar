<?php

namespace Tests\Unit;

use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\RestrictionFormPayloadBuilder;
use DomainException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class RestrictionFormPayloadBuilderTest extends TestCase
{
    public function test_schema2_builder_accepts_the_nine_contract_pairs_and_preserves_typed_rule_fields(): void
    {
        $pairs = [
            'car|private', 'car|taxi', 'car|special', 'motorcycle|private',
            'truck|private', 'truck|public_cargo', 'bus|public_passenger',
            'bus|special', 'motocarro|private',
        ];
        $coverages = [];
        foreach ($pairs as $index => $pair) {
            $coverages[] = $this->schema2Coverage($pair, 'rule-'.$index, [
                'weekdays' => $index === 0 ? '1' : '2',
                'digits' => (string) ($index % 10),
                'time_windows' => $index === 0
                    ? "00:00-00:00 fullDay\n06:00-08:00"
                    : '06:00-20:00',
                'conditions_json' => $index === 0
                    ? '[{"type":"occupants_at_least","value":2}]'
                    : '[]',
            ]);
        }

        $jurisdiction = new Jurisdiction(['key' => 'synthetic-city', 'name' => 'Ciudad sintética']);
        $jurisdiction->setRelation('primaryGeographicUnit', new GeographicUnit(['code' => '05001']));
        $payload = (new RestrictionFormPayloadBuilder)->build(
            $jurisdiction,
            [
                'coverages' => $coverages,
                'municipality_codes' => '05001',
                'consultation_enabled' => '1',
            ],
            2,
        );

        $this->assertSame(2, $payload['schemaVersion']);
        $this->assertSame(['05001'], $payload['municipalityCodes']);
        $this->assertTrue($payload['consultationEnabled']);
        $this->assertSame($pairs, array_map(
            static fn (array $coverage): string => $coverage['vehicleKind'].'|'.$coverage['serviceType'],
            $payload['coverages'],
        ));
        $this->assertSame('partial', $payload['coverages'][0]['coverageCompleteness']);
        $this->assertTrue($payload['coverages'][0]['consultationEnabled']);
        $this->assertSame([
            ['startMinute' => 0, 'endMinute' => 0, 'fullDay' => true],
            ['startMinute' => 360, 'endMinute' => 480],
        ], $payload['coverages'][0]['rules'][0]['timeWindows']);
        $this->assertSame([
            ['type' => 'occupants_at_least', 'value' => 2],
        ], $payload['coverages'][0]['rules'][0]['conditions']);
    }

    public function test_schema2_builder_rejects_invalid_or_duplicate_pairs_and_more_than_nine_coverages(): void
    {
        $builder = new RestrictionFormPayloadBuilder;
        $jurisdiction = new Jurisdiction(['key' => 'synthetic-city', 'name' => 'Ciudad sintética']);
        $valid = $this->schema2Coverage('car|private', 'rule-one');

        try {
            $builder->build($jurisdiction, ['coverages' => [$this->schema2Coverage('car|public_cargo', 'bad')]], 2);
            $this->fail('An invalid schema2 vehicle/service pair was accepted.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('combinación de vehículo y servicio', $error->getMessage());
        }

        try {
            $builder->build($jurisdiction, ['coverages' => [$valid, $valid]], 2);
            $this->fail('A duplicate schema2 coverage pair was accepted.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('No repitas', $error->getMessage());
        }

        try {
            $builder->build($jurisdiction, ['coverages' => array_fill(0, 10, $valid)], 2);
            $this->fail('More than nine schema2 coverages were accepted.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('entre 1 y 9', $error->getMessage());
        }
    }

    public function test_schema2_builder_preserves_existing_conditions_when_a_post_omits_that_field(): void
    {
        $builder = new RestrictionFormPayloadBuilder;
        $jurisdiction = new Jurisdiction(['key' => 'synthetic-city', 'name' => 'Ciudad sintética']);
        $jurisdiction->setRelation('primaryGeographicUnit', new GeographicUnit(['code' => '05001']));
        $coverage = $this->schema2Coverage('car|private', 'preserve-conditions', [
            'conditions_json' => '[{"type":"occupants_at_least","value":2}]',
        ]);
        $input = [
            'coverages' => [$coverage],
            'consultation_enabled' => '1',
        ];
        $original = $builder->build($jurisdiction, $input, 2);
        unset($input['coverages'][0]['rules'][0]['conditions_json']);
        unset($input['consultation_enabled']);
        unset($input['consultation_enabled']);

        $updated = $builder->build($jurisdiction, $input, 2, $original);

        $this->assertSame($original['coverages'][0]['rules'][0]['conditions'], $updated['coverages'][0]['rules'][0]['conditions']);
        $this->assertSame(['05001'], $updated['municipalityCodes']);
        $this->assertTrue($updated['consultationEnabled']);
        $this->assertSame(['05001'], $updated['municipalityCodes']);
        $this->assertTrue($updated['consultationEnabled']);
    }

    public function test_schema2_builder_requires_a_full_day_marker_and_reports_invalid_condition_field(): void
    {
        $builder = new RestrictionFormPayloadBuilder;
        $jurisdiction = new Jurisdiction(['key' => 'synthetic-city', 'name' => 'Ciudad sintética']);
        $withoutMarker = $this->schema2Coverage('car|private', 'full-day');
        $withoutMarker['rules'][0]['time_windows'] = '08:00-08:00';

        try {
            $builder->build($jurisdiction, ['coverages' => [$withoutMarker]], 2);
            $this->fail('Equal start and end minutes were accepted without fullDay.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('fullDay', $error->getMessage());
        }

        $invalidCondition = $this->schema2Coverage('car|private', 'bad-condition');
        $invalidCondition['rules'][0]['conditions_json'] = '[{"type":"occupants_at_least","value":0}]';
        try {
            $builder->build($jurisdiction, ['coverages' => [$invalidCondition]], 2);
            $this->fail('An invalid typed condition was accepted by the editor builder.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('coverages.0.rules.0.conditions_json', $error->getMessage());
            $this->assertStringContainsString('occupants_at_least', $error->getMessage());
        }
    }

    public function test_it_builds_the_real_mobile_contract_from_human_fields(): void
    {
        $jurisdiction = new Jurisdiction(['key' => 'co-ant-medellin', 'name' => 'Medellín']);
        $payload = (new RestrictionFormPayloadBuilder)->build($jurisdiction, [
            'coverages' => [[
                'vehicle_kind' => 'car',
                'service_type' => 'private',
                'verified_at' => '2026-09-20T08:00',
                'stale_after' => '2026-10-01T00:00',
                'source_urls' => "https://example.test/decreto\nhttps://example.test/calendario",
                'rules' => [[
                    'id' => 'medellin-car-test',
                    'priority' => '1000',
                    'effect' => 'restrict',
                    'valid_from' => '2026-09-21T00:00',
                    'valid_until' => '2026-12-31T23:59',
                    'weekdays' => '1, 3, 5',
                    'date_parity' => '',
                    'digit_position' => 'lastNumeric',
                    'digits' => '0, 2, 4, 6, 8',
                    'time_windows' => "05:00-20:00\n22:00-23:30",
                    'applies_on_holidays' => '0',
                    'source_url' => 'https://example.test/decreto',
                    'verified_at' => '2026-09-20T08:00',
                ]],
            ]],
        ]);

        $this->assertSame('co-ant-medellin', $payload['id']);
        $this->assertSame('Medellín', $payload['name']);
        $coverage = $payload['coverages'][0];
        $this->assertSame(['https://example.test/decreto', 'https://example.test/calendario'], $coverage['sourceUrls']);
        $rule = $coverage['rules'][0];
        $this->assertSame([1, 3, 5], $rule['weekdays']);
        $this->assertSame([0, 2, 4, 6, 8], $rule['digits']);
        $this->assertSame([
            ['startMinute' => 300, 'endMinute' => 1200],
            ['startMinute' => 1320, 'endMinute' => 1410],
        ], $rule['timeWindows']);
        $this->assertFalse($rule['appliesOnHolidays']);
        $this->assertStringContainsString('-05:00', $rule['validFrom']);
    }

    public function test_schema2_toggle_changes_one_modality_without_dropping_rules_or_completeness(): void
    {
        $builder = new RestrictionFormPayloadBuilder;
        $jurisdiction = new Jurisdiction(['key' => 'synthetic-city', 'name' => 'Ciudad sintética']);
        $jurisdiction->setRelation('primaryGeographicUnit', new GeographicUnit(['code' => '05001']));
        $car = $this->schema2Coverage('car|private', 'car-rule');
        $taxi = $this->schema2Coverage('car|taxi', 'taxi-rule');
        $active = $builder->build($jurisdiction, ['coverages' => [$car, $taxi]], 2);
        $taxi['consultation_enabled_present'] = '1';
        $paused = $builder->build($jurisdiction, ['coverages' => [$car, $taxi]], 2, $active);

        $this->assertSame($active['coverages'][0], $paused['coverages'][0], 'Unrelated modality must not change.');
        $this->assertSame('taxi', $paused['coverages'][1]['serviceType']);
        $this->assertFalse($paused['coverages'][1]['consultationEnabled']);
        $this->assertSame('partial', $paused['coverages'][1]['coverageCompleteness']);
        $this->assertSame($active['coverages'][1]['rules'], $paused['coverages'][1]['rules']);

        $taxi['consultation_enabled'] = '1';
        $resumed = $builder->build($jurisdiction, ['coverages' => [$car, $taxi]], 2, $paused);
        $this->assertTrue($resumed['coverages'][1]['consultationEnabled']);
        $this->assertSame($active['coverages'][1]['rules'], $resumed['coverages'][1]['rules']);
    }

    public function test_schema2_toggle_preserves_an_existing_off_value_when_form_omits_it(): void
    {
        $builder = new RestrictionFormPayloadBuilder;
        $jurisdiction = new Jurisdiction(['key' => 'synthetic-city', 'name' => 'Ciudad sintética']);
        $coverage = $this->schema2Coverage('car|private', 'car-rule');
        $coverage['consultation_enabled_present'] = '1';
        $original = $builder->build($jurisdiction, ['coverages' => [$coverage]], 2);
        unset($coverage['consultation_enabled_present']);

        $updated = $builder->build($jurisdiction, ['coverages' => [$coverage]], 2, [
            ...$original,
            'coverages' => [[...$original['coverages'][0], 'consultationEnabled' => false]],
        ]);

        $this->assertFalse($updated['coverages'][0]['consultationEnabled']);
        $this->assertSame($original['coverages'][0]['rules'], $updated['coverages'][0]['rules']);
    }

    public function test_schema2_toggle_rejects_non_boolean_contract_values(): void
    {
        $coverage = $this->schema2Coverage('car|private', 'car-rule');
        $coverage['consultationEnabled'] = 'false';
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('debe ser booleana');
        (new RestrictionFormPayloadBuilder)->build(
            new Jurisdiction(['key' => 'synthetic-city', 'name' => 'Ciudad sintética']),
            ['coverages' => [$coverage]],
            2,
        );
    }

    #[DataProvider('invalidInputs')]
    public function test_it_rejects_ambiguous_or_unsafe_human_fields(array $data, string $message): void
    {
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage($message);

        (new RestrictionFormPayloadBuilder)->build(
            new Jurisdiction(['key' => 'synthetic-city', 'name' => 'Ciudad sintética']),
            $data,
        );
    }

    public static function invalidInputs(): array
    {
        $base = [
            'coverages' => [[
                'vehicle_kind' => 'car',
                'service_type' => 'private',
                'verified_at' => '2026-09-20T08:00',
                'stale_after' => '2026-10-01T00:00',
                'source_urls' => 'https://example.test/source',
                'rules' => [[
                    'id' => 'rule-1',
                    'priority' => '1000',
                    'effect' => 'restrict',
                    'valid_from' => '2026-09-21T00:00',
                    'weekdays' => '1',
                    'digit_position' => 'lastNumeric',
                    'digits' => '1,2',
                    'time_windows' => '06:00-20:00',
                    'applies_on_holidays' => '0',
                    'source_url' => 'https://example.test/source',
                    'verified_at' => '2026-09-20T08:00',
                ]],
            ]],
        ];

        $badWindow = $base;
        $badWindow['coverages'][0]['rules'][0]['time_windows'] = '20:00 a 06:00';
        $badUrl = $base;
        $badUrl['coverages'][0]['source_urls'] = 'http://insecure.example.test';
        $badDigits = $base;
        $badDigits['coverages'][0]['rules'][0]['digits'] = '1,11';

        return [
            'ambiguous schedule' => [$badWindow, 'Horario inválido'],
            'insecure source' => [$badUrl, 'HTTPS'],
            'invalid digit' => [$badDigits, 'Dígito inválido'],
        ];
    }

    /** @param array<string,string> $overrides @return array<string,mixed> */
    private function schema2Coverage(string $pair, string $ruleId, array $overrides = []): array
    {
        return [
            'pair' => $pair,
            'verified_at' => '2026-11-16T08:00',
            'stale_after' => '2026-12-01T00:00',
            'source_urls' => 'https://example.test/restrictions',
            'rules' => [[
                'id' => $ruleId,
                'priority' => '1000',
                'effect' => 'restrict',
                'valid_from' => '2026-11-16T00:00',
                'valid_until' => '2026-11-30T23:59',
                'weekdays' => '1,2',
                'date_parity' => '',
                'digit_position' => 'lastNumeric',
                'digits' => '1,2',
                'time_windows' => '06:00-20:00',
                'applies_on_holidays' => '0',
                'source_url' => 'https://example.test/restrictions',
                'verified_at' => '2026-11-16T08:00',
                'registration_origins' => '',
                'conditions_json' => '[]',
                ...$overrides,
            ]],
        ];
    }
}
