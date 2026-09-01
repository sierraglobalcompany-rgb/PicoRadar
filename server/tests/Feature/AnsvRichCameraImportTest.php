<?php

namespace Tests\Feature;

use App\Enums\CameraSourceType;
use App\Enums\CameraStatus;
use App\Enums\CameraType;
use App\Enums\OperatorRole;
use App\Models\AnsvCameraImport;
use App\Models\AnsvCameraImportRow;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\AnsvCameraImportGovernanceService;
use App\Services\AnsvCameraRowNormalizer;
use App\Services\AnsvRichCameraImporter;
use App\Services\CameraRegistryService;
use App\Services\DatasetAuditLogger;
use App\Services\GeographyImporter;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class AnsvRichCameraImportTest extends TestCase
{
    use RefreshDatabase;

    private CarbonImmutable $fetchedAt;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        app(GeographyImporter::class)->bootstrap();
        $this->fetchedAt = CarbonImmutable::parse('2026-08-31T15:44:00Z');
    }

    public function test_source_mapping_keeps_raw_37_nullable_and_parses_explicit_kmh(): void
    {
        $normalizer = app(AnsvCameraRowNormalizer::class);

        $this->assertNull($normalizer->speed('37'));
        $this->assertSame(50, $normalizer->speed('50 km/h'));
        $this->assertNull($normalizer->sourceDate('37', 'operation_started_on')['date']);
        $this->assertSame('IMPLAUSIBLE_ANSV_DATE', $normalizer->sourceDate('37', 'operation_started_on')['anomaly']['reason']);
        $this->assertSame('2025-01-01', $normalizer->sourceDate('2025-01-01', 'operation_started_on')['date']?->toDateString());
    }

    public function test_imports_operating_candidates_and_keeps_authorized_install_out_of_runtime(): void
    {
        $result = $this->import([
            $this->row(['Estado operación' => 'Operando', 'Velocidad' => '50 km/h']),
            $this->row(['Estado operación' => 'Autorizada instalar', 'Nombre equipo' => 'FUTURE01', 'Dirección' => 'CL 1 # 1-2']),
        ]);

        $this->assertSame(2, $result['rowCount']);
        $this->assertSame(2, $result['masterImportedCount']);
        $this->assertSame(1, $result['activeCandidateCount']);
        $this->assertSame(0, $result['raw37ParsedAs37Kmh']);
        $this->assertSame(0, Camera::query()->where('status', CameraStatus::Active)->count());
        $this->assertSame(2, Camera::query()->where('status', CameraStatus::Draft)->count());
        $this->assertDatabaseHas('ansv_camera_import_rows', [
            'operation_status' => 'Autorizada instalar',
            'active_public_candidate' => false,
        ]);
    }

    public function test_raw_infraction_codes_are_preserved_without_unsourced_d02_camera_type_semantics(): void
    {
        $this->import([
            $this->row(['Código unico' => 'CU-D02-A', 'Código solicitud' => 'SOL-D02-A', 'Nombre equipo' => 'D02-NO-SPEED', 'Velocidad' => '', 'Infracciones' => 'D02']),
            $this->row(['Código unico' => 'CU-D02-B', 'Código solicitud' => 'SOL-D02-B', 'Nombre equipo' => 'D02-SPEED', 'Velocidad' => '50 km/h', 'Infracciones' => 'C02, D02']),
        ], str_repeat('7', 64));

        $withoutSpeed = Camera::query()->where('name', 'D02-NO-SPEED')->firstOrFail();
        $withSpeed = Camera::query()->where('name', 'D02-SPEED')->firstOrFail();

        $this->assertSame(['D02'], $withoutSpeed->raw_infraction_codes);
        $this->assertSame(CameraType::Other, $withoutSpeed->type);
        $this->assertSame(['C02', 'D02'], $withSpeed->raw_infraction_codes);
        $this->assertSame(CameraType::Speed, $withSpeed->type);
    }

    public function test_expired_desisted_future_and_invalid_coordinates_fail_closed(): void
    {
        $result = $this->import([
            $this->row(['Estado operación' => 'Vencida', 'Nombre equipo' => 'VEN01', 'Dirección' => 'CL 2 # 1-2']),
            $this->row(['Estado operación' => 'Autorizada – Desistida', 'Nombre equipo' => 'DES01', 'Dirección' => 'CL 3 # 1-2']),
            $this->row(['Estado operación' => 'Operando', 'Nombre equipo' => 'FUT01', 'Dirección' => 'CL 4 # 1-2', 'Fecha inicio de operación' => '2027-01-01']),
            $this->row(['Estado operación' => 'Operando', 'Nombre equipo' => 'BAD01', 'Dirección' => 'CL 5 # 1-2', 'Latitud' => '20', 'Longitud' => '-74.082919']),
        ], 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');

        $this->assertSame(0, $result['activeCandidateCount']);
        $this->assertSame(1, $result['invalidCoordinateCount']);
        $this->assertSame(0, Camera::query()->where('status', CameraStatus::Active)->count());
    }

    public function test_source_row_identity_does_not_collapse_duplicate_codigo_unico_with_distinct_equipment(): void
    {
        $result = $this->import([
            $this->row(['Código unico' => 'CU0001', 'Nombre equipo' => 'CAM01', 'Dirección' => 'AV 1']),
            $this->row(['Código unico' => 'CU0001', 'Nombre equipo' => 'CAM02', 'Dirección' => 'AV 2']),
        ], 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc');

        $this->assertSame(0, $result['duplicateIdentityCount']);
        $this->assertSame(2, Camera::query()->count());
        $this->assertSame(2, AnsvCameraImportRow::query()->distinct('source_row_identity')->count('source_row_identity'));
    }

    public function test_source_row_identity_excludes_mutable_location_and_worksheet_row_number(): void
    {
        $normalizer = app(AnsvCameraRowNormalizer::class);
        $first = $this->row(['Dirección' => 'AV 1', 'Latitud' => '6.244203', 'Longitud' => '-75.581211']) + ['_source_row_number' => '2'];
        $second = $this->row(['Dirección' => 'AV 2', 'Latitud' => '6.300000', 'Longitud' => '-75.500000']) + ['_source_row_number' => '57'];

        $this->assertSame($normalizer->identity($first), $normalizer->identity($second));
    }

    public function test_exact_official_identity_duplicates_are_collapsed_without_location_identity(): void
    {
        $duplicate = $this->row(['Estado operación' => 'Autorizada instalar']);

        $result = $this->import([$duplicate, $duplicate], str_repeat('4', 64));

        $this->assertSame(0, $result['duplicateIdentityCount']);
        $this->assertSame(0, $result['duplicateIdentitySignals']['codigoUnicoCodigoSolicitudNombreEquipo']);
        $this->assertSame(1, $result['exactDuplicateSourceRowCount']);
        $this->assertSame(1, AnsvCameraImportRow::query()->count());
        $this->assertSame(1, AnsvCameraImportRow::query()->distinct('source_row_identity')->count('source_row_identity'));
        $this->assertSame(2, AnsvCameraImportRow::query()->firstOrFail()->duplicate_source_row_count);
        $this->assertSame(0, AnsvCameraImportRow::query()->whereJsonContains('review_reasons', 'DUPLICATE_OFFICIAL_IDENTITY_DISAMBIGUATED')->count());
    }

    public function test_operating_rows_outside_pico_jurisdictions_are_not_dropped(): void
    {
        $result = $this->import([
            $this->row([
                'Código solicitud' => 'SOL-AMAGA-1',
                'Código unico' => 'CU-AMAGA-1',
                'Departamento' => 'ANTIOQUIA',
                'Municipio' => 'AMAGÁ',
                'Nombre equipo' => 'AMAGA-CAM-01',
                'Dirección' => 'CL 50 # 50-10',
                'Latitud' => '6.040000',
                'Longitud' => '-75.700000',
            ]),
        ], str_repeat('1', 64));

        $this->assertSame(1, $result['activeImportedCount']);
        $this->assertSame(0, $result['operatingRowsDroppedDueToPicoJurisdiction']);
        $this->assertSame(1, Camera::query()->where('status', CameraStatus::Draft)->count());
        $jurisdiction = Jurisdiction::query()->where('key', 'camera-registry-05030')->firstOrFail();
        $this->assertTrue($jurisdiction->enabled);
        $this->assertSame('camera_registry', $jurisdiction->metadata['scope']);
    }

    public function test_unknown_status_empty_source_and_missing_schema_require_review(): void
    {
        $result = $this->import([$this->row(['Estado operación' => 'Nuevo estado'])]);

        $this->assertTrue($result['reviewRequired']);
        $this->assertSame(1, $result['reviewGates']['unknownOperationStatusCount']);
        $this->assertSame('review_required', AnsvCameraImport::query()->firstOrFail()->status);
    }

    public function test_empty_source_is_rejected(): void
    {
        $this->expectException(DomainException::class);
        app(AnsvRichCameraImporter::class)->importRows([], str_repeat('d', 64), $this->fetchedAt);
    }

    public function test_schema_columns_are_required(): void
    {
        $this->expectException(DomainException::class);
        app(AnsvRichCameraImporter::class)->importRows([['Estado operación' => 'Operando']], str_repeat('e', 64), $this->fetchedAt);
    }

    public function test_transaction_rolls_back_when_import_checkpoint_fails(): void
    {
        $importer = new AnsvRichCameraImporter(
            app(AnsvCameraRowNormalizer::class),
            app(DatasetAuditLogger::class),
            app(CameraRegistryService::class),
            static fn (string $point) => throw new \RuntimeException($point),
        );

        try {
            $importer->importRows([$this->row()], str_repeat('f', 64), $this->fetchedAt);
            $this->fail('Expected injected failure.');
        } catch (\RuntimeException) {
            $this->assertSame(0, AnsvCameraImport::query()->count());
            $this->assertSame(0, AnsvCameraImportRow::query()->count());
            $this->assertSame(0, Camera::query()->count());
        }
    }

    public function test_idempotent_reimport_keeps_b03_master_and_provenance_stable(): void
    {
        $rows = [$this->row(['Velocidad' => '37'])];
        $sha = str_repeat('a', 64);

        $first = $this->import($rows, $sha);
        $second = $this->import($rows, $sha);

        $this->assertFalse($first['idempotent']);
        $this->assertTrue($second['idempotent']);
        $this->assertSame(1, Camera::query()->count());
        $camera = Camera::query()->firstOrFail();
        $this->assertSame(CameraStatus::Draft, $camera->status);
        $this->assertSame('cam_'.substr($camera->external_id, 0, 26), $camera->camera_id);
        $this->assertNull($camera->speed_limit);
        $this->assertFalse($camera->speed_limit_verified);
        $this->assertNull($camera->verified_at);
        $this->assertNull($camera->verification_fingerprint);
        $this->assertSame('Operando', $camera->operation_status);
        $this->assertSame(str_repeat('a', 64), $camera->source_snapshot_sha);
    }

    public function test_active_camera_immutable_fields_are_not_mutated_by_later_import(): void
    {
        $row = $this->row();
        $identity = app(AnsvCameraRowNormalizer::class)->identity($row);

        $result = $this->import([$row]);
        $import = AnsvCameraImport::query()->findOrFail($result['importId']);
        $camera = Camera::query()->firstOrFail();
        $this->assertSame('AV REGIONAL - CL 10', $camera->direction);
        [$editor, $reviewer] = $this->users();
        $governance = app(AnsvCameraImportGovernanceService::class);
        $governance->approve($import, $reviewer, 'Synthetic reviewed import');
        $governance->submitCandidates($import, $editor);
        $governance->verifyCandidates($import, $reviewer);
        $governance->activateCandidates($import, $reviewer);
        $camera->refresh();
        $this->assertSame(CameraStatus::Active, $camera->status);

        DB::table('cameras')->where('id', $camera->id)->update(['direction' => 'AV REGIONAL - CL HISTORICA']);

        $this->import([$row], str_repeat('b', 64));

        $camera->refresh();
        $this->assertSame($identity, $camera->external_id);
        $this->assertSame('AV REGIONAL - CL HISTORICA', $camera->direction);
        $this->assertSame(6.244203, (float) $camera->lat);
        $importRow = AnsvCameraImportRow::query()->latest('id')->firstOrFail();
        $this->assertSame('REVIEW_REQUIRED', $importRow->review_state);
        $this->assertContains('ACTIVE_CAMERA_SOURCE_CHANGE_REVIEW_REQUIRED', $importRow->review_reasons);
        $this->assertSame('AV REGIONAL - CL HISTORICA', $importRow->source_delta['direction']['current']);
        $this->assertSame('AV REGIONAL - CL 10', $importRow->source_delta['direction']['incoming']);
    }

    public function test_deactivated_ansv_source_is_not_reactivated_and_blocks_approval_until_operator_action(): void
    {
        CameraSource::factory()->create([
            'key' => 'ansv-fotodeteccion-rich',
            'title' => 'ANSV ubicaciones aprobadas de fotodetección',
            'authority' => 'Agencia Nacional de Seguridad Vial',
            'url' => 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
            'source_type' => CameraSourceType::Official,
            'is_active' => false,
            'verified_at' => null,
        ]);

        $result = $this->import([$this->row()], str_repeat('8', 64));
        $source = CameraSource::query()->where('key', 'ansv-fotodeteccion-rich')->firstOrFail();
        $import = AnsvCameraImport::query()->findOrFail($result['importId']);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);

        $this->assertFalse($source->is_active);
        $this->assertNull($source->verified_at);
        $this->assertTrue($import->report['reviewGates']['sourceConfigurationReviewRequired']);
        $this->assertContains('ANSV_SOURCE_INACTIVE', $import->report['sourceReviewReasons']);
        $this->expectException(DomainException::class);
        app(AnsvCameraImportGovernanceService::class)->approve($import, $reviewer, 'Source must be reactivated explicitly.');
    }

    public function test_snapshot_diff_reports_added_removed_and_changed_rows(): void
    {
        $this->import([
            $this->row(['Código unico' => 'CU-A', 'Código solicitud' => 'SOL-A', 'Nombre equipo' => 'CAM-A']),
            $this->row(['Código unico' => 'CU-B', 'Código solicitud' => 'SOL-B', 'Nombre equipo' => 'CAM-B']),
        ], str_repeat('2', 64));

        $result = $this->import([
            $this->row(['Código unico' => 'CU-A', 'Código solicitud' => 'SOL-A', 'Nombre equipo' => 'CAM-A', 'Velocidad' => '60 km/h']),
            $this->row(['Código unico' => 'CU-C', 'Código solicitud' => 'SOL-C', 'Nombre equipo' => 'CAM-C']),
        ], str_repeat('3', 64));

        $this->assertSame(1, $result['snapshotDiff']['addedRows']);
        $this->assertSame(1, $result['snapshotDiff']['removedRows']);
        $this->assertSame(1, $result['snapshotDiff']['changedRows']);
    }

    public function test_governance_bulk_review_is_four_eyes_and_never_marks_speed_verified(): void
    {
        $result = $this->import([$this->row(['Velocidad' => '50 km/h'])]);
        $import = AnsvCameraImport::query()->findOrFail($result['importId']);
        [$editor, $reviewer] = $this->users();
        $governance = app(AnsvCameraImportGovernanceService::class);

        $governance->approve($import, $reviewer, 'Synthetic reviewed import');
        $this->assertSame(['submitted' => 1, 'skipped' => 0], $governance->submitCandidates($import, $editor));
        $this->assertSame(['verified' => 1, 'skipped' => 0], $governance->verifyCandidates($import, $reviewer));
        $this->assertSame(['activated' => 1, 'skipped' => 0], $governance->activateCandidates($import, $reviewer));

        $camera = Camera::query()->firstOrFail();
        $this->assertSame(CameraStatus::Active, $camera->status);
        $this->assertNull($camera->speed_limit);
        $this->assertFalse($camera->speed_limit_verified);
        $this->assertNotNull($camera->verified_at);
    }

    public function test_same_operator_cannot_bulk_verify_import_candidate(): void
    {
        $result = $this->import([$this->row()]);
        $import = AnsvCameraImport::query()->findOrFail($result['importId']);
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $governance = app(AnsvCameraImportGovernanceService::class);

        $governance->approve($import, $admin, 'Synthetic reviewed import');
        $governance->submitCandidates($import, $admin);
        $this->expectException(DomainException::class);
        $governance->verifyCandidates($import, $admin);
    }

    public function test_combined_submit_verify_cli_same_actor_fails_before_partial_mutation(): void
    {
        $result = $this->import([$this->row()], str_repeat('9', 64));
        $import = AnsvCameraImport::query()->findOrFail($result['importId']);
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        app(AnsvCameraImportGovernanceService::class)->approve($import, $admin, 'Synthetic reviewed import');

        $this->artisan('picoradar:ansv:cameras:review', [
            'import' => $import->id,
            '--submit' => true,
            '--verify' => true,
            '--reviewer-id' => $admin->id,
            '--operator-id' => $admin->id,
        ])->expectsOutputToContain('Combined submit and verify requires different operator and reviewer IDs.')
            ->assertFailed();

        $this->assertSame(CameraStatus::Draft, Camera::query()->firstOrFail()->status);
    }

    public function test_active_import_rows_with_review_reasons_block_approval(): void
    {
        $result = $this->import([
            $this->row(['Código unico' => 'CU0001', 'Nombre equipo' => 'CAM01', 'Dirección' => 'AV 1']),
            $this->row(['Código unico' => 'CU0001', 'Nombre equipo' => 'CAM01', 'Dirección' => 'AV 2']),
        ], str_repeat('6', 64));
        $import = AnsvCameraImport::query()->findOrFail($result['importId']);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);

        $this->expectException(DomainException::class);
        app(AnsvCameraImportGovernanceService::class)->approve($import, $reviewer, 'Synthetic review');
    }

    public function test_official_grid_reconciliation_records_real_counts(): void
    {
        $row = $this->row();
        $result = app(AnsvRichCameraImporter::class)->importRows(
            [$row],
            str_repeat('5', 64),
            $this->fetchedAt,
            false,
            [[
                'codigo_unico' => $row['Código unico'],
                'latitud' => (float) $row['Latitud'],
                'longitud' => (float) $row['Longitud'],
            ]],
        );

        $this->assertSame('RUN', $result['featureServerReconciliation']['status']);
        $this->assertSame(1, $result['featureServerReconciliation']['matchedRows']);
        $this->assertSame(0, $result['featureServerReconciliation']['xlsxOnlyRows']);
        $this->assertSame(0, $result['featureServerReconciliation']['featureServerOnlyRows']);
    }

    /** @param list<array<string, string|null>> $rows */
    private function import(array $rows, string $sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'): array
    {
        return app(AnsvRichCameraImporter::class)->importRows($rows, $sha, $this->fetchedAt);
    }

    /** @param array<string, string|null> $overrides */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'Acciones' => '',
            'Código solicitud' => 'SOL0000016334',
            'Código unico' => 'CU000000000001',
            'Estado operación' => 'Operando',
            'Departamento' => 'ANTIOQUIA',
            'Municipio' => 'MEDELLÍN',
            'Fecha aprobación' => '2025-01-01',
            'Dirección' => 'AV REGIONAL - CL 10',
            'Latitud' => '6.244203',
            'Longitud' => '-75.581211',
            'Autoridad de tránsito' => 'SECRETARIA DE MOVILIDAD DE MEDELLÍN',
            'Jurisdicción' => 'Municipal',
            'Infracciones' => 'C02, C14, D02',
            'Velocidad' => '50 km/h',
            'Tipo de tecnología' => 'Radar Doppler',
            'Tipo de instalación' => 'Fijo',
            'Nombre equipo' => 'DEI47CAM01',
            'Resolución de renovación' => '',
            'Fecha radicación de renovación' => '',
            'Fecha de notificación' => '',
            'Fecha de recurso' => '',
            'Fecha resolución de recurso' => '',
            'Fecha de aprobación final' => '',
            'Fecha finalización de prórroga' => '',
            'Fecha inicio de operación' => '2025-01-01',
            'Fecha finalización inicial' => '2031-08-31',
        ], $overrides);
    }

    /** @return array{0:User,1:User} */
    private function users(): array
    {
        return [
            User::factory()->create(['role' => OperatorRole::Editor]),
            User::factory()->create(['role' => OperatorRole::Reviewer]),
        ];
    }
}
