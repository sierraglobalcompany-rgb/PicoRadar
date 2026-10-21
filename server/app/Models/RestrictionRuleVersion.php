<?php

namespace App\Models;

use App\Enums\RestrictionRuleVersionStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['jurisdiction_id', 'version', 'status', 'payload', 'payload_sha256', 'base_publication_revision', 'vehicle_kinds', 'valid_from', 'valid_until', 'stale_after', 'source_checked_at', 'created_by_id', 'updated_by_id', 'validated_by_id', 'validated_at', 'archived_by_id', 'archived_at'])]
class RestrictionRuleVersion extends Model
{
    protected function casts(): array
    {
        return [
            'status' => RestrictionRuleVersionStatus::class,
            'payload' => 'array',
            'vehicle_kinds' => 'array',
            'valid_from' => 'date',
            'valid_until' => 'date',
            'stale_after' => 'datetime',
            'source_checked_at' => 'datetime',
            'validated_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }

    public function jurisdiction(): BelongsTo
    {
        return $this->belongsTo(Jurisdiction::class);
    }

    public function publicationItems(): HasMany
    {
        return $this->hasMany(RestrictionPublicationItem::class);
    }
}
