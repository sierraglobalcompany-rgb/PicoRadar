<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraImportRun;
use App\Models\CameraVerification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class CameraImportCliTest extends TestCase
{
    use RefreshDatabase;

    public function test_check_is_pure_and_its_json_output_has_a_versioned_schema(): void
    {
        $temporary = tempnam(sys_get_temp_dir(), 'picoradar-import-');
        $path = $temporary.'.csv';
        rename($temporary, $path);
        file_put_contents($path, "lat,lon\n6.2,-75.5\n");
        $before = [CameraImportRun::count(), CameraImportItem::count(), Camera::count(), CameraVerification::count(), AuditLog::count()];

        $this->assertSame(0, Artisan::call('picoradar:cameras:import:check', ['file' => $path, '--json' => true]));
        $output = json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame('picoradar.camera-import-check.v1', $output['schema']);
        $this->assertTrue($output['valid']);
        $this->assertSame($before, [CameraImportRun::count(), CameraImportItem::count(), Camera::count(), CameraVerification::count(), AuditLog::count()]);
        unlink($path);
    }

    public function test_import_health_and_integrity_emit_json_only(): void
    {
        $this->assertSame(0, Artisan::call('picoradar:cameras:imports:health', ['--json' => true]));
        $health = json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR);
        $this->assertSame(0, Artisan::call('picoradar:cameras:imports:integrity', ['--json' => true]));
        $integrity = json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame('picoradar.camera-import-health.v1', $health['schema']);
        $this->assertSame('picoradar.camera-import-integrity.v1', $integrity['schema']);
    }
}
