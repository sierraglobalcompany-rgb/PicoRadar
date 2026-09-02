<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Models\AnsvCameraImport;
use App\Models\AnsvCameraImportRow;
use App\Models\Camera;
use Carbon\CarbonImmutable;
use Closure;
use DomainException;
use Illuminate\Support\Facades\File;
use RuntimeException;
use Throwable;

class CameraMobileDatasetPublisher
{
    public static ?Closure $failureHook = null;

    public function __construct(private readonly CameraContractReadinessService $readiness) {}

    public function publish(string $outputDirectory, ?string $version, CarbonImmutable $generatedAt, CarbonImmutable $asOf, ?int $importId = null, bool $latestApproved = false): array
    {
        if (($importId === null) === ! $latestApproved) {
            throw new DomainException('Select exactly one approved ANSV import source.');
        }

        $query = AnsvCameraImport::query()->with('source')->where('status', 'approved');
        $import = $importId !== null
            ? $query->whereKey($importId)->first()
            : $query->orderByDesc('source_fetched_at')->orderByDesc('id')->first();
        if ($import === null) {
            throw new DomainException('No approved ANSV camera import is available for publication.');
        }
        $records = [];
        $speedKnown = 0;
        $exclusions = [];
        $asOfDate = $asOf->setTimezone('America/Bogota')->toDateString();
        $version = $version ?: $this->defaultVersion($import, $asOfDate);
        $this->validateVersion($version);

        AnsvCameraImportRow::query()
            ->where('ansv_camera_import_id', $import->id)
            ->where('active_public_candidate', true)
            ->where('review_state', 'OK')
            ->with(['camera', 'import'])
            ->orderBy('source_row_identity')
            ->each(function (AnsvCameraImportRow $sourceRow) use (&$records, &$speedKnown, &$exclusions, $asOfDate): void {
                $camera = $sourceRow->camera;
                if ($camera === null) {
                    $this->exclude($exclusions, 'missing_camera');

                    return;
                }
                $readiness = $this->readiness->assess($camera);
                if (! $readiness['readyForFutureDataset']) {
                    foreach ($readiness['reasons'] as $reason) {
                        $this->exclude($exclusions, 'readiness_'.$reason);
                    }

                    return;
                }
                if ($camera->status !== CameraStatus::Active || $camera->operation_status !== 'Operando' || $sourceRow->operation_status !== 'Operando') {
                    $this->exclude($exclusions, 'non_operating');

                    return;
                }
                if ($sourceRow->source_delta !== null) {
                    $this->exclude($exclusions, 'pending_source_delta');

                    return;
                }
                if (! $this->matchesVerifiedSourceRow($camera, $sourceRow)) {
                    $this->exclude($exclusions, 'stale_master_source_mismatch');

                    return;
                }
                if ($sourceRow->operation_started_on !== null && $sourceRow->operation_started_on->toDateString() > $asOfDate) {
                    $this->exclude($exclusions, 'future_operation_window');

                    return;
                }
                $operationEndsOn = $sourceRow->operation_extension_ends_on ?? $sourceRow->operation_initial_ends_on;
                if ($operationEndsOn !== null && $operationEndsOn->toDateString() < $asOfDate) {
                    $this->exclude($exclusions, 'expired_operation_window');

                    return;
                }

                $speed = $sourceRow->reported_speed_kmh;
                $speedKnown += $speed !== null ? 1 : 0;

                $records[] = [
                    'cameraId' => $camera->camera_id,
                    'sourceRowId' => $sourceRow->source_row_identity,
                    'sourceOfficialCode' => $sourceRow->codigo_unico,
                    'sourceRequestCode' => $sourceRow->codigo_solicitud,
                    'lat' => round((float) $camera->lat, 7),
                    'lon' => round((float) $camera->lon, 7),
                    'municipality' => $sourceRow->municipality,
                    'department' => $sourceRow->department,
                    'address' => $sourceRow->address,
                    'trafficAuthority' => $sourceRow->traffic_authority,
                    'jurisdiction' => $sourceRow->jurisdiction_label,
                    'operationStatus' => $camera->operation_status,
                    'reportedSpeedKmh' => $speed,
                    'rawSpeed' => $sourceRow->raw_speed,
                    'technology' => $sourceRow->technology,
                    'installationType' => $camera->installation_type,
                    'equipmentName' => $camera->equipment_name,
                    'infractionCodes' => $camera->raw_infraction_codes ?? [],
                    'sourceFetchedAt' => $sourceRow->import->source_fetched_at?->toIso8601String(),
                    'validFrom' => $sourceRow->operation_started_on?->toDateString(),
                    'validUntil' => $operationEndsOn?->toDateString(),
                ];
            });

        $recordCount = count($records);
        if ($recordCount === 0) {
            throw new DomainException('No operating cameras are ready for publication.');
        }
        $this->validateRecords($records, $import, $asOfDate);

        $dataset = [
            'schemaVersion' => 1,
            'datasetKey' => 'traffic_cameras',
            'version' => $version,
            'generatedAt' => $generatedAt->toIso8601String(),
            'source' => [
                'title' => $import->source?->title ?? 'ANSV ubicaciones aprobadas de fotodetección',
                'url' => $import->source_url,
                'importKey' => $this->importKey($import),
                'snapshotSha256' => $import->snapshot_sha,
                'fetchedAt' => $import->source_fetched_at?->toIso8601String(),
            ],
            'recordCount' => $recordCount,
            'speedKnownCount' => $speedKnown,
            'speedCoverage' => round($speedKnown / $recordCount, 4),
            'records' => $records,
        ];

        $datasetBytes = $this->canonicalJson($dataset);
        $assetSha = hash('sha256', $datasetBytes);
        $manifest = [
            'schemaVersion' => 1,
            'datasetKey' => 'traffic_cameras',
            'version' => $version,
            'generatedAt' => $generatedAt->toIso8601String(),
            'sourceImportKey' => $this->importKey($import),
            'sourceSnapshotSha256' => $import->snapshot_sha,
            'asset' => [
                'path' => 'cameras_v1.json',
                'sha256' => $assetSha,
                'bytes' => strlen($datasetBytes),
            ],
            'recordCount' => $recordCount,
            'speedKnownCount' => $speedKnown,
            'speedCoverage' => round($speedKnown / $recordCount, 4),
            'runtimeFilter' => [
                'status' => 'active',
                'operationStatus' => 'Operando',
                'cameraContractReadiness' => true,
                'sourceImportRowState' => 'OK',
            ],
            'freshness' => [
                'sourceFetchedAt' => $import->source_fetched_at?->toIso8601String(),
                'asOf' => $asOfDate,
            ],
        ];
        $manifestBytes = $this->canonicalJson($manifest);

        $this->publishPair($outputDirectory, $datasetBytes, $manifestBytes);

        return [
            'schema' => 'picoradar.camera-dataset-publication.v1',
            'version' => $version,
            'recordCount' => $recordCount,
            'speedKnownCount' => $speedKnown,
            'speedCoverage' => round($speedKnown / $recordCount, 4),
            'assetBytes' => strlen($datasetBytes),
            'assetSha256' => $assetSha,
            'manifestBytes' => strlen($manifestBytes),
            'manifestSha256' => hash('sha256', $manifestBytes),
            'asOf' => $asOfDate,
            'outputDirectory' => $outputDirectory,
            'acceptedImportId' => $import->id,
            'sourceSnapshotSha256' => $import->snapshot_sha,
            'exclusions' => $exclusions,
            'nonOperatingPublishedCount' => count(array_filter($records, fn (array $record): bool => $record['operationStatus'] !== 'Operando')),
            'reportedSpeedInventedCount' => count(array_filter($records, fn (array $record): bool => $record['rawSpeed'] === '37' && $record['reportedSpeedKmh'] === 37)),
        ];
    }

    /** @param array<string,int> $exclusions */
    private function exclude(array &$exclusions, string $reason): void
    {
        $exclusions[$reason] = ($exclusions[$reason] ?? 0) + 1;
    }

    private function defaultVersion(AnsvCameraImport $import, string $asOfDate): string
    {
        return str_replace('-', '.', $asOfDate).'-ansv-'.substr($import->snapshot_sha, 0, 12);
    }

    private function validateVersion(string $version): void
    {
        if (! preg_match('/^(?<year>\d{4})\.(?<month>\d{2})\.(?<day>\d{2})(?:-[a-z0-9.-]+)?$/', $version, $matches)) {
            throw new DomainException('Camera dataset version is invalid.');
        }

        $year = (int) $matches['year'];
        $month = (int) $matches['month'];
        $day = (int) $matches['day'];
        if ($year < 1 || ! checkdate($month, $day, $year)) {
            throw new DomainException('Camera dataset version is invalid.');
        }
    }

    private function importKey(AnsvCameraImport $import): string
    {
        return 'ansv:'.$import->snapshot_sha;
    }

    private function matchesVerifiedSourceRow(Camera $camera, AnsvCameraImportRow $sourceRow): bool
    {
        return $camera->external_id === $sourceRow->source_row_identity
            && round((float) $camera->lat, 7) === round((float) $sourceRow->lat, 7)
            && round((float) $camera->lon, 7) === round((float) $sourceRow->lon, 7)
            && $camera->direction === $sourceRow->address
            && $camera->operation_status === $sourceRow->operation_status
            && $camera->traffic_authority === $sourceRow->traffic_authority
            && $camera->installation_type === $sourceRow->installation_type
            && $camera->equipment_name === $sourceRow->equipment_name
            && ($camera->raw_infraction_codes ?? []) === ($sourceRow->raw_infraction_codes ?? [])
            && $camera->raw_speed === $sourceRow->raw_speed
            && $camera->source_snapshot_sha === $sourceRow->import->snapshot_sha;
    }

    /** @param array<string,mixed> $payload */
    private function canonicalJson(array $payload): string
    {
        return json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)."\n";
    }

    /** @param list<array<string,mixed>> $records */
    private function validateRecords(array $records, AnsvCameraImport $import, string $asOfDate): void
    {
        $cameraIds = [];
        $sourceRowIds = [];
        $speedKnown = 0;

        foreach ($records as $record) {
            $cameraId = (string) ($record['cameraId'] ?? '');
            $sourceRowId = (string) ($record['sourceRowId'] ?? '');
            if ($cameraId === '' || isset($cameraIds[$cameraId])) {
                throw new DomainException('Camera dataset contains duplicate or empty camera IDs.');
            }
            if ($sourceRowId === '' || isset($sourceRowIds[$sourceRowId])) {
                throw new DomainException('Camera dataset contains duplicate or empty source row IDs.');
            }
            $cameraIds[$cameraId] = true;
            $sourceRowIds[$sourceRowId] = true;

            $lat = $record['lat'] ?? null;
            $lon = $record['lon'] ?? null;
            if (! is_numeric($lat) || ! is_numeric($lon) || $lat < -4.5 || $lat > 13.5 || $lon < -82.5 || $lon > -66.0) {
                throw new DomainException('Camera dataset contains coordinates outside Colombia bounds.');
            }
            if (($record['operationStatus'] ?? null) !== 'Operando') {
                throw new DomainException('Camera dataset contains a non-operating camera.');
            }
            if (trim((string) ($record['address'] ?? '')) === '' || trim((string) ($record['trafficAuthority'] ?? '')) === '') {
                throw new DomainException('Camera dataset contains missing address or authority.');
            }
            $speed = $record['reportedSpeedKmh'] ?? null;
            if ($speed !== null) {
                if (! is_int($speed) || $speed < 1 || $speed > 200) {
                    throw new DomainException('Camera dataset contains invalid reported speed.');
                }
                $speedKnown++;
            }
            if (($record['rawSpeed'] ?? null) === '37' && $speed === 37) {
                throw new DomainException('Camera dataset contains an invented raw 37 speed.');
            }
            if (($record['sourceFetchedAt'] ?? null) !== $import->source_fetched_at?->toIso8601String()) {
                throw new DomainException('Camera dataset contains mismatched source snapshot metadata.');
            }
            $validFrom = $record['validFrom'] ?? null;
            $validUntil = $record['validUntil'] ?? null;
            if ($validFrom !== null && $validFrom > $asOfDate) {
                throw new DomainException('Camera dataset contains future validFrom values.');
            }
            if ($validUntil !== null && $validUntil < $asOfDate) {
                throw new DomainException('Camera dataset contains expired validUntil values.');
            }
        }

        if ($speedKnown !== count(array_filter($records, fn (array $record): bool => $record['reportedSpeedKmh'] !== null))) {
            throw new DomainException('Camera dataset speed count is inconsistent.');
        }
    }

    private function publishPair(string $outputDirectory, string $datasetBytes, string $manifestBytes): void
    {
        File::ensureDirectoryExists($outputDirectory);
        if (! is_dir($outputDirectory) || ! is_writable($outputDirectory)) {
            throw new DomainException('Camera dataset output directory is not writable.');
        }

        $datasetPath = $outputDirectory.DIRECTORY_SEPARATOR.'cameras_v1.json';
        $manifestPath = $outputDirectory.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json';
        $token = bin2hex(random_bytes(8));
        $datasetTemp = $datasetPath.'.tmp-'.$token;
        $manifestTemp = $manifestPath.'.tmp-'.$token;
        $previousDataset = File::exists($datasetPath) ? File::get($datasetPath) : null;
        $previousManifest = File::exists($manifestPath) ? File::get($manifestPath) : null;

        try {
            if (File::put($datasetTemp, $datasetBytes) === false || File::put($manifestTemp, $manifestBytes) === false) {
                throw new RuntimeException('Camera dataset temporary files could not be written.');
            }
            $this->fail('after_temp_files');

            if (File::exists($datasetPath)) {
                File::delete($datasetPath);
            }
            if (! rename($datasetTemp, $datasetPath)) {
                throw new RuntimeException('Camera dataset file could not be published.');
            }
            $this->fail('after_dataset_replace');
            $this->fail('before_manifest_replace');

            if (File::exists($manifestPath)) {
                File::delete($manifestPath);
            }
            if (! rename($manifestTemp, $manifestPath)) {
                throw new RuntimeException('Camera dataset manifest could not be published.');
            }
        } catch (Throwable $throwable) {
            File::delete([$datasetTemp, $manifestTemp]);
            if ($previousDataset === null) {
                File::delete($datasetPath);
            } elseif (File::put($datasetPath, $previousDataset) === false) {
                throw new RuntimeException('Previous camera dataset could not be restored.', 0, $throwable);
            }
            if ($previousManifest === null) {
                File::delete($manifestPath);
            } elseif (File::put($manifestPath, $previousManifest) === false) {
                throw new RuntimeException('Previous camera dataset manifest could not be restored.', 0, $throwable);
            }

            throw $throwable;
        } finally {
            File::delete([$datasetTemp, $manifestTemp]);
        }
    }

    private function fail(string $point): void
    {
        if (self::$failureHook !== null) {
            (self::$failureHook)($point);
        }
    }
}
