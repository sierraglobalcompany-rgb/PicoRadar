<?php

namespace App\Installation;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use RuntimeException;

final class SyntheticCronProbeJob implements ShouldQueue
{
    use Dispatchable;
    use Queueable;

    public int $tries = 1;

    public function __construct(
        private readonly string $markerPath,
        private readonly bool $shouldFail = false,
    ) {}

    public function handle(): void
    {
        if ($this->shouldFail) {
            throw new RuntimeException('Synthetic cron probe failure.');
        }

        $directory = dirname($this->markerPath);
        if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
            throw new RuntimeException('Synthetic cron probe directory is unavailable.');
        }
        if (file_put_contents($this->markerPath, 'processed'.PHP_EOL, LOCK_EX) === false) {
            throw new RuntimeException('Synthetic cron probe marker cannot be written.');
        }
    }
}
