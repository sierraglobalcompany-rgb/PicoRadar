<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['restriction_import_id', 'row_number', 'jurisdiction_id', 'state', 'publishable', 'normalized', 'errors', 'raw'])]
class RestrictionImportRow extends Model
{
    protected function casts(): array
    {
        return ['publishable' => 'boolean', 'normalized' => 'array', 'errors' => 'array', 'raw' => 'array'];
    }

    public function import(): BelongsTo
    {
        return $this->belongsTo(RestrictionImport::class, 'restriction_import_id');
    }

    public function jurisdiction(): BelongsTo
    {
        return $this->belongsTo(Jurisdiction::class);
    }
}
