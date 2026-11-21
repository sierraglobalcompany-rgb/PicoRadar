<?php

namespace App\Installation;

use RuntimeException;

class AtomicFileWriter
{
    public function write(string $path, string $contents): void
    {
        $directory = dirname($path);
        if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
            throw new RuntimeException('The destination directory cannot be created.');
        }

        $temporary = $path.'.tmp.'.bin2hex(random_bytes(6));
        $backup = $path.'.bak';
        if (file_put_contents($temporary, $contents, LOCK_EX) === false) {
            throw new RuntimeException('The private file cannot be written.');
        }
        @chmod($temporary, 0600);

        if (is_file($backup) && ! unlink($backup)) {
            @unlink($temporary);
            throw new RuntimeException('The previous backup cannot be removed.');
        }
        if (is_file($path) && ! rename($path, $backup)) {
            @unlink($temporary);
            throw new RuntimeException('The previous private file cannot be preserved.');
        }
        if (! rename($temporary, $path)) {
            if (is_file($backup)) {
                @rename($backup, $path);
            }
            @unlink($temporary);
            throw new RuntimeException('The private file cannot be replaced.');
        }
        if (is_file($backup)) {
            @unlink($backup);
        }
    }
}
