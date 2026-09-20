<?php

namespace App\Installation;

class PackageManifestVerifier
{
    /** @param array<string, mixed> $manifest */
    public function verify(string $root, array $manifest): PackageManifestReport
    {
        $errors = [];
        $root = rtrim(str_replace('\\', '/', $root), '/');

        foreach ((array) ($manifest['files'] ?? []) as $entry) {
            if (! is_array($entry)) {
                $errors[] = 'invalid_entry';

                continue;
            }

            $relative = str_replace('\\', '/', (string) ($entry['path'] ?? ''));
            if (! $this->isSafeRelativePath($relative)) {
                $errors[] = 'unsafe_path:'.$relative;

                continue;
            }

            $path = $root.'/'.$relative;
            if (! is_file($path)) {
                $errors[] = 'missing:'.$relative;

                continue;
            }

            if (isset($entry['size']) && filesize($path) !== (int) $entry['size']) {
                $errors[] = 'size:'.$relative;

                continue;
            }

            $expectedHash = strtolower((string) ($entry['sha256'] ?? ''));
            if (! preg_match('/^[a-f0-9]{64}$/', $expectedHash)
                || ! hash_equals($expectedHash, hash_file('sha256', $path))) {
                $errors[] = 'hash:'.$relative;
            }
        }

        return new PackageManifestReport($errors === [], $errors);
    }

    private function isSafeRelativePath(string $path): bool
    {
        if ($path === '' || str_starts_with($path, '/') || preg_match('/^[a-zA-Z]:/', $path)) {
            return false;
        }

        return ! in_array('..', explode('/', $path), true);
    }
}
