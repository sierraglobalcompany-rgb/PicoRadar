<?php

namespace Tests\Feature;

use App\Enums\CameraType;
use App\Enums\GeographicUnitLevel;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\CameraImportResolutionService;
use App\Services\CameraImportService;
use App\Services\CameraRegistryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class CameraImportResolutionTest extends TestCase
{
    use RefreshDatabase;

    public function test_link_existing_allow_create_municipality_type_skip_and_canonical_resolutions_are_auditable(): void
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $imports = app(CameraImportService::class);
        $resolution = app(CameraImportResolutionService::class);
        $target = app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'target', 'lat' => 6.2, 'lon' => -75.5, 'type' => 'other']);

        $link = $this->item($imports, $source, $jurisdiction, ',05001,6.2,-75.5,other');
        $linked = $resolution->resolve($link, $link->updated_at, 'link_existing', ['camera_id' => $target->id]);
        $this->assertSame($target->id, $linked->matched_camera_id);
        $this->assertSame('noop', $linked->classification);

        $duplicate = $this->item($imports, $source, $jurisdiction, 'override,05001,6.20001,-75.5,other');
        $allowed = $resolution->resolve($duplicate, $duplicate->updated_at, 'allow_create', ['reason' => '<script>reviewed</script>']);
        $this->assertSame('create_ready', $allowed->classification);
        $this->assertSame('reviewed', $allowed->resolution['reason']);

        $municipalityItem = $this->item($imports, $source, $jurisdiction, 'municipality,unknown,6.3,-75.5,other');
        $municipalityResolved = $resolution->resolve($municipalityItem, $municipalityItem->updated_at, 'municipality_override', ['geographic_unit_id' => $municipality->id]);
        $this->assertSame('05001', $municipalityResolved->normalized_payload['municipality_code']);

        $typeItem = $this->item($imports, $source, $jurisdiction, 'typed,05001,6.4,-75.5,other');
        $typed = $resolution->resolve($typeItem, $typeItem->updated_at, 'type_override', ['type' => CameraType::Speed->value]);
        $this->assertSame('speed', $typed->normalized_payload['type']);

        $skipped = $resolution->resolve($typeItem->fresh(), $typeItem->fresh()->updated_at, 'skip', []);
        $this->assertSame('skipped', $skipped->status);

        $conflict = $imports->analyze($imports->upload(UploadedFile::fake()->createWithContent('conflict.csv', "external_id,municipality_code,lat,lon,type\nconflict,05001,6.5,-75.5,other\nconflict,05001,6.6,-75.5,other\n"), $source, 'delta', $jurisdiction));
        $chosen = $conflict->items()->orderBy('row_number')->firstOrFail();
        $canonical = $resolution->resolve($chosen, $chosen->updated_at, 'choose_canonical_file_row', ['row_number' => $chosen->row_number]);
        $this->assertSame('ready', $canonical->status);
        $this->assertSame(1, CameraImportItem::where('run_id', $conflict->id)->where('status', 'ready')->count());
        $this->assertSame(1, Camera::where('external_id', 'target')->count());
    }

    public function test_resolution_rejects_invalid_target_action_and_stale_version(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $item = $this->item(app(CameraImportService::class), $source, $jurisdiction, ',05001,6.2,-75.5,other');
        $service = app(CameraImportResolutionService::class);
        $this->expectException(\DomainException::class);
        $service->resolve($item, $item->updated_at->copy()->subSecond(), 'link_existing', ['camera_id' => 999999]);
    }

    private function item(CameraImportService $imports, CameraSource $source, Jurisdiction $jurisdiction, string $row): CameraImportItem
    {
        $run = $imports->analyze($imports->upload(UploadedFile::fake()->createWithContent('item.csv', "external_id,municipality_code,lat,lon,type\n{$row}\n"), $source, 'delta', $jurisdiction));

        return $run->items()->firstOrFail();
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
