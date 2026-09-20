<?php

namespace Tests\Unit\Installation;

use App\Installation\DatabaseCredentials;
use App\Installation\StagingEnvironmentBuilder;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

class StagingEnvironmentBuilderTest extends TestCase
{
    public function test_it_builds_a_fail_closed_staging_environment_with_escaped_credentials(): void
    {
        $credentials = new DatabaseCredentials(
            host: 'localhost',
            port: 3306,
            database: 'u390570745_picoradar',
            username: 'u390570745_owner',
            password: 'special # value "with quotes"',
        );

        $environment = (new StagingEnvironmentBuilder)->build(
            credentials: $credentials,
            appKey: 'base64:'.base64_encode(str_repeat('a', 32)),
            appUrl: 'https://picoradar.bodegadigitalmedellin.com',
        );

        $this->assertStringContainsString('APP_ENV="staging"', $environment);
        $this->assertStringContainsString('APP_DEBUG="false"', $environment);
        $this->assertStringContainsString('APP_URL="https://picoradar.bodegadigitalmedellin.com"', $environment);
        $this->assertStringContainsString('DB_CONNECTION="mysql"', $environment);
        $this->assertStringContainsString('DB_DATABASE="u390570745_picoradar"', $environment);
        $this->assertStringContainsString('DB_PASSWORD="special # value \\"with quotes\\""', $environment);
        $this->assertStringContainsString('SESSION_ENCRYPT="true"', $environment);
        $this->assertStringContainsString('SESSION_SECURE_COOKIE="true"', $environment);
        $this->assertStringContainsString('SESSION_SAME_SITE="strict"', $environment);
        $this->assertStringContainsString('QUEUE_CONNECTION="database"', $environment);
        $this->assertStringContainsString('MAIL_MAILER="array"', $environment);
        $this->assertStringContainsString('TRIPS_ENABLED="false"', $environment);
        $this->assertStringContainsString('PRIVATE_OSRM_ENABLED="false"', $environment);
        $this->assertStringContainsString('PARTNER_INQUIRIES_ENABLED="false"', $environment);
    }

    public function test_database_credentials_reject_control_characters_and_malformed_identifiers(): void
    {
        $invalid = [
            ['bad\nhost', 3306, 'database', 'user', 'password'],
            ['localhost', 0, 'database', 'user', 'password'],
            ['localhost', 3306, 'database;drop', 'user', 'password'],
            ['localhost', 3306, 'database', 'user name', 'password'],
            ['localhost', 3306, 'database', 'user', "password\rvalue"],
        ];

        foreach ($invalid as [$host, $port, $database, $username, $password]) {
            try {
                new DatabaseCredentials($host, $port, $database, $username, $password);
                $this->fail('Invalid database credentials were accepted.');
            } catch (InvalidArgumentException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    public function test_it_rejects_non_https_urls_and_invalid_application_keys(): void
    {
        $credentials = new DatabaseCredentials('localhost', 3306, 'database', 'user', 'password');
        $builder = new StagingEnvironmentBuilder;

        foreach ([
            ['not-a-key', 'https://picoradar.example.test'],
            ['base64:'.base64_encode(str_repeat('a', 32)), 'http://picoradar.example.test'],
            ['base64:'.base64_encode(str_repeat('a', 31)), 'https://picoradar.example.test'],
        ] as [$key, $url]) {
            try {
                $builder->build($credentials, $key, $url);
                $this->fail('Invalid staging configuration was accepted.');
            } catch (InvalidArgumentException) {
                $this->addToAssertionCount(1);
            }
        }
    }
}
