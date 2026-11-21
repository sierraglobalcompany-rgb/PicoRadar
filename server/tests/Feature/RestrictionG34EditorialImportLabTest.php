<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Enums\RestrictionImportStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\DatasetPublisher;
use App\Services\DatasetReleaseValidator;
use App\Services\GeographyImporter;
use App\Services\JurisdictionService;
use App\Services\RestrictionImportService;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RestrictionG34EditorialImportLabTest extends TestCase
{
    use RefreshDatabase;

    public function test_three_proposals_match_independent_rotation_oracles_and_remain_partial(): void
    {
        $expected = [
            'co-ant-medellin' => [
                'car/private' => [
                    'position' => 'lastNumeric', 'from' => '2026-08-03', 'until' => '2026-12-31',
                    'minutes' => [[300, 1200]],
                    'digits' => [1 => [5, 8], 2 => [1, 4], 3 => [0, 2], 4 => [3, 6], 5 => [7, 9]],
                ],
                'motorcycle/private' => [
                    'position' => 'firstNumeric', 'from' => '2026-08-03', 'until' => '2026-12-31',
                    'minutes' => [[300, 1200]],
                    'digits' => [1 => [5, 8], 2 => [1, 4], 3 => [0, 2], 4 => [3, 6], 5 => [7, 9]],
                ],
            ],
            'co-bol-cartagena' => [
                'car/private' => [
                    'position' => 'lastNumeric', 'from' => '2026-10-05', 'until' => '2026-12-10',
                    'minutes' => [[420, 540], [1080, 1200]],
                    'digits' => [1 => [1, 2], 2 => [3, 4], 3 => [5, 6], 4 => [7, 8], 5 => [9, 0]],
                ],
                'motorcycle/private' => [
                    'position' => 'lastNumeric', 'from' => '2026-10-05', 'until' => '2026-12-10',
                    'minutes' => [[300, 1380]],
                    'digits' => [1 => [1, 2], 2 => [3, 4], 3 => [5, 6], 4 => [7, 8], 5 => [9, 0]],
                ],
            ],
            'co-cal-manizales' => [
                'car/private' => [
                    'position' => 'lastNumeric', 'from' => '2026-11-03', 'until' => '2026-11-30',
                    'minutes' => [[360, 1200]],
                    'digits' => [1 => [1, 2], 2 => [3, 4], 3 => [5, 6], 4 => [7, 8], 5 => [9, 0]],
                ],
            ],
        ];
        $directory = base_path('database/data/restrictions/official/g34');
        $files = glob($directory.DIRECTORY_SEPARATOR.'*.json');
        self::assertCount(3, $files);
        $actualCities = [];

        foreach ($files as $file) {
            $envelope = json_decode(file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
            self::assertSame(2, $envelope['schemaVersion']);
            $city = $envelope['jurisdictions'][0];
            $cityId = $city['id'];
            $actualCities[$cityId] = true;
            self::assertArrayHasKey($cityId, $expected);
            $actualCoverages = [];

            foreach ($city['coverages'] as $coverage) {
                self::assertSame('partial', $coverage['coverageCompleteness']);
                self::assertSame('2026-11-17', substr($coverage['staleAfter'], 0, 10));
                $key = $coverage['vehicleKind'].'/'.$coverage['serviceType'];
                self::assertArrayHasKey($key, $expected[$cityId]);
                $oracle = $expected[$cityId][$key];
                $actualDigits = [];
                foreach ($coverage['rules'] as $rule) {
                    $weekday = $rule['weekdays'][0];
                    $actualDigits[$weekday] = $rule['digits'];
                    self::assertSame($oracle['position'], $rule['digitPosition']);
                    self::assertSame($oracle['from'], substr($rule['validFrom'], 0, 10));
                    self::assertSame($oracle['until'], substr($rule['validUntil'], 0, 10));
                    self::assertFalse($rule['appliesOnHolidays']);
                    self::assertSame($oracle['minutes'], array_map(
                        fn (array $window): array => [$window['startMinute'], $window['endMinute']],
                        $rule['timeWindows'],
                    ));
                }
                ksort($actualDigits);
                self::assertSame($oracle['digits'], $actualDigits);
                $actualCoverages[$key] = true;
            }

            self::assertSame(array_fill_keys(array_keys($expected[$cityId]), true), $actualCoverages);
        }

        $expectedCities = array_fill_keys(array_keys($expected), true);
        ksort($expectedCities);
        ksort($actualCities);
        self::assertSame($expectedCities, $actualCities);
    }

    public function test_three_city_proposals_import_and_validate_in_fake_database_without_publication(): void
    {
        Storage::fake('local');
        Storage::fake('public');
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->assertSame(33, app(GeographyImporter::class)->bootstrap()['departments']);

        $catalogPath = base_path('../mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json');
        $catalogHashBefore = hash_file('sha256', $catalogPath);
        $catalog = json_decode(file_get_contents($catalogPath), true, 512, JSON_THROW_ON_ERROR);
        foreach (['co-bol-cartagena', 'co-cal-manizales'] as $cityId) {
            $record = collect($catalog['records'])->firstWhere('id', $cityId);
            self::assertFalse($record['engineEnabled']);
            $jurisdiction = Jurisdiction::query()->where('key', $cityId)->firstOrFail();
            app(JurisdictionService::class)->update($jurisdiction, ['enabled' => true], $editor);
            self::assertTrue($jurisdiction->fresh()->enabled);
        }
        $this->assertSame($catalogHashBefore, hash_file('sha256', $catalogPath));

        $dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 2, 'enabled' => true,
        ]);
        $paths = [
            base_path('database/data/restrictions/official/g34/2026-11-medellin.json'),
            base_path('database/data/restrictions/official/g34/2026-11-cartagena.json'),
            base_path('database/data/restrictions/official/g34/2026-11-manizales.json'),
        ];
        $allSources = [];
        foreach ($paths as $path) {
            $proposal = json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
            self::assertSame(2, $proposal['schemaVersion']);
            foreach ($proposal['jurisdictions'][0]['coverages'] as $coverage) {
                $allSources = [...$allSources, ...$coverage['sourceUrls']];
            }
        }
        foreach (array_unique($allSources) as $source) {
            $dataset->sources()->create([
                'title' => 'G34 official proposal source', 'authority' => parse_url($source, PHP_URL_HOST),
                'url' => $source, 'verified_at' => now(), 'is_active' => true,
            ]);
        }

        $imports = app(RestrictionImportService::class);
        $versionService = app(RestrictionRuleVersionService::class);
        $publication = app(RestrictionPublicationService::class);
        $coverageCounts = [];
        foreach ($paths as $path) {
            $import = $imports->analyze($path, basename($path), 'json', null, $editor);
            self::assertSame(RestrictionImportStatus::Analyzed, $import->status);
            self::assertSame(1, $import->valid_count, json_encode($import->rows()->first()->errors, JSON_THROW_ON_ERROR));
            self::assertSame(0, $import->invalid_count);

            $drafts = $imports->confirm($import, $import->rows()->pluck('id')->all(), $editor);
            self::assertCount(1, $drafts);
            self::assertSame(RestrictionImportStatus::Confirmed, $import->fresh()->status);
            self::assertSame(2, $drafts[0]->payload['schemaVersion']);

            $validated = $versionService->validate($drafts[0], $editor);
            self::assertSame(RestrictionRuleVersionStatus::Validated, $validated->status);
            $coverageCounts[$validated->jurisdiction->key] = count($validated->payload['coverages']);
            $preview = $publication->materialChangePreview($validated, 0);
            self::assertSame('NO_BASELINE', $preview['baseCitySha256']);
            self::assertContains('new_jurisdiction', $preview['changes']);
        }

        self::assertSame([
            'co-ant-medellin' => 2,
            'co-bol-cartagena' => 2,
            'co-cal-manizales' => 1,
        ], $coverageCounts);
        self::assertSame(0, $dataset->releases()->count());
        self::assertSame(0, (int) $dataset->publication_revision);
        self::assertSame([], Storage::disk('public')->allFiles());
        self::assertDatabaseMissing('jurisdictions', ['key' => 'co-g2-synthetic']);
    }

    public function test_g34_proposals_publish_one_r2_based_lab_release_and_manifest(): void
    {
        Storage::fake('local');
        Storage::fake('public');
        $evidenceDirectory = getenv('PICORADAR_G34_LAB_EVIDENCE_DIR');
        self::assertIsString($evidenceDirectory);
        self::assertNotSame('', $evidenceDirectory);
        self::assertDirectoryExists($evidenceDirectory);

        $r2Path = getenv('PICORADAR_G2_R2_RELEASE');
        self::assertIsString($r2Path);
        self::assertNotSame('', $r2Path);
        $r2Bytes = file_get_contents($r2Path);
        self::assertIsString($r2Bytes);
        self::assertSame('c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5', hash('sha256', $r2Bytes));
        self::assertSame(58476, strlen($r2Bytes));
        $r2 = json_decode($r2Bytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertSame(1, $r2['schemaVersion']);
        self::assertCount(7, $r2['jurisdictions']);
        self::assertSame(12, array_sum(array_map(static fn (array $city): int => count($city['coverages']), $r2['jurisdictions'])));
        self::assertSame(119, array_sum(array_map(
            static fn (array $city): int => array_sum(array_map(static fn (array $coverage): int => count($coverage['rules']), $city['coverages'])),
            $r2['jurisdictions'],
        )));

        $catalogPath = base_path('../mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json');
        $catalogHashBefore = hash_file('sha256', $catalogPath);
        $geography = app(GeographyImporter::class)->bootstrap();
        self::assertSame(33, $geography['departments']);
        self::assertSame(1104, $geography['municipalities']);

        $dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions G34 lab', 'schema_version' => 2, 'enabled' => true,
        ]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        self::assertNotSame($editor->id, $reviewer->id);

        foreach (['co-bol-cartagena', 'co-cal-manizales'] as $cityId) {
            $record = collect(json_decode(file_get_contents($catalogPath), true, 512, JSON_THROW_ON_ERROR)['records'])
                ->firstWhere('id', $cityId);
            self::assertFalse($record['engineEnabled']);
            $jurisdiction = Jurisdiction::query()->where('key', $cityId)->firstOrFail();
            app(JurisdictionService::class)->update($jurisdiction, ['enabled' => true], $editor);
            self::assertTrue($jurisdiction->fresh()->enabled);
        }

        $proposalPaths = [
            base_path('database/data/restrictions/official/g34/2026-11-medellin.json'),
            base_path('database/data/restrictions/official/g34/2026-11-manizales.json'),
            base_path('database/data/restrictions/official/g34/2026-11-cartagena.json'),
        ];
        $sourceUrls = [];
        foreach ($r2['jurisdictions'] as $city) {
            foreach ($city['coverages'] as $coverage) {
                $sourceUrls = [...$sourceUrls, ...($coverage['sourceUrls'] ?? [])];
                foreach ($coverage['rules'] as $rule) {
                    if (isset($rule['sourceUrl'])) {
                        $sourceUrls[] = $rule['sourceUrl'];
                    }
                }
            }
        }
        foreach ($proposalPaths as $path) {
            $proposal = json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
            self::assertSame(2, $proposal['schemaVersion']);
            foreach ($proposal['jurisdictions'][0]['coverages'] as $coverage) {
                self::assertSame('partial', $coverage['coverageCompleteness']);
                $sourceUrls = [...$sourceUrls, ...$coverage['sourceUrls']];
                foreach ($coverage['rules'] as $rule) {
                    if (isset($rule['sourceUrl'])) {
                        $sourceUrls[] = $rule['sourceUrl'];
                    }
                }
            }
        }
        foreach (array_unique($sourceUrls) as $source) {
            $dataset->sources()->create([
                'title' => 'G34 laboratory source registration',
                'authority' => parse_url($source, PHP_URL_HOST) ?: 'LAB_SOURCE',
                'url' => $source,
                'verified_at' => now(),
                'notes' => 'LAB_ONLY_NOT_JURIDICAL_CERTIFICATION',
                'is_active' => true,
            ]);
        }

        // Seed the already-published R2 baseline in fake storage; this bypass is test-only.
        $baseline = $r2;
        $baseline['schemaVersion'] = 2;
        $baseline['version'] = 'G34_R2_LAB_BASELINE';
        $baseline['generatedAt'] = '2026-11-10T00:00:00Z';
        $baselineBytes = json_encode($baseline, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        $baselineDraft = 'dataset-drafts/restrictions/'.$baseline['version'].'.json';
        Storage::disk('local')->put($baselineDraft, $baselineBytes);
        $baselineRelease = $dataset->releases()->create([
            'version' => $baseline['version'],
            'status' => DatasetReleaseStatus::Draft,
            'draft_path' => $baselineDraft,
        ]);
        $baselineRelease = app(DatasetReleaseValidator::class)->validate($baselineRelease, $reviewer);
        app(DatasetPublisher::class)->publish($baselineRelease, $reviewer, 0);
        $baselineRevision = (int) $dataset->refresh()->publication_revision;
        self::assertSame(1, $baselineRevision);
        self::assertSame($baseline['version'], $dataset->current_version);

        $imports = app(RestrictionImportService::class);
        $versions = app(RestrictionRuleVersionService::class);
        $publication = app(RestrictionPublicationService::class);
        $validatedByCity = [];
        $previews = [];
        $proposalsByCity = [];
        foreach ($proposalPaths as $path) {
            $proposal = json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
            $cityId = $proposal['jurisdictions'][0]['id'];
            $import = $imports->analyze($path, basename($path), 'json', null, $editor);
            self::assertSame(RestrictionImportStatus::Analyzed, $import->status);
            self::assertSame(1, $import->valid_count, json_encode($import->rows()->first()->errors, JSON_THROW_ON_ERROR));
            self::assertSame(0, $import->invalid_count);
            $drafts = $imports->confirm($import, $import->rows()->pluck('id')->all(), $editor);
            self::assertCount(1, $drafts);
            $version = $versions->validate($drafts[0], $editor);
            self::assertSame(RestrictionRuleVersionStatus::Validated, $version->status);
            self::assertSame($editor->id, $version->created_by_id);
            self::assertSame($editor->id, $version->updated_by_id);
            $preview = $publication->materialChangePreview($version, $baselineRevision);
            self::assertSame($baselineRevision, $preview['publicationRevision']);
            self::assertSame($cityId, $preview['jurisdictionId']);
            self::assertNotEmpty($preview['changes']);
            self::assertNotEmpty($preview['sources']);
            if ($cityId === 'co-bol-cartagena') {
                self::assertSame('NO_BASELINE', $preview['baseCitySha256']);
                self::assertContains('new_jurisdiction', $preview['changes']);
            } else {
                self::assertNotSame('NO_BASELINE', $preview['baseCitySha256'], $cityId);
            }
            $validatedByCity[$cityId] = $version;
            $previews[$cityId] = $preview;
            $proposalsByCity[$cityId] = $proposal['jurisdictions'][0];
        }
        self::assertSame([
            'co-ant-medellin' => true,
            'co-cal-manizales' => true,
            'co-bol-cartagena' => true,
        ], array_fill_keys(array_keys($validatedByCity), true));

        try {
            $publication->publish(array_map(static fn ($version): int => $version->id, array_values($validatedByCity)), $baselineRevision, $reviewer);
            self::fail('G34 material changes published without editorial approvals.');
        } catch (DomainException $error) {
            self::assertStringContainsString('REVIEW_REQUIRED', $error->getMessage());
        }
        self::assertSame(1, $dataset->releases()->count());
        self::assertSame($baselineRevision, (int) $dataset->refresh()->publication_revision);
        self::assertSame($baseline['version'], $dataset->refresh()->current_version);

        foreach ($validatedByCity as $cityId => $version) {
            $source = $previews[$cityId]['sources'][0];
            $approval = $publication->approveMaterialChange(
                $version,
                $baselineRevision,
                $reviewer,
                'Aprobación técnica aislada del lote G34.',
                $source,
            );
            self::assertSame($reviewer->id, $approval->actor_id);
            self::assertSame('EDITORIAL_APPROVAL_ONLY', $approval->metadata['classification']);
            self::assertSame($editor->id, $approval->metadata['authorId']);
            self::assertSame($editor->id, $approval->metadata['updatedById']);
            self::assertSame($baselineRevision, $approval->metadata['publicationRevision']);
        }

        $published = $publication->publish(
            array_map(static fn ($version): int => $version->id, array_values($validatedByCity)),
            $baselineRevision,
            $reviewer,
        );
        $dataset = $dataset->refresh();
        self::assertSame(DatasetReleaseStatus::Published, $published->status);
        self::assertSame($published->version, $dataset->current_version);
        self::assertSame($baselineRevision + 1, (int) $dataset->publication_revision);
        self::assertSame(2, (int) $dataset->schema_version);

        $releaseBytes = Storage::disk('public')->get($published->asset_path);
        $manifestBytes = Storage::disk('public')->get(config('datasets.manifest_path'));
        self::assertIsString($releaseBytes);
        self::assertIsString($manifestBytes);
        $releaseSha = hash('sha256', $releaseBytes);
        $manifestSha = hash('sha256', $manifestBytes);
        self::assertSame($releaseSha, $published->sha256);
        $release = json_decode($releaseBytes, true, 512, JSON_THROW_ON_ERROR);
        $manifest = json_decode($manifestBytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertSame(2, $release['schemaVersion']);
        self::assertSame('restrictions', $release['datasetKey']);
        self::assertSame(1, $manifest['schemaVersion']);
        $entry = $manifest['datasets']['restrictions'];
        self::assertSame($published->version, $entry['version']);
        self::assertSame($releaseSha, $entry['sha256']);
        self::assertSame($dataset->publication_revision, $entry['publicationRevision']);

        $cities = [];
        $coverageCount = 0;
        $ruleCount = 0;
        foreach ($release['jurisdictions'] as $city) {
            self::assertArrayNotHasKey($city['id'], $cities);
            $cities[$city['id']] = $city;
            $coverageCount += count($city['coverages']);
            foreach ($city['coverages'] as $coverage) {
                $ruleCount += count($coverage['rules']);
            }
        }
        self::assertCount(8, $cities);
        self::assertSame(14, $coverageCount);
        self::assertArrayNotHasKey('co-g2-synthetic', $cities);

        $modifiedCityIds = ['co-ant-medellin', 'co-cal-manizales'];
        $untouchedLegacyCount = 0;
        foreach ($r2['jurisdictions'] as $legacyCity) {
            $cityId = $legacyCity['id'];
            if (in_array($cityId, $modifiedCityIds, true)) {
                $beforePairs = array_map(static fn (array $coverage): string => $coverage['vehicleKind'].'/'.$coverage['serviceType'], $legacyCity['coverages']);
                $afterPairs = array_map(static fn (array $coverage): string => $coverage['vehicleKind'].'/'.$coverage['serviceType'], $cities[$cityId]['coverages']);
                sort($beforePairs);
                sort($afterPairs);
                self::assertSame($beforePairs, $afterPairs, $cityId.' coverage identities changed.');
            } else {
                self::assertSame($legacyCity, $cities[$cityId], $cityId.' legacy jurisdiction changed.');
                $untouchedLegacyCount++;
            }
        }
        self::assertSame(5, $untouchedLegacyCount);
        $g34CoverageCount = 0;
        foreach ($proposalsByCity as $cityId => $proposalCity) {
            self::assertArrayHasKey($cityId, $cities);
            $expectedPairs = array_map(static fn (array $coverage): string => $coverage['vehicleKind'].'/'.$coverage['serviceType'], $proposalCity['coverages']);
            $publishedPairs = array_map(static fn (array $coverage): string => $coverage['vehicleKind'].'/'.$coverage['serviceType'], $cities[$cityId]['coverages']);
            sort($expectedPairs);
            sort($publishedPairs);
            self::assertSame($expectedPairs, $publishedPairs, $cityId.' proposal coverage identities changed.');
            foreach ($cities[$cityId]['coverages'] as $coverage) {
                self::assertSame('partial', $coverage['coverageCompleteness']);
                $g34CoverageCount++;
            }
        }
        self::assertSame(5, $g34CoverageCount);
        self::assertSame($catalogHashBefore, hash_file('sha256', $catalogPath));
        self::assertSame([], $dataset->releases()->where('version', 'like', '%co-g2-synthetic%')->pluck('version')->all());

        $actualReleasePath = $evidenceDirectory.DIRECTORY_SEPARATOR.'G34_PHP_RELEASE.json';
        $actualManifestPath = $evidenceDirectory.DIRECTORY_SEPARATOR.'G34_PHP_MANIFEST.json';
        self::assertSame(strlen($releaseBytes), file_put_contents($actualReleasePath, $releaseBytes));
        self::assertSame(strlen($manifestBytes), file_put_contents($actualManifestPath, $manifestBytes));
        $result = [
            'classification' => 'LAB_ONLY_NOT_JURIDICAL_CERTIFICATION',
            'baselineR2Sha256' => hash('sha256', $r2Bytes),
            'releaseSha256' => $releaseSha,
            'manifestSha256' => $manifestSha,
            'releaseVersion' => $published->version,
            'publicationRevision' => $dataset->publication_revision,
            'schemaVersion' => $release['schemaVersion'],
            'manifestSchemaVersion' => $manifest['schemaVersion'],
            'jurisdictions' => count($cities),
            'coverages' => $coverageCount,
            'g34PartialCoverages' => $g34CoverageCount,
            'measuredRuleCount' => $ruleCount,
            'untouchedR2Jurisdictions' => $untouchedLegacyCount,
            'editorFakeId' => $editor->id,
            'reviewerFakeId' => $reviewer->id,
            'catalogSha256BeforeAfter' => $catalogHashBefore,
            'syntheticJurisdictionIncluded' => false,
        ];
        $resultBytes = json_encode($result, JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n";
        self::assertSame(strlen($resultBytes), file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'G34_LAB_RESULT.json', $resultBytes));
    }
}
