<?php

namespace App\Installation;

use DateTimeImmutable;
use RuntimeException;

class InstallAttemptLimiter
{
    public function __construct(
        private readonly string $path,
        private readonly int $maximumAttempts = 5,
        private readonly int $windowSeconds = 900,
    ) {}

    public function allows(string $clientKey, ?DateTimeImmutable $now = null): bool
    {
        $attempts = $this->readPruned($now ?? new DateTimeImmutable);

        return count($attempts[$clientKey] ?? []) < $this->maximumAttempts;
    }

    public function recordFailure(string $clientKey, ?DateTimeImmutable $now = null): void
    {
        $now ??= new DateTimeImmutable;
        $this->mutate(function (array $attempts) use ($clientKey, $now): array {
            $attempts = $this->prune($attempts, $now);
            $attempts[$clientKey][] = $now->getTimestamp();

            return $attempts;
        });
    }

    public function clear(string $clientKey): void
    {
        $this->mutate(function (array $attempts) use ($clientKey): array {
            unset($attempts[$clientKey]);

            return $attempts;
        });
    }

    /** @return array<string, list<int>> */
    private function readPruned(DateTimeImmutable $now): array
    {
        return $this->withLock(fn (): array => $this->prune($this->read(), $now));
    }

    private function mutate(callable $callback): void
    {
        $this->withLock(function () use ($callback): void {
            $payload = $callback($this->read());
            (new AtomicFileWriter)->write(
                $this->path,
                json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES),
            );
        });
    }

    private function withLock(callable $callback): mixed
    {
        $directory = dirname($this->path);
        if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
            throw new RuntimeException('The attempt limiter directory cannot be created.');
        }

        $handle = fopen($this->path.'.lock', 'c+');
        if ($handle === false || ! flock($handle, LOCK_EX)) {
            throw new RuntimeException('The attempt limiter cannot be locked.');
        }

        try {
            return $callback();
        } finally {
            flock($handle, LOCK_UN);
            fclose($handle);
        }
    }

    /** @return array<string, list<int>> */
    private function read(): array
    {
        if (! is_file($this->path)) {
            return [];
        }

        $decoded = json_decode((string) file_get_contents($this->path), true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * @param  array<string, list<int>>  $attempts
     * @return array<string, list<int>>
     */
    private function prune(array $attempts, DateTimeImmutable $now): array
    {
        $cutoff = $now->getTimestamp() - $this->windowSeconds;
        foreach ($attempts as $clientKey => $timestamps) {
            $attempts[$clientKey] = array_values(array_filter(
                $timestamps,
                fn (mixed $timestamp): bool => is_int($timestamp) && $timestamp > $cutoff,
            ));
            if ($attempts[$clientKey] === []) {
                unset($attempts[$clientKey]);
            }
        }

        return $attempts;
    }
}
