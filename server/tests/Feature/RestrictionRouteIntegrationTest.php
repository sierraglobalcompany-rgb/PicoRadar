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
use Illuminate\Support\Facades\Gate;
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

    public function test_off_schema2_creation_is_gate_protected_and_cannot_be_spoofed_on_post(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $offJurisdiction = $this->municipalityJurisdiction('05001', false);
        $activeJurisdiction = $this->municipalityJurisdiction('05002', true);

        $this->actingAs($editor)
            ->get(route('admin.restrictions.create', ['jurisdiction_id' => $offJurisdiction->id]))
            ->assertOk()
            ->assertSee('OFF — NO PUBLICADO')
            ->assertSee('Este borrador conserva la consulta global y todas sus modalidades apagadas')
            ->assertSee('name="coverages[__COVERAGE__][consultation_enabled]" value="1" disabled', false)
            ->assertViewHas('preselectedJurisdictionId', $offJurisdiction->id)
            ->assertViewHas('jurisdictions', fn ($jurisdictions): bool => $jurisdictions->contains('id', $activeJurisdiction->id)
                && $jurisdictions->contains('id', $offJurisdiction->id));

        Gate::define('jurisdictions.edit', static fn (User $user): bool => false);
        $this->get(route('admin.restrictions.create', ['jurisdiction_id' => $offJurisdiction->id]))
            ->assertOk()
            ->assertSee('Se requiere el permiso de edición territorial')
            ->assertDontSee('value="'.$offJurisdiction->id.'"')
            ->assertViewHas('preselectedJurisdictionId', null)
            ->assertViewHas('jurisdictions', fn ($jurisdictions): bool => ! $jurisdictions->contains('id', $offJurisdiction->id));

        $this->post(route('admin.restrictions.store'), $this->offDraftInput($offJurisdiction))
            ->assertForbidden();
        $this->assertDatabaseCount('restriction_rule_versions', 0);

        $activeInput = $this->offDraftInput($activeJurisdiction);
        $activeInput['consultation_enabled'] = '1';
        $activeInput['coverages'] = array_map(static function (array $coverage): array {
            $coverage['confirmed_no_rules'] = '1';

            return $coverage;
        }, $activeInput['coverages']);
        $this->post(route('admin.restrictions.store'), $activeInput)
            ->assertRedirect()
            ->assertSessionHasNoErrors();
        $activeVersion = RestrictionRuleVersion::query()->sole();
        $this->assertTrue($activeVersion->payload['consultationEnabled']);
        $this->assertTrue($activeVersion->payload['coverages'][0]['consultationEnabled']);
        $this->assertTrue($activeJurisdiction->fresh()->enabled);
    }

    public function test_off_schema2_post_forces_all_nine_coverages_off_partial_and_uses_primary_divipola(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $jurisdiction = $this->municipalityJurisdiction('05001', false);
        $input = $this->offDraftInput($jurisdiction);
        $input['consultation_enabled'] = '1';
        $input['coverages'] = array_map(static function (array $coverage): array {
            $coverage['consultationEnabled'] = true;
            $coverage['consultation_enabled_present'] = '1';
            $coverage['consultation_enabled'] = '1';

            return $coverage;
        }, $input['coverages']);

        $response = $this->actingAs($editor)->post(route('admin.restrictions.store'), $input);
        $version = RestrictionRuleVersion::query()->sole();
        $response->assertRedirect(route('admin.restrictions.edit', $version))->assertSessionHasNoErrors();

        $this->assertSame(2, $version->payload['schemaVersion']);
        $this->assertSame(['05001'], $version->payload['municipalityCodes']);
        $this->assertFalse($version->payload['consultationEnabled']);
        $this->assertCount(9, $version->payload['coverages']);
        $this->assertSame([
            'car|private', 'car|taxi', 'car|special', 'motorcycle|private',
            'truck|private', 'truck|public_cargo', 'bus|public_passenger',
            'bus|special', 'motocarro|private',
        ], array_map(static fn (array $coverage): string => $coverage['vehicleKind'].'|'.$coverage['serviceType'], $version->payload['coverages']));
        foreach ($version->payload['coverages'] as $coverage) {
            $this->assertFalse($coverage['consultationEnabled']);
            $this->assertSame('partial', $coverage['coverageCompleteness']);
        }
        $this->assertSame(RestrictionRuleVersionStatus::Draft, $version->status);
        $this->assertFalse($jurisdiction->fresh()->enabled);
        $this->assertNull(Dataset::query()->where('key', 'restrictions')->value('current_version'));
        $this->assertDatabaseCount('restriction_publications', 0);
    }

    public function test_schema1_rejects_off_creation_and_does_not_expose_the_option(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $jurisdiction = $this->municipalityJurisdiction('05001', false);

        $this->actingAs($editor)
            ->get(route('admin.restrictions.create', ['jurisdiction_id' => $jurisdiction->id]))
            ->assertOk()
            ->assertSee('restrictions use schema1')
            ->assertDontSee('value="'.$jurisdiction->id.'"')
            ->assertViewHas('preselectedJurisdictionId', null);

        $input = $this->offDraftInput($jurisdiction);
        $input['coverages'] = array_slice($input['coverages'], 0, 1);
        $this->post(route('admin.restrictions.store'), $input)
            ->assertSessionHasErrors('jurisdiction_id');
        $this->assertDatabaseCount('restriction_rule_versions', 0);
        $this->assertFalse($jurisdiction->fresh()->enabled);
    }

    public function test_off_schema2_requires_explicit_dates_and_https_sources(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $jurisdiction = $this->municipalityJurisdiction('05001', false);
        $input = $this->offDraftInput($jurisdiction);
        unset($input['coverages'][0]['verified_at']);

        $this->actingAs($editor)->post(route('admin.restrictions.store'), $input)
            ->assertSessionHasErrors('coverages');
        $this->assertDatabaseCount('restriction_rule_versions', 0);

        $input = $this->offDraftInput($jurisdiction);
        $input['coverages'][0]['source_urls'] = 'http://example.test/not-https';
        $this->post(route('admin.restrictions.store'), $input)
            ->assertSessionHasErrors('coverages');
        $this->assertDatabaseCount('restriction_rule_versions', 0);
    }

    public function test_editing_an_existing_off_schema2_draft_forces_global_and_coverage_consultation_off(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $jurisdiction = $this->municipalityJurisdiction('05001', false);
        $payload = [
            'schemaVersion' => 2,
            'id' => $jurisdiction->key,
            'name' => $jurisdiction->name,
            'municipalityCodes' => ['05001'],
            'consultationEnabled' => true,
            'coverages' => [[
                'vehicleKind' => 'car',
                'serviceType' => 'private',
                'coverageCompleteness' => 'complete',
                'consultationEnabled' => true,
                'verifiedAt' => '2026-11-20T08:00:00-05:00',
                'staleAfter' => '2026-12-20T00:00:00-05:00',
                'sourceUrls' => ['https://example.test/historical-source'],
                'rules' => [],
            ]],
        ];
        $version = RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id,
            'version' => 1,
            'status' => RestrictionRuleVersionStatus::Draft,
            'payload' => $payload,
            'payload_sha256' => hash('sha256', json_encode($payload)),
            'base_publication_revision' => 0,
            'created_by_id' => $editor->id,
            'updated_by_id' => $editor->id,
        ]);

        $response = $this->actingAs($editor)->get(route('admin.restrictions.edit', $version));
        $response->assertOk()
            ->assertViewHas('editable', true)
            ->assertViewHas('version', fn (RestrictionRuleVersion $formVersion): bool =>
                $formVersion->payload['consultationEnabled'] === false
                && $formVersion->payload['coverages'][0]['consultationEnabled'] === false)
            ->assertSee('name="consultation_enabled" value="0" checked', false)
            ->assertDontSee('name="consultation_enabled" value="1" checked', false);

        $input = $this->offDraftInput($jurisdiction);
        $input['consultation_enabled'] = '1';
        $input['coverages'] = array_map(static function (array $coverage): array {
            $coverage['consultationEnabled'] = true;
            $coverage['consultation_enabled_present'] = '1';
            $coverage['consultation_enabled'] = '1';

            return $coverage;
        }, $input['coverages']);
        $this->put(route('admin.restrictions.update', $version), $input)
            ->assertRedirect()
            ->assertSessionHasNoErrors();

        $saved = $version->fresh();
        $this->assertFalse($saved->payload['consultationEnabled']);
        $this->assertCount(9, $saved->payload['coverages']);
        foreach ($saved->payload['coverages'] as $coverage) {
            $this->assertFalse($coverage['consultationEnabled']);
        }
        $this->assertFalse($jurisdiction->fresh()->enabled);
        $this->assertDatabaseCount('restriction_publications', 0);
    }

    public function test_off_edit_and_duplicate_require_jurisdiction_edit_without_blocking_active_dataset_edits(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $active = $this->municipalityJurisdiction('05002', true);
        $activeInput = $this->offDraftInput($active);
        $activeInput['coverages'] = array_slice($activeInput['coverages'], 0, 1);
        $this->actingAs($editor)->post(route('admin.restrictions.store'), $activeInput)->assertRedirect()->assertSessionHasNoErrors();
        $activeVersion = RestrictionRuleVersion::query()->where('jurisdiction_id', $active->id)->firstOrFail();

        $off = $this->municipalityJurisdiction('05003', false);
        $payload = [
            'schemaVersion' => 2,
            'id' => $off->key,
            'name' => $off->name,
            'municipalityCodes' => ['05003'],
            'consultationEnabled' => false,
            'coverages' => [[
                'vehicleKind' => 'car', 'serviceType' => 'private', 'coverageCompleteness' => 'partial',
                'consultationEnabled' => false,
                'verifiedAt' => '2026-11-20T08:00:00-05:00', 'staleAfter' => '2026-12-20T00:00:00-05:00',
                'sourceUrls' => ['https://example.test/synthetic-restrictions'], 'rules' => [],
            ]],
        ];
        $offVersion = RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $off->id, 'version' => 1, 'status' => RestrictionRuleVersionStatus::Draft,
            'payload' => $payload, 'payload_sha256' => hash('sha256', json_encode($payload)),
            'base_publication_revision' => 0, 'created_by_id' => $editor->id, 'updated_by_id' => $editor->id,
        ]);

        Gate::define('jurisdictions.edit', static fn (User $user): bool => false);
        $this->get(route('admin.restrictions.edit', $offVersion))->assertOk()->assertViewHas('editable', false);
        $this->put(route('admin.restrictions.update', $offVersion), $this->offDraftInput($off))->assertForbidden();
        $this->post(route('admin.restrictions.duplicate', $offVersion))->assertForbidden();

        $this->get(route('admin.restrictions.edit', $activeVersion))->assertOk()->assertViewHas('editable', true);
        $this->put(route('admin.restrictions.update', $activeVersion), $activeInput)
            ->assertRedirect()->assertSessionHasNoErrors();
        $this->post(route('admin.restrictions.duplicate', $activeVersion))->assertRedirect();
    }

    private function municipalityJurisdiction(string $code, bool $enabled): Jurisdiction
    {
        $country = GeographicUnit::query()->create([
            'key' => 'co-off-'.$code, 'level' => GeographicUnitLevel::Country, 'code' => 'CO',
            'name' => 'Colombia sintética', 'normalized_name' => 'colombia sintetica',
            'source_system' => 'test-fixture', 'source_version' => '2026-11',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-05-off-'.$code,
            'level' => GeographicUnitLevel::Department, 'code' => '05',
            'name' => 'Antioquia sintética', 'normalized_name' => 'antioquia sintetica',
            'source_system' => 'test-fixture', 'source_version' => '2026-11',
        ]);
        $municipality = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'co-'.$code,
            'level' => GeographicUnitLevel::Municipality, 'code' => $code,
            'name' => 'Municipio sintético '.$code, 'normalized_name' => 'municipio sintetico '.$code,
            'source_system' => 'test-fixture', 'source_version' => '2026-11',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'municipio-'.$code, 'name' => $municipality->name,
            'kind' => JurisdictionKind::City, 'primary_geographic_unit_id' => $municipality->id,
            'enabled' => $enabled, 'timezone' => 'America/Bogota',
        ]);
        $jurisdiction->geographicUnits()->attach($municipality->id);

        return $jurisdiction;
    }

    /** @return array<string,mixed> */
    private function offDraftInput(Jurisdiction $jurisdiction): array
    {
        $pairs = [
            'car|private', 'car|taxi', 'car|special', 'motorcycle|private',
            'truck|private', 'truck|public_cargo', 'bus|public_passenger',
            'bus|special', 'motocarro|private',
        ];

        return [
            'jurisdiction_id' => $jurisdiction->id,
            'consultation_enabled' => '0',
            'coverages' => array_map(static fn (string $pair): array => [
                'pair' => $pair,
                'verified_at' => '2026-11-20T08:00',
                'stale_after' => '2026-12-20T00:00',
                'source_urls' => 'https://example.test/synthetic-restrictions',
                'rules' => [],
            ], $pairs),
        ];
    }
}
