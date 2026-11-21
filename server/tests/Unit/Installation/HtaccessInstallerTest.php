<?php

namespace Tests\Unit\Installation;

use App\Installation\HtaccessInstaller;
use PHPUnit\Framework\TestCase;

class HtaccessInstallerTest extends TestCase
{
    private string $directory;

    protected function setUp(): void
    {
        parent::setUp();
        $this->directory = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-htaccess-'.bin2hex(random_bytes(6));
        mkdir($this->directory, 0700, true);
    }

    protected function tearDown(): void
    {
        foreach (new \FilesystemIterator($this->directory) as $file) {
            unlink($file->getPathname());
        }
        rmdir($this->directory);
        parent::tearDown();
    }

    public function test_it_preserves_existing_basic_auth_and_installs_routing_once(): void
    {
        $target = $this->directory.DIRECTORY_SEPARATOR.'.htaccess';
        $template = $this->directory.DIRECTORY_SEPARATOR.'routing.htaccess';
        file_put_contents($target, "AuthType Basic\nAuthName \"Private staging\"\nRequire valid-user\n");
        file_put_contents($template, "<IfModule mod_rewrite.c>\nRewriteEngine On\n</IfModule>\n");

        $installer = new HtaccessInstaller;
        $installer->install($target, $template);
        $installer->install($target, $template);

        $contents = (string) file_get_contents($target);
        $this->assertStringContainsString('AuthType Basic', $contents);
        $this->assertStringContainsString('Require valid-user', $contents);
        $this->assertSame(1, substr_count($contents, HtaccessInstaller::START_MARKER));
        $this->assertSame(1, substr_count($contents, 'RewriteEngine On'));
    }
}
