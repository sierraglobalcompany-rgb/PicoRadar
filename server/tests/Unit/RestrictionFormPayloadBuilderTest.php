<?php

namespace Tests\Unit;

use App\Models\Jurisdiction;
use App\Services\RestrictionFormPayloadBuilder;
use DomainException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class RestrictionFormPayloadBuilderTest extends TestCase
{
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
}
