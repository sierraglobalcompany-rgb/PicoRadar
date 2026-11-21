<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Models\Camera;

class CameraContractReadinessService
{
    public function __construct(private readonly CameraRegistryService $registry, private readonly CameraVerificationService $verification) {}

    /** @return array{readyForFutureDataset: bool, reasons: list<string>} */
    public function assess(Camera $camera): array
    {
        $camera->loadMissing(['source', 'jurisdiction', 'geographicUnit', 'jurisdiction.primaryGeographicUnit']);
        $reasons = [];
        if ($camera->status !== CameraStatus::Active) {
            $reasons[] = 'not_active';
        }
        if (! preg_match('/^cam_[0-9a-z]+$/', $camera->camera_id)) {
            $reasons[] = 'camera_id';
        }
        if (! $camera->jurisdiction?->enabled || ! $camera->jurisdiction?->primaryGeographicUnit) {
            $reasons[] = 'jurisdiction';
        }
        if (! $camera->source?->is_active || ! $camera->source?->verified_at) {
            $reasons[] = 'source';
        }
        if (! $camera->verified_at || ! $camera->verification_fingerprint) {
            $reasons[] = 'verification';
        } elseif (! hash_equals($this->verification->fingerprint($camera), $camera->verification_fingerprint)) {
            $reasons[] = 'fingerprint';
        }
        if ((float) $camera->lat < -90 || (float) $camera->lat > 90 || (float) $camera->lon < -180 || (float) $camera->lon > 180) {
            $reasons[] = 'coordinates';
        }
        if ($camera->speed_limit_verified && ($camera->speed_limit === null || ! $camera->type->supportsSpeed() || ! $camera->speed_limit_verified_at)) {
            $reasons[] = 'speed_invariant';
        }
        try {
            $this->registry->assertCoverage($camera);
        } catch (\Throwable) {
            $reasons[] = 'coverage';
        }

        return ['readyForFutureDataset' => $reasons === [], 'reasons' => array_values(array_unique($reasons))];
    }
}
