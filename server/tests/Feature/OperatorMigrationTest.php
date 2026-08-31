<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class OperatorMigrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_clean_sqlite_migrations_create_the_operator_columns(): void
    {
        $this->assertTrue(Schema::hasColumns('users', ['role', 'is_active']));
    }
}
