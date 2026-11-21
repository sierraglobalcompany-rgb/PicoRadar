<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Enums\RestrictionImportStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\DatasetPublisher;
use App\Services\DatasetReleaseValidator;
use App\Services\RestrictionImportService;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RestrictionNationalLabPublicationTest extends TestCase
{
    use RefreshDatabase;

    private const R2_RELEASE_SHA256 = 'c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5';

    private string $baselineBytes;

    /** @var array<string,mixed> */
    private array $baseline;

    private User $actor;

    private Dataset $dataset;

    /** @var array<string,Jurisdiction> */
    private array $jurisdictions;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
        [$this->baselineBytes, $this->baseline] = $this->readR2Baseline();
        $this->actor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true,
        ]);
        $this->registerSources($this->baseline);
        $this->jurisdictions = $this->createJurisdictions($this->baseline);
        $this->publishBaseline();
    }

    public function test_two_synthetic_city_imports_publish_in_one_laboratory_batch_and_export_exact_bytes(): void
    {
        $evidenceDirectory = getenv('PICORADAR_G1_EVIDENCE_DIR');
        self::assertIsString($evidenceDirectory);
        self::assertNotSame('', $evidenceDirectory, 'G1 evidence directory is required; this E2E is never skipped.');
        self::assertDirectoryExists($evidenceDirectory);

        $officialBytes = file_get_contents(base_path('database/data/restrictions/official/2026-11-bogota.json'));
        self::assertIsString($officialBytes);
        self::assertSame(
            strlen($officialBytes),
            file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'SOURCE_BOGOTA_EDITORIAL.json', $officialBytes),
        );
        $official = json_decode($officialBytes, true, 512, JSON_THROW_ON_ERROR);
        $bogotaBefore = $this->city($this->baseline, 'co-dc-bogota');
        $bogotaOfficial = $this->city($official, 'co-dc-bogota');
        self::assertSame($this->canonical($bogotaBefore), $this->canonical($bogotaOfficial));

        $bogotaSynthetic = $bogotaOfficial;
        $bogotaPrivate = &$bogotaSynthetic['coverages'][0];
        self::assertSame('car', $bogotaPrivate['vehicleKind']);
        self::assertSame('private', $bogotaPrivate['serviceType']);
        $this->changeOneDigit($bogotaPrivate);
        unset($bogotaPrivate);
        $bogotaOnlyDigitChange = $bogotaSynthetic;
        $bogotaOnlyDigitChange['coverages'][0]['rules'][0]['digits'] = $bogotaOfficial['coverages'][0]['rules'][0]['digits'];
        self::assertSame($this->canonical($bogotaOfficial), $this->canonical($bogotaOnlyDigitChange));

        $popayanBefore = $this->city($this->baseline, 'co-cau-popayan');
        $popayanSynthetic = $popayanBefore;
        $popayanPrivateIndex = $this->coverageIndex($popayanSynthetic, 'car', 'private');
        $popayanPrivate = &$popayanSynthetic['coverages'][$popayanPrivateIndex];
        $testSource = 'https://example.test/synthetic-not-for-release';
        $popayanPrivate['verifiedAt'] = '2026-11-10T00:00:00Z';
        $popayanPrivate['staleAfter'] = '2026-11-17T00:00:00Z';
        $popayanPrivate['sourceUrls'] = array_values(array_unique([...$popayanPrivate['sourceUrls'], $testSource]));
        $this->changeOneDigit($popayanPrivate);
        $popayanPrivate['rules'][0]['sourceUrl'] = $testSource;
        $popayanPrivate['rules'][0]['verifiedAt'] = '2026-11-10T00:00:00Z';
        unset($popayanPrivate);

        $bogotaInput = ['jurisdictions' => [$bogotaSynthetic]];
        $popayanInput = ['jurisdictions' => [$popayanSynthetic]];
        $bogotaPath = $evidenceDirectory.DIRECTORY_SEPARATOR.'BOGOTA_SYNTHETIC_VARIANT_ONLY.json';
        $popayanPath = $evidenceDirectory.DIRECTORY_SEPARATOR.'SECOND_CITY_SYNTHETIC_ONLY.json';
        $this->writeJson($bogotaPath, $bogotaInput);
        $this->writeJson($popayanPath, $popayanInput);

        $imports = app(RestrictionImportService::class);
        $bogotaImport = $imports->analyze($bogotaPath, basename($bogotaPath), 'json', null, $this->actor);
        $popayanImport = $imports->analyze($popayanPath, basename($popayanPath), 'json', null, $this->actor);
        foreach ([$bogotaImport, $popayanImport] as $import) {
            self::assertSame(RestrictionImportStatus::Analyzed, $import->status);
            self::assertSame(1, $import->valid_count, json_encode($import->rows()->first()->errors, JSON_THROW_ON_ERROR));
            self::assertSame(0, $import->invalid_count);
            self::assertSame(0, $import->excluded_count);
        }
        self::assertSame(1, $this->dataset->releases()->count(), 'Analysis must not create releases.');
        self::assertSame(1, $this->dataset->refresh()->publication_revision);

        $this->writeJson(
            $evidenceDirectory.DIRECTORY_SEPARATOR.'BEFORE_AFTER_COVERAGES.json',
            $this->coverageDiff($bogotaBefore, $bogotaSynthetic, $popayanBefore, $popayanSynthetic),
        );

        $bogotaDrafts = $imports->confirm($bogotaImport, $bogotaImport->rows()->pluck('id')->all(), $this->actor);
        $popayanDrafts = $imports->confirm($popayanImport, $popayanImport->rows()->pluck('id')->all(), $this->actor);
        self::assertCount(1, $bogotaDrafts);
        self::assertCount(1, $popayanDrafts);
        self::assertSame(RestrictionImportStatus::Confirmed, $bogotaImport->fresh()->status);
        self::assertSame(RestrictionImportStatus::Confirmed, $popayanImport->fresh()->status);
        self::assertSame(1, $this->dataset->releases()->count(), 'Explicit confirmation creates versions, not releases.');

        $versionService = app(RestrictionRuleVersionService::class);
        $bogotaVersion = $versionService->validate($bogotaDrafts[0], $this->actor);
        $popayanVersion = $versionService->validate($popayanDrafts[0], $this->actor);
        self::assertSame(RestrictionRuleVersionStatus::Validated, $bogotaVersion->status);
        self::assertSame(RestrictionRuleVersionStatus::Validated, $popayanVersion->status);

        $release = app(RestrictionPublicationService::class)->publish(
            [$bogotaVersion->id, $popayanVersion->id],
            1,
            $this->actor,
        );
        self::assertSame(DatasetReleaseStatus::Published, $release->status);
        $releaseBytes = Storage::disk('public')->get($release->asset_path);
        $manifestBytes = Storage::disk('public')->get(config('datasets.manifest_path'));
        $releaseSha = hash('sha256', $releaseBytes);
        $manifest = json_decode($manifestBytes, true, 512, JSON_THROW_ON_ERROR);
        $entry = $manifest['datasets']['restrictions'];
        self::assertSame($releaseSha, $release->sha256);
        self::assertSame($releaseSha, $entry['sha256']);
        self::assertSame($release->version, $entry['version']);
        self::assertSame(2, $entry['publicationRevision']);

        $published = json_decode($releaseBytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertSame(7, count($published['jurisdictions']));
        self::assertSame(12, $this->coverageCount($published));
        self::assertSame($this->canonical($bogotaSynthetic), $this->canonical($this->city($published, 'co-dc-bogota')));
        self::assertSame($this->canonical($popayanSynthetic), $this->canonical($this->city($published, 'co-cau-popayan')));
        foreach ($this->baseline['jurisdictions'] as $city) {
            if (! in_array($city['id'], ['co-dc-bogota', 'co-cau-popayan'], true)) {
                self::assertSame($this->canonical($city), $this->canonical($this->city($published, $city['id'])));
            }
        }

        $releaseOutput = $evidenceDirectory.DIRECTORY_SEPARATOR.'LARAVEL_REAL_LAB_RELEASE.json';
        $manifestOutput = $evidenceDirectory.DIRECTORY_SEPARATOR.'LARAVEL_REAL_LAB_MANIFEST.json';
        self::assertSame(strlen($releaseBytes), file_put_contents($releaseOutput, $releaseBytes));
        self::assertSame(strlen($manifestBytes), file_put_contents($manifestOutput, $manifestBytes));
        self::assertSame($releaseBytes, file_get_contents($releaseOutput));
        self::assertSame($manifestBytes, file_get_contents($manifestOutput));
        $this->writeJson($evidenceDirectory.DIRECTORY_SEPARATOR.'PHP_G1_LAB_RESULT.json', [
            'classification' => 'LAB_SYNTHETIC_NOT_FOR_RELEASE',
            'baselineR2Sha256' => hash('sha256', $this->baselineBytes),
            'bogotaEditorialSha256' => hash('sha256', $officialBytes),
            'bogotaVariantInputSha256' => hash_file('sha256', $bogotaPath),
            'popayanVariantInputSha256' => hash_file('sha256', $popayanPath),
            'releaseVersion' => $release->version,
            'releaseSha256' => $releaseSha,
            'manifestSha256' => hash('sha256', $manifestBytes),
            'manifestReleaseSha256' => $entry['sha256'],
            'jurisdictions' => count($published['jurisdictions']),
            'coverages' => $this->coverageCount($published),
            'changedJurisdictions' => ['co-dc-bogota', 'co-cau-popayan'],
            'otherJurisdictionsPreserved' => true,
            'publicationRevision' => $entry['publicationRevision'],
            'publicationAction' => 'one explicit two-jurisdiction laboratory batch',
        ]);
    }

    /** @return array{0:string,1:array<string,mixed>} */
    private function readR2Baseline(): array
    {
        $directory = getenv('PICORADAR_R2_EVIDENCE_DIR');
        self::assertIsString($directory);
        self::assertNotSame('', $directory, 'Exact R2 baseline is required; R4 is not a substitute.');
        $bytes = file_get_contents($directory.DIRECTORY_SEPARATOR.'ACTUAL_R2_LARAVEL_RELEASE.json');
        self::assertIsString($bytes);
        self::assertSame(self::R2_RELEASE_SHA256, hash('sha256', $bytes));
        $payload = json_decode($bytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertSame(7, count($payload['jurisdictions']));
        self::assertSame(12, $this->coverageCount($payload));

        return [$bytes, $payload];
    }

    private function registerSources(array $payload): void
    {
        $sources = [];
        foreach ($payload['jurisdictions'] as $city) {
            foreach ($city['coverages'] as $coverage) {
                foreach ($coverage['sourceUrls'] ?? [] as $url) {
                    $sources[$url] ??= $coverage['verifiedAt'] ?? $payload['generatedAt'];
                }
                foreach ($coverage['rules'] as $rule) {
                    $sources[$rule['sourceUrl']] ??= $rule['verifiedAt'] ?? $payload['generatedAt'];
                }
            }
        }
        foreach ($sources as $url => $verifiedAt) {
            $this->dataset->sources()->create([
                'title' => 'R2 verified baseline source', 'authority' => 'Recorded source authority',
                'url' => $url, 'verified_at' => $verifiedAt, 'is_active' => true,
            ]);
        }
    }

    private function publishBaseline(): void
    {
        $path = 'dataset-drafts/restrictions/'.$this->baseline['version'].'.json';
        Storage::disk('local')->put($path, $this->baselineBytes);
        $release = $this->dataset->releases()->create([
            'version' => $this->baseline['version'], 'status' => DatasetReleaseStatus::Draft, 'draft_path' => $path,
        ]);
        app(DatasetReleaseValidator::class)->validate($release, $this->actor);
        app(DatasetPublisher::class)->publish($release, $this->actor);
    }

    private function createJurisdictions(array $payload): array
    {
        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia', 'normalized_name' => 'colombia',
            'is_active' => true, 'source_system' => 'g1-test', 'source_version' => 'R2',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-g1-test', 'level' => 'department', 'code' => '99',
            'name' => 'Jurisdicción de prueba', 'normalized_name' => 'jurisdiccion de prueba', 'is_active' => true,
            'source_system' => 'g1-test', 'source_version' => 'R2',
        ]);
        $result = [];
        foreach ($payload['jurisdictions'] as $index => $city) {
            $code = $city['id'] === 'co-dc-bogota' ? '11001' : str_pad((string) (20000 + $index), 5, '0', STR_PAD_LEFT);
            $unit = GeographicUnit::query()->create([
                'parent_id' => $department->id, 'key' => $city['id'], 'level' => 'municipality', 'code' => $code,
                'name' => $city['name'], 'normalized_name' => mb_strtolower($city['name']), 'is_active' => true,
                'source_system' => 'g1-test', 'source_version' => 'R2',
            ]);
            $result[$city['id']] = Jurisdiction::query()->create([
                'key' => $city['id'], 'name' => $city['name'], 'kind' => 'city', 'primary_geographic_unit_id' => $unit->id,
                'enabled' => true, 'timezone' => 'America/Bogota',
            ]);
        }

        return $result;
    }

    private function coverageIndex(array $city, string $vehicleKind, string $serviceType): int
    {
        foreach ($city['coverages'] as $index => $coverage) {
            if ($coverage['vehicleKind'] === $vehicleKind && $coverage['serviceType'] === $serviceType) {
                return $index;
            }
        }
        self::fail("Missing coverage $vehicleKind/$serviceType in {$city['id']}.");
    }

    private function changeOneDigit(array &$coverage): void
    {
        $digits = $coverage['rules'][0]['digits'];
        foreach (range(0, 9) as $candidate) {
            if ($candidate !== $digits[0] && ! in_array($candidate, array_slice($digits, 1), true)) {
                $coverage['rules'][0]['digits'][0] = $candidate;

                return;
            }
        }
        self::fail('No distinct digit is available for the synthetic data-only variant.');
    }

    private function city(array $payload, string $id): array
    {
        foreach ($payload['jurisdictions'] as $city) {
            if ($city['id'] === $id) {
                return $city;
            }
        }
        self::fail("Missing jurisdiction $id.");
    }

    private function coverageCount(array $payload): int
    {
        return array_sum(array_map(static fn (array $city): int => count($city['coverages']), $payload['jurisdictions']));
    }

    private function coverageDiff(array $bogotaBefore, array $bogotaAfter, array $popayanBefore, array $popayanAfter): array
    {
        return [
            'classification' => 'LAB_SYNTHETIC_NOT_FOR_RELEASE',
            'generatedBeforeConfirmation' => true,
            'cities' => [
                $this->cityDiff($bogotaBefore, $bogotaAfter),
                $this->cityDiff($popayanBefore, $popayanAfter),
            ],
            'unmodifiedR2Coverages' => [
                'Bogota motorcycle/private and car/taxi are byte-semantically preserved.',
                'Popayan motorcycle/private and four unchanged car/private rules are preserved.',
                'The other five jurisdictions are preserved in the published release.',
            ],
            'rejections' => ['Normal publication coverage loss is separately rejected by REJECT_COVERAGE_LOSS test.'],
        ];
    }

    private function cityDiff(array $before, array $after): array
    {
        $beforeCoverages = [];
        foreach ($before['coverages'] as $coverage) {
            $beforeCoverages[$coverage['vehicleKind'].'/'.$coverage['serviceType']] = $coverage;
        }
        $afterCoverages = [];
        foreach ($after['coverages'] as $coverage) {
            $afterCoverages[$coverage['vehicleKind'].'/'.$coverage['serviceType']] = $coverage;
        }
        $diffs = [];
        foreach (array_unique([...array_keys($beforeCoverages), ...array_keys($afterCoverages)]) as $identity) {
            $old = $beforeCoverages[$identity] ?? null;
            $new = $afterCoverages[$identity] ?? null;
            $oldRules = $this->rulesById($old['rules'] ?? []);
            $newRules = $this->rulesById($new['rules'] ?? []);
            $added = array_values(array_diff(array_keys($newRules), array_keys($oldRules)));
            $removed = array_values(array_diff(array_keys($oldRules), array_keys($newRules)));
            $changed = [];
            $ruleChanges = [];
            foreach (array_intersect(array_keys($oldRules), array_keys($newRules)) as $ruleId) {
                $changedFields = [];
                foreach (array_unique([...array_keys($oldRules[$ruleId]), ...array_keys($newRules[$ruleId])]) as $field) {
                    $beforeValue = $oldRules[$ruleId][$field] ?? null;
                    $afterValue = $newRules[$ruleId][$field] ?? null;
                    if (array_key_exists($field, $oldRules[$ruleId]) !== array_key_exists($field, $newRules[$ruleId]) ||
                        $this->canonical($beforeValue) !== $this->canonical($afterValue)) {
                        $changedFields[$field] = ['before' => $beforeValue, 'after' => $afterValue];
                    }
                }
                if ($changedFields !== []) {
                    $changed[] = $ruleId;
                    $ruleChanges[] = ['id' => $ruleId, 'fields' => $changedFields];
                }
            }
            $same = $old !== null && $new !== null && $this->canonical($old) === $this->canonical($new);
            $diffs[] = [
                'identity' => $identity,
                'beforeCanonicalSha256' => $old === null ? null : $this->canonicalSha($old),
                'afterCanonicalSha256' => $new === null ? null : $this->canonicalSha($new),
                'preserved' => $same,
                'rulesAdded' => $added,
                'rulesAddedDetails' => array_map(static fn (string $id): array => $newRules[$id], $added),
                'rulesRemoved' => $removed,
                'rulesRemovedDetails' => array_map(static fn (string $id): array => $oldRules[$id], $removed),
                'rulesChanged' => $changed,
                'ruleChanges' => $ruleChanges,
                'verifiedAtBefore' => $old['verifiedAt'] ?? null,
                'verifiedAtAfter' => $new['verifiedAt'] ?? null,
                'staleAfterBefore' => $old['staleAfter'] ?? null,
                'staleAfterAfter' => $new['staleAfter'] ?? null,
                'sourceUrlsBefore' => $old['sourceUrls'] ?? [],
                'sourceUrlsAfter' => $new['sourceUrls'] ?? [],
            ];
        }

        return [
            'jurisdictionId' => $before['id'],
            'beforeCoverageCount' => count($beforeCoverages),
            'afterCoverageCount' => count($afterCoverages),
            'beforeCoverageIdentities' => array_keys($beforeCoverages),
            'afterCoverageIdentities' => array_keys($afterCoverages),
            'coverages' => $diffs,
        ];
    }

    private function rulesById(array $rules): array
    {
        $result = [];
        foreach ($rules as $rule) {
            $result[$rule['id']] = $rule;
        }

        return $result;
    }

    private function canonicalSha(mixed $value): string
    {
        return hash('sha256', json_encode($this->canonical($value), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    }

    private function canonical(mixed $value): mixed
    {
        if (! is_array($value)) {
            return $value;
        }
        if (array_is_list($value)) {
            return array_map(fn (mixed $item): mixed => $this->canonical($item), $value);
        }
        ksort($value);
        foreach ($value as $key => $item) {
            $value[$key] = $this->canonical($item);
        }

        return $value;
    }

    private function writeJson(string $path, array $value): void
    {
        self::assertSame(
            strlen($bytes = json_encode($value, JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)),
            file_put_contents($path, $bytes),
        );
    }
}
