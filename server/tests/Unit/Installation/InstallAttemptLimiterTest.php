<?php

namespace Tests\Unit\Installation;

use App\Installation\InstallAttemptLimiter;
use DateTimeImmutable;
use PHPUnit\Framework\TestCase;

class InstallAttemptLimiterTest extends TestCase
{
    private string $path;

    protected function setUp(): void
    {
        parent::setUp();
        $this->path = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-attempts-'.bin2hex(random_bytes(6)).'.json';
    }

    protected function tearDown(): void
    {
        @unlink($this->path);
        @unlink($this->path.'.bak');
        @unlink($this->path.'.lock');
        parent::tearDown();
    }

    public function test_it_blocks_after_five_failures_and_recovers_after_the_window(): void
    {
        $limiter = new InstallAttemptLimiter($this->path, 5, 900);
        $start = new DateTimeImmutable('2026-09-19T12:00:00Z');

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->assertTrue($limiter->allows('hashed-client', $start));
            $limiter->recordFailure('hashed-client', $start);
        }

        $this->assertFalse($limiter->allows('hashed-client', $start));
        $this->assertTrue($limiter->allows('hashed-client', $start->modify('+16 minutes')));
    }

    public function test_a_success_clears_only_that_clients_failures(): void
    {
        $limiter = new InstallAttemptLimiter($this->path, 1, 900);
        $now = new DateTimeImmutable('2026-09-19T12:00:00Z');
        $limiter->recordFailure('first', $now);
        $limiter->recordFailure('second', $now);

        $limiter->clear('first');

        $this->assertTrue($limiter->allows('first', $now));
        $this->assertFalse($limiter->allows('second', $now));
    }
}
