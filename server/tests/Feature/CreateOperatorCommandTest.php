<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreateOperatorCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_cli_command_uses_the_shared_initial_operator_rules(): void
    {
        $this->artisan('picoradar:admin:create', [
            '--name' => 'Owner',
            '--email' => 'OWNER@EXAMPLE.TEST',
        ])
            ->expectsQuestion('Password (at least 12 characters)', 'a-secure-password')
            ->expectsQuestion('Confirm password', 'a-secure-password')
            ->expectsOutputToContain('Super administrator created.')
            ->assertSuccessful();

        $operator = User::query()->sole();
        $this->assertSame('owner@example.test', $operator->email);
        $this->assertSame(OperatorRole::SuperAdmin, $operator->role);
        $this->assertTrue($operator->isActive());
    }

    public function test_the_cli_command_refuses_a_second_operator(): void
    {
        User::factory()->create();

        $this->artisan('picoradar:admin:create', [
            '--name' => 'Owner',
            '--email' => 'owner@example.test',
        ])
            ->expectsQuestion('Password (at least 12 characters)', 'a-secure-password')
            ->expectsQuestion('Confirm password', 'a-secure-password')
            ->assertFailed();

        $this->assertDatabaseCount('users', 1);
    }
}
