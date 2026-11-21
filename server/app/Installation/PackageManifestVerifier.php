<?php

namespace App\Installation;

class PackageManifestVerifier
{
    /** @param list<string> $requiredPaths */
    public function __construct(private readonly array $requiredPaths = []) {}

    /** @param array<string, mixed> $manifest */
    public function verify(
        string $root,
        array $manifest,
        ?string $expectedReleaseId = null,
    ): PackageManifestReport {
        $errors = [];
        $root = rtrim(str_replace('\\', '/', $root), '/');
        $rootRealPath = realpath($root);

        if (($manifest['schemaVersion'] ?? null) !== 1) {
            $errors[] = 'schema_version';
        }

        $releaseId = $manifest['releaseId'] ?? null;
        if (! is_string($releaseId) || trim($releaseId) === '') {
            $errors[] = 'release_id';
        } elseif ($expectedReleaseId !== null && ! hash_equals($expectedReleaseId, $releaseId)) {
            $errors[] = 'release_id';
        }

        $entries = $manifest['files'] ?? null;
        if (! is_array($entries) || $entries === []) {
            $errors[] = 'files';

            return new PackageManifestReport(false, array_values(array_unique($errors)));
        }

        $seen = [];

        foreach ($entries as $entry) {
            if (! is_array($entry)) {
                $errors[] = 'invalid_entry';

                continue;
            }

            $relative = str_replace('\\', '/', (string) ($entry['path'] ?? ''));
            if (! $this->isSafeRelativePath($relative)) {
                $errors[] = 'unsafe_path:'.$relative;

                continue;
            }

            if (isset($seen[$relative])) {
                $errors[] = 'duplicate:'.$relative;

                continue;
            }
            $seen[$relative] = true;

            $path = $root.'/'.$relative;
            if (! is_file($path)) {
                $errors[] = 'missing:'.$relative;

                continue;
            }

            if (is_link($path)) {
                $errors[] = 'symlink:'.$relative;

                continue;
            }

            $realPath = realpath($path);
            if ($rootRealPath === false
                || $realPath === false
                || ! str_starts_with(
                    str_replace('\\', '/', $realPath).'/',
                    rtrim(str_replace('\\', '/', $rootRealPath), '/').'/',
                )) {
                $errors[] = 'outside_root:'.$relative;

                continue;
            }

            if (! array_key_exists('size', $entry)
                || ! is_int($entry['size'])
                || $entry['size'] < 0
                || filesize($path) !== $entry['size']) {
                $errors[] = 'size:'.$relative;

                continue;
            }

            $expectedHash = strtolower((string) ($entry['sha256'] ?? ''));
            if (! preg_match('/^[a-f0-9]{64}$/', $expectedHash)
                || ! hash_equals($expectedHash, hash_file('sha256', $path))) {
                $errors[] = 'hash:'.$relative;
            }
        }

        foreach ($this->requiredPaths as $requiredPath) {
            $normalized = str_replace('\\', '/', $requiredPath);
            if (! isset($seen[$normalized])) {
                $errors[] = 'required:'.$normalized;
            }
        }

        return new PackageManifestReport($errors === [], array_values(array_unique($errors)));
    }

    private function isSafeRelativePath(string $path): bool
    {
        if ($path === ''
            || str_starts_with($path, '/')
            || preg_match('/^[a-zA-Z]:/', $path)
            || preg_match('/[\x00-\x1f\x7f]/', $path)) {
            return false;
        }

        foreach (explode('/', $path) as $segment) {
            if ($segment === '' || $segment === '.' || $segment === '..') {
                return false;
            }
        }

        return true;
    }
}
