<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Enums\JurisdictionKind;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RestrictionRouteIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Pico y placa',
            'schema_version' => 1,
            'enabled' => true,
        ]);
    }

    public function test_editor_reaches_real_rules_import_and_template_routes(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);

        $this->actingAs($editor)
            ->get(route('admin.restrictions.index'))
            ->assertOk()
            ->assertSee('Reglas por ciudad');
        $this->get(route('admin.restrictions.import'))
            ->assertOk()
            ->assertSee('Archivo JSON, CSV o XLSX');
        $this->get(route('admin.restrictions.template'))
            ->assertOk()
            ->assertDownload('restriction-rules-template.csv');
    }

    public function test_commercial_operator_cannot_access_rule_operations(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $this->actingAs($commercial)->get(route('admin.restrictions.index'))->assertForbidden();
        $this->get(route('admin.restrictions.import'))->assertForbidden();
    }

    public function test_editor_creates_a_city_draft_with_human_fields_instead_of_json(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $country = GeographicUnit::query()->create([
            'key' => 'co',
            'level' => GeographicUnitLevel::Country,
            'code' => 'CO',
            'name' => 'Colombia',
            'normalized_name' => 'colombia',
            'source_system' => 'synthetic',
            'source_version' => 'test-v1',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'synthetic-city',
            'name' => 'Ciudad sintética',
            'kind' => JurisdictionKind::City,
            'primary_geographic_unit_id' => $country->id,
            'enabled' => true,
        ]);

        $response = $this->actingAs($editor)->post(route('admin.restrictions.store'), [
            'jurisdiction_id' => $jurisdiction->id,
            'coverages' => [[
                'vehicle_kind' => 'car',
                'service_type' => 'private',
                'verified_at' => '2026-09-20T08:00',
                'stale_after' => '2026-10-01T00:00',
                'source_urls' => 'https://example.test/source',
                'rules' => [[
                    'id' => 'synthetic-rule',
                    'priority' => '1000',
                    'effect' => 'restrict',
                    'valid_from' => '2026-09-21T00:00',
                    'valid_until' => '2026-12-31T23:59',
                    'weekdays' => '1,2,3,4,5',
                    'digit_position' => 'lastNumeric',
                    'digits' => '1,2',
                    'time_windows' => '06:00-20:00',
                    'applies_on_holidays' => '0',
                    'source_url' => 'https://example.test/source',
                    'verified_at' => '2026-09-20T08:00',
                ]],
            ]],
        ]);

        $version = RestrictionRuleVersion::query()->sole();
        $response->assertRedirect(route('admin.restrictions.edit', $version));
        $this->assertSame('synthetic-city', $version->payload['id']);
        $this->assertSame([1, 2], $version->payload['coverages'][0]['rules'][0]['digits']);
        $this->get(route('admin.restrictions.edit', $version))
            ->assertOk()
            ->assertSee('Tipo de vehículo')
            ->assertSee('Horarios')
            ->assertDontSee('Contrato JSON');
    }
}
