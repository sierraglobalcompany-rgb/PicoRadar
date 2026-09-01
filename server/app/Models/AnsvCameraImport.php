<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['source_id', 'snapshot_sha', 'source_url', 'source_fetched_at', 'row_count', 'master_imported_count', 'active_candidate_count', 'status_counts', 'report'])]
class AnsvCameraImport extends Model
{
    protected function casts(): array
    {
        return ['source_fetched_at' => 'datetime', 'status_counts' => 'array', 'report' => 'array'];
    }

    public function source(): BelongsTo
    {
        return $this->belongsTo(CameraSource::class, 'source_id');
    }

    public function rows(): HasMany
    {
        return $this->hasMany(AnsvCameraImportRow::class);
    }
}
