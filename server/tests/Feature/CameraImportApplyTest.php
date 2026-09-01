<?php

namespace Tests\Feature;

use App\Enums\CameraStatus;
use App\Enums\CameraType;
use App\Enums\GeographicUnitLevel;
use App\Models\AuditLog;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\CameraVerification;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\CameraImportService;
use App\Services\CameraRegistryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CameraImportApplyTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_csv_is_analyzed_and_applied_as_a_b03_draft_without_verification(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $file = UploadedFile::fake()->createWithContent('synthetic.csv', "external_id,municipality_code,lat,lon,type,speed_limit,name\nsynthetic-001,05001,6.2442,-75.5812,speed,50,Synthetic\n");
        $service = app(CameraImportService::class);
        $run = $service->upload($file, $source, 'delta', $jurisdiction);
        $beforeCameras = Camera::count();
        $beforeVerifications = CameraVerification::count();
        $run = $service->analyze($run);
        $this->assertSame('ready', $run->status);
        $this->assertSame(1, $run->create_ready_rows);
        $this->assertSame($beforeCameras, Camera::count());
        $this->assertSame($beforeVerifications, CameraVerification::count());
        $service->apply($run);
        $camera = Camera::where('source_id', $source->id)->where('external_id', 'synthetic-001')->firstOrFail();
        $this->assertSame(CameraStatus::Draft, $camera->status);
        $this->assertSame(CameraType::Speed, $camera->type);
        $this->assertSame(50, $camera->speed_limit);
        $this->assertFalse($camera->speed_limit_verified);
        $this->assertNull($camera->verified_at);
        $this->assertNull($camera->verification_fingerprint);
        $this->assertSame($beforeVerifications, CameraVerification::count());
    }

    public function test_a_changed_draft_is_updated_without_changing_its_identity_or_lifecycle(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $existing = app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'synthetic-002', 'lat' => 6.2442, 'lon' => -75.5812, 'type' => 'speed', 'speed_limit' => 50]);
        $file = UploadedFile::fake()->createWithContent('update.csv', "external_id,municipality_code,lat,lon,type,speed_limit,corridor\nsynthetic-002,05001,6.2443,-75.5812,speed,60,Updated corridor\n");
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload($file, $source, 'delta', $jurisdiction));
        $this->assertSame(1, $run->update_ready_rows);
        $beforeVerifications = CameraVerification::count();
        $service->apply($run);
        $updated = $existing->fresh();
        $this->assertSame($existing->id, $updated->id);
        $this->assertSame($existing->camera_id, $updated->camera_id);
        $this->assertSame(CameraStatus::Draft, $updated->status);
        $this->assertSame(60, $updated->speed_limit);
        $this->assertSame('Updated corridor', $updated->corridor);
        $this->assertSame($beforeVerifications, CameraVerification::count());
    }

    public function test_a_changed_rejected_camera_is_updated_without_resubmission_or_verification(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $camera = app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'rejected-001', 'lat' => 6.2442, 'lon' => -75.5812, 'type' => 'other']);
        $camera->forceFill(['status' => CameraStatus::Rejected])->save();
        $run = app(CameraImportService::class)->analyze(app(CameraImportService::class)->upload(UploadedFile::fake()->createWithContent('rejected.csv', "external_id,municipality_code,lat,lon,type,name\nrejected-001,05001,6.2443,-75.5812,other,Changed\n"), $source, 'delta', $jurisdiction));
        $this->assertSame(1, $run->update_ready_rows);
        app(CameraImportService::class)->apply($run);
        $updated = $camera->fresh();
        $this->assertSame(CameraStatus::Rejected, $updated->status);
        $this->assertSame('Changed', $updated->name);
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_changed_operational_and_retired_cameras_are_never_applied(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        foreach ([CameraStatus::Verified, CameraStatus::Active, CameraStatus::Inactive, CameraStatus::Retired] as $status) {
            $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
            $camera = app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'locked-'.$status->value, 'lat' => 6.2442, 'lon' => -75.5812, 'type' => 'other']);
            $camera->forceFill(['status' => $status])->save();
            $run = app(CameraImportService::class)->analyze(app(CameraImportService::class)->upload(UploadedFile::fake()->createWithContent('locked.csv', "external_id,municipality_code,lat,lon,type,name\nlocked-{$status->value},05001,6.2443,-75.5812,other,Changed\n"), $source, 'delta', $jurisdiction));
            $this->assertSame($status === CameraStatus::Retired ? 1 : 1, $run->blocked_rows);
            app(CameraImportService::class)->apply($run);
            $this->assertSame(6.2442, (float) $camera->fresh()->lat);
        }
    }

    public function test_same_file_identical_duplicate_has_one_applyable_canonical_row(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $csv = "external_id,municipality_code,lat,lon,type\ndupe-1,05001,6.2442,-75.5812,other\ndupe-1,05001,6.2442,-75.5812,other\n";
        $run = app(CameraImportService::class)->analyze(app(CameraImportService::class)->upload(UploadedFile::fake()->createWithContent('dupe.csv', $csv), $source, 'delta', $jurisdiction));
        $this->assertSame(1, $run->create_ready_rows);
        $this->assertSame(1, $run->duplicate_review_rows);
        $this->assertSame(1, $run->blocked_rows);
        app(CameraImportService::class)->apply($run);
        $this->assertSame(1, Camera::where('source_id', $source->id)->where('external_id', 'dupe-1')->count());
    }

    public function test_same_file_conflicting_duplicate_blocks_every_row(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $csv = "external_id,municipality_code,lat,lon,type\nconflict-1,05001,6.2442,-75.5812,other\nconflict-1,05001,6.2443,-75.5812,other\n";
        $run = app(CameraImportService::class)->analyze(app(CameraImportService::class)->upload(UploadedFile::fake()->createWithContent('conflict.csv', $csv), $source, 'delta', $jurisdiction));
        $this->assertSame(0, $run->create_ready_rows);
        $this->assertSame(2, $run->blocked_rows);
        $this->assertSame(2, $run->duplicate_review_rows);
        app(CameraImportService::class)->apply($run);
        $this->assertSame(0, Camera::where('source_id', $source->id)->where('external_id', 'conflict-1')->count());
    }

    public function test_pre_apply_source_and_coverage_changes_block_without_camera_mutation(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $file = UploadedFile::fake()->createWithContent('stale.csv', "external_id,municipality_code,lat,lon,type\nstale-1,05001,6.2442,-75.5812,other\n");
        $run = $service->analyze($service->upload($file, $source, 'delta', $jurisdiction));
        $source->update(['is_active' => false]);
        $service->apply($run);
        $this->assertSame(0, Camera::where('external_id', 'stale-1')->count());
        $source->update(['is_active' => true]);
        $run2 = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('coverage.csv', "external_id,municipality_code,lat,lon,type\nstale-2,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        $jurisdiction->geographicUnits()->detach($municipality->id);
        $service->apply($run2);
        $this->assertSame(0, Camera::where('external_id', 'stale-2')->count());
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_pre_apply_source_unverified_and_camera_state_change_block_without_mutation(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('unverified.csv', "external_id,municipality_code,lat,lon,type\nunverified-1,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        $source->update(['verified_at' => null]);
        $result = $service->apply($run);
        $this->assertSame('ready', $result->status);
        $this->assertSame(['source_not_operational' => 1], $result->error_summary);
        $this->assertSame(0, Camera::where('external_id', 'unverified-1')->count());
        $source->update(['verified_at' => now()]);
        $camera = app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'state-1', 'lat' => 6.2442, 'lon' => -75.5812, 'type' => 'other']);
        $run2 = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('state.csv', "external_id,municipality_code,lat,lon,type,name\nstate-1,05001,6.2443,-75.5812,other,Changed\n"), $source, 'delta', $jurisdiction));
        app(CameraRegistryService::class)->submit($camera);
        $service->apply($run2);
        $this->assertSame(CameraStatus::InReview, $camera->fresh()->status);
        $this->assertSame(6.2442, (float) $camera->fresh()->lat);
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_update_ready_blocks_when_camera_becomes_operational_or_retired_before_apply(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        foreach ([CameraStatus::Verified, CameraStatus::Active, CameraStatus::Inactive, CameraStatus::Retired] as $status) {
            $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
            $camera = app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'stale-'.$status->value, 'lat' => 6.2442, 'lon' => -75.5812, 'type' => 'other']);
            $service = app(CameraImportService::class);
            $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('stale-state.csv', "external_id,municipality_code,lat,lon,type,name\nstale-{$status->value},05001,6.2443,-75.5812,other,Changed\n"), $source, 'delta', $jurisdiction));
            $this->assertSame(1, $run->update_ready_rows);
            $camera->forceFill(['status' => $status])->save();
            $service->apply($run);
            $item = $run->items()->firstOrFail()->fresh();
            $this->assertSame('blocked', $item->status);
            $this->assertSame(6.2442, (float) $camera->fresh()->lat);
        }
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_external_identity_claimed_after_analysis_blocks_without_duplicate_camera(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('race.csv', "external_id,municipality_code,lat,lon,type\nrace-1,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'race-1', 'lat' => 6.2442, 'lon' => -75.5812, 'type' => 'other']);
        $service->apply($run);
        $this->assertSame(1, Camera::where('source_id', $source->id)->where('external_id', 'race-1')->count());
        $this->assertSame('blocked', $run->items()->firstOrFail()->fresh()->status);
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_changed_or_missing_private_file_blocks_apply_without_camera_mutation(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('hash.csv', "external_id,municipality_code,lat,lon,type\nhash-1,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        Storage::disk('local')->put($run->stored_path, 'changed');
        $result = $service->apply($run);
        $this->assertSame(['file_hash_mismatch' => 1], $result->error_summary);
        $this->assertSame(0, Camera::where('external_id', 'hash-1')->count());
        $run2 = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('missing.csv', "external_id,municipality_code,lat,lon,type\nmissing-1,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        Storage::disk('local')->delete($run2->stored_path);
        $result2 = $service->apply($run2);
        $this->assertSame(['file_hash_mismatch' => 1], $result2->error_summary);
        $this->assertSame(0, Camera::where('external_id', 'missing-1')->count());
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_duplicate_or_dense_scan_appearing_after_analysis_blocks_apply(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('near.csv', "external_id,municipality_code,lat,lon,type\nnear-1,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'near-existing', 'lat' => 6.24421, 'lon' => -75.5812, 'type' => 'other']);
        $service->apply($run);
        $item = $run->items()->firstOrFail()->fresh();
        $this->assertSame('blocked', $item->status);
        $this->assertContains('duplicate_candidate', $item->errors);
        $this->assertSame(0, Camera::where('external_id', 'near-1')->count());
        $run2 = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('dense.csv', "external_id,municipality_code,lat,lon,type\ndense-1,05001,6.25,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        Camera::factory()->count(251)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'lat' => 6.25001, 'lon' => -75.5812, 'type' => CameraType::Other]);
        $service->apply($run2);
        $item2 = $run2->items()->firstOrFail()->fresh();
        $this->assertSame('blocked', $item2->status);
        $this->assertContains('duplicate_scan_capped', $item2->errors);
        $this->assertSame(0, Camera::where('external_id', 'dense-1')->count());
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_second_apply_is_idempotent_and_does_not_repeat_success_audits(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('once.csv', "external_id,municipality_code,lat,lon,type\nonce-1,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));

        $first = $service->apply($run);
        $cameraCount = Camera::count();
        $verificationCount = CameraVerification::count();
        $itemAuditCount = AuditLog::where('action', 'camera_import.item_applied')->count();
        $runAuditCount = AuditLog::where('action', 'camera_import.applied')->count();
        $second = $service->apply($first);

        $this->assertSame('applied', $second->status);
        $this->assertSame($cameraCount, Camera::count());
        $this->assertSame($verificationCount, CameraVerification::count());
        $this->assertSame($itemAuditCount, AuditLog::where('action', 'camera_import.item_applied')->count());
        $this->assertSame($runAuditCount, AuditLog::where('action', 'camera_import.applied')->count());
    }

    public function test_exact_file_reimport_reconciles_to_noop_without_creating_a_second_camera(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $contents = "external_id,municipality_code,lat,lon,type,name\nreimport-1,05001,6.2442,-75.5812,other,Stable\n";
        $first = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('first.csv', $contents), $source, 'delta', $jurisdiction));
        $service->apply($first);
        $cameraCount = Camera::count();

        $second = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('second.csv', $contents), $source, 'delta', $jurisdiction));
        $this->assertSame(1, $second->noop_rows);
        $result = $service->apply($second);

        $this->assertSame('applied', $result->status);
        $this->assertSame($cameraCount, Camera::count());
        $this->assertSame(0, CameraVerification::count());
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
