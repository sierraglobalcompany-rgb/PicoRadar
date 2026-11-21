<?php

namespace App\Services;

use App\Models\CameraSource;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class CameraSourceService
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    public function create(array $attributes, ?User $actor = null): CameraSource
    {
        return DB::transaction(function () use ($attributes, $actor): CameraSource {
            $source = CameraSource::query()->create($attributes);
            $this->audit->log($actor, 'camera_source.created', $source, $this->metadata($source));

            return $source;
        });
    }

    public function update(CameraSource $source, array $attributes, ?User $actor = null): CameraSource
    {
        return DB::transaction(function () use ($source, $attributes, $actor): CameraSource {
            $current = CameraSource::lockForUpdate()->findOrFail($source->id);
            $current->fill($attributes);
            if (! $current->isDirty()) {
                return $current;
            }
            $criticalChanged = $current->isDirty(['authority', 'url', 'source_type']);
            $wasActive = (bool) $current->getOriginal('is_active');
            if ($criticalChanged) {
                $current->verified_at = null;
            }
            $current->save();
            $event = $wasActive !== $current->is_active ? ($current->is_active ? 'camera_source.reactivated' : 'camera_source.deactivated') : 'camera_source.updated';
            $this->audit->log($actor, $event, $current, $this->metadata($current));

            return $current;
        });
    }

    /** @return array<string, scalar|null> */
    private function metadata(CameraSource $source): array
    {
        return ['sourceKey' => $source->key, 'sourceType' => $source->source_type->value, 'authority' => $source->authority, 'active' => $source->is_active, 'verified' => $source->verified_at !== null];
    }
}
