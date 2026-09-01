<?php

namespace App\Console\Commands;

use App\Models\CameraImportRun;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class CameraImportHealthCommand extends Command
{
    protected $signature = 'picoradar:cameras:imports:health {--json}';

    public function handle(): int
    {
        $runs = CameraImportRun::query();
        $result = ['schema' => 'picoradar.camera-import-health.v1', 'byStatus' => $runs->selectRaw('status,count(*) as count')->groupBy('status')->pluck('count', 'status'), 'missingFiles' => CameraImportRun::query()->get()->filter(fn ($r) => ! Storage::disk('local')->exists($r->stored_path))->count(), 'stuckApplying' => CameraImportRun::query()->where('status', 'applying')->where('apply_started_at', '<', now()->subMinutes(config('picoradar.camera_import_apply_stuck_minutes')))->count()];
        $this->line(json_encode($result));

        return self::SUCCESS;
    }
}
