<?php

namespace Tests\Feature;

use App\Enums\CameraStatus;
use App\Enums\OperatorRole;
use App\Models\AnsvCameraImport;
use App\Models\Camera;
use App\Models\User;
use App\Services\AnsvCameraImportGovernanceService;
use App\Services\AnsvRichCameraImporter;
use App\Services\CameraMobileDatasetPublisher;
use App\Services\GeographyImporter;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Tests\TestCase;

class CameraDatasetPublicationTest extends TestCase
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

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_publishes_only_operating_ready_cameras_with_compact_mobile_manifest(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Nombre equipo' => 'DEI47CAM01', 'Dirección' => 'AV REGIONAL - CL 10', 'Velocidad' => '50 km/h']),
            $this->row(['Nombre equipo' => 'DEI47CAM02', 'Dirección' => 'AV REGIONAL - CL 20', 'Velocidad' => '37']),
            $this->row(['Nombre equipo' => 'DEI47CAM03', 'Dirección' => 'AV REGIONAL - CL 30', 'Estado operación' => 'Autorizada instalar']),
        ], str_repeat('a', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);

        $output = base_path('storage/testing-camera-dataset');
        File::deleteDirectory($output);

        $result = app(CameraMobileDatasetPublisher::class)->publish(
            $output,
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $import->id,
        );

        $datasetPath = $output.DIRECTORY_SEPARATOR.'cameras_v1.json';
        $manifestPath = $output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json';
        $this->assertFileExists($datasetPath);
        $this->assertFileExists($manifestPath);
        $this->assertSame(hash_file('sha256', $datasetPath), $result['assetSha256']);

        $dataset = json_decode((string) file_get_contents($datasetPath), true, flags: JSON_THROW_ON_ERROR);
        $manifest = json_decode((string) file_get_contents($manifestPath), true, flags: JSON_THROW_ON_ERROR);

        $this->assertSame('traffic_cameras', $dataset['datasetKey']);
        $this->assertSame(2, $dataset['recordCount']);
        $this->assertSame(1, $dataset['speedKnownCount']);
        $this->assertSame(0.5, $dataset['speedCoverage']);
        $this->assertSame(2, $manifest['recordCount']);
        $this->assertSame($result['assetSha256'], $manifest['asset']['sha256']);
        $this->assertArrayNotHasKey('acceptedImportId', $manifest);
        $this->assertSame('ansv:'.$import->snapshot_sha, $manifest['sourceImportKey']);
        $this->assertSame('ansv:'.$import->snapshot_sha, $dataset['source']['importKey']);
        $this->assertSame(0, $result['nonOperatingPublishedCount']);
        $this->assertSame(0, $result['reportedSpeedInventedCount']);
        $this->assertSame($import->id, $result['acceptedImportId']);
        $this->assertSame([], $result['exclusions']);
        $this->assertCount(2, $dataset['records']);
        $this->assertSame(['Operando'], array_values(array_unique(array_column($dataset['records'], 'operationStatus'))));
        $speedRecord = collect($dataset['records'])->firstWhere('reportedSpeedKmh', 50);
        $noSpeedRecord = collect($dataset['records'])->firstWhere('reportedSpeedKmh', null);
        $this->assertSame('AV REGIONAL - CL 10', $speedRecord['address']);
        $this->assertSame('SECRETARIA DE MOVILIDAD DE MEDELLÍN', $speedRecord['trafficAuthority']);
        $this->assertSame(['C02', 'C14', 'D02'], $speedRecord['infractionCodes']);
        $this->assertArrayNotHasKey('infractionDescriptions', $speedRecord);
        $this->assertSame('AV REGIONAL - CL 20', $noSpeedRecord['address']);
        $this->assertSame(3, Camera::query()->count());
    }

    public function test_artisan_command_writes_dataset_and_reports_json_contract(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(),
        ], str_repeat('b', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        $output = base_path('storage/testing-camera-dataset-command');
        File::deleteDirectory($output);

        $this->artisan('picoradar:cameras:publish-mobile-dataset', [
            '--output-dir' => $output,
            '--dataset-version' => '2026.08.31-ansv',
            '--generated-at' => '2026-08-31T15:44:00Z',
            '--as-of' => '2026-08-31',
            '--import-id' => $import->id,
            '--json' => true,
        ])->expectsOutputToContain('picoradar.camera-dataset-publication.v1')->assertExitCode(0);

        $this->assertFileExists($output.DIRECTORY_SEPARATOR.'cameras_v1.json');
        $this->assertFileExists($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json');
        $manifest = json_decode((string) file_get_contents($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('2026.08.31-ansv', $manifest['version']);
        $this->assertSame('2026-08-31', $manifest['freshness']['asOf']);
    }

    public function test_command_defaults_use_current_colombia_date_not_frozen_seed_date(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-09-15T10:30:00-05:00'));
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('f', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        $output = base_path('storage/testing-camera-dataset-defaults');
        File::deleteDirectory($output);

        $this->artisan('picoradar:cameras:publish-mobile-dataset', [
            '--output-dir' => $output,
            '--import-id' => $import->id,
            '--json' => true,
        ])->expectsOutputToContain('2026.09.15-ansv-ffffffffffff')->assertExitCode(0);

        $manifest = json_decode((string) file_get_contents($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('2026.09.15-ansv-ffffffffffff', $manifest['version']);
        $this->assertSame('2026-09-15T15:30:00+00:00', $manifest['generatedAt']);
        $this->assertSame('2026-09-15', $manifest['freshness']['asOf']);
        $this->assertFalse(str_starts_with($manifest['version'], '2026.08.31'));
    }

    public function test_publication_requires_explicit_approved_import_selection(): void
    {
        app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('c', 64), $this->fetchedAt);

        $this->expectException(\DomainException::class);
        app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-blocked'),
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
        );
    }

    public function test_unapproved_import_id_is_not_publishable(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('d', 64), $this->fetchedAt);

        $this->expectException(\DomainException::class);
        app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-blocked'),
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $result['importId'],
        );
    }

    public function test_forged_active_camera_without_b03_readiness_is_excluded(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('e', 64), $this->fetchedAt);
        $import = AnsvCameraImport::query()->findOrFail($result['importId']);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        app(AnsvCameraImportGovernanceService::class)->approve($import, $reviewer, 'Synthetic reviewed import');
        Camera::query()->firstOrFail()->forceFill(['status' => CameraStatus::Active])->saveQuietly();

        $this->expectException(\DomainException::class);
        app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-forged'),
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $import->id,
        );
    }

    public function test_bad_verification_fingerprint_cannot_publish(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('1', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        Camera::query()->firstOrFail()->forceFill(['verification_fingerprint' => str_repeat('0', 64)])->saveQuietly();

        $this->expectException(\DomainException::class);
        app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-bad-fingerprint'),
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $import->id,
        );
    }

    public function test_operation_window_uses_selected_as_of_date(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Fecha finalización inicial' => '2026-09-10']),
        ], str_repeat('2', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);

        $published = app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-as-of-ok'),
            '2026.09.10-ansv',
            CarbonImmutable::parse('2026-09-10T12:00:00Z'),
            CarbonImmutable::parse('2026-09-10'),
            $import->id,
        );
        $this->assertSame(1, $published['recordCount']);

        $this->expectException(\DomainException::class);
        app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-as-of-expired'),
            '2026.09.11-ansv',
            CarbonImmutable::parse('2026-09-11T12:00:00Z'),
            CarbonImmutable::parse('2026-09-11'),
            $import->id,
        );
    }

    public function test_master_source_row_mismatch_is_not_published(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('3', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        Camera::query()->firstOrFail()->forceFill(['direction' => 'UNREVIEWED CHANGE'])->saveQuietly();

        $this->expectException(\DomainException::class);
        app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-source-mismatch'),
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $import->id,
        );
    }

    public function test_mobile_manifest_portable_provenance_does_not_depend_on_local_import_id(): void
    {
        app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Código unico' => 'CU-DUMMY', 'Código solicitud' => 'SOL-DUMMY', 'Nombre equipo' => 'DUMMY']),
        ], str_repeat('4', 64), $this->fetchedAt);
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('5', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        $manifest = $this->publishManifest($import->id, 'portable');

        $this->assertGreaterThan(1, $import->id);
        $this->assertArrayNotHasKey('acceptedImportId', $manifest);
        $this->assertSame('ansv:'.$import->snapshot_sha, $manifest['sourceImportKey']);
        $this->assertSame($import->snapshot_sha, $manifest['sourceSnapshotSha256']);
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

    private function approveAndActivateImport(int $importId): AnsvCameraImport
    {
        $import = AnsvCameraImport::query()->findOrFail($importId);
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $governance = app(AnsvCameraImportGovernanceService::class);
        $governance->approve($import, $reviewer, 'Synthetic reviewed import');
        $governance->submitCandidates($import, $editor);
        $governance->verifyCandidates($import, $reviewer);
        $governance->activateCandidates($import, $reviewer);

        return $import->fresh();
    }

    /** @return array<string,mixed> */
    private function publishManifest(int $importId, string $outputName): array
    {
        $output = base_path('storage/testing-camera-dataset-'.$outputName);
        File::deleteDirectory($output);

        app(CameraMobileDatasetPublisher::class)->publish(
            $output,
            '2026.09.15-ansv-portable',
            CarbonImmutable::parse('2026-09-15T15:30:00Z'),
            CarbonImmutable::parse('2026-09-15'),
            $importId,
        );

        return json_decode((string) file_get_contents($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json'), true, flags: JSON_THROW_ON_ERROR);
    }
}
