<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Models\AuditLog;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Services\DatasetPublisher;
use App\Services\DatasetReleaseValidator;
use App\Services\RestrictionImportService;
use App\Services\RestrictionPayloadEncoder;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RestrictionSchemaV2LabRoundTripTest extends TestCase
{
    use RefreshDatabase;

    private User $actor;

    private Dataset $dataset;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(\Carbon\CarbonImmutable::parse('2026-11-19T12:00:00Z'));
        Storage::fake('local');
        Storage::fake('public');
        $this->actor = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Synthetic restrictions',
            'schema_version' => 2, 'enabled' => true,
        ]);
        $this->dataset->sources()->create([
            'title' => 'Synthetic G2 fixture', 'authority' => 'NON_OFFICIAL_TEST_SOURCE',
            'url' => 'https://example.test/g2-synthetic', 'verified_at' => now(), 'is_active' => true,
        ]);

        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia',
            'normalized_name' => 'colombia', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'g2',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-99', 'level' => 'department',
            'code' => '99', 'name' => 'Departamento sintético',
            'normalized_name' => 'departamento sintetico', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'g2',
        ]);
        $municipality = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'co-99001', 'level' => 'municipality',
            'code' => '99001', 'name' => 'Ciudad sintética',
            'normalized_name' => 'ciudad sintetica', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'g2',
        ]);
        Jurisdiction::query()->create([
            'key' => 'co-g2-synthetic', 'name' => 'Ciudad sintética', 'kind' => 'city',
            'primary_geographic_unit_id' => $municipality->id, 'enabled' => true,
            'timezone' => 'America/Bogota',
        ]);
    }

    public function test_schema2_import_confirm_validate_publish_emits_matching_release_and_manifest_bytes(): void
    {
        $evidenceDirectory = getenv('PICORADAR_G2_EVIDENCE_DIR');
        self::assertIsString($evidenceDirectory);
        self::assertNotSame('', $evidenceDirectory);
        self::assertDirectoryExists($evidenceDirectory);

        $invalid = $this->payload();
        $invalid['jurisdictions'][0]['coverages'][0]['rules'][0]['conditions'][] = [
            'type' => 'future_operator', 'value' => true,
        ];
        $invalidImport = $this->analyze($invalid, 'invalid-schema2.json');
        self::assertSame(1, $invalidImport->invalid_count);
        self::assertSame(0, $this->dataset->releases()->count());

        $payload = $this->payload();
        $inputBytes = json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        $import = $this->analyze($payload, 'valid-schema2.json');
        self::assertSame([1, 0], [$import->valid_count, $import->invalid_count]);
        self::assertSame(0, $this->dataset->releases()->count(), 'Analyze must not publish.');

        $versions = app(RestrictionImportService::class)->confirm(
            $import,
            $import->rows()->pluck('id')->all(),
            $this->actor,
        );
        self::assertCount(1, $versions);
        self::assertSame(2, $versions[0]->payload['schemaVersion']);
        self::assertSame('partial', $versions[0]->payload['coverages'][0]['coverageCompleteness']);
        self::assertSame($payload['jurisdictions'][0]['coverages'][0]['rules'][0]['conditions'], $versions[0]->payload['coverages'][0]['rules'][0]['conditions']);

        $version = app(RestrictionRuleVersionService::class)->validate($versions[0], $this->actor);
        self::assertSame(2, $version->payload['schemaVersion']);
        $release = $this->publishWithEditorialApproval($version, 0);
        $releaseBytes = Storage::disk('public')->get($release->asset_path);
        $manifestBytes = Storage::disk('public')->get(config('datasets.manifest_path'));
        self::assertSame(2, json_decode($releaseBytes, true, 512, JSON_THROW_ON_ERROR)['schemaVersion']);
        self::assertSame(2, json_decode($releaseBytes, true, 512, JSON_THROW_ON_ERROR)['jurisdictions'][0]['schemaVersion']);
        self::assertSame(1, $this->dataset->refresh()->publication_revision);

        $manifest = json_decode($manifestBytes, true, 512, JSON_THROW_ON_ERROR);
        $entry = $manifest['datasets']['restrictions'];
        $releaseSha = hash('sha256', $releaseBytes);
        self::assertSame($releaseSha, $release->sha256);
        self::assertSame($releaseSha, $entry['sha256']);
        self::assertSame($release->version, $entry['version']);
        self::assertSame($releaseBytes, file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_REAL_LAB_RELEASE.json', $releaseBytes) === strlen($releaseBytes)
            ? file_get_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_REAL_LAB_RELEASE.json')
            : false);
        self::assertSame($manifestBytes, file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_REAL_LAB_MANIFEST.json', $manifestBytes) === strlen($manifestBytes)
            ? file_get_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_REAL_LAB_MANIFEST.json')
            : false);
        file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_INPUT_SHA256.txt', hash('sha256', $inputBytes)."\n");
    }

    public function test_schema2_editorial_envelope_accepts_legacy_and_v2_city_rows(): void
    {
        $r2Path = getenv('PICORADAR_G2_R2_RELEASE');
        self::assertIsString($r2Path);
        self::assertNotSame('', $r2Path, 'The exact R2 release is required; R4 is not a substitute.');
        $r2Bytes = file_get_contents($r2Path);
        self::assertIsString($r2Bytes);
        self::assertSame('c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5', hash('sha256', $r2Bytes));
        $r2 = json_decode($r2Bytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertCount(7, $r2['jurisdictions']);
        self::assertSame(12, $this->coverageCount($r2));

        $legacyCity = $r2['jurisdictions'][0];
        $this->createJurisdiction($legacyCity['id'], $legacyCity['name'], 99002);
        $mixed = [
            'schemaVersion' => 2,
            'datasetKey' => 'restrictions',
            'version' => 'G2_V3_MIXED_IMPORT_TEST',
            'generatedAt' => '2026-11-10T00:00:00Z',
            'jurisdictions' => [$legacyCity, $this->payload()['jurisdictions'][0]],
        ];
        $import = $this->analyze($mixed, 'mixed-schema2-legacy-v2.json');

        self::assertSame(2, $import->valid_count);
        self::assertSame(0, $import->invalid_count);
        self::assertSame(0, $import->excluded_count);
        self::assertSame(0, $this->dataset->releases()->count(), 'Analyze must not publish.');
        $normalized = $import->rows()->orderBy('row_number')->get();
        self::assertArrayNotHasKey('schemaVersion', $normalized[0]->normalized['payload']);
        self::assertSame(2, $normalized[1]->normalized['payload']['schemaVersion']);

        $invalidCityVersion = $mixed;
        $invalidCityVersion['jurisdictions'][0]['schemaVersion'] = null;
        try {
            $this->analyze($invalidCityVersion, 'null-city-schema-version.json');
            self::fail('An explicit null city schemaVersion was accepted.');
        } catch (DomainException $error) {
            self::assertStringContainsString('schemaVersion does not match', $error->getMessage());
        }

        $invalidEnvelopeVersion = $mixed;
        $invalidEnvelopeVersion['schemaVersion'] = null;
        try {
            $this->analyze($invalidEnvelopeVersion, 'null-envelope-schema-version.json');
            self::fail('An explicit null envelope schemaVersion was accepted.');
        } catch (DomainException $error) {
            self::assertStringContainsString('envelope is invalid', $error->getMessage());
        }
    }

    public function test_schema2_dataset_publishes_one_v2_city_without_changing_seven_r2_legacy_cities(): void
    {
        $r2Path = getenv('PICORADAR_G2_R2_RELEASE');
        self::assertIsString($r2Path);
        self::assertNotSame('', $r2Path, 'The exact R2 release is required; R4 is not a substitute.');
        $r2Bytes = file_get_contents($r2Path);
        self::assertIsString($r2Bytes);
        self::assertSame('c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5', hash('sha256', $r2Bytes));
        $r2 = json_decode($r2Bytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertSame(1, $r2['schemaVersion']);
        self::assertCount(7, $r2['jurisdictions']);
        self::assertSame(12, $this->coverageCount($r2));

        $baseline = $r2;
        $baseline['schemaVersion'] = 2;
        $baseline['version'] = 'g2-v3-mixed-baseline';
        $baseline['generatedAt'] = '2026-11-10T00:00:00Z';
        $baselineBytes = json_encode($baseline, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)."\n";
        $baselinePath = 'dataset-drafts/restrictions/'.$baseline['version'].'.json';
        Storage::disk('local')->put($baselinePath, $baselineBytes);
        $baselineRelease = $this->dataset->releases()->create([
            'version' => $baseline['version'],
            'status' => DatasetReleaseStatus::Draft,
            'draft_path' => $baselinePath,
        ]);
        $baselineRelease = app(DatasetReleaseValidator::class)->validate($baselineRelease, $this->actor);
        app(DatasetPublisher::class)->publish($baselineRelease, $this->actor);
        self::assertSame(1, $this->dataset->refresh()->publication_revision);

        $import = $this->analyze($this->payload(), 'single-v2-synthetic-city.json');
        self::assertSame([1, 0, 0], [$import->valid_count, $import->invalid_count, $import->excluded_count]);
        self::assertSame(1, $this->dataset->releases()->count(), 'Analyze must not create a release.');
        $drafts = app(RestrictionImportService::class)->confirm(
            $import,
            $import->rows()->pluck('id')->all(),
            $this->actor,
        );
        self::assertCount(1, $drafts);
        $version = app(RestrictionRuleVersionService::class)->validate($drafts[0], $this->actor);
        $release = $this->publishWithEditorialApproval($version, 1);
        $releaseBytes = Storage::disk('public')->get($release->asset_path);
        $manifestBytes = Storage::disk('public')->get(config('datasets.manifest_path'));
        $published = json_decode($releaseBytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertSame(2, $published['schemaVersion']);
        self::assertCount(8, $published['jurisdictions']);
        self::assertSame(13, $this->coverageCount($published));

        $publishedById = [];
        foreach ($published['jurisdictions'] as $city) {
            $publishedById[$city['id']] = $city;
        }
        foreach ($r2['jurisdictions'] as $legacyCity) {
            self::assertArrayNotHasKey('schemaVersion', $legacyCity);
            self::assertSame(
                $this->canonical($legacyCity),
                $this->canonical($publishedById[$legacyCity['id']]),
                'Every R2 legacy city must remain structurally unchanged: '.$legacyCity['id'],
            );
        }
        self::assertSame(2, $publishedById['co-g2-synthetic']['schemaVersion']);
        self::assertSame('partial', $publishedById['co-g2-synthetic']['coverages'][0]['coverageCompleteness']);
        self::assertSame(2, $this->dataset->refresh()->publication_revision);

        $manifest = json_decode($manifestBytes, true, 512, JSON_THROW_ON_ERROR);
        $entry = $manifest['datasets']['restrictions'];
        $releaseSha = hash('sha256', $releaseBytes);
        self::assertSame($releaseSha, $release->sha256);
        self::assertSame($releaseSha, $entry['sha256']);
        self::assertSame($release->version, $entry['version']);

        $evidenceDirectory = getenv('PICORADAR_G2_V3_EVIDENCE_DIR');
        self::assertIsString($evidenceDirectory);
        self::assertNotSame('', $evidenceDirectory);
        self::assertDirectoryExists($evidenceDirectory);
        self::assertSame(strlen($releaseBytes), file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_V3_REAL_LAB_RELEASE.json', $releaseBytes));
        self::assertSame(strlen($manifestBytes), file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_V3_REAL_LAB_MANIFEST.json', $manifestBytes));
        self::assertSame(strlen($r2Bytes), file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'FIXTURE_R2_SCHEMA1_RELEASE.json', $r2Bytes));
        file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_V3_INPUT_SHA256.txt', hash('sha256', $this->encoder()->encode($this->payload()))."\n");
        file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G2_V3_RESULT.json', json_encode([
            'classification' => 'LAB_SYNTHETIC_NOT_FOR_RELEASE',
            'baselineR2Sha256' => hash('sha256', $r2Bytes),
            'releaseSha256' => $releaseSha,
            'manifestReleaseSha256' => $entry['sha256'],
            'jurisdictions' => count($published['jurisdictions']),
            'coverages' => $this->coverageCount($published),
            'legacyJurisdictionsPreserved' => count($r2['jurisdictions']),
            'legacyCoveragesPreserved' => $this->coverageCount($r2),
            'syntheticJurisdiction' => 'co-g2-synthetic',
        ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
    }

    public function test_schema1_dataset_rejects_schema2_city_and_schema1_envelope_rejects_schema2_city(): void
    {
        $invalidEnvelope = $this->payload();
        $invalidEnvelope['schemaVersion'] = 1;
        try {
            $this->analyze($invalidEnvelope, 'schema1-envelope-v2-city.json');
            self::fail('A schema1 envelope accepted a schema2 city.');
        } catch (DomainException $error) {
            self::assertStringContainsString('does not match the dataset envelope', $error->getMessage());
        }

        $this->dataset->update(['schema_version' => 1]);
        $import = $this->analyze($this->payload(), 'schema2-city-in-schema1-dataset.json');
        $drafts = app(RestrictionImportService::class)->confirm(
            $import,
            $import->rows()->pluck('id')->all(),
            $this->actor,
        );
        try {
            app(RestrictionRuleVersionService::class)->validate($drafts[0], $this->actor);
            self::fail('A schema1 dataset accepted a schema2 city draft.');
        } catch (DomainException $error) {
            self::assertStringContainsString('does not match the dataset envelope', $error->getMessage());
        }
        self::assertSame(0, $this->dataset->releases()->count());
        self::assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_schema2_form_edits_publish_a_complete_snapshot_and_preserve_other_jurisdictions(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $medellin = $this->createDaneJurisdiction('co-ant-medellin-form', 'Medellín QA sintética', '05001');
        $abejorral = $this->createDaneJurisdiction('co-ant-abejorral-form', 'Abejorral QA sintética', '05002');
        $source = 'https://example.test/g2-synthetic';

        $a1 = $this->createFormDraft($editor, $medellin, $this->formInput(
            'car|private', 'FORM_A_CAR', '05001',
            weekdays: '1', digits: '1,2', windows: "00:00-00:00 fullDay\n06:00-08:00",
            conditions: '[{"type":"occupants_at_least","value":2}]',
        ));
        $b1 = $this->createFormDraft($editor, $abejorral, $this->formInput(
            'truck|public_cargo', 'FORM_B_CARGO', '05002',
            weekdays: '5', digits: '8,9', windows: '12:00-15:00', conditions: '[]',
        ));
        $this->assertTrue($medellin->refresh()->enabled);
        self::assertSame(2, $a1->payload['schemaVersion']);
        self::assertSame(2, $b1->payload['schemaVersion']);

        $this->validateVersionAs($a1, $reviewer);
        $this->validateVersionAs($b1, $reviewer);
        $this->approveVersion($a1, 0, $source);
        $this->approveVersion($b1, 0, $source);
        $this->publishAs($reviewer, [$a1, $b1], 0);
        $v1 = $this->readPublishedRestrictions();
        $cityA1 = $this->city($v1, 'co-ant-medellin-form');
        $cityB = $this->city($v1, 'co-ant-abejorral-form');
        self::assertSame(['05001'], $cityA1['municipalityCodes']);
        self::assertTrue($cityA1['consultationEnabled']);
        self::assertSame([['type' => 'occupants_at_least', 'value' => 2]], $cityA1['coverages'][0]['rules'][0]['conditions']);
        self::assertTrue($cityA1['coverages'][0]['rules'][0]['timeWindows'][0]['fullDay']);

        $this->actingAs($editor)->post(route('admin.restrictions.duplicate', $a1))
            ->assertRedirect();
        $a2 = RestrictionRuleVersion::query()->where('jurisdiction_id', $medellin->id)->latest('version')->firstOrFail();
        $a2Input = $this->formInput(
            'car|private', 'FORM_A_CAR', '05001',
            weekdays: '2', digits: '3,4', windows: "00:00-00:00 fullDay\n07:00-09:00",
            conditions: '[{"type":"occupants_at_least","value":2}]',
        );
        $a2Input['coverages'][] = $this->formInput(
            'car|taxi', 'FORM_A_TAXI', '05001',
            weekdays: '3', digits: '5,6', windows: '07:00-09:00', conditions: '[]',
        )['coverages'][0];
        $this->actingAs($editor)->put(route('admin.restrictions.update', $a2), $a2Input)
            ->assertRedirect()->assertSessionHasNoErrors();
        $a2->refresh();
        self::assertSame(2, $a2->payload['schemaVersion']);
        self::assertSame([2], $a2->payload['coverages'][0]['rules'][0]['weekdays']);
        self::assertSame([3, 4], $a2->payload['coverages'][0]['rules'][0]['digits']);
        self::assertSame(420, $a2->payload['coverages'][0]['rules'][0]['timeWindows'][1]['startMinute']);
        self::assertTrue($a2->payload['coverages'][0]['rules'][0]['timeWindows'][0]['fullDay']);
        self::assertSame([['type' => 'occupants_at_least', 'value' => 2]], $a2->payload['coverages'][0]['rules'][0]['conditions']);
        self::assertSame('taxi', $a2->payload['coverages'][1]['serviceType']);
        self::assertSame(['05001'], $a2->payload['municipalityCodes']);
        self::assertTrue($a2->payload['consultationEnabled']);

        $this->validateVersionAs($a2, $reviewer);
        $unapproved = $this->actingAs($reviewer)->post(route('admin.restrictions.publish'), [
            'versions' => [$a2->id], 'publication_revision' => 1,
        ]);
        $unapproved->assertRedirect()->assertSessionHasErrors('publication');
        self::assertSame(1, $this->dataset->refresh()->publication_revision);
        $this->approveVersion($a2, 1, $source);
        $this->publishAs($reviewer, [$a2], 1);
        $v2 = $this->readPublishedRestrictions();
        $cityA2 = $this->city($v2, 'co-ant-medellin-form');
        self::assertSame($this->canonical($cityB), $this->canonical($this->city($v2, 'co-ant-abejorral-form')));
        self::assertSame(['car/private', 'car/taxi'], array_map(
            static fn (array $coverage): string => $coverage['vehicleKind'].'/'.$coverage['serviceType'],
            $cityA2['coverages'],
        ));

        $this->actingAs($editor)->post(route('admin.restrictions.duplicate', $a2))->assertRedirect();
        $disableModality = RestrictionRuleVersion::query()->where('jurisdiction_id', $medellin->id)->latest('version')->firstOrFail();
        $withoutTaxi = $this->formInput(
            'car|private', 'FORM_A_CAR', '05001',
            weekdays: '2', digits: '3,4', windows: "00:00-00:00 fullDay\n07:00-09:00",
            conditions: '[{"type":"occupants_at_least","value":2}]',
        );
        $this->actingAs($editor)->put(route('admin.restrictions.update', $disableModality), $withoutTaxi)
            ->assertRedirect()->assertSessionHasNoErrors();
        $this->validateVersionAs($disableModality, $reviewer);
        $blockedDisable = $this->actingAs($reviewer)->post(route('admin.restrictions.publish'), [
            'versions' => [$disableModality->id], 'publication_revision' => 2,
        ]);
        $blockedDisable->assertRedirect()->assertSessionHasErrors('publication');
        self::assertStringContainsString('REJECT_COVERAGE_LOSS', session('errors')->first('publication'));
        self::assertSame(2, $this->dataset->refresh()->publication_revision);

        $this->actingAs($editor)->post(route('admin.restrictions.duplicate', $a2))->assertRedirect();
        $a3 = RestrictionRuleVersion::query()->where('jurisdiction_id', $medellin->id)->latest('version')->firstOrFail();
        $disabledInput = $a2Input;
        $disabledInput['consultation_enabled'] = '0';
        $this->actingAs($editor)->put(route('admin.restrictions.update', $a3), $disabledInput)
            ->assertRedirect()->assertSessionHasNoErrors();
        $a3->refresh();
        self::assertFalse($a3->payload['consultationEnabled']);
        self::assertSame(['05001'], $a3->payload['municipalityCodes']);
        $this->validateVersionAs($a3, $reviewer);
        $this->approveVersion($a3, 2, $source);
        $this->publishAs($reviewer, [$a3], 2);
        $v3 = $this->readPublishedRestrictions();
        self::assertFalse($this->city($v3, 'co-ant-medellin-form')['consultationEnabled']);
        self::assertTrue($medellin->refresh()->enabled, 'Public consultation is versioned independently from the admin jurisdiction flag.');
        self::assertSame($this->canonical($cityB), $this->canonical($this->city($v3, 'co-ant-abejorral-form')));

        $this->actingAs($reviewer)->post(route('admin.restrictions.rollback', $a2), [
            'publication_revision' => 3,
        ])->assertRedirect(route('admin.restrictions.history'))->assertSessionHasNoErrors();
        self::assertSame(4, $this->dataset->refresh()->publication_revision);
        $v4 = $this->readPublishedRestrictions();
        self::assertTrue($this->city($v4, 'co-ant-medellin-form')['consultationEnabled']);
        self::assertSame($this->canonical($cityB), $this->canonical($this->city($v4, 'co-ant-abejorral-form')));

        // Pausing an individual modality must not delete its coverage, overwrite
        // another jurisdiction, or claim that the vehicle can circulate.
        $this->actingAs($editor)->post(route('admin.restrictions.duplicate', $a2))->assertRedirect();
        $paused = RestrictionRuleVersion::query()->where('jurisdiction_id', $medellin->id)->latest('version')->firstOrFail();
        $pauseInput = $a2Input;
        $pauseInput['coverages'][1]['suspend_consultation'] = '1';
        $this->actingAs($editor)->put(route('admin.restrictions.update', $paused), $pauseInput)
            ->assertRedirect()->assertSessionHasNoErrors();
        $paused->refresh();
        self::assertCount(2, $paused->payload['coverages']);
        self::assertSame('partial', $paused->payload['coverages'][1]['coverageCompleteness']);
        self::assertSame([], $paused->payload['coverages'][1]['rules']);
        $this->validateVersionAs($paused, $reviewer);
        $this->actingAs($reviewer)->post(route('admin.restrictions.publish'), [
            'versions' => [$paused->id], 'publication_revision' => 4,
        ])->assertRedirect()->assertSessionHasErrors('publication');
        self::assertSame(4, $this->dataset->refresh()->publication_revision);
        $this->approveVersion($paused, 4, $source);
        $this->publishAs($reviewer, [$paused], 4);
        $v5 = $this->readPublishedRestrictions();
        $cityA5 = $this->city($v5, 'co-ant-medellin-form');
        self::assertCount(2, $cityA5['coverages']);
        self::assertSame('partial', $cityA5['coverages'][1]['coverageCompleteness']);
        self::assertSame([], $cityA5['coverages'][1]['rules']);
        self::assertSame($this->canonical($cityB), $this->canonical($this->city($v5, 'co-ant-abejorral-form')));

        $this->actingAs($reviewer)->post(route('admin.restrictions.rollback', $a2), [
            'publication_revision' => 5,
        ])->assertRedirect(route('admin.restrictions.history'))->assertSessionHasNoErrors();
        $restored = $this->city($this->readPublishedRestrictions(), 'co-ant-medellin-form');
        self::assertNotEmpty($restored['coverages'][1]['rules']);
        self::assertSame($this->canonical($cityB), $this->canonical($this->city($this->readPublishedRestrictions(), 'co-ant-abejorral-form')));
    }

    public function test_material_rule_removal_requires_editorial_review_and_keeps_the_active_release(): void
    {
        $jurisdiction = Jurisdiction::query()->where('key', 'co-g2-synthetic')->firstOrFail();
        $versions = app(RestrictionRuleVersionService::class);
        $publication = app(RestrictionPublicationService::class);
        $initialPayload = $this->payload()['jurisdictions'][0];
        $initial = $versions->validate(
            $versions->createDraft($jurisdiction, $initialPayload, $this->actor),
            $this->actor,
        );
        $this->publishWithEditorialApproval($initial, 0);
        $activeVersion = $this->dataset->refresh()->current_version;

        $removalPayload = $initialPayload;
        $removalPayload['coverages'][0]['rules'] = [];
        $removal = $versions->validate(
            $versions->createDraft($jurisdiction, $removalPayload, $this->actor),
            $this->actor,
        );
        try {
            $publication->publish([$removal->id], 1, $this->actor);
            self::fail('Material removal was published without an explicit editorial decision.');
        } catch (DomainException $error) {
            self::assertStringContainsString('REVIEW_REQUIRED', $error->getMessage());
        }

        $review = AuditLog::query()->where('action', 'restriction.material_change.review_required')->latest('id')->firstOrFail();
        self::assertSame($this->actor->id, $review->actor_id);
        self::assertSame('REVIEW_REQUIRED', $review->metadata['classification']);
        self::assertSame('co-g2-synthetic', $review->metadata['jurisdictionId']);
        self::assertSame('restrictive_rule_removed', $review->metadata['change']);
        self::assertSame('No matching independent editorial approval exists for this version, content, and publication revision.', $review->metadata['reason']);
        self::assertNotSame($review->metadata['before']['sha256'], $review->metadata['after']['sha256']);
        self::assertSame($activeVersion, $this->dataset->refresh()->current_version);
        self::assertSame(1, $this->dataset->publication_revision);
        self::assertSame(1, $this->dataset->releases()->count());

        $additionalCoverage = [
            'vehicleKind' => 'bus',
            'serviceType' => 'special',
            'coverageCompleteness' => 'partial',
            'verifiedAt' => '2026-11-10T00:00:00Z',
            'staleAfter' => '2026-11-20T00:00:00Z',
            'sourceUrls' => ['https://example.test/g2-synthetic'],
            'rules' => [],
        ];
        $extendedPayload = $initialPayload;
        $extendedPayload['coverages'][] = $additionalCoverage;
        $extended = $versions->validate(
            $versions->createDraft($jurisdiction, $extendedPayload, $this->actor),
            $this->actor,
        );
        $this->publishWithEditorialApproval($extended, 1);
        $publication->rollbackCity($initial, 2, $this->actor);

        self::assertSame(3, $this->dataset->refresh()->publication_revision);
        self::assertSame(
            ['publish', 'publish', 'rollback'],
            RestrictionPublication::query()->orderBy('id')->pluck('action')->all(),
        );
    }

    public function test_complete_coverage_cannot_enter_a_release_without_editorial_evidence(): void
    {
        $jurisdiction = Jurisdiction::query()->where('key', 'co-g2-synthetic')->firstOrFail();
        $payload = $this->payload()['jurisdictions'][0];
        $payload['coverages'][0]['coverageCompleteness'] = 'complete';
        $versionService = app(RestrictionRuleVersionService::class);
        $version = $versionService->validate(
            $versionService->createDraft($jurisdiction, $payload, $this->actor),
            $this->actor,
        );

        try {
            app(RestrictionPublicationService::class)->publish([$version->id], 0, $this->actor);
            self::fail('Complete coverage was released without evidence that the full scope was evaluated.');
        } catch (DomainException $error) {
            self::assertStringContainsString('COVERAGE_COMPLETE_REQUIRES_SPATIAL_QA', $error->getMessage());
        }

        $review = AuditLog::query()
            ->where('action', 'restriction.material_change.review_required')
            ->get()
            ->first(fn (AuditLog $event): bool => $event->metadata['change'] === 'coverage_marked_complete_without_spatial_qa');
        self::assertNotNull($review);
        self::assertSame('coverage_marked_complete_without_spatial_qa', $review->metadata['change']);
        self::assertSame($this->actor->id, $review->actor_id);
        self::assertSame(0, $this->dataset->refresh()->publication_revision);
        self::assertSame(0, $this->dataset->releases()->count());

        $envelope = $this->payload();
        $envelope['jurisdictions'][0]['coverages'][0]['coverageCompleteness'] = 'complete';
        $bytes = json_encode($envelope, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        $path = 'dataset-drafts/restrictions/direct-complete.json';
        Storage::disk('local')->put($path, $bytes);
        $directRelease = $this->dataset->releases()->create([
            'version' => $envelope['version'],
            'status' => DatasetReleaseStatus::Draft,
            'draft_path' => $path,
        ]);
        try {
            app(DatasetReleaseValidator::class)->validate($directRelease, $this->actor);
            self::fail('The generic release validator accepted unproven complete coverage.');
        } catch (DomainException $error) {
            self::assertStringContainsString('REVIEW_REQUIRED', $error->getMessage());
        }
        self::assertSame(DatasetReleaseStatus::Draft, $directRelease->refresh()->status);
        self::assertSame(0, $this->dataset->refresh()->publication_revision);
        self::assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_expanding_rule_validity_without_a_new_source_requires_review(): void
    {
        $jurisdiction = Jurisdiction::query()->where('key', 'co-g2-synthetic')->firstOrFail();
        $versions = app(RestrictionRuleVersionService::class);
        $publication = app(RestrictionPublicationService::class);
        $initialPayload = $this->payload()['jurisdictions'][0];
        $initial = $versions->validate(
            $versions->createDraft($jurisdiction, $initialPayload, $this->actor),
            $this->actor,
        );
        $this->publishWithEditorialApproval($initial, 0);

        $extendedPayload = $initialPayload;
        $extendedPayload['coverages'][0]['rules'][0]['validUntil'] = '2026-11-25T23:59:59-05:00';
        $extended = $versions->validate(
            $versions->createDraft($jurisdiction, $extendedPayload, $this->actor),
            $this->actor,
        );
        try {
            $publication->publish([$extended->id], 1, $this->actor);
            self::fail('A validity expansion without a new source was published.');
        } catch (DomainException $error) {
            self::assertStringContainsString('REVIEW_REQUIRED', $error->getMessage());
        }

        $review = AuditLog::query()->where('action', 'restriction.material_change.review_required')->latest('id')->firstOrFail();
        self::assertSame('restriction_validity_expanded_without_source', $review->metadata['change']);
        self::assertSame(1, $this->dataset->refresh()->publication_revision);
    }

    /** @param array<string,mixed> $payload */
    private function analyze(array $payload, string $filename): RestrictionImport
    {
        $path = tempnam(sys_get_temp_dir(), 'picoradar-g2-');
        file_put_contents($path, json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
        try {
            return app(RestrictionImportService::class)->analyze($path, $filename, 'json', null, $this->actor);
        } finally {
            unlink($path);
        }
    }

    private function publishWithEditorialApproval(RestrictionRuleVersion $version, int $revision): DatasetRelease
    {
        $service = app(RestrictionPublicationService::class);
        $preview = $service->materialChangePreview($version, $revision);
        if ($preview['changes'] !== []) {
            $reviewer = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
            $service->approveMaterialChange(
                $version,
                $revision,
                $reviewer,
                'Independent review of the synthetic G2 fixture change.',
                $preview['sources'][0],
            );
        }

        return $service->publish([$version->id], $revision, $this->actor);
    }

    /** @return array<string,mixed> */
    private function payload(): array
    {
        $jurisdiction = [
            'schemaVersion' => 2,
            'id' => 'co-g2-synthetic',
            'name' => 'Ciudad sintética G2',
            'coverages' => [[
                'vehicleKind' => 'truck',
                'serviceType' => 'public_cargo',
                'coverageCompleteness' => 'partial',
                'verifiedAt' => '2026-11-10T00:00:00Z',
                'staleAfter' => '2026-11-20T00:00:00Z',
                'sourceUrls' => ['https://example.test/g2-synthetic'],
                'rules' => [[
                    'id' => 'SYNTHETIC_G2_CARGO', 'priority' => 100, 'effect' => 'restrict',
                    'validFrom' => '2026-11-10T00:00:00-05:00',
                    'validUntil' => '2026-11-19T23:59:59-05:00',
                    'weekdays' => [1, 2, 3, 4, 5],
                    'timeWindows' => [
                        ['startMinute' => 360, 'endMinute' => 480],
                        ['startMinute' => 1020, 'endMinute' => 1200],
                    ],
                    'appliesOnHolidays' => false,
                    'sourceUrl' => 'https://example.test/g2-synthetic',
                    'verifiedAt' => '2026-11-10T00:00:00Z',
                    'conditions' => [
                        ['type' => 'gross_weight_kg_gt', 'value' => 8500],
                        ['type' => 'inside_scope_ref', 'value' => 'co-dc-bogota-zone1@2026-lab'],
                    ],
                ]],
            ]],
        ];

        return [
            'schemaVersion' => 2,
            'datasetKey' => 'restrictions',
            'version' => 'SYNTHETIC_G2_V2',
            'generatedAt' => '2026-11-10T00:00:00Z',
            'jurisdictions' => [$jurisdiction],
        ];
    }

    private function createJurisdiction(string $key, string $name, int $code): void
    {
        $parent = GeographicUnit::query()->where('key', 'co-99')->firstOrFail();
        $unit = GeographicUnit::query()->create([
            'parent_id' => $parent->id,
            'key' => $key,
            'level' => 'municipality',
            'code' => (string) $code,
            'name' => $name,
            'normalized_name' => strtolower($name),
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'g2-v3-test',
        ]);
        Jurisdiction::query()->create([
            'key' => $key,
            'name' => $name,
            'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id,
            'enabled' => true,
            'timezone' => 'America/Bogota',
        ]);
    }

    private function createDaneJurisdiction(string $key, string $name, string $code): Jurisdiction
    {
        $department = GeographicUnit::query()->firstOrCreate(
            ['key' => 'co-antioquia-n3-test'],
            [
                'parent_id' => GeographicUnit::query()->where('key', 'co')->value('id'),
                'level' => 'department', 'code' => '05', 'name' => 'Antioquia',
                'normalized_name' => 'antioquia', 'is_active' => true,
                'source_system' => 'synthetic-test', 'source_version' => 'n3r1',
            ],
        );
        $unit = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'co-ant-'.$code.'-n3-test',
            'level' => 'municipality', 'code' => $code, 'name' => $name,
            'normalized_name' => mb_strtolower($name), 'is_active' => true,
            'source_system' => 'DANE', 'source_version' => '2025',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => $key, 'name' => $name, 'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id, 'enabled' => true,
            'timezone' => 'America/Bogota',
        ]);
        $jurisdiction->geographicUnits()->attach($unit->id);

        return $jurisdiction;
    }

    /** @return array<string,mixed> */
    private function formInput(string $pair, string $ruleId, string $municipalityCode, string $weekdays, string $digits, string $windows, string $conditions): array
    {
        $source = 'https://example.test/g2-synthetic';

        return [
            'municipality_codes' => $municipalityCode,
            'consultation_enabled' => '1',
            'coverages' => [[
                'pair' => $pair,
                'verified_at' => '2026-11-16T08:00',
                'stale_after' => '2026-12-01T00:00',
                'source_urls' => $source,
                'rules' => [[
                    'id' => $ruleId, 'priority' => '1000', 'effect' => 'restrict',
                    'valid_from' => '2026-11-16T00:00', 'valid_until' => '2026-11-30T23:59',
                    'weekdays' => $weekdays, 'date_parity' => '', 'digit_position' => 'lastNumeric',
                    'digits' => $digits, 'time_windows' => $windows, 'applies_on_holidays' => '0',
                    'source_url' => $source, 'verified_at' => '2026-11-16T08:00',
                    'registration_origins' => '', 'conditions_json' => $conditions,
                ]],
            ]],
        ];
    }

    private function createFormDraft(User $editor, Jurisdiction $jurisdiction, array $input): RestrictionRuleVersion
    {
        $input['jurisdiction_id'] = $jurisdiction->id;
        $this->actingAs($editor)->post(route('admin.restrictions.store'), $input)
            ->assertRedirect()->assertSessionHasNoErrors();

        return RestrictionRuleVersion::query()->where('jurisdiction_id', $jurisdiction->id)->latest('version')->firstOrFail();
    }

    private function validateVersionAs(RestrictionRuleVersion $version, User $reviewer): void
    {
        $this->actingAs($reviewer)->post(route('admin.restrictions.validate', $version))
            ->assertRedirect()->assertSessionHasNoErrors();
        $version->refresh();
    }

    private function approveVersion(RestrictionRuleVersion $version, int $revision, string $source): void
    {
        $this->actingAs($this->actor)->post(route('admin.restrictions.approve-material-change', $version), [
            'publication_revision' => $revision,
            'reason' => 'Revisión editorial independiente de fixture QA sintética.',
            'evidence_url' => $source,
        ])->assertRedirect()->assertSessionHasNoErrors();
    }

    /** @param list<RestrictionRuleVersion> $versions */
    private function publishAs(User $reviewer, array $versions, int $revision): void
    {
        $this->actingAs($reviewer)->post(route('admin.restrictions.publish'), [
            'versions' => array_map(static fn (RestrictionRuleVersion $version): int => $version->id, $versions),
            'publication_revision' => $revision,
        ])->assertRedirect(route('admin.restrictions.history'))->assertSessionHasNoErrors();
    }

    /** @return array<string,mixed> */
    private function readPublishedRestrictions(): array
    {
        $release = $this->dataset->refresh()->releases()->where('version', $this->dataset->current_version)->firstOrFail();
        $bytes = Storage::disk('public')->get($release->asset_path);
        $manifest = json_decode(Storage::disk('public')->get(config('datasets.manifest_path')), true, 512, JSON_THROW_ON_ERROR);
        $entry = $manifest['datasets']['restrictions'];
        self::assertSame(hash('sha256', $bytes), $release->sha256);
        self::assertSame($release->sha256, $entry['sha256']);
        self::assertSame($release->version, $entry['version']);
        $evidenceDirectory = getenv('PICORADAR_N3R1_EVIDENCE_DIR');
        if (is_string($evidenceDirectory) && $evidenceDirectory !== '') {
            if (! is_dir($evidenceDirectory)) {
                mkdir($evidenceDirectory, 0755, true);
            }
            $manifestBytes = Storage::disk('public')->get(config('datasets.manifest_path'));
            file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'publication-revision-'.$this->dataset->refresh()->publication_revision.'.json', json_encode([
                'publicationRevision' => $this->dataset->publication_revision,
                'releaseVersion' => $release->version,
                'assetPath' => $release->asset_path,
                'assetBytes' => strlen($bytes),
                'assetSha256' => hash('sha256', $bytes),
                'manifestBytes' => strlen($manifestBytes),
                'manifestSha256' => hash('sha256', $manifestBytes),
                'manifestDatasetEntry' => $entry,
                'syntheticFixture' => true,
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR));
        }

        return json_decode($bytes, true, 512, JSON_THROW_ON_ERROR);
    }

    /** @param array<string,mixed> $release @return array<string,mixed> */
    private function city(array $release, string $id): array
    {
        foreach ($release['jurisdictions'] as $jurisdiction) {
            if ($jurisdiction['id'] === $id) {
                return $jurisdiction;
            }
        }
        self::fail('Published snapshot omitted jurisdiction '.$id.'.');
    }

    private function coverageCount(array $payload): int
    {
        return array_sum(array_map(static fn (array $city): int => count($city['coverages']), $payload['jurisdictions']));
    }

    private function canonical(array $value): string
    {
        $sort = function (array $input) use (&$sort): array {
            if (! array_is_list($input)) {
                ksort($input);
            }
            foreach ($input as $key => $item) {
                if (is_array($item)) {
                    $input[$key] = $sort($item);
                }
            }

            return $input;
        };

        return json_encode($sort($value), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    }

    private function encoder(): RestrictionPayloadEncoder
    {
        return app(RestrictionPayloadEncoder::class);
    }
}
