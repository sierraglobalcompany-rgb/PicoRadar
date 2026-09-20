<?php

namespace App\Installation;

class HostPreflightCollector
{
    public function __construct(
        private readonly string $privateRoot,
        private readonly string $publicRoot,
        private readonly array $trustedProxyIps = [],
    ) {}

    /** @param array<string, mixed> $server */
    public function collect(array $server): HostPreflightReport
    {
        $storage = $this->privateRoot.DIRECTORY_SEPARATOR.'storage';
        $cache = $this->privateRoot.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'cache';

        return (new HostPreflight)->evaluate([
            'phpVersion' => PHP_VERSION,
            'extensions' => get_loaded_extensions(),
            'https' => $this->transportIsSecure($server),
            'writablePaths' => [
                'storage' => is_dir($storage) && is_writable($storage),
                'bootstrap/cache' => is_dir($cache) && is_writable($cache),
            ],
            'symlinkAvailable' => $this->canCreateSymlink($storage),
            'permissions' => [
                'storage' => $this->permissions($storage),
                'bootstrap/cache' => $this->permissions($cache),
            ],
        ]);
    }

    /** @param array<string, mixed> $server */
    public function transportIsSecure(array $server): bool
    {
        $remoteAddress = (string) ($server['REMOTE_ADDR'] ?? '');
        $forwarded = strtolower(trim(explode(',', (string) ($server['HTTP_X_FORWARDED_PROTO'] ?? ''))[0]));
        $trustedForwardedHttps = in_array($remoteAddress, $this->trustedProxyIps, true)
            && $forwarded === 'https';

        return strtolower((string) ($server['HTTPS'] ?? '')) === 'on'
            || $trustedForwardedHttps
            || (int) ($server['SERVER_PORT'] ?? 0) === 443;
    }

    private function canCreateSymlink(string $storage): bool
    {
        if (! function_exists('symlink') || ! is_writable($this->publicRoot)) {
            return false;
        }

        $directory = $storage.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer';
        if (! is_dir($directory) && ! @mkdir($directory, 0700, true) && ! is_dir($directory)) {
            return false;
        }

        $suffix = bin2hex(random_bytes(6));
        $target = $directory.DIRECTORY_SEPARATOR.'symlink-target-'.$suffix;
        $link = $this->publicRoot.DIRECTORY_SEPARATOR.'.picoradar-symlink-'.$suffix;
        if (@file_put_contents($target, 'test', LOCK_EX) === false) {
            return false;
        }

        try {
            return @symlink($target, $link) && is_link($link);
        } finally {
            if (is_link($link) || file_exists($link)) {
                @unlink($link);
            }
            @unlink($target);
        }
    }

    private function permissions(string $path): string
    {
        $permissions = @fileperms($path);

        return $permissions === false ? '' : substr(sprintf('%o', $permissions), -4);
    }
}
