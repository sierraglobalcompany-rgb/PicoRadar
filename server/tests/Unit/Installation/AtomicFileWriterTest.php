<?php

namespace Tests\Unit\Installation;

use App\Installation\AtomicFileWriter;
use PHPUnit\Framework\TestCase;

class AtomicFileWriterTest extends TestCase
{
    private string $directory;

    protected function setUp(): void
    {
        parent::setUp();
        $this->directory = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-writer-'.bin2hex(random_bytes(6));
        mkdir($this->directory, 0700, true);
    }

    protected function tearDown(): void
    {
        @unlink($this->directory.DIRECTORY_SEPARATOR.'.env');
        @unlink($this->directory.DIRECTORY_SEPARATOR.'.env.bak');
        foreach (glob($this->directory.DIRECTORY_SEPARATOR.'*') ?: [] as $file) {
            unlink($file);
        }
        rmdir($this->directory);
        parent::tearDown();
    }

    public function test_it_replaces_a_private_file_without_leaving_temporary_content(): void
    {
        $path = $this->directory.DIRECTORY_SEPARATOR.'.env';
        file_put_contents($path, 'old');

        (new AtomicFileWriter)->write($path, 'new');

        $this->assertSame('new', file_get_contents($path));
        $this->assertSame([], glob($path.'.tmp.*') ?: []);
        $this->assertFileDoesNotExist($path.'.bak');
    }
}
