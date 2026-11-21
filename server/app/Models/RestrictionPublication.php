<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['dataset_release_id', 'action', 'base_publication_revision', 'result_publication_revision', 'actor_id', 'summary'])]
class RestrictionPublication extends Model
{
    protected function casts(): array
    {
        return ['summary' => 'array'];
    }

    public function datasetRelease(): BelongsTo
    {
        return $this->belongsTo(DatasetRelease::class);
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(RestrictionPublicationItem::class);
    }
}
