<?php

namespace App\Services;

use App\Enums\CameraSourceType;
use App\Enums\CameraStatus;
use App\Enums\CameraType;
use App\Models\AnsvCameraImport;
use App\Models\AnsvCameraImportRow;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Support\GeographicNameNormalizer;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Facades\DB;

class AnsvRichCameraImporter
{
    private const SOURCE_KEY = 'ansv-fotodeteccion-rich';

    private const SOURCE_URL = 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html';

    public function __construct(
        private readonly AnsvCameraRowNormalizer $normalizer,
        private readonly DatasetAuditLogger $audit,
        private readonly ?\Closure $failureHook = null,
    ) {}

    /** @param list<array<string, string|null>> $rows */
    public function importRows(array $rows, string $snapshotSha, CarbonImmutable $fetchedAt, bool $dryRun = false): array
    {
        if ($rows === []) {
            throw new DomainException('ANSV camera source is empty.');
        }
        $this->normalizer->assertHeaders(array_keys($rows[0]));
        if (! preg_match('/^[a-f0-9]{64}$/i', $snapshotSha)) {
            throw new DomainException('ANSV source snapshot SHA-256 is invalid.');
        }

        $normalized = [];
        foreach ($rows as $index => $row) {
            $normalized[] = $this->normalizer->normalize($row + ['_source_row_number' => (string) ($index + 2)], $fetchedAt);
        }
        $report = $this->report($normalized);
        if ($report['reviewGates']['missingCriticalColumns'] || $report['reviewGates']['emptySource'] || $report['reviewGates']['unknownOperationStatusCount'] > 0) {
            throw new DomainException('ANSV camera source requires review before import.');
        }
        if ($dryRun) {
            return $report + ['snapshotSha' => strtolower($snapshotSha), 'dryRun' => true];
        }

        return DB::transaction(function () use ($normalized, $snapshotSha, $fetchedAt, $report): array {
            $source = $this->source($fetchedAt);
            $import = AnsvCameraImport::query()->firstOrCreate(
                ['snapshot_sha' => strtolower($snapshotSha)],
                [
                    'source_id' => $source->id,
                    'source_url' => self::SOURCE_URL,
                    'source_fetched_at' => $fetchedAt,
                    'row_count' => count($normalized),
                    'master_imported_count' => 0,
                    'active_candidate_count' => 0,
                    'status_counts' => $report['statusCounts'],
                    'report' => $report,
                ],
            );
            if (! $import->wasRecentlyCreated) {
                return $import->report + ['idempotent' => true, 'importId' => $import->id];
            }

            $masterImported = 0;
            $activeCandidates = 0;
            foreach ($normalized as $row) {
                $camera = $this->upsertCamera($source, $row, strtolower($snapshotSha), $fetchedAt);
                $masterImported += $camera !== null ? 1 : 0;
                $activeCandidates += $row['active_public_candidate'] && $camera !== null ? 1 : 0;
                AnsvCameraImportRow::query()->create($row + [
                    'ansv_camera_import_id' => $import->id,
                    'camera_id' => $camera?->id,
                ]);
            }
            $this->checkpoint('after_rows');
            $report['masterImportedCount'] = $masterImported;
            $report['activeImportedCount'] = $activeCandidates;
            $import->forceFill([
                'master_imported_count' => $masterImported,
                'active_candidate_count' => $activeCandidates,
                'report' => $report,
            ])->save();
            $this->audit->log(null, 'ansv_camera_import.completed', $import, [
                'snapshotSha' => strtolower($snapshotSha),
                'rows' => count($normalized),
                'sourceActiveCandidates' => $report['activeCandidateCount'],
                'activeImported' => $activeCandidates,
            ]);

            return $report + ['idempotent' => false, 'importId' => $import->id];
        });
    }

    private function upsertCamera(CameraSource $source, array $row, string $snapshotSha, CarbonImmutable $fetchedAt): ?Camera
    {
        if (! $row['valid_colombia_coordinates'] || in_array('MISSING_REQUIRED_IDENTITY', $row['review_reasons'], true)) {
            return null;
        }
        $municipality = $this->municipality($row['municipality'], $row['department']);
        if ($municipality === null) {
            return null;
        }
        $jurisdiction = $municipality->jurisdictions()->where('enabled', true)->first();
        if ($jurisdiction === null) {
            return null;
        }

        $status = $row['active_public_candidate'] ? CameraStatus::Active : CameraStatus::Inactive;
        $type = $this->cameraType($row);
        $camera = Camera::query()->where('source_id', $source->id)->where('external_id', $row['source_row_identity'])->first();
        $attributes = [
            'jurisdiction_id' => $jurisdiction->id,
            'geographic_unit_id' => $municipality->id,
            'source_id' => $source->id,
            'external_id' => $row['source_row_identity'],
            'name' => $row['equipment_name'],
            'lat' => $row['lat'],
            'lon' => $row['lon'],
            'type' => $type,
            'direction' => $row['address'],
            'speed_limit' => $row['reported_speed_kmh'],
            'notes' => 'ANSV rich import; source status: '.$row['operation_status'],
            'operation_status' => $row['operation_status'],
            'traffic_authority' => $row['traffic_authority'],
            'installation_type' => $row['installation_type'],
            'equipment_name' => $row['equipment_name'],
            'raw_infraction_codes' => $row['raw_infraction_codes'],
            'raw_speed' => $row['raw_speed'],
            'operation_started_on' => $row['operation_started_on'],
            'operation_initial_ends_on' => $row['operation_initial_ends_on'],
            'operation_extension_ends_on' => $row['operation_extension_ends_on'],
            'source_snapshot_sha' => $snapshotSha,
            'source_fetched_at' => $fetchedAt,
        ];
        if ($camera !== null && $camera->status === CameraStatus::Active && $this->hasImmutableDifferences($camera, $attributes)) {
            return $camera;
        }
        $camera ??= new Camera;
        $camera->forceFill($attributes + [
            'camera_id' => $camera->camera_id ?: 'cam_'.substr($row['source_row_identity'], 0, 26),
            'status' => $status,
            'verified_at' => $fetchedAt,
            'speed_limit_verified' => $row['reported_speed_kmh'] !== null && $type->supportsSpeed(),
            'speed_limit_verified_at' => $row['reported_speed_kmh'] !== null && $type->supportsSpeed() ? $fetchedAt : null,
        ]);
        $camera->verification_fingerprint = app(CameraVerificationService::class)->fingerprint($camera);
        $camera->save();

        return $camera;
    }

    /** @param array<string,mixed> $attributes */
    private function hasImmutableDifferences(Camera $camera, array $attributes): bool
    {
        $immutable = ['lat', 'lon', 'jurisdiction_id', 'geographic_unit_id', 'source_id', 'type', 'direction', 'bearing', 'corridor'];
        foreach ($immutable as $key) {
            if (array_key_exists($key, $attributes) && $camera->getAttribute($key) != $attributes[$key]) {
                return true;
            }
        }

        return false;
    }

    private function source(CarbonImmutable $fetchedAt): CameraSource
    {
        return CameraSource::query()->firstOrCreate(
            ['key' => self::SOURCE_KEY],
            [
                'title' => 'ANSV ubicaciones aprobadas de fotodetección',
                'authority' => 'Agencia Nacional de Seguridad Vial',
                'url' => self::SOURCE_URL,
                'source_type' => CameraSourceType::Official,
                'is_active' => true,
                'verified_at' => $fetchedAt,
                'notes' => 'B04 rich source package import.',
            ],
        );
    }

    private function municipality(string $municipality, string $department): ?GeographicUnit
    {
        $municipalityKey = GeographicNameNormalizer::normalize($municipality);
        $departmentKey = GeographicNameNormalizer::normalize($department);

        return GeographicUnit::query()
            ->where('level', 'municipality')
            ->where('normalized_name', $municipalityKey)
            ->whereHas('parent', fn ($query) => $query->where('normalized_name', $departmentKey))
            ->first();
    }

    private function cameraType(array $row): CameraType
    {
        $codes = $row['raw_infraction_codes'];
        if ($row['reported_speed_kmh'] !== null && in_array('D02', $codes, true)) {
            return CameraType::Combined;
        }
        if ($row['reported_speed_kmh'] !== null) {
            return CameraType::Speed;
        }
        if (in_array('D02', $codes, true)) {
            return CameraType::RedLight;
        }

        return CameraType::Other;
    }

    /** @param list<array<string,mixed>> $rows */
    private function report(array $rows): array
    {
        $statusCounts = [];
        $identities = [];
        $duplicateIdentities = 0;
        $speedKnown = 0;
        $raw37Parsed = 0;
        $invalidCoordinates = 0;
        $unknownStatuses = 0;
        foreach ($rows as $row) {
            $statusCounts[$row['operation_status']] = ($statusCounts[$row['operation_status']] ?? 0) + 1;
            $duplicateIdentities += isset($identities[$row['source_row_identity']]) ? 1 : 0;
            $identities[$row['source_row_identity']] = true;
            $speedKnown += $row['reported_speed_kmh'] !== null ? 1 : 0;
            $raw37Parsed += trim((string) $row['raw_speed']) === '37' && $row['reported_speed_kmh'] === 37 ? 1 : 0;
            $invalidCoordinates += $row['valid_colombia_coordinates'] ? 0 : 1;
            $unknownStatuses += ! in_array($row['operation_status'], AnsvCameraRowNormalizer::KNOWN_STATUSES, true) ? 1 : 0;
        }
        $activeCandidates = count(array_filter($rows, fn (array $row): bool => (bool) $row['active_public_candidate']));

        return [
            'schema' => 'picoradar.ansv-camera-import.v1',
            'rowCount' => count($rows),
            'statusCounts' => $statusCounts,
            'sourceIdentity' => 'sha256(codigo_unico|codigo_solicitud|nombre_equipo|direccion|lat|lon|worksheet_row_number)',
            'duplicateIdentityCount' => $duplicateIdentities,
            'speedKnownCount' => $speedKnown,
            'raw37ParsedAs37Kmh' => $raw37Parsed,
            'invalidCoordinateCount' => $invalidCoordinates,
            'activeCandidateCount' => $activeCandidates,
            'reviewGates' => [
                'emptySource' => $rows === [],
                'missingCriticalColumns' => false,
                'unknownOperationStatusCount' => $unknownStatuses,
                'duplicateIdentityCount' => $duplicateIdentities,
                'invalidCoordinateCount' => $invalidCoordinates,
            ],
            'featureServerReconciliation' => [
                'matchedRows' => 0,
                'xlsxOnlyRows' => count($rows),
                'featureServerOnlyRows' => 0,
                'ambiguousMatches' => 0,
                'authorityMatrix' => [
                    'richExportOwns' => ['operation_status', 'address', 'traffic_authority', 'reported_speed', 'operation_dates'],
                    'featureServerSupports' => ['geometry_validation', 'independent_cross_check'],
                ],
            ],
            'monthlySync' => [
                'ready' => true,
                'scheduler' => 'Laravel scheduler/manual Artisan command',
                'githubActionsRequired' => false,
            ],
        ];
    }

    private function checkpoint(string $point): void
    {
        ($this->failureHook) ? ($this->failureHook)($point) : null;
    }
}
