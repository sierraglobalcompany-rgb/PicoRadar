<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Enums\OperatorRole;
use App\Models\AuditLog;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\DatasetAuditLogger;
use App\Services\GeographyImporter;
use App\Services\JurisdictionService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use LogicException;
use Tests\TestCase;

class GeographyJurisdictionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_dane_fixture_dry_run_is_complete_and_does_not_mutate_database(): void
    {
        $summary = app(GeographyImporter::class)->bootstrap(true);

        $this->assertSame(1, $summary['countries']);
        $this->assertSame(33, $summary['departments']);
        $this->assertSame(1104, $summary['municipalities']);
        $this->assertSame(15, $summary['jurisdictions']);
        $this->assertSame(288, $summary['registrationRecords']);
        $this->assertSame(276, $summary['exactMatches']);
        $this->assertSame(12, $summary['aliasMatches']);
        $this->assertSame(0, $summary['unmatched']);
        $this->assertSame(0, GeographicUnit::query()->count());
    }

    public function test_bootstrap_is_idempotent_and_preserves_canonical_hierarchy_and_audit_summary(): void
    {
        $first = app(GeographyImporter::class)->bootstrap();
        $counts = [GeographicUnit::query()->count(), Jurisdiction::query()->count(), DB::table('jurisdiction_geographic_unit')->count()];
        $second = app(GeographyImporter::class)->bootstrap();

        $this->assertSame($first, $second);
        $this->assertSame($counts, [GeographicUnit::query()->count(), Jurisdiction::query()->count(), DB::table('jurisdiction_geographic_unit')->count()]);
        $this->assertDatabaseHas('geographic_units', ['key' => 'co', 'code' => 'CO', 'level' => 'country']);
        $this->assertDatabaseHas('geographic_units', ['key' => 'co-05', 'code' => '05', 'level' => 'department']);
        $this->assertDatabaseHas('geographic_units', ['key' => 'co-05001', 'code' => '05001', 'level' => 'municipality']);
        $this->assertDatabaseHas('geographic_units', ['key' => 'co-11', 'code' => '11', 'level' => 'department']);
        $this->assertDatabaseHas('geographic_units', ['key' => 'co-11001', 'code' => '11001', 'level' => 'municipality']);
        $this->assertDatabaseHas('geographic_units', ['key' => 'co-76', 'code' => '76', 'level' => 'department']);
        $this->assertDatabaseHas('geographic_units', ['key' => 'co-76001', 'code' => '76001', 'level' => 'municipality']);
        $audit = AuditLog::query()->where('action', 'geography.bootstrapped')->latest('id')->firstOrFail();
        $this->assertSame(33, $audit->metadata['departmentCount']);
        $this->assertSame(1104, $audit->metadata['municipalityCount']);
        $this->assertSame(12, $audit->metadata['aliasMatches']);
    }

    public function test_alias_validation_is_explicit_and_fails_closed_for_unknown_codes_duplicates_and_unknown_cities(): void
    {
        $aliases = $this->fixture('registration_city_divipola_aliases_v1.json');
        $aliases['records'][0]['divipolaCode'] = '99999';
        $this->expectException(DomainException::class);
        $this->importer(aliasPath: $this->writeFixture($aliases))->bootstrap(true);
    }

    public function test_duplicate_alias_and_unknown_registration_city_fail_closed(): void
    {
        $aliases = $this->fixture('registration_city_divipola_aliases_v1.json');
        $aliases['records'][1] = $aliases['records'][0];
        try {
            $this->importer(aliasPath: $this->writeFixture($aliases))->bootstrap(true);
            $this->fail('Duplicate aliases were accepted.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        $catalog = $this->mobileFixture('catalogs/colombia_registration_cities_v1.json');
        $catalog['records'][] = ['municipality' => 'Municipio Inventado', 'department' => 'Departamento Inventado', 'displayName' => 'Inventado', 'source' => 'test'];
        $this->expectException(DomainException::class);
        $this->importer(registrationPath: $this->writeFixture($catalog))->bootstrap(true);
    }

    public function test_geography_structure_is_immutable_and_invalid_hierarchy_is_rejected(): void
    {
        $country = GeographicUnit::query()->create(['key' => 'co', 'code' => 'CO', 'level' => GeographicUnitLevel::Country, 'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'test', 'source_version' => 'v1']);
        $department = GeographicUnit::query()->create(['parent_id' => $country->id, 'key' => 'co-05', 'code' => '05', 'level' => GeographicUnitLevel::Department, 'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true, 'source_system' => 'test', 'source_version' => 'v1']);
        try {
            GeographicUnit::query()->create(['parent_id' => $department->id, 'key' => 'bad', 'code' => '99', 'level' => GeographicUnitLevel::Country, 'name' => 'Bad', 'normalized_name' => 'bad', 'is_active' => true, 'source_system' => 'test', 'source_version' => 'v1']);
            $this->fail('Invalid hierarchy was accepted.');
        } catch (LogicException) {
            $this->addToAssertionCount(1);
        }
        $department->key = 'co-99';
        $this->expectException(LogicException::class);
        $department->save();
    }

    public function test_bogota_and_valle_de_aburra_contracts_are_preserved(): void
    {
        app(GeographyImporter::class)->bootstrap();
        $bogota = Jurisdiction::query()->where('key', 'co-dc-bogota')->with('geographicUnits')->firstOrFail();
        $this->assertTrue($bogota->enabled);
        $this->assertSame('district', $bogota->kind->value);
        $this->assertSame('11001', $bogota->primaryGeographicUnit->code);
        $this->assertCount(1, $bogota->geographicUnits);
        $medellin = Jurisdiction::query()->where('key', 'co-ant-medellin')->with('geographicUnits')->firstOrFail();
        $this->assertTrue($medellin->enabled);
        $this->assertSame('05001', $medellin->primaryGeographicUnit->code);
        $this->assertSame(['05001', '05079', '05088', '05129', '05212', '05266', '05308', '05360', '05380', '05631'], $medellin->geographicUnits->pluck('code')->sort()->values()->all());
    }

    public function test_jurisdiction_coverage_and_key_invariants_fail_closed(): void
    {
        app(GeographyImporter::class)->bootstrap();
        $service = app(JurisdictionService::class);
        $primary = GeographicUnit::query()->where('code', '05001')->firstOrFail();
        $extra = GeographicUnit::query()->where('code', '05088')->firstOrFail();
        $jurisdiction = $service->create(['key' => 'co-ant-test', 'name' => 'Test', 'kind' => 'city', 'primary_geographic_unit_id' => $primary->id, 'enabled' => false, 'timezone' => 'America/Bogota'], [$primary->id]);
        $service->attachCoverage($jurisdiction, $extra);
        try {
            $service->attachCoverage($jurisdiction, $extra);
            $this->fail('Duplicate mapping was accepted.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        try {
            $service->detachCoverage($jurisdiction, $primary);
            $this->fail('Primary coverage was detached.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        $jurisdiction->key = 'co-ant-renamed';
        $this->expectException(LogicException::class);
        $jurisdiction->save();
    }

    public function test_admin_surfaces_enforce_roles_and_search_normalized_geography(): void
    {
        app(GeographyImporter::class)->bootstrap();
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);
        $this->actingAs($editor)->get('/admin/geography?q=medellin')->assertOk()->assertSee('MEDELLÍN');
        $this->actingAs($editor)->get('/admin/geography?q=05001')->assertOk()->assertSee('05001');
        $this->actingAs($reviewer)->get(route('admin.jurisdictions.index'))->assertOk();
        $this->actingAs($reviewer)->get(route('admin.jurisdictions.create'))->assertForbidden();
        $this->actingAs($commercial)->get(route('admin.geography.index'))->assertForbidden();
        $this->actingAs($commercial)->get(route('admin.jurisdictions.index'))->assertForbidden();
    }

    /** @return array<string,mixed> */
    private function fixture(string $name): array
    {
        return json_decode((string) file_get_contents(database_path("data/$name")), true, 512, JSON_THROW_ON_ERROR);
    }

    /** @return array<string,mixed> */
    private function mobileFixture(string $path): array
    {
        return json_decode((string) file_get_contents(base_path("../mobile/assets/$path")), true, 512, JSON_THROW_ON_ERROR);
    }

    /** @param array<string,mixed> $fixture */
    private function writeFixture(array $fixture): string
    {
        $path = tempnam(sys_get_temp_dir(), 'picoradar-geo-');
        file_put_contents($path, json_encode($fixture, JSON_THROW_ON_ERROR));

        return $path;
    }

    private function importer(?string $aliasPath = null, ?string $registrationPath = null): GeographyImporter
    {
        return new GeographyImporter(app(DatasetAuditLogger::class), app(JurisdictionService::class), null, $aliasPath, null, null, $registrationPath);
    }
}
