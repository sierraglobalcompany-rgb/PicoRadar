<?php

namespace App\Installation;

use RuntimeException;
use Throwable;

class HostingerCronRunner
{
    public function __construct(private readonly string $lockPath) {}

    public function run(callable $task): string
    {
        $directory = dirname($this->lockPath);
        if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
            return 'ERROR_LOCK';
        }

        $handle = @fopen($this->lockPath, 'c+');
        if ($handle === false) {
            return 'ERROR_LOCK';
        }

        if (! flock($handle, LOCK_EX | LOCK_NB)) {
            fclose($handle);

            return 'SKIPPED_LOCKED';
        }

        try {
            $task();

            return 'OK';
        } catch (RuntimeException) {
            return 'ERROR_RUNTIME';
        } catch (Throwable) {
            return 'ERROR_UNKNOWN';
        } finally {
            flock($handle, LOCK_UN);
            fclose($handle);
        }
    }
}
