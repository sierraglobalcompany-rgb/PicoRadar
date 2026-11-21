<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use LogicException;

#[Fillable(['version', 'asset_path', 'sha256', 'campaign_count', 'generated_at', 'expires_at', 'published_by_id'])]
class CampaignCatalogRelease extends Model
{
    public const UPDATED_AT = null;

    protected function casts(): array
    {
        return [
            'version' => 'integer',
            'campaign_count' => 'integer',
            'generated_at' => 'datetime',
            'expires_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Campaign catalog releases are immutable.'));
        static::deleting(fn () => throw new LogicException('Campaign catalog releases are immutable.'));
    }
}
