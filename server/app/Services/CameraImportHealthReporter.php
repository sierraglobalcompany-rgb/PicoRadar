<?php

namespace App\Services;

use App\Models\CameraImportRun;
use Illuminate\Support\Facades\Storage;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use SplFileInfo;

/** Read-only storage and queue health summary for B04 imports. */
class CameraImportHealthReporter
{
    /** @return array<string, int|array<string, int>|string> */
    public function report(): array
    {
        $storedPaths = [];
        $missingFiles = 0;
        $hashMismatches = 0;
        $disk = Storage::disk('local');
        CameraImportRun::query()->orderBy('id')->eachById(function (CameraImportRun $run) use (&$storedPaths, &$missingFiles, &$hashMismatches, $disk): void {
            $storedPaths[$run->stored_path] = true;
            if (! $disk->exists($run->stored_path)) {
                $missingFiles++;

                return;
            }
            if (! hash_equals($run->file_sha256, hash_file('sha256', $disk->path($run->stored_path)))) {
                $hashMismatches++;
            }
        });

        [$orphanStorage, $storageBytes] = $this->storageUsage($disk->path('camera-imports'), $storedPaths);
        $byStatus = CameraImportRun::query()->selectRaw('status, count(*) as count')->groupBy('status')->pluck('count', 'status')->map(fn ($count) => (int) $count)->all();

        return [
            'schema' => 'picoradar.camera-import-health.v1',
            'runsByStatus' => $byStatus,
            'failed' => CameraImportRun::query()->where('status', 'failed')->count(),
            'stuckApplying' => CameraImportRun::query()->where('status', 'applying')->where('apply_started_at', '<', now()->subMinutes(config('picoradar.camera_import_apply_stuck_minutes')))->count(),
            'unresolved' => CameraImportRun::query()->whereIn('status', ['ready', 'applying'])->count(),
            'missingFiles' => $missingFiles,
            'hashMismatches' => $hashMismatches,
            'orphanStorage' => $orphanStorage,
            'storageBytes' => $storageBytes,
        ];
    }

    /** @param array<string, true> $storedPaths
     * @return array{0: int, 1: int} */
    private function storageUsage(string $directory, array $storedPaths): array
    {
        if (! is_dir($directory)) {
            return [0, 0];
        }
        $orphans = 0;
        $bytes = 0;
        $base = rtrim(str_replace('\\', '/', $directory), '/').'/';
        $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($directory, RecursiveDirectoryIterator::SKIP_DOTS));
        foreach ($iterator as $file) {
            if (! $file instanceof SplFileInfo || ! $file->isFile()) {
                continue;
            }
            $bytes += $file->getSize();
            $relative = str_replace('\\', '/', $file->getPathname());
            $relative = substr($relative, strlen($base));
            if (! isset($storedPaths['camera-imports/'.$relative])) {
                $orphans++;
            }
        }

        return [$orphans, $bytes];
    }
}
