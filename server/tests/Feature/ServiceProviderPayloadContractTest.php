<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Models\GeographicUnit;
use App\Models\ServiceProvider;
use App\Services\DatasetAuditLogger;
use App\Services\MobileCatalogPayloadValidator;
use App\Services\ServiceProviderCatalogService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class ServiceProviderPayloadContractTest extends TestCase
{
    use RefreshDatabase;

    public function test_catalog_projects_one_sorted_schema_v1_payload_with_geographic_names_and_stable_ids(): void
    {
        $this->createGeography();
        $asOf = Carbon::parse('2026-11-22 12:00:00', config('app.timezone'));
        $this->createProvider('Zeta sintético', 'published', '2026-11-23', 'mailto:private@example.test');
        $this->createProvider('Alpha sintético', 'published', '2026-11-23');
        $this->createProvider('Borrador sintético', 'draft', '2026-11-23');
        $this->createProvider('Vencido sintético', 'published', '2026-11-21');

        $payload = $this->catalog()->publishedDatasetPayload('2026.11.22-test', $asOf);
        (new MobileCatalogPayloadValidator)->validate($payload, ServiceProvider::DATASET_KEY);

        $this->assertSame(1, $payload['schemaVersion']);
        $this->assertSame('service_providers', $payload['datasetKey']);
        $this->assertSame('2026.11.22-test', $payload['version']);
        $this->assertSame(['Alpha sintético', 'Zeta sintético'], array_column($payload['providers'], 'name'));
        $this->assertSame(['sp-2', 'sp-1'], array_column($payload['providers'], 'id'));
        $this->assertSame(['Departamento sintético', 'Departamento sintético'], array_column($payload['providers'], 'department'));
        $this->assertSame(['Municipio sintético', 'Municipio sintético'], array_column($payload['providers'], 'municipality'));
        $this->assertNull($payload['providers'][1]['contactUrl']);
        $this->assertArrayNotHasKey('phone', $payload['providers'][1]);
        $this->assertSame($payload, $this->catalog()->publishedDatasetPayload('2026.11.22-test', $asOf));
    }

    public function test_empty_catalog_is_a_valid_snapshot_without_invented_provider_records(): void
    {
        $payload = $this->catalog()->publishedDatasetPayload('preview', Carbon::parse('2026-11-22T12:00:00Z'));

        (new MobileCatalogPayloadValidator)->validate($payload, ServiceProvider::DATASET_KEY);

        $this->assertSame([], $payload['providers']);
    }

    public function test_payload_validity_date_uses_the_colombian_calendar_day(): void
    {
        $this->createGeography();
        $payload = $this->payload();
        $payload['generatedAt'] = '2026-11-22T04:30:00Z';
        $payload['providers'][0]['verifiedAt'] = '2026-11-22T04:00:00Z';
        $payload['providers'][0]['validUntil'] = '2026-11-21';

        (new MobileCatalogPayloadValidator)->validate($payload, ServiceProvider::DATASET_KEY);

        $this->addToAssertionCount(1);
    }

    public function test_payload_rejects_invalid_identity_category_dates_coordinates_urls_extra_fields_and_order(): void
    {
        $this->createGeography();
        $base = $this->payload();
        $invalid = [];

        $case = $base;
        $case['providers'][0]['id'] = 'provider-1';
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['category'] = 'unknown';
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['sourceUrl'] = 'http://source.example.test/';
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['validUntil'] = '2026-11-21';
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['verifiedAt'] = '2026-11-22T13:00:00Z';
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['latitude'] = 6.25;
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['latitude'] = 14.1;
        $case['providers'][0]['longitude'] = -75.5;
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['contactUrl'] = 'https://contact.example.test:8443/';
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['phone'] = '+573001112233';
        $invalid[] = $case;
        $case = $base;
        $case['providers'][0]['departmentCode'] = '99';
        $case['providers'][0]['department'] = 'Otro departamento';
        $invalid[] = $case;

        $this->createProvider('B sintético', 'draft', '2026-11-23');
        $second = $base['providers'][0];
        $second['id'] = 'sp-2';
        $second['name'] = 'A sintético';
        $case = $base;
        $case['providers'][] = $second;
        $invalid[] = $case;
        $case = $base;
        $case['providers'][] = $base['providers'][0];
        $invalid[] = $case;

        foreach ($invalid as $payload) {
            $this->assertRejected($payload);
        }
    }

    public function test_payload_rejects_a_municipality_whose_parent_is_not_the_declared_department(): void
    {
        $this->createGeography();
        $otherDepartment = GeographicUnit::query()->create([
            'parent_id' => GeographicUnit::query()->where('level', GeographicUnitLevel::Country->value)->value('id'),
            'key' => 'co-99-test',
            'level' => GeographicUnitLevel::Department,
            'code' => '99',
            'name' => 'Otro departamento',
            'normalized_name' => 'otro departamento',
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'v1',
        ]);
        GeographicUnit::query()->create([
            'parent_id' => $otherDepartment->id,
            'key' => 'co-99001-test',
            'level' => GeographicUnitLevel::Municipality,
            'code' => '99001',
            'name' => 'Municipio del otro departamento',
            'normalized_name' => 'municipio del otro departamento',
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'v1',
        ]);
        $payload = $this->payload();
        $payload['providers'][0]['municipalityCode'] = '99001';
        $payload['providers'][0]['municipality'] = 'Municipio del otro departamento';

        $this->assertRejected($payload);
    }

    /** @return array<string,mixed> */
    private function payload(): array
    {
        return [
            'schemaVersion' => 1,
            'datasetKey' => ServiceProvider::DATASET_KEY,
            'version' => '2026.11.22-test',
            'generatedAt' => '2026-11-22T12:00:00Z',
            'providers' => [[
                'id' => 'sp-1',
                'category' => 'cda',
                'departmentCode' => '05',
                'department' => 'Departamento sintético',
                'municipalityCode' => '05001',
                'municipality' => 'Municipio sintético',
                'name' => 'Proveedor sintético',
                'address' => null,
                'latitude' => 6.25184,
                'longitude' => -75.56359,
                'contactUrl' => 'https://contact.example.test/',
                'sourceUrl' => 'https://source.example.test/providers/1',
                'verifiedAt' => '2026-11-22T11:00:00Z',
                'validUntil' => '2026-11-23',
            ]],
        ];
    }

    private function createGeography(): void
    {
        $country = GeographicUnit::query()->create([
            'key' => 'co-test',
            'level' => GeographicUnitLevel::Country,
            'code' => 'CO',
            'name' => 'Colombia',
            'normalized_name' => 'colombia',
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'v1',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id,
            'key' => 'co-05-test',
            'level' => GeographicUnitLevel::Department,
            'code' => '05',
            'name' => 'Departamento sintético',
            'normalized_name' => 'departamento sintetico',
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'v1',
        ]);
        GeographicUnit::query()->create([
            'parent_id' => $department->id,
            'key' => 'co-05001-test',
            'level' => GeographicUnitLevel::Municipality,
            'code' => '05001',
            'name' => 'Municipio sintético',
            'normalized_name' => 'municipio sintetico',
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'v1',
        ]);
    }

    private function createProvider(string $name, string $status, string $validUntil, ?string $contactUrl = null): ServiceProvider
    {
        return ServiceProvider::query()->create([
            'category' => 'cda',
            'department_code' => '05',
            'municipality_code' => '05001',
            'name' => $name,
            'contact_url' => $contactUrl,
            'source_url' => 'https://source.example.test/providers/1',
            'verified_at' => '2026-11-22 11:00:00',
            'valid_until' => $validUntil,
            'status' => $status,
        ]);
    }

    private function catalog(): ServiceProviderCatalogService
    {
        return new ServiceProviderCatalogService(new DatasetAuditLogger);
    }

    /** @param array<string,mixed> $payload */
    private function assertRejected(array $payload): void
    {
        try {
            (new MobileCatalogPayloadValidator)->validate($payload, ServiceProvider::DATASET_KEY);
            $this->fail('Invalid service_providers payload was accepted.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
    }
}
