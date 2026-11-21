<?php

namespace Tests\Unit\Installation;

use App\Installation\InstallTokenGuard;
use DateTimeImmutable;
use PHPUnit\Framework\TestCase;

class InstallTokenGuardTest extends TestCase
{
    public function test_it_accepts_only_the_token_matching_the_packaged_hash(): void
    {
        $hash = password_hash('owner-only-token', PASSWORD_ARGON2ID);
        $guard = new InstallTokenGuard;

        $this->assertTrue($guard->verify('owner-only-token', $hash));
        $this->assertFalse($guard->verify('wrong-token', $hash));
        $this->assertFalse($guard->verify('', $hash));
        $this->assertFalse($guard->verify('owner-only-token', 'invalid-hash'));
    }

    public function test_it_rejects_an_expired_token(): void
    {
        $hash = password_hash('owner-only-token', PASSWORD_ARGON2ID);

        $this->assertFalse((new InstallTokenGuard)->verify(
            'owner-only-token',
            $hash,
            new DateTimeImmutable('2026-09-18T00:00:00Z'),
            new DateTimeImmutable('2026-09-19T00:00:00Z'),
        ));
    }
}
