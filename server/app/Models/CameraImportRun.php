<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

class CameraImportRun extends Model
{
    public const SCHEMA_VERSION = 1;

    public const IMPORTER_VERSION = 'camera-importer-v1';

    public const NORMALIZATION_VERSION = 'camera-normalization-v1';

    protected $guarded = [];

    protected function casts(): array
    {
        return ['source_snapshot' => 'array', 'parser_options' => 'array', 'column_mapping' => 'array', 'error_summary' => 'array', 'warning_summary' => 'array', 'analyzed_at' => 'datetime', 'apply_started_at' => 'datetime', 'apply_finished_at' => 'datetime'];
    }

    public function source(): BelongsTo
    {
        return $this->belongsTo(CameraSource::class);
    }

    public function defaultJurisdiction(): BelongsTo
    {
        return $this->belongsTo(Jurisdiction::class, 'default_jurisdiction_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(CameraImportItem::class, 'run_id');
    }

    protected static function booted(): void
    {
        static::updating(function (self $run): void {
            if ($run->getOriginal('status') !== 'uploaded' && $run->isDirty(['source_id', 'default_jurisdiction_id', 'format', 'import_mode', 'stored_path', 'file_sha256', 'profile_key', 'profile_sha256'])) {
                throw new LogicException('Import input is immutable after analysis starts.');
            }
        });
        static::deleting(fn () => throw new LogicException('Import history cannot be hard deleted.'));
    }
}
