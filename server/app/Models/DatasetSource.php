<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['dataset_id', 'title', 'authority', 'url', 'verified_at', 'valid_from', 'valid_until', 'notes', 'is_active'])]
class DatasetSource extends Model
{
    protected $table = 'sources';

    protected function casts(): array
    {
        return ['verified_at' => 'datetime', 'valid_from' => 'datetime', 'valid_until' => 'datetime', 'is_active' => 'boolean'];
    }

    public function dataset(): BelongsTo
    {
        return $this->belongsTo(Dataset::class);
    }
}
