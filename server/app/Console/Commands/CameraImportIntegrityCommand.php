<?php

namespace App\Console\Commands;

use App\Models\CameraImportRun;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class CameraImportIntegrityCommand extends Command
{
    protected $signature = 'picoradar:cameras:imports:integrity {--json} {--fail-on-error}';

    public function handle(): int
    {
        $errors = [];
        CameraImportRun::query()->eachById(function ($r) use (&$errors) {
            $actual = $r->items()->where('analysis_generation', $r->analysis_generation)->count();
            if ($actual !== $r->total_rows) {
                $errors[] = ['runId' => $r->id, 'code' => 'counter_mismatch'];
            }if (! Storage::disk('local')->exists($r->stored_path)) {
                $errors[] = ['runId' => $r->id, 'code' => 'file_missing'];
            }
        });
        $result = ['schema' => 'picoradar.camera-import-integrity.v1', 'errors' => $errors];
        $this->line(json_encode($result));

        return $errors && $this->option('fail-on-error') ? self::FAILURE : self::SUCCESS;
    }
}
