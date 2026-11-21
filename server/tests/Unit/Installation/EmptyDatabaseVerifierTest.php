<?php

namespace Tests\Unit\Installation;

use App\Installation\EmptyDatabaseVerifier;
use Mockery;
use Mockery\Adapter\Phpunit\MockeryPHPUnitIntegration;
use PDO;
use PDOStatement;
use PHPUnit\Framework\TestCase;

class EmptyDatabaseVerifierTest extends TestCase
{
    use MockeryPHPUnitIntegration;

    public function test_it_accepts_an_empty_database(): void
    {
        $statement = Mockery::mock(PDOStatement::class);
        $statement->shouldReceive('fetchColumn')->once()->andReturn(false);
        $pdo = Mockery::mock(PDO::class);
        $pdo->shouldReceive('query')
            ->once()
            ->with(Mockery::pattern('/information_schema\.tables/i'))
            ->andReturn($statement);

        $this->assertTrue((new EmptyDatabaseVerifier)->isEmpty($pdo));
    }

    public function test_it_rejects_a_database_that_already_contains_a_table(): void
    {
        $statement = Mockery::mock(PDOStatement::class);
        $statement->shouldReceive('fetchColumn')->once()->andReturn('users');
        $pdo = Mockery::mock(PDO::class);
        $pdo->shouldReceive('query')->once()->andReturn($statement);

        $this->assertFalse((new EmptyDatabaseVerifier)->isEmpty($pdo));
    }
}
