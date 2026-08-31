<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

#[Fillable(['key', 'title', 'schema_version', 'enabled', 'current_version'])]
class Dataset extends Model
{
    protected function casts(): array
    {
        return ['schema_version' => 'integer', 'enabled' => 'boolean'];
    }

    public function releases(): HasMany
    {
        return $this->hasMany(DatasetRelease::class);
    }

    public function sources(): HasMany
    {
        return $this->hasMany(DatasetSource::class);
    }

    protected static function booted(): void
    {
        static::updating(function (self $dataset): void {
            if ($dataset->isDirty(['key', 'schema_version']) && $dataset->releases()->exists()) {
                throw new LogicException('Dataset key and schema version are immutable after releases exist.');
            }
        });
    }
}
