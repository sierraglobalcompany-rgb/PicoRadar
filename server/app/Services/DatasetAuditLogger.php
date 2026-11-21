<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;

class DatasetAuditLogger
{
    /** @param array<string, mixed> $metadata */
    public function log(?User $actor, string $action, Model $subject, array $metadata = []): void
    {
        AuditLog::query()->create(['actor_id' => $actor?->id, 'action' => $action, 'subject_type' => $subject::class, 'subject_id' => $subject->getKey(), 'metadata' => $metadata]);
    }
}
