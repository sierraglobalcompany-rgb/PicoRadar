<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Enums\GeographicUnitLevel;
use App\Models\Camera;
use App\Models\GeographicUnit;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CameraRegistryService
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    public function create(array $data, ?User $actor = null): Camera
    {
        return DB::transaction(function () use ($data, $actor): Camera {
            $camera = new Camera;
            $camera->forceFill($data + ['camera_id' => 'cam_'.strtolower((string) Str::ulid()), 'status' => CameraStatus::Draft, 'created_by_id' => $actor?->id, 'updated_by_id' => $actor?->id])->save();
            $this->assertCoverage($camera);
            $this->audit->log($actor, 'camera.created', $camera, $this->meta($camera));

            return $camera;
        });
    }

    public function submit(Camera $camera, ?User $actor = null): Camera
    {
        return $this->transition($camera, CameraStatus::Draft, CameraStatus::InReview, 'camera.submitted', $actor);
    }

    public function updateDraft(Camera $camera, array $attributes, ?User $actor = null): Camera
    {
        return DB::transaction(function () use ($camera, $attributes, $actor): Camera {
            $current = Camera::lockForUpdate()->findOrFail($camera->id);
            if ($current->status !== CameraStatus::Draft) {
                throw new DomainException('Only draft cameras can edit master data. Reopen for correction first.');
            }
            $current->fill($attributes);
            $current->forceFill(['updated_by_id' => $actor?->id]);
            $this->assertCoverage($current);
            $current->save();
            $this->audit->log($actor, 'camera.updated', $current, $this->meta($current));

            return $current;
        });
    }

    public function withdraw(Camera $camera, ?User $actor = null): Camera
    {
        return $this->transition($camera, CameraStatus::InReview, CameraStatus::Draft, 'camera.withdrawn', $actor);
    }

    public function deactivate(Camera $camera, string $reason, ?User $actor = null): Camera
    {
        return $this->transition($camera, CameraStatus::Active, CameraStatus::Inactive, 'camera.deactivated', $actor, true, $this->reason($reason));
    }

    public function retire(Camera $camera, string $reason, ?User $actor = null): Camera
    {
        return DB::transaction(function () use ($camera, $reason, $actor): Camera {
            $metadata = $this->reason($reason);
            $current = Camera::lockForUpdate()->findOrFail($camera->id);
            if ($current->status === CameraStatus::Retired) {
                return $current;
            }
            if (! in_array($current->status, [CameraStatus::Active, CameraStatus::Inactive], true)) {
                throw new DomainException('Camera cannot retire from this state.');
            }
            $current->forceFill(['status' => CameraStatus::Retired, 'retired_at' => now(), 'retired_by_id' => $actor?->id])->save();
            $this->audit->log($actor, 'camera.retired', $current, $this->meta($current) + $metadata);

            return $current;
        });
    }

    public function reopen(Camera $camera, string $reason, ?User $actor = null): Camera
    {
        return DB::transaction(function () use ($camera, $reason, $actor): Camera {
            $metadata = $this->reason($reason);
            $current = Camera::lockForUpdate()->findOrFail($camera->id);
            if (! in_array($current->status, [CameraStatus::Verified, CameraStatus::Active, CameraStatus::Inactive], true)) {
                throw new DomainException('Camera cannot reopen from this state.');
            }
            $current->forceFill(['status' => CameraStatus::Draft, 'verified_at' => null, 'verified_by_id' => null, 'verification_fingerprint' => null, 'speed_limit_verified' => false, 'speed_limit_verified_at' => null, 'speed_limit_verified_by_id' => null])->save();
            $this->audit->log($actor, 'camera.reopened', $current, $this->meta($current) + $metadata);

            return $current;
        });
    }

    public function assertCoverage(Camera $camera): void
    {
        $unit = GeographicUnit::findOrFail($camera->geographic_unit_id);
        $camera->loadMissing('jurisdiction');
        if ($unit->level !== GeographicUnitLevel::Municipality || ! $camera->jurisdiction->geographicUnits()->whereKey($unit->id)->exists()) {
            throw new DomainException('Camera municipality must belong to jurisdiction coverage.');
        }
    }

    private function transition(Camera $camera, CameraStatus $from, CameraStatus $to, string $event, ?User $actor, bool $noop = false, array $extra = []): Camera
    {
        return DB::transaction(function () use ($camera, $from, $to, $event, $actor, $noop, $extra): Camera {
            $current = Camera::lockForUpdate()->findOrFail($camera->id);
            if ($noop && $current->status === $to) {
                return $current;
            }
            if ($current->status !== $from) {
                throw new DomainException('Invalid camera state transition.');
            }
            $values = ['status' => $to];
            if ($to === CameraStatus::InReview) {
                $values['submitted_at'] = now();
            }
            $current->forceFill($values)->save();
            $this->audit->log($actor, $event, $current, $this->meta($current) + $extra);

            return $current;
        });
    }

    private function reason(string $reason): array
    {
        $reason = trim(strip_tags($reason));
        if ($reason === '' || mb_strlen($reason) > 1000) {
            throw new DomainException('A non-empty reason of at most 1000 characters is required.');
        }

        return ['reason' => $reason];
    }

    private function meta(Camera $camera): array
    {
        $camera->loadMissing(['source', 'jurisdiction', 'geographicUnit']);

        return ['cameraId' => $camera->camera_id, 'sourceKey' => $camera->source->key, 'jurisdictionKey' => $camera->jurisdiction->key, 'geographicUnitCode' => $camera->geographicUnit->code];
    }
}
