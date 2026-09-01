<?php

namespace App\Console\Commands;

use App\Models\Camera;
use App\Services\CameraDuplicateDetector;
use Illuminate\Console\Command;

class CameraDuplicatesCommand extends Command
{
    protected $signature = 'picoradar:cameras:duplicates {--jurisdiction=} {--distance=25}';

    protected $description = 'Report read-only possible camera duplicates.';

    public function handle(CameraDuplicateDetector $detector): int
    {
        $distance = min(500, max(1, (float) $this->option('distance')));
        $query = Camera::query()->where('status', '!=', 'retired')->when($this->option('jurisdiction'), fn ($builder, $key) => $builder->whereHas('jurisdiction', fn ($jurisdiction) => $jurisdiction->where('key', $key)));
        $query->orderBy('id')->eachById(function (Camera $camera) use ($detector, $distance): void {
            $scan = $detector->scan($camera, $distance);
            if ($scan['scanCapped']) {
                $this->warn("{$camera->camera_id} candidate scan capped; additional nearby records may exist.");
            }
            foreach ($scan['candidates'] as $candidate) {
                if ($camera->id < $candidate['camera']->id) {
                    $this->line("{$camera->camera_id} {$candidate['camera']->camera_id} ".round($candidate['distanceMeters'], 2).'m');
                }
            }
        });

        return self::SUCCESS;
    }
}
