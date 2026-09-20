<?php

namespace Tests\Unit\Installation;

use App\Installation\PackageManifestVerifier;
use PHPUnit\Framework\TestCase;

class PackageManifestVerifierTest extends TestCase
{
    private string $directory;

    protected function setUp(): void
    {
        parent::setUp();

        $this->directory = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-manifest-'.bin2hex(random_bytes(6));
        mkdir($this->directory, 0700, true);
        file_put_contents($this->directory.DIRECTORY_SEPARATOR.'index.php', 'safe package');
    }

    protected function tearDown(): void
    {
        foreach (glob($this->directory.DIRECTORY_SEPARATOR.'*') ?: [] as $file) {
            unlink($file);
        }
        rmdir($this->directory);

        parent::tearDown();
    }

    public function test_it_accepts_a_complete_untampered_package(): void
    {
        $manifest = [
            'releaseId' => 'release-test',
            'files' => [[
                'path' => 'index.php',
                'size' => filesize($this->directory.DIRECTORY_SEPARATOR.'index.php'),
                'sha256' => hash_file('sha256', $this->directory.DIRECTORY_SEPARATOR.'index.php'),
            ]],
        ];

        $report = (new PackageManifestVerifier)->verify($this->directory, $manifest);

        $this->assertTrue($report->valid);
        $this->assertSame([], $report->errors);
    }

    public function test_it_rejects_missing_tampered_and_traversal_files(): void
    {
        $manifest = [
            'releaseId' => 'release-test',
            'files' => [
                ['path' => 'index.php', 'size' => 12, 'sha256' => str_repeat('0', 64)],
                ['path' => 'missing.php', 'size' => 1, 'sha256' => str_repeat('1', 64)],
                ['path' => '../outside.php', 'size' => 1, 'sha256' => str_repeat('2', 64)],
            ],
        ];

        $report = (new PackageManifestVerifier)->verify($this->directory, $manifest);

        $this->assertFalse($report->valid);
        $this->assertContains('hash:index.php', $report->errors);
        $this->assertContains('missing:missing.php', $report->errors);
        $this->assertContains('unsafe_path:../outside.php', $report->errors);
    }
}
