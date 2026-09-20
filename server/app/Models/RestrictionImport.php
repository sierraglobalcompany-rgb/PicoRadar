<?php

namespace App\Models;

use App\Enums\RestrictionImportStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['sha256', 'original_name', 'format', 'private_path', 'sheet', 'status', 'row_count', 'valid_count', 'invalid_count', 'excluded_count', 'report', 'created_by_id', 'confirmed_by_id', 'analyzed_at', 'confirmed_at'])]
class RestrictionImport extends Model
{
    protected function casts(): array
    {
        return [
            'status' => RestrictionImportStatus::class,
            'report' => 'array',
            'analyzed_at' => 'datetime',
            'confirmed_at' => 'datetime',
        ];
    }

    public function rows(): HasMany
    {
        return $this->hasMany(RestrictionImportRow::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_id');
    }
}
