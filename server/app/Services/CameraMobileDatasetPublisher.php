<?php

namespace App\Services;

use App\Enums\CameraStatus;
use App\Models\AnsvCameraImportRow;
use App\Models\Camera;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Facades\File;

class CameraMobileDatasetPublisher
{
    public function __construct(private readonly CameraContractReadinessService $readiness) {}

    public function publish(string $outputDirectory, string $version, CarbonImmutable $generatedAt, CarbonImmutable $asOf): array
    {
        if (! preg_match('/^\d{4}\.\d{2}\.\d{2}[-a-z0-9.]*$/', $version)) {
            throw new DomainException('Camera dataset version is invalid.');
        }

        $records = [];
        $speedKnown = 0;
        $latestSourceFetchedAt = null;
        $sourceSnapshotSha = null;

        Camera::query()
            ->where('status', CameraStatus::Active)
            ->where('operation_status', 'Operando')
            ->with(['source', 'jurisdiction.primaryGeographicUnit', 'geographicUnit'])
            ->orderBy('camera_id')
            ->each(function (Camera $camera) use (&$records, &$speedKnown, &$latestSourceFetchedAt, &$sourceSnapshotSha, $asOf): void {
                $assessment = $this->readiness->assess($camera);
                if (! $assessment['readyForFutureDataset']) {
                    throw new DomainException("Camera {$camera->camera_id} is not ready for publication: ".implode(', ', $assessment['reasons']));
                }
                if ($camera->operation_status !== 'Operando') {
                    throw new DomainException("Camera {$camera->camera_id} is not operating.");
                }
                if ($camera->operation_started_on !== null && CarbonImmutable::parse($camera->operation_started_on)->isAfter($asOf)) {
                    throw new DomainException("Camera {$camera->camera_id} operation starts in the future.");
                }
                $operationEndsOn = $camera->operation_extension_ends_on ?? $camera->operation_initial_ends_on;
                if ($operationEndsOn !== null && CarbonImmutable::parse($operationEndsOn)->isBefore($asOf)) {
                    throw new DomainException("Camera {$camera->camera_id} operation window is expired.");
                }

                $sourceRow = AnsvCameraImportRow::query()
                    ->where('camera_id', $camera->id)
                    ->where('active_public_candidate', true)
                    ->latest('id')
                    ->first();
                if ($sourceRow === null) {
                    throw new DomainException("Camera {$camera->camera_id} has no accepted ANSV source row.");
                }

                $speed = $camera->speed_limit_verified ? $camera->speed_limit : null;
                $speedKnown += $speed !== null ? 1 : 0;
                $latestSourceFetchedAt = max(
                    $latestSourceFetchedAt ?? $camera->source_fetched_at?->toIso8601String(),
                    $camera->source_fetched_at?->toIso8601String(),
                );
                $sourceSnapshotSha ??= $camera->source_snapshot_sha;

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
                    'sourceFetchedAt' => $camera->source_fetched_at?->toIso8601String(),
                    'validFrom' => $camera->operation_started_on?->toDateString(),
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
                'title' => 'ANSV ubicaciones aprobadas de fotodetección',
                'url' => 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
                'snapshotSha256' => $sourceSnapshotSha,
                'fetchedAt' => $latestSourceFetchedAt,
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
            'sourceSnapshotSha256' => $sourceSnapshotSha,
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
                'readiness' => 'ready',
            ],
            'freshness' => [
                'sourceFetchedAt' => $latestSourceFetchedAt,
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
            'nonOperatingPublishedCount' => count(array_filter($records, fn (array $record): bool => $record['operationStatus'] !== 'Operando')),
            'reportedSpeedInventedCount' => count(array_filter($records, fn (array $record): bool => $record['rawSpeed'] === '37' && $record['reportedSpeedKmh'] === 37)),
        ];
    }

    /** @param array<string,mixed> $payload */
    private function canonicalJson(array $payload): string
    {
        return json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)."\n";
    }
}
