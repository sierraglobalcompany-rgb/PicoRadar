<?php

namespace Tests\Unit\Installation;

use App\Installation\DatabaseCredentials;
use App\Installation\DatabaseProbeReceipt;
use DateTimeImmutable;
use PHPUnit\Framework\TestCase;

class DatabaseProbeReceiptTest extends TestCase
{
    public function test_it_accepts_only_the_same_credentials_before_expiry(): void
    {
        $credentials = new DatabaseCredentials('localhost', 3306, 'picoradar', 'owner', 'test_${APP_NAME}_tail');
        $changed = new DatabaseCredentials('localhost', 3306, 'picoradar', 'owner', 'different');
        $service = new DatabaseProbeReceipt('test-hmac-key');
        $now = new DateTimeImmutable('2026-09-20T12:00:00+00:00');
        $receipt = $service->issue($credentials, $now);

        $this->assertTrue($service->verify($credentials, $receipt, $now->modify('+4 minutes')));
        $this->assertFalse($service->verify($changed, $receipt, $now->modify('+4 minutes')));
        $this->assertFalse($service->verify($credentials, $receipt, $now->modify('+6 minutes')));
        $this->assertStringNotContainsString($credentials->password, json_encode($receipt, JSON_THROW_ON_ERROR));
    }
}
