<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class OperatorMigrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_clean_sqlite_migrations_create_the_operator_columns(): void
    {
        $this->assertTrue(Schema::hasColumns('users', ['role', 'is_active']));
    }

    public function test_a_legacy_user_defaults_to_inactive_and_cannot_sign_in(): void
    {
        DB::table('users')->insert([
            'name' => 'Legacy User',
            'email' => 'legacy-user@example.test',
            'password' => Hash::make('a-long-test-password'),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $legacyUser = User::query()->sole();

        $this->assertSame(OperatorRole::Reviewer, $legacyUser->role);
        $this->assertFalse($legacyUser->is_active);

        $this->from('/login')->post('/login', [
            'email' => $legacyUser->email,
            'password' => 'a-long-test-password',
        ])->assertRedirect('/login')->assertSessionHasErrors('email');

        $this->assertGuest();
    }
}
