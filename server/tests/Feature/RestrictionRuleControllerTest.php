<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Http\Controllers\Admin\RestrictionRuleController;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\RestrictionRuleVersionService;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Tests\TestCase;

class RestrictionRuleControllerTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_rule_index_reuses_dataset_view_permission(): void
    {
        Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $viewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $this->actingAs($viewer);
        $view = app(RestrictionRuleController::class)->index($this->request($viewer));
        $this->assertSame('admin.restrictions.index', $view->name());
        $this->assertSame(0, $view->getData()['jurisdictions']->count());

        $this->actingAs($commercial);
        $this->expectException(AuthorizationException::class);
        app(RestrictionRuleController::class)->index($this->request($commercial));
    }

    public function test_csv_template_reuses_dataset_edit_permission_and_has_real_contract_headers(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);

        $this->actingAs($editor);
        $response = app(RestrictionRuleController::class)->template();
        $this->assertSame('text/csv; charset=UTF-8', $response->headers->get('content-type'));
        $this->assertStringContainsString('jurisdiction_id', $response->getContent());
        $this->assertStringContainsString('time_windows', $response->getContent());
        $this->assertStringContainsString('stale_after', $response->getContent());

        $this->actingAs($reviewer);
        $this->expectException(AuthorizationException::class);
        app(RestrictionRuleController::class)->template();
    }

    public function test_rule_index_filters_by_department_city_and_vehicle_without_hiding_other_versions(): void
    {
        Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $viewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $country = GeographicUnit::query()->create(['key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $antioquia = GeographicUnit::query()->create(['parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05', 'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $cundinamarca = GeographicUnit::query()->create(['parent_id' => $country->id, 'key' => 'co-25', 'level' => 'department', 'code' => '25', 'name' => 'Cundinamarca', 'normalized_name' => 'cundinamarca', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $medellin = $this->jurisdiction($antioquia, '05001', 'medellin-test', 'Medellín prueba');
        $soacha = $this->jurisdiction($cundinamarca, '25754', 'soacha-test', 'Soacha prueba');
        $versions = app(RestrictionRuleVersionService::class);
        $versions->createDraft($medellin, $this->payload($medellin, 'motorcycle'), $viewer);
        $versions->createDraft($soacha, $this->payload($soacha, 'car'), $viewer);

        $response = $this->actingAs($viewer)->get(route('admin.restrictions.index', [
            'q' => 'medellin',
            'department' => '05',
            'vehicle_kind' => 'motorcycle',
        ]));

        $response->assertOk()->assertSee('Medellín prueba')->assertDontSee('Soacha prueba');
        $response->assertSee('Buscar ciudad')->assertSee('Departamento')->assertSee('Tipo de vehículo');
    }

    private function request(User $user): Request
    {
        $request = Request::create('/_b07/restrictions');
        $request->setUserResolver(fn (): User => $user);

        return $request;
    }

    private function jurisdiction(GeographicUnit $department, string $code, string $key, string $name): Jurisdiction
    {
        $unit = GeographicUnit::query()->create(['parent_id' => $department->id, 'key' => "co-$code", 'level' => 'municipality', 'code' => $code, 'name' => $name, 'normalized_name' => strtolower($name), 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);

        return Jurisdiction::query()->create(['key' => $key, 'name' => $name, 'kind' => 'city', 'primary_geographic_unit_id' => $unit->id, 'enabled' => true, 'timezone' => 'America/Bogota']);
    }

    /** @return array<string,mixed> */
    private function payload(Jurisdiction $jurisdiction, string $vehicleKind): array
    {
        return ['id' => $jurisdiction->key, 'name' => $jurisdiction->name, 'coverages' => [[
            'vehicleKind' => $vehicleKind, 'serviceType' => 'private', 'verifiedAt' => '2026-09-20T08:00:00-05:00', 'staleAfter' => '2026-10-20T08:00:00-05:00', 'sourceUrls' => ['https://example.test/source'],
            'rules' => [['id' => $jurisdiction->key.'-rule', 'priority' => 100, 'effect' => 'restrict', 'validFrom' => '2026-09-20T00:00:00-05:00', 'weekdays' => [1], 'digitPosition' => 'lastNumeric', 'digits' => [1], 'timeWindows' => [['startMinute' => 360, 'endMinute' => 1200]], 'appliesOnHolidays' => false, 'sourceUrl' => 'https://example.test/source', 'verifiedAt' => '2026-09-20T08:00:00-05:00']],
        ]]];
    }
}
