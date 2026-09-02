<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['source_id', 'snapshot_sha', 'source_url', 'source_fetched_at', 'status', 'analyzed_at', 'approved_at', 'approved_by_id', 'rejected_at', 'rejected_by_id', 'review_notes', 'row_count', 'master_imported_count', 'active_candidate_count', 'status_counts', 'report'])]
class AnsvCameraImport extends Model
{
    protected function casts(): array
    {
        return ['source_fetched_at' => 'datetime', 'analyzed_at' => 'datetime', 'approved_at' => 'datetime', 'rejected_at' => 'datetime', 'status_counts' => 'array', 'report' => 'array'];
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
