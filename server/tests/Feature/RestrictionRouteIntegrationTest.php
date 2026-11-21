<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Enums\JurisdictionKind;
use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
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

    public function test_schema2_draft_keeps_its_schema_and_rejects_a_legacy_post_without_losing_data(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => GeographicUnitLevel::Country, 'code' => 'CO',
            'name' => 'Colombia', 'normalized_name' => 'colombia',
            'source_system' => 'synthetic', 'source_version' => 'test-v1',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'synthetic-city', 'name' => 'Ciudad sintética',
            'kind' => JurisdictionKind::City,
            'primary_geographic_unit_id' => $country->id, 'enabled' => true,
        ]);
        $payload = [
            'schemaVersion' => 2, 'id' => 'synthetic-city', 'name' => 'Ciudad sintética',
            'coverages' => [[
                'vehicleKind' => 'truck', 'serviceType' => 'public_cargo',
                'coverageCompleteness' => 'partial',
                'verifiedAt' => '2026-11-13T10:00:00-05:00',
                'staleAfter' => '2026-11-20T23:59:59-05:00',
                'sourceUrls' => ['https://example.test/municipal'],
                'rules' => [],
            ]],
        ];
        $version = RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id, 'version' => 1,
            'status' => RestrictionRuleVersionStatus::Draft,
            'payload' => $payload, 'payload_sha256' => hash('sha256', json_encode($payload)),
            'base_publication_revision' => 0,
            'created_by_id' => $editor->id, 'updated_by_id' => $editor->id,
        ]);
        $this->actingAs($editor)->get(route('admin.restrictions.edit', $version))
            ->assertOk()
            ->assertSee('Editar cobertura schema2')
            ->assertSee('conditions_json');

        $this->actingAs($editor)->put(route('admin.restrictions.update', $version), [
            'coverages' => [[
                'vehicle_kind' => 'car', 'service_type' => 'private',
                'rules' => [],
            ]],
        ])->assertSessionHasErrors('coverages');
        $version->refresh();
        $this->assertSame($payload, $version->payload);
    }

    public function test_editor_creates_and_edits_schema2_through_the_existing_form_without_losing_typed_fields(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $country = GeographicUnit::query()->create([
            'key' => 'co-schema2', 'level' => GeographicUnitLevel::Country, 'code' => 'CO',
            'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'test-v2',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-05-schema2', 'level' => GeographicUnitLevel::Department,
            'code' => '05', 'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'test-v2',
        ]);
        $municipality = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'co-05001-schema2', 'level' => GeographicUnitLevel::Municipality,
            'code' => '05001', 'name' => 'Medellín sintética', 'normalized_name' => 'medellin sintetica',
            'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'test-v2',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'co-ant-medellin-form', 'name' => 'Medellín sintética', 'kind' => JurisdictionKind::City,
            'primary_geographic_unit_id' => $municipality->id, 'enabled' => true,
        ]);
        $jurisdiction->geographicUnits()->attach($municipality->id);

        $this->actingAs($editor)->get(route('admin.restrictions.create'))
            ->assertOk()
            ->assertSee('schema2')
            ->assertSee('Carro · particular')
            ->assertSee('Consulta pública');

        $source = 'https://example.test/restrictions';
        $firstCoverage = [
            'pair' => 'car|private',
            'verified_at' => '2026-11-16T08:00',
            'stale_after' => '2026-12-01T00:00',
            'source_urls' => $source,
            'rules' => [[
                'id' => 'synthetic-car-rule', 'priority' => '1000', 'effect' => 'restrict',
                'valid_from' => '2026-11-16T00:00', 'valid_until' => '2026-11-30T23:59',
                'weekdays' => '1', 'date_parity' => '', 'digit_position' => 'lastNumeric', 'digits' => '1,2',
                'time_windows' => "00:00-00:00 fullDay\n06:00-08:00", 'applies_on_holidays' => '0',
                'source_url' => $source, 'verified_at' => '2026-11-16T08:00', 'registration_origins' => '',
                'conditions_json' => '[{"type":"occupants_at_least","value":2}]',
            ]],
        ];
        $createInput = [
            'jurisdiction_id' => $jurisdiction->id,
            'municipality_codes' => '05001',
            'consultation_enabled' => '1',
            'coverages' => [$firstCoverage],
        ];
        $response = $this->actingAs($editor)->post(route('admin.restrictions.store'), $createInput);
        $version = RestrictionRuleVersion::query()->sole();
        $response->assertRedirect(route('admin.restrictions.edit', $version))->assertSessionHasNoErrors();
        $this->assertSame(2, $version->payload['schemaVersion']);
        $this->assertSame(['05001'], $version->payload['municipalityCodes']);
        $this->assertTrue($version->payload['consultationEnabled']);
        $this->assertSame('partial', $version->payload['coverages'][0]['coverageCompleteness']);
        $this->assertSame(true, $version->payload['coverages'][0]['rules'][0]['timeWindows'][0]['fullDay']);
        $this->assertSame([['type' => 'occupants_at_least', 'value' => 2]], $version->payload['coverages'][0]['rules'][0]['conditions']);

        $this->actingAs($editor)->get(route('admin.restrictions.edit', $version))
            ->assertOk()
            ->assertSee('Editar cobertura schema2')
            ->assertSee('conditions_json')
            ->assertSee('fullDay')
            ->assertSee('Administración territorial:')
            ->assertSee('no cambia el dataset publicado')
            ->assertSee('00:00-00:00 fullDay')
            ->assertSee('occupants_at_least');

        $secondCoverage = [
            'pair' => 'car|taxi',
            'verified_at' => '2026-11-16T08:00',
            'stale_after' => '2026-12-01T00:00',
            'source_urls' => $source,
            'rules' => [[
                'id' => 'synthetic-taxi-rule', 'priority' => '1000', 'effect' => 'restrict',
                'valid_from' => '2026-11-16T00:00', 'valid_until' => '2026-11-30T23:59',
                'weekdays' => '3', 'date_parity' => '', 'digit_position' => 'lastNumeric', 'digits' => '5,6',
                'time_windows' => '07:00-09:00', 'applies_on_holidays' => '0',
                'source_url' => $source, 'verified_at' => '2026-11-16T08:00', 'registration_origins' => '',
                'conditions_json' => '[]',
            ]],
        ];
        $updateInput = [
            'municipality_codes' => '05001', 'consultation_enabled' => '1',
            'coverages' => [
                [
                    ...$firstCoverage,
                    'rules' => [[
                        ...$firstCoverage['rules'][0],
                        'weekdays' => '2', 'digits' => '3,4',
                        'time_windows' => "00:00-00:00 fullDay\n07:00-09:00",
                    ]],
                ],
                $secondCoverage,
            ],
        ];
        $this->actingAs($editor)->put(route('admin.restrictions.update', $version), $updateInput)
            ->assertRedirect()->assertSessionHasNoErrors();
        $version->refresh();
        $this->assertSame(2, $version->payload['schemaVersion']);
        $this->assertSame([2], $version->payload['coverages'][0]['rules'][0]['weekdays']);
        $this->assertSame([3, 4], $version->payload['coverages'][0]['rules'][0]['digits']);
        $this->assertSame(420, $version->payload['coverages'][0]['rules'][0]['timeWindows'][1]['startMinute']);
        $this->assertSame(true, $version->payload['coverages'][0]['rules'][0]['timeWindows'][0]['fullDay']);
        $this->assertSame([['type' => 'occupants_at_least', 'value' => 2]], $version->payload['coverages'][0]['rules'][0]['conditions']);
        $this->assertSame(['05001'], $version->payload['municipalityCodes']);
        $this->assertTrue($version->payload['consultationEnabled']);
        $this->assertSame('taxi', $version->payload['coverages'][1]['serviceType']);

        $this->actingAs($reviewer)->put(route('admin.restrictions.update', $version), $updateInput)->assertForbidden();
        $this->actingAs($editor)->post(route('admin.restrictions.publish'), [
            'versions' => [$version->id], 'publication_revision' => 0,
        ])->assertForbidden();

        $pairs = [
            'car|private', 'car|taxi', 'car|special', 'motorcycle|private',
            'truck|private', 'truck|public_cargo', 'bus|public_passenger',
            'bus|special', 'motocarro|private',
        ];
        $nineCoverages = [];
        foreach ($pairs as $index => $pair) {
            $nineCoverages[] = [
                'pair' => $pair,
                'verified_at' => '2026-11-16T08:00', 'stale_after' => '2026-12-01T00:00',
                'source_urls' => $source,
                'rules' => [[
                    'id' => 'synthetic-pair-'.$index, 'priority' => '1000', 'effect' => 'restrict',
                    'valid_from' => '2026-11-16T00:00', 'valid_until' => '2026-11-30T23:59',
                    'weekdays' => '1', 'date_parity' => '', 'digit_position' => 'lastNumeric', 'digits' => '1,2',
                    'time_windows' => '06:00-08:00', 'applies_on_holidays' => '0',
                    'source_url' => $source, 'verified_at' => '2026-11-16T08:00', 'registration_origins' => '',
                    'conditions_json' => '[]',
                ]],
            ];
        }
        $this->actingAs($editor)->put(route('admin.restrictions.update', $version), [
            'consultation_enabled' => '1', 'coverages' => $nineCoverages,
        ])->assertRedirect()->assertSessionHasNoErrors();
        $version->refresh();
        $this->assertCount(9, $version->payload['coverages']);
        $this->assertSame('motocarro', $version->payload['coverages'][8]['vehicleKind']);

        $nineCoverages[0]['pair'] = 'car|public_cargo';
        $this->actingAs($editor)->put(route('admin.restrictions.update', $version), [
            'consultation_enabled' => '1', 'coverages' => $nineCoverages,
        ])->assertSessionHasErrors('coverages');
        $version->refresh();
        $this->assertCount(9, $version->payload['coverages']);
        $this->assertSame('car', $version->payload['coverages'][0]['vehicleKind']);

        $invalidConditions = $nineCoverages;
        $invalidConditions[0]['pair'] = 'car|private';
        $invalidConditions[0]['rules'][0]['conditions_json'] = '[{"type":"occupants_at_least","value":0}]';
        $invalidResponse = $this->followingRedirects()->actingAs($editor)->from(route('admin.restrictions.edit', $version))->put(route('admin.restrictions.update', $version), [
            'consultation_enabled' => '1', 'coverages' => $invalidConditions,
        ]);
        $invalidResponse->assertSee('Las condiciones no cumplen el contrato schema2');
        $version->refresh();
        $this->assertCount(9, $version->payload['coverages']);
    }
}
