<?php

namespace App\Installation;

use RuntimeException;

class InstallationMutationLock
{
    /** @var resource|null */
    private $handle = null;

    public function __construct(private readonly string $path) {}

    public function acquire(int $timeoutMilliseconds = 1500): void
    {
        if ($this->handle !== null) {
            throw new RuntimeException('The installation lock is already held.');
        }

        $directory = dirname($this->path);
        if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
            throw new RuntimeException('The installation lock directory cannot be created.');
        }

        $handle = fopen($this->path, 'c+b');
        if ($handle === false) {
            throw new RuntimeException('The installation lock cannot be opened.');
        }
        @chmod($this->path, 0600);

        $deadline = hrtime(true) + max(0, $timeoutMilliseconds) * 1_000_000;
        do {
            if (flock($handle, LOCK_EX | LOCK_NB)) {
                $this->handle = $handle;

                return;
            }
            if ($timeoutMilliseconds === 0 || hrtime(true) >= $deadline) {
                break;
            }
            usleep(25_000);
        } while (true);

        fclose($handle);
        throw new InstallationLockBusyException('Another installation action is in progress.');
    }

    public function release(): void
    {
        if ($this->handle === null) {
            return;
        }

        flock($this->handle, LOCK_UN);
        fclose($this->handle);
        $this->handle = null;
    }

    public function __destruct()
    {
        $this->release();
    }
}
