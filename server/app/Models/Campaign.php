<?php

namespace App\Models;

use App\Enums\CampaignScope;
use App\Enums\CampaignStatus;
use DateTimeInterface;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

#[Fillable(['public_id', 'sponsor_id', 'status', 'placement', 'eyebrow', 'title', 'subtitle', 'cta_text', 'cta_url', 'priority', 'scope', 'geographic_unit_id', 'starts_at', 'ends_at', 'source_image_path', 'public_image_path', 'image_sha256', 'image_mime', 'image_width', 'image_height', 'image_bytes', 'content_revision', 'created_by_id', 'updated_by_id', 'activated_by_id', 'paused_by_id', 'archived_by_id', 'activated_at', 'paused_at', 'archived_at'])]
class Campaign extends Model
{
    protected function casts(): array
    {
        return [
            'status' => CampaignStatus::class,
            'scope' => CampaignScope::class,
            'priority' => 'integer',
            'image_width' => 'integer',
            'image_height' => 'integer',
            'image_bytes' => 'integer',
            'content_revision' => 'integer',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'activated_at' => 'datetime',
            'paused_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }

    public function sponsor(): BelongsTo
    {
        return $this->belongsTo(Sponsor::class);
    }

    public function geographicUnit(): BelongsTo
    {
        return $this->belongsTo(GeographicUnit::class);
    }

    public function operationalStatus(DateTimeInterface $at): string
    {
        if ($this->status !== CampaignStatus::Active) {
            return $this->status->value;
        }
        $instant = $at->getTimestamp();
        if ($this->starts_at->getTimestamp() > $instant) {
            return 'scheduled';
        }
        if ($this->ends_at->getTimestamp() <= $instant) {
            return 'expired';
        }

        return 'active';
    }

    protected static function booted(): void
    {
        static::saving(function (self $campaign): void {
            if ($campaign->ends_at && $campaign->starts_at && $campaign->ends_at <= $campaign->starts_at) {
                throw new LogicException('Campaign end must be after its start.');
            }
            if ($campaign->exists && $campaign->isDirty('public_id')) {
                throw new LogicException('Campaign public IDs are immutable.');
            }
            if ($campaign->exists && $campaign->getOriginal('status') === CampaignStatus::Archived->value) {
                throw new LogicException('Archived campaigns are terminal.');
            }
        });
        static::deleting(fn () => throw new LogicException('Campaigns cannot be hard deleted.'));
    }
}
