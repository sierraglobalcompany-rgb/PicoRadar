<?php

namespace Tests\Unit\Installation;

use App\Installation\HostPreflight;
use PHPUnit\Framework\TestCase;

class HostPreflightTest extends TestCase
{
    public function test_a_compatible_secure_host_with_symlinks_is_ready(): void
    {
        $report = (new HostPreflight)->evaluate([
            'phpVersion' => '8.5.8',
            'extensions' => ['ctype', 'curl', 'dom', 'fileinfo', 'filter', 'hash', 'mbstring', 'openssl', 'pcre', 'pdo', 'pdo_mysql', 'session', 'tokenizer', 'xml'],
            'https' => true,
            'writablePaths' => ['storage' => true, 'bootstrap/cache' => true],
            'symlinkAvailable' => true,
            'permissions' => ['storage' => '0755', 'bootstrap/cache' => '0755'],
        ]);

        $this->assertTrue($report->ready);
        $this->assertSame([], $report->blockers);
    }

    public function test_it_blocks_unsupported_php_http_missing_extensions_and_unsafe_permissions(): void
    {
        $report = (new HostPreflight)->evaluate([
            'phpVersion' => '8.2.20',
            'extensions' => ['pdo'],
            'https' => false,
            'writablePaths' => ['storage' => false, 'bootstrap/cache' => true],
            'symlinkAvailable' => false,
            'permissions' => ['storage' => '0777', 'bootstrap/cache' => '0755'],
        ]);

        $this->assertFalse($report->ready);
        $this->assertContains('php_version', $report->blockers);
        $this->assertContains('https', $report->blockers);
        $this->assertContains('extensions', $report->blockers);
        $this->assertContains('writable_paths', $report->blockers);
        $this->assertContains('symlink', $report->blockers);
        $this->assertContains('unsafe_permissions', $report->blockers);
    }
}
