<?php

namespace App\Console\Commands;

use App\Models\CameraImportRun;
use App\Services\CameraImportReproducibilityVerifier;
use Illuminate\Console\Command;

class CameraImportReproducibilityCommand extends Command
{
    protected $signature = 'picoradar:cameras:import:verify-reproducibility {runId}';

    public function handle(CameraImportReproducibilityVerifier $verifier): int
    {
        $run = CameraImportRun::query()->find($this->argument('runId'));
        if (! $run) {
            $this->line(json_encode(['schema' => 'picoradar.camera-import-reproducibility.v1', 'status' => 'not_found', 'runId' => (int) $this->argument('runId')], JSON_THROW_ON_ERROR));

            return self::FAILURE;
        }
        $result = $verifier->verify($run);
        $this->line(json_encode($result, JSON_THROW_ON_ERROR));

        return $result['status'] === 'reproducible' ? self::SUCCESS : self::FAILURE;
    }
}
