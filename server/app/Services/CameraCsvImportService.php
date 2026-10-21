<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\GeographicUnitLevel;
use App\Models\Camera;
use App\Models\CameraCsvImport;
use App\Models\CameraSource;
use App\Models\Jurisdiction;
use App\Models\User;
use DomainException;
use Illuminate\Database\QueryException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

final class CameraCsvImportService
{
    private const ALLOWED = [
        'external_id', 'name', 'lat', 'lon', 'type',
        'direction', 'bearing', 'corridor', 'speed_limit', 'notes',
    ];

    public function __construct(
        private readonly CameraCsvParser $parser,
        private readonly CameraCsvPreviewService $preview,
        private readonly CameraRegistryService $registry,
        private readonly DatasetAuditLogger $audit,
    ) {}

    public function create(
        UploadedFile $file, CameraSource $source, Jurisdiction $jurisdiction,
        string $mode, User $actor
    ): CameraCsvImport {
        $realPath = $file->getRealPath();
        if ($realPath === false) {
            throw new RuntimeException('Uploaded CSV is unavailable.');
        }
        $bytes = file_get_contents($realPath);
        if ($bytes === false) {
            throw new RuntimeException('Uploaded CSV could not be read.');
        }
        $parsed = $this->parser->parseBytes($bytes);
        $preview = $this->preview->preview($parsed, $source, $jurisdiction, $mode);
        $analysis = json_encode(['parsed' => $parsed, 'preview' => $preview], JSON_THROW_ON_ERROR);
        $directory = 'camera-csv-imports/'.Str::uuid();
        $original = $directory.'/original.csv';
        $snapshot = $directory.'/analysis.json';
        $disk = Storage::disk('local');

        try {
            if (! $disk->put($original, $bytes) || ! $disk->put($snapshot, $analysis)) {
                throw new RuntimeException('Private import storage is unavailable.');
            }

            return DB::transaction(function () use (
                $source, $jurisdiction, $actor, $mode, $original,
                $snapshot, $bytes, $analysis, $parsed, $preview
            ): CameraCsvImport {
                $batch = CameraCsvImport::query()->create([
                    'source_id' => $source->id,
                    'jurisdiction_id' => $jurisdiction->id,
                    'created_by_id' => $actor->id,
                    'mode' => $mode,
                    'status' => 'review',
                    'original_path' => $original,
                    'original_sha256' => hash('sha256', $bytes),
                    'analysis_path' => $snapshot,
                    'analysis_sha256' => hash('sha256', $analysis),
                    'counts' => $preview['counts'],
                    'row_count' => count($parsed['rows']),
                ]);
                $this->audit->log($actor, 'camera_csv_import.analyzed', $batch, [
                    'sourceKey' => $source->key, 'jurisdictionKey' => $jurisdiction->key,
                    'sha256' => $batch->original_sha256, 'count' => $batch->row_count,
                ]);

                return $batch;
            });
        } catch (\Throwable $failure) {
            // Only delete the newly allocated opaque folder for this attempt.
            $disk->deleteDirectory($directory);
            throw $failure;
        }
    }

    /** @return array{parsed:array<string,mixed>,preview:array<string,mixed>} */
    public function load(CameraCsvImport $batch): array
    {
        $disk = Storage::disk('local');
        if (! $disk->exists($batch->original_path) || ! $disk->exists($batch->analysis_path)) {
            abort(409, 'Private CSV or its analysis is missing.');
        }
        $original = $disk->get($batch->original_path);
        $analysis = $disk->get($batch->analysis_path);
        if (! is_string($original) || ! is_string($analysis)
            || ! hash_equals($batch->original_sha256, hash('sha256', $original))
            || ! hash_equals($batch->analysis_sha256, hash('sha256', $analysis))) {
            abort(409, 'Private CSV or its analysis is missing or has changed.');
        }
        $data = json_decode($analysis, true, 512, JSON_THROW_ON_ERROR);
        if (! is_array($data) || ! isset($data['parsed']['rows'], $data['preview']['rows'])) {
            abort(409, 'This CSV analysis is invalid.');
        }

        return $data;
    }

    /**
     * @param list<int|string> $records
     * @return array{already_applied:bool,created:int,updated:int}
     */
    public function apply(CameraCsvImport $batch, array $records, string $analysisSha, User $actor): array
    {
        $keys = [];
        if ($records === [] || count($records) > CameraCsvParser::MAX_ROWS) {
            abort(422, 'Select a non-empty bounded set of rows.');
        }
        foreach ($records as $record) {
            if ((! is_string($record) && ! is_int($record))
                || ! preg_match('/^(?:[2-9]|[1-9]\d+)$/D', (string) $record)) {
                abort(422, 'Invalid CSV record number.');
            }
            $key = (int) $record;
            if (isset($keys[$key])) {
                abort(422, 'Duplicate CSV record selected.');
            }
            $keys[$key] = true;
        }
        $selected = array_keys($keys);
        sort($selected, SORT_NUMERIC);
        $selectionSha = hash('sha256', json_encode($selected, JSON_THROW_ON_ERROR));

        try {
            return DB::transaction(function () use ($batch, $keys, $analysisSha, $selectionSha, $actor): array {
                $current = CameraCsvImport::query()->lockForUpdate()->findOrFail($batch->id);
                // Even an idempotent replay must verify the immutable original
                // and analysis files before reporting the batch as applied.
                $data = $this->load($current);
                if ($current->status === 'applied') {
                    if (! hash_equals($current->analysis_sha256, $analysisSha)
                        || $current->applied_selection_sha256 === null
                        || ! hash_equals($current->applied_selection_sha256, $selectionSha)) {
                        abort(409, 'This batch was already applied with a different row selection or review version.');
                    }

                    return ['already_applied' => true, 'created' => 0, 'updated' => 0];
                }
                if ($current->status !== 'review' || ! hash_equals($current->analysis_sha256, $analysisSha)) {
                    abort(409, 'Import review version is stale.');
                }
                $source = CameraSource::query()->lockForUpdate()->findOrFail($current->source_id);
                $jurisdiction = Jurisdiction::query()->lockForUpdate()->findOrFail($current->jurisdiction_id);
                $newPreview = $this->preview->preview($data['parsed'], $source, $jurisdiction, $current->mode);
                $old = collect($data['preview']['rows'])->keyBy('record');
                $new = collect($newPreview['rows'])->keyBy('record');

                // Validate every selected row before making any write.
                foreach (array_keys($keys) as $record) {
                    $before = $old->get($record);
                    $after = $new->get($record);
                    if (! is_array($before) || ! is_array($after)
                        || ! in_array($before['status'], ['create_ready', 'update_ready'], true)
                        || $before['status'] !== $after['status']
                        || $before['camera_id'] !== $after['camera_id']
                        || $before['expected_fingerprint'] !== $after['expected_fingerprint']
                        || $before['values'] !== $after['values']) {
                        abort(409, 'Selected CSV rows are stale or unsafe.');
                    }
                }

                $created = 0;
                $updated = 0;
                foreach (array_keys($keys) as $record) {
                    $row = $old->get($record);
                    $values = $row['values'];
                    $existing = Camera::query()->where('source_id', $source->id)
                        ->where('external_id', $values['external_id'])
                        ->lockForUpdate()->first();
                    if ($row['status'] === 'create_ready' && $existing !== null) {
                        abort(409, 'CSV identity has been created by another operator.');
                    }
                    if ($row['status'] === 'update_ready'
                        && ($existing === null || $existing->id !== $row['camera_id']
                            || ! hash_equals($row['expected_fingerprint'], CameraCsvPreviewService::fingerprint($existing)))) {
                        abort(409, 'Camera changed during this import.');
                    }

                    $safe = Arr::only($values, self::ALLOWED);
                    if ($row['status'] === 'create_ready') {
                        $unit = $jurisdiction->geographicUnits()->where('is_active', true)
                            ->where('level', GeographicUnitLevel::Municipality->value)
                            ->where('code', $values['municipality_code'])->firstOrFail();
                        // The first array to CameraRegistryService::create(forceFill)
                        // is explicitly bounded; no CSV-supplied lifecycle keys.
                        $this->registry->create([
                            'source_id' => $source->id,
                            'jurisdiction_id' => $jurisdiction->id,
                            'geographic_unit_id' => $unit->id,
                        ] + $safe, $actor);
                        $created++;
                    } else {
                        $this->registry->updateDraft($existing, Arr::except($safe, ['external_id', 'type']), $actor);
                        $updated++;
                    }
                }

                $current->forceFill([
                    'status' => 'applied',
                    'applied_by_id' => $actor->id,
                    'applied_at' => now(),
                    'applied_selection_sha256' => $selectionSha,
                ])->save();
                $this->audit->log($actor, 'camera_csv_import.applied', $current, [
                    'created' => $created, 'updated' => $updated, 'sha256' => $current->original_sha256,
                ]);

                return ['already_applied' => false, 'created' => $created, 'updated' => $updated];
            });
        } catch (QueryException $error) {
            // Atomic DB rollback has already happened. Expose known identity
            // and transactional contention as 409, not a misleading 500.
            // MariaDB/MySQL: 1062 duplicate, 1205 lock wait, 1213 deadlock;
            // SQLSTATE 40001 denotes serialization/deadlock contention.
            $sqlState = (string) $error->getCode();
            $driverCode = (int) ($error->errorInfo[1] ?? 0);
            if (in_array($sqlState, ['23000', '23505', '40001', '40P01'], true)
                || in_array($driverCode, [1062, 1205, 1213], true)) {
                abort(409, 'Camera identity or concurrent transaction changed; no CSV batch rows were committed.');
            }
            throw $error;
        } catch (DomainException $error) {
            // CameraRegistryService rechecks lifecycle and geographic coverage
            // under row locks. A conflicting manual change must not become a
            // partial CSV batch or an opaque HTTP 500.
            abort(409, 'The camera changed during application; the CSV transaction was rolled back.');
        }
    }
}
