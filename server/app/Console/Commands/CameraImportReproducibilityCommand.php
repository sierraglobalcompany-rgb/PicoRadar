<?php

namespace App\Console\Commands;

use App\Models\CameraImportRun;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class CameraImportReproducibilityCommand extends Command
{
    protected $signature = 'picoradar:cameras:import:verify-reproducibility {runId}';

    public function handle(): int
    {
        $r = CameraImportRun::findOrFail($this->argument('runId'));
        $status = ! Storage::disk('local')->exists($r->stored_path) || hash_file('sha256', Storage::disk('local')->path($r->stored_path)) !== $r->file_sha256 ? 'file_changed' : ($r->analysis_schema_version !== 1 ? 'unsupported_old_version' : 'reproducible');
        $this->line(json_encode(['schema' => 'picoradar.camera-import-reproducibility.v1', 'status' => $status, 'runId' => $r->id]));

        return $status === 'reproducible' ? self::SUCCESS : self::FAILURE;
    }
}
