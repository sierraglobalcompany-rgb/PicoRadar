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
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class RestrictionMunicipalityMatrixTest extends TestCase
{
    use RefreshDatabase;

    private GeographicUnit $department;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Http::preventStrayRequests();
        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia',
            'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'c7-test',
        ]);
        $this->department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05',
            'name' => 'Departamento sintético', 'normalized_name' => 'departamento sintetico', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'c7-test',
        ]);
    }

    public function test_unassigned_municipalities_are_searchable_filtered_and_paginated_by_fifty(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        for ($index = 1; $index <= 55; $index++) {
            $code = sprintf('05%03d', $index);
            $this->municipality($code, sprintf('c7-city-%03d', $index), sprintf('C7 Municipality %03d', $index));
        }

        $filters = [
            'q' => 'C7 Municipality',
            'department' => '05',
            'management' => 'unassigned',
            'availability' => 'unknown',
        ];
        $first = $this->actingAs($reviewer)
            ->get(route('admin.restrictions.municipalities', $filters))
            ->assertOk()
            ->assertSee('Matriz municipal')
            ->assertSee('NO_JURISDICTION')
            ->assertSee('UNKNOWN');
        $pageOne = $first->viewData('municipalities');
        self::assertSame(55, $pageOne->total());
        self::assertCount(50, $pageOne->items());
        self::assertSame('05001', $pageOne->items()[0]['municipality']->code);
        self::assertSame('05050', $pageOne->items()[49]['municipality']->code);

        $pageTwo = $this->actingAs($reviewer)
            ->get(route('admin.restrictions.municipalities', [...$filters, 'page' => 2]))
            ->assertOk()
            ->viewData('municipalities');
        self::assertSame(55, $pageTwo->total());
        self::assertCount(5, $pageTwo->items());
        self::assertSame('05051', $pageTwo->items()[0]['municipality']->code);
        self::assertSame('UNKNOWN', $pageTwo->items()[0]['entries'][0]['coverages'][0]['availability']);
    }

    public function test_matrix_keeps_multiple_jurisdictions_categories_and_real_release_separate_from_draft(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $municipality = $this->municipality('05901', 'mixed-city', 'Municipio sintético mixto');
        $inactive = $this->jurisdiction($municipality, 'inactive-city', 'Jurisdicción inactiva', false);
        $draft = $this->version($inactive, 9, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('car', 'private'),
        ]);
        $active = $this->jurisdiction($municipality, 'active-city', 'Jurisdicción activa', true);
        $published = $this->version($active, 4, RestrictionRuleVersionStatus::Validated, [
            $this->coverage('car', 'private'),
            $this->coverage('motorcycle', 'public_cargo'),
        ]);
        $this->publishVersion($published, $active, $reviewer, 'c7-release-1');

        $response = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities', [
            'q' => 'mixto', 'department' => '05', 'management' => 'all', 'availability' => 'all',
        ]))->assertOk();
        $page = $response->viewData('municipalities');
        self::assertSame(1, $page->total());
        self::assertCount(2, $page->items()[0]['entries']);
        $entries = $page->items()[0]['entries'];
        $inactiveEntry = collect($entries)->first(fn (array $entry): bool => $entry['jurisdiction']->key === 'inactive-city');
        $publishedEntries = collect($entries)->filter(fn (array $entry): bool => $entry['jurisdiction']->key === 'active-city');

        self::assertSame('INACTIVE', $inactiveEntry['management_state']);
        self::assertSame(9, $inactiveEntry['version']->version);
        self::assertNull($inactiveEntry['published_release']);
        self::assertCount(1, $publishedEntries);
        self::assertCount(2, $publishedEntries[0]['coverages']);
        self::assertSame(['car', 'motorcycle'], array_column($publishedEntries[0]['coverages'], 'vehicle_kind'));
        self::assertSame('c7-release-1', $publishedEntries[0]['published_release']->version);
        $response->assertSee('c7-release-1')->assertSee('Sin release publicado');
        $response->assertDontSee('ALLOWED');

        $inactivePage = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities', [
            'q' => 'mixto', 'management' => 'inactive', 'availability' => 'verified',
        ]))->assertOk()->viewData('municipalities');
        self::assertSame(1, $inactivePage->total());
        self::assertCount(1, $inactivePage->items()[0]['entries']);
        self::assertSame('inactive-city', $inactivePage->items()[0]['entries'][0]['jurisdiction']->key);
    }

    public function test_page_requires_view_permission_and_only_shows_existing_actions_by_role(): void
    {
        $municipality = $this->municipality('05902', 'roles-city', 'Municipio de permisos');
        $draftJurisdiction = $this->jurisdiction($municipality, 'roles-draft', 'Jurisdicción borrador');
        $draft = $this->version($draftJurisdiction, 2, RestrictionRuleVersionStatus::Draft, [$this->coverage('car', 'private')]);
        $validatedJurisdiction = $this->jurisdiction($municipality, 'roles-review', 'Jurisdicción revisión');
        $validated = $this->version($validatedJurisdiction, 3, RestrictionRuleVersionStatus::Validated, [$this->coverage('car', 'private')]);

        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $editorResponse = $this->actingAs($editor)->get(route('admin.restrictions.municipalities'))->assertOk();
        $editorResponse->assertSee(route('admin.restrictions.edit', $draft));
        $editorResponse->assertSee(route('admin.restrictions.edit', $validated));
        $editorResponse->assertSee('Editar borrador')->assertSee('Ver versión');
        $editorResponse->assertDontSee(route('admin.restrictions.publish.preview', ['versions' => [$validated->id]]));

        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $reviewerResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.municipalities'))->assertOk();
        $reviewerResponse->assertSee(route('admin.restrictions.publish.preview', ['versions' => [$validated->id]]));
        $reviewerResponse->assertSee(route('admin.restrictions.edit', $draft));
        $reviewerResponse->assertDontSee('Editar borrador');

        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $this->actingAs($commercial)->get(route('admin.restrictions.municipalities'))->assertForbidden();
    }

    private function municipality(string $code, string $key, string $name): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'parent_id' => $this->department->id, 'key' => 'co-'.$code, 'level' => 'municipality',
            'code' => $code, 'name' => $name, 'normalized_name' => strtolower($name), 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'c7-test',
        ]);
    }

    private function jurisdiction(GeographicUnit $municipality, string $key, string $name, bool $enabled = true): Jurisdiction
    {
        $jurisdiction = Jurisdiction::query()->create([
            'key' => $key, 'name' => $name, 'kind' => 'city', 'primary_geographic_unit_id' => $municipality->id,
            'enabled' => $enabled, 'timezone' => 'America/Bogota',
        ]);
        $municipality->jurisdictions()->attach($jurisdiction->id);

        return $jurisdiction;
    }

    private function version(Jurisdiction $jurisdiction, int $number, RestrictionRuleVersionStatus $status, array $coverages): RestrictionRuleVersion
    {
        $payload = ['id' => $jurisdiction->key, 'name' => $jurisdiction->name, 'coverages' => $coverages];

        return RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id, 'version' => $number, 'status' => $status,
            'payload' => $payload, 'payload_sha256' => hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR)),
            'base_publication_revision' => 0,
        ]);
    }

    private function coverage(string $vehicleKind, string $serviceType): array
    {
        return [
            'vehicleKind' => $vehicleKind, 'serviceType' => $serviceType, 'coverageCompleteness' => 'complete',
            'sourceUrls' => ['https://example.test/c7-source'], 'verifiedAt' => '2026-11-19T00:00:00Z',
            'staleAfter' => '2099-01-01T00:00:00Z', 'rules' => [],
        ];
    }

    private function publishVersion(RestrictionRuleVersion $version, Jurisdiction $jurisdiction, User $actor, string $releaseVersion): void
    {
        Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 2, 'enabled' => true,
            'current_version' => $releaseVersion, 'publication_revision' => 1,
        ]);
        $release = DatasetRelease::query()->create([
            'dataset_id' => Dataset::query()->where('key', 'restrictions')->value('id'),
            'version' => $releaseVersion, 'status' => DatasetReleaseStatus::Draft,
            'sha256' => hash('sha256', 'synthetic-'.$releaseVersion),
        ]);
        DB::table('dataset_releases')->where('id', $release->id)->update([
            'status' => DatasetReleaseStatus::Published->value,
            'asset_path' => 'datasets/restrictions/'.$releaseVersion.'/restrictions.json',
            'published_at' => now(),
        ]);
        $publication = RestrictionPublication::query()->create([
            'dataset_release_id' => $release->id, 'action' => 'publish',
            'base_publication_revision' => 0, 'result_publication_revision' => 1,
            'actor_id' => $actor->id, 'summary' => ['jurisdictionCount' => 1],
        ]);
        RestrictionPublicationItem::query()->create([
            'restriction_publication_id' => $publication->id, 'jurisdiction_id' => $jurisdiction->id,
            'restriction_rule_version_id' => $version->id, 'action' => 'publish',
        ]);
    }
}
