<?php

namespace Tests\Unit\Installation;

use App\Installation\HostPreflightCollector;
use PHPUnit\Framework\TestCase;

class HostPreflightCollectorTest extends TestCase
{
    private string $root;

    protected function setUp(): void
    {
        parent::setUp();
        $this->root = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-preflight-'.bin2hex(random_bytes(6));
        mkdir($this->root.DIRECTORY_SEPARATOR.'private'.DIRECTORY_SEPARATOR.'storage', 0700, true);
        mkdir($this->root.DIRECTORY_SEPARATOR.'private'.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'cache', 0700, true);
        mkdir($this->root.DIRECTORY_SEPARATOR.'public', 0700, true);
    }

    protected function tearDown(): void
    {
        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($this->root, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::CHILD_FIRST,
        );
        foreach ($iterator as $entry) {
            $entry->isDir() ? rmdir($entry->getPathname()) : unlink($entry->getPathname());
        }
        rmdir($this->root);
        parent::tearDown();
    }

    public function test_untrusted_forwarded_proto_cannot_claim_https(): void
    {
        $report = (new HostPreflightCollector(
            $this->root.DIRECTORY_SEPARATOR.'private',
            $this->root.DIRECTORY_SEPARATOR.'public',
        ))->collect([
            'REMOTE_ADDR' => '203.0.113.9',
            'HTTPS' => 'off',
            'SERVER_PORT' => 80,
            'HTTP_X_FORWARDED_PROTO' => 'https',
        ]);

        $this->assertContains('https', $report->blockers);
    }

    public function test_windows_clean_room_uses_directory_junction_capability_without_posix_permission_false_positives(): void
    {
        if (DIRECTORY_SEPARATOR !== '\\') {
            $this->markTestSkipped('Windows-specific clean-room capability test.');
        }

        $report = (new HostPreflightCollector(
            $this->root.DIRECTORY_SEPARATOR.'private',
            $this->root.DIRECTORY_SEPARATOR.'public',
        ))->collect([
            'REMOTE_ADDR' => '127.0.0.1',
            'HTTPS' => 'on',
            'SERVER_PORT' => 443,
        ]);

        $this->assertNotContains('symlink', $report->blockers);
        $this->assertNotContains('unsafe_permissions', $report->blockers);
    }
}
