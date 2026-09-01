<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\CameraImportRunComparator;
use App\Services\CameraImportService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class CameraImportComparisonTest extends TestCase
{
    use RefreshDatabase;

    public function test_snapshot_inferrs_removals_but_delta_does_not_and_compare_is_read_only(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $previous = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('previous.csv', "external_id,municipality_code,lat,lon,type\na,05001,6.2,-75.5,other\nb,05001,6.3,-75.5,other\n"), $source, 'snapshot', $jurisdiction));
        $snapshot = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('snapshot.csv', "external_id,municipality_code,lat,lon,type\na,05001,6.2000000,-75.5,other\n"), $source, 'snapshot', $jurisdiction));
        $delta = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('delta.csv', "external_id,municipality_code,lat,lon,type\na,05001,6.2,-75.5,other\n"), $source, 'delta', $jurisdiction));
        $comparator = app(CameraImportRunComparator::class);

        $snapshotDiff = $comparator->compare($previous, $snapshot);
        $deltaDiff = $comparator->compare($previous, $delta);
        $this->assertSame(1, $snapshotDiff['counts']['removed']);
        $this->assertSame(0, $deltaDiff['counts']['removed']);
        $this->assertSame(1, $snapshotDiff['counts']['unchanged']);
    }

    public function test_comparator_rejects_cross_source_comparison(): void
    {
        [$jurisdiction] = $this->geography();
        $service = app(CameraImportService::class);
        $one = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $two = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $left = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('one.csv', "external_id,municipality_code,lat,lon,type\na,05001,6.2,-75.5,other\n"), $one, 'snapshot', $jurisdiction));
        $right = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('two.csv', "external_id,municipality_code,lat,lon,type\na,05001,6.2,-75.5,other\n"), $two, 'snapshot', $jurisdiction));
        $this->expectException(DomainException::class);
        app(CameraImportRunComparator::class)->compare($left, $right);
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
