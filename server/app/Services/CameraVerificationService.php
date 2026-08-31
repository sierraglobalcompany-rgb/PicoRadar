<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Enums\CameraVerificationDecision;
use App\Models\Camera;
use App\Models\CameraVerification;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;

class CameraVerificationService
{
    public function __construct(private readonly DatasetAuditLogger $audit, private readonly CameraRegistryService $registry) {}

    public function fingerprint(Camera $camera): string
    {
        return hash('sha256', json_encode([$camera->jurisdiction_id, $camera->geographic_unit_id, $camera->source_id, $camera->external_id, $camera->lat, $camera->lon, $camera->type->value, $camera->direction, $camera->bearing, $camera->corridor], JSON_THROW_ON_ERROR));
    }

    public function verify(Camera $camera, bool $speedVerified, ?User $actor = null, string $notes = ''): Camera
    {
        return DB::transaction(function () use ($camera, $speedVerified, $actor, $notes): Camera {
            $current = Camera::lockForUpdate()->with(['source', 'jurisdiction', 'geographicUnit'])->findOrFail($camera->id);
            if ($current->status !== CameraStatus::InReview) {
                throw new DomainException('Only in-review cameras can verify.');
            }
            if (! $current->source->is_active || ! $current->source->verified_at) {
                throw new DomainException('Camera source is not operationally verified.');
            }
            $this->registry->assertCoverage($current);
            if ($speedVerified && ($current->speed_limit === null || ! $current->type->supportsSpeed())) {
                throw new DomainException('Speed limit cannot verify.');
            }
            $fingerprint = $this->fingerprint($current);
            $verification = CameraVerification::create(['camera_id' => $current->id, 'reviewer_id' => $actor?->id, 'decision' => CameraVerificationDecision::Verified, 'fingerprint' => $fingerprint, 'source_id' => $current->source_id, 'source_url_snapshot' => $current->source->url, 'speed_limit_snapshot' => $current->speed_limit, 'speed_limit_verified' => $speedVerified, 'notes' => trim(strip_tags($notes))]);
            $current->forceFill(['status' => CameraStatus::Verified, 'verified_at' => now(), 'verified_by_id' => $actor?->id, 'verification_fingerprint' => $fingerprint, 'speed_limit_verified' => $speedVerified, 'speed_limit_verified_at' => $speedVerified ? now() : null, 'speed_limit_verified_by_id' => $speedVerified ? $actor?->id : null])->save();
            $this->audit->log($actor, 'camera.verified', $current, ['cameraId' => $current->camera_id, 'verificationId' => $verification->id, 'speedVerified' => $speedVerified]);

            return $current;
        });
    }

    public function reject(Camera $camera, string $reason, ?User $actor = null): Camera
    {
        $reason = $this->reason($reason);

        return DB::transaction(function () use ($camera, $reason, $actor): Camera {
            $current = Camera::lockForUpdate()->with('source')->findOrFail($camera->id);
            if ($current->status !== CameraStatus::InReview) {
                throw new DomainException('Only in-review cameras can reject.');
            }
            $verification = CameraVerification::create(['camera_id' => $current->id, 'reviewer_id' => $actor?->id, 'decision' => CameraVerificationDecision::Rejected, 'fingerprint' => $this->fingerprint($current), 'source_id' => $current->source_id, 'source_url_snapshot' => $current->source->url, 'speed_limit_snapshot' => $current->speed_limit, 'speed_limit_verified' => false, 'notes' => $reason]);
            $current->forceFill(['status' => CameraStatus::Rejected])->save();
            $this->audit->log($actor, 'camera.rejected', $current, ['cameraId' => $current->camera_id, 'verificationId' => $verification->id, 'reason' => $reason]);

            return $current;
        });
    }

    public function activate(Camera $camera, ?User $actor = null): Camera
    {
        return DB::transaction(function () use ($camera, $actor): Camera {
            $current = Camera::lockForUpdate()->with(['source', 'jurisdiction', 'geographicUnit'])->findOrFail($camera->id);
            if ($current->status === CameraStatus::Active) {
                return $current;
            }
            if (! in_array($current->status, [CameraStatus::Verified, CameraStatus::Inactive], true) || ! $current->source->is_active || ! $current->source->verified_at || ! $current->jurisdiction->enabled || ! $current->verified_at || ! hash_equals($this->fingerprint($current), (string) $current->verification_fingerprint)) {
                throw new DomainException('Camera is not eligible for activation.');
            }
            $this->registry->assertCoverage($current);
            $current->forceFill(['status' => CameraStatus::Active])->save();
            $this->audit->log($actor, 'camera.activated', $current, ['cameraId' => $current->camera_id]);

            return $current;
        });
    }

    private function reason(string $reason): string
    {
        $reason = trim(strip_tags($reason));
        if ($reason === '' || mb_strlen($reason) > 1000) {
            throw new DomainException('A non-empty reason of at most 1000 characters is required.');
        }

        return $reason;
    }
}
