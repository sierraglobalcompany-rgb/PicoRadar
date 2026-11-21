<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class C9JurisdictionOnboardingTest extends TestCase
{
    use RefreshDatabase;

    private GeographicUnit $department;

    private GeographicUnit $activeMunicipality;

    private GeographicUnit $otherActiveMunicipality;

    private GeographicUnit $inactiveMunicipality;

    private GeographicUnit $assignedMunicipality;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();

        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia',
            'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'c9-test', 'source_version' => '1',
        ]);
        $this->department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05',
            'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true,
            'source_system' => 'c9-test', 'source_version' => '1',
        ]);
        $this->activeMunicipality = $this->municipality('05001', 'co-05001', 'Municipio Uno', true);
        $this->otherActiveMunicipality = $this->municipality('05002', 'co-05002', 'Municipio Dos', true);
        $this->inactiveMunicipality = $this->municipality('05003', 'co-05003', 'Municipio Inactivo', false);
        $this->assignedMunicipality = $this->municipality('05004', 'co-05004', 'Municipio Asignado', true);
        $assignedJurisdiction = Jurisdiction::query()->create([
            'key' => 'co-ant-asignado', 'name' => 'Jurisdicción asignada', 'kind' => 'city',
            'primary_geographic_unit_id' => $this->assignedMunicipality->id, 'enabled' => true, 'timezone' => 'America/Bogota',
        ]);
        $this->assignedMunicipality->jurisdictions()->attach($assignedJurisdiction->id);
    }

    public function test_matrix_cta_is_only_visible_to_jurisdiction_editors_for_unassigned_rows(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $viewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $ctaUrl = route('admin.jurisdictions.create', ['primary_geographic_unit_id' => $this->activeMunicipality->id]);

        $this->actingAs($editor)
            ->get(route('admin.restrictions.municipalities'))
            ->assertOk()
            ->assertSee('NO_JURISDICTION')
            ->assertSee('Preparar jurisdicción')
            ->assertSee(e($ctaUrl), false)
            ->assertDontSee(e(route('admin.jurisdictions.create', ['primary_geographic_unit_id' => $this->assignedMunicipality->id])), false);

        $this->actingAs($viewer)
            ->get(route('admin.restrictions.municipalities'))
            ->assertOk()
            ->assertSee('NO_JURISDICTION')
            ->assertDontSee('Preparar jurisdicción');
    }

    public function test_create_get_preselects_only_active_municipalities_and_old_valid_choice_wins(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $url = route('admin.jurisdictions.create', ['primary_geographic_unit_id' => $this->activeMunicipality->id]);

        $response = $this->actingAs($editor)->get($url)->assertOk();
        self::assertSame($this->activeMunicipality->id, $response->viewData('preselectedMunicipalityId'));
        $response->assertSee('value="'.$this->activeMunicipality->id.'" selected', false);
        $response->assertDontSee('value="'.$this->otherActiveMunicipality->id.'" selected', false);

        $oldChoice = $this->actingAs($editor)
            ->withSession(['_old_input' => ['primary_geographic_unit_id' => (string) $this->otherActiveMunicipality->id]])
            ->get($url)
            ->assertOk();
        $oldChoice->assertSee('value="'.$this->otherActiveMunicipality->id.'" selected', false);
        $oldChoice->assertDontSee('value="'.$this->activeMunicipality->id.'" selected', false);
    }

    public function test_malformed_or_ineligible_preselection_is_ignored_without_mutating_database(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $invalidValues = [
            ['bad'],
            0,
            '-1',
            $this->department->id,
            999999999,
            str_repeat('9', 80),
            $this->inactiveMunicipality->id,
        ];
        $before = [
            DB::table('jurisdictions')->count(),
            DB::table('jurisdiction_geographic_unit')->count(),
            DB::table('audit_logs')->count(),
        ];

        foreach ($invalidValues as $value) {
            $response = $this->actingAs($editor)
                ->get(route('admin.jurisdictions.create', ['primary_geographic_unit_id' => $value]))
                ->assertOk();
            self::assertNull($response->viewData('preselectedMunicipalityId'));
            $response->assertDontSee('value="'.$this->activeMunicipality->id.'" selected', false);
            $response->assertDontSee('value="'.$this->otherActiveMunicipality->id.'" selected', false);
        }

        self::assertSame($before, [
            DB::table('jurisdictions')->count(),
            DB::table('jurisdiction_geographic_unit')->count(),
            DB::table('audit_logs')->count(),
        ]);
    }

    public function test_post_keeps_existing_validation_and_service_creation_path(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $payload = [
            'key' => 'co-ant-municipio-uno',
            'name' => 'Municipio Uno',
            'kind' => 'city',
            'enabled' => '1',
            'timezone' => 'America/Bogota',
        ];

        $this->actingAs($editor)
            ->post(route('admin.jurisdictions.store'), [...$payload, 'primary_geographic_unit_id' => $this->department->id])
            ->assertStatus(422);
        // setUp() creates the already-assigned municipality's jurisdiction.
        // Invalid POST must not create a second one.
        self::assertSame(1, Jurisdiction::query()->count());

        $this->actingAs($editor)
            ->post(route('admin.jurisdictions.store'), [...$payload, 'primary_geographic_unit_id' => $this->activeMunicipality->id])
            ->assertRedirect(route('admin.jurisdictions.show', Jurisdiction::query()->where('key', $payload['key'])->firstOrFail()));

        $jurisdiction = Jurisdiction::query()->where('key', $payload['key'])->firstOrFail();
        self::assertTrue($jurisdiction->enabled);
        self::assertSame($this->activeMunicipality->id, $jurisdiction->primary_geographic_unit_id);
        self::assertTrue($jurisdiction->geographicUnits()->whereKey($this->activeMunicipality->id)->exists());
    }

    private function municipality(string $code, string $key, string $name, bool $active): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'parent_id' => $this->department->id,
            'key' => $key,
            'level' => 'municipality',
            'code' => $code,
            'name' => $name,
            'normalized_name' => mb_strtolower($name),
            'is_active' => $active,
            'source_system' => 'c9-test',
            'source_version' => '1',
        ]);
    }
}
