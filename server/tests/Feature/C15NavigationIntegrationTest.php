<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class C15NavigationIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_dashboard_exposes_national_operations_only_to_roles_with_both_read_gates(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);

        $this->actingAs($admin)
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee(route('admin.operations.national'));

        $this->actingAs($commercial)
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertDontSee(route('admin.operations.national'));
    }

    public function test_campaign_planning_route_is_read_only_navigable_by_commercial_before_resource_binding(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);

        $this->actingAs($commercial)
            ->get(route('admin.campaigns.planning'))
            ->assertOk();

        $this->actingAs($commercial)
            ->get(route('admin.campaigns.index'))
            ->assertOk()
            ->assertSee(route('admin.campaigns.planning'));
    }
}
