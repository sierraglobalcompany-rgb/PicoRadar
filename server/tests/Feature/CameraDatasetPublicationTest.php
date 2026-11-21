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
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use RuntimeException;
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
        CameraMobileDatasetPublisher::$failureHook = null;
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

    public function test_command_accepts_valid_leap_day_publication_dates(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Fecha inicio de operación' => '2024-01-01']),
        ], str_repeat('0', 64), CarbonImmutable::parse('2024-02-29T23:59:59Z'));
        $import = $this->approveAndActivateImport($result['importId']);
        $output = base_path('storage/testing-camera-dataset-leap-day');
        File::deleteDirectory($output);

        $this->artisan('picoradar:cameras:publish-mobile-dataset', [
            '--output-dir' => $output,
            '--dataset-version' => '2024.02.29-ansv',
            '--generated-at' => '2024-02-29T23:59:59Z',
            '--as-of' => '2024-02-29',
            '--import-id' => $import->id,
            '--json' => true,
        ])->assertExitCode(0);

        $manifest = json_decode((string) file_get_contents($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('2024.02.29-ansv', $manifest['version']);
        $this->assertSame('2024-02-29', $manifest['freshness']['asOf']);
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

    public function test_publication_requires_exactly_one_approved_import_selection(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('c', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);

        try {
            app(CameraMobileDatasetPublisher::class)->publish(
                base_path('storage/testing-camera-dataset-blocked'),
                '2026.08.31-ansv',
                $this->fetchedAt,
                CarbonImmutable::parse('2026-08-31'),
            );
            $this->fail('Publisher should require one import selector.');
        } catch (DomainException $exception) {
            $this->assertSame('Select exactly one approved ANSV import source.', $exception->getMessage());
        }

        try {
            app(CameraMobileDatasetPublisher::class)->publish(
                base_path('storage/testing-camera-dataset-blocked'),
                '2026.08.31-ansv',
                $this->fetchedAt,
                CarbonImmutable::parse('2026-08-31'),
                $import->id,
                true,
            );
            $this->fail('Publisher should reject conflicting import selectors.');
        } catch (DomainException $exception) {
            $this->assertSame('Select exactly one approved ANSV import source.', $exception->getMessage());
        }
    }

    public function test_unapproved_import_id_is_not_publishable(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('d', 64), $this->fetchedAt);

        $this->expectException(DomainException::class);
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

        $this->expectException(DomainException::class);
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

        $this->expectException(DomainException::class);
        app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-bad-fingerprint'),
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $import->id,
        );
    }

    public function test_operation_window_uses_inclusive_colombia_as_of_date(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([
            $this->row([
                'Fecha finalización inicial' => '2026-09-10',
                'Fecha finalización de prórroga' => '2026-09-10',
            ]),
        ], str_repeat('2', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);

        $published = app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-as-of-ok'),
            '2026.09.10-ansv',
            CarbonImmutable::parse('2026-09-10T12:00:00Z'),
            CarbonImmutable::parse('2026-09-10T15:00:00-05:00'),
            $import->id,
        );
        $this->assertSame(1, $published['recordCount']);

        $this->expectException(DomainException::class);
        app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-as-of-expired'),
            '2026.09.11-ansv',
            CarbonImmutable::parse('2026-09-11T12:00:00Z'),
            CarbonImmutable::parse('2026-09-11', 'America/Bogota'),
            $import->id,
        );
    }

    public function test_valid_from_same_day_is_published(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Fecha inicio de operación' => '2026-08-31']),
        ], str_repeat('6', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);

        $published = app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-valid-from'),
            '2026.08.31-ansv',
            CarbonImmutable::parse('2026-08-31T15:44:00Z'),
            CarbonImmutable::parse('2026-08-31T15:00:00-05:00'),
            $import->id,
        );

        $this->assertSame(1, $published['recordCount']);
    }

    public function test_manifest_as_of_and_default_version_use_same_colombia_date_as_filters(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Nombre equipo' => 'COLOMBIA-DATE']),
            $this->row([
                'Código unico' => 'CU000000000002',
                'Código solicitud' => 'SOL0000016335',
                'Nombre equipo' => 'FUTURE-FILTERED',
                'Dirección' => 'AV REGIONAL - CL 20',
                'Fecha inicio de operación' => '2026-09-01',
            ]),
        ], str_repeat('7', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        $output = base_path('storage/testing-camera-dataset-as-of-provenance');
        File::deleteDirectory($output);

        $published = app(CameraMobileDatasetPublisher::class)->publish(
            $output,
            null,
            CarbonImmutable::parse('2026-09-01T01:00:00Z'),
            CarbonImmutable::parse('2026-09-01T01:00:00Z'),
            $import->id,
        );

        $manifest = json_decode((string) file_get_contents($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame(1, $published['recordCount']);
        $this->assertSame('2026-08-31', $published['asOf']);
        $this->assertSame('2026-08-31', $manifest['freshness']['asOf']);
        $this->assertStringStartsWith('2026.08.31-ansv-', $manifest['version']);
    }

    public function test_master_source_row_mismatch_is_not_published(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('3', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        Camera::query()->firstOrFail()->forceFill(['direction' => 'UNREVIEWED CHANGE'])->saveQuietly();

        $this->expectException(DomainException::class);
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

    public function test_fresh_output_failure_leaves_no_dataset_manifest_or_temp_files(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('7', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        $output = base_path('storage/testing-camera-dataset-fresh-failure');
        File::deleteDirectory($output);
        CameraMobileDatasetPublisher::$failureHook = fn (string $point) => $point === 'after_temp_files'
            ? throw new RuntimeException('Injected temp-file failure.')
            : null;

        try {
            app(CameraMobileDatasetPublisher::class)->publish(
                $output,
                '2026.08.31-ansv',
                $this->fetchedAt,
                CarbonImmutable::parse('2026-08-31'),
                $import->id,
            );
            $this->fail('Publisher should have failed.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected temp-file failure.', $exception->getMessage());
        }

        $this->assertFalse(File::exists($output.DIRECTORY_SEPARATOR.'cameras_v1.json'));
        $this->assertFalse(File::exists($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json'));
        $this->assertNoPublisherTempFiles($output);
    }

    public function test_existing_valid_pair_is_restored_after_partial_replace_failure(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('8', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        $output = base_path('storage/testing-camera-dataset-restore-failure');
        File::deleteDirectory($output);
        app(CameraMobileDatasetPublisher::class)->publish(
            $output,
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $import->id,
        );
        $datasetPath = $output.DIRECTORY_SEPARATOR.'cameras_v1.json';
        $manifestPath = $output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json';
        $datasetBefore = File::get($datasetPath);
        $manifestBefore = File::get($manifestPath);
        CameraMobileDatasetPublisher::$failureHook = fn (string $point) => $point === 'after_dataset_replace'
            ? throw new RuntimeException('Injected partial replace failure.')
            : null;

        try {
            app(CameraMobileDatasetPublisher::class)->publish(
                $output,
                '2026.09.01-ansv',
                CarbonImmutable::parse('2026-09-01T12:00:00Z'),
                CarbonImmutable::parse('2026-09-01'),
                $import->id,
            );
            $this->fail('Publisher should have failed.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected partial replace failure.', $exception->getMessage());
        }

        $this->assertSame($datasetBefore, File::get($datasetPath));
        $this->assertSame($manifestBefore, File::get($manifestPath));
        $this->assertNoPublisherTempFiles($output);
    }

    public function test_successful_publish_leaves_no_temp_files_and_manifest_matches_dataset_bytes(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('9', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        $output = base_path('storage/testing-camera-dataset-success-temp');
        File::deleteDirectory($output);

        app(CameraMobileDatasetPublisher::class)->publish(
            $output,
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $import->id,
        );

        $datasetPath = $output.DIRECTORY_SEPARATOR.'cameras_v1.json';
        $manifest = json_decode((string) file_get_contents($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame(filesize($datasetPath), $manifest['asset']['bytes']);
        $this->assertSame(hash_file('sha256', $datasetPath), $manifest['asset']['sha256']);
        $this->assertNoPublisherTempFiles($output);
    }

    public function test_command_validation_failures_are_controlled_and_do_not_mutate_existing_pair(): void
    {
        $result = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('a', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($result['importId']);
        $output = base_path('storage/testing-camera-dataset-command-validation');
        File::deleteDirectory($output);
        app(CameraMobileDatasetPublisher::class)->publish(
            $output,
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            $import->id,
        );
        $datasetBefore = File::get($output.DIRECTORY_SEPARATOR.'cameras_v1.json');
        $manifestBefore = File::get($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json');

        foreach ([
            ['--generated-at' => 'tomorrow', '--as-of' => '2026-08-31', '--import-id' => $import->id],
            ['--generated-at' => '2026-02-30T15:44:00Z', '--as-of' => '2026-08-31', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T24:00:00Z', '--as-of' => '2026-08-31', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T23:60:00Z', '--as-of' => '2026-08-31', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T23:59:60Z', '--as-of' => '2026-08-31', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00+99:99', '--as-of' => '2026-08-31', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => 'tomorrow', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-02-30', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-02-29', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-04-31', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-13-01', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-00-10', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '0000-01-01', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-08-31', '--dataset-version' => '../bad', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-08-31', '--dataset-version' => '2026.02.30-ansv', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-08-31', '--dataset-version' => '2026.13.01-ansv', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-08-31', '--dataset-version' => '2026.00.01', '--import-id' => $import->id],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-08-31', '--import-id' => $import->id, '--latest-approved' => true],
            ['--generated-at' => '2026-08-31T15:44:00Z', '--as-of' => '2026-08-31', '--import-id' => 'abc'],
        ] as $options) {
            $this->artisan('picoradar:cameras:publish-mobile-dataset', array_merge([
                '--output-dir' => $output,
                '--json' => true,
            ], $options))->expectsOutputToContain('"status":"failed"')->assertExitCode(1);
            $this->assertSame($datasetBefore, File::get($output.DIRECTORY_SEPARATOR.'cameras_v1.json'));
            $this->assertSame($manifestBefore, File::get($output.DIRECTORY_SEPARATOR.'cameras_manifest_v1.json'));
            $this->assertNoPublisherTempFiles($output);
        }
    }

    public function test_command_fails_controlled_for_unwritable_output_and_unpublishable_import(): void
    {
        $draft = app(AnsvRichCameraImporter::class)->importRows([$this->row()], str_repeat('f', 64), $this->fetchedAt);
        $this->artisan('picoradar:cameras:publish-mobile-dataset', [
            '--output-dir' => base_path('storage/testing-camera-dataset-unpublishable'),
            '--dataset-version' => '2026.08.31-ansv',
            '--generated-at' => '2026-08-31T15:44:00Z',
            '--as-of' => '2026-08-31',
            '--import-id' => $draft['importId'],
            '--json' => true,
        ])->assertExitCode(1);

        $approved = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Código unico' => 'CU000000000099', 'Código solicitud' => 'SOL0000000099', 'Nombre equipo' => 'UNWRITABLE']),
        ], str_repeat('0', 64), $this->fetchedAt);
        $import = $this->approveAndActivateImport($approved['importId']);
        $outputFile = base_path('storage/testing-camera-dataset-output-file');
        File::delete($outputFile);
        File::put($outputFile, 'not a directory');

        $this->artisan('picoradar:cameras:publish-mobile-dataset', [
            '--output-dir' => $outputFile,
            '--dataset-version' => '2026.08.31-ansv',
            '--generated-at' => '2026-08-31T15:44:00Z',
            '--as-of' => '2026-08-31',
            '--import-id' => $import->id,
            '--json' => true,
        ])->assertExitCode(1);
        $this->assertSame('not a directory', File::get($outputFile));
    }

    public function test_latest_approved_uses_deterministic_source_fetched_at_and_id_tie_break(): void
    {
        $first = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Código unico' => 'CU000000000101', 'Código solicitud' => 'SOL0000000101', 'Nombre equipo' => 'FIRST', 'Dirección' => 'AV 1']),
        ], str_repeat('a', 64), $this->fetchedAt);
        $this->approveAndActivateImport($first['importId']);
        $second = app(AnsvRichCameraImporter::class)->importRows([
            $this->row(['Código unico' => 'CU000000000102', 'Código solicitud' => 'SOL0000000102', 'Nombre equipo' => 'SECOND', 'Dirección' => 'AV 2']),
        ], str_repeat('b', 64), $this->fetchedAt);
        $secondImport = $this->approveAndActivateImport($second['importId']);

        $published = app(CameraMobileDatasetPublisher::class)->publish(
            base_path('storage/testing-camera-dataset-latest-approved'),
            '2026.08.31-ansv',
            $this->fetchedAt,
            CarbonImmutable::parse('2026-08-31'),
            null,
            true,
        );

        $this->assertSame($secondImport->id, $published['acceptedImportId']);
        $this->assertSame(str_repeat('b', 64), $published['sourceSnapshotSha256']);
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

    private function assertNoPublisherTempFiles(string $output): void
    {
        if (! File::isDirectory($output)) {
            return;
        }

        $this->assertSame([], collect(File::files($output))
            ->map(fn ($file): string => $file->getFilename())
            ->filter(fn (string $filename): bool => str_contains($filename, '.tmp-'))
            ->values()
            ->all());
    }
}
