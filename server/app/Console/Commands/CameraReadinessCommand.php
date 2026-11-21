<?php

namespace App\Console\Commands;

use App\Models\Camera;
use App\Services\CameraContractReadinessService;
use Illuminate\Console\Command;

class CameraReadinessCommand extends Command
{
    protected $signature = 'picoradar:cameras:readiness {--json} {--fail-on-error} {--jurisdiction=}';

    protected $description = 'Assess active cameras for future dataset contract readiness without publishing.';

    public function handle(CameraContractReadinessService $readiness): int
    {
        $notReady = [];
        $reasons = [];
        $query = Camera::query()->where('status', 'active')->with(['source', 'jurisdiction.primaryGeographicUnit', 'jurisdiction.geographicUnits', 'geographicUnit']);
        $query->when($this->option('jurisdiction'), fn ($builder, $key) => $builder->whereHas('jurisdiction', fn ($jurisdiction) => $jurisdiction->where('key', $key)))->orderBy('id')->eachById(function (Camera $camera) use ($readiness, &$notReady, &$reasons): void {
            $result = $readiness->assess($camera);
            if (! $result['readyForFutureDataset']) {
                $notReady[] = ['cameraId' => $camera->camera_id, 'reasons' => $result['reasons']];
                foreach ($result['reasons'] as $reason) {
                    $reasons[$reason] = ($reasons[$reason] ?? 0) + 1;
                }
            }
        });
        $payload = ['schema' => 'picoradar.camera-readiness.v1', 'totalActive' => $query->count(), 'ready' => $query->count() - count($notReady), 'notReady' => count($notReady), 'reasons' => $reasons, 'cameras' => $notReady];
        if ($this->option('json')) {
            $this->line(json_encode($payload, JSON_THROW_ON_ERROR));
        } else {
            $this->table(['metric', 'value'], [['total active', $payload['totalActive']], ['ready', $payload['ready']], ['not ready', $payload['notReady']]]);
        }

        return $this->option('fail-on-error') && $notReady !== [] ? self::FAILURE : self::SUCCESS;
    }
}
