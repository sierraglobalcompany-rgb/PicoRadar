<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Enums\RestrictionImportStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Services\DatasetPublisher;
use App\Services\DatasetReleaseValidator;
use App\Services\RestrictionImportService;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class BogotaNovember2026PublicationTest extends TestCase
{
    use RefreshDatabase;

    private const R2_RELEASE_SHA256 = 'c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5';

    public function test_editorial_json_is_analyzed_and_confirmed_then_noops_against_the_exact_r2_baseline(): void
    {
        Storage::fake('local');
        Storage::fake('public');

        $evidenceDirectory = getenv('PICORADAR_R2_EVIDENCE_DIR');
        self::assertIsString($evidenceDirectory);
        self::assertNotSame('', $evidenceDirectory, 'The exact R2 baseline evidence directory is required.');
        $baselinePath = $evidenceDirectory.DIRECTORY_SEPARATOR.'ACTUAL_R2_LARAVEL_RELEASE.json';
        $baselineBytes = file_get_contents($baselinePath);
        self::assertIsString($baselineBytes, 'The R2 release must be supplied; the bundled R4 dataset is not a baseline.');
        self::assertSame(self::R2_RELEASE_SHA256, hash('sha256', $baselineBytes));
        $baseline = json_decode($baselineBytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertSame(7, count($baseline['jurisdictions']));
        self::assertSame(12, $this->coverageCount($baseline));

        $editorialPath = base_path('database/data/restrictions/official/2026-11-bogota.json');
        $editorialBytes = file_get_contents($editorialPath);
        self::assertIsString($editorialBytes);
        $editorial = json_decode($editorialBytes, true, 512, JSON_THROW_ON_ERROR);
        self::assertSame(['jurisdictions'], array_keys($editorial));
        self::assertCount(1, $editorial['jurisdictions']);
        $bogota = $editorial['jurisdictions'][0];
        self::assertSame('co-dc-bogota', $bogota['id']);
        self::assertSame(['car/private', 'motorcycle/private', 'car/taxi'], $this->coverageKeys($bogota));
        $baselineBogota = $this->city($baseline, 'co-dc-bogota');
        self::assertSame($this->canonical($baselineBogota), $this->canonical($bogota));

        $taxi = $this->coverage($bogota, 'car', 'taxi');
        $digitsByDate = [];
        foreach ($taxi['rules'] as $rule) {
            $date = substr($rule['validFrom'], 0, 10);
            $digitsByDate[$date] = $rule['digits'];
            self::assertSame($date, substr($rule['validUntil'], 0, 10));
            self::assertSame([(int) (new \DateTimeImmutable($rule['validFrom']))->format('N')], $rule['weekdays']);
            self::assertSame(330, $rule['timeWindows'][0]['startMinute']);
            self::assertSame(1260, $rule['timeWindows'][0]['endMinute']);
            self::assertFalse($rule['appliesOnHolidays']);
            self::assertSame($taxi['sourceUrls'][0], $rule['sourceUrl']);
            self::assertSame($taxi['verifiedAt'], $rule['verifiedAt']);
        }
        self::assertCount(23, $digitsByDate);
        self::assertSame([1, 2], $digitsByDate['2026-11-03']);
        self::assertSame([1, 2], $digitsByDate['2026-11-09']);
        self::assertArrayNotHasKey('2026-11-16', $digitsByDate);
        self::assertSame([7, 8], $digitsByDate['2026-11-30']);
        self::assertSame('bogota.gov.co', parse_url($taxi['sourceUrls'][0], PHP_URL_HOST));

        $actor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true,
        ]);
        $this->registerSources($dataset, $baseline);
        $jurisdictions = $this->createJurisdictions($baseline);
        $baselineDraftPath = 'dataset-drafts/restrictions/'.$baseline['version'].'.json';
        Storage::disk('local')->put($baselineDraftPath, $baselineBytes);
        $baselineRelease = $dataset->releases()->create([
            'version' => $baseline['version'], 'status' => DatasetReleaseStatus::Draft, 'draft_path' => $baselineDraftPath,
        ]);
        app(DatasetReleaseValidator::class)->validate($baselineRelease, $actor);
        app(DatasetPublisher::class)->publish($baselineRelease, $actor);
        self::assertSame(1, $dataset->refresh()->publication_revision);

        $imports = app(RestrictionImportService::class);
        $import = $imports->analyze($editorialPath, basename($editorialPath), 'json', null, $actor);
        $idempotent = $imports->analyze($editorialPath, 'renamed-editorial.json', 'json', null, $actor);
        self::assertTrue($import->is($idempotent));
        self::assertSame(1, $import->valid_count);
        self::assertSame(0, $import->invalid_count);
        self::assertSame(0, $import->excluded_count);
        self::assertSame(RestrictionImportStatus::Analyzed, $import->status);
        self::assertSame(0, RestrictionRuleVersion::query()->count());
        self::assertSame(1, $dataset->releases()->count());
        Storage::disk('local')->assertExists($import->private_path);
        $row = $import->rows()->firstOrFail();
        self::assertSame($this->canonical($bogota), $this->canonical($row->normalized['payload']));

        $versions = app(RestrictionImportService::class)->confirm($import, [$row->id], $actor);
        self::assertCount(1, $versions);
        self::assertSame(RestrictionImportStatus::Confirmed, $import->fresh()->status);
        self::assertSame(RestrictionRuleVersionStatus::Draft, $versions[0]->status);
        self::assertSame($this->canonical($bogota), $this->canonical($versions[0]->payload));
        self::assertSame(1, $dataset->releases()->count(), 'Confirmation must not publish a release.');
        $manifestBeforeNoop = Storage::disk('public')->get(config('datasets.manifest_path'));

        $validated = app(RestrictionRuleVersionService::class)->validate($versions[0], $actor);
        self::assertSame(RestrictionRuleVersionStatus::Validated, $validated->status);
        try {
            app(RestrictionPublicationService::class)->publish([$validated->id], 1, $actor);
            self::fail('The official R2 payload should be a no-op against its identical baseline.');
        } catch (DomainException $error) {
            self::assertSame('The selected city rules are already active.', $error->getMessage());
        }

        self::assertSame(1, $dataset->releases()->count());
        self::assertSame(1, $dataset->refresh()->publication_revision);
        self::assertSame($manifestBeforeNoop, Storage::disk('public')->get(config('datasets.manifest_path')));
        self::assertSame(7, count($baseline['jurisdictions']));
        self::assertSame(12, $this->coverageCount($baseline));
    }

    private function registerSources(Dataset $dataset, array $payload): void
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
            $dataset->sources()->create([
                'title' => 'R2 verified baseline source', 'authority' => 'Recorded source authority',
                'url' => $url, 'verified_at' => $verifiedAt, 'is_active' => true,
            ]);
        }
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

    private function city(array $payload, string $id): array
    {
        foreach ($payload['jurisdictions'] as $city) {
            if ($city['id'] === $id) {
                return $city;
            }
        }
        self::fail("Missing jurisdiction $id.");
    }

    private function coverage(array $city, string $vehicleKind, string $serviceType): array
    {
        foreach ($city['coverages'] as $coverage) {
            if ($coverage['vehicleKind'] === $vehicleKind && $coverage['serviceType'] === $serviceType) {
                return $coverage;
            }
        }
        self::fail("Missing coverage $vehicleKind/$serviceType in {$city['id']}.");
    }

    private function coverageKeys(array $city): array
    {
        return array_map(static fn (array $coverage): string => $coverage['vehicleKind'].'/'.$coverage['serviceType'], $city['coverages']);
    }

    private function coverageCount(array $payload): int
    {
        return array_sum(array_map(static fn (array $city): int => count($city['coverages']), $payload['jurisdictions']));
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
}
