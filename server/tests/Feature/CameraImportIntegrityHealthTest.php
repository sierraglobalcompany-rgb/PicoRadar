<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Models\AuditLog;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraImportRun;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\CameraImportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CameraImportIntegrityHealthTest extends TestCase
{
    use RefreshDatabase;

    public function test_integrity_reports_the_item_run_file_and_counter_contracts_without_repairing_them(): void
    {
        $run = $this->analyzedRun();
        $item = $run->items()->firstOrFail();
        Storage::disk('local')->put($run->stored_path, 'tampered bytes');
        DB::table('camera_import_runs')->where('id', $run->id)->update(['total_rows' => 9, 'status' => 'impossible']);
        DB::table('camera_import_items')->where('id', $item->id)->update(['status' => 'applied', 'classification' => 'impossible', 'applied_camera_id' => null, 'applied_at' => null, 'resolved_by_id' => User::factory()->create()->id, 'resolved_at' => null]);
        $before = [CameraImportRun::findOrFail($run->id)->updated_at->toISOString(), CameraImportItem::findOrFail($item->id)->updated_at->toISOString(), Camera::count(), AuditLog::count()];

        $this->assertSame(1, Artisan::call('picoradar:cameras:imports:integrity', ['--json' => true, '--fail-on-error' => true]));
        $payload = json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR);
        $codes = array_column($payload['errors'], 'code');

        $this->assertSame('picoradar.camera-import-integrity.v1', $payload['schema']);
        $this->assertGreaterThanOrEqual(6, $payload['errorCount']);
        foreach (['impossible_run_state', 'file_hash_mismatch', 'counter_mismatch', 'impossible_item_state', 'applied_item_missing_application', 'resolution_missing_actor_or_time'] as $code) {
            $this->assertContains($code, $codes);
        }
        $this->assertSame($before, [CameraImportRun::findOrFail($run->id)->updated_at->toISOString(), CameraImportItem::findOrFail($item->id)->updated_at->toISOString(), Camera::count(), AuditLog::count()]);
    }

    public function test_health_reports_storage_drift_and_stuck_runs_without_repairing_or_deleting(): void
    {
        [$jurisdiction] = $this->geography();
        $run = $this->analyzedRun($jurisdiction);
        $missing = $this->analyzedRun($jurisdiction);
        Storage::disk('local')->delete($missing->stored_path);
        Storage::disk('local')->put($run->stored_path, 'tampered bytes');
        Storage::disk('local')->put('camera-imports/orphan/source.csv', 'orphan');
        DB::table('camera_import_runs')->where('id', $run->id)->update(['status' => 'applying', 'apply_started_at' => now()->subMinutes(31)]);
        $before = [CameraImportRun::count(), CameraImportItem::count(), Camera::count(), AuditLog::count(), Storage::disk('local')->exists('camera-imports/orphan/source.csv')];

        $this->assertSame(0, Artisan::call('picoradar:cameras:imports:health', ['--json' => true]));
        $payload = json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame('picoradar.camera-import-health.v1', $payload['schema']);
        $this->assertSame(1, $payload['stuckApplying']);
        $this->assertSame(1, $payload['missingFiles']);
        $this->assertSame(1, $payload['hashMismatches']);
        $this->assertGreaterThanOrEqual(1, $payload['orphanStorage']);
        $this->assertGreaterThan(0, $payload['storageBytes']);
        $this->assertSame($before, [CameraImportRun::count(), CameraImportItem::count(), Camera::count(), AuditLog::count(), Storage::disk('local')->exists('camera-imports/orphan/source.csv')]);
    }

    private function analyzedRun(?Jurisdiction $jurisdiction = null): CameraImportRun
    {
        $jurisdiction ??= $this->geography()[0];
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);

        return app(CameraImportService::class)->analyze(app(CameraImportService::class)->upload(UploadedFile::fake()->createWithContent('integrity.csv', "external_id,municipality_code,lat,lon,type\nintegrity-".uniqid().",05001,6.2442,-75.5812,other\n"), $source, 'delta', $jurisdiction));
    }

    private function geography(): array
    {
        $country = GeographicUnit::create(['key' => 'colombia-'.uniqid(), 'code' => '00'.random_int(10, 99), 'level' => GeographicUnitLevel::Country, 'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'test', 'source_version' => '1']);
        $department = GeographicUnit::create(['parent_id' => $country->id, 'key' => 'antioquia-'.uniqid(), 'code' => '05'.random_int(10, 99), 'level' => GeographicUnitLevel::Department, 'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true, 'source_system' => 'test', 'source_version' => '1']);
        $municipality = GeographicUnit::create(['parent_id' => $department->id, 'key' => 'medellin-'.uniqid(), 'code' => '05001', 'level' => GeographicUnitLevel::Municipality, 'name' => 'Medellín', 'normalized_name' => 'medellin', 'is_active' => true, 'source_system' => 'test', 'source_version' => '1']);
        $jurisdiction = Jurisdiction::create(['key' => 'co-ant-medellin-'.uniqid(), 'name' => 'Medellín', 'kind' => 'city', 'primary_geographic_unit_id' => $municipality->id, 'enabled' => true, 'timezone' => 'America/Bogota']);
        $jurisdiction->geographicUnits()->attach($municipality->id);

        return [$jurisdiction->fresh(), $municipality];
    }
}
