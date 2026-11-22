<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['sha256', 'original_name', 'format', 'private_path', 'status', 'row_count', 'report', 'created_by_id', 'confirmed_by_id', 'confirmed_at', 'expires_at'])]
class ServiceProviderImport extends Model
{
    protected function casts(): array
    {
        return ['report' => 'array', 'confirmed_at' => 'datetime', 'expires_at' => 'datetime'];
    }

    public function rows(): HasMany
    {
        return $this->hasMany(ServiceProviderImportRow::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_id');
    }
}