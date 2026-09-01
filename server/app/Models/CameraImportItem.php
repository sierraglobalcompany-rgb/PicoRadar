<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

class CameraImportItem extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['normalized_payload' => 'array', 'duplicate_candidates' => 'array', 'errors' => 'array', 'warnings' => 'array', 'resolution' => 'array', 'duplicate_scan_capped' => 'boolean', 'resolved_at' => 'datetime', 'applied_at' => 'datetime'];
    }

    public function run(): BelongsTo
    {
        return $this->belongsTo(CameraImportRun::class);
    }

    public function matchedCamera(): BelongsTo
    {
        return $this->belongsTo(Camera::class, 'matched_camera_id');
    }

    public function appliedCamera(): BelongsTo
    {
        return $this->belongsTo(Camera::class, 'applied_camera_id');
    }

    protected static function booted(): void
    {
        static::deleting(fn () => throw new LogicException('Import item history cannot be hard deleted.'));
    }
}
