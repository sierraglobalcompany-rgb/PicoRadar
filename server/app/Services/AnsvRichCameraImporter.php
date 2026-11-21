<?php

namespace App\Services;

use App\Enums\CameraSourceType;
use App\Enums\CameraStatus;
use App\Enums\CameraType;
use App\Enums\JurisdictionKind;
use App\Models\AnsvCameraImport;
use App\Models\AnsvCameraImportRow;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Support\GeographicNameNormalizer;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class AnsvRichCameraImporter
{
    private const SOURCE_KEY = 'ansv-fotodeteccion-rich';

    private const SOURCE_URL = 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html';

    public function __construct(
        private readonly AnsvCameraRowNormalizer $normalizer,
        private readonly DatasetAuditLogger $audit,
        private readonly CameraRegistryService $registry,
        private readonly ?\Closure $failureHook = null,
    ) {}

    /** @param list<array<string, string|null>> $rows */
    public function importRows(array $rows, string $snapshotSha, CarbonImmutable $fetchedAt, bool $dryRun = false, ?array $officialGridRows = null): array
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
        $normalized = $this->collapseExactDuplicateSourceRows($normalized);
        $normalized = $this->markIdentityCollisions($normalized);
        $report = $this->report($normalized, $officialGridRows);
        if ($dryRun) {
            return $report + ['snapshotSha' => strtolower($snapshotSha), 'dryRun' => true];
        }

        return DB::transaction(function () use ($normalized, $snapshotSha, $fetchedAt, $report): array {
            $source = $this->source($fetchedAt);
            $sourceReviewReasons = $this->sourceReviewReasons($source);
            if ($sourceReviewReasons !== []) {
                $report['reviewRequired'] = true;
                $report['sourceReviewReasons'] = $sourceReviewReasons;
                $report['reviewGates']['sourceConfigurationReviewRequired'] = true;
            }
            $previousImport = AnsvCameraImport::query()
                ->where('source_id', $source->id)
                ->where('snapshot_sha', '!=', strtolower($snapshotSha))
                ->latest('source_fetched_at')
                ->first();
            $report['snapshotDiff'] = $this->snapshotDiff($previousImport, $normalized);
            $import = AnsvCameraImport::query()->firstOrCreate(
                ['snapshot_sha' => strtolower($snapshotSha)],
                [
                    'source_id' => $source->id,
                    'source_url' => self::SOURCE_URL,
                    'source_fetched_at' => $fetchedAt,
                    'status' => $report['reviewRequired'] ? 'review_required' : 'analyzed',
                    'analyzed_at' => now(),
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
            $activeSourceChanges = 0;
            $activeDroppedDueToPicoJurisdiction = 0;
            $dropReasons = [];
            foreach ($normalized as $row) {
                $upsert = $this->upsertCamera($source, $row, strtolower($snapshotSha), $fetchedAt);
                $camera = $upsert['camera'];
                $activeSourceChanges += $upsert['sourceDelta'] !== [] && $row['active_public_candidate'] ? 1 : 0;
                $activeDroppedDueToPicoJurisdiction += $upsert['dropReason'] === 'PICO_JURISDICTION_NOT_ENABLED' ? 1 : 0;
                if ($upsert['dropReason'] !== null) {
                    $dropReasons[$upsert['dropReason']] = ($dropReasons[$upsert['dropReason']] ?? 0) + 1;
                }
                $row['review_reasons'] = array_values(array_unique(array_merge($row['review_reasons'], $upsert['reviewReasons'])));
                $row['review_state'] = $row['review_reasons'] === [] ? 'OK' : 'REVIEW_REQUIRED';
                $masterImported += $camera !== null ? 1 : 0;
                $activeCandidates += $row['active_public_candidate'] && $camera !== null ? 1 : 0;
                AnsvCameraImportRow::query()->create($row + [
                    'ansv_camera_import_id' => $import->id,
                    'camera_id' => $camera?->id,
                    'source_delta' => $upsert['sourceDelta'] ?: null,
                ]);
            }
            $this->checkpoint('after_rows');
            $report['masterImportedCount'] = $masterImported;
            $report['activeImportedCount'] = $activeCandidates;
            $report['activeSourceChangeReviewRequiredCount'] = $activeSourceChanges;
            $report['activeCameraSourceChangesSilentlyIgnoredCount'] = 0;
            $report['operatingRowsDroppedDueToPicoJurisdiction'] = $activeDroppedDueToPicoJurisdiction;
            $report['runtimeDropReasons'] = $dropReasons;
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

    /**
     * @return array{camera:?Camera, sourceDelta:array<string,array{current:mixed,incoming:mixed}>, reviewReasons:list<string>, dropReason:?string}
     */
    private function upsertCamera(CameraSource $source, array $row, string $snapshotSha, CarbonImmutable $fetchedAt): array
    {
        if (! $row['valid_colombia_coordinates'] || in_array('MISSING_REQUIRED_IDENTITY', $row['review_reasons'], true)) {
            return ['camera' => null, 'sourceDelta' => [], 'reviewReasons' => [], 'dropReason' => 'INVALID_SOURCE_ROW'];
        }
        $municipality = $this->municipality($row['municipality'], $row['department']);
        if ($municipality === null) {
            return ['camera' => null, 'sourceDelta' => [], 'reviewReasons' => ['UNMAPPED_GEOGRAPHY'], 'dropReason' => 'UNMAPPED_GEOGRAPHY'];
        }
        $jurisdiction = $municipality->jurisdictions()->where('enabled', true)->first()
            ?? $this->ensureCameraRegistryJurisdiction($municipality);
        if ($jurisdiction === null) {
            return ['camera' => null, 'sourceDelta' => [], 'reviewReasons' => ['CAMERA_REGISTRY_JURISDICTION_UNAVAILABLE'], 'dropReason' => 'CAMERA_REGISTRY_JURISDICTION_UNAVAILABLE'];
        }

        if (in_array('IDENTITY_COLLISION_REVIEW_REQUIRED', $row['review_reasons'], true)) {
            return ['camera' => null, 'sourceDelta' => [], 'reviewReasons' => [], 'dropReason' => 'IDENTITY_COLLISION_REVIEW_REQUIRED'];
        }

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
        $sourceDelta = $camera !== null ? $this->sourceDelta($camera, $attributes) : [];
        if ($camera !== null && in_array($camera->status, [CameraStatus::Verified, CameraStatus::Active, CameraStatus::Inactive], true) && $this->hasImmutableDifferences($camera, $attributes)) {
            return [
                'camera' => $camera,
                'sourceDelta' => $sourceDelta,
                'reviewReasons' => ['ACTIVE_CAMERA_SOURCE_CHANGE_REVIEW_REQUIRED'],
                'dropReason' => null,
            ];
        }
        if ($camera === null) {
            $camera = $this->registry->create($attributes + ['camera_id' => 'cam_'.substr($row['source_row_identity'], 0, 26)]);
        } elseif (in_array($camera->status, [CameraStatus::Draft, CameraStatus::Rejected], true)) {
            $camera = $this->registry->updateDraft($camera, $attributes);
        }

        return ['camera' => $camera, 'sourceDelta' => $sourceDelta, 'reviewReasons' => [], 'dropReason' => null];
    }

    /** @param list<array<string,mixed>> $rows @return list<array<string,mixed>> */
    private function collapseExactDuplicateSourceRows(array $rows): array
    {
        $byRawRow = [];
        $collapsed = [];
        foreach ($rows as $row) {
            $key = $this->canonicalSourceRowHash($row);
            if (! isset($byRawRow[$key])) {
                $row['duplicate_source_row_count'] = 1;
                $row['raw']['_duplicate_source_row_numbers'] = [$row['raw']['_source_row_number'] ?? null];
                $byRawRow[$key] = count($collapsed);
                $collapsed[] = $row;

                continue;
            }

            $index = $byRawRow[$key];
            $collapsed[$index]['duplicate_source_row_count']++;
            $collapsed[$index]['raw']['_duplicate_source_row_numbers'][] = $row['raw']['_source_row_number'] ?? null;
        }

        return $collapsed;
    }

    /** @param list<array<string,mixed>> $rows @return list<array<string,mixed>> */
    private function markIdentityCollisions(array $rows): array
    {
        $counts = [];
        foreach ($rows as $row) {
            $counts[$row['source_row_identity']] = ($counts[$row['source_row_identity']] ?? 0) + 1;
        }
        foreach ($rows as $index => $row) {
            $identity = $row['source_row_identity'];
            if (($counts[$identity] ?? 0) < 2) {
                continue;
            }
            $rows[$index]['review_reasons'][] = 'IDENTITY_COLLISION_REVIEW_REQUIRED';
            $rows[$index]['review_state'] = 'REVIEW_REQUIRED';
            $rows[$index]['raw']['_base_source_row_identity'] = $identity;
        }

        return $rows;
    }

    /** @param array<string,mixed> $row */
    private function canonicalSourceRowHash(array $row): string
    {
        $raw = $row['raw'] ?? [];
        unset($raw['_source_row_number']);
        ksort($raw);

        return hash('sha256', json_encode($raw, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR));
    }

    /** @param array<string,mixed> $attributes */
    private function hasImmutableDifferences(Camera $camera, array $attributes): bool
    {
        $immutable = ['lat', 'lon', 'jurisdiction_id', 'geographic_unit_id', 'source_id', 'type', 'direction', 'bearing', 'corridor'];
        foreach ($immutable as $key) {
            if (array_key_exists($key, $attributes) && $this->normalizeForDelta($camera->getAttribute($key)) !== $this->normalizeForDelta($attributes[$key])) {
                return true;
            }
        }

        return false;
    }

    /** @param array<string,mixed> $attributes @return array<string,array{current:mixed,incoming:mixed}> */
    private function sourceDelta(Camera $camera, array $attributes): array
    {
        $fields = [
            'jurisdiction_id',
            'geographic_unit_id',
            'lat',
            'lon',
            'type',
            'direction',
            'speed_limit',
            'operation_status',
            'traffic_authority',
            'installation_type',
            'equipment_name',
            'raw_infraction_codes',
            'raw_speed',
            'operation_started_on',
            'operation_initial_ends_on',
            'operation_extension_ends_on',
        ];
        $delta = [];
        foreach ($fields as $field) {
            if (! array_key_exists($field, $attributes)) {
                continue;
            }
            $current = $this->normalizeForDelta($camera->getAttribute($field));
            $incoming = $this->normalizeForDelta($attributes[$field]);
            if ($current !== $incoming) {
                $delta[$field] = ['current' => $current, 'incoming' => $incoming];
            }
        }

        return $delta;
    }

    private function normalizeForDelta(mixed $value): mixed
    {
        if ($value instanceof \BackedEnum) {
            return $value->value;
        }
        if ($value instanceof \DateTimeInterface) {
            return $value->format('Y-m-d');
        }
        if (is_float($value)) {
            return round($value, 7);
        }
        if (is_numeric($value) && is_string($value) && preg_match('/^-?\d+\.\d+$/', $value) === 1) {
            return round((float) $value, 7);
        }
        if (is_array($value)) {
            ksort($value);

            return $value;
        }

        return $value;
    }

    private function ensureCameraRegistryJurisdiction(GeographicUnit $municipality): Jurisdiction
    {
        $key = 'camera-registry-'.Str::slug((string) $municipality->code);
        $jurisdiction = Jurisdiction::query()->firstOrCreate(
            ['key' => $key],
            [
                'name' => 'Camera registry '.$municipality->name,
                'kind' => JurisdictionKind::City,
                'primary_geographic_unit_id' => $municipality->id,
                'enabled' => true,
                'timezone' => 'America/Bogota',
                'metadata' => ['scope' => 'camera_registry', 'source' => 'dane_geography'],
            ],
        );
        if (! $jurisdiction->geographicUnits()->whereKey($municipality->id)->exists()) {
            $jurisdiction->geographicUnits()->attach($municipality->id);
        }

        return $jurisdiction->refresh();
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

    /** @return list<string> */
    private function sourceReviewReasons(CameraSource $source): array
    {
        $reasons = [];
        if ($source->authority !== 'Agencia Nacional de Seguridad Vial') {
            $reasons[] = 'ANSV_SOURCE_AUTHORITY_CHANGED';
        }
        if ($source->url !== self::SOURCE_URL) {
            $reasons[] = 'ANSV_SOURCE_URL_CHANGED';
        }
        if ($source->source_type !== CameraSourceType::Official) {
            $reasons[] = 'ANSV_SOURCE_TYPE_CHANGED';
        }
        if (! $source->is_active) {
            $reasons[] = 'ANSV_SOURCE_INACTIVE';
        }
        if ($source->verified_at === null) {
            $reasons[] = 'ANSV_SOURCE_UNVERIFIED';
        }

        return $reasons;
    }

    private function municipality(string $municipality, string $department): ?GeographicUnit
    {
        [$municipality, $department] = $this->ansvGeographyAlias($municipality, $department);
        $municipalityKey = GeographicNameNormalizer::normalize($municipality);
        $departmentKey = GeographicNameNormalizer::normalize($department);

        return GeographicUnit::query()
            ->where('level', 'municipality')
            ->where('normalized_name', $municipalityKey)
            ->whereHas('parent', fn ($query) => $query->where('normalized_name', $departmentKey))
            ->first();
    }

    /** @return array{0:string,1:string} */
    private function ansvGeographyAlias(string $municipality, string $department): array
    {
        $key = GeographicNameNormalizer::normalize($department).'|'.GeographicNameNormalizer::normalize($municipality);
        $aliases = [
            'bogota d.c|bogota d.c' => ['BOGOTÁ, D.C.', 'BOGOTÁ, D.C.'],
            'valle del cauca|cali' => ['SANTIAGO DE CALI', 'VALLE DEL CAUCA'],
            'n. de santander|cucuta' => ['SAN JOSÉ DE CÚCUTA', 'NORTE DE SANTANDER'],
            'bolivar|cartagena' => ['CARTAGENA DE INDIAS', 'BOLÍVAR'],
            'n. de santander|los patios' => ['LOS PATIOS', 'NORTE DE SANTANDER'],
            'n. de santander|ocana' => ['OCAÑA', 'NORTE DE SANTANDER'],
            'sucre|tolu viejo' => ['SAN JOSÉ DE TOLUVIEJO', 'SUCRE'],
            'valle del cauca|san pedro (valle)' => ['SAN PEDRO', 'VALLE DEL CAUCA'],
            'antioquia|santafe de antioquia' => ['SANTA FÉ DE ANTIOQUIA', 'ANTIOQUIA'],
            'n. de santander|villa del rosario' => ['VILLA DEL ROSARIO', 'NORTE DE SANTANDER'],
            'cauca|piendamo' => ['PIENDAMÓ - TUNÍA', 'CAUCA'],
        ];

        return $aliases[$key] ?? [$municipality, $department];
    }

    private function cameraType(array $row): CameraType
    {
        if ($row['reported_speed_kmh'] !== null) {
            return CameraType::Speed;
        }

        return CameraType::Other;
    }

    /** @param list<array<string,mixed>> $rows @return array<string,mixed> */
    private function snapshotDiff(?AnsvCameraImport $previousImport, array $rows): array
    {
        if ($previousImport === null) {
            return ['previousImportId' => null, 'addedRows' => count($rows), 'removedRows' => 0, 'changedRows' => 0, 'changes' => []];
        }

        $previous = [];
        foreach ($previousImport->rows as $row) {
            $previous[$row->source_row_identity] = $this->rowSnapshot($row->toArray());
        }
        $current = [];
        foreach ($rows as $row) {
            $current[$row['source_row_identity']] = $this->rowSnapshot($row);
        }

        $changes = [];
        foreach ($current as $identity => $snapshot) {
            if (! isset($previous[$identity])) {
                continue;
            }
            $delta = [];
            foreach ($snapshot as $field => $value) {
                if (($previous[$identity][$field] ?? null) !== $value) {
                    $delta[$field] = ['previous' => $previous[$identity][$field] ?? null, 'current' => $value];
                }
            }
            if ($delta !== []) {
                $changes[$identity] = $delta;
            }
        }

        return [
            'previousImportId' => $previousImport->id,
            'addedRows' => count(array_diff(array_keys($current), array_keys($previous))),
            'removedRows' => count(array_diff(array_keys($previous), array_keys($current))),
            'changedRows' => count($changes),
            'changes' => array_slice($changes, 0, 20, true),
        ];
    }

    /** @param array<string,mixed> $row @return array<string,mixed> */
    private function rowSnapshot(array $row): array
    {
        return [
            'operation_status' => $row['operation_status'] ?? null,
            'department' => $row['department'] ?? null,
            'municipality' => $row['municipality'] ?? null,
            'address' => $row['address'] ?? null,
            'lat' => $this->normalizeForDelta($row['lat'] ?? null),
            'lon' => $this->normalizeForDelta($row['lon'] ?? null),
            'traffic_authority' => $row['traffic_authority'] ?? null,
            'jurisdiction_label' => $row['jurisdiction_label'] ?? null,
            'raw_infraction_codes' => $this->normalizeForDelta($row['raw_infraction_codes'] ?? []),
            'raw_speed' => $row['raw_speed'] ?? null,
            'reported_speed_kmh' => $row['reported_speed_kmh'] ?? null,
            'technology' => $row['technology'] ?? null,
            'installation_type' => $row['installation_type'] ?? null,
            'equipment_name' => $row['equipment_name'] ?? null,
            'approval_date' => $this->normalizeForDelta($row['approval_date'] ?? null),
            'operation_started_on' => $this->normalizeForDelta($row['operation_started_on'] ?? null),
            'operation_initial_ends_on' => $this->normalizeForDelta($row['operation_initial_ends_on'] ?? null),
            'operation_extension_ends_on' => $this->normalizeForDelta($row['operation_extension_ends_on'] ?? null),
            'active_public_candidate' => (bool) ($row['active_public_candidate'] ?? false),
        ];
    }

    /** @param list<array<string,mixed>> $rows @param list<array<string,mixed>>|null $officialGridRows */
    private function report(array $rows, ?array $officialGridRows): array
    {
        $statusCounts = [];
        $identities = [];
        $duplicateIdentities = 0;
        $speedKnown = 0;
        $raw37Parsed = 0;
        $rawDate37StoredAs1900 = 0;
        $dateAnomalyCount = 0;
        $activeDateAnomalyCount = 0;
        $exactDuplicateSourceRows = 0;
        $invalidCoordinates = 0;
        $unknownStatuses = 0;
        $codigoUnicoKeys = [];
        $codigoSolicitudKeys = [];
        $stableIdentityKeys = [];
        foreach ($rows as $row) {
            $statusCounts[$row['operation_status']] = ($statusCounts[$row['operation_status']] ?? 0) + 1;
            $duplicateIdentities += isset($identities[$row['source_row_identity']]) ? 1 : 0;
            $identities[$row['source_row_identity']] = true;
            $codigoUnicoKeys[] = [(string) ($row['codigo_unico'] ?? '')];
            $codigoSolicitudKeys[] = [(string) ($row['codigo_unico'] ?? ''), (string) ($row['codigo_solicitud'] ?? '')];
            $stableIdentityKeys[] = [(string) ($row['codigo_unico'] ?? ''), (string) ($row['codigo_solicitud'] ?? ''), (string) ($row['equipment_name'] ?? '')];
            $speedKnown += $row['reported_speed_kmh'] !== null ? 1 : 0;
            $raw37Parsed += trim((string) $row['raw_speed']) === '37' && $row['reported_speed_kmh'] === 37 ? 1 : 0;
            $dateAnomalies = $row['date_anomalies'] ?? [];
            $dateAnomalyCount += count($dateAnomalies);
            $activeDateAnomalyCount += $row['active_public_candidate'] ? count($dateAnomalies) : 0;
            $rawDate37StoredAs1900 += count(array_filter($dateAnomalies, fn (array $anomaly): bool => ($anomaly['raw'] ?? null) === '37')) > 0 && ($row['operation_started_on'] ?? null) === '1900-02-05' ? 1 : 0;
            $exactDuplicateSourceRows += max(0, (int) ($row['duplicate_source_row_count'] ?? 1) - 1);
            $invalidCoordinates += $row['valid_colombia_coordinates'] ? 0 : 1;
            $unknownStatuses += ! in_array($row['operation_status'], AnsvCameraRowNormalizer::KNOWN_STATUSES, true) ? 1 : 0;
        }
        $activeCandidates = count(array_filter($rows, fn (array $row): bool => (bool) $row['active_public_candidate']));
        $reviewRequired = $rows === [] || $unknownStatuses > 0 || $invalidCoordinates > 0 || $duplicateIdentities > 0 || $dateAnomalyCount > 0;

        return [
            'schema' => 'picoradar.ansv-camera-import.v1',
            'rowCount' => count($rows),
            'statusCounts' => $statusCounts,
            'sourceIdentity' => 'sha256(codigo_unico|codigo_solicitud|nombre_equipo); exact duplicate source rows collapse; non-identical official identity collisions require review',
            'sourceIdentityExcludedMutableFields' => ['direccion', 'latitud', 'longitud', 'worksheet_row_number', 'operation_status', 'velocidad'],
            'duplicateIdentityCount' => $duplicateIdentities,
            'exactDuplicateSourceRowCount' => $exactDuplicateSourceRows,
            'duplicateIdentitySignals' => [
                'codigoUnicoOnly' => $this->duplicateKeyCount($codigoUnicoKeys),
                'codigoUnicoCodigoSolicitud' => $this->duplicateKeyCount($codigoSolicitudKeys),
                'codigoUnicoCodigoSolicitudNombreEquipo' => $this->duplicateKeyCount($stableIdentityKeys),
            ],
            'speedKnownCount' => $speedKnown,
            'raw37ParsedAs37Kmh' => $raw37Parsed,
            'rawDate37StoredAs1900Date' => $rawDate37StoredAs1900,
            'dateAnomalyCount' => $dateAnomalyCount,
            'activeDateAnomalyCount' => $activeDateAnomalyCount,
            'invalidCoordinateCount' => $invalidCoordinates,
            'activeCandidateCount' => $activeCandidates,
            'reviewRequired' => $reviewRequired,
            'reviewGates' => [
                'emptySource' => $rows === [],
                'missingCriticalColumns' => false,
                'unknownOperationStatusCount' => $unknownStatuses,
                'duplicateIdentityCount' => $duplicateIdentities,
                'invalidCoordinateCount' => $invalidCoordinates,
                'dateAnomalyCount' => $dateAnomalyCount,
                'activeDateAnomalyCount' => $activeDateAnomalyCount,
                'suspiciousSnapshot' => $reviewRequired,
            ],
            'featureServerReconciliation' => $this->officialGridReconciliation($rows, $officialGridRows),
            'sourceAcquisition' => [
                'mode' => 'manual_official_export',
                'autoFetch' => 'BLOCKED_OFFICIAL_EXPORT_ENDPOINT',
                'officialLandingPage' => self::SOURCE_URL,
            ],
            'monthlySync' => [
                'ready' => false,
                'scheduler' => null,
                'githubActionsRequired' => false,
            ],
        ];
    }

    /** @param list<array<string,mixed>> $rows @param list<array<string,mixed>>|null $officialGridRows @return array<string,mixed> */
    private function officialGridReconciliation(array $rows, ?array $officialGridRows): array
    {
        $authorityMatrix = [
            'richExportOwns' => ['operation_status', 'address', 'traffic_authority', 'reported_speed', 'operation_dates'],
            'featureServerSupports' => ['geometry_validation', 'independent_cross_check'],
        ];
        if ($officialGridRows === null) {
            return [
                'status' => 'NOT_RUN',
                'source' => null,
                'matchedRows' => null,
                'xlsxOnlyRows' => null,
                'featureServerOnlyRows' => null,
                'ambiguousMatches' => null,
                'authorityMatrix' => $authorityMatrix,
            ];
        }

        $xlsx = [];
        foreach ($rows as $row) {
            $key = $this->reconciliationXlsxKey($row);
            $xlsx[$key] = ($xlsx[$key] ?? 0) + 1;
        }
        $grid = [];
        foreach ($officialGridRows as $row) {
            $key = $this->reconciliationGridKey($row);
            $grid[$key] = ($grid[$key] ?? 0) + 1;
        }

        $matched = 0;
        $xlsxOnly = 0;
        $gridOnly = 0;
        foreach (array_unique(array_merge(array_keys($xlsx), array_keys($grid))) as $key) {
            $matched += min($xlsx[$key] ?? 0, $grid[$key] ?? 0);
            $xlsxOnly += max(0, ($xlsx[$key] ?? 0) - ($grid[$key] ?? 0));
            $gridOnly += max(0, ($grid[$key] ?? 0) - ($xlsx[$key] ?? 0));
        }

        return [
            'status' => 'RUN',
            'source' => 'official_grid_json',
            'key' => 'codigo_unico|lat|lon',
            'matchedRows' => $matched,
            'xlsxOnlyRows' => $xlsxOnly,
            'featureServerOnlyRows' => $gridOnly,
            'ambiguousMatches' => count(array_filter($xlsx, fn (int $count): bool => $count > 1)) + count(array_filter($grid, fn (int $count): bool => $count > 1)),
            'authorityMatrix' => $authorityMatrix,
        ];
    }

    /** @param array<string,mixed> $row */
    private function reconciliationXlsxKey(array $row): string
    {
        return $this->reconciliationText($row['codigo_unico'] ?? '').'|'.round((float) ($row['lat'] ?? 0), 6).'|'.round((float) ($row['lon'] ?? 0), 6);
    }

    /** @param array<string,mixed> $row */
    private function reconciliationGridKey(array $row): string
    {
        return $this->reconciliationText($row['codigo_unico'] ?? '').'|'.round((float) ($row['latitud'] ?? 0), 6).'|'.round((float) ($row['longitud'] ?? 0), 6);
    }

    private function reconciliationText(mixed $value): string
    {
        return mb_strtolower(preg_replace('/\s+/u', ' ', trim((string) $value)) ?? '', 'UTF-8');
    }

    /** @param list<list<string>> $keys */
    private function duplicateKeyCount(array $keys): int
    {
        $seen = [];
        $duplicates = 0;
        foreach ($keys as $parts) {
            $key = Str::lower(implode('|', $parts));
            if (isset($seen[$key])) {
                $duplicates++;
            }
            $seen[$key] = true;
        }

        return $duplicates;
    }

    private function checkpoint(string $point): void
    {
        ($this->failureHook) ? ($this->failureHook)($point) : null;
    }
}
