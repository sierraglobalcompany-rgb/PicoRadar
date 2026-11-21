<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AdminOperatorManagementTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_only_super_admin_can_manage_operators(): void
    {
        $superAdmin = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);

        $this->actingAs($admin)->get('/admin/operators')->assertForbidden();
        $this->actingAs($superAdmin)->get('/admin/operators')->assertOk();

        $this->actingAs($superAdmin)->post('/admin/operators', [
            'name' => 'Editor de contenido',
            'email' => 'editor@example.test',
            'role' => OperatorRole::Editor->value,
            'password' => 'Long-Test-Password-2026',
            'password_confirmation' => 'Long-Test-Password-2026',
        ])->assertRedirect('/admin/operators');

        $this->assertDatabaseHas('users', [
            'email' => 'editor@example.test',
            'role' => OperatorRole::Editor->value,
            'is_active' => true,
        ]);
        $this->assertDatabaseHas('audit_logs', ['action' => 'operator.created']);
    }

    public function test_super_admin_cannot_deactivate_self_or_last_active_super_admin(): void
    {
        $superAdmin = User::factory()->create([
            'role' => OperatorRole::SuperAdmin,
            'is_active' => true,
        ]);

        $this->actingAs($superAdmin)
            ->put("/admin/operators/{$superAdmin->id}", [
                'role' => OperatorRole::SuperAdmin->value,
                'is_active' => false,
            ])
            ->assertSessionHasErrors('operator');

        $this->assertTrue($superAdmin->fresh()->isActive());
    }

    public function test_operator_changes_own_password_with_current_password(): void
    {
        $operator = User::factory()->create([
            'role' => OperatorRole::Reviewer,
            'password' => Hash::make('Current-Password-2026'),
        ]);

        $this->actingAs($operator)->put('/admin/profile/password', [
            'current_password' => 'wrong-password',
            'password' => 'New-Password-For-Panel-2026',
            'password_confirmation' => 'New-Password-For-Panel-2026',
        ])->assertSessionHasErrors('current_password');

        $this->actingAs($operator)->put('/admin/profile/password', [
            'current_password' => 'Current-Password-2026',
            'password' => 'New-Password-For-Panel-2026',
            'password_confirmation' => 'New-Password-For-Panel-2026',
        ])->assertRedirect('/admin/profile');

        $this->assertTrue(Hash::check('New-Password-For-Panel-2026', $operator->fresh()->password));
        $this->assertDatabaseHas('audit_logs', ['action' => 'operator.password_changed']);
    }
}
