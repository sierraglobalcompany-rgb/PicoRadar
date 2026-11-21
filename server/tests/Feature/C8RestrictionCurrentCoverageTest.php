<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionPublication;
use App\Models\RestrictionPublicationItem;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Services\DatasetPublisher;
use App\Services\RestrictionPayloadEncoder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class C8RestrictionCurrentCoverageTest extends TestCase
{
    use RefreshDatabase;

    private GeographicUnit $department;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Storage::fake('local');
        Storage::fake('public');

        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia',
            'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'c8-test',
        ]);
        $this->department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05',
            'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'c8-test',
        ]);
    }

    public function test_current_coverage_tracks_the_verified_dataset_pointer_across_city_release_and_rollback(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 2,
            'enabled' => true, 'publication_revision' => 2,
        ]);
        [$bogotaUnit, $bogota] = $this->jurisdiction('05001', 'bogota', 'Bogotá');
        [, $cali] = $this->jurisdiction('05002', 'cali', 'Cali');
        $this->municipality('05003', 'co-05003', ' =HYPERLINK("https://example.test","x")');
        $this->jurisdiction('05004', 'no-editor-version', 'Sin versión editorial');

        $bogotaV1Payload = $this->city($bogota, [$this->coverage('car', '=SUM(1,1)', 'complete', 'https://official.example.test/bogota')]);
        $bogotaV1 = $this->editorVersion($bogota, 1, RestrictionRuleVersionStatus::Validated, $bogotaV1Payload);
        $bogotaV2Payload = $this->city($bogota, [$this->coverage('car', 'private', 'partial', 'https://draft.example.test/bogota')]);
        $this->editorVersion($bogota, 2, RestrictionRuleVersionStatus::Draft, $bogotaV2Payload);

        $caliEditorPayload = $this->city($cali, [$this->coverage('motorcycle', 'private', 'complete', 'https://draft.example.test/cali')]);
        $caliV1 = $this->editorVersion($cali, 1, RestrictionRuleVersionStatus::Draft, $caliEditorPayload);
        $release1Payload = $this->datasetPayload('c8-release-1', [$bogotaV1Payload]);
        $release1 = $this->publishedRelease($dataset, 'c8-release-1', $release1Payload);
        $this->publicationItem($release1, $admin, $bogota, $bogotaV1, 1);

        $caliNationalPayload = $this->city($cali, [$this->coverage('car', 'private', 'complete', 'https://official.example.test/cali')]);
        $release2Payload = $this->datasetPayload('c8-release-2', [$bogotaV1Payload, $caliNationalPayload]);
        $release2 = $this->publishedRelease($dataset, 'c8-release-2', $release2Payload);
        $this->publicationItem($release2, $admin, $cali, $caliV1, 2);

        $orphanPayload = [
            'id' => 'unmapped-city', 'name' => 'Unmapped',
            'coverages' => [$this->coverage('car', 'private', 'complete', 'https://official.example.test/unmapped')],
        ];
        $release2Payload['jurisdictions'][] = $orphanPayload;
        $this->replaceReleaseAsset($release2, $release2Payload);
        $dataset->forceFill(['current_version' => $release2->version])->save();

        $matrix = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities'));
        $matrix->assertOk()
            ->assertSee('Cobertura nacional actual')
            ->assertSee('Release nacional actual: c8-release-2')
            ->assertSee('Bogotá')
            ->assertSee('Editor: v2 · draft')
            ->assertSee('VERIFIED')
            ->assertSee('PARTIAL')
            ->assertSee('NO_IDENTIFICADA');

        $bogotaRow = $this->matrixRow($matrix->viewData('municipalities')->items(), '05001');
        self::assertSame('2', (string) $bogotaRow['entries'][0]['version']->version);
        self::assertSame('1', $bogotaRow['entries'][0]['source_editor_version']);
        self::assertSame('VERIFIED', $bogotaRow['entries'][0]['coverages'][0]['availability']);
        self::assertSame('PARTIAL', $bogotaRow['entries'][0]['editor_coverages'][0]['availability']);
        $caliCurrentRow = $this->matrixRow($matrix->viewData('municipalities')->items(), '05002');
        self::assertSame('VERIFIED', $caliCurrentRow['entries'][0]['coverages'][0]['availability']);
        self::assertSame('NO_IDENTIFICADA', $caliCurrentRow['entries'][0]['source_editor_version']);

        $unassignedRow = $this->matrixRow($matrix->viewData('municipalities')->items(), '05003');
        self::assertSame('NO_JURISDICTION', $unassignedRow['entries'][0]['coverages'][0]['missing_reason']);
        self::assertSame('UNKNOWN', $unassignedRow['entries'][0]['coverages'][0]['availability']);

        // A source release may be retired while its city data remains in the current national asset.
        \Illuminate\Support\Facades\DB::table('dataset_releases')->where('id', $release1->id)->update([
            'status' => DatasetReleaseStatus::Retired->value,
        ]);
        $sourceRetired = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities'));
        $sourceRetired->assertOk()->assertSee('Release nacional actual: c8-release-2');
        $bogotaWithRetiredSource = $this->matrixRow($sourceRetired->viewData('municipalities')->items(), '05001');
        self::assertSame('VERIFIED', $bogotaWithRetiredSource['entries'][0]['coverages'][0]['availability']);
        \Illuminate\Support\Facades\DB::table('dataset_releases')->where('id', $release1->id)->update([
            'status' => DatasetReleaseStatus::Published->value,
        ]);

        $editorialResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', ['scope' => 'editorial']));
        $editorialResponse->assertOk();
        $editorialRows = $this->csvRows($editorialResponse->streamedContent());
        $bogotaEditorial = collect($editorialRows)->firstWhere('municipality_code', '05001');
        self::assertNotNull($bogotaEditorial);
        self::assertSame('PARTIAL', $bogotaEditorial['coverage_evidence_state']);
        self::assertSame('private', $bogotaEditorial['service_type']);
        self::assertSame('2', $bogotaEditorial['editor_version']);
        self::assertSame('draft', $bogotaEditorial['editor_version_status']);
        self::assertSame('1', $bogotaEditorial['source_editor_version']);
        self::assertSame('c8-release-2', $bogotaEditorial['published_release']);
        self::assertSame('REFERENCE_ONLY', $bogotaEditorial['publication_state']);
        $noEditorVersion = collect($editorialRows)->firstWhere('municipality_code', '05004');
        self::assertSame('UNKNOWN', $noEditorVersion['coverage_evidence_state']);
        self::assertSame('NO_EDITOR_VERSION', $noEditorVersion['missing_reason']);
        self::assertSame('', $noEditorVersion['editor_version']);

        $publishedResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', ['scope' => 'published']));
        $publishedResponse->assertOk();
        $publishedRows = $this->csvRows($publishedResponse->streamedContent());
        $bogotaPublished = collect($publishedRows)->firstWhere('municipality_code', '05001');
        self::assertNotNull($bogotaPublished);
        self::assertSame('VERIFIED', $bogotaPublished['coverage_evidence_state']);
        self::assertSame("'=SUM(1,1)", $bogotaPublished['service_type']);
        self::assertSame('2', $bogotaPublished['editor_version']);
        self::assertSame('draft', $bogotaPublished['editor_version_status']);
        self::assertSame('1', $bogotaPublished['source_editor_version']);
        self::assertSame('c8-release-2', $bogotaPublished['published_release']);
        self::assertSame('PUBLISHED', $bogotaPublished['publication_state']);
        $noPublishedCoverage = collect($publishedRows)->firstWhere('municipality_code', '05004');
        self::assertSame('UNKNOWN', $noPublishedCoverage['coverage_evidence_state']);
        self::assertSame('NOT_PRESENT_IN_CURRENT_RELEASE', $noPublishedCoverage['missing_reason']);

        $municipalitiesResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', ['scope' => 'municipalities']));
        $municipalityRows = $this->csvRows($municipalitiesResponse->streamedContent());
        $bogotaMunicipality = collect($municipalityRows)->firstWhere('municipality_code', '05001');
        self::assertSame('VERIFIED', $bogotaMunicipality['coverage_evidence_state']);
        self::assertSame('2', $bogotaMunicipality['editor_version']);
        self::assertSame('draft', $bogotaMunicipality['editor_version_status']);
        self::assertSame('c8-release-2', $bogotaMunicipality['published_release']);
        self::assertSame('PUBLISHED', $bogotaMunicipality['publication_state']);
        $unassignedCsv = collect($municipalityRows)->firstWhere('municipality_code', '05003');
        self::assertSame('UNKNOWN', $unassignedCsv['coverage_evidence_state']);
        self::assertSame('NO_JURISDICTION', $unassignedCsv['missing_reason']);
        self::assertSame("' =HYPERLINK(\"https://example.test\",\"x\")", $unassignedCsv['municipality_name']);

        $indexFilters = [
            'q' => 'Bogotá', 'department' => '05', 'vehicle_kind' => 'car',
            'availability' => 'partial', 'management' => 'active',
        ];
        $publishedCsvUrl = route('admin.restrictions.coverage.export', ['scope' => 'published'] + $indexFilters);
        $this->actingAs($reviewer)
            ->get(route('admin.restrictions.index', $indexFilters))
            ->assertOk()
            ->assertSee('Exportar vista CSV · editorial')
            ->assertSee('CSV publicado')
            ->assertSee(e($publishedCsvUrl), false);

        app(DatasetPublisher::class)->rollback($dataset, $release1, $admin);
        self::assertSame('c8-release-1', $dataset->fresh()->current_version);

        $publishedAfterRollback = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', ['scope' => 'published']));
        $publishedAfterRollbackRows = $this->csvRows($publishedAfterRollback->streamedContent());
        $bogotaAfterRollback = collect($publishedAfterRollbackRows)->firstWhere('municipality_code', '05001');
        self::assertSame('VERIFIED', $bogotaAfterRollback['coverage_evidence_state']);
        self::assertSame('c8-release-1', $bogotaAfterRollback['published_release']);
        self::assertSame('PUBLISHED', $bogotaAfterRollback['publication_state']);
        $caliAfterRollback = collect($publishedAfterRollbackRows)->firstWhere('municipality_code', '05002');
        self::assertSame('UNKNOWN', $caliAfterRollback['coverage_evidence_state']);
        self::assertSame('NOT_PRESENT_IN_CURRENT_RELEASE', $caliAfterRollback['missing_reason']);

        $rolledBack = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities'));
        $rolledBack->assertOk()
            ->assertSee('Release nacional actual: c8-release-1')
            ->assertSee('NOT_PRESENT_IN_CURRENT_RELEASE');
        $caliRow = $this->matrixRow($rolledBack->viewData('municipalities')->items(), '05002');
        self::assertSame('UNKNOWN', $caliRow['entries'][0]['coverages'][0]['availability']);
        self::assertSame('NO_IDENTIFICADA', $caliRow['entries'][0]['source_editor_version']);
        self::assertSame('c8-release-1', $caliRow['entries'][0]['published_release']->version);

        Storage::disk('public')->put($release1->asset_path, 'corrupt bytes');
        $corruptCsvResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', ['scope' => 'published']));
        $corruptCsvRows = $this->csvRows($corruptCsvResponse->streamedContent());
        $corruptCsvCity = collect($corruptCsvRows)->firstWhere('municipality_code', '05001');
        self::assertSame('UNKNOWN', $corruptCsvCity['coverage_evidence_state']);
        self::assertSame('UNKNOWN', $corruptCsvCity['publication_state']);
        self::assertSame('', $corruptCsvCity['published_release']);
        self::assertSame('2', $corruptCsvCity['editor_version']);
        self::assertSame('draft', $corruptCsvCity['editor_version_status']);

        $corruptAsset = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities'));
        $corruptAsset->assertOk()->assertSee('Sin release actual verificable');
        $bogotaWithCorruptAsset = $this->matrixRow($corruptAsset->viewData('municipalities')->items(), '05001');
        self::assertSame('UNKNOWN', $bogotaWithCorruptAsset['entries'][0]['coverages'][0]['availability']);
        self::assertNull($bogotaWithCorruptAsset['entries'][0]['published_release']);

        $dataset->forceFill(['current_version' => 'missing-release'])->save();
        $missingReleaseResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', ['scope' => 'published']));
        $missingReleaseRows = $this->csvRows($missingReleaseResponse->streamedContent());
        $missingReleaseCity = collect($missingReleaseRows)->firstWhere('municipality_code', '05001');
        self::assertSame('UNKNOWN', $missingReleaseCity['coverage_evidence_state']);
        self::assertSame('UNKNOWN', $missingReleaseCity['publication_state']);
        self::assertSame('', $missingReleaseCity['published_release']);
        $dataset->forceFill(['current_version' => $release1->version])->save();

        $this->replaceReleaseAsset($release1, $release1Payload);
        \Illuminate\Support\Facades\DB::table('dataset_releases')->where('id', $release1->id)->update(['status' => DatasetReleaseStatus::Retired->value]);
        $notPublished = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities'));
        $notPublished->assertOk()->assertSee('Sin release actual verificable');
        $bogotaAfterRetirement = $this->matrixRow($notPublished->viewData('municipalities')->items(), '05001');
        self::assertSame('UNKNOWN', $bogotaAfterRetirement['entries'][0]['coverages'][0]['availability']);
        self::assertNull($bogotaAfterRetirement['entries'][0]['published_release']);

        $retiredPublishedResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', ['scope' => 'published']));
        $retiredPublishedRows = $this->csvRows($retiredPublishedResponse->streamedContent());
        $retiredPublishedCity = collect($retiredPublishedRows)->firstWhere('municipality_code', '05001');
        self::assertSame('UNKNOWN', $retiredPublishedCity['coverage_evidence_state']);
        self::assertSame('UNKNOWN', $retiredPublishedCity['publication_state']);
        self::assertSame('', $retiredPublishedCity['published_release']);
    }

    public function test_malformed_filter_arrays_and_extreme_pages_are_bounded_without_errors(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $this->municipality('05001', 'co-05001', 'Test municipality');

        $matrix = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities', [
            'q' => ['bad'], 'department' => ['05'], 'page' => ['2'],
        ]));
        $matrix->assertOk();
        self::assertSame('', $matrix->viewData('filters')['q']);
        self::assertSame('', $matrix->viewData('filters')['department']);
        self::assertSame(1, $matrix->viewData('municipalities')->currentPage());

        $invalidStates = $this->get(route('admin.restrictions.municipalities', [
            'management' => '', 'availability' => 'unsupported',
        ]));
        $invalidStates->assertOk();
        self::assertSame('all', $invalidStates->viewData('filters')['management']);
        self::assertSame('all', $invalidStates->viewData('filters')['availability']);

        $bounded = $this->get(route('admin.restrictions.municipalities', [
            'q' => str_repeat('x', 120), 'department' => '05', 'page' => '999999999',
        ]));
        $bounded->assertOk();
        self::assertSame(100, mb_strlen($bounded->viewData('filters')['q']));
        self::assertSame('05', $bounded->viewData('filters')['department']);
        self::assertSame(10000, $bounded->viewData('municipalities')->currentPage());

        $csv = $this->get(route('admin.restrictions.coverage.export', [
            'scope' => 'editorial', 'q' => ['bad'], 'department' => ['05'],
        ]));
        $csv->assertOk();
        self::assertSame([], $this->csvRows($csv->streamedContent()));

        $this->actingAs($reviewer)
            ->get(route('admin.restrictions.coverage.export', ['scope' => 'unknown']))
            ->assertStatus(422);
    }

    public function test_municipality_and_export_routes_keep_dataset_view_authorization(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $this->actingAs($commercial)
            ->get(route('admin.restrictions.municipalities'))
            ->assertForbidden();
        $this->get(route('admin.restrictions.coverage.export', ['scope' => 'municipalities']))
            ->assertForbidden();
    }

    /** @return array{GeographicUnit, Jurisdiction} */
    private function jurisdiction(string $code, string $key, string $name): array
    {
        $municipality = $this->municipality($code, "co-$code", $name);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => $key, 'name' => $name, 'kind' => 'city',
            'primary_geographic_unit_id' => $municipality->id, 'enabled' => true, 'timezone' => 'America/Bogota',
        ]);
        $municipality->jurisdictions()->attach($jurisdiction->id);

        return [$municipality, $jurisdiction];
    }

    private function municipality(string $code, string $key, string $name): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'parent_id' => $this->department->id, 'key' => $key, 'level' => 'municipality', 'code' => $code,
            'name' => $name, 'normalized_name' => strtolower($name), 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'c8-test',
        ]);
    }

    /** @param list<array<string, mixed>> $coverages
     * @return array<string, mixed>
     */
    private function city(Jurisdiction $jurisdiction, array $coverages): array
    {
        return ['id' => $jurisdiction->key, 'name' => $jurisdiction->name, 'schemaVersion' => 2, 'coverages' => $coverages];
    }

    /** @return array<string, mixed> */
    private function coverage(string $vehicleKind, string $serviceType, string $completeness, string $source): array
    {
        return [
            'vehicleKind' => $vehicleKind, 'serviceType' => $serviceType,
            'coverageCompleteness' => $completeness, 'sourceUrls' => [$source],
            'verifiedAt' => '2026-11-20T00:00:00Z', 'staleAfter' => '2099-01-01T00:00:00Z', 'rules' => [],
        ];
    }

    /** @param array<string, mixed> $payload */
    private function editorVersion(Jurisdiction $jurisdiction, int $number, RestrictionRuleVersionStatus $status, array $payload): RestrictionRuleVersion
    {
        $encoder = app(RestrictionPayloadEncoder::class);

        return RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id, 'version' => $number, 'status' => $status,
            'payload' => $payload, 'payload_sha256' => hash('sha256', $encoder->encode($payload)),
            'base_publication_revision' => 0,
        ]);
    }

    /** @param list<array<string, mixed>> $cities
     * @return array<string, mixed>
     */
    private function datasetPayload(string $version, array $cities): array
    {
        return [
            'schemaVersion' => 2, 'datasetKey' => 'restrictions', 'version' => $version,
            'generatedAt' => '2026-11-20T00:00:00Z', 'jurisdictions' => $cities,
        ];
    }

    /** @param array<string, mixed> $payload */
    private function publishedRelease(Dataset $dataset, string $version, array $payload): DatasetRelease
    {
        $bytes = app(RestrictionPayloadEncoder::class)->encode($payload, pretty: true);
        $path = "datasets/restrictions/$version/restrictions-$version.json";
        Storage::disk('public')->put($path, $bytes);
        $release = $dataset->releases()->create([
            'version' => $version, 'status' => DatasetReleaseStatus::Draft,
            'asset_path' => $path, 'sha256' => hash('sha256', $bytes), 'published_at' => now(),
        ]);
        \Illuminate\Support\Facades\DB::table('dataset_releases')->where('id', $release->id)->update([
            'status' => DatasetReleaseStatus::Published->value,
        ]);

        return $release->refresh();
    }

    /** @param array<string, mixed> $payload */
    private function replaceReleaseAsset(DatasetRelease $release, array $payload): void
    {
        $bytes = app(RestrictionPayloadEncoder::class)->encode($payload, pretty: true);
        Storage::disk('public')->put($release->asset_path, $bytes);
        \Illuminate\Support\Facades\DB::table('dataset_releases')->where('id', $release->id)->update([
            'sha256' => hash('sha256', $bytes),
        ]);
        $release->refresh();
    }

    private function publicationItem(DatasetRelease $release, User $actor, Jurisdiction $jurisdiction, RestrictionRuleVersion $version, int $revision): void
    {
        $publication = RestrictionPublication::query()->create([
            'dataset_release_id' => $release->id, 'action' => 'publish',
            'base_publication_revision' => $revision - 1, 'result_publication_revision' => $revision,
            'actor_id' => $actor->id, 'summary' => ['jurisdictionCount' => 1],
        ]);
        RestrictionPublicationItem::query()->create([
            'restriction_publication_id' => $publication->id, 'jurisdiction_id' => $jurisdiction->id,
            'restriction_rule_version_id' => $version->id, 'action' => 'publish',
        ]);
    }

    /** @param list<array<string, mixed>> $rows
     * @return array<string, mixed>
     */
    private function matrixRow(array $rows, string $municipalityCode): array
    {
        foreach ($rows as $row) {
            if ($row['municipality']->code === $municipalityCode) {
                return $row;
            }
        }

        self::fail("Municipality $municipalityCode was not present in the matrix.");
    }

    /** @return list<array<string, string>> */
    private function csvRows(string $csv): array
    {
        $stream = fopen('php://temp', 'w+b');
        self::assertNotFalse($stream);
        fwrite($stream, $csv);
        rewind($stream);
        $headers = fgetcsv($stream, null, ',', '"', '');
        self::assertIsArray($headers);
        $rows = [];
        while (($values = fgetcsv($stream, null, ',', '"', '')) !== false) {
            if (count($values) === count($headers)) {
                $rows[] = array_combine($headers, $values);
            }
        }
        fclose($stream);

        return $rows;
    }
}
