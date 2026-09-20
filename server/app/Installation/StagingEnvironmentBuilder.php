<?php

namespace App\Installation;

use InvalidArgumentException;

class StagingEnvironmentBuilder
{
    public function build(
        DatabaseCredentials $credentials,
        string $appKey,
        string $appUrl,
    ): string {
        $decodedKey = str_starts_with($appKey, 'base64:')
            ? base64_decode(substr($appKey, 7), true)
            : false;
        if ($decodedKey === false || strlen($decodedKey) !== 32) {
            throw new InvalidArgumentException('The application key is invalid.');
        }

        $url = parse_url($appUrl);
        if (! is_array($url)
            || ($url['scheme'] ?? null) !== 'https'
            || empty($url['host'])
            || isset($url['user'], $url['pass'])
            || isset($url['query'])
            || isset($url['fragment'])) {
            throw new InvalidArgumentException('The application URL must be an HTTPS origin.');
        }
        $appUrl = rtrim($appUrl, '/');

        $values = [
            'APP_NAME' => 'PicoRadar',
            'APP_ENV' => 'staging',
            'APP_KEY' => $appKey,
            'APP_DEBUG' => 'false',
            'APP_URL' => $appUrl,
            'APP_LOCALE' => 'es',
            'APP_FALLBACK_LOCALE' => 'es',
            'APP_MAINTENANCE_DRIVER' => 'file',
            'BCRYPT_ROUNDS' => '12',
            'LOG_CHANNEL' => 'stack',
            'LOG_STACK' => 'single',
            'LOG_LEVEL' => 'warning',
            'DB_CONNECTION' => 'mysql',
            'DB_HOST' => $credentials->host,
            'DB_PORT' => (string) $credentials->port,
            'DB_DATABASE' => $credentials->database,
            'DB_USERNAME' => $credentials->username,
            'DB_PASSWORD' => $credentials->password,
            'SESSION_DRIVER' => 'database',
            'SESSION_LIFETIME' => '120',
            'SESSION_ENCRYPT' => 'true',
            'SESSION_PATH' => '/',
            'SESSION_DOMAIN' => 'null',
            'SESSION_SECURE_COOKIE' => 'true',
            'SESSION_HTTP_ONLY' => 'true',
            'SESSION_SAME_SITE' => 'strict',
            'BROADCAST_CONNECTION' => 'log',
            'FILESYSTEM_DISK' => 'local',
            'DATASET_DRAFT_DISK' => 'local',
            'DATASET_PUBLISHED_DISK' => 'public',
            'DATASET_PUBLIC_BASE_URL' => $appUrl.'/storage',
            'CAMPAIGN_PUBLIC_BASE_URL' => $appUrl.'/storage',
            'QUEUE_CONNECTION' => 'database',
            'CACHE_STORE' => 'database',
            'MAIL_MAILER' => 'array',
            'TRIPS_ENABLED' => 'false',
            'TRIPS_ACCESS_AUTHORIZED' => 'false',
            'TRIPS_LICENSE_AUTHORIZED' => 'false',
            'PRIVATE_OSRM_ENABLED' => 'false',
            'PRIVATE_OSRM_ACCESS_AUTHORIZED' => 'false',
            'PRIVATE_OSRM_SOURCE_AUTHORIZED' => 'false',
            'PARTNER_INQUIRIES_ENABLED' => 'false',
            'PARTNER_INQUIRIES_ADMIN_INBOX_ENABLED' => 'false',
            'PARTNER_INQUIRIES_ALLOW_INSECURE_LOCAL' => 'false',
        ];

        return implode(PHP_EOL, array_map(
            fn (string $key, string $value): string => $key.'='.$this->quote($value),
            array_keys($values),
            $values,
        )).PHP_EOL;
    }

    private function quote(string $value): string
    {
        if (preg_match('/[\r\n\x00]/', $value)) {
            throw new InvalidArgumentException('Environment values cannot contain control characters.');
        }

        return '"'.str_replace(
            ['\\', '"', '$'],
            ['\\\\', '\\"', '\\$'],
            $value,
        ).'"';
    }
}
