<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraImportRun;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use DomainException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/** B04 boundary: parses private files and can only create/update B03 drafts. */
class CameraImportService
{
    /** The optional callback is a test-only failure seam; it is not request configurable. */
    public function __construct(private readonly CameraRegistryService $registry, private readonly CameraDuplicateDetector $duplicates, private readonly DatasetAuditLogger $audit, private readonly CameraImportPreApplyValidator $preApply, private readonly CameraImportDiffService $diff, private readonly CameraImportProfileValidator $profiles, private readonly ?\Closure $failureHook = null) {}

    public function upload(UploadedFile $file, CameraSource $source, string $mode, ?Jurisdiction $defaultJurisdiction, ?User $actor = null): CameraImportRun
    {
        $format = $this->format($file->getClientOriginalName());
        $max = ($format === 'geojson' ? config('picoradar.camera_import_geojson_max_mb', 20) : config('picoradar.camera_import_max_mb', 50)) * 1024 * 1024;
        if (! in_array($mode, ['snapshot', 'delta'], true) || $file->getSize() === false || $file->getSize() > $max) {
            throw new DomainException('Unsupported import mode or oversized file.');
        }
        $id = (string) Str::uuid();
        $ext = $format === 'geojson' ? 'geojson' : $format;
        $profileKey = "generic_{$format}_v1";
        $profile = $this->profiles->read($profileKey);
        $path = "camera-imports/{$id}/source.{$ext}";
        $disk = Storage::disk('local');
        if (! $disk->putFileAs("camera-imports/{$id}", $file, "source.{$ext}")) {
            throw new DomainException('Private storage write failed.');
        }
        try {
            $sha = hash_file('sha256', $disk->path($path));
            $run = CameraImportRun::query()->create([
                'source_id' => $source->id, 'default_jurisdiction_id' => $defaultJurisdiction?->id, 'format' => $format, 'import_mode' => $mode, 'original_filename' => basename(str_replace(['\\', '/'], '_', $file->getClientOriginalName())), 'stored_path' => $path, 'file_size' => $file->getSize(), 'file_sha256' => $sha, 'status' => 'uploaded',
                'importer_version' => CameraImportRun::IMPORTER_VERSION, 'normalization_version' => CameraImportRun::NORMALIZATION_VERSION, 'source_snapshot' => $this->sourceSnapshot($source), 'parser_options' => ['encoding' => 'UTF-8', 'format' => $format], 'column_mapping' => $profile['columnMappings'], 'profile_key' => $profileKey, 'profile_sha256' => $this->profiles->hash($profileKey), 'analysis_input_fingerprint' => $this->hash(['file' => $sha, 'source' => $this->sourceSnapshot($source), 'jurisdiction' => $defaultJurisdiction?->id, 'mode' => $mode, 'profile' => $profileKey, 'profileSha256' => $this->profiles->hash($profileKey), 'parser' => ['encoding' => 'UTF-8', 'format' => $format], 'schema' => 1, 'normalization' => CameraImportRun::NORMALIZATION_VERSION]), 'created_by_id' => $actor?->id,
            ]);
        } catch (\Throwable $e) {
            $disk->delete($path);
            throw $e;
        }
        $this->audit->log($actor, 'camera_import.created', $run, ['fileSha256' => $sha, 'sourceKey' => $source->key]);

        return $run;
    }

    public function analyze(CameraImportRun $run, ?User $actor = null): CameraImportRun
    {
        if (in_array($run->status, ['applied', 'cancelled', 'applying'], true) || ($run->applied_rows ?? 0) > 0) {
            throw new DomainException('Run cannot be analyzed in its current state.');
        }
        $this->assertFile($run);
        $run->update(['status' => 'analyzing', 'analysis_generation' => $run->analysis_generation + 1]);
        $generation = $run->analysis_generation;
        try {
            foreach ($this->records($run) as $number => $raw) {
                $this->analyseRecord($run, $generation, $number + 1, $raw);
            }
        } catch (DomainException|\JsonException $exception) {
            $run->forceFill(['status' => 'failed', 'error_summary' => ['structural_file_error' => 1]])->save();
            $this->audit->log($actor, 'camera_import.analysis_failed', $run, ['exception' => $exception::class]);

            return $run->fresh();
        }
        $this->resolveSameFileExternalIdConflicts($run, $generation);
        $this->refreshCounters($run);
        $result = $this->resultHash($run, $generation);
        $run->forceFill(['status' => 'ready', 'analysis_result_hash' => $result, 'analyzed_at' => now()])->save();
        $this->audit->log($actor, 'camera_import.analyzed', $run, ['analysisResultHash' => $result]);

        return $run->fresh();
    }

    public function apply(CameraImportRun $run, ?User $actor = null): CameraImportRun
    {
        $run = CameraImportRun::query()->findOrFail($run->id);
        if (in_array($run->status, ['applied', 'applied_with_blocks'], true)) {
            return $run;
        }
        try {
            $this->assertFile($run);
        } catch (DomainException $exception) {
            $run->forceFill(['error_summary' => [$exception->getMessage() => 1]])->save();

            return $run->fresh();
        }
        if ($run->analyzed_at?->lt(now()->subHours(config('picoradar.camera_import_analysis_max_age_hours', 24)))) {
            throw new DomainException('Analysis is stale. Reanalyze before apply.');
        }
        $source = $run->source()->firstOrFail();
        if (! $source->is_active || ! $source->verified_at) {
            $run->forceFill(['error_summary' => ['source_not_operational' => 1]])->save();

            return $run->fresh();
        }
        [$run, $ownsApply] = DB::transaction(function () use ($run, $actor): array {
            $locked = CameraImportRun::query()->lockForUpdate()->findOrFail($run->id);
            if (in_array($locked->status, ['applied', 'applied_with_blocks', 'applying'], true)) {
                return [$locked, false];
            }
            if ($locked->status !== 'ready') {
                throw new DomainException('Only a ready import can apply.');
            }
            $locked->forceFill(['status' => 'applying', 'apply_started_at' => now(), 'error_summary' => null])->save();
            $this->audit->log($actor, 'camera_import.apply_started', $locked, []);

            return [$locked, true];
        });
        if (! $ownsApply) {
            return $run;
        }
        try {
            $run->items()->where('analysis_generation', $run->analysis_generation)->whereIn('classification', ['create_ready', 'update_ready', 'noop'])->whereNotIn('status', ['applied', 'skipped'])->orderBy('id')->eachById(function (CameraImportItem $item) use ($run, $actor): void {
                $this->applyItem($run, $item, $actor);
            });
            $this->refreshCounters($run);
            $run->refresh();
            $run->forceFill(['status' => $run->blocked_rows ? 'applied_with_blocks' : 'applied', 'apply_finished_at' => now()])->save();
            $this->audit->log($actor, 'camera_import.applied', $run, ['appliedRows' => $run->applied_rows]);
        } catch (\Throwable $exception) {
            DB::transaction(function () use ($run, $actor, $exception): void {
                $recoverable = CameraImportRun::query()->lockForUpdate()->findOrFail($run->id);
                $recoverable->forceFill(['status' => 'ready', 'error_summary' => ['apply_failed' => 1]])->save();
                $this->audit->log($actor, 'camera_import.apply_failed', $recoverable, ['exception' => $exception::class]);
            });

            return $run->fresh();
        }

        return $run->fresh();
    }

    public function refreshCounters(CameraImportRun $run): void
    {
        $q = $run->items()->where('analysis_generation', $run->analysis_generation);
        $counts = (clone $q)->selectRaw('classification, count(*) c')->groupBy('classification')->pluck('c', 'classification');
        $run->forceFill(['total_rows' => (clone $q)->count(), 'valid_rows' => (clone $q)->whereNot('classification', 'invalid')->count(), 'invalid_rows' => $counts['invalid'] ?? 0, 'create_ready_rows' => $counts['create_ready'] ?? 0, 'update_ready_rows' => $counts['update_ready'] ?? 0, 'noop_rows' => $counts['noop'] ?? 0, 'duplicate_review_rows' => $counts['duplicate_review'] ?? 0, 'operational_change_rows' => $counts['operational_change_review'] ?? 0, 'dense_scan_rows' => $counts['dense_scan_review'] ?? 0, 'blocked_rows' => (clone $q)->whereIn('status', ['blocked', 'failed'])->count(), 'applied_rows' => (clone $q)->where('status', 'applied')->count()])->save();
    }

    private function analyseRecord(CameraImportRun $run, int $generation, int $row, array $raw): void
    {
        $parseErrors = $raw['_parse_errors'] ?? [];
        unset($raw['_parse_errors']);
        $payload = $this->normalize($raw);
        $errors = $parseErrors;
        $warnings = ! empty($raw['_geometry_property_coordinate_conflict']) ? ['geometry_property_coordinate_conflict'] : [];
        foreach (['lat', 'lon'] as $key) {
            if (! is_numeric($payload[$key] ?? null) || ($key === 'lat' && ($payload[$key] < -90 || $payload[$key] > 90)) || ($key === 'lon' && ($payload[$key] < -180 || $payload[$key] > 180))) {
                $errors[] = 'invalid_'.$key;
            }
        }
        if (($payload['speed_limit'] ?? null) !== null && ($payload['speed_limit'] < 1 || $payload['speed_limit'] > 200)) {
            $errors[] = 'invalid_speed_limit';
        }
        if (($payload['bearing'] ?? null) !== null && ($payload['bearing'] < 0 || $payload['bearing'] > 359)) {
            $errors[] = 'invalid_bearing';
        }
        [$jurisdiction,$municipality] = $this->geography($run, $payload, $errors);
        $classification = $errors ? 'invalid' : (($payload['external_id'] ?? null) === null ? 'manual_identity_review' : 'create_ready');
        $matched = null;
        $scan = null;
        if (! $errors && $payload['external_id']) {
            $matched = Camera::query()->where('source_id', $run->source_id)->where('external_id', $payload['external_id'])->first();
            if ($matched) {
                $same = ! $this->diff->differs($matched, $payload, $jurisdiction->id, $municipality->id);
                $classification = $same ? 'noop' : ($matched->status === CameraStatus::Retired ? 'manual_identity_review' : (in_array($matched->status, [CameraStatus::Draft, CameraStatus::Rejected], true) ? 'update_ready' : 'operational_change_review'));
            } else {
                $seed = new Camera(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $run->source_id, 'lat' => $payload['lat'], 'lon' => $payload['lon'], 'type' => $payload['type']]);
                $scan = $this->duplicates->scan($seed);
                $classification = $scan['scanCapped'] ? 'dense_scan_review' : ($scan['candidates'] ? 'duplicate_review' : 'create_ready');
            }
        }
        CameraImportItem::query()->create(['run_id' => $run->id, 'analysis_generation' => $generation, 'row_number' => $row, 'raw_hash' => $this->hash($raw), 'normalized_hash' => $this->hash($payload), 'external_id' => $payload['external_id'] ?? null, 'normalized_payload' => $payload, 'classification' => $classification, 'status' => in_array($classification, ['create_ready', 'update_ready', 'noop'], true) ? 'ready' : 'blocked', 'matched_camera_id' => $matched?->id, 'duplicate_scan_capped' => $scan['scanCapped'] ?? false, 'duplicate_candidates' => $scan ? array_map(fn ($c) => ['cameraId' => $c['camera']->camera_id, 'distanceMeters' => $c['distanceMeters']], $scan['candidates']) : null, 'errors' => $errors ?: null, 'warnings' => $warnings ?: null]);
    }

    private function applyItem(CameraImportRun $run, CameraImportItem $item, ?User $actor): void
    {
        DB::transaction(function () use ($run, $item, $actor): void {
            $item = CameraImportItem::lockForUpdate()->findOrFail($item->id);
            if ($item->status === 'applied') {
                return;
            }
            try {
                $this->preApply->assertSafe($run, $item);
            } catch (DomainException $e) {
                $classification = match ($e->getMessage()) {
                    'duplicate_candidate' => 'duplicate_review',
                    'duplicate_scan_capped' => 'dense_scan_review',
                    default => $item->classification,
                };
                $item->forceFill(['classification' => $classification, 'status' => 'blocked', 'errors' => array_values(array_unique(array_merge($item->errors ?? [], [$e->getMessage()])))])->save();

                return;
            }
            $p = $item->normalized_payload;
            $camera = $item->matchedCamera?->fresh();
            $attributes = $this->cameraPayloadFromImport($run, $p);
            if ($item->classification === 'create_ready') {
                $camera = $this->registry->create($attributes, $actor);
            } elseif ($item->classification === 'update_ready' && $camera) {
                $camera = $this->registry->updateDraft($camera, $attributes, $actor);
            } elseif ($item->classification === 'noop' && $camera) {
            } else {
                $item->forceFill(['status' => 'blocked'])->save();

                return;
            }
            $this->checkpoint('apply.after_camera_mutation');
            $item->forceFill(['status' => 'applied', 'applied_camera_id' => $camera->id, 'applied_at' => now()])->save();
            $this->audit->log($actor, 'camera_import.item_applied', $item, ['cameraId' => $camera->camera_id]);
        });
    }

    /** The canonical row is deterministic (lowest row number); conflicts never pick a winner. */
    private function resolveSameFileExternalIdConflicts(CameraImportRun $run, int $generation): void
    {
        $groups = $run->items()->where('analysis_generation', $generation)->whereNotNull('external_id')->selectRaw('external_id, count(*) as total, count(distinct normalized_hash) as hashes')->groupBy('external_id')->having('total', '>', 1)->get();
        foreach ($groups as $group) {
            $items = $run->items()->where('analysis_generation', $generation)->where('external_id', $group->external_id)->orderBy('row_number')->get();
            if ((int) $group->hashes === 1) {
                foreach ($items->skip(1) as $item) {
                    $item->forceFill(['classification' => 'duplicate_review', 'status' => 'blocked', 'warnings' => array_values(array_unique(array_merge($item->warnings ?? [], ['duplicate_external_id_identical'])))])->save();
                }

                continue;
            }
            foreach ($items as $item) {
                $item->forceFill(['classification' => 'duplicate_review', 'status' => 'blocked', 'errors' => array_values(array_unique(array_merge($item->errors ?? [], ['duplicate_external_id_conflict'])))])->save();
            }
        }
    }

    private function records(CameraImportRun $run): \Generator
    {
        $path = Storage::disk('local')->path($run->stored_path);
        if ($run->format === 'csv') {
            $f = new \SplFileObject($path);
            $first = (string) $f->fgets();
            $this->assertUtf8Text($first);
            $first = preg_replace('/^\xEF\xBB\xBF/', '', $first) ?? $first;
            $comma = count(str_getcsv($first, ','));
            $semicolon = count(str_getcsv($first, ';'));
            $delimiter = $semicolon > $comma ? ';' : ',';
            $f->rewind();
            $f->setCsvControl($delimiter);
            $f->setFlags(\SplFileObject::READ_CSV | \SplFileObject::SKIP_EMPTY);
            $headers = null;
            foreach ($f as $row) {
                if (! is_array($row)) {
                    continue;
                }
                if ($headers === null) {
                    $headers = array_map(fn ($h) => strtolower(trim(preg_replace('/^\xEF\xBB\xBF/', '', (string) $h) ?? (string) $h)), $row);
                    if (count($headers) !== count(array_unique($headers)) || ! in_array('lat', $headers, true) || ! in_array('lon', $headers, true)) {
                        throw new DomainException('Invalid CSV headers.');
                    }

                    continue;
                }
                foreach ($row as $value) {
                    $this->assertUtf8Text((string) $value);
                }
                if ($row === [null]) {
                    continue;
                }yield array_combine($headers, array_pad($row, count($headers), null));
            }

            return;
        } if ($run->format === 'geojson') {
            $handle = fopen($path, 'rb');
            $document = json_decode(stream_get_contents($handle), true, 512, JSON_THROW_ON_ERROR);
            fclose($handle);
            if (($document['type'] ?? null) !== 'FeatureCollection' || isset($document['crs']) || ! is_array($document['features'] ?? null)) {
                throw new DomainException('Only standard GeoJSON FeatureCollection is supported.');
            }
            foreach ($document['features'] as $feature) {
                $geometry = $feature['geometry'] ?? null;
                if (($feature['type'] ?? null) !== 'Feature' || ! is_array($geometry) || ($geometry['type'] ?? null) !== 'Point' || ! is_array($geometry['coordinates'] ?? null) || count($geometry['coordinates']) !== 2) {
                    yield ['_parse_errors' => ['unsupported_geometry']];

                    continue;
                }
                [$lon, $lat] = $geometry['coordinates'];
                if (! is_numeric($lat) || ! is_numeric($lon)) {
                    yield ['_parse_errors' => ['invalid_lat', 'invalid_lon']];

                    continue;
                }
                $properties = is_array($feature['properties'] ?? null) ? $feature['properties'] : [];
                if ((isset($properties['lat']) && (float) $properties['lat'] !== (float) $lat) || (isset($properties['lon']) && (float) $properties['lon'] !== (float) $lon)) {
                    $properties['_geometry_property_coordinate_conflict'] = true;
                }
                $properties['lat'] = $lat;
                $properties['lon'] = $lon;
                yield $properties;
            }

            return;
        } $f = new \SplFileObject($path);
        foreach ($f as $line) {
            $line = trim((string) $line);
            if ($line === '') {
                continue;
            }
            try {
                $this->assertUtf8Text($line);
                $v = json_decode($line, true, 512, JSON_THROW_ON_ERROR);
            } catch (\JsonException) {
                yield ['_parse_errors' => ['invalid_ndjson']];

                continue;
            }
            if (! is_array($v) || array_is_list($v)) {
                yield ['_parse_errors' => ['invalid_ndjson_record']];

                continue;
            }
            yield $v;
        }
    }

    private function normalize(array $r): array
    {
        $get = fn ($k) => isset($r[$k]) && trim((string) $r[$k]) !== '' ? trim((string) $r[$k]) : null;
        $type = match (strtolower((string) $get('type'))) {
            'speed','speed_camera' => 'speed','red_light','redlight' => 'red_light','combined' => 'combined','other' => 'other',default => 'unknown'
        };

        return ['region_code' => $get('region_code'), 'municipality_code' => $get('municipality_code'), 'municipality_name' => $get('municipality_name'), 'external_id' => $get('external_id'), 'name' => $get('name'), 'lat' => $get('lat') === null ? null : round((float) $get('lat'), 7), 'lon' => $get('lon') === null ? null : round((float) $get('lon'), 7), 'type' => $type, 'direction' => $get('direction'), 'bearing' => $get('bearing') === null ? null : (int) $get('bearing'), 'corridor' => $get('corridor'), 'speed_limit' => $get('speed_limit') === null ? null : (int) $get('speed_limit'), 'notes' => $get('notes')];
    }

    private function geography(CameraImportRun $run, array $p, array &$errors): array
    {
        $j = $p['region_code'] ? Jurisdiction::query()->where('key', $p['region_code'])->first() : $run->defaultJurisdiction;
        if (! $j) {
            $errors[] = 'unknown_jurisdiction';

            return [new Jurisdiction, new GeographicUnit];
        } $q = GeographicUnit::query()->where('level', 'municipality');
        if ($p['municipality_code']) {
            $q->where('code', $p['municipality_code']);
        } elseif ($p['municipality_name']) {
            $q->where('normalized_name', strtolower(trim($p['municipality_name'])));
        } else {
            $errors[] = 'unknown_municipality';

            return [$j, new GeographicUnit];
        }$units = $q->get();
        if ($units->count() !== 1) {
            $errors[] = $units->isEmpty() ? 'unknown_municipality' : 'ambiguous_municipality';

            return [$j, new GeographicUnit];
        }$u = $units->first();
        if (! $j->geographicUnits()->whereKey($u->id)->exists()) {
            $errors[] = 'municipality_outside_coverage';
        }

        return [$j, $u];
    }

    private function cameraPayloadFromImport(CameraImportRun $run, array $p): array
    {
        $j = $p['region_code'] ? Jurisdiction::where('key', $p['region_code'])->first() : $run->defaultJurisdiction;
        $u = $p['municipality_code'] ? GeographicUnit::where('code', $p['municipality_code'])->first() : GeographicUnit::where('normalized_name', strtolower((string) $p['municipality_name']))->first();
        if (! $j || ! $u) {
            throw new DomainException('Geography changed since analysis.');
        }

        return ['jurisdiction_id' => $j->id, 'geographic_unit_id' => $u->id, 'source_id' => $run->source_id, 'external_id' => $p['external_id'], 'name' => $p['name'], 'lat' => $p['lat'], 'lon' => $p['lon'], 'type' => $p['type'], 'direction' => $p['direction'], 'bearing' => $p['bearing'], 'corridor' => $p['corridor'], 'speed_limit' => $p['speed_limit']];
    }

    private function cameraPayload(Camera $c): array
    {
        return ['external_id' => $c->external_id, 'name' => $c->name, 'lat' => round((float) $c->lat, 7), 'lon' => round((float) $c->lon, 7), 'type' => $c->type->value, 'direction' => $c->direction, 'bearing' => $c->bearing, 'corridor' => $c->corridor, 'speed_limit' => $c->speed_limit];
    }

    private function assertFile(CameraImportRun $run): void
    {
        $disk = Storage::disk('local');
        if (! $disk->exists($run->stored_path) || hash_file('sha256', $disk->path($run->stored_path)) !== $run->file_sha256) {
            throw new DomainException('file_hash_mismatch');
        }
    }

    private function assertUtf8Text(string $value): void
    {
        if (str_contains($value, "\0") || preg_match('//u', $value) !== 1) {
            throw new DomainException('invalid_encoding');
        }
    }

    private function checkpoint(string $point): void
    {
        if ($this->failureHook) {
            ($this->failureHook)($point);
        }
    }

    private function format(string $name): string
    {
        return match (strtolower(pathinfo($name, PATHINFO_EXTENSION))) {
            'csv' => 'csv','ndjson','jsonl' => 'ndjson','geojson' => 'geojson',default => throw new DomainException('Unsupported import format.')
        };
    }

    private function sourceSnapshot(CameraSource $s): array
    {
        return ['source_id' => $s->id, 'key' => $s->key, 'authority' => $s->authority, 'url' => $s->url, 'source_type' => $s->source_type->value, 'verified_at' => $s->verified_at?->toISOString()];
    }

    private function resultHash(CameraImportRun $r, int $g): string
    {
        return $this->hash($r->items()->where('analysis_generation', $g)->orderBy('row_number')->get()->map(fn ($i) => [$i->row_number, $i->raw_hash, $i->normalized_hash, $i->classification, $i->errors, $i->warnings])->all());
    }

    private function hash(mixed $v): string
    {
        $sort = function (&$x) use (&$sort) {
            if (is_array($x)) {
                ksort($x);
                foreach ($x as &$y) {
                    $sort($y);
                }
            }
        };
        $sort($v);

        return hash('sha256', json_encode($v, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR));
    }
}
