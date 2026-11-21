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
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class C5InactiveJurisdictionDashboardTest extends TestCase
{
    use RefreshDatabase;

    private int $nextCode = 10000;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_index_defaults_to_active_and_keeps_inactive_and_unknown_as_separate_states(): void
    {
        [$department, $reviewer] = $this->baseFixtures();
        $active = $this->jurisdiction($department, 'C5 Active City', true);
        $inactive = $this->jurisdiction($department, 'C5 Inactive City', false);
        $this->version($inactive, $reviewer, RestrictionRuleVersionStatus::Draft);

        $default = $this->actingAs($reviewer)->get(route('admin.restrictions.index'));
        $default->assertOk()
            ->assertSee('C5 Active City')
            ->assertDontSee('C5 Inactive City')
            ->assertSee('name="management"', false)
            ->assertSee('value="active" selected', false);

        $inactiveResponse = $this->get(route('admin.restrictions.index', ['management' => 'inactive']));
        $inactiveResponse->assertOk()
            ->assertSee('C5 Inactive City')
            ->assertSee('Inactiva')
            ->assertSee('UNKNOWN')
            ->assertDontSee('C5 Active City')
            ->assertDontSee('sin pico y placa', false)
            ->assertDontSee('ALLOWED', false);

        $this->assertTrue($active->fresh()->enabled);
        $this->assertFalse($inactive->fresh()->enabled);
    }

    public function test_inactive_and_all_filters_preserve_combined_filters_and_pagination_totals(): void
    {
        [$department, $reviewer] = $this->baseFixtures();

        for ($index = 1; $index <= 52; $index++) {
            $jurisdiction = $this->jurisdiction($department, sprintf('C5 Match Inactive %03d', $index), false);
            $this->version($jurisdiction, $reviewer, RestrictionRuleVersionStatus::Draft);
        }
        for ($index = 1; $index <= 2; $index++) {
            $jurisdiction = $this->jurisdiction($department, sprintf('C5 Match Active %03d', $index), true);
            $this->version($jurisdiction, $reviewer, RestrictionRuleVersionStatus::Draft);
        }

        $filters = [
            'q' => 'C5 Match',
            'department' => '05',
            'vehicle_kind' => 'car',
            'availability' => 'unknown',
        ];
        $inactiveResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.index', $filters + [
            'management' => 'inactive',
            'page' => 2,
        ]));
        $inactiveResponse->assertOk()->assertSee('C5 Match Inactive 052');
        $inactive = $inactiveResponse->viewData('jurisdictions');
        $this->assertSame(50, $inactive->perPage());
        $this->assertSame(2, $inactive->currentPage());
        $this->assertSame(52, $inactive->total());
        $this->assertCount(2, $inactive->items());
        $this->assertSame('UNKNOWN', $inactive->items()[0]['coverages']->first()['availability']);
        $this->assertPaginatorQuery($inactive, $filters + ['management' => 'inactive']);

        $allResponse = $this->get(route('admin.restrictions.index', $filters + [
            'management' => 'all',
            'page' => 2,
        ]));
        $allResponse->assertOk();
        $all = $allResponse->viewData('jurisdictions');
        $this->assertSame(2, $all->currentPage());
        $this->assertSame(54, $all->total());
        $this->assertCount(4, $all->items());
        $this->assertPaginatorQuery($all, $filters + ['management' => 'all']);
    }

    public function test_inactive_rows_are_read_only_for_authorized_roles_and_get_does_not_mutate_state(): void
    {
        [$department, $reviewer, $dataset] = $this->baseFixtures();
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $activeDraftJurisdiction = $this->jurisdiction($department, 'C5 Active Draft', true);
        $activeValidatedJurisdiction = $this->jurisdiction($department, 'C5 Active Validated', true);
        $activeEmptyJurisdiction = $this->jurisdiction($department, 'C5 Active Empty', true);
        $inactiveDraftJurisdiction = $this->jurisdiction($department, 'C5 Inactive Draft', false);
        $inactiveValidatedJurisdiction = $this->jurisdiction($department, 'C5 Inactive Validated', false);
        $inactiveEmptyJurisdiction = $this->jurisdiction($department, 'C5 Inactive Empty', false);

        $activeDraft = $this->version($activeDraftJurisdiction, $reviewer, RestrictionRuleVersionStatus::Draft);
        $activeValidated = $this->version($activeValidatedJurisdiction, $reviewer, RestrictionRuleVersionStatus::Validated);
        $inactiveDraft = $this->version($inactiveDraftJurisdiction, $reviewer, RestrictionRuleVersionStatus::Draft);
        $inactiveValidated = $this->version($inactiveValidatedJurisdiction, $reviewer, RestrictionRuleVersionStatus::Validated);
        $before = $this->restrictionStateSnapshot();

        $reviewerResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.index', ['management' => 'all']));
        $reviewerResponse->assertOk()
            ->assertSee(route('admin.restrictions.validate', $activeDraft), false)
            ->assertSee(route('admin.restrictions.publish.preview', ['versions' => [$activeValidated->id]]), false)
            ->assertDontSee(route('admin.restrictions.validate', $inactiveDraft), false)
            ->assertDontSee(route('admin.restrictions.publish.preview', ['versions' => [$inactiveValidated->id]]), false)
            ->assertSee('C5 Inactive Draft')
            ->assertSee('C5 Inactive Empty')
            ->assertSee('Solo lectura');

        $reviewerInactiveResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.index', ['management' => 'inactive']));
        $reviewerInactiveResponse->assertOk()
            ->assertDontSee(route('admin.restrictions.publish.preview'), false)
            ->assertDontSee(route('admin.restrictions.validate', $inactiveDraft), false);

        $editorResponse = $this->actingAs($editor)->get(route('admin.restrictions.index', ['management' => 'all']));
        $editorResponse->assertOk()
            ->assertSee(route('admin.restrictions.edit', $activeDraft), false)
            ->assertDontSee(route('admin.restrictions.edit', $inactiveDraft), false);

        $this->actingAs($commercial)
            ->get(route('admin.restrictions.index', ['management' => 'inactive']))
            ->assertForbidden();

        $inactiveEditorResponse = $this->actingAs($editor)->get(route('admin.restrictions.index', ['management' => 'inactive']));
        $inactiveEditorResponse->assertDontSee(route('admin.restrictions.create'), false)
            ->assertDontSee(route('admin.restrictions.import'), false);
        $this->assertSame($before, $this->restrictionStateSnapshot());
        $this->assertSame(0, (int) $dataset->fresh()->publication_revision);
        $this->assertTrue($activeEmptyJurisdiction->fresh()->enabled);
        $this->assertFalse($inactiveEmptyJurisdiction->fresh()->enabled);
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
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $country = GeographicUnit::query()->create([
            'key' => 'co',
            'level' => 'country',
            'code' => 'CO',
            'name' => 'Colombia',
            'normalized_name' => 'colombia',
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'c5-fixture',
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
            'source_version' => 'c5-fixture',
        ]);

        return [$department, $reviewer, $dataset];
    }

    private function jurisdiction(GeographicUnit $department, string $name, bool $enabled): Jurisdiction
    {
        $code = (string) $this->nextCode++;
        $unit = GeographicUnit::query()->create([
            'parent_id' => $department->id,
            'key' => "co-$code",
            'level' => 'municipality',
            'code' => $code,
            'name' => $name,
            'normalized_name' => strtolower($name),
            'is_active' => true,
            'source_system' => 'synthetic',
            'source_version' => 'c5-fixture',
        ]);

        return Jurisdiction::query()->create([
            'key' => strtolower(str_replace(' ', '-', $name)),
            'name' => $name,
            'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id,
            'enabled' => $enabled,
            'timezone' => 'America/Bogota',
        ]);
    }

    private function version(
        Jurisdiction $jurisdiction,
        User $actor,
        RestrictionRuleVersionStatus $status,
    ): RestrictionRuleVersion {
        $payload = [
            'id' => $jurisdiction->key,
            'name' => $jurisdiction->name,
            'coverages' => [[
                'vehicleKind' => 'car',
                'serviceType' => 'private',
                'rules' => [],
            ]],
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

    private function assertPaginatorQuery(mixed $paginator, array $expected): void
    {
        $query = [];
        parse_str((string) parse_url($paginator->url(1), PHP_URL_QUERY), $query);

        foreach ($expected as $key => $value) {
            $this->assertSame($value, $query[$key] ?? null, "Paginator must retain the $key filter.");
        }
    }

    /** @return array<string, array<int, array<string, mixed>>> */
    private function restrictionStateSnapshot(): array
    {
        $models = [
            Dataset::class,
            Jurisdiction::class,
            RestrictionRuleVersion::class,
            RestrictionPublication::class,
            DatasetRelease::class,
        ];
        $snapshot = [];

        foreach ($models as $modelClass) {
            $model = new $modelClass;
            $snapshot[$model->getTable()] = DB::table($model->getTable())
                ->orderBy($model->getKeyName())
                ->get()
                ->map(fn (object $row): array => (array) $row)
                ->all();
        }

        return $snapshot;
    }
}
