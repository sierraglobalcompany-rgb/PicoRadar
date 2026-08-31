<?php

namespace App\Models;

use App\Enums\DatasetReleaseStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

#[Fillable(['dataset_id', 'version', 'status', 'draft_path', 'asset_path', 'sha256', 'content_encoding', 'generated_at', 'verified_at', 'expires_at', 'validated_at', 'published_at', 'retired_at', 'metadata'])]
class DatasetRelease extends Model
{
    protected function casts(): array
    {
        return ['status' => DatasetReleaseStatus::class, 'metadata' => 'array', 'generated_at' => 'datetime', 'verified_at' => 'datetime', 'expires_at' => 'datetime', 'validated_at' => 'datetime', 'published_at' => 'datetime', 'retired_at' => 'datetime'];
    }

    public function dataset(): BelongsTo
    {
        return $this->belongsTo(Dataset::class);
    }

    protected static function booted(): void
    {
        static::updating(function (self $release): void {
            if ($release->getRawOriginal('status') === DatasetReleaseStatus::Published->value && $release->isDirty(['version', 'draft_path', 'asset_path', 'sha256', 'content_encoding', 'generated_at'])) {
                throw new LogicException('Published releases are immutable.');
            }
        });
    }
}
