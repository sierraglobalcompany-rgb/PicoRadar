<?php

namespace Tests\Unit\Installation;

use App\Installation\HostingerCronRunner;
use PHPUnit\Framework\TestCase;

class HostingerCronRunnerTest extends TestCase
{
    private string $lockPath;

    protected function setUp(): void
    {
        parent::setUp();
        $this->lockPath = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-cron-'.bin2hex(random_bytes(6)).'.lock';
    }

    protected function tearDown(): void
    {
        @unlink($this->lockPath);
        parent::tearDown();
    }

    public function test_it_runs_a_bounded_task_and_returns_ok(): void
    {
        $calls = 0;
        $result = (new HostingerCronRunner($this->lockPath))->run(function () use (&$calls): void {
            $calls++;
        });

        $this->assertSame('OK', $result);
        $this->assertSame(1, $calls);
    }

    public function test_it_skips_when_another_cron_owns_the_lock(): void
    {
        $handle = fopen($this->lockPath, 'c+');
        $this->assertIsResource($handle);
        $this->assertTrue(flock($handle, LOCK_EX | LOCK_NB));

        $result = (new HostingerCronRunner($this->lockPath))->run(
            fn () => $this->fail('The task must not run while locked.'),
        );

        $this->assertSame('SKIPPED_LOCKED', $result);
        flock($handle, LOCK_UN);
        fclose($handle);
    }

    public function test_it_returns_only_a_sanitized_error_code(): void
    {
        $result = (new HostingerCronRunner($this->lockPath))->run(
            fn () => throw new \RuntimeException('secret database password'),
        );

        $this->assertSame('ERROR_RUNTIME', $result);
        $this->assertStringNotContainsString('secret', $result);
    }
}
