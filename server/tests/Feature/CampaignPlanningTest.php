<?php

namespace Tests\Feature;

use App\Enums\CampaignScope;
use App\Enums\CampaignStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\OperatorRole;
use App\Enums\SponsorStatus;
use App\Models\Campaign;
use App\Models\GeographicUnit;
use App\Models\Sponsor;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CampaignPlanningTest extends TestCase
{
    use RefreshDatabase;

    private GeographicUnit $department;
    private GeographicUnit $otherDepartment;
    private GeographicUnit $municipality;
    private GeographicUnit $otherMunicipality;
    private Sponsor $activeSponsor;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        config(['campaigns.public_catalog_enabled' => false, 'datasets.features.ads' => false]);
        $this->travelTo(CarbonImmutable::parse('2026-11-22 17:00:00', 'UTC'));

        $country = $this->unit('co', GeographicUnitLevel::Country, '00', 'Colombia');
        $this->department = $this->unit('co-11', GeographicUnitLevel::Department, '11', 'Bogotá D.C.', $country);
        $this->otherDepartment = $this->unit('co-05', GeographicUnitLevel::Department, '05', 'Antioquia', $country);
        $this->municipality = $this->unit('co-11-001', GeographicUnitLevel::Municipality, '11001', 'Bogotá', $this->department);
        $this->otherMunicipality = $this->unit('co-05-001', GeographicUnitLevel::Municipality, '05001', 'Medellín', $this->otherDepartment);
        $this->activeSponsor = $this->sponsor('Patrocinador activo', SponsorStatus::Active);
    }

    public function test_commercial_can_read_planning_with_separate_server_mobile_and_off_states(): void
    {
        $national = $this->campaign('national', $this->activeSponsor, CampaignScope::National, null, 5);
        $this->campaign('scheduled', $this->activeSponsor, CampaignScope::Municipality, $this->municipality, 10, [
            'starts_at' => '2026-11-22 18:00:00',
            'ends_at' => '2026-11-22 20:00:00',
        ]);
        $this->campaign('future-beyond-window', $this->activeSponsor, CampaignScope::Municipality, $this->municipality, 11, [
            'starts_at' => '2026-11-24 12:00:00',
            'ends_at' => '2026-11-25 12:00:00',
        ]);
        $this->campaign('outside-city', $this->activeSponsor, CampaignScope::Municipality, $this->otherMunicipality, 12);
        $inactiveSponsor = $this->sponsor('Patrocinador inactivo', SponsorStatus::Inactive);
        $this->campaign('inactive', $inactiveSponsor, CampaignScope::National, null, 15);
        $this->campaign('draft', $this->activeSponsor, CampaignScope::National, null, 20, ['status' => CampaignStatus::Draft]);
        $this->campaign('ended-at-t', $this->activeSponsor, CampaignScope::National, null, 25, [
            'starts_at' => '2026-11-22 15:00:00',
            'ends_at' => '2026-11-22 17:00:00',
        ]);

        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $response = $this->actingAs($commercial)->get(route('admin.campaigns.planning', $this->filters([
            'municipality_id' => $this->municipality->id,
        ])));

        $response->assertOk()
            ->assertSee('PUBLICIDAD OFF / SOLO SIMULACIÓN')
            ->assertSee('EN_CATÁLOGO_CANDIDATO')
            ->assertSee('ELEGIBLE EN MÓVIL EN TEORÍA')
            ->assertSee('PROGRAMADA · AÚN NO VISIBLE')
            ->assertSee('FUERA DEL TERRITORIO')
            ->assertSee('PATROCINADOR INACTIVO')
            ->assertSee('BORRADOR')
            ->assertSee('VENCIDA')
            ->assertSee('data-simulation-campaign="future-beyond-window" data-server-candidate="true" data-mobile-reason="scheduled"', false)
            ->assertSee('data-simulation-campaign="scheduled" data-server-candidate="true" data-mobile-reason="scheduled"', false)
            ->assertSee('data-simulation-campaign="outside-city" data-server-candidate="true" data-mobile-reason="outside_territory"', false)
            ->assertSee('data-simulation-campaign="ended-at-t" data-server-candidate="false" data-mobile-reason="not_in_server_candidate"', false)
            ->assertSee(route('admin.campaigns.show', $national), false)
            ->assertSee(route('admin.campaigns.edit', $national), false);

        $this->actingAs($commercial)
            ->get(route('admin.campaigns.planning', $this->filters(['department_id' => $this->department->id])))
            ->assertOk()
            ->assertSee('data-simulation-campaign="outside-city" data-server-candidate="true" data-mobile-reason="municipality_required"', false);

        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->get(route('admin.campaigns.planning', $this->filters()))->assertForbidden();
        self::assertFalse((bool) config('campaigns.public_catalog_enabled', false));
        self::assertFalse((bool) config('datasets.features.ads', false));
        $this->get(route('api.v1.campaign-catalog'))->assertNotFound();
        $this->assertDatabaseCount('campaign_catalog_releases', 0);
        $this->assertDatabaseCount('campaigns', 7);
    }

    public function test_non_campaign_viewer_is_denied_and_invalid_range_returns_validation_errors(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $this->actingAs($editor)->get(route('admin.campaigns.planning', $this->filters()))->assertForbidden();

        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $this->actingAs($commercial)->get(route('admin.campaigns.planning', $this->filters([
            'from' => '2026-01-01',
            'until' => '2026-04-02',
            'simulation_at' => '2026-02-01T12:00',
        ])))->assertSessionHasErrors('until');
    }

    public function test_territorial_overlap_uses_half_open_time_windows_and_does_not_claim_capacity(): void
    {
        $national = $this->campaign('national-overlap', $this->activeSponsor, CampaignScope::National, null, 5);
        $department = $this->campaign('department-overlap', $this->activeSponsor, CampaignScope::Department, $this->department, 10);
        $city = $this->campaign('municipality-overlap', $this->activeSponsor, CampaignScope::Municipality, $this->municipality, 15);
        $otherCity = $this->campaign('other-municipality', $this->activeSponsor, CampaignScope::Municipality, $this->otherMunicipality, 20);
        $nonOverlapping = $this->campaign('touching-window', $this->activeSponsor, CampaignScope::National, null, 25, [
            'starts_at' => '2026-11-22 18:00:00',
            'ends_at' => '2026-11-22 19:00:00',
        ]);

        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $response = $this->actingAs($commercial)->get(route('admin.campaigns.planning', $this->filters()));

        $response->assertOk()
            ->assertSee('data-campaign="national-overlap" data-overlap-count="3"', false)
            ->assertSee('data-campaign="department-overlap" data-overlap-count="2"', false)
            ->assertSee('data-campaign="municipality-overlap" data-overlap-count="2"', false)
            ->assertSee('data-campaign="other-municipality" data-overlap-count="1"', false)
            ->assertSee('data-campaign="touching-window" data-overlap-count="0"', false)
            ->assertSee('no indica límite ni agotamiento de espacios');
        $this->assertDatabaseCount('campaigns', 5);
        $this->assertNotSame($national->id, $department->id);
        $this->assertNotSame($city->id, $otherCity->id);
        $this->assertGreaterThan(0, $nonOverlapping->id);
    }

    public function test_server_order_and_effective_delivery_are_truthful_when_both_flags_are_on(): void
    {
        config(['campaigns.public_catalog_enabled' => true, 'datasets.features.ads' => true]);
        $second = $this->campaign('z-last-id', $this->activeSponsor, CampaignScope::National, null, 5);
        $first = $this->campaign('a-first-id', $this->activeSponsor, CampaignScope::National, null, 5);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $html = $this->actingAs($commercial)->get(route('admin.campaigns.planning', $this->filters()))
            ->assertOk()
            ->assertSee('DIFUSIÓN NO CERTIFICADA')
            ->assertSee('no acredita impresiones reales')
            ->getContent();

        $this->assertLessThan(
            strpos($html, 'data-campaign="z-last-id"'),
            strpos($html, 'data-campaign="a-first-id"'),
        );
    }

    /** @return array<string, scalar|null> */
    private function filters(array $overrides = []): array
    {
        return array_replace([
            'from' => '2026-11-22',
            'until' => '2026-11-23',
            'placement' => 'home_c11',
            'simulation_at' => '2026-11-22T12:00',
            'per_page' => '25',
        ], $overrides);
    }

    private function unit(string $key, GeographicUnitLevel $level, string $code, string $name, ?GeographicUnit $parent = null): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'parent_id' => $parent?->id,
            'key' => $key,
            'level' => $level,
            'code' => $code,
            'name' => $name,
            'normalized_name' => mb_strtolower($name),
            'is_active' => true,
            'source_system' => 'synthetic-test',
            'source_version' => 'test-1',
        ]);
    }

    private function sponsor(string $name, SponsorStatus $status): Sponsor
    {
        static $sequence = 0;
        $sequence++;

        return Sponsor::query()->create([
            'public_id' => 'sponsor-test-'.$sequence,
            'name' => $name,
            'status' => $status,
        ]);
    }

    /** @param array<string, mixed> $overrides */
    private function campaign(
        string $publicId,
        Sponsor $sponsor,
        CampaignScope $scope,
        ?GeographicUnit $unit,
        int $priority,
        array $overrides = [],
    ): Campaign {
        return Campaign::query()->create(array_replace([
            'public_id' => $publicId,
            'sponsor_id' => $sponsor->id,
            'status' => CampaignStatus::Active,
            'placement' => 'home_c11',
            'eyebrow' => 'PATROCINADO',
            'title' => 'Campaña sintética '.$publicId,
            'subtitle' => 'Fixture local sin oferta comercial real.',
            'cta_text' => 'Ver información',
            'cta_url' => 'https://example.test/campaign',
            'priority' => $priority,
            'scope' => $scope,
            'geographic_unit_id' => $unit?->id,
            'starts_at' => '2026-11-22 16:00:00',
            'ends_at' => '2026-11-22 18:00:00',
            'source_image_path' => 'synthetic/source.png',
            'public_image_path' => null,
            'image_sha256' => str_repeat('a', 64),
            'image_mime' => 'image/png',
            'image_width' => 1440,
            'image_height' => 360,
            'image_bytes' => 1024,
        ], $overrides));
    }
}
