<?php

namespace App\Models;

use App\Enums\JurisdictionKind;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use LogicException;

#[Fillable(['key', 'name', 'kind', 'primary_geographic_unit_id', 'enabled', 'timezone', 'metadata'])]
class Jurisdiction extends Model
{
    protected function casts(): array
    {
        return ['kind' => JurisdictionKind::class, 'enabled' => 'boolean', 'metadata' => 'array'];
    }

    public function primaryGeographicUnit(): BelongsTo
    {
        return $this->belongsTo(GeographicUnit::class, 'primary_geographic_unit_id');
    }

    public function geographicUnits(): BelongsToMany
    {
        return $this->belongsToMany(GeographicUnit::class, 'jurisdiction_geographic_unit')->withTimestamps();
    }

    protected static function booted(): void
    {
        static::saving(function (self $jurisdiction): void {
            if (! preg_match('/^[a-z0-9-]+$/', $jurisdiction->key)) {
                throw new LogicException('Jurisdiction keys must be URL-safe.');
            }
        });
        static::updating(function (self $jurisdiction): void {
            if ($jurisdiction->isDirty('key')) {
                throw new LogicException('Jurisdiction keys are immutable.');
            }
        });
    }
}
