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
use App\Services\CameraImportRunComparator;
use App\Services\CameraImportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class CameraImportScaleTest extends TestCase
{
    use RefreshDatabase;

    public function test_csv_and_ndjson_ten_thousand_row_imports_are_fully_analyzed_without_camera_mutations(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);

        $csv = "external_id,municipality_code,lat,lon,type\n".$this->csvRows('csv', 10_000);
        $csvRun = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('scale.csv', $csv), $source, 'delta', $jurisdiction));
        $ndjsonRun = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('scale.ndjson', $this->ndjsonRows('ndjson', 10_000)), $source, 'delta', $jurisdiction));

        foreach ([$csvRun, $ndjsonRun] as $run) {
            $this->assertSame('ready', $run->status);
            $this->assertSame(10_000, $run->total_rows);
            $this->assertSame(10_000, $run->create_ready_rows);
            $this->assertSame(0, $run->invalid_rows);
            $this->assertSame(10_000, CameraImportItem::query()->where('run_id', $run->id)->count());
        }
        $this->assertSame(0, Camera::query()->count());
        $this->assertSame(0, CameraVerification::query()->count());
    }

    public function test_comparator_handles_ten_thousand_rows_through_cursor_backed_input(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        [$previous, $current] = $this->emptyRuns($source, $jurisdiction);
        $this->insertItems($previous, 'same', 10_000);
        $this->insertItems($current, 'same', 9_900);
        $this->insertItems($current, 'added', 100, 9_900);

        $diff = app(CameraImportRunComparator::class)->compare($previous->fresh(), $current->fresh());

        $this->assertSame(100, $diff['counts']['added']);
        $this->assertSame(100, $diff['counts']['removed']);
        $this->assertSame(9_900, $diff['counts']['unchanged']);
        $this->assertSame(0, Camera::query()->count());
        $this->assertSame(0, CameraVerification::query()->count());
    }

    public function test_one_thousand_noop_analysis_emits_only_run_level_b04_audit_events(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $first = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('seed.csv', "external_id,municipality_code,lat,lon,type\n".$this->csvRows('noop', 1_000)), $source, 'delta', $jurisdiction));
        $service->apply($first);
        $before = AuditLog::query()->count();

        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('noop.csv', "external_id,municipality_code,lat,lon,type\n".$this->csvRows('noop', 1_000)), $source, 'delta', $jurisdiction));

        $this->assertSame(1_000, $run->noop_rows);
        $this->assertSame($before + 2, AuditLog::query()->count()); // creation + one run-level analysis event
        $this->assertSame(0, AuditLog::query()->where('action', 'camera_import.item_analyzed')->count());
        $this->assertSame(0, CameraVerification::query()->count());
    }

    public function test_b04_review_and_apply_indexes_are_present_in_the_schema_contract(): void
    {
        $runs = file_get_contents(database_path('migrations/2026_08_31_040000_create_camera_import_runs_table.php'));
        $items = file_get_contents(database_path('migrations/2026_08_31_040100_create_camera_import_items_table.php'));

        $this->assertStringContainsString("index(['source_id', 'status'])", $runs);
        $this->assertStringContainsString("index(['status', 'created_at'])", $runs);
        $this->assertStringContainsString("unique(['run_id', 'analysis_generation', 'row_number'])", $items);
        foreach (["index(['run_id', 'classification'])", "index(['run_id', 'status'])", "index(['run_id', 'external_id'])", "index('matched_camera_id')", "index('applied_camera_id')"] as $index) {
            $this->assertStringContainsString($index, $items);
        }
    }

    private function csvRows(string $prefix, int $count, int $offset = 0): string
    {
        $rows = [];
        for ($index = $offset; $index < $offset + $count; $index++) {
            // Keep synthetic points safely outside the B03 25m duplicate radius.
            $rows[] = "{$prefix}-{$index},05001,".(6.0 + $index / 1_000).',-75.5,other';
        }

        return implode("\n", $rows)."\n";
    }

    private function ndjsonRows(string $prefix, int $count): string
    {
        $rows = [];
        for ($index = 0; $index < $count; $index++) {
            $rows[] = json_encode(['external_id' => "{$prefix}-{$index}", 'municipality_code' => '05001', 'lat' => 6.0 + $index / 1_000, 'lon' => -75.5, 'type' => 'other'], JSON_THROW_ON_ERROR);
        }

        return implode("\n", $rows)."\n";
    }

    /** @return array{CameraImportRun, CameraImportRun} */
    private function emptyRuns(CameraSource $source, Jurisdiction $jurisdiction): array
    {
        $service = app(CameraImportService::class);
        $previous = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('previous.csv', "external_id,municipality_code,lat,lon,type\n"), $source, 'snapshot', $jurisdiction));
        $current = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('current.csv', "external_id,municipality_code,lat,lon,type\n"), $source, 'snapshot', $jurisdiction));

        return [$previous, $current];
    }

    private function insertItems(CameraImportRun $run, string $prefix, int $count, int $offset = 0): void
    {
        $now = now();
        foreach (array_chunk(range($offset, $offset + $count - 1), 500) as $chunk) {
            $rows = [];
            foreach ($chunk as $index) {
                $externalId = "{$prefix}-{$index}";
                $payload = ['external_id' => $externalId, 'municipality_code' => '05001', 'lat' => 6.2, 'lon' => -75.5, 'type' => 'other'];
                $rows[] = ['run_id' => $run->id, 'analysis_generation' => $run->analysis_generation, 'row_number' => $index + 1, 'raw_hash' => hash('sha256', $externalId), 'normalized_hash' => hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR)), 'external_id' => $externalId, 'normalized_payload' => json_encode($payload, JSON_THROW_ON_ERROR), 'classification' => 'create_ready', 'status' => 'ready', 'duplicate_scan_capped' => false, 'created_at' => $now, 'updated_at' => $now];
            }
            CameraImportItem::query()->insert($rows);
        }
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
