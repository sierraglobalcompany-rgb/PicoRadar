<?php

namespace App\Services;

use App\Models\CameraImportRun;
use Illuminate\Support\Facades\Storage;

/** Read-only evidence verifier for a historical import run. */
class CameraImportReproducibilityVerifier
{
    public function __construct(private readonly CameraImportProfileValidator $profiles) {}

    /** @return array{schema:string,status:string,runId:int} */
    public function verify(CameraImportRun $run): array
    {
        $disk = Storage::disk('local');
        if (! $disk->exists($run->stored_path) || hash_file('sha256', $disk->path($run->stored_path)) !== $run->file_sha256) {
            return $this->result($run, 'file_changed');
        }
        try {
            $profileMatches = is_string($run->profile_key)
                && is_string($run->profile_sha256)
                && hash_equals($run->profile_sha256, $this->profiles->hash($run->profile_key));
        } catch (\Throwable) {
            $profileMatches = false;
        }
        if (! $profileMatches) {
            return $this->result($run, 'profile_changed');
        }
        $source = $run->source()->first();
        $snapshot = $source ? [
            'source_id' => $source->id,
            'key' => $source->key,
            'authority' => $source->authority,
            'url' => $source->url,
            'source_type' => $source->source_type->value,
            'is_active' => (bool) $source->is_active,
            'verified_at' => $source->verified_at?->toISOString(),
        ] : null;
        if ($snapshot !== $run->source_snapshot) {
            return $this->result($run, 'source_changed');
        }
        if ($run->analysis_schema_version !== CameraImportRun::SCHEMA_VERSION
            || $run->importer_version !== CameraImportRun::IMPORTER_VERSION
            || $run->normalization_version !== CameraImportRun::NORMALIZATION_VERSION) {
            return $this->result($run, 'unsupported_old_version');
        }

        return $this->result($run, 'reproducible');
    }

    /** @return array{schema:string,status:string,runId:int} */
    private function result(CameraImportRun $run, string $status): array
    {
        return ['schema' => 'picoradar.camera-import-reproducibility.v1', 'status' => $status, 'runId' => $run->id];
    }
}
