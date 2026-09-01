<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraImportRun;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use DomainException;
use Illuminate\Support\Facades\Storage;

class CameraImportPreApplyValidator
{
    public function __construct(private readonly CameraDuplicateDetector $duplicates, private readonly CameraRegistryService $registry) {}

    public function assertSafe(CameraImportRun $run, CameraImportItem $item): void
    {
        if (! Storage::disk('local')->exists($run->stored_path) || hash_file('sha256', Storage::disk('local')->path($run->stored_path)) !== $run->file_sha256) {
            throw new DomainException('file_hash_mismatch');
        }
        $source = $run->source()->firstOrFail();
        if (! $source->is_active || ! $source->verified_at) {
            throw new DomainException('source_not_operational');
        }
        $payload = $item->normalized_payload;
        $jurisdiction = $payload['region_code'] ? Jurisdiction::where('key', $payload['region_code'])->first() : $run->defaultJurisdiction;
        $municipality = $payload['municipality_code'] ? GeographicUnit::where('code', $payload['municipality_code'])->first() : GeographicUnit::where('normalized_name', strtolower((string) $payload['municipality_name']))->first();
        if (! $jurisdiction || ! $jurisdiction->enabled || ! $municipality || ! $jurisdiction->geographicUnits()->whereKey($municipality->id)->exists()) {
            throw new DomainException('geography_changed');
        }
        if ($item->classification === 'update_ready') {
            $camera = Camera::find($item->matched_camera_id);
            if (! $camera || ! in_array($camera->status, [CameraStatus::Draft, CameraStatus::Rejected], true)) {
                throw new DomainException('camera_state_changed');
            }
        }
        if ($item->classification === 'create_ready') {
            if (Camera::where('source_id', $run->source_id)->where('external_id', $payload['external_id'])->exists()) {
                throw new DomainException('external_id_claimed');
            }
            $seed = new Camera(['id' => 0, 'jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $run->source_id, 'lat' => $payload['lat'], 'lon' => $payload['lon'], 'type' => $payload['type']]);
            if (($item->resolution['action'] ?? null) !== 'allow_create') {
                $scan = $this->duplicates->scan($seed);
                if ($scan['scanCapped']) {
                    throw new DomainException('duplicate_scan_capped');
                }
                if ($scan['candidates']) {
                    throw new DomainException('duplicate_candidate');
                }
            }
        }
    }
}
