<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

final class CameraCsvImport extends Model
{
    protected $fillable = [
        'source_id', 'jurisdiction_id', 'created_by_id', 'applied_by_id',
        'mode', 'status', 'original_path', 'original_sha256',
        'analysis_path', 'analysis_sha256', 'applied_selection_sha256',
        'counts', 'row_count', 'applied_at',
    ];

    protected function casts(): array
    {
        return ['counts' => 'array', 'applied_at' => 'datetime'];
    }

    public function source(): BelongsTo
    {
        return $this->belongsTo(CameraSource::class, 'source_id');
    }

    public function jurisdiction(): BelongsTo
    {
        return $this->belongsTo(Jurisdiction::class, 'jurisdiction_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_id');
    }
}
