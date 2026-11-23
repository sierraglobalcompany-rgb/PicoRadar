<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class C26MobileNavigationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_super_admin_sees_accessible_mobile_navigation_and_all_permitted_links(): void
    {
        $superAdmin = User::factory()->create([
            'role' => OperatorRole::SuperAdmin,
            'is_active' => true,
        ]);

        [$menu, $page] = $this->mobileMenuFor($superAdmin);

        $this->assertStringContainsString('<summary', $menu);
        $this->assertStringContainsString('>Menú</summary>', $menu);
        $this->assertStringContainsString('md:hidden', $menu);
        $this->assertStringContainsString('min-h-11', $menu);
        $this->assertStringContainsString('focus-visible:outline', $menu);
        $this->assertStringContainsString('action="'.route('logout').'"', $page);
        $this->assertStringContainsString('name="_token"', $page);

        $this->assertMobileLinks($menu, [
            'admin.dashboard',
            'admin.operations.national',
            'admin.restrictions.municipalities',
            'admin.restrictions.index',
            'admin.campaigns.planning',
            'admin.app-users.index',
            'admin.operators.index',
            'admin.profile.edit',
        ]);
    }

    public function test_editor_sees_dataset_navigation_but_not_super_admin_or_campaign_links(): void
    {
        $editor = User::factory()->create([
            'role' => OperatorRole::Editor,
            'is_active' => true,
        ]);

        [$menu] = $this->mobileMenuFor($editor);

        $this->assertMobileLinks($menu, [
            'admin.dashboard',
            'admin.operations.national',
            'admin.restrictions.municipalities',
            'admin.restrictions.index',
            'admin.profile.edit',
        ]);
        $this->assertMobileLinksAbsent($menu, [
            'admin.campaigns.planning',
            'admin.app-users.index',
            'admin.operators.index',
        ]);
    }

    public function test_commercial_sees_campaign_planning_without_national_or_client_links(): void
    {
        $commercial = User::factory()->create([
            'role' => OperatorRole::Commercial,
            'is_active' => true,
        ]);

        [$menu] = $this->mobileMenuFor($commercial);

        $this->assertMobileLinks($menu, [
            'admin.dashboard',
            'admin.campaigns.planning',
            'admin.profile.edit',
        ]);
        $this->assertMobileLinksAbsent($menu, [
            'admin.operations.national',
            'admin.restrictions.municipalities',
            'admin.restrictions.index',
            'admin.app-users.index',
            'admin.operators.index',
        ]);
    }

    /** @return array{string, string} */
    private function mobileMenuFor(User $operator): array
    {
        $response = $this->actingAs($operator)
            ->get(route('admin.dashboard'))
            ->assertOk();

        $content = $response->getContent();
        $matched = preg_match('~<details id="mobile-navigation"[^>]*>(.*?)</details>~s', $content, $matches);

        $this->assertSame(1, $matched, 'The mobile navigation details element should be rendered.');

        return [$matches[1], $content];
    }

    /** @param list<string> $routeNames */
    private function assertMobileLinks(string $menu, array $routeNames): void
    {
        foreach ($routeNames as $routeName) {
            $this->assertStringContainsString('href="'.route($routeName).'"', $menu, $routeName);
        }
    }

    /** @param list<string> $routeNames */
    private function assertMobileLinksAbsent(string $menu, array $routeNames): void
    {
        foreach ($routeNames as $routeName) {
            $this->assertStringNotContainsString('href="'.route($routeName).'"', $menu, $routeName);
        }
    }
}
