<?php

namespace Tests\Unit;

use App\Services\RestrictionContractValidator;
use DomainException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class RestrictionContractValidatorTest extends TestCase
{
    public function test_accepts_the_mobile_city_contract_and_summarizes_dates_and_vehicle_kinds(): void
    {
        $payload = $this->payload();
        $payload['coverages'][0]['rules'][0]['timeWindows'] = [['startMinute' => 1320, 'endMinute' => 300]];

        $summary = (new RestrictionContractValidator)->validateJurisdiction($payload, 'co-test-synthetic');

        $this->assertSame(['car'], $summary['vehicleKinds']);
        $this->assertSame('2026-09-01', $summary['validFrom']);
        $this->assertSame('2026-12-31', $summary['validUntil']);
        $this->assertSame('2027-01-15T05:00:00+00:00', $summary['staleAfter']);
        $this->assertSame('2026-09-01T05:00:00+00:00', $summary['sourceCheckedAt']);
    }

    #[DataProvider('invalidPayloads')]
    public function test_rejects_values_the_mobile_contract_cannot_safely_evaluate(callable $mutate, string $message): void
    {
        $payload = $this->payload();
        $mutate($payload);

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage($message);
        (new RestrictionContractValidator)->validateJurisdiction($payload, 'co-test-synthetic');
    }

    public static function invalidPayloads(): iterable
    {
        yield 'wrong jurisdiction' => [
            static function (array &$payload): void {
                $payload['id'] = 'co-other';
            },
            'Jurisdiction id does not match',
        ];
        yield 'inverted validity' => [
            static function (array &$payload): void {
                $payload['coverages'][0]['rules'][0]['validUntil'] = '2026-08-31T23:59:59Z';
            },
            'validUntil must not precede validFrom',
        ];
        yield 'digit without position' => [
            static function (array &$payload): void {
                unset($payload['coverages'][0]['rules'][0]['digitPosition']);
            },
            'digitPosition is required with digits',
        ];
        yield 'unsafe source' => [
            static function (array &$payload): void {
                $payload['coverages'][0]['rules'][0]['sourceUrl'] = 'http://example.test/rules';
            },
            'sourceUrl must be an HTTPS URL',
        ];
        yield 'same priority conflict' => [
            static function (array &$payload): void {
                $duplicate = $payload['coverages'][0]['rules'][0];
                $duplicate['id'] = 'synthetic-rule-2';
                $payload['coverages'][0]['rules'][] = $duplicate;
            },
            'Conflicting restriction rules share scope and priority',
        ];
    }

    /** @return array<string,mixed> */
    private function payload(): array
    {
        return [
            'id' => 'co-test-synthetic',
            'name' => 'Ciudad sintética',
            'coverages' => [[
                'vehicleKind' => 'car',
                'serviceType' => 'private',
                'verifiedAt' => '2026-09-01T05:00:00Z',
                'staleAfter' => '2027-01-15T05:00:00Z',
                'sourceUrls' => ['https://example.test/rules'],
                'rules' => [[
                    'id' => 'synthetic-rule-1',
                    'priority' => 100,
                    'effect' => 'restrict',
                    'validFrom' => '2026-09-01T00:00:00-05:00',
                    'validUntil' => '2026-12-31T23:59:59-05:00',
                    'weekdays' => [1],
                    'digitPosition' => 'lastNumeric',
                    'digits' => [1, 2],
                    'timeWindows' => [['startMinute' => 360, 'endMinute' => 1200]],
                    'appliesOnHolidays' => false,
                    'sourceUrl' => 'https://example.test/rules',
                    'verifiedAt' => '2026-09-01T05:00:00Z',
                ]],
            ]],
        ];
    }
}
