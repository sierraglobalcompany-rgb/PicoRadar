<?php

namespace App\Models;

use App\Enums\CameraStatus;
use App\Enums\CameraType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

class Camera extends Model
{
    use HasFactory;

    protected $fillable = ['jurisdiction_id', 'geographic_unit_id', 'source_id', 'external_id', 'name', 'lat', 'lon', 'type', 'direction', 'bearing', 'corridor', 'speed_limit', 'notes', 'operation_status', 'traffic_authority', 'installation_type', 'equipment_name', 'raw_infraction_codes', 'raw_speed', 'operation_started_on', 'operation_initial_ends_on', 'operation_extension_ends_on', 'source_snapshot_sha', 'source_fetched_at'];

    protected function casts(): array
    {
        return ['type' => CameraType::class, 'status' => CameraStatus::class, 'speed_limit_verified' => 'boolean', 'submitted_at' => 'datetime', 'verified_at' => 'datetime', 'speed_limit_verified_at' => 'datetime', 'retired_at' => 'datetime', 'raw_infraction_codes' => 'array', 'operation_started_on' => 'date', 'operation_initial_ends_on' => 'date', 'operation_extension_ends_on' => 'date', 'source_fetched_at' => 'datetime'];
    }

    public function source(): BelongsTo
    {
        return $this->belongsTo(CameraSource::class);
    }

    public function jurisdiction(): BelongsTo
    {
        return $this->belongsTo(Jurisdiction::class);
    }

    public function geographicUnit(): BelongsTo
    {
        return $this->belongsTo(GeographicUnit::class);
    }

    public function verifications(): HasMany
    {
        return $this->hasMany(CameraVerification::class);
    }

    public function isOverspeedEligible(): bool
    {
        return $this->status === CameraStatus::Active && $this->type->supportsSpeed() && $this->speed_limit !== null && $this->speed_limit_verified && $this->speed_limit_verified_at !== null;
    }

    protected static function booted(): void
    {
        static::saving(function (self $c): void {
            if ($c->lat < -90 || $c->lat > 90 || $c->lon < -180 || $c->lon > 180 || ($c->bearing !== null && ($c->bearing < 0 || $c->bearing > 359)) || ($c->speed_limit !== null && ($c->speed_limit < 1 || $c->speed_limit > 200)) || ($c->speed_limit_verified && ($c->speed_limit === null || ! $c->type->supportsSpeed()))) {
                throw new LogicException('Camera operational invariants are invalid.');
            }if ($c->exists && $c->isDirty('camera_id')) {
                throw new LogicException('Camera IDs are immutable.');
            }if ($c->exists && $c->getOriginal('status') === 'retired') {
                throw new LogicException('Retired cameras are terminal.');
            }if ($c->exists && in_array($c->getOriginal('status'), ['verified', 'active', 'inactive'], true) && $c->isDirty(['lat', 'lon', 'jurisdiction_id', 'geographic_unit_id', 'source_id', 'type', 'direction', 'bearing', 'corridor'])) {
                throw new LogicException('Reopen camera for correction first.');
            }if ($c->exists && $c->isDirty('speed_limit')) {
                $c->speed_limit_verified = false;
                $c->speed_limit_verified_at = null;
                $c->speed_limit_verified_by_id = null;
            }
        });
        static::deleting(fn () => throw new LogicException('Cameras are immutable operational history and cannot be hard deleted.'));
    }
}
