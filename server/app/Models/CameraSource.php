<?php

namespace App\Models;

use App\Enums\CameraSourceType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

class CameraSource extends Model
{
    use HasFactory;

    protected $fillable = ['key', 'title', 'authority', 'url', 'source_type', 'is_active', 'verified_at', 'notes'];

    protected function casts(): array
    {
        return ['source_type' => CameraSourceType::class, 'is_active' => 'boolean', 'verified_at' => 'datetime'];
    }

    public function cameras(): HasMany
    {
        return $this->hasMany(Camera::class, 'source_id');
    }

    protected static function booted(): void
    {
        static::saving(function (self $s): void {
            if (! preg_match('/^[a-z0-9_-]+$/', $s->key) || ! filter_var($s->url, FILTER_VALIDATE_URL) || ! in_array(parse_url($s->url, PHP_URL_SCHEME), ['http', 'https'], true) || ($s->verified_at && $s->verified_at->isFuture())) {
                throw new LogicException('Camera source identity, URL, or verification date is invalid.');
            }
        });
        static::updating(function (self $s): void {
            if ($s->isDirty('key')) {
                throw new LogicException('Camera source keys are immutable.');
            }if ($s->isDirty(['authority', 'url', 'source_type']) && $s->cameras()->where('status', 'active')->exists()) {
                throw new LogicException('Critical source fields cannot change while active cameras depend on it.');
            }if ($s->isDirty('is_active') && ! $s->is_active && $s->cameras()->where('status', 'active')->exists()) {
                throw new LogicException('Deactivate active cameras before their source.');
            }
        });
        static::deleting(function (self $s): void {
            if ($s->cameras()->exists()) {
                throw new LogicException('Camera sources with history cannot be hard deleted.');
            }
        });
    }
}
