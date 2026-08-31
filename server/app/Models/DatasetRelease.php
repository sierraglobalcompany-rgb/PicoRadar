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
        static::creating(function (self $release): void {
            if ($release->status !== DatasetReleaseStatus::Draft) {
                throw new LogicException('New releases must be created as drafts.');
            }
            if (! preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/', $release->version)) {
                throw new LogicException('Release version is unsafe.');
            }
        });
        static::updating(function (self $release): void {
            $from = $release->getRawOriginal('status');
            $to = $release->status->value;
            if ($from === DatasetReleaseStatus::Draft->value && ! in_array($to, [DatasetReleaseStatus::Draft->value, DatasetReleaseStatus::Validated->value], true)) {
                throw new LogicException('Invalid draft release transition.');
            }
            if ($from === DatasetReleaseStatus::Validated->value && $to !== DatasetReleaseStatus::Published->value) {
                throw new LogicException('Validated releases can only be published.');
            }
            if ($from === DatasetReleaseStatus::Published->value && $to !== DatasetReleaseStatus::Retired->value) {
                throw new LogicException('Published releases can only be retired.');
            }
            if ($from === DatasetReleaseStatus::Retired->value) {
                throw new LogicException('Retired releases are terminal.');
            }
            $allowed = match ($from) {
                DatasetReleaseStatus::Draft->value => ['status', 'sha256', 'generated_at', 'verified_at', 'validated_at', 'metadata'],
                DatasetReleaseStatus::Validated->value => ['status', 'asset_path', 'content_encoding', 'published_at'],
                DatasetReleaseStatus::Published->value => ['status', 'retired_at'],
                default => [],
            };
            if (array_diff(array_keys($release->getDirty()), $allowed) !== []) {
                throw new LogicException('Historical release fields are immutable.');
            }
        });
    }
}
