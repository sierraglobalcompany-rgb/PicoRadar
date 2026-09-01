<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Models\AnsvCameraImport;
use App\Models\AnsvCameraImportRow;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Facades\File;

class CameraMobileDatasetPublisher
{
    public function __construct(private readonly CameraContractReadinessService $readiness) {}

    public function publish(string $outputDirectory, string $version, CarbonImmutable $generatedAt, CarbonImmutable $asOf, ?int $importId = null, bool $latestApproved = false): array
    {
        if (! preg_match('/^\d{4}\.\d{2}\.\d{2}[-a-z0-9.]*$/', $version)) {
            throw new DomainException('Camera dataset version is invalid.');
        }
        if ($importId === null && ! $latestApproved) {
            throw new DomainException('Explicit approved ANSV import selection is required.');
        }

        $query = AnsvCameraImport::query()->with('source')->where('status', 'approved');
        $import = $importId !== null
            ? $query->whereKey($importId)->first()
            : $query->latest('source_fetched_at')->first();
        if ($import === null) {
            throw new DomainException('No approved ANSV camera import is available for publication.');
        }

        $records = [];
        $speedKnown = 0;
        $exclusions = [];

        AnsvCameraImportRow::query()
            ->where('ansv_camera_import_id', $import->id)
            ->where('active_public_candidate', true)
            ->where('review_state', 'OK')
            ->with(['camera', 'import'])
            ->orderBy('source_row_identity')
            ->each(function (AnsvCameraImportRow $sourceRow) use (&$records, &$speedKnown, &$exclusions, $asOf): void {
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
                if ($sourceRow->operation_started_on !== null && CarbonImmutable::parse($sourceRow->operation_started_on)->isAfter($asOf)) {
                    $this->exclude($exclusions, 'future_operation_window');

                    return;
                }
                $operationEndsOn = $sourceRow->operation_extension_ends_on ?? $sourceRow->operation_initial_ends_on;
                if ($operationEndsOn !== null && CarbonImmutable::parse($operationEndsOn)->isBefore($asOf)) {
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

        $dataset = [
            'schemaVersion' => 1,
            'datasetKey' => 'traffic_cameras',
            'version' => $version,
            'generatedAt' => $generatedAt->toIso8601String(),
            'source' => [
                'title' => $import->source?->title ?? 'ANSV ubicaciones aprobadas de fotodetección',
                'url' => $import->source_url,
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
            'sourceSnapshotSha256' => $import->snapshot_sha,
            'acceptedImportId' => $import->id,
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
                'asOf' => $asOf->toDateString(),
            ],
        ];
        $manifestBytes = $this->canonicalJson($manifest);

        File::ensureDirectoryExists($outputDirectory);
        File::put($outputDirectory.DIRECTORY_SEPARATOR.'cameras_v1.json', $datasetBytes);
        File::put($outputDirectory.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json', $manifestBytes);

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

    /** @param array<string,mixed> $payload */
    private function canonicalJson(array $payload): string
    {
        return json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)."\n";
    }
}
