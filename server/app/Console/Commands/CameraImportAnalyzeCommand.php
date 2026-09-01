<?php

namespace App\Console\Commands;

use App\Models\CameraImportRun;
use App\Services\CameraImportService;
use DomainException;
use Illuminate\Console\Command;

class CameraImportAnalyzeCommand extends Command
{
    protected $signature = 'picoradar:cameras:import:analyze {runId} {--json}';

    public function handle(CameraImportService $imports): int
    {
        try {
            $run = $imports->analyze(CameraImportRun::query()->findOrFail($this->argument('runId')));
        } catch (DomainException $exception) {
            $this->line(json_encode(['schema' => 'picoradar.camera-import-analysis.v1', 'status' => 'failed', 'error' => $exception->getMessage()], JSON_THROW_ON_ERROR));

            return self::FAILURE;
        }
        $this->line(json_encode(['schema' => 'picoradar.camera-import-analysis.v1', 'runId' => $run->id, 'status' => $run->status, 'totalRows' => $run->total_rows], JSON_THROW_ON_ERROR));

        return $run->status === 'ready' ? self::SUCCESS : self::FAILURE;
    }
}
