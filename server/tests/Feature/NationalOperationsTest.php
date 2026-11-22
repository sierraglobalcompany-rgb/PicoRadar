<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Enums\OperatorRole;
use App\Enums\RestrictionImportStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NationalOperationsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_commercial_operator_cannot_open_national_operations(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);

        $this->actingAs($commercial)->get('/admin/operations/national')->assertForbidden();
    }

    public function test_dashboard_counts_distinct_municipalities_and_shows_editorial_and_release_separately(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $department05 = $this->department('05', 'Antioquia sintética');
        $department11 = $this->department('11', 'Bogotá sintética');
        $unassigned = $this->municipality($department05, '05001', 'Municipio sin jurisdicción');
        $off = $this->municipality($department05, '05002', 'Municipio deshabilitado');
        $draft = $this->municipality($department05, '05003', 'Municipio borrador');
        $validated = $this->municipality($department11, '11001', 'Municipio validado');
        $stale = $this->municipality($department11, '11002', 'Municipio vencido');
        $noEvidence = $this->municipality($department11, '11003', 'Municipio sin evidencia');

        $offJurisdiction = $this->jurisdiction($off, false);
        $draftJurisdiction = $this->jurisdiction($draft, true);
        $validatedJurisdiction = $this->jurisdiction($validated, true);
        $staleJurisdiction = $this->jurisdiction($stale, true);
        $noEvidenceJurisdiction = $this->jurisdiction($noEvidence, true);
        $this->version($offJurisdiction, RestrictionRuleVersionStatus::Draft);
        $this->version($draftJurisdiction, RestrictionRuleVersionStatus::Draft);
        $this->version($validatedJurisdiction, RestrictionRuleVersionStatus::Validated);
        $this->version($staleJurisdiction, RestrictionRuleVersionStatus::Validated, stale: true);

        $import = RestrictionImport::query()->create([
            'sha256' => str_repeat('a', 64),
            'original_name' => 'fixture.json',
            'format' => 'json',
            'private_path' => 'restriction-imports/fixture.json',
            'status' => RestrictionImportStatus::Analyzed,
            'row_count' => 1,
            'created_by_id' => $admin->id,
            'analyzed_at' => now(),
        ]);
        $import->rows()->create([
            'row_number' => 1,
            'state' => 'valid',
            'publishable' => true,
            'normalized' => ['onboarding' => ['status' => 'ALTA_PROPUESTA', 'municipality_code' => '05001']],
            'raw' => ['fixture' => true],
        ]);

        $response = $this->actingAs($admin)->get(route('admin.operations.national'));

        $response->assertOk()
            ->assertSeeText('PUBLICACIÓN POR CIUDAD NO COMPROBADA')
            ->assertSeeText('Sin evidencia')
            ->assertSee(route('admin.restrictions.imports.review', $import));
        $response->assertViewHas('metrics', function (array $metrics): bool {
            return $metrics['active_municipalities'] === 6
                && $metrics['associated_municipalities'] === 5
                && $metrics['off_jurisdictions'] === 1
                && $metrics['draft_versions'] === 2
                && $metrics['validated_versions'] === 2
                && $metrics['pending_proposal_rows'] === 1;
        });
        $response->assertViewHas('rows', function ($rows): bool {
            $states = collect($rows->items())->keyBy('municipality_code')->map(fn (array $row): string => $row['state']);

            return $states->get('05001') === 'sin_asignar'
                && $states->get('05002') === 'off'
                && $states->get('05003') === 'borrador'
                && $states->get('11001') === 'validado'
                && $states->get('11002') === 'vencido'
                && $states->get('11003') === 'sin_evidencia';
        });
    }

    public function test_department_search_state_filter_and_page_size_are_bounded(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $department = $this->department('05', 'Antioquia sintética');
        for ($number = 1; $number <= 52; $number++) {
            $this->municipality($department, sprintf('05%03d', $number), 'Municipio sintético '.$number);
        }

        $pageOne = $this->actingAs($admin)->get(route('admin.operations.national', ['department' => '05', 'per_page' => 50]));
        $pageOne->assertOk()->assertViewHas('rows', fn ($rows): bool => $rows->total() === 52 && $rows->count() === 50);

        $pageTwo = $this->actingAs($admin)->get(route('admin.operations.national', ['department' => '05', 'per_page' => 50, 'page' => 2]));
        $pageTwo->assertOk()->assertViewHas('rows', fn ($rows): bool => $rows->total() === 52 && $rows->count() === 2);

        $search = $this->actingAs($admin)->get(route('admin.operations.national', ['q' => '05007', 'state' => 'sin_asignar', 'per_page' => 25]));
        $search->assertOk()->assertViewHas('rows', fn ($rows): bool => $rows->total() === 1 && $rows->items()[0]['municipality_code'] === '05007');

        $this->actingAs($admin)->get(route('admin.operations.national', ['department' => '5']))->assertSessionHasErrors('department');
    }

    private function department(string $code, string $name): GeographicUnit
    {
        $country = GeographicUnit::query()->firstOrCreate(['key' => 'co'], [
            'level' => GeographicUnitLevel::Country,
            'code' => 'CO',
            'name' => 'Colombia sintética',
            'normalized_name' => 'colombia sintetica',
            'is_active' => true,
            'source_system' => 'test-fixture',
            'source_version' => '2026-11',
        ]);

        return GeographicUnit::query()->create([
            'parent_id' => $country->id,
            'key' => 'co-'.$code,
            'level' => GeographicUnitLevel::Department,
            'code' => $code,
            'name' => $name,
            'normalized_name' => strtolower($name),
            'is_active' => true,
            'source_system' => 'test-fixture',
            'source_version' => '2026-11',
        ]);
    }

    private function municipality(GeographicUnit $department, string $code, string $name): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'parent_id' => $department->id,
            'key' => 'co-'.$code,
            'level' => GeographicUnitLevel::Municipality,
            'code' => $code,
            'name' => $name,
            'normalized_name' => strtolower($name),
            'is_active' => true,
            'source_system' => 'test-fixture',
            'source_version' => '2026-11',
        ]);
    }

    private function jurisdiction(GeographicUnit $municipality, bool $enabled): Jurisdiction
    {
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'municipio-'.$municipality->code,
            'name' => $municipality->name,
            'kind' => 'city',
            'primary_geographic_unit_id' => $municipality->id,
            'enabled' => $enabled,
            'timezone' => 'America/Bogota',
        ]);
        $jurisdiction->geographicUnits()->attach($municipality->id);

        return $jurisdiction;
    }

    private function version(Jurisdiction $jurisdiction, RestrictionRuleVersionStatus $status, bool $stale = false): RestrictionRuleVersion
    {
        return RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id,
            'version' => 1,
            'status' => $status,
            'payload' => ['schemaVersion' => 2, 'coverages' => [['sourceUrls' => ['https://example.test/synthetic-rules'], 'rules' => []]]],
            'payload_sha256' => hash('sha256', 'synthetic-'.$jurisdiction->key),
            'base_publication_revision' => 0,
            'vehicle_kinds' => ['car'],
            'valid_until' => now()->addDays(30)->toDateString(),
            'stale_after' => $stale ? now()->subDay() : now()->addDays(7),
            'source_checked_at' => now()->subDay(),
            'validated_at' => $status === RestrictionRuleVersionStatus::Validated ? now()->subDay() : null,
        ]);
    }
}
