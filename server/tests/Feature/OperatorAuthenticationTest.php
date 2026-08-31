<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class OperatorAuthenticationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->withoutVite();
    }

    public function test_an_active_operator_can_sign_in_and_access_the_dashboard(): void
    {
        $operator = $this->operator();

        $this->post('/login', [
            'email' => $operator->email,
            'password' => 'a-long-test-password',
        ])->assertRedirect(route('admin.dashboard'));

        $this->assertAuthenticatedAs($operator);

        $this->get('/admin')
            ->assertOk()
            ->assertSee('PicoRadar Control Plane')
            ->assertSee('Administrator')
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('X-Content-Type-Options', 'nosniff');
    }

    public function test_invalid_login_is_rejected_without_authenticating_a_user(): void
    {
        $operator = $this->operator();

        $this->from('/login')->post('/login', [
            'email' => $operator->email,
            'password' => 'wrong-password',
        ])->assertRedirect('/login')->assertSessionHasErrors('email');

        $this->assertGuest();
    }

    public function test_login_page_has_security_headers(): void
    {
        $this->get('/login')
            ->assertOk()
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin')
            ->assertHeader('Permissions-Policy', 'camera=(), geolocation=(), microphone=()');
    }

    public function test_an_inactive_operator_cannot_sign_in_or_keep_a_dashboard_session(): void
    {
        $operator = $this->operator(active: false);

        $this->from('/login')->post('/login', [
            'email' => $operator->email,
            'password' => 'a-long-test-password',
        ])->assertRedirect('/login')->assertSessionHasErrors('email');

        $this->assertGuest();

        $this->actingAs($operator)->get('/admin')
            ->assertRedirect('/login')
            ->assertSessionHasErrors('email');
    }

    public function test_dashboard_requires_an_authenticated_operator(): void
    {
        $this->get('/admin')->assertRedirect(route('login'));
    }

    public function test_logout_invalidates_the_operator_session(): void
    {
        $operator = $this->operator();

        $this->actingAs($operator)->post('/logout')->assertRedirect(route('login'));

        $this->assertGuest();
    }

    public function test_public_operator_registration_does_not_exist(): void
    {
        $this->get('/register')->assertNotFound();
        $this->post('/register')->assertNotFound();
    }

    public function test_operator_roles_are_limited_to_the_application_enum(): void
    {
        $operator = $this->operator(role: OperatorRole::Commercial);

        $this->assertSame(OperatorRole::Commercial, $operator->role);
        $this->assertTrue($operator->isActive());
        $this->assertSame('Commercial', $operator->role->label());
    }

    private function operator(
        bool $active = true,
        OperatorRole $role = OperatorRole::Admin,
    ): User {
        return User::factory()->create([
            'password' => Hash::make('a-long-test-password'),
            'role' => $role,
            'is_active' => $active,
        ]);
    }
}
