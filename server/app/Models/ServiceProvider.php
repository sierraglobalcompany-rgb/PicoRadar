<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

#[Fillable([
    'category',
    'department_code',
    'municipality_code',
    'name',
    'address',
    'latitude',
    'longitude',
    'source_url',
    'verified_at',
    'valid_until',
    'status',
    'contact_url',
])]
class ServiceProvider extends Model
{
    public const CATEGORIES = ['cda', 'soat', 'workshop', 'tow', 'ally'];

    public const STATUSES = ['draft', 'published', 'disabled'];

    protected function casts(): array
    {
        return [
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
            'verified_at' => 'datetime',
            'valid_until' => 'date',
        ];
    }

    public function department(): BelongsTo
    {
        return $this->belongsTo(GeographicUnit::class, 'department_code', 'code')
            ->where('level', 'department');
    }

    public function municipality(): BelongsTo
    {
        return $this->belongsTo(GeographicUnit::class, 'municipality_code', 'code')
            ->where('level', 'municipality');
    }

    public function hasCurrentSourceEvidence(?Carbon $asOf = null): bool
    {
        $asOf ??= now();
        $url = parse_url((string) $this->source_url);

        if (
            ! is_array($url)
            || strtolower((string) ($url['scheme'] ?? '')) !== 'https'
            || trim((string) ($url['host'] ?? '')) === ''
            || isset($url['user'])
            || isset($url['pass'])
            || $this->verified_at === null
            || $this->valid_until === null
            || $this->verified_at->isAfter($asOf)
        ) {
            return false;
        }

        return $this->valid_until->toDateString() >= $asOf->toDateString();
    }

    /** @return array<string, mixed>|null */
    public function toPublishedDatasetRecord(?Carbon $asOf = null): ?array
    {
        if ($this->status !== 'published' || ! $this->hasCurrentSourceEvidence($asOf)) {
            return null;
        }

        return [
            'category' => $this->category,
            'departmentCode' => $this->department_code,
            'municipalityCode' => $this->municipality_code,
            'name' => $this->name,
            'address' => $this->address,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'sourceUrl' => $this->source_url,
            'verifiedAt' => $this->verified_at?->toAtomString(),
            'validUntil' => $this->valid_until?->toDateString(),
            'contactUrl' => $this->contact_url,
        ];
    }
}
