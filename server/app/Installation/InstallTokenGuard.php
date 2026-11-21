<?php

namespace App\Installation;

use DateTimeImmutable;

class InstallTokenGuard
{
    public function verify(
        string $candidate,
        string $hash,
        ?DateTimeImmutable $expiresAt = null,
        ?DateTimeImmutable $now = null,
    ): bool {
        if ($candidate === '' || $hash === '' || password_get_info($hash)['algo'] === null) {
            return false;
        }

        if ($expiresAt !== null && ($now ?? new DateTimeImmutable) >= $expiresAt) {
            return false;
        }

        return password_verify($candidate, $hash);
    }
}
