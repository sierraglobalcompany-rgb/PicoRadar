<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Models\Camera;

class CameraIntegrityAuditor
{
    public function __construct(private readonly CameraRegistryService $registry, private readonly CameraVerificationService $verification) {}

    /** @return array{cameraId: string, errors: list<string>} */
    public function assess(Camera $camera): array
    {
        $camera->loadMissing(['source', 'jurisdiction', 'geographicUnit']);
        $errors = [];
        $status = $camera->status;
        if (! preg_match('/^cam_[0-9a-z]+$/', $camera->camera_id)) {
            $errors[] = 'camera_id';
        }
        if (! $camera->source || ! filter_var($camera->source->url, FILTER_VALIDATE_URL)) {
            $errors[] = 'source';
        }
        if (in_array($status, [CameraStatus::Verified, CameraStatus::Active, CameraStatus::Inactive], true) && (! $camera->source || ! $camera->source->is_active || ! $camera->source->verified_at)) {
            $errors[] = 'source_state';
        }
        try {
            $this->registry->assertCoverage($camera);
        } catch (\Throwable) {
            $errors[] = 'coverage';
        }
        if ((float) $camera->lat < -90 || (float) $camera->lat > 90 || (float) $camera->lon < -180 || (float) $camera->lon > 180) {
            $errors[] = 'coordinates';
        }
        if ($camera->speed_limit_verified && ($camera->speed_limit === null || ! $camera->type->supportsSpeed())) {
            $errors[] = 'speed_verification';
        }
        if ($camera->speed_limit !== null && ((int) $camera->speed_limit < 1 || (int) $camera->speed_limit > 200)) {
            $errors[] = 'speed_limit';
        }
        if (in_array($status, [CameraStatus::Draft, CameraStatus::Rejected], true) && $camera->verified_at) {
            $errors[] = 'unexpected_verified_at';
        }
        if ($status === CameraStatus::InReview && ! $camera->submitted_at) {
            $errors[] = 'missing_submitted_at';
        }
        if (in_array($status, [CameraStatus::Verified, CameraStatus::Active, CameraStatus::Inactive], true) && ! $camera->verified_at) {
            $errors[] = 'missing_verified_at';
        }
        if ($status === CameraStatus::Retired && ! $camera->retired_at) {
            $errors[] = 'missing_retired_at';
        }
        if ($status !== CameraStatus::Retired && $camera->retired_at) {
            $errors[] = 'unexpected_retired_at';
        }
        if ($camera->verification_fingerprint && ! hash_equals($this->verification->fingerprint($camera), $camera->verification_fingerprint)) {
            $errors[] = 'fingerprint';
        }
        if ($status === CameraStatus::Active && (! $camera->verified_at || ! $camera->verification_fingerprint || ! $camera->jurisdiction?->enabled)) {
            $errors[] = 'active_requirements';
        }

        return ['cameraId' => $camera->camera_id, 'errors' => array_values(array_unique($errors))];
    }
}
