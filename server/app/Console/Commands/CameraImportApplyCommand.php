<?php

namespace App\Console\Commands;

use App\Models\CameraImportRun;
use App\Services\CameraImportService;
use DomainException;
use Illuminate\Console\Command;

class CameraImportApplyCommand extends Command
{
    protected $signature = 'picoradar:cameras:import:apply {runId} {--json}';

    public function handle(CameraImportService $imports): int
    {
        try {
            $run = $imports->apply(CameraImportRun::query()->findOrFail($this->argument('runId')));
        } catch (DomainException $exception) {
            $this->line(json_encode(['schema' => 'picoradar.camera-import-apply.v1', 'status' => 'failed', 'error' => $exception->getMessage()], JSON_THROW_ON_ERROR));

            return self::FAILURE;
        }
        $this->line(json_encode(['schema' => 'picoradar.camera-import-apply.v1', 'runId' => $run->id, 'status' => $run->status, 'appliedRows' => $run->applied_rows], JSON_THROW_ON_ERROR));

        return in_array($run->status, ['applied', 'applied_with_blocks'], true) ? self::SUCCESS : self::FAILURE;
    }
}
