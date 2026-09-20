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
            'schemaVersion' => 1,
            'releaseId' => 'release-test',
            'files' => [[
                'path' => 'index.php',
                'size' => filesize($this->directory.DIRECTORY_SEPARATOR.'index.php'),
                'sha256' => hash_file('sha256', $this->directory.DIRECTORY_SEPARATOR.'index.php'),
            ]],
        ];

        $report = (new PackageManifestVerifier)->verify($this->directory, $manifest, 'release-test');

        $this->assertTrue($report->valid);
        $this->assertSame([], $report->errors);
    }

    public function test_it_rejects_missing_tampered_and_traversal_files(): void
    {
        $manifest = [
            'schemaVersion' => 1,
            'releaseId' => 'release-test',
            'files' => [
                ['path' => 'index.php', 'size' => 12, 'sha256' => str_repeat('0', 64)],
                ['path' => 'missing.php', 'size' => 1, 'sha256' => str_repeat('1', 64)],
                ['path' => '../outside.php', 'size' => 1, 'sha256' => str_repeat('2', 64)],
            ],
        ];

        $report = (new PackageManifestVerifier)->verify($this->directory, $manifest, 'release-test');

        $this->assertFalse($report->valid);
        $this->assertContains('hash:index.php', $report->errors);
        $this->assertContains('missing:missing.php', $report->errors);
        $this->assertContains('unsafe_path:../outside.php', $report->errors);
    }

    public function test_it_rejects_missing_or_empty_manifest_contracts(): void
    {
        $verifier = new PackageManifestVerifier;

        foreach ([[], ['files' => []], ['schemaVersion' => 1, 'releaseId' => 'release-test', 'files' => []]] as $manifest) {
            $report = $verifier->verify($this->directory, $manifest, 'release-test');

            $this->assertFalse($report->valid);
            $this->assertNotSame([], $report->errors);
        }
    }

    public function test_it_rejects_release_mismatch_duplicates_and_symlink_entries(): void
    {
        $link = $this->directory.DIRECTORY_SEPARATOR.'linked.php';
        if (! @symlink($this->directory.DIRECTORY_SEPARATOR.'index.php', $link)) {
            $this->markTestSkipped('This runtime cannot create a test symlink.');
        }

        $entry = [
            'path' => 'index.php',
            'size' => filesize($this->directory.DIRECTORY_SEPARATOR.'index.php'),
            'sha256' => hash_file('sha256', $this->directory.DIRECTORY_SEPARATOR.'index.php'),
        ];
        $manifest = [
            'schemaVersion' => 1,
            'releaseId' => 'wrong-release',
            'files' => [
                $entry,
                $entry,
                [
                    'path' => 'linked.php',
                    'size' => filesize($link),
                    'sha256' => hash_file('sha256', $link),
                ],
            ],
        ];

        $report = (new PackageManifestVerifier)->verify($this->directory, $manifest, 'release-test');

        $this->assertFalse($report->valid);
        $this->assertContains('release_id', $report->errors);
        $this->assertContains('duplicate:index.php', $report->errors);
        $this->assertContains('symlink:linked.php', $report->errors);
    }

    public function test_it_requires_declared_entrypoints(): void
    {
        $manifest = [
            'schemaVersion' => 1,
            'releaseId' => 'release-test',
            'files' => [[
                'path' => 'index.php',
                'size' => filesize($this->directory.DIRECTORY_SEPARATOR.'index.php'),
                'sha256' => hash_file('sha256', $this->directory.DIRECTORY_SEPARATOR.'index.php'),
            ]],
        ];

        $report = (new PackageManifestVerifier(['artisan']))
            ->verify($this->directory, $manifest, 'release-test');

        $this->assertFalse($report->valid);
        $this->assertContains('required:artisan', $report->errors);
    }
}
