<?php

namespace App\Models;

use App\Enums\GeographicUnitLevel;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

#[Fillable(['parent_id', 'key', 'level', 'code', 'name', 'normalized_name', 'is_active', 'source_system', 'source_version', 'metadata'])]
class GeographicUnit extends Model
{
    protected function casts(): array
    {
        return ['level' => GeographicUnitLevel::class, 'is_active' => 'boolean', 'metadata' => 'array'];
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(self::class, 'parent_id');
    }

    public function jurisdictions(): BelongsToMany
    {
        return $this->belongsToMany(Jurisdiction::class, 'jurisdiction_geographic_unit')->withTimestamps();
    }

    protected static function booted(): void
    {
        static::saving(function (self $unit): void {
            $unit->assertValidIdentity();
        });
        static::updating(function (self $unit): void {
            if ($unit->isDirty(['key', 'code', 'level', 'parent_id'])) {
                throw new LogicException('Canonical geographic identity and hierarchy are immutable.');
            }
        });
    }

    private function assertValidIdentity(): void
    {
        if (! preg_match('/^[a-z0-9-]+$/', $this->key)) {
            throw new LogicException('Geographic keys must be URL-safe.');
        }
        $parent = $this->parent_id ? self::query()->find($this->parent_id) : null;
        $valid = match ($this->level) {
            GeographicUnitLevel::Country => $parent === null,
            GeographicUnitLevel::Department => $parent?->level === GeographicUnitLevel::Country,
            GeographicUnitLevel::Municipality => $parent?->level === GeographicUnitLevel::Department,
        };
        if (! $valid) {
            throw new LogicException('Geographic hierarchy is invalid.');
        }
    }
}
