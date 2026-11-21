<?php

namespace App\Installation;

class HostPreflight
{
    /** @var list<string> */
    private const REQUIRED_EXTENSIONS = [
        'ctype',
        'curl',
        'dom',
        'fileinfo',
        'filter',
        'hash',
        'mbstring',
        'openssl',
        'pcre',
        'pdo',
        'pdo_mysql',
        'session',
        'tokenizer',
        'xml',
    ];

    /** @param array<string, mixed> $facts */
    public function evaluate(array $facts): HostPreflightReport
    {
        $blockers = [];
        $version = (string) ($facts['phpVersion'] ?? '0.0.0');
        if (version_compare($version, '8.3.0', '<') || version_compare($version, '8.6.0', '>=')) {
            $blockers[] = 'php_version';
        }

        if (($facts['https'] ?? false) !== true) {
            $blockers[] = 'https';
        }

        $extensions = array_map('strtolower', (array) ($facts['extensions'] ?? []));
        if (array_diff(self::REQUIRED_EXTENSIONS, $extensions) !== []) {
            $blockers[] = 'extensions';
        }

        $writablePaths = (array) ($facts['writablePaths'] ?? []);
        if (($writablePaths['storage'] ?? false) !== true || ($writablePaths['bootstrap/cache'] ?? false) !== true) {
            $blockers[] = 'writable_paths';
        }

        if (($facts['symlinkAvailable'] ?? false) !== true) {
            $blockers[] = 'symlink';
        }

        foreach ((array) ($facts['permissions'] ?? []) as $permission) {
            if (ltrim((string) $permission, '0') === '777') {
                $blockers[] = 'unsafe_permissions';
                break;
            }
        }

        return new HostPreflightReport($blockers === [], $blockers);
    }
}
