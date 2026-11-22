<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Enums\RestrictionImportStatus;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Services\RestrictionImportService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;
use ZipArchive;

class RestrictionImportServiceTest extends TestCase
{
    use RefreshDatabase;

    private User $actor;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        $this->actor = User::factory()->create(['role' => OperatorRole::Editor]);
        Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $this->jurisdiction();
    }

    public function test_json_contract_is_analyzed_idempotently_and_confirmed_as_a_draft(): void
    {
        $json = json_encode(['schemaVersion' => 1, 'datasetKey' => 'restrictions', 'version' => 'synthetic-import', 'generatedAt' => '2026-09-20T12:00:00Z', 'jurisdictions' => [$this->payload()]], JSON_THROW_ON_ERROR);
        $path = $this->temporaryFile($json);
        $service = app(RestrictionImportService::class);

        $import = $service->analyze($path, 'synthetic.json', 'json', null, $this->actor);
        $same = $service->analyze($path, 'renamed.json', 'json', null, $this->actor);

        $this->assertTrue($import->is($same));
        $this->assertSame([1, 1, 0, 0], [$import->row_count, $import->valid_count, $import->invalid_count, $import->excluded_count]);
        Storage::disk('local')->assertExists($import->private_path);

        $versions = $service->confirm($import, $import->rows()->pluck('id')->all(), $this->actor);
        $this->assertCount(1, $versions);
        $this->assertSame($this->payload(), $versions[0]->payload);
        $this->assertSame(RestrictionImportStatus::Confirmed, $import->fresh()->status);
    }

    public function test_review_shows_jurisdiction_modality_and_provenance_before_confirmation(): void
    {
        $json = json_encode(['schemaVersion' => 1, 'datasetKey' => 'restrictions', 'version' => 'synthetic-review', 'generatedAt' => '2026-09-20T12:00:00Z', 'jurisdictions' => [$this->payload()]], JSON_THROW_ON_ERROR);
        $import = app(RestrictionImportService::class)->analyze($this->temporaryFile($json), 'synthetic-review.json', 'json', null, $this->actor);
        $dataset = Dataset::query()->where('key', 'restrictions')->firstOrFail();

        $this->actingAs($this->actor)
            ->get(route('admin.restrictions.imports.review', $import))
            ->assertOk()
            ->assertSeeText('Antioquia')
            ->assertSeeText('05001')
            ->assertSeeText('co-test-synthetic')
            ->assertSeeText('car')
            ->assertSeeText('private')
            ->assertSeeText('https://example.test/synthetic-rules')
            ->assertSeeText('2026-09-01T05:00:00Z')
            ->assertSeeText($import->sha256);

        $this->assertSame(RestrictionImportStatus::Analyzed, $import->fresh()->status);
        $this->assertSame(0, RestrictionRuleVersion::query()->count());
        $this->assertSame(0, $dataset->releases()->count());
        $this->assertSame(0, $dataset->fresh()->publication_revision);
    }

    public function test_partial_schema2_import_preserves_existing_off_state_rules_and_unselected_coverages(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $jurisdiction = Jurisdiction::query()->where('key', 'co-test-synthetic')->firstOrFail();
        $existing = $this->payload();
        $existing['schemaVersion'] = 2;
        $existing['municipalityCodes'] = ['05001'];
        $existing['consultationEnabled'] = false;
        $car = $existing['coverages'][0];
        $car['coverageCompleteness'] = 'partial';
        $car['consultationEnabled'] = true;
        $car['rules'][0]['conditions'] = [];
        $motorcycle = $car;
        $motorcycle['vehicleKind'] = 'motorcycle';
        $motorcycle['consultationEnabled'] = false;
        $motorcycle['rules'][0]['id'] = 'synthetic-motorcycle-rule';
        $existing['coverages'] = [$car, $motorcycle];
        app(\App\Services\RestrictionRuleVersionService::class)->createDraft($jurisdiction, $existing, $this->actor);

        $partial = $motorcycle;
        unset($partial['consultationEnabled']);
        $incoming = [
            'schemaVersion' => 2,
            'id' => $jurisdiction->key,
            'name' => $jurisdiction->name,
            'coverages' => [$partial],
        ];
        $json = json_encode([
            'schemaVersion' => 2,
            'datasetKey' => 'restrictions',
            'version' => 'synthetic-partial-toggle-import',
            'generatedAt' => '2026-09-20T12:00:00Z',
            'jurisdictions' => [$incoming],
        ], JSON_THROW_ON_ERROR);
        $import = app(RestrictionImportService::class)->analyze(
            $this->temporaryFile($json),
            'synthetic-partial-toggle.json',
            'json',
            null,
            $this->actor,
        );

        $this->assertSame(1, $import->valid_count);
        $versions = app(RestrictionImportService::class)->confirm(
            $import,
            $import->rows()->pluck('id')->all(),
            $this->actor,
        );

        $draft = $versions[0]->payload;
        $this->assertSame(false, $draft['consultationEnabled']);
        $this->assertSame(['05001'], $draft['municipalityCodes']);
        $this->assertSame(2, count($draft['coverages']));
        $byPair = [];
        foreach ($draft['coverages'] as $coverage) {
            $byPair[$coverage['vehicleKind'].'|'.$coverage['serviceType']] = $coverage;
        }
        $this->assertTrue($byPair['car|private']['consultationEnabled']);
        $this->assertFalse($byPair['motorcycle|private']['consultationEnabled']);
        $this->assertSame('synthetic-motorcycle-rule', $byPair['motorcycle|private']['rules'][0]['id']);
        $this->assertSame('partial', $byPair['motorcycle|private']['coverageCompleteness']);
    }

    public function test_csv_and_xlsx_rows_use_the_same_real_contract_mapping(): void
    {
        $header = array_keys($this->flatRow());
        $csv = implode(',', $header)."\n".implode(',', array_map(fn (string $value): string => $this->csv($value), array_values($this->flatRow())))."\n";
        $service = app(RestrictionImportService::class);

        $csvImport = $service->analyze($this->temporaryFile($csv), 'synthetic.csv', 'csv', null, $this->actor);
        $xlsxImport = $service->analyze($this->xlsx($header, array_values($this->flatRow())), 'synthetic.xlsx', 'xlsx', 'Rules', $this->actor);

        $this->assertSame(1, $csvImport->valid_count);
        $this->assertSame(1, $xlsxImport->valid_count);
        $this->assertSame($csvImport->rows()->first()->normalized, $xlsxImport->rows()->first()->normalized);
    }

    public function test_tabular_import_accepts_a_per_modality_consultation_toggle(): void
    {
        $row = $this->flatRow();
        $row['consultation_enabled'] = 'false';
        $header = array_keys($row);
        $csv = implode(',', $header)."\n".implode(',', array_map(fn (string $value): string => $this->csv($value), array_values($row)))."\n";
        $import = app(RestrictionImportService::class)->analyze(
            $this->temporaryFile($csv),
            'synthetic-toggle.csv',
            'csv',
            null,
            $this->actor,
        );

        $this->assertSame(1, $import->valid_count);
        $versions = app(RestrictionImportService::class)->confirm(
            $import,
            $import->rows()->pluck('id')->all(),
            $this->actor,
        );
        $coverage = $versions[0]->payload['coverages'][0];
        $this->assertSame(2, $versions[0]->payload['schemaVersion']);
        $this->assertFalse($coverage['consultationEnabled']);
        $this->assertSame('partial', $coverage['coverageCompleteness']);
        $this->assertSame('synthetic-rule-1', $coverage['rules'][0]['id']);
    }

    public function test_invalid_or_excluded_rows_are_never_confirmed(): void
    {
        $excluded = $this->flatRow();
        $excluded['publish'] = 'no';
        $invalid = $this->flatRow();
        $invalid['source_url'] = 'http://unsafe.test/rules';
        $json = json_encode([$excluded, $invalid], JSON_THROW_ON_ERROR);
        $import = app(RestrictionImportService::class)->analyze($this->temporaryFile($json), 'rows.json', 'json', null, $this->actor);

        $this->assertSame([0, 1, 1], [$import->valid_count, $import->invalid_count, $import->excluded_count]);
        $this->expectException(DomainException::class);
        app(RestrictionImportService::class)->confirm($import, $import->rows()->pluck('id')->all(), $this->actor);
    }

    public function test_confirmation_is_atomic_when_two_rows_for_the_same_city_conflict(): void
    {
        $first = $this->flatRow();
        $second = $first;
        $second['rule_id'] = 'synthetic-rule-2';
        $second['effect'] = 'allow';
        $import = app(RestrictionImportService::class)->analyze($this->temporaryFile(json_encode([$first, $second], JSON_THROW_ON_ERROR)), 'conflict.json', 'json', null, $this->actor);

        $this->expectException(DomainException::class);
        try {
            app(RestrictionImportService::class)->confirm($import, $import->rows()->pluck('id')->all(), $this->actor);
        } finally {
            $this->assertSame(0, RestrictionRuleVersion::query()->count());
        }
    }

    public function test_divipola_review_confirms_one_disabled_jurisdiction_per_municipality_and_is_idempotent(): void
    {
        $this->geoMunicipality('05', '05002', 'Municipio sintético 2');
        $this->geoMunicipality('05', '05003', 'Municipio sin fuente');
        $this->geoMunicipality('05', '05004', 'Municipio padre incorrecto');
        $this->geoMunicipality('08', '08001', 'Municipio sintético 8');
        $rows = [];
        $car = $this->flatRow();
        $car['jurisdiction_id'] = '';
        $car['department_code'] = '05';
        $car['municipality_code'] = '05002';
        $car['rule_id'] = 'new-car-rule';
        $rows[] = $car;
        $motorcycle = $car;
        $motorcycle['vehicle_kind'] = 'motorcycle';
        $motorcycle['rule_id'] = 'new-motorcycle-rule';
        $rows[] = $motorcycle;
        $otherDepartment = $car;
        $otherDepartment['department_code'] = '08';
        $otherDepartment['municipality_code'] = '08001';
        $otherDepartment['rule_id'] = 'other-department-rule';
        $rows[] = $otherDepartment;
        $existing = $this->flatRow();
        $existing['department_code'] = '05';
        $existing['municipality_code'] = '05001';
        $rows[] = $existing;
        $missingSource = $car;
        $missingSource['municipality_code'] = '05003';
        $missingSource['source_url'] = '';
        $rows[] = $missingSource;
        $wrongParent = $car;
        $wrongParent['department_code'] = '08';
        $wrongParent['municipality_code'] = '05004';
        $rows[] = $wrongParent;

        $header = array_keys($rows[0]);
        $csv = implode(',', $header)."\n";
        foreach ($rows as $row) {
            $csv .= implode(',', array_map($this->csv(...), array_values($row)))."\n";
        }
        $service = app(RestrictionImportService::class);
        $jurisdictionsBefore = Jurisdiction::query()->count();
        $geographyBefore = GeographicUnit::query()->count();
        $import = $service->analyze($this->temporaryFile($csv), 'synthetic-divipola.csv', 'csv', null, $this->actor);

        $this->assertSame([6, 4, 2, 0], [$import->row_count, $import->valid_count, $import->invalid_count, $import->excluded_count]);
        $this->assertSame($jurisdictionsBefore, Jurisdiction::query()->count(), 'Analyze must not create jurisdictions.');
        $this->assertSame($geographyBefore, GeographicUnit::query()->count(), 'Analyze must not write canonical geography.');
        $this->assertSame(3, $import->report['onboarding']['new']);
        $this->assertSame(1, $import->report['onboarding']['existing']);
        $this->assertSame('ALTA_PROPUESTA', $import->rows()->where('row_number', 1)->firstOrFail()->normalized['onboarding']['status']);
        $this->assertSame('EXISTENTE', $import->rows()->where('row_number', 4)->firstOrFail()->normalized['onboarding']['status']);

        $this->actingAs($this->actor)->get(route('admin.restrictions.imports.review', $import))
            ->assertOk()
            ->assertSeeText('Alta propuesta')
            ->assertSeeText('Municipio sintético 2')
            ->assertSeeText('https://example.test/synthetic-rules')
            ->assertSeeText('2026-09-01T05:00:00Z')
            ->assertSeeText('Department and municipality DIVIPOLA codes must be valid and match.');

        $selected = $import->rows()->where('state', 'valid')->pluck('id')->all();
        $versions = $service->confirm($import, $selected, $this->actor);
        $this->assertCount(3, $versions);
        $this->assertSame(3, RestrictionRuleVersion::query()->count());
        $this->assertSame($jurisdictionsBefore + 2, Jurisdiction::query()->count());
        foreach (['05002', '08001'] as $code) {
            $jurisdiction = Jurisdiction::query()->where('key', 'municipio-'.$code)->firstOrFail();
            $this->assertFalse($jurisdiction->enabled);
            $version = collect($versions)->first(fn (RestrictionRuleVersion $candidate): bool => $candidate->jurisdiction_id === $jurisdiction->id);
            $this->assertNotNull($version);
            $this->assertSame([$code], $version->payload['municipalityCodes']);
        }
        $newMunicipalityVersion = collect($versions)->first(fn (RestrictionRuleVersion $version): bool => $version->jurisdiction_id === Jurisdiction::query()->where('key', 'municipio-05002')->value('id'));
        $this->assertFalse($newMunicipalityVersion->payload['consultationEnabled']);
        $this->assertSame(['05002'], $newMunicipalityVersion->payload['municipalityCodes']);
        $this->assertCount(2, $newMunicipalityVersion->payload['coverages']);
        foreach ($newMunicipalityVersion->payload['coverages'] as $coverage) {
            $this->assertFalse($coverage['consultationEnabled']);
            $this->assertSame('partial', $coverage['coverageCompleteness']);
        }
        $this->assertSame(0, $import->rows()->whereIn('row_number', [1, 2, 3, 4])->whereNull('jurisdiction_id')->count());

        $again = $service->confirm($import, $selected, $this->actor);
        $this->assertSame(collect($versions)->pluck('id')->all(), collect($again)->pluck('id')->all());
        $this->assertSame(3, RestrictionRuleVersion::query()->count());
        $this->assertSame(3, Jurisdiction::query()->count());
        $this->assertSame(2, count($import->fresh()->report['confirmation']['created_jurisdictions']));
    }

    public function test_schema2_json_new_municipality_is_canonicalized_and_multiple_codes_require_manual_assignment(): void
    {
        $this->geoMunicipality('05', '05002', 'Municipio sintético 2');
        $city = $this->payload();
        $city['id'] = 'file-provided-id';
        $city['name'] = 'Nombre no canónico';
        $city['schemaVersion'] = 2;
        $city['municipalityCodes'] = ['05002'];
        $city['consultationEnabled'] = true;
        $city['coverages'][0]['coverageCompleteness'] = 'complete';
        $city['coverages'][0]['consultationEnabled'] = true;
        $city['coverages'][0]['rules'][0]['conditions'] = [];
        $document = ['schemaVersion' => 2, 'datasetKey' => 'restrictions', 'version' => 'synthetic-json-onboarding', 'generatedAt' => '2026-11-21T12:00:00Z', 'jurisdictions' => [$city]];
        $service = app(RestrictionImportService::class);
        $import = $service->analyze($this->temporaryFile(json_encode($document, JSON_THROW_ON_ERROR)), 'new-city.json', 'json', null, $this->actor);
        $row = $import->rows()->firstOrFail();

        $this->assertSame('valid', $row->state);
        $this->assertNull($row->jurisdiction_id);
        $this->assertSame('municipio-05002', $row->normalized['payload']['id']);
        $this->assertSame('Municipio sintético 2', $row->normalized['payload']['name']);
        $this->assertFalse($row->normalized['payload']['consultationEnabled']);
        $this->assertFalse($row->normalized['payload']['coverages'][0]['consultationEnabled']);
        $this->assertSame('partial', $row->normalized['payload']['coverages'][0]['coverageCompleteness']);
        $this->assertSame(1, Jurisdiction::query()->count());

        $city['municipalityCodes'] = ['05001', '05002'];
        sort($city['municipalityCodes']);
        $manualDoc = [...$document, 'version' => 'synthetic-json-manual', 'jurisdictions' => [$city]];
        $manual = $service->analyze($this->temporaryFile(json_encode($manualDoc, JSON_THROW_ON_ERROR)), 'multi-city.json', 'json', null, $this->actor);
        $manualRow = $manual->rows()->firstOrFail();
        $this->assertSame('invalid', $manualRow->state);
        $this->assertSame('REQUIERE_ASIGNACION_MANUAL', $manualRow->normalized['onboarding']['status']);
        $this->assertNull($manualRow->jurisdiction_id);
        $this->assertSame(1, Jurisdiction::query()->count());
    }

    public function test_schema2_proposal_rebinds_identity_when_confirmation_reuses_a_new_registration(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $unit = $this->geoMunicipality('05', '05002', 'Municipio sintético 2');
        $city = $this->payload();
        $city['id'] = 'file-provided-id';
        $city['name'] = 'Nombre no canónico';
        $city['schemaVersion'] = 2;
        $city['municipalityCodes'] = ['05002'];
        $city['consultationEnabled'] = true;
        $city['coverages'][0]['coverageCompleteness'] = 'complete';
        $city['coverages'][0]['consultationEnabled'] = true;
        $city['coverages'][0]['rules'][0]['conditions'] = [];
        $document = ['schemaVersion' => 2, 'datasetKey' => 'restrictions', 'version' => 'synthetic-race-rebind', 'generatedAt' => '2026-11-21T12:00:00Z', 'jurisdictions' => [$city]];
        $service = app(RestrictionImportService::class);
        $import = $service->analyze($this->temporaryFile(json_encode($document, JSON_THROW_ON_ERROR)), 'race-rebind.json', 'json', null, $this->actor);
        $row = $import->rows()->firstOrFail();
        $this->assertSame('valid', $row->state);
        $this->assertSame('ALTA_PROPUESTA', $row->normalized['onboarding']['status']);

        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'editorial-05002',
            'name' => 'Nombre editorial existente',
            'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id,
            'enabled' => true,
            'timezone' => 'America/Bogota',
        ]);
        $existingPayload = $city;
        $existingPayload['id'] = $jurisdiction->key;
        $existingPayload['name'] = $jurisdiction->name;
        app(\App\Services\RestrictionRuleVersionService::class)->createDraft($jurisdiction, $existingPayload, $this->actor);

        $versions = $service->confirm($import, [$row->id], $this->actor);

        $this->assertCount(1, $versions);
        $this->assertSame($jurisdiction->key, $versions[0]->payload['id']);
        $this->assertSame($jurisdiction->name, $versions[0]->payload['name']);
        $this->assertTrue($versions[0]->payload['consultationEnabled']);
        $this->assertTrue($versions[0]->payload['coverages'][0]['consultationEnabled']);
        $this->assertSame($jurisdiction->id, $row->fresh()->jurisdiction_id);
        $this->assertSame(2, Jurisdiction::query()->count());
        $this->assertSame(2, RestrictionRuleVersion::query()->count());
    }

    public function test_schema2_proposal_rejects_embedded_credentials_in_any_source_url(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $this->geoMunicipality('05', '05002', 'Municipio sintético 2');
        $city = $this->payload();
        $city['id'] = 'file-provided-id';
        $city['schemaVersion'] = 2;
        $city['municipalityCodes'] = ['05002'];
        $city['coverages'][0]['rules'][0]['conditions'] = [];
        $city['coverages'][0]['sourceUrls'][] = 'https://user:password@example.test/private-rules';
        $document = ['schemaVersion' => 2, 'datasetKey' => 'restrictions', 'version' => 'synthetic-credential-url', 'generatedAt' => '2026-11-21T12:00:00Z', 'jurisdictions' => [$city]];
        $import = app(RestrictionImportService::class)->analyze(
            $this->temporaryFile(json_encode($document, JSON_THROW_ON_ERROR)),
            'credential-url.json',
            'json',
            null,
            $this->actor,
        );
        $row = $import->rows()->firstOrFail();

        $this->assertSame('invalid', $row->state);
        $this->assertStringContainsString('embedded credentials', $row->errors[0]);
        $this->assertSame(1, Jurisdiction::query()->count());
        $this->assertSame(0, RestrictionRuleVersion::query()->count());
    }

    public function test_confirmation_rechecks_onboarding_urls_for_embedded_credentials(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $this->geoMunicipality('05', '05002', 'Municipio sintético 2');
        $city = $this->payload();
        $city['id'] = 'file-provided-id';
        $city['schemaVersion'] = 2;
        $city['municipalityCodes'] = ['05002'];
        $city['coverages'][0]['rules'][0]['conditions'] = [];
        $document = ['schemaVersion' => 2, 'datasetKey' => 'restrictions', 'version' => 'synthetic-confirm-credential-url', 'generatedAt' => '2026-11-21T12:00:00Z', 'jurisdictions' => [$city]];
        $service = app(RestrictionImportService::class);
        $import = $service->analyze($this->temporaryFile(json_encode($document, JSON_THROW_ON_ERROR)), 'confirm-credential-url.json', 'json', null, $this->actor);
        $row = $import->rows()->firstOrFail();
        $normalized = $row->normalized;
        $normalized['onboarding']['source']['urls'][] = 'https://user:password@example.test/private-rules';
        $row->normalized = $normalized;
        $row->save();

        try {
            $service->confirm($import, [$row->id], $this->actor);
            $this->fail('Confirmation accepted embedded source credentials.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('embedded credentials', $error->getMessage());
        }

        $this->assertSame(1, Jurisdiction::query()->count());
        $this->assertSame(0, RestrictionRuleVersion::query()->count());
    }

    public function test_existing_rule_conditions_are_preserved_and_material_rule_id_conflicts_are_review_errors(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $jurisdiction = Jurisdiction::query()->where('key', 'co-test-synthetic')->firstOrFail();
        $existing = $this->payload();
        $existing['schemaVersion'] = 2;
        $existing['municipalityCodes'] = ['05001'];
        $existing['consultationEnabled'] = false;
        $existing['coverages'][0]['coverageCompleteness'] = 'partial';
        $existing['coverages'][0]['consultationEnabled'] = false;
        $existing['coverages'][0]['rules'][0]['conditions'] = [['type' => 'pillion_present', 'value' => true]];
        app(\App\Services\RestrictionRuleVersionService::class)->createDraft($jurisdiction, $existing, $this->actor);

        $newRule = $this->flatRow();
        $newRule['department_code'] = '05';
        $newRule['municipality_code'] = '05001';
        $newRule['rule_id'] = 'synthetic-rule-2';
        $import = app(RestrictionImportService::class)->analyze($this->temporaryFile(json_encode([$newRule], JSON_THROW_ON_ERROR)), 'preserve-existing-rule.json', 'json', null, $this->actor);
        $version = app(RestrictionImportService::class)->confirm($import, $import->rows()->pluck('id')->all(), $this->actor)[0];
        $rules = $version->payload['coverages'][0]['rules'];
        $this->assertCount(2, $rules);
        $this->assertSame([['type' => 'pillion_present', 'value' => true]], $rules[0]['conditions']);
        $this->assertFalse($version->payload['coverages'][0]['consultationEnabled']);

        $conflicting = $this->flatRow();
        $conflicting['jurisdiction_id'] = '';
        $conflicting['department_code'] = '05';
        $conflicting['municipality_code'] = '05001';
        $conflicting['effect'] = 'allow';
        $conflictImport = app(RestrictionImportService::class)->analyze($this->temporaryFile(json_encode([$conflicting], JSON_THROW_ON_ERROR)), 'material-conflict.json', 'json', null, $this->actor);
        $conflictRow = $conflictImport->rows()->firstOrFail();
        $this->assertSame('invalid', $conflictRow->state);
        $this->assertStringContainsString('Material conflict', $conflictRow->errors[0]);
        $this->assertSame(2, RestrictionRuleVersion::query()->count());
    }

    public function test_new_schema2_modality_is_forced_off_and_partial_without_changing_existing_coverage(): void
    {
        Dataset::query()->where('key', 'restrictions')->update(['schema_version' => 2]);
        $jurisdiction = Jurisdiction::query()->where('key', 'co-test-synthetic')->firstOrFail();
        $existing = $this->payload();
        $existing['schemaVersion'] = 2;
        $existing['municipalityCodes'] = ['05001'];
        $existing['consultationEnabled'] = false;
        $existing['coverages'][0]['coverageCompleteness'] = 'partial';
        $existing['coverages'][0]['consultationEnabled'] = true;
        $existing['coverages'][0]['rules'][0]['conditions'] = [];
        app(\App\Services\RestrictionRuleVersionService::class)->createDraft($jurisdiction, $existing, $this->actor);

        $newCoverage = $existing['coverages'][0];
        $newCoverage['vehicleKind'] = 'motorcycle';
        $newCoverage['coverageCompleteness'] = 'complete';
        $newCoverage['consultationEnabled'] = true;
        $newCoverage['rules'][0]['id'] = 'new-modality-rule';
        $city = [
            'schemaVersion' => 2,
            'id' => $jurisdiction->key,
            'name' => $jurisdiction->name,
            'municipalityCodes' => ['05001'],
            'consultationEnabled' => false,
            'coverages' => [$newCoverage],
        ];
        $import = app(RestrictionImportService::class)->analyze(
            $this->temporaryFile(json_encode(['schemaVersion' => 2, 'datasetKey' => 'restrictions', 'version' => 'new-modality-off', 'generatedAt' => '2026-11-21T12:00:00Z', 'jurisdictions' => [$city]], JSON_THROW_ON_ERROR)),
            'new-modality.json',
            'json',
            null,
            $this->actor,
        );
        $review = $import->rows()->firstOrFail();
        $this->assertSame('valid', $review->state);
        $this->assertFalse($review->normalized['payload']['coverages'][0]['consultationEnabled']);
        $this->assertSame('partial', $review->normalized['payload']['coverages'][0]['coverageCompleteness']);

        $version = app(RestrictionImportService::class)->confirm($import, [$review->id], $this->actor)[0];
        $coverages = collect($version->payload['coverages'])->keyBy('vehicleKind');
        $this->assertCount(2, $coverages);
        $this->assertTrue($coverages->get('car')['consultationEnabled']);
        $this->assertFalse($coverages->get('motorcycle')['consultationEnabled']);
        $this->assertSame('partial', $coverages->get('motorcycle')['coverageCompleteness']);
    }

    public function test_reviewer_cannot_confirm_a_municipality_proposal(): void
    {
        $this->geoMunicipality('05', '05002', 'Municipio sintético 2');
        $row = $this->flatRow();
        $row['jurisdiction_id'] = '';
        $row['department_code'] = '05';
        $row['municipality_code'] = '05002';
        $import = app(RestrictionImportService::class)->analyze($this->temporaryFile(json_encode([$row], JSON_THROW_ON_ERROR)), 'permission-gate.json', 'json', null, $this->actor);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);

        $this->actingAs($reviewer)->post(route('admin.restrictions.imports.confirm', $import), ['rows' => [$import->rows()->value('id')]])
            ->assertForbidden();
        $this->assertSame(1, Jurisdiction::query()->count());
        $this->assertSame(0, RestrictionRuleVersion::query()->count());
    }

    public function test_ambiguous_municipality_requires_an_explicit_existing_jurisdiction_id(): void
    {
        $municipality = GeographicUnit::query()->where('code', '05001')->firstOrFail();
        $candidate = Jurisdiction::query()->create([
            'key' => 'co-test-synthetic-alternative',
            'name' => 'Jurisdicción alternativa sintética',
            'kind' => 'city',
            'primary_geographic_unit_id' => $municipality->id,
            'enabled' => false,
            'timezone' => 'America/Bogota',
        ]);
        $row = $this->flatRow();
        $row['jurisdiction_id'] = '';
        $row['department_code'] = '05';
        $row['municipality_code'] = '05001';
        $service = app(RestrictionImportService::class);
        $ambiguous = $service->analyze($this->temporaryFile(json_encode([$row], JSON_THROW_ON_ERROR)), 'ambiguous.json', 'json', null, $this->actor);
        $ambiguousRow = $ambiguous->rows()->firstOrFail();
        $this->assertSame('invalid', $ambiguousRow->state);
        $this->assertSame('REQUIERE_ASIGNACION_MANUAL', $ambiguousRow->normalized['onboarding']['status']);
        $this->assertCount(2, $ambiguousRow->normalized['onboarding']['candidate_jurisdictions']);
        $this->assertSame(0, RestrictionRuleVersion::query()->count());

        $row['jurisdiction_id'] = $candidate->key;
        $selected = $service->analyze($this->temporaryFile(json_encode([$row], JSON_THROW_ON_ERROR)), 'manual-selection.json', 'json', null, $this->actor);
        $selectedRow = $selected->rows()->firstOrFail();
        $this->assertSame('valid', $selectedRow->state);
        $this->assertSame('EXISTENTE', $selectedRow->normalized['onboarding']['status']);
        $this->assertSame($candidate->id, $selectedRow->jurisdiction_id);

        $versions = $service->confirm($selected, [$selectedRow->id], $this->actor);
        $this->assertCount(1, $versions);
        $this->assertSame(2, Jurisdiction::query()->count());
        $this->assertFalse($candidate->fresh()->enabled);
    }

    /** @return array<string,string> */
    private function flatRow(): array
    {
        return [
            'jurisdiction_id' => 'co-test-synthetic', 'jurisdiction_name' => 'Ciudad sintética',
            'vehicle_kind' => 'car', 'service_type' => 'private', 'rule_id' => 'synthetic-rule-1',
            'priority' => '100', 'effect' => 'restrict', 'valid_from' => '2026-09-01T00:00:00-05:00',
            'valid_until' => '2026-12-31T23:59:59-05:00', 'weekdays' => '[1]', 'date_parity' => '',
            'digit_position' => 'lastNumeric', 'digits' => '[1,2]',
            'time_windows' => '[{"startMinute":360,"endMinute":1200}]', 'applies_on_holidays' => 'false',
            'source_url' => 'https://example.test/synthetic-rules', 'verified_at' => '2026-09-01T05:00:00Z',
            'stale_after' => '2027-01-15T05:00:00Z', 'publish' => 'yes',
        ];
    }

    /** @return array<string,mixed> */
    private function payload(): array
    {
        return [
            'id' => 'co-test-synthetic', 'name' => 'Ciudad sintética',
            'coverages' => [[
                'vehicleKind' => 'car', 'serviceType' => 'private', 'verifiedAt' => '2026-09-01T05:00:00Z',
                'staleAfter' => '2027-01-15T05:00:00Z', 'sourceUrls' => ['https://example.test/synthetic-rules'],
                'rules' => [[
                    'id' => 'synthetic-rule-1', 'priority' => 100, 'effect' => 'restrict',
                    'validFrom' => '2026-09-01T00:00:00-05:00', 'validUntil' => '2026-12-31T23:59:59-05:00',
                    'weekdays' => [1], 'digitPosition' => 'lastNumeric', 'digits' => [1, 2],
                    'timeWindows' => [['startMinute' => 360, 'endMinute' => 1200]],
                    'appliesOnHolidays' => false, 'sourceUrl' => 'https://example.test/synthetic-rules',
                    'verifiedAt' => '2026-09-01T05:00:00Z',
                ]],
            ]],
        ];
    }

    private function jurisdiction(): void
    {
        $country = GeographicUnit::query()->create(['key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $department = GeographicUnit::query()->create(['parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05', 'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $municipality = GeographicUnit::query()->create(['parent_id' => $department->id, 'key' => 'co-05001', 'level' => 'municipality', 'code' => '05001', 'name' => 'Ciudad sintética', 'normalized_name' => 'ciudad sintetica', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        Jurisdiction::query()->create(['key' => 'co-test-synthetic', 'name' => 'Ciudad sintética', 'kind' => 'city', 'primary_geographic_unit_id' => $municipality->id, 'enabled' => true, 'timezone' => 'America/Bogota']);
    }

    private function geoMunicipality(string $departmentCode, string $municipalityCode, string $name): GeographicUnit
    {
        $country = GeographicUnit::query()->where('level', 'country')->firstOrFail();
        $department = GeographicUnit::query()->where('code', $departmentCode)->first();
        if (! $department) {
            $department = GeographicUnit::query()->create([
                'parent_id' => $country->id,
                'key' => 'co-'.$departmentCode,
                'level' => 'department',
                'code' => $departmentCode,
                'name' => 'Departamento '.$departmentCode,
                'normalized_name' => 'departamento '.$departmentCode,
                'is_active' => true,
                'source_system' => 'synthetic',
                'source_version' => 'v1',
            ]);
        }

        return GeographicUnit::query()->create([
            'parent_id' => $department->id,
            'key' => 'co-'.$municipalityCode,
            'level' => 'municipality',
            'code' => $municipalityCode,
            'name' => $name,
            'normalized_name' => strtolower(str_replace(' ', '-', $name)),
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'v1',
        ]);
    }

    private function temporaryFile(string $contents): string
    {
        $path = tempnam(sys_get_temp_dir(), 'restriction-import-');
        file_put_contents($path, $contents);

        return $path;
    }

    private function csv(string $value): string
    {
        return '"'.str_replace('"', '""', $value).'"';
    }

    /** @param list<string> $header @param list<string> $row */
    private function xlsx(array $header, array $row): string
    {
        $path = tempnam(sys_get_temp_dir(), 'restriction-xlsx-');
        $zip = new ZipArchive;
        $zip->open($path, ZipArchive::OVERWRITE);
        $zip->addFromString('[Content_Types].xml', '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>');
        $zip->addFromString('xl/workbook.xml', '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Rules" sheetId="1" r:id="rId1"/></sheets></workbook>');
        $zip->addFromString('xl/_rels/workbook.xml.rels', '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>');
        $rows = [$header, $row];
        $xmlRows = '';
        foreach ($rows as $rowIndex => $cells) {
            $xmlRows .= '<row r="'.($rowIndex + 1).'">';
            foreach ($cells as $column => $value) {
                $reference = $this->column($column + 1).($rowIndex + 1);
                $xmlRows .= '<c r="'.$reference.'" t="inlineStr"><is><t>'.htmlspecialchars($value, ENT_XML1).'</t></is></c>';
            }
            $xmlRows .= '</row>';
        }
        $zip->addFromString('xl/worksheets/sheet1.xml', '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'.$xmlRows.'</sheetData></worksheet>');
        $zip->close();

        return $path;
    }

    private function column(int $number): string
    {
        $result = '';
        while ($number > 0) {
            $number--;
            $result = chr(65 + ($number % 26)).$result;
            $number = intdiv($number, 26);
        }

        return $result;
    }
}
