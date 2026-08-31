<?php

namespace App\Console\Commands;

use App\Models\Camera;
use App\Services\CameraIntegrityAuditor;
use Illuminate\Console\Command;

class CameraIntegrityCommand extends Command
{
    protected $signature = 'picoradar:cameras:integrity {--json} {--fail-on-error} {--jurisdiction=}';

    protected $description = 'Audit camera registry integrity without modifying data.';

    public function handle(CameraIntegrityAuditor $auditor): int
    {
        $violations = [];
        Camera::query()->with(['source', 'jurisdiction.geographicUnits', 'geographicUnit'])->when($this->option('jurisdiction'), fn ($query, $key) => $query->whereHas('jurisdiction', fn ($jurisdiction) => $jurisdiction->where('key', $key)))->orderBy('id')->eachById(function (Camera $camera) use ($auditor, &$violations): void {
            $result = $auditor->assess($camera);
            if ($result['errors'] !== []) {
                $violations[] = $result;
            }
        });
        $payload = ['schema' => 'picoradar.camera-integrity.v1', 'violations' => $violations, 'errorCount' => count($violations)];
        if ($this->option('json')) {
            $this->line(json_encode($payload, JSON_THROW_ON_ERROR));
        } else {
            $this->table(['camera_id', 'errors'], collect($violations)->map(fn ($row) => [$row['cameraId'], implode(', ', $row['errors'])])->all());
        }

        return $this->option('fail-on-error') && $violations !== [] ? self::FAILURE : self::SUCCESS;
    }
}
