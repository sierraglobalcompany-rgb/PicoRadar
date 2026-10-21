<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Enums\GeographicUnitLevel;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CameraRegistryService
{
    /** The optional hook is a test-only transaction seam; no request can set it. */
    public function __construct(private readonly DatasetAuditLogger $audit, private readonly ?\Closure $failureHook = null) {}

    /**
     * $internalCameraId is reserved for trusted, server-computed identities
     * (the ANSV importer uses a fixed SHA-256-derived value). Never bind it
     * to a request field. Ordinary callers receive a server-generated ULID.
     */
    public function create(array $data, ?User $actor = null, ?string $internalCameraId = null): Camera
    {
        return DB::transaction(function () use ($data, $actor, $internalCameraId): Camera {
            $camera = new Camera;
            // Accept only fields declared as editable camera master data.
            // Never allow a caller to provide lifecycle, verification or audit fields.
            if (array_diff(array_keys($data), $camera->getFillable()) !== []) {
                throw new DomainException('Camera creation contains server-controlled fields.');
            }

            if ($internalCameraId !== null && ! preg_match('/^cam_[0-9a-f]{26}$/D', $internalCameraId)) {
                throw new DomainException('Trusted camera identity has an invalid format.');
            }

            // Serialize manual and CSV creates for this source. CSV Apply already
            // holds this source lock, so nested calls reuse the same transaction.
            CameraSource::query()->whereKey($data['source_id'] ?? null)->lockForUpdate()->firstOrFail();
            // Spatial duplicates are scoped to a jurisdiction, not a source.
            // Locking the jurisdiction serializes edits from other sources too.
            Jurisdiction::query()->whereKey($data['jurisdiction_id'] ?? null)->lockForUpdate()->firstOrFail();

            $camera->fill($data);
            $camera->forceFill([
                'camera_id' => $internalCameraId ?? 'cam_'.strtolower((string) Str::ulid()),
                'status' => CameraStatus::Draft,
                'created_by_id' => $actor?->id,
                'updated_by_id' => $actor?->id,
            ])->save();
            $this->assertCoverage($camera);
            $this->audit->log($actor, 'camera.created', $camera, $this->meta($camera));

            return $camera;
        });
    }

    public function submit(Camera $camera, ?User $actor = null): Camera
    {
        return $this->transition($camera, [CameraStatus::Draft, CameraStatus::Rejected], CameraStatus::InReview, 'camera.submitted', $actor, true);
    }

    public function updateDraft(Camera $camera, array $attributes, ?User $actor = null): Camera
    {
        return DB::transaction(function () use ($camera, $attributes, $actor): Camera {
            // Source-first lock order matches CSV Apply, including moves to a
            // different source from the manual editor. This also serializes
            // manual updates against the import preview/apply window.
            $sourceIds = array_unique([(int) $camera->source_id, (int) ($attributes['source_id'] ?? $camera->source_id)]);
            sort($sourceIds, SORT_NUMERIC);
            CameraSource::query()->whereKey($sourceIds)->orderBy('id')->lockForUpdate()->get();
            $jurisdictionIds = array_unique([
                (int) $camera->jurisdiction_id,
                (int) ($attributes['jurisdiction_id'] ?? $camera->jurisdiction_id),
            ]);
            sort($jurisdictionIds, SORT_NUMERIC);
            Jurisdiction::query()->whereKey($jurisdictionIds)->orderBy('id')->lockForUpdate()->get();
            $current = Camera::lockForUpdate()->findOrFail($camera->id);
            if (! in_array($current->status, [CameraStatus::Draft, CameraStatus::Rejected], true)) {
                throw new DomainException('Only draft or rejected cameras can edit master data. Reopen for correction first.');
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
        return $this->transition($camera, CameraStatus::InReview, CameraStatus::Draft, 'camera.withdrawn', $actor, true);
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
            $this->checkpoint('retire.after_mutation');
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
        $unit = $camera->relationLoaded('geographicUnit') ? $camera->geographicUnit : GeographicUnit::findOrFail($camera->geographic_unit_id);
        $camera->loadMissing('jurisdiction');
        $covered = $camera->jurisdiction->relationLoaded('geographicUnits')
            ? $camera->jurisdiction->geographicUnits->contains('id', $unit->id)
            : $camera->jurisdiction->geographicUnits()->whereKey($unit->id)->exists();
        if ($unit->level !== GeographicUnitLevel::Municipality || ! $covered) {
            throw new DomainException('Camera municipality must belong to jurisdiction coverage.');
        }
    }

    /** @param CameraStatus|list<CameraStatus> $from */
    private function transition(Camera $camera, CameraStatus|array $from, CameraStatus $to, string $event, ?User $actor, bool $noop = false, array $extra = []): Camera
    {
        return DB::transaction(function () use ($camera, $from, $to, $event, $actor, $noop, $extra): Camera {
            $current = Camera::lockForUpdate()->findOrFail($camera->id);
            if ($noop && $current->status === $to) {
                return $current;
            }
            $allowed = is_array($from) ? $from : [$from];
            if (! in_array($current->status, $allowed, true)) {
                throw new DomainException('Invalid camera state transition.');
            }
            $values = ['status' => $to];
            if ($to === CameraStatus::InReview) {
                $values['submitted_at'] = now();
            }
            $current->forceFill($values)->save();
            $this->checkpoint("{$event}.after_mutation");
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

    private function checkpoint(string $point): void
    {
        ($this->failureHook) ? ($this->failureHook)($point) : null;
    }
}
