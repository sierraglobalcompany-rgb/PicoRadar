<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CampaignRouteIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Storage::fake('public');
    }

    public function test_authorized_operator_reaches_real_sponsor_and_campaign_routes(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $this->actingAs($commercial)
            ->get(route('admin.sponsors.index'))
            ->assertOk()
            ->assertSee('Patrocinadores');
        $this->get(route('admin.campaigns.index'))
            ->assertOk()
            ->assertSee('Campañas');
    }

    public function test_editor_cannot_open_campaign_operations(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);

        $this->actingAs($editor)->get(route('admin.campaigns.index'))->assertForbidden();
        $this->get(route('admin.sponsors.index'))->assertForbidden();
    }

    public function test_public_catalog_route_fails_closed_before_first_publication(): void
    {
        $this->get(route('api.v1.campaign-catalog'))
            ->assertNotFound()
            ->assertJson(['message' => 'Campaign catalog is not available.']);
    }
}
