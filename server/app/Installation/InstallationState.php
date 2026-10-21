<?php

namespace App\Installation;

use DateTimeImmutable;

readonly class InstallationState
{
    public function __construct(
        public InstallationStage $stage,
        public ?string $releaseId = null,
        public ?DateTimeImmutable $updatedAt = null,
        public ?InstallationStage $retryStage = null,
        public ?string $errorCode = null,
    ) {}
}
