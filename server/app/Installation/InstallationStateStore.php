<?php

namespace App\Installation;

use DateTimeImmutable;
use JsonException;
use LogicException;
use RuntimeException;

class InstallationStateStore
{
    public function __construct(
        private readonly string $path,
        private readonly ?string $expectedReleaseId = null,
    ) {}

    public function read(): InstallationState
    {
        $primaryExists = is_file($this->path);
        $backupExists = is_file($this->backupPath());
        $primaryError = null;

        try {
            $payload = $this->readPayload($this->path);
        } catch (RuntimeException $exception) {
            $primaryError = $exception;
            $payload = null;
        }

        if ($payload === null) {
            try {
                $payload = $this->readPayload($this->backupPath());
            } catch (RuntimeException $backupError) {
                throw new RuntimeException(
                    'The installation state and its backup are invalid.',
                    0,
                    $backupError,
                );
            }
        }

        if ($payload === null) {
            if ($primaryExists || $backupExists) {
                throw new RuntimeException(
                    'The installation state cannot be recovered.',
                    0,
                    $primaryError,
                );
            }

            return new InstallationState(InstallationStage::New);
        }

        try {
            $state = new InstallationState(
                InstallationStage::from((string) $payload['stage']),
                isset($payload['releaseId']) ? (string) $payload['releaseId'] : null,
                isset($payload['updatedAt'])
                    ? new DateTimeImmutable((string) $payload['updatedAt'])
                    : null,
                isset($payload['retryStage'])
                    ? InstallationStage::from((string) $payload['retryStage'])
                    : null,
                isset($payload['errorCode']) ? (string) $payload['errorCode'] : null,
            );

            if ($this->expectedReleaseId !== null
                && $state->releaseId !== null
                && ! hash_equals($this->expectedReleaseId, $state->releaseId)) {
                throw new RuntimeException('The installation state belongs to another release.');
            }

            return $state;
        } catch (\Throwable $exception) {
            throw new RuntimeException('The installation state is invalid.', 0, $exception);
        }
    }

    public function write(InstallationStage $stage, string $releaseId): InstallationState
    {
        $this->assertReleaseId($releaseId);
        $current = $this->read();
        if ($current->stage === InstallationStage::Completed && $stage !== InstallationStage::Completed) {
            throw new LogicException('A completed installation cannot move backwards.');
        }
        $currentStage = $current->stage === InstallationStage::Failed
            ? ($current->retryStage ?? InstallationStage::New)
            : $current->stage;
        if ($stage !== $currentStage && $stage !== $this->nextStage($currentStage)) {
            throw new LogicException('The installation transition is invalid.');
        }

        $state = new InstallationState($stage, $releaseId, new DateTimeImmutable);
        $this->persist($state);

        return $state;
    }

    public function fail(
        InstallationStage $retryStage,
        string $releaseId,
        string $errorCode,
    ): InstallationState {
        $this->assertReleaseId($releaseId);
        $current = $this->read();
        if ($current->stage === InstallationStage::Completed) {
            throw new LogicException('A completed installation cannot fail.');
        }
        if ($retryStage === InstallationStage::Failed || $retryStage === InstallationStage::Completed) {
            throw new LogicException('The retry stage is invalid.');
        }
        if (! preg_match('/^[a-z0-9_]{1,64}$/', $errorCode)) {
            throw new LogicException('The installation error code is invalid.');
        }

        $state = new InstallationState(
            InstallationStage::Failed,
            $releaseId,
            new DateTimeImmutable,
            $retryStage,
            $errorCode,
        );
        $this->persist($state);

        return $state;
    }

    private function persist(InstallationState $state): void
    {
        $this->writeAtomically([
            'stage' => $state->stage->value,
            'releaseId' => $state->releaseId,
            'updatedAt' => $state->updatedAt?->format(DATE_ATOM),
            'retryStage' => $state->retryStage?->value,
            'errorCode' => $state->errorCode,
        ]);
    }

    /** @return array<string, mixed>|null */
    private function readPayload(string $path): ?array
    {
        if (! is_file($path)) {
            return null;
        }

        try {
            $decoded = json_decode((string) file_get_contents($path), true, 16, JSON_THROW_ON_ERROR);
        } catch (JsonException $exception) {
            throw new RuntimeException('The installation state cannot be decoded.', 0, $exception);
        }

        return is_array($decoded) ? $decoded : null;
    }

    /** @param array<string, mixed> $payload */
    private function writeAtomically(array $payload): void
    {
        $directory = dirname($this->path);
        if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
            throw new RuntimeException('The installation state directory cannot be created.');
        }

        $temporary = $this->path.'.tmp.'.bin2hex(random_bytes(6));
        $encoded = json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
        if (file_put_contents($temporary, $encoded.PHP_EOL, LOCK_EX) === false) {
            throw new RuntimeException('The installation state cannot be written.');
        }
        @chmod($temporary, 0600);

        $backup = $this->backupPath();
        if (is_file($backup) && ! unlink($backup)) {
            @unlink($temporary);
            throw new RuntimeException('The previous installation state backup cannot be removed.');
        }

        if (is_file($this->path) && ! rename($this->path, $backup)) {
            @unlink($temporary);
            throw new RuntimeException('The previous installation state cannot be preserved.');
        }

        if (! rename($temporary, $this->path)) {
            if (is_file($backup)) {
                @rename($backup, $this->path);
            }
            @unlink($temporary);
            throw new RuntimeException('The installation state cannot be replaced.');
        }

        if (is_file($backup)) {
            @unlink($backup);
        }
    }

    private function backupPath(): string
    {
        return $this->path.'.bak';
    }

    private function assertReleaseId(string $releaseId): void
    {
        if ($releaseId === ''
            || ($this->expectedReleaseId !== null && ! hash_equals($this->expectedReleaseId, $releaseId))) {
            throw new LogicException('The installation release is invalid.');
        }
    }

    private function nextStage(InstallationStage $stage): ?InstallationStage
    {
        return match ($stage) {
            InstallationStage::New => InstallationStage::Configured,
            InstallationStage::Configured => InstallationStage::Migrated,
            InstallationStage::Migrated => InstallationStage::OperatorCreated,
            InstallationStage::OperatorCreated => InstallationStage::Completed,
            InstallationStage::Completed, InstallationStage::Failed => null,
        };
    }
}
