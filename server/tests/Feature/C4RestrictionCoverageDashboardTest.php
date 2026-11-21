<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class C4RestrictionCoverageDashboardTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->travelTo(Carbon::parse('2026-11-20 12:00:00', 'America/Bogota'));
    }

    public function test_http_index_renders_supported_coverage_states_and_source_evidence(): void
    {
        [$department, $viewer, $dataset] = $this->baseFixtures();

        $current = $this->jurisdiction($department, '05001', 'currentville', 'Currentville');
        $expired = $this->jurisdiction($department, '05002', 'expiredtown', 'Expiredtown');
        $partial = $this->jurisdiction($department, '05003', 'partialtown', 'Partialtown');
        $unknown = $this->jurisdiction($department, '05004', 'unknowntown', 'Unknowntown');

        $this->version($current, $viewer, RestrictionRuleVersionStatus::Validated, [
            $this->coverage('car', 'complete', 'https://official.example.test/current', '2026-11-19T12:00:00-05:00', '2026-12-01T00:00:00-05:00', '2026-12-15T23:59:59-05:00'),
        ]);
        $this->version($expired, $viewer, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('motorcycle', 'complete', 'https://official.example.test/expired', '2026-11-01T12:00:00-05:00', '2026-11-10T23:59:59-05:00', '2026-11-10T23:59:59-05:00'),
        ]);
        $this->version($partial, $viewer, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('car', 'partial', 'https://official.example.test/partial', '2026-11-19T12:00:00-05:00', '2026-12-01T00:00:00-05:00', '2026-12-15T23:59:59-05:00'),
        ]);
        $this->version($unknown, $viewer, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('car', null, null, null, null, null),
        ]);

        $response = $this->actingAs($viewer)->get(route('admin.restrictions.index'));

        $response->assertOk()
            ->assertSee('Currentville')
            ->assertSee('VERIFIED')
            ->assertSee('STALE')
            ->assertSee('PARTIAL')
            ->assertSee('UNKNOWN')
            ->assertSee('https://official.example.test/current')
            ->assertSee('https://official.example.test/expired')
            ->assertSee('2026-12-15')
            ->assertSee('No verificada')
            ->assertDontSee('ALLOWED')
            ->assertDontSee('ALLOWED TO DRIVE');

        $this->assertSame(0, (int) $dataset->fresh()->publication_revision);
    }

    public function test_http_index_filters_attention_and_categories_and_paginates_the_unknown_queue(): void
    {
        [$department, $viewer] = $this->baseFixtures();

        $current = $this->jurisdiction($department, '05001', 'currentville', 'Currentville');
        $expired = $this->jurisdiction($department, '05002', 'expiredtown', 'Expiredtown');
        $partial = $this->jurisdiction($department, '05003', 'partialtown', 'Partialtown');
        $this->version($current, $viewer, RestrictionRuleVersionStatus::Validated, [
            $this->coverage('car', 'complete', 'https://official.example.test/current', '2026-11-19T12:00:00-05:00', '2026-12-01T00:00:00-05:00', '2026-12-15T23:59:59-05:00'),
        ]);
        $this->version($expired, $viewer, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('motorcycle', 'complete', 'https://official.example.test/expired', '2026-11-01T12:00:00-05:00', '2026-11-10T23:59:59-05:00', '2026-11-10T23:59:59-05:00'),
        ]);
        $this->version($partial, $viewer, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('car', 'partial', 'https://official.example.test/partial', '2026-11-19T12:00:00-05:00', '2026-12-01T00:00:00-05:00', '2026-12-15T23:59:59-05:00'),
        ]);

        $attention = $this->actingAs($viewer)->get(route('admin.restrictions.index', ['availability' => 'attention']));
        $attention->assertOk()
            ->assertSee('Expiredtown')
            ->assertSee('Partialtown')
            ->assertDontSee('Currentville');

        $motorcycles = $this->get(route('admin.restrictions.index', ['vehicle_kind' => 'motorcycle']));
        $motorcycles->assertOk()->assertSee('Expiredtown')->assertDontSee('Currentville')->assertDontSee('Partialtown');

        for ($index = 1; $index <= 52; $index++) {
            $number = str_pad((string) $index, 3, '0', STR_PAD_LEFT);
            $this->jurisdiction($department, '06'.str_pad((string) $index, 3, '0', STR_PAD_LEFT), "unknown-$number", "Unknown municipality $number");
        }

        $unknownPage = $this->get(route('admin.restrictions.index', ['availability' => 'unknown', 'page' => 2]));
        $unknownPage->assertOk()
            ->assertSee('Unknown municipality 052')
            ->assertSee('availability=unknown', false)
            ->assertDontSee('Currentville');

        $this->assertSame(50, $unknownPage->viewData('jurisdictions')->perPage());
        $this->assertSame(2, $unknownPage->viewData('jurisdictions')->currentPage());
        $this->assertSame(52, $unknownPage->viewData('jurisdictions')->total());
    }

    public function test_http_index_respects_editor_and_reviewer_actions_without_publishing(): void
    {
        [$department, $reviewer, $dataset] = $this->baseFixtures();
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $validatedJurisdiction = $this->jurisdiction($department, '05001', 'validatedtown', 'Validatedtown');
        $draftJurisdiction = $this->jurisdiction($department, '05002', 'drafttown', 'Drafttown');
        $validated = $this->version($validatedJurisdiction, $reviewer, RestrictionRuleVersionStatus::Validated, [
            $this->coverage('car', 'complete', 'https://official.example.test/current', '2026-11-19T12:00:00-05:00', '2026-12-01T00:00:00-05:00', '2026-12-15T23:59:59-05:00'),
        ]);
        $draft = $this->version($draftJurisdiction, $reviewer, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('car', 'partial', 'https://official.example.test/draft', '2026-11-19T12:00:00-05:00', '2026-12-01T00:00:00-05:00', '2026-12-15T23:59:59-05:00'),
        ]);

        $revisionBefore = (int) $dataset->fresh()->publication_revision;
        $versionCountBefore = RestrictionRuleVersion::query()->count();
        $publicationCountBefore = RestrictionPublication::query()->count();
        $releaseCountBefore = DatasetRelease::query()->count();

        $reviewerResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.index'));
        $reviewerResponse->assertOk()
            ->assertSee(route('admin.restrictions.publish.preview', ['versions' => [$validated->id]]), false)
            ->assertSee(route('admin.restrictions.validate', $draft), false)
            ->assertDontSee(route('admin.restrictions.edit', $draft), false)
            ->assertDontSee('Ver versión');

        $editorResponse = $this->actingAs($editor)->get(route('admin.restrictions.index'));
        $editorResponse->assertOk()
            ->assertSee(route('admin.restrictions.edit', $draft), false)
            ->assertDontSee(route('admin.restrictions.validate', $draft), false)
            ->assertDontSee(route('admin.restrictions.publish.preview', ['versions' => [$validated->id]]), false);

        $this->actingAs($commercial)->get(route('admin.restrictions.index'))->assertForbidden();

        $this->assertSame($revisionBefore, (int) $dataset->fresh()->publication_revision);
        $this->assertSame($versionCountBefore, RestrictionRuleVersion::query()->count());
        $this->assertSame($publicationCountBefore, RestrictionPublication::query()->count());
        $this->assertSame($releaseCountBefore, DatasetRelease::query()->count());
    }

    /** @return array{GeographicUnit, User, Dataset} */
    private function baseFixtures(): array
    {
        $dataset = Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Restrictions',
            'schema_version' => 1,
            'enabled' => true,
        ]);
        $viewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $country = GeographicUnit::query()->create([
            'key' => 'co',
            'level' => 'country',
            'code' => 'CO',
            'name' => 'Colombia',
            'normalized_name' => 'colombia',
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'c4-fixture',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id,
            'key' => 'co-05',
            'level' => 'department',
            'code' => '05',
            'name' => 'Departamento sintético',
            'normalized_name' => 'departamento sintetico',
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'c4-fixture',
        ]);

        return [$department, $viewer, $dataset];
    }

    private function jurisdiction(GeographicUnit $department, string $code, string $key, string $name): Jurisdiction
    {
        $unit = GeographicUnit::query()->create([
            'parent_id' => $department->id,
            'key' => "co-$code",
            'level' => 'municipality',
            'code' => $code,
            'name' => $name,
            'normalized_name' => strtolower($name),
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'c4-fixture',
        ]);

        return Jurisdiction::query()->create([
            'key' => $key,
            'name' => $name,
            'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id,
            'enabled' => true,
            'timezone' => 'America/Bogota',
        ]);
    }

    /** @param array<int, array<string, mixed>> $coverages */
    private function version(Jurisdiction $jurisdiction, User $actor, RestrictionRuleVersionStatus $status, array $coverages): RestrictionRuleVersion
    {
        $payload = [
            'id' => $jurisdiction->key,
            'name' => $jurisdiction->name,
            'coverages' => $coverages,
        ];

        return RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id,
            'version' => 1,
            'status' => $status,
            'payload' => $payload,
            'payload_sha256' => hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR)),
            'base_publication_revision' => 0,
            'created_by_id' => $actor->id,
            'updated_by_id' => $actor->id,
        ]);
    }

    /** @return array<string, mixed> */
    private function coverage(string $vehicleKind, ?string $completeness, ?string $source, ?string $verifiedAt, ?string $staleAfter, ?string $validUntil): array
    {
        $coverage = [
            'vehicleKind' => $vehicleKind,
            'serviceType' => 'private',
            'rules' => $validUntil === null ? [] : [[
                'id' => "$vehicleKind-rule",
                'priority' => 100,
                'effect' => 'restrict',
                'validFrom' => '2026-11-01T00:00:00-05:00',
                'validUntil' => $validUntil,
                'sourceUrl' => $source,
                'verifiedAt' => $verifiedAt,
            ]],
        ];

        if ($completeness !== null) {
            $coverage['coverageCompleteness'] = $completeness;
        }
        if ($source !== null) {
            $coverage['sourceUrls'] = [$source];
        }
        if ($verifiedAt !== null) {
            $coverage['verifiedAt'] = $verifiedAt;
        }
        if ($staleAfter !== null) {
            $coverage['staleAfter'] = $staleAfter;
        }

        return $coverage;
    }
}
