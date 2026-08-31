<?php

namespace App\Console\Commands;

use App\Enums\CameraStatus;
use App\Models\Camera;
use Illuminate\Console\Command;

class CameraQualityCommand extends Command
{
    protected $signature = 'picoradar:cameras:quality {--json : Emit a stable JSON document}';

    protected $description = 'Report read-only camera registry quality.';

    public function handle(): int
    {
        $byStatus = Camera::query()->selectRaw('status, count(*) as total')->groupBy('status')->pluck('total', 'status');
        $metrics = ['total' => (int) $byStatus->sum()];
        foreach (CameraStatus::cases() as $status) {
            $metrics[$status->value] = (int) ($byStatus[$status->value] ?? 0);
        }
        $metrics['active_speed'] = Camera::query()->where('status', 'active')->whereIn('type', ['speed', 'combined'])->count();
        $metrics['overspeed_eligible'] = Camera::query()->where('status', 'active')->whereIn('type', ['speed', 'combined'])->whereNotNull('speed_limit')->where('speed_limit_verified', true)->count();
        $metrics['speed_limit_missing'] = Camera::query()->whereIn('status', ['active', 'verified'])->whereIn('type', ['speed', 'combined'])->whereNull('speed_limit')->count();
        $metrics['speed_limit_unverified'] = Camera::query()->whereIn('status', ['active', 'verified'])->whereIn('type', ['speed', 'combined'])->where('speed_limit_verified', false)->count();

        if ($this->option('json')) {
            $this->line(json_encode(['schema' => 'picoradar.camera-quality.v1', 'metrics' => $metrics], JSON_THROW_ON_ERROR));

            return self::SUCCESS;
        }
        $this->table(['metric', 'count'], collect($metrics)->map(fn ($count, $metric) => [$metric, $count])->all());

        return self::SUCCESS;
    }
}
