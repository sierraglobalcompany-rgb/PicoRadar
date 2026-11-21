<?php

namespace App\Models;

use App\Enums\SponsorStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

#[Fillable(['public_id', 'name', 'contact_name', 'contact_email', 'contact_phone', 'notes', 'status', 'created_by_id', 'updated_by_id', 'archived_by_id', 'archived_at'])]
class Sponsor extends Model
{
    protected function casts(): array
    {
        return ['status' => SponsorStatus::class, 'archived_at' => 'datetime'];
    }

    public function campaigns(): HasMany
    {
        return $this->hasMany(Campaign::class);
    }

    protected static function booted(): void
    {
        static::updating(function (self $sponsor): void {
            if ($sponsor->isDirty('public_id')) {
                throw new LogicException('Sponsor public IDs are immutable.');
            }
            if ($sponsor->getOriginal('status') === SponsorStatus::Archived->value) {
                throw new LogicException('Archived sponsors are terminal.');
            }
        });
        static::deleting(fn () => throw new LogicException('Sponsors cannot be hard deleted.'));
    }
}
