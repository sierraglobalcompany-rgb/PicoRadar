<?php

namespace Tests\Feature;

use App\Enums\JurisdictionKind;
use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class C11NationalEditorialFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();

        Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Restrictions',
            'schema_version' => 2,
            'enabled' => true,
        ]);
    }

    public function test_editor_onboards_an_unassigned_municipality_and_saves_a_schema2_draft_without_publication(): void
    {
        Http::preventStrayRequests();

        $country = $this->geographicUnit(null, 'country', 'CO', 'Colombia', 'co-c11');
        $department = $this->geographicUnit($country, 'department', '05', 'Departamento sintético', 'co-05-c11');
        $municipality = $this->geographicUnit($department, 'municipality', '05001', 'Municipio sintético', 'co-05001-c11');
        $municipalityWithoutDivipola = $this->geographicUnit($department, 'municipality', '501', 'Municipio sin DIVIPOLA válido', 'co-501-c11');

        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);

        $beforeMatrixGet = $this->editorFlowCounts();
        $matrix = $this->actingAs($editor)
            ->get(route('admin.restrictions.municipalities'))
            ->assertOk()
            ->assertSee('NO_JURISDICTION')
            ->assertSee('Preparar jurisdicción');
        $matrix->assertSee(e(route('admin.jurisdictions.create', ['primary_geographic_unit_id' => $municipality->id])), false);
        self::assertSame($beforeMatrixGet, $this->editorFlowCounts());

        $jurisdictionKey = 'co-c11-municipio-sintetico';
        $jurisdictionResponse = $this->actingAs($editor)
            ->post(route('admin.jurisdictions.store'), [
                'key' => $jurisdictionKey,
                'name' => 'Municipio sintético',
                'kind' => JurisdictionKind::City->value,
                'enabled' => '1',
                'timezone' => 'America/Bogota',
                'primary_geographic_unit_id' => $municipality->id,
            ]);

        $jurisdiction = Jurisdiction::query()->where('key', $jurisdictionKey)->firstOrFail();
        $jurisdictionResponse->assertRedirect(route('admin.jurisdictions.show', $jurisdiction));
        self::assertSame($municipality->id, $jurisdiction->primary_geographic_unit_id);
        self::assertTrue($jurisdiction->geographicUnits()->whereKey($municipality->id)->exists());

        $showUrl = route('admin.jurisdictions.show', $jurisdiction);
        $editorEntryUrl = route('admin.restrictions.create', ['jurisdiction_id' => $jurisdiction->id]);
        $beforeShowGet = $this->editorFlowCounts();
        $this->actingAs($editor)
            ->get($showUrl)
            ->assertOk()
            ->assertSee('Crear borrador de restricciones')
            ->assertSee(e($editorEntryUrl), false);
        self::assertSame($beforeShowGet, $this->editorFlowCounts());

        $beforeEditorGet = $this->editorFlowCounts();
        $editorForm = $this->actingAs($editor)
            ->get($editorEntryUrl)
            ->assertOk()
            ->assertSee('<option value="'.$jurisdiction->id.'" data-municipality-code="05001" data-management-state="activa" selected>', false)
            ->assertSee('<input type="hidden" name="consultation_enabled" value="0">', false);
        self::assertSame($jurisdiction->id, $editorForm->viewData('preselectedJurisdictionId'));
        self::assertSame($beforeEditorGet, $this->editorFlowCounts());

        $withoutDivipolaJurisdiction = $this->jurisdiction($municipalityWithoutDivipola);
        $beforeUnknownDivipolaGet = $this->editorFlowCounts();
        $unknownDivipolaForm = $this->actingAs($editor)
            ->get(route('admin.restrictions.create', ['jurisdiction_id' => $withoutDivipolaJurisdiction->id]))
            ->assertOk()
            ->assertSee('<option value="'.$withoutDivipolaJurisdiction->id.'" data-municipality-code="" data-management-state="activa" selected>', false)
            ->assertSee('<input type="hidden" name="consultation_enabled" value="0">', false);
        self::assertMatchesRegularExpression('/\sdisabled(?:\s|>)/', $this->renderedCheckbox($unknownDivipolaForm->getContent()));
        self::assertSame($beforeUnknownDivipolaGet, $this->editorFlowCounts());

        $this->actingAs($reviewer)->post(route('admin.restrictions.store'), [])->assertForbidden();
        $this->actingAs($commercial)->post(route('admin.restrictions.store'), [])->assertForbidden();
        self::assertSame(0, RestrictionRuleVersion::query()->count());

        $draftResponse = $this->actingAs($editor)
            ->post(route('admin.restrictions.store'), [
                'jurisdiction_id' => $jurisdiction->id,
                'consultation_enabled' => '0',
                'coverages' => [],
            ]);

        $version = RestrictionRuleVersion::query()->sole();
        $draftResponse->assertRedirect(route('admin.restrictions.edit', $version));
        self::assertSame(2, $version->payload['schemaVersion']);
        self::assertSame($jurisdiction->id, $version->jurisdiction_id);
        self::assertSame(RestrictionRuleVersionStatus::Draft, $version->status);
        self::assertFalse($version->payload['consultationEnabled']);
        self::assertSame([], $version->publicationItems()->get()->all());
        self::assertSame(0, RestrictionPublication::query()->count());
        self::assertSame(0, DatasetRelease::query()->count());
        Http::assertNothingSent();
    }

    private function geographicUnit(?GeographicUnit $parent, string $level, string $code, string $name, string $key): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'parent_id' => $parent?->id,
            'key' => $key,
            'level' => $level,
            'code' => $code,
            'name' => $name,
            'normalized_name' => mb_strtolower($name),
            'is_active' => true,
            'source_system' => 'c11-flow-test',
            'source_version' => '1',
        ]);
    }

    private function jurisdiction(GeographicUnit $municipality): Jurisdiction
    {
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'co-c11-no-divipola',
            'name' => 'Municipio sin DIVIPOLA válido',
            'kind' => JurisdictionKind::City,
            'primary_geographic_unit_id' => $municipality->id,
            'enabled' => true,
            'timezone' => 'America/Bogota',
        ]);
        $municipality->jurisdictions()->attach($jurisdiction->id);

        return $jurisdiction;
    }

    private function renderedCheckbox(string $html): string
    {
        $this->assertSame(1, preg_match('/<input id="consultation-enabled"[^>]*>/', $html, $matches));

        return $matches[0];
    }

    /** @return array<string, int> */
    private function editorFlowCounts(): array
    {
        return [
            'users' => User::query()->count(),
            'geographic_units' => GeographicUnit::query()->count(),
            'jurisdictions' => Jurisdiction::query()->count(),
            'jurisdiction_geographic_unit' => DB::table('jurisdiction_geographic_unit')->count(),
            'restriction_rule_versions' => RestrictionRuleVersion::query()->count(),
            'datasets' => Dataset::query()->count(),
            'restriction_publications' => RestrictionPublication::query()->count(),
            'dataset_releases' => DatasetRelease::query()->count(),
            'audit_logs' => DB::table('audit_logs')->count(),
        ];
    }
}
