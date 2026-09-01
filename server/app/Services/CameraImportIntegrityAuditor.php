<?php

namespace App\Services;

use App\Models\CameraImportItem;
use App\Models\CameraImportRun;
use Illuminate\Support\Facades\Storage;

/** Read-only consistency audit for B04 import history and its private source files. */
class CameraImportIntegrityAuditor
{
    private const RUN_STATUSES = ['uploaded', 'analyzing', 'ready', 'applying', 'applied', 'applied_with_blocks', 'failed', 'cancelled'];

    private const ITEM_STATUSES = ['pending', 'ready', 'blocked', 'skipped', 'applied', 'failed'];

    private const CLASSIFICATIONS = ['invalid', 'manual_identity_review', 'create_ready', 'update_ready', 'noop', 'duplicate_review', 'dense_scan_review', 'operational_change_review'];

    /** @return array{schema: string, errorCount: int, errors: list<array<string, int|string>>} */
    public function audit(): array
    {
        $errors = [];
        CameraImportRun::query()->orderBy('id')->eachById(function (CameraImportRun $run) use (&$errors): void {
            $this->auditRun($run, $errors);
        });

        return ['schema' => 'picoradar.camera-import-integrity.v1', 'errorCount' => count($errors), 'errors' => $errors];
    }

    /** @param list<array<string, int|string>> $errors */
    private function auditRun(CameraImportRun $run, array &$errors): void
    {
        if (! in_array($run->status, self::RUN_STATUSES, true)) {
            $this->error($errors, $run, 'impossible_run_state');
        }
        $disk = Storage::disk('local');
        if (! $disk->exists($run->stored_path)) {
            $this->error($errors, $run, 'file_missing');
        } elseif (! hash_equals($run->file_sha256, hash_file('sha256', $disk->path($run->stored_path)))) {
            $this->error($errors, $run, 'file_hash_mismatch');
        }
        $generation = (int) $run->analysis_generation;
        if ($generation === 0 && $run->items()->exists()) {
            $this->error($errors, $run, 'run_item_generation_mismatch');
        }
        if ($run->items()->where('analysis_generation', '>', $generation)->exists()) {
            $this->error($errors, $run, 'future_item_generation');
        }
        if (in_array($run->status, ['uploaded', 'analyzing'], true) && $run->items()->where('analysis_generation', $generation)->exists()) {
            $this->error($errors, $run, 'run_item_state_mismatch');
        }

        $current = $run->items()->where('analysis_generation', $generation);
        $counts = (clone $current)->selectRaw('classification, count(*) as count')->groupBy('classification')->pluck('count', 'classification');
        $expected = [
            'total_rows' => (clone $current)->count(),
            'valid_rows' => (clone $current)->whereNot('classification', 'invalid')->count(),
            'invalid_rows' => $counts['invalid'] ?? 0,
            'create_ready_rows' => $counts['create_ready'] ?? 0,
            'update_ready_rows' => $counts['update_ready'] ?? 0,
            'noop_rows' => $counts['noop'] ?? 0,
            'duplicate_review_rows' => $counts['duplicate_review'] ?? 0,
            'operational_change_rows' => $counts['operational_change_review'] ?? 0,
            'dense_scan_rows' => $counts['dense_scan_review'] ?? 0,
            'blocked_rows' => (clone $current)->whereIn('status', ['blocked', 'failed'])->count(),
            'applied_rows' => (clone $current)->where('status', 'applied')->count(),
        ];
        foreach ($expected as $column => $value) {
            if ((int) $run->{$column} !== $value) {
                $this->error($errors, $run, 'counter_mismatch');

                break;
            }
        }

        $run->items()->orderBy('id')->eachById(function (CameraImportItem $item) use ($run, $generation, &$errors): void {
            if (! in_array($item->status, self::ITEM_STATUSES, true) || ! in_array($item->classification, self::CLASSIFICATIONS, true)) {
                $this->error($errors, $run, 'impossible_item_state', $item);
            }
            if ($item->status === 'applied' && (! $item->applied_camera_id || ! $item->applied_at)) {
                $this->error($errors, $run, 'applied_item_missing_application', $item);
            }
            if ($item->status !== 'applied' && ($item->applied_camera_id || $item->applied_at)) {
                $this->error($errors, $run, 'unapplied_item_has_application', $item);
            }
            if (($item->resolved_by_id === null) !== ($item->resolved_at === null)) {
                $this->error($errors, $run, 'resolution_missing_actor_or_time', $item);
            }
            if ($item->analysis_generation === $generation && $item->status === 'ready' && ! empty($item->errors)) {
                $this->error($errors, $run, 'ready_item_has_fatal_errors', $item);
            }
        });
    }

    /** @param list<array<string, int|string>> $errors */
    private function error(array &$errors, CameraImportRun $run, string $code, ?CameraImportItem $item = null): void
    {
        $error = ['runId' => $run->id, 'code' => $code];
        if ($item) {
            $error['itemId'] = $item->id;
        }
        $errors[] = $error;
    }
}
