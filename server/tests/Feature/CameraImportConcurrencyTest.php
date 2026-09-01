<?php

namespace Tests\Feature;

use App\Enums\CameraStatus;
use App\Enums\GeographicUnitLevel;
use App\Models\AuditLog;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraSource;
use App\Models\CameraVerification;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\CameraDuplicateDetector;
use App\Services\CameraImportDiffService;
use App\Services\CameraImportPreApplyValidator;
use App\Services\CameraImportProfileValidator;
use App\Services\CameraImportService;
use App\Services\CameraRegistryService;
use App\Services\DatasetAuditLogger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class CameraImportConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_partial_apply_resumes_without_reapplying_completed_items(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $calls = 0;
        $failing = $this->service(function (string $point) use (&$calls): void {
            if ($point === 'apply.after_camera_mutation' && ++$calls === 2) {
                throw new \RuntimeException('synthetic item two failure');
            }
        });
        $run = $failing->analyze($failing->upload($this->threeRows('resume'), $source, 'delta', $jurisdiction));

        $first = $failing->apply($run);
        $items = CameraImportItem::where('run_id', $run->id)->orderBy('row_number')->get();
        $this->assertSame('ready', $first->status);
        $this->assertSame('applied', $items[0]->status);
        $this->assertSame('ready', $items[1]->status);
        $this->assertSame('ready', $items[2]->status);
        $this->assertSame(1, Camera::count());
        $this->assertSame(0, AuditLog::where('action', 'camera_import.applied')->count());

        $result = app(CameraImportService::class)->apply($first);
        $this->assertSame('applied', $result->status);
        $this->assertSame(3, Camera::count());
        $this->assertSame(3, CameraImportItem::where('run_id', $run->id)->where('status', 'applied')->count());
        $this->assertSame(1, AuditLog::where('action', 'camera_import.applied')->count());
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_fault_injection_after_create_rolls_back_camera_and_keeps_run_retryable(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = $this->service(fn (string $point) => $point === 'apply.after_camera_mutation' ? throw new \RuntimeException('create failure') : null);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('create.csv', "external_id,municipality_code,lat,lon,type\ncreate-failure,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));

        $result = $service->apply($run);

        $this->assertSame('ready', $result->status);
        $this->assertSame(['apply_failed' => 1], $result->error_summary);
        $this->assertSame(0, Camera::where('external_id', 'create-failure')->count());
        $this->assertSame('ready', $run->items()->firstOrFail()->fresh()->status);
        $this->assertSame(0, AuditLog::where('action', 'camera_import.item_applied')->count());
        $this->assertSame(0, AuditLog::where('action', 'camera_import.applied')->count());
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_fault_injection_after_update_rolls_back_master_data_and_keeps_item_unapplied(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $camera = app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'update-failure', 'lat' => 6.2442, 'lon' => -75.5812, 'type' => 'other', 'name' => 'Original']);
        $service = $this->service(fn (string $point) => $point === 'apply.after_camera_mutation' ? throw new \RuntimeException('update failure') : null);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('update.csv', "external_id,municipality_code,lat,lon,type,name\nupdate-failure,05001,6.2443,-75.5812,other,Changed\n"), $source, 'delta', $jurisdiction));

        $result = $service->apply($run);

        $this->assertSame('ready', $result->status);
        $this->assertSame(CameraStatus::Draft, $camera->fresh()->status);
        $this->assertSame('Original', $camera->fresh()->name);
        $this->assertSame('ready', $run->items()->firstOrFail()->fresh()->status);
        $this->assertSame(0, AuditLog::where('action', 'camera_import.item_applied')->count());
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_an_apply_already_owned_by_another_worker_is_not_processed_twice(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('owned.csv', "external_id,municipality_code,lat,lon,type\nowned-1,05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        $run->update(['status' => 'applying', 'apply_started_at' => now()]);

        $result = $service->apply($run);

        $this->assertSame('applying', $result->status);
        $this->assertSame(0, Camera::where('external_id', 'owned-1')->count());
        $this->assertSame(0, AuditLog::where('action', 'camera_import.item_applied')->count());
        $this->assertSame(0, CameraVerification::count());
    }

    public function test_two_runs_racing_for_one_source_external_id_leave_exactly_one_camera(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $contents = "external_id,municipality_code,lat,lon,type\ntwo-run-1,05001,6.2442,-75.5812,other\n";
        $first = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('one.csv', $contents), $source, 'delta', $jurisdiction));
        $second = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('two.csv', $contents), $source, 'delta', $jurisdiction));

        $service->apply($first);
        $result = $service->apply($second);

        $this->assertSame(1, Camera::where('source_id', $source->id)->where('external_id', 'two-run-1')->count());
        $this->assertSame('applied_with_blocks', $result->status);
        $this->assertSame('blocked', $second->items()->firstOrFail()->fresh()->status);
        $this->assertSame(1, AuditLog::where('action', 'camera_import.item_applied')->count());
        $this->assertSame(0, CameraVerification::count());
    }

    private function service(?\Closure $failureHook = null): CameraImportService
    {
        return new CameraImportService(app(CameraRegistryService::class), app(CameraDuplicateDetector::class), app(DatasetAuditLogger::class), app(CameraImportPreApplyValidator::class), app(CameraImportDiffService::class), app(CameraImportProfileValidator::class), $failureHook);
    }

    private function threeRows(string $prefix): UploadedFile
    {
        return UploadedFile::fake()->createWithContent("{$prefix}.csv", "external_id,municipality_code,lat,lon,type\n{$prefix}-1,05001,6.2400,-75.5812,other\n{$prefix}-2,05001,6.2500,-75.5812,other\n{$prefix}-3,05001,6.2600,-75.5812,other\n");
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
