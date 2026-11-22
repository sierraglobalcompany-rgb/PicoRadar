<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['service_provider_import_id', 'row_number', 'status', 'publishable', 'service_provider_id', 'normalized', 'errors', 'raw'])]
class ServiceProviderImportRow extends Model
{
    protected function casts(): array
    {
        return ['publishable' => 'boolean', 'normalized' => 'array', 'errors' => 'array', 'raw' => 'array'];
    }

    public function import(): BelongsTo
    {
        return $this->belongsTo(ServiceProviderImport::class, 'service_provider_import_id');
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(ServiceProvider::class, 'service_provider_id');
    }
}