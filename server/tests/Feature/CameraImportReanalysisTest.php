<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Models\AuditLog;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraImportRun;
use App\Models\CameraSource;
use App\Models\CameraVerification;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\CameraImportReproducibilityVerifier;
use App\Services\CameraImportService;
use App\Services\CameraRegistryService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CameraImportReanalysisTest extends TestCase
{
    use RefreshDatabase;

    public function test_initial_analysis_is_generation_one_and_reanalysis_replaces_the_current_generation_without_camera_mutations(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create();
        $service = app(CameraImportService::class);
        $run = $service->analyze($this->importRun($service, $source, $jurisdiction, 'generation.csv', 'generation-1'));
        $before = [Camera::count(), CameraVerification::count()];

        $reanalysed = $service->analyze($run);

        $this->assertSame(1, $run->analysis_generation);
        $this->assertSame(2, $reanalysed->analysis_generation);
        $this->assertSame(1, CameraImportItem::where('run_id', $run->id)->where('analysis_generation', 1)->count());
        $this->assertSame(1, CameraImportItem::where('run_id', $run->id)->where('analysis_generation', 2)->count());
        $this->assertSame(1, CameraImportItem::where('run_id', $run->id)->where('analysis_generation', $reanalysed->analysis_generation)->where('status', 'ready')->count());
        $this->assertSame($before, [Camera::count(), CameraVerification::count()]);
    }

    public function test_reanalysis_refreshes_source_geography_and_identity_without_creating_or_verifying_cameras(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create();
        $service = app(CameraImportService::class);
        $run = $service->analyze($this->importRun($service, $source, $jurisdiction, 'refresh.csv', 'refresh-1'));
        app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'refresh-1', 'lat' => 6.2, 'lon' => -75.5, 'type' => 'other']);
        $source->update(['is_active' => false]);
        $jurisdiction->geographicUnits()->detach($municipality->id);
        $before = [Camera::count(), CameraVerification::count()];

        $reanalysed = $service->analyze($run);
        $item = $reanalysed->items()->where('analysis_generation', $reanalysed->analysis_generation)->firstOrFail();

        $this->assertSame('invalid', $item->classification);
        $this->assertContains('municipality_outside_coverage', $item->errors);
        $this->assertSame(['source_not_operational' => 1], $reanalysed->warning_summary);
        $this->assertSame($before, [Camera::count(), CameraVerification::count()]);
    }

    public function test_reanalysis_refreshes_a_later_claimed_identity_to_noop_without_a_new_camera(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create();
        $service = app(CameraImportService::class);
        $run = $service->analyze($this->importRun($service, $source, $jurisdiction, 'identity.csv', 'identity-1'));
        app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'identity-1', 'lat' => 6.2, 'lon' => -75.5, 'type' => 'other']);
        $before = [Camera::count(), CameraVerification::count()];

        $reanalysed = $service->analyze($run);
        $item = $reanalysed->items()->where('analysis_generation', $reanalysed->analysis_generation)->firstOrFail();

        $this->assertSame('noop', $item->classification);
        $this->assertSame($before, [Camera::count(), CameraVerification::count()]);
    }

    public function test_reanalysis_refreshes_a_new_nearby_duplicate_without_creating_or_verifying_a_camera(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create();
        $service = app(CameraImportService::class);
        $run = $service->analyze($this->importRun($service, $source, $jurisdiction, 'duplicate.csv', 'duplicate-1'));
        app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'existing-nearby', 'lat' => 6.20001, 'lon' => -75.5, 'type' => 'other']);
        $before = [Camera::count(), CameraVerification::count()];

        $reanalysed = $service->analyze($run);
        $item = $reanalysed->items()->where('analysis_generation', $reanalysed->analysis_generation)->firstOrFail();

        $this->assertSame('duplicate_review', $item->classification);
        $this->assertSame('blocked', $item->status);
        $this->assertSame($before, [Camera::count(), CameraVerification::count()]);
    }

    public function test_file_hash_change_or_missing_file_blocks_reanalysis_without_accepting_a_new_generation(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create();
        $service = app(CameraImportService::class);
        foreach (['changed', 'missing'] as $mode) {
            $run = $service->analyze($this->importRun($service, $source, $jurisdiction, "{$mode}.csv", "{$mode}-1"));
            $generation = $run->analysis_generation;
            if ($mode === 'changed') {
                Storage::disk('local')->put($run->stored_path, 'tampered');
            } else {
                Storage::disk('local')->delete($run->stored_path);
            }
            try {
                $service->analyze($run);
                $this->fail('Reanalysis must reject a changed or missing private file.');
            } catch (DomainException $exception) {
                $this->assertSame('file_hash_mismatch', $exception->getMessage());
            }
            $this->assertSame($generation, $run->fresh()->analysis_generation);
            $this->assertSame(0, Camera::where('source_id', $source->id)->where('external_id', "{$mode}-1")->count());
            $this->assertSame(0, CameraVerification::count());
        }
    }

    public function test_reanalysis_is_blocked_after_any_item_has_applied(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create();
        $service = app(CameraImportService::class);
        $run = $service->analyze($this->importRun($service, $source, $jurisdiction, 'applied.csv', 'applied-1'));
        $service->apply($run);

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('Run cannot be analyzed after items have been applied.');
        $service->analyze($run);
    }

    public function test_reproducibility_verifier_reports_all_evidence_drift_statuses_without_mutating_history(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create();
        $service = app(CameraImportService::class);
        $verifier = app(CameraImportReproducibilityVerifier::class);
        $clean = $service->analyze($this->importRun($service, $source, $jurisdiction, 'clean.csv', 'clean-1'));
        $before = [CameraImportRun::count(), CameraImportItem::count(), Camera::count(), CameraVerification::count(), AuditLog::count()];

        $this->assertSame('reproducible', $verifier->verify($clean)['status']);
        Storage::disk('local')->put($clean->stored_path, 'tampered');
        $this->assertSame('file_changed', $verifier->verify($clean)['status']);

        $profile = $service->analyze($this->importRun($service, $source, $jurisdiction, 'profile.csv', 'profile-1'));
        DB::table('camera_import_runs')->where('id', $profile->id)->update(['profile_sha256' => str_repeat('0', 64)]);
        $this->assertSame('profile_changed', $verifier->verify($profile->fresh())['status']);

        $provenance = $service->analyze($this->importRun($service, $source, $jurisdiction, 'source.csv', 'source-1'));
        $source->update(['authority' => 'Changed authority']);
        $this->assertSame('source_changed', $verifier->verify($provenance)['status']);
        $source->update(['authority' => $provenance->source_snapshot['authority']]);

        $version = $service->analyze($this->importRun($service, $source, $jurisdiction, 'version.csv', 'version-1'));
        DB::table('camera_import_runs')->where('id', $version->id)->update(['analysis_schema_version' => 99]);
        $this->assertSame('unsupported_old_version', $verifier->verify($version->fresh())['status']);
        $this->assertSame($before[2], Camera::count());
        $this->assertSame($before[3], CameraVerification::count());
        $this->assertSame($before[4] + 6, AuditLog::count());
    }

    public function test_reproducibility_command_emits_stable_json_and_is_read_only(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create();
        $service = app(CameraImportService::class);
        $run = $service->analyze($this->importRun($service, $source, $jurisdiction, 'command.csv', 'command-1'));
        $before = [CameraImportRun::count(), CameraImportItem::count(), Camera::count(), CameraVerification::count(), AuditLog::count()];

        $this->assertSame(0, Artisan::call('picoradar:cameras:import:verify-reproducibility', ['runId' => $run->id]));
        $result = json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame(['schema' => 'picoradar.camera-import-reproducibility.v1', 'status' => 'reproducible', 'runId' => $run->id], $result);
        $this->assertSame($before, [CameraImportRun::count(), CameraImportItem::count(), Camera::count(), CameraVerification::count(), AuditLog::count()]);
    }

    private function importRun(CameraImportService $service, CameraSource $source, Jurisdiction $jurisdiction, string $name, string $externalId): CameraImportRun
    {
        return $service->upload(UploadedFile::fake()->createWithContent($name, "external_id,municipality_code,lat,lon,type\n{$externalId},05001,6.2,-75.5,other\n"), $source, 'delta', $jurisdiction);
    }

    private function geography(): array
    {
        $country = GeographicUnit::create(['key' => 'colombia', 'code' => '00', 'level' => GeographicUnitLevel::Country, 'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'test', 'source_version' => '1']);
        $department = GeographicUnit::create(['parent_id' => $country->id, 'key' => 'antioquia', 'code' => '05', 'level' => GeographicUnitLevel::Department, 'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true, 'source_system' => 'test', 'source_version' => '1']);
        $municipality = GeographicUnit::create(['parent_id' => $department->id, 'key' => 'medellin', 'code' => '05001', 'level' => GeographicUnitLevel::Municipality, 'name' => 'Medellín', 'normalized_name' => 'medellin', 'is_active' => true, 'source_system' => 'test', 'source_version' => '1']);
        $jurisdiction = Jurisdiction::create(['key' => 'co-ant-medellin', 'name' => 'Medellín', 'kind' => 'city', 'primary_geographic_unit_id' => $municipality->id, 'enabled' => true, 'timezone' => 'America/Bogota']);
        $jurisdiction->geographicUnits()->attach($municipality->id);

        return [$jurisdiction->fresh(), $municipality];
    }
}
