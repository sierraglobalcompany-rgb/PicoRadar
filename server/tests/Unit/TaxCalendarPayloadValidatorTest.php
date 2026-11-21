<?php

namespace Tests\Unit;

use App\Services\TaxCalendarPayloadValidator;
use DomainException;
use Illuminate\Support\Arr;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Tests\Fixtures\TaxCalendarPayload;

class TaxCalendarPayloadValidatorTest extends TestCase
{
    #[DataProvider('invalidPayloads')]
    public function test_rejects_invalid_frozen_contract_payload(array $payload): void
    {
        $this->expectException(DomainException::class);
        (new TaxCalendarPayloadValidator)->validate($payload);
    }

    public static function invalidPayloads(): iterable
    {
        $values = [
            'schemaVersion' => [2, '1'],
            'datasetKey' => ['restrictions', ''],
            'version' => ['', 1],
            'generatedAt' => ['tomorrow', '2026-02-30T00:00:00Z', '2026-09-13T12:00:00', '2026-09-13T24:00:00Z', '2026-09-13T12:00:00+24:00'],
            'authorities' => [null, ['entry' => []]],
            'authorities.0' => ['invalid', []],
            'authorities.0.id' => ['', 1],
            'authorities.0.territoryCode' => [11, '1', '110', 'AA'],
            'authorities.0.territoryName' => [''],
            'authorities.0.name' => [''],
            'authorities.0.reviewedAt' => ['2026-02-29T00:00:00Z', '2026-01-01'],
            'authorities.0.sourceUrls' => [[], null, 'https://hacienda.example.org/'],
            'calendars' => [null, ['entry' => []]],
            'calendars.0' => ['invalid', []],
            'calendars.0.id' => [''],
            'calendars.0.authorityId' => ['missing', ''],
            'calendars.0.year' => ['2026', 2026.5, 0, -1, 10000],
            'calendars.0.obligationKind' => ['income_tax', 'debt_relief'],
            'calendars.0.status' => ['unknown', 'pending', 'withdrawn'],
            'calendars.0.reviewedAt' => [null, '2026-13-01T00:00:00Z'],
            'calendars.0.reviewAfter' => ['tomorrow', '2026-09-13T12:61:00Z'],
            'calendars.0.sourceUrls' => [[], null, ['url' => 'https://hacienda.example.org/']],
            'calendars.0.events' => [null, ['entry' => []]],
            'calendars.0.events.0' => ['invalid', []],
            'calendars.0.events.0.id' => ['', false],
            'calendars.0.events.0.date' => ['2026-02-29', '2026-02-30', '2026-04-31', '2026-00-01', '2026-01-00', '0000-01-01', '2026-1-01', '2026-10-30T00:00:00Z', '2025-10-30', '2027-01-01', '2028-01-01', '2026-10-30 '],
            'calendars.0.events.0.label' => ['', null],
            'calendars.0.events.0.kind' => ['unknown', 'debtRelief', 'installment', 'installmentEnrollment'],
            'calendars.0.events.0.condition' => [['formula' => 'amount * 0.1'], true, '   '],
            'calendars.0.events.0.status' => ['unknown', 'superseded'],
            'calendars.0.events.0.supersededBy' => ['missing', 'ordinary', false, ''],
            'calendars.0.events.0.sourceUrls' => [[], null, ['url' => 'https://hacienda.example.org/']],
        ];
        foreach ($values as $path => $invalidValues) {
            foreach ($invalidValues as $index => $value) {
                $payload = TaxCalendarPayload::valid();
                Arr::set($payload, $path, $value);
                yield "$path invalid $index" => [$payload];
            }
        }

        foreach (['schemaVersion', 'datasetKey', 'version', 'generatedAt', 'authorities', 'calendars',
            'authorities.0.id', 'authorities.0.territoryCode', 'authorities.0.territoryName', 'authorities.0.name', 'authorities.0.sourceUrls',
            'calendars.0.id', 'calendars.0.authorityId', 'calendars.0.year', 'calendars.0.obligationKind', 'calendars.0.status', 'calendars.0.sourceUrls', 'calendars.0.events',
            'calendars.0.events.0.id', 'calendars.0.events.0.date', 'calendars.0.events.0.label', 'calendars.0.events.0.kind', 'calendars.0.events.0.status', 'calendars.0.events.0.sourceUrls'] as $path) {
            $payload = TaxCalendarPayload::valid();
            Arr::forget($payload, $path);
            yield "$path missing" => [$payload];
        }

        foreach (['authorities', 'calendars', 'calendars.0.events'] as $path) {
            $payload = TaxCalendarPayload::valid();
            Arr::set($payload, "$path.1", Arr::get($payload, "$path.0"));
            yield "$path duplicate id" => [$payload];
        }
        $payload = TaxCalendarPayload::valid();
        $payload['authorities'][] = array_replace($payload['authorities'][0], ['id' => 'another']);
        yield 'duplicate territory under another authority' => [$payload];
        $payload = TaxCalendarPayload::valid();
        $payload['calendars'][] = array_replace($payload['calendars'][0], ['id' => 'another']);
        yield 'duplicate calendar key under another id' => [$payload];

        $payload = TaxCalendarPayload::valid();
        $payload['calendars'][0]['events'][0]['status'] = 'superseded';
        $payload['calendars'][0]['events'][0]['supersededBy'] = 'missing';
        yield 'missing replacement' => [$payload];
        $payload['calendars'][0]['events'][0]['supersededBy'] = 'ordinary';
        yield 'self replacement' => [$payload];
        $payload['calendars'][0]['events'][0]['supersededBy'] = 'extension';
        $payload['calendars'][0]['events'][] = array_replace($payload['calendars'][0]['events'][0], ['id' => 'extension', 'supersededBy' => 'ordinary']);
        yield 'supersession cycle' => [$payload];
        $payload = TaxCalendarPayload::valid();
        $payload['calendars'][0]['events'][0]['date'] = '2028-01-01';
        $payload['calendars'][0]['events'][0]['condition'] = 'Explicit condition';
        yield 'condition cannot move event two tax years' => [$payload];
    }

    #[DataProvider('unsafeUrls')]
    public function test_rejects_unsafe_urls_at_every_tax_link_surface(string $url): void
    {
        foreach (['authorities.0.institutionalUrl', 'authorities.0.portalUrl', 'authorities.0.sourceUrls.0', 'calendars.0.sourceUrls.0', 'calendars.0.events.0.sourceUrls.0'] as $path) {
            $payload = TaxCalendarPayload::valid();
            Arr::set($payload, $path, $url);
            try {
                (new TaxCalendarPayloadValidator)->validate($payload);
                $this->fail("Unsafe URL accepted at $path.");
            } catch (DomainException $exception) {
                $this->assertStringNotContainsString($url, $exception->getMessage());
            }
        }
    }

    public static function unsafeUrls(): iterable
    {
        foreach (['http://hacienda.example.org/', 'javascript:alert(1)', '//hacienda.example.org/',
            'https://user:secret@hacienda.example.org/', 'https://@hacienda.example.org/',
            'https://127.0.0.1/', 'https://8.8.8.8/', 'https://[::1]/', 'https://2130706433/', 'https://0x7f.0.0.1/',
            'https://localhost/', 'https://api.localhost/', 'https://hacienda.local/', 'https://hacienda.internal/', 'https://hacienda.test/',
            'https://hacienda/', 'https://hacienda.example.org./', 'https://bad_host.example.org/',
            ' https://hacienda.example.org/', "https://hacienda.example.org/\n", 'https://hacienda.example.org\\@localhost/',
            'https://hacienda.example.org/?placa=ABC123', 'https://hacienda.example.org/?CEDULA=123456',
            'https://hacienda.example.org/?%70laca=ABC123', 'https://hacienda.example.org/?owner[documento]=123456',
            'https://hacienda.example.org/?license_plate=ABC123', 'https://hacienda.example.org/?email=owner%40example.org',
            'https://hacienda.example.org/?access_token=secret', 'https://hacienda.example.org/?year=2026;cedula=123456',
            'https://hacienda.example.org/?nit=123456', 'https://hacienda.example.org/?doc=123456'] as $index => $url) {
            yield "unsafe URL $index" => [$url];
        }
    }

    #[DataProvider('validPayloads')]
    public function test_accepts_supported_calendar_states_and_additive_fields(array $payload): void
    {
        (new TaxCalendarPayloadValidator)->validate($payload);
        $this->addToAssertionCount(1);
    }

    public static function validPayloads(): iterable
    {
        yield 'partial fixture' => [TaxCalendarPayload::valid()];
        $payload = TaxCalendarPayload::valid();
        $payload['calendars'][0]['status'] = 'verified';
        $payload['calendars'][0]['year'] = 2028;
        $payload['calendars'][0]['events'][0]['date'] = '2028-02-29';
        yield 'future tax year and real leap date' => [$payload];

        foreach (['discount', 'ordinary', 'installmentEnrollment', 'installment'] as $kind) {
            $payload = TaxCalendarPayload::valid();
            $payload['calendars'][0]['events'][0]['kind'] = $kind;
            $payload['calendars'][0]['events'][0]['condition'] = 'Only for enrolled participants';
            $payload['calendars'][0]['events'][0]['date'] = '2027-01-15';
            yield "$kind with explicit next-year condition" => [$payload];
        }
        foreach (['pending', 'withdrawn'] as $status) {
            $payload = TaxCalendarPayload::valid();
            $payload['authorities'][0]['portalUrl'] = null;
            $payload['authorities'][0]['institutionalUrl'] = null;
            $payload['authorities'][0]['reviewedAt'] = null;
            $payload['calendars'][0]['status'] = $status;
            $payload['calendars'][0]['reviewedAt'] = null;
            $payload['calendars'][0]['reviewAfter'] = null;
            $payload['calendars'][0]['sourceUrls'] = [];
            $payload['calendars'][0]['events'] = [];
            yield "$status without confirmed dates or portal" => [$payload];
            $payload['calendars'][0]['events'] = [array_replace(TaxCalendarPayload::valid()['calendars'][0]['events'][0], ['status' => 'withdrawn'])];
            yield "$status with sourced withdrawn history" => [$payload];
        }

        $payload = TaxCalendarPayload::valid();
        $payload['calendars'][0]['events'][0]['status'] = 'superseded';
        $payload['calendars'][0]['events'][0]['supersededBy'] = 'extension';
        $payload['calendars'][0]['events'][] = array_replace(TaxCalendarPayload::valid()['calendars'][0]['events'][0], ['id' => 'extension']);
        yield 'sourced replacement history and same-day distinct ids' => [$payload];
        $payload['calendars'][0]['events'][1]['status'] = 'superseded';
        $payload['calendars'][0]['events'][1]['supersededBy'] = 'final';
        $payload['calendars'][0]['events'][] = array_replace(TaxCalendarPayload::valid()['calendars'][0]['events'][0], ['id' => 'final', 'status' => 'withdrawn']);
        yield 'replacement chain ending with withdrawal' => [$payload];

        $payload = TaxCalendarPayload::valid();
        foreach (['semaforizacion', 'sistematizacion'] as $kind) {
            $payload['calendars'][] = array_replace($payload['calendars'][0], ['id' => $kind, 'obligationKind' => $kind]);
        }
        $payload['authorities'][] = array_replace($payload['authorities'][0], ['id' => 'antioquia', 'territoryCode' => '05']);
        $payload['futureMetadata'] = ['edition' => 'test'];
        $payload['authorities'][0]['futureMetadata'] = true;
        $payload['calendars'][0]['futureMetadata'] = true;
        $payload['calendars'][0]['events'][0]['futureMetadata'] = true;
        $payload['authorities'][0]['portalUrl'] = 'https://portal.example.org/index.php?page=vehiculos&year=2026&id=42&template=calendar&province=antioquia#calendario';
        yield 'separate obligations reused event ids stable authority aliases safe query and additive fields' => [$payload];
    }
}
