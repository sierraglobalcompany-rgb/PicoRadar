<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionPublication;
use App\Models\User;
use App\Services\DatasetPublisher;
use App\Services\DatasetReleaseValidator;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RestrictionPublicationServiceTest extends TestCase
{
    use RefreshDatabase;

    private User $actor;

    private Dataset $dataset;

    private Jurisdiction $alpha;

    private Jurisdiction $beta;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
        $this->actor = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $this->dataset->sources()->create(['title' => 'Synthetic source', 'authority' => 'Synthetic authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $country = GeographicUnit::query()->create(['key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $department = GeographicUnit::query()->create(['parent_id' => $country->id, 'key' => 'co-99', 'level' => 'department', 'code' => '99', 'name' => 'Departamento sintético', 'normalized_name' => 'departamento sintetico', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $alphaUnit = GeographicUnit::query()->create(['parent_id' => $department->id, 'key' => 'co-99001', 'level' => 'municipality', 'code' => '99001', 'name' => 'Alpha sintética', 'normalized_name' => 'alpha sintetica', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $betaUnit = GeographicUnit::query()->create(['parent_id' => $department->id, 'key' => 'co-99002', 'level' => 'municipality', 'code' => '99002', 'name' => 'Beta sintética', 'normalized_name' => 'beta sintetica', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $this->alpha = Jurisdiction::query()->create(['key' => 'co-alpha', 'name' => 'Alpha sintética', 'kind' => 'city', 'primary_geographic_unit_id' => $alphaUnit->id, 'enabled' => true, 'timezone' => 'America/Bogota']);
        $this->beta = Jurisdiction::query()->create(['key' => 'co-beta', 'name' => 'Beta sintética', 'kind' => 'city', 'primary_geographic_unit_id' => $betaUnit->id, 'enabled' => true, 'timezone' => 'America/Bogota']);
        $this->publishBaseline();
    }

    public function test_selective_publication_and_city_rollback_preserve_other_cities(): void
    {
        $versions = app(RestrictionRuleVersionService::class);
        $publisher = app(RestrictionPublicationService::class);
        $alphaV1 = $versions->validate($versions->createDraft($this->alpha, $this->city($this->alpha, [2]), $this->actor), $this->actor);
        $publisher->publish([$alphaV1->id], 1, $this->actor);
        $betaV1 = $versions->validate($versions->createDraft($this->beta, $this->city($this->beta, [3]), $this->actor), $this->actor);
        $publisher->publish([$betaV1->id], 2, $this->actor);
        $alphaV2Payload = $this->city($this->alpha, [4]);
        $alphaV2Payload['coverages'][] = $this->emptyMotorcycleCoverage();
        $alphaV2 = $versions->validate($versions->createDraft($this->alpha, $alphaV2Payload, $this->actor), $this->actor);
        $publisher->publish([$alphaV2->id], 3, $this->actor);

        $publisher->rollbackCity($alphaV1, 4, $this->actor);

        $payload = $this->currentPayload();
        $this->assertSame([2], $this->digits($payload, 'co-alpha'));
        $this->assertSame([3], $this->digits($payload, 'co-beta'));
        $alpha = array_values(array_filter($payload['jurisdictions'], static fn (array $city): bool => $city['id'] === 'co-alpha'))[0];
        $this->assertCount(1, $alpha['coverages']);
        $this->assertSame(5, $this->dataset->refresh()->publication_revision);
        $this->assertSame(['publish', 'publish', 'publish', 'rollback'], RestrictionPublication::query()->orderBy('id')->pluck('action')->all());
        $last = RestrictionPublication::query()->latest('id')->firstOrFail();
        $this->assertSame([$this->alpha->id], $last->items()->pluck('jurisdiction_id')->all());
    }

    public function test_normal_publication_rejects_coverage_loss_before_writing_release(): void
    {
        $versions = app(RestrictionRuleVersionService::class);
        $publisher = app(RestrictionPublicationService::class);
        $complete = $this->city($this->alpha, [2]);
        $complete['coverages'][] = $this->emptyMotorcycleCoverage();
        $first = $versions->validate($versions->createDraft($this->alpha, $complete, $this->actor), $this->actor);
        $publisher->publish([$first->id], 1, $this->actor);

        $incomplete = $versions->validate(
            $versions->createDraft($this->alpha, $this->city($this->alpha, [3]), $this->actor),
            $this->actor,
        );
        $releaseCount = $this->dataset->releases()->count();
        $draftsBefore = Storage::disk('local')->allFiles('dataset-drafts/restrictions');
        $manifestBefore = Storage::disk('public')->get(config('datasets.manifest_path'));

        try {
            $publisher->publish([$incomplete->id], 2, $this->actor);
            $this->fail('A publication that drops an existing coverage was accepted.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('REJECT_COVERAGE_LOSS', $error->getMessage());
            $this->assertStringContainsString('motorcycle/private', $error->getMessage());
        }

        $this->assertSame($releaseCount, $this->dataset->releases()->count());
        $this->assertSame(2, $this->dataset->refresh()->publication_revision);
        $this->assertSame(1, RestrictionPublication::query()->count());
        $this->assertSame($draftsBefore, Storage::disk('local')->allFiles('dataset-drafts/restrictions'));
        $this->assertSame($manifestBefore, Storage::disk('public')->get(config('datasets.manifest_path')));
    }

    public function test_new_jurisdiction_without_a_baseline_remains_publishable(): void
    {
        $department = GeographicUnit::query()->where('level', 'department')->firstOrFail();
        $unit = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'co-99003', 'level' => 'municipality', 'code' => '99003',
            'name' => 'Gamma sintética', 'normalized_name' => 'gamma sintetica', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'v1',
        ]);
        $gamma = Jurisdiction::query()->create([
            'key' => 'co-gamma', 'name' => 'Gamma sintética', 'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id, 'enabled' => true, 'timezone' => 'America/Bogota',
        ]);
        $versions = app(RestrictionRuleVersionService::class);
        $validated = $versions->validate($versions->createDraft($gamma, $this->city($gamma, [6]), $this->actor), $this->actor);

        app(RestrictionPublicationService::class)->publish([$validated->id], 1, $this->actor);

        $this->assertSame(2, $this->dataset->refresh()->publication_revision);
        $this->assertSame([6], $this->digits($this->currentPayload(), 'co-gamma'));
    }

    public function test_publish_rejects_stale_revision_and_duplicate_city_selection_without_writing_a_release(): void
    {
        $versions = app(RestrictionRuleVersionService::class);
        $alpha = $versions->validate($versions->createDraft($this->alpha, $this->city($this->alpha, [7]), $this->actor), $this->actor);
        $duplicate = $versions->validate($versions->createDraft($this->alpha, $this->city($this->alpha, [8]), $this->actor), $this->actor);

        try {
            app(RestrictionPublicationService::class)->publish([$alpha->id, $duplicate->id], 1, $this->actor);
            $this->fail('Two versions for one city were published together.');
        } catch (DomainException $error) {
            $this->assertSame('Only one rule version per jurisdiction can be published.', $error->getMessage());
        }

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('The dataset changed after review; refresh the publication preview.');
        try {
            app(RestrictionPublicationService::class)->publish([$alpha->id], 0, $this->actor);
        } finally {
            $this->assertSame(1, $this->dataset->releases()->count());
        }
    }

    public function test_city_rollback_only_accepts_a_version_previously_published_for_that_city(): void
    {
        $draft = app(RestrictionRuleVersionService::class)->validate(
            app(RestrictionRuleVersionService::class)->createDraft($this->alpha, $this->city($this->alpha, [9]), $this->actor),
            $this->actor,
        );

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('Rollback target was never published for this jurisdiction.');
        app(RestrictionPublicationService::class)->rollbackCity($draft, 1, $this->actor);
    }

    public function test_publishing_the_active_city_version_is_a_no_op(): void
    {
        $versions = app(RestrictionRuleVersionService::class);
        $alpha = $versions->validate($versions->createDraft($this->alpha, $this->city($this->alpha, [2]), $this->actor), $this->actor);
        $publisher = app(RestrictionPublicationService::class);
        $publisher->publish([$alpha->id], 1, $this->actor);

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('The selected city rules are already active.');
        try {
            $publisher->publish([$alpha->id], 2, $this->actor);
        } finally {
            $this->assertSame(2, $this->dataset->releases()->count());
            $this->assertSame(2, $this->dataset->refresh()->publication_revision);
        }
    }

    private function publishBaseline(): void
    {
        $payload = [
            'schemaVersion' => 1, 'datasetKey' => 'restrictions', 'version' => 'synthetic-baseline',
            'generatedAt' => '2026-09-20T12:00:00Z',
            'jurisdictions' => [$this->city($this->alpha, [0]), $this->city($this->beta, [1])],
        ];
        $path = 'dataset-drafts/restrictions/synthetic-baseline.json';
        Storage::disk('local')->put($path, json_encode($payload, JSON_THROW_ON_ERROR));
        $release = $this->dataset->releases()->create(['version' => 'synthetic-baseline', 'status' => DatasetReleaseStatus::Draft, 'draft_path' => $path]);
        app(DatasetReleaseValidator::class)->validate($release, $this->actor);
        app(DatasetPublisher::class)->publish($release, $this->actor);
    }

    /** @return array<string,mixed> */
    private function city(Jurisdiction $jurisdiction, array $digits): array
    {
        return [
            'id' => $jurisdiction->key, 'name' => $jurisdiction->name,
            'coverages' => [[
                'vehicleKind' => 'car', 'serviceType' => 'private', 'verifiedAt' => '2026-09-01T05:00:00Z',
                'staleAfter' => '2027-01-15T05:00:00Z', 'sourceUrls' => ['https://example.test/rules'],
                'rules' => [[
                    'id' => $jurisdiction->key.'-synthetic-rule-'.implode('-', $digits), 'priority' => 100, 'effect' => 'restrict',
                    'validFrom' => '2026-09-01T00:00:00-05:00', 'validUntil' => '2026-12-31T23:59:59-05:00',
                    'weekdays' => [1], 'digitPosition' => 'lastNumeric', 'digits' => $digits,
                    'timeWindows' => [['startMinute' => 360, 'endMinute' => 1200]], 'appliesOnHolidays' => false,
                    'sourceUrl' => 'https://example.test/rules', 'verifiedAt' => '2026-09-01T05:00:00Z',
                ]],
            ]],
        ];
    }

    /** @return array<string,mixed> */
    private function emptyMotorcycleCoverage(): array
    {
        return [
            'vehicleKind' => 'motorcycle', 'serviceType' => 'private', 'verifiedAt' => '2026-09-01T05:00:00Z',
            'staleAfter' => '2027-01-15T05:00:00Z', 'sourceUrls' => ['https://example.test/rules'], 'rules' => [],
        ];
    }

    /** @return array<string,mixed> */
    private function currentPayload(): array
    {
        $release = $this->dataset->releases()->where('version', $this->dataset->refresh()->current_version)->firstOrFail();

        return json_decode(Storage::disk('public')->get($release->asset_path), true, 512, JSON_THROW_ON_ERROR);
    }

    /** @param array<string,mixed> $payload @return list<int> */
    private function digits(array $payload, string $jurisdiction): array
    {
        foreach ($payload['jurisdictions'] as $city) {
            if ($city['id'] === $jurisdiction) {
                return $city['coverages'][0]['rules'][0]['digits'];
            }
        }

        $this->fail("Jurisdiction $jurisdiction is missing from the published payload.");
    }
}
