<?php

namespace App\Models;

use App\Enums\CameraVerificationDecision;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use LogicException;

class CameraVerification extends Model
{
    use HasFactory;

    public const UPDATED_AT = null;

    protected $fillable = ['camera_id', 'reviewer_id', 'decision', 'fingerprint', 'source_id', 'source_url_snapshot', 'speed_limit_snapshot', 'speed_limit_verified', 'notes'];

    protected function casts(): array
    {
        return ['decision' => CameraVerificationDecision::class, 'speed_limit_verified' => 'boolean', 'created_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Camera verifications are append-only.'));
        static::deleting(fn () => throw new LogicException('Camera verifications are append-only.'));
    }
}
