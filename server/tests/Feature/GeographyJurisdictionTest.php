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

    public function test_wrong_department_alias_and_ambiguous_canonical_pair_fail_during_dry_run_without_mutation(): void
    {
        $aliases = $this->fixture('registration_city_divipola_aliases_v1.json');
        $aliases['records'][11]['sourceDepartmentDivipolaCode'] = '05';
        try {
            $this->importer(aliasPath: $this->writeFixture($aliases))->bootstrap(true);
            $this->fail('Wrong-department alias was accepted.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        $dane = $this->fixture('colombia_divipola_mgn_2025.json');
        $duplicate = $dane['municipalities'][0];
        $duplicate['code'] = '99998';
        $dane['municipalities'][] = $duplicate;
        try {
            $this->importer(fixturePath: $this->writeFixture($dane))->bootstrap(true);
            $this->fail('Ambiguous canonical pair was accepted.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        $this->assertSame(0, GeographicUnit::query()->count());
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

    public function test_service_enforces_municipality_only_coverage_exact_sync_atomic_primary_changes_and_accurate_audits(): void
    {
        app(GeographyImporter::class)->bootstrap();
        $service = app(JurisdictionService::class);
        $municipalityA = GeographicUnit::query()->where('code', '05001')->firstOrFail();
        $municipalityB = GeographicUnit::query()->where('code', '05088')->firstOrFail();
        $municipalityX = GeographicUnit::query()->where('code', '05079')->firstOrFail();
        $municipalityY = GeographicUnit::query()->where('code', '05129')->firstOrFail();
        $department = GeographicUnit::query()->where('code', '05')->firstOrFail();
        $country = GeographicUnit::query()->where('code', 'CO')->firstOrFail();
        $jurisdiction = $service->create(['key' => 'co-ant-sync-test', 'name' => 'Sync test', 'kind' => 'city', 'primary_geographic_unit_id' => $municipalityA->id, 'enabled' => false, 'timezone' => 'America/Bogota'], [$municipalityA->id]);
        $service->attachCoverage($jurisdiction, $municipalityX);
        foreach ([$department, $country] as $nonMunicipality) {
            try {
                $service->attachCoverage($jurisdiction, $nonMunicipality);
                $this->fail('Non-municipality coverage was accepted.');
            } catch (DomainException) {
                $this->addToAssertionCount(1);
            }
            try {
                $service->create(['key' => 'co-invalid-'.$nonMunicipality->code, 'name' => 'Invalid', 'kind' => 'city', 'primary_geographic_unit_id' => $nonMunicipality->id, 'enabled' => false, 'timezone' => 'America/Bogota'], [$nonMunicipality->id]);
                $this->fail('Non-municipality primary was accepted.');
            } catch (DomainException) {
                $this->addToAssertionCount(1);
            }
        }
        $service->setCoverage($jurisdiction, [$municipalityA->id]);
        $this->assertSame([$municipalityA->id], $jurisdiction->fresh()->geographicUnits()->pluck('geographic_unit_id')->all());
        $service->syncFromCanonicalMapping($jurisdiction, ['primary_geographic_unit_id' => $municipalityB->id, 'name' => 'Sync test updated'], [$municipalityB->id, $municipalityY->id]);
        $jurisdiction = $jurisdiction->fresh();
        $this->assertSame($municipalityB->id, $jurisdiction->primary_geographic_unit_id);
        $this->assertSame([$municipalityB->id, $municipalityY->id], $jurisdiction->geographicUnits()->orderBy('geographic_unit_id')->pluck('geographic_unit_id')->all());
        $auditCount = AuditLog::query()->count();
        try {
            $service->detachCoverage($jurisdiction, $municipalityX);
            $this->fail('Missing coverage detach was accepted.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        $this->assertSame($auditCount, AuditLog::query()->count());
        $beforeIdempotent = AuditLog::query()->whereIn('action', ['jurisdiction.coverage_attached', 'jurisdiction.coverage_detached'])->count();
        $service->syncFromCanonicalMapping($jurisdiction, ['primary_geographic_unit_id' => $municipalityB->id, 'name' => 'Sync test updated'], [$municipalityB->id, $municipalityY->id]);
        $this->assertSame($beforeIdempotent, AuditLog::query()->whereIn('action', ['jurisdiction.coverage_attached', 'jurisdiction.coverage_detached'])->count());
    }

    public function test_pico_mapping_contract_reconciles_every_mobile_key_and_preserves_metadata_and_enabled_state(): void
    {
        app(GeographyImporter::class)->bootstrap();
        $mobile = $this->mobileFixture('catalogs/pico_jurisdiction_catalog_v1.json');
        $server = Jurisdiction::query()->orderBy('key')->get()->keyBy('key');
        $this->assertCount(15, $server);
        $this->assertSame(collect($mobile['records'])->pluck('id')->sort()->values()->all(), $server->keys()->sort()->values()->all());
        foreach ($mobile['records'] as $record) {
            $jurisdiction = $server[$record['id']];
            $this->assertSame($record['classification'], $jurisdiction->metadata['picoClassification']);
            $this->assertSame($record['sourceDate'], $jurisdiction->metadata['sourceDate']);
            $this->assertSame($record['classification'] === 'SUPPORTED_CURRENT', $jurisdiction->enabled);
        }
    }

    public function test_bootstrap_rolls_back_everything_when_a_failure_occurs_after_geography_import(): void
    {
        $importer = $this->importer(failureHook: static function (): void {
            throw new DomainException('Injected bootstrap failure.');
        });
        try {
            $importer->bootstrap();
            $this->fail('Injected bootstrap failure was accepted.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        $this->assertSame(0, GeographicUnit::query()->count());
        $this->assertSame(0, Jurisdiction::query()->count());
        $this->assertSame(0, DB::table('jurisdiction_geographic_unit')->count());
        $this->assertSame(0, AuditLog::query()->count());
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

    public function test_authorization_matrix_covers_editor_reviewer_commercial_admin_and_super_admin_http_operations(): void
    {
        app(GeographyImporter::class)->bootstrap();
        $primary = GeographicUnit::query()->where('code', '05001')->firstOrFail();
        $extra = GeographicUnit::query()->where('code', '05088')->firstOrFail();
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);
        foreach ([OperatorRole::Admin, OperatorRole::SuperAdmin] as $role) {
            $operator = User::factory()->create(['role' => $role, 'is_active' => true]);
            $this->actingAs($operator)->get(route('admin.geography.index'))->assertOk();
            $this->actingAs($operator)->get(route('admin.jurisdictions.index'))->assertOk();
            $this->actingAs($operator)->get(route('admin.jurisdictions.create'))->assertOk();
        }
        $this->actingAs($editor)->get(route('admin.geography.index'))->assertOk();
        $this->actingAs($editor)->get(route('admin.jurisdictions.index'))->assertOk();
        $response = $this->actingAs($editor)->post(route('admin.jurisdictions.store'), ['key' => 'co-ant-editor-test', 'name' => 'Editor test', 'kind' => 'city', 'enabled' => '1', 'timezone' => 'America/Bogota', 'primary_geographic_unit_id' => $primary->id]);
        $response->assertRedirect();
        $jurisdiction = Jurisdiction::query()->where('key', 'co-ant-editor-test')->firstOrFail();
        $this->actingAs($editor)->put(route('admin.jurisdictions.update', $jurisdiction), ['name' => 'Editor test updated', 'kind' => 'city', 'enabled' => '1', 'timezone' => 'America/Bogota', 'primary_geographic_unit_id' => $primary->id])->assertRedirect();
        $this->actingAs($editor)->post(route('admin.jurisdictions.coverage.attach', $jurisdiction), ['geographic_unit_id' => $extra->id])->assertRedirect();
        $this->actingAs($editor)->delete(route('admin.jurisdictions.coverage.detach', [$jurisdiction, $extra]))->assertRedirect();
        $this->actingAs($reviewer)->get(route('admin.geography.index'))->assertOk();
        $this->actingAs($reviewer)->get(route('admin.jurisdictions.index'))->assertOk();
        $this->actingAs($reviewer)->post(route('admin.jurisdictions.store'), [])->assertForbidden();
        $this->actingAs($reviewer)->put(route('admin.jurisdictions.update', $jurisdiction), [])->assertForbidden();
        $this->actingAs($reviewer)->post(route('admin.jurisdictions.coverage.attach', $jurisdiction), ['geographic_unit_id' => $extra->id])->assertForbidden();
        $this->actingAs($reviewer)->delete(route('admin.jurisdictions.coverage.detach', [$jurisdiction, $extra]))->assertForbidden();
        $this->actingAs($commercial)->get(route('admin.geography.index'))->assertForbidden();
        $this->actingAs($commercial)->get(route('admin.jurisdictions.index'))->assertForbidden();
        $this->actingAs($commercial)->post(route('admin.jurisdictions.store'), [])->assertForbidden();
        $this->actingAs($commercial)->put(route('admin.jurisdictions.update', $jurisdiction), [])->assertForbidden();
        $this->actingAs($commercial)->post(route('admin.jurisdictions.coverage.attach', $jurisdiction), ['geographic_unit_id' => $extra->id])->assertForbidden();
        $this->actingAs($commercial)->delete(route('admin.jurisdictions.coverage.detach', [$jurisdiction, $extra]))->assertForbidden();
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

    private function importer(?string $aliasPath = null, ?string $registrationPath = null, ?string $fixturePath = null, ?\Closure $failureHook = null): GeographyImporter
    {
        return new GeographyImporter(app(DatasetAuditLogger::class), app(JurisdictionService::class), $fixturePath, $aliasPath, null, null, $registrationPath, $failureHook);
    }
}
