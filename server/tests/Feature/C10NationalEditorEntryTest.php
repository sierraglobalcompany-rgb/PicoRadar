<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
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

class C10NationalEditorEntryTest extends TestCase
{
    use RefreshDatabase;

    private Jurisdiction $medellin;

    private Jurisdiction $bogota;

    private Jurisdiction $inactive;

    private Jurisdiction $withoutDivipola;

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

        $country = GeographicUnit::query()->create([
            'key' => 'co-c10', 'level' => GeographicUnitLevel::Country, 'code' => 'CO', 'name' => 'Colombia',
            'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'c10-test', 'source_version' => '1',
        ]);
        $antioquia = $this->department($country, '05', 'co-05-c10', 'Antioquia');
        $district = $this->department($country, '11', 'co-11-c10', 'Bogotá D.C.');

        $this->medellin = $this->jurisdiction(
            $this->municipality($antioquia, '05001', 'co-05001-c10', 'Medellín sintética', true),
            'co-ant-medellin-c10', 'Medellín sintética', true,
        );
        $this->inactive = $this->jurisdiction(
            $this->municipality($antioquia, '05002', 'co-05002-c10', 'Municipio inactivo sintético', false),
            'co-ant-inactive-c10', 'Municipio inactivo sintético', false,
        );
        $this->withoutDivipola = $this->jurisdiction(
            $this->municipality($antioquia, '501', 'co-501-c10', 'Municipio sin DIVIPOLA válido', true),
            'co-ant-no-divipola-c10', 'Municipio sin DIVIPOLA válido', true,
        );
        $this->bogota = $this->jurisdiction(
            $this->municipality($district, '11001', 'co-11001-c10', 'Bogotá sintética', true),
            'co-dc-bogota-c10', 'Bogotá sintética', true,
        );
    }

    public function test_editor_gets_entry_only_for_enabled_jurisdictions_and_edit_permission(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);

        $this->actingAs($editor)
            ->get(route('admin.jurisdictions.show', $this->medellin))
            ->assertOk()
            ->assertSee('Crear borrador de restricciones')
            ->assertSee(e(route('admin.restrictions.create', ['jurisdiction_id' => $this->medellin->id])), false);

        $this->actingAs($editor)
            ->get(route('admin.jurisdictions.show', $this->inactive))
            ->assertOk()
            ->assertDontSee('Crear borrador de restricciones');

        $this->actingAs($reviewer)
            ->get(route('admin.jurisdictions.show', $this->medellin))
            ->assertOk()
            ->assertDontSee('Crear borrador de restricciones');
        $this->get(route('admin.restrictions.create'))->assertForbidden();

        $this->actingAs($commercial)
            ->get(route('admin.jurisdictions.show', $this->medellin))
            ->assertForbidden();
        $this->get(route('admin.restrictions.create'))->assertForbidden();
    }

    public function test_get_preselects_the_requested_jurisdiction_and_uses_its_divipola_with_consultation_off(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $url = route('admin.restrictions.create', ['jurisdiction_id' => $this->bogota->id]);

        $response = $this->actingAs($editor)->get($url)->assertOk();

        $this->assertSame($this->bogota->id, $response->viewData('preselectedJurisdictionId'));
        $response->assertSee('<option value="'.$this->bogota->id.'" data-municipality-code="11001" selected>', false)
            ->assertSee('Bogotá sintética · co-dc-bogota-c10')
            ->assertSee('value="11001"', false)
            ->assertSee('Administración territorial: <strong id="jurisdiction-management-state">activa</strong>', false)
            ->assertSee('<input type="hidden" name="consultation_enabled" value="0">', false);
        $checkbox = $this->renderedCheckbox($response->getContent());
        $this->assertDoesNotMatchRegularExpression('/\schecked(?:\s|>)/', $checkbox);
        $this->assertDoesNotMatchRegularExpression('/\sdisabled(?:\s|>)/', $checkbox);
    }

    public function test_valid_old_jurisdiction_precedes_query_and_rehydrates_consultation_for_that_city(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $response = $this->actingAs($editor)
            ->withSession(['_old_input' => [
                'jurisdiction_id' => (string) $this->medellin->id,
                'consultation_enabled' => '1',
            ]])
            ->get(route('admin.restrictions.create', ['jurisdiction_id' => $this->bogota->id]))
            ->assertOk();

        $response->assertSee('<option value="'.$this->medellin->id.'" data-municipality-code="05001" selected>', false)
            ->assertSee('value="05001"', false)
            ->assertDontSee('<option value="'.$this->bogota->id.'" data-municipality-code="11001" selected>', false);
        $checkbox = $this->renderedCheckbox($response->getContent());
        $this->assertMatchesRegularExpression('/\schecked(?:\s|>)/', $checkbox);
        $this->assertDoesNotMatchRegularExpression('/\sdisabled(?:\s|>)/', $checkbox);
    }

    public function test_inactive_or_missing_old_jurisdiction_is_not_used_and_query_remains_a_valid_fallback(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);

        $inactiveOld = $this->actingAs($editor)
            ->withSession(['_old_input' => [
                'jurisdiction_id' => (string) $this->inactive->id,
                'consultation_enabled' => '1',
            ]])
            ->get(route('admin.restrictions.create', ['jurisdiction_id' => $this->bogota->id]))
            ->assertOk();
        $inactiveOld->assertSee('<option value="'.$this->bogota->id.'" data-municipality-code="11001" selected>', false)
            ->assertSee('value="11001"', false);
        $this->assertDoesNotMatchRegularExpression('/\schecked(?:\s|>)/', $this->renderedCheckbox($inactiveOld->getContent()));

        $noSelection = $this->withSession(['_old_input' => [
            'jurisdiction_id' => (string) $this->inactive->id,
            'consultation_enabled' => '1',
        ]])->get(route('admin.restrictions.create'))->assertOk();
        $noSelection->assertSee('<option value="" disabled selected>Selecciona municipio y jurisdicción</option>', false)
            ->assertDontSee('<option value="'.$this->inactive->id.'"', false);
        $this->assertMatchesRegularExpression('/\sdisabled(?:\s|>)/', $this->renderedCheckbox($noSelection->getContent()));
        $this->assertDoesNotMatchRegularExpression('/\schecked(?:\s|>)/', $this->renderedCheckbox($noSelection->getContent()));
    }

    public function test_invalid_query_values_leave_no_selection_and_get_does_not_mutate_records(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $before = $this->editorEntryCounts();
        $invalidIds = [
            [$this->bogota->id],
            'not-an-id',
            0,
            -1,
            $this->inactive->id,
            999999999,
            '999999999999999999999999999999',
        ];

        foreach ($invalidIds as $invalidId) {
            $query = http_build_query(['jurisdiction_id' => $invalidId]);
            $response = $this->actingAs($editor)
                ->get(route('admin.restrictions.create').($query === '' ? '' : '?'.$query))
                ->assertOk();

            $this->assertNull($response->viewData('preselectedJurisdictionId'));
            $response->assertSee('<option value="" disabled selected>Selecciona municipio y jurisdicción</option>', false);
            $this->assertMatchesRegularExpression('/<input id="municipality-code"[^>]*value=""[^>]*readonly/', $response->getContent());
            $checkbox = $this->renderedCheckbox($response->getContent());
            $this->assertMatchesRegularExpression('/\sdisabled(?:\s|>)/', $checkbox);
            $this->assertDoesNotMatchRegularExpression('/\schecked(?:\s|>)/', $checkbox);
        }

        $withInvalidGeographicUnit = $this->get(route('admin.restrictions.create', ['jurisdiction_id' => $this->withoutDivipola->id]))
            ->assertOk();
        $withInvalidGeographicUnit->assertSee('<option value="'.$this->withoutDivipola->id.'" data-municipality-code="" selected>', false)
            ->assertSee('<input type="hidden" name="consultation_enabled" value="0">', false);
        $this->assertMatchesRegularExpression('/\sdisabled(?:\s|>)/', $this->renderedCheckbox($withInvalidGeographicUnit->getContent()));

        $this->assertSame($before, $this->editorEntryCounts());
    }

    public function test_edit_keeps_the_version_jurisdiction_even_when_a_different_query_id_is_present(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $version = $this->draft($this->medellin, $editor, [
            'schemaVersion' => 2,
            'id' => $this->medellin->key,
            'name' => $this->medellin->name,
            'municipalityCodes' => ['05001'],
            'consultationEnabled' => false,
            'coverages' => [],
        ]);

        $response = $this->actingAs($editor)
            ->get(route('admin.restrictions.edit', $version).'?jurisdiction_id='.$this->bogota->id)
            ->assertOk()
            ->assertSee('Borrador '.$this->medellin->name.' v1')
            ->assertSee('value="05001"', false)
            ->assertDontSee('value="11001"', false)
            ->assertDontSee('name="jurisdiction_id"', false);

        $this->assertSame($this->medellin->id, $version->jurisdiction_id);
        $this->assertSame(0, preg_match('/\schecked(?:\s|>)/', $this->renderedCheckbox($response->getContent())));
    }

    public function test_change_handler_clears_consultation_and_updates_divipola_availability_only(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $response = $this->actingAs($editor)
            ->get(route('admin.restrictions.create', ['jurisdiction_id' => $this->bogota->id]))
            ->assertOk();

        $response->assertSee('consultationCheckbox.checked = false;', false)
            ->assertSee('consultationCheckbox.disabled = !hasMunicipalityCode;', false)
            ->assertSee('codeInput.value = hasMunicipalityCode ? selectedCode :', false)
            ->assertSee("managementState.textContent = selectedOption?.dataset.managementState ?? 'sin municipio seleccionado';", false);
    }

    public function test_post_requires_edit_permission_and_creates_only_an_unpublished_draft_with_consultation_off(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);
        $this->actingAs($reviewer)->post(route('admin.restrictions.store'), [])->assertForbidden();
        $this->actingAs($commercial)->post(route('admin.restrictions.store'), [])->assertForbidden();

        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        Http::preventStrayRequests();
        $response = $this->actingAs($editor)->post(route('admin.restrictions.store'), [
            'jurisdiction_id' => $this->bogota->id,
            'consultation_enabled' => '0',
            'coverages' => [[
                'pair' => 'car|private',
                'verified_at' => '2026-11-18T08:00',
                'stale_after' => '2026-12-18T00:00',
                'source_urls' => 'https://example.test/restrictions',
                'rules' => [[
                    'id' => 'c10-editor-entry-rule',
                    'priority' => '1000',
                    'effect' => 'restrict',
                    'valid_from' => '2026-11-18T00:00',
                    'weekdays' => '1',
                    'date_parity' => '',
                    'digit_position' => 'lastNumeric',
                    'digits' => '1',
                    'time_windows' => '06:00-08:00',
                    'applies_on_holidays' => '0',
                    'source_url' => 'https://example.test/restrictions',
                    'verified_at' => '2026-11-18T08:00',
                    'registration_origins' => '',
                    'conditions_json' => '[]',
                ]],
            ]],
        ]);

        $version = RestrictionRuleVersion::query()->sole();
        $response->assertRedirect(route('admin.restrictions.edit', $version))->assertSessionHasNoErrors();
        $this->assertSame(RestrictionRuleVersionStatus::Draft, $version->status);
        $this->assertFalse($version->payload['consultationEnabled']);
        $this->assertSame([], $version->publicationItems()->get()->all());
        $this->assertSame(0, RestrictionPublication::query()->count());
        $this->assertSame(0, DatasetRelease::query()->count());
        Http::assertNothingSent();
    }

    private function department(GeographicUnit $country, string $code, string $key, string $name): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => $key, 'level' => GeographicUnitLevel::Department, 'code' => $code,
            'name' => $name, 'normalized_name' => mb_strtolower($name), 'is_active' => true,
            'source_system' => 'c10-test', 'source_version' => '1',
        ]);
    }

    private function municipality(GeographicUnit $department, string $code, string $key, string $name, bool $active): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => $key, 'level' => GeographicUnitLevel::Municipality, 'code' => $code,
            'name' => $name, 'normalized_name' => mb_strtolower($name), 'is_active' => $active,
            'source_system' => 'c10-test', 'source_version' => '1',
        ]);
    }

    private function jurisdiction(GeographicUnit $municipality, string $key, string $name, bool $enabled): Jurisdiction
    {
        return Jurisdiction::query()->create([
            'key' => $key,
            'name' => $name,
            'kind' => JurisdictionKind::City,
            'primary_geographic_unit_id' => $municipality->id,
            'enabled' => $enabled,
            'timezone' => 'America/Bogota',
        ]);
    }

    /** @param array<string, mixed> $payload */
    private function draft(Jurisdiction $jurisdiction, User $editor, array $payload): RestrictionRuleVersion
    {
        return RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id,
            'version' => 1,
            'status' => RestrictionRuleVersionStatus::Draft,
            'payload' => $payload,
            'payload_sha256' => hash('sha256', json_encode($payload)),
            'base_publication_revision' => 0,
            'created_by_id' => $editor->id,
            'updated_by_id' => $editor->id,
        ]);
    }

    private function renderedCheckbox(string $html): string
    {
        $this->assertSame(1, preg_match('/<input id="consultation-enabled"[^>]*>/', $html, $matches));

        return $matches[0];
    }

    /** @return array<string, int> */
    private function editorEntryCounts(): array
    {
        return [
            'jurisdictions' => DB::table('jurisdictions')->count(),
            'restriction_rule_versions' => DB::table('restriction_rule_versions')->count(),
            'datasets' => DB::table('datasets')->count(),
            'restriction_publications' => DB::table('restriction_publications')->count(),
        ];
    }
}
