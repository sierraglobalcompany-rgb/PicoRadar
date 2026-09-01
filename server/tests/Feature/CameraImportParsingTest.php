<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\CameraImportProfileValidator;
use App\Services\CameraImportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class CameraImportParsingTest extends TestCase
{
    use RefreshDatabase;

    public function test_csv_supports_bom_semicolon_quoted_values_and_crlf(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $csv = "\xEF\xBB\xBFEXTERNAL_ID;MUNICIPALITY_CODE;LAT;LON;TYPE;NAME\r\nformat-1;05001;6.2000000;-75.5812;other;\"A; quoted \"\"camera\"\"\"\r\n";
        $run = app(CameraImportService::class)->analyze(app(CameraImportService::class)->upload(UploadedFile::fake()->createWithContent('format.csv', $csv), $source, 'delta', $jurisdiction));

        $this->assertSame('ready', $run->status);
        $this->assertSame(1, $run->create_ready_rows);
        $this->assertSame('generic_csv_v1', $run->profile_key);
        $this->assertNotNull($run->profile_sha256);
        $this->assertSame('UTF-8', $run->parser_options['encoding']);
    }

    public function test_csv_structural_headers_and_invalid_encoding_fail_the_run_without_camera_mutation(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $headers = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('headers.csv', "lat,LAT,lon\n6.2,6.2,-75.5\n"), $source, 'delta', $jurisdiction));
        $encoding = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('binary.csv', "lat,lon\n6.2,-75.5\0\n"), $source, 'delta', $jurisdiction));

        $this->assertSame('failed', $headers->status);
        $this->assertSame('failed', $encoding->status);
        $this->assertSame(0, Camera::count());
    }

    public function test_ndjson_keeps_line_level_errors_as_invalid_items(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $contents = "\n{\"external_id\":\"json-1\",\"municipality_code\":\"05001\",\"lat\":6.2,\"lon\":-75.5,\"type\":\"other\"}\n{broken}\n[]\n";
        $run = app(CameraImportService::class)->analyze(app(CameraImportService::class)->upload(UploadedFile::fake()->createWithContent('rows.ndjson', $contents), $source, 'delta', $jurisdiction));

        $this->assertSame('ready', $run->status);
        $this->assertSame(3, $run->total_rows);
        $this->assertSame(2, $run->invalid_rows);
        $this->assertContains('invalid_ndjson', CameraImportItem::where('run_id', $run->id)->orderBy('row_number')->get()[1]->errors);
    }

    public function test_geojson_uses_point_geometry_and_marks_unsupported_features_as_row_errors(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $document = ['type' => 'FeatureCollection', 'features' => [['type' => 'Feature', 'geometry' => ['type' => 'Point', 'coordinates' => [-75.5, 6.2]], 'properties' => ['external_id' => 'geo-1', 'municipality_code' => '05001', 'type' => 'other', 'lat' => 1]], ['type' => 'Feature', 'geometry' => ['type' => 'Polygon', 'coordinates' => []], 'properties' => []]]];
        $run = app(CameraImportService::class)->analyze(app(CameraImportService::class)->upload(UploadedFile::fake()->createWithContent('points.geojson', json_encode($document, JSON_THROW_ON_ERROR)), $source, 'delta', $jurisdiction));
        $items = CameraImportItem::where('run_id', $run->id)->orderBy('row_number')->get();

        $this->assertSame('ready', $run->status);
        $this->assertSame(6.2, $items[0]->normalized_payload['lat']);
        $this->assertContains('geometry_property_coordinate_conflict', $items[0]->warnings);
        $this->assertContains('unsupported_geometry', $items[1]->errors);
    }

    public function test_profile_hash_is_stable_and_is_snapshotted_on_the_run(): void
    {
        $profiles = app(CameraImportProfileValidator::class);
        $this->assertSame($profiles->hash('generic_csv_v1'), $profiles->hash('generic_csv_v1'));
        $this->expectException(\DomainException::class);
        $profiles->read('unknown_profile');
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
