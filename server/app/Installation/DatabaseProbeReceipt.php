<?php

namespace App\Installation;

use DateTimeImmutable;

class DatabaseProbeReceipt
{
    public function __construct(
        private readonly string $hmacKey,
        private readonly int $lifetimeSeconds = 300,
    ) {}

    /** @return array{fingerprint: string, expiresAt: int} */
    public function issue(DatabaseCredentials $credentials, ?DateTimeImmutable $now = null): array
    {
        $now ??= new DateTimeImmutable;
        $expiresAt = $now->getTimestamp() + $this->lifetimeSeconds;

        return [
            'fingerprint' => $this->fingerprint($credentials, $expiresAt),
            'expiresAt' => $expiresAt,
        ];
    }

    /** @param array<string, mixed> $receipt */
    public function verify(
        DatabaseCredentials $credentials,
        array $receipt,
        ?DateTimeImmutable $now = null,
    ): bool {
        $now ??= new DateTimeImmutable;
        $expiresAt = $receipt['expiresAt'] ?? null;
        $fingerprint = $receipt['fingerprint'] ?? null;
        if (! is_int($expiresAt)
            || ! is_string($fingerprint)
            || $expiresAt < $now->getTimestamp()) {
            return false;
        }

        return hash_equals($this->fingerprint($credentials, $expiresAt), $fingerprint);
    }

    private function fingerprint(DatabaseCredentials $credentials, int $expiresAt): string
    {
        $payload = json_encode([
            'host' => $credentials->host,
            'port' => $credentials->port,
            'database' => $credentials->database,
            'username' => $credentials->username,
            'password' => $credentials->password,
            'expiresAt' => $expiresAt,
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);

        return hash_hmac('sha256', $payload, $this->hmacKey);
    }
}
