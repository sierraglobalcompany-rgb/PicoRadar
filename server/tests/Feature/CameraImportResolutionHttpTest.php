<?php

namespace Tests\Feature;

use App\Enums\CameraStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\OperatorRole;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\CameraImportService;
use App\Services\CameraRegistryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CameraImportResolutionHttpTest extends TestCase
{
    use RefreshDatabase;

    public function test_reviewer_and_commercial_are_forbidden_for_every_resolution_and_editor_cannot_allow_create(): void
    {
        [$run, $item] = $this->item();
        $actions = ['link_existing', 'allow_create', 'municipality_override', 'type_override', 'skip', 'choose_canonical_file_row'];
        foreach ([OperatorRole::Reviewer, OperatorRole::Commercial] as $role) {
            $user = User::factory()->create(['role' => $role, 'is_active' => true]);
            foreach ($actions as $action) {
                $this->actingAs($user)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => $action, 'updated_at' => $item->updated_at->toISOString(), 'reason' => 'authorized test'])->assertForbidden();
            }
        }
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->updated_at->toISOString(), 'reason' => 'override'])->assertForbidden();
    }

    public function test_every_resolution_action_has_a_shared_stale_http_guard(): void
    {
        [$run, $item] = $this->item();
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        foreach (['link_existing', 'allow_create', 'municipality_override', 'type_override', 'skip', 'choose_canonical_file_row'] as $action) {
            $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => $action, 'updated_at' => $item->updated_at->copy()->subSecond()->toISOString(), 'reason' => 'override'])->assertStatus(409);
            $this->assertSame('ready', $item->fresh()->status);
        }
    }

    public function test_admin_and_super_admin_can_allow_duplicate_creation_with_a_server_owned_plain_text_reason(): void
    {
        [$run, $item] = $this->duplicateItem();
        foreach ([OperatorRole::Admin, OperatorRole::SuperAdmin] as $role) {
            $operator = User::factory()->create(['role' => $role, 'is_active' => true]);
            $this->actingAs($operator)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->fresh()->updated_at->toISOString(), 'reason' => '<script>reviewed duplicate</script>', 'resolved_by_id' => 999, 'resolved_at' => now()->addDay(), 'status' => 'applied'])->assertRedirect();
            $resolved = $item->fresh();
            $this->assertSame('create_ready', $resolved->classification);
            $this->assertSame('ready', $resolved->status);
            $this->assertSame('reviewed duplicate', $resolved->resolution['reason']);
            $this->assertSame($operator->id, $resolved->resolved_by_id);
            $this->assertNotNull($resolved->resolved_at);
        }
    }

    public function test_allow_create_does_not_bypass_exact_identity_uniqueness_at_http_apply(): void
    {
        [$run, $item, $source, $jurisdiction, $municipality] = $this->duplicateItem(true);
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->updated_at->toISOString(), 'reason' => 'Reviewed'])->assertRedirect();
        app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'duplicate-1', 'lat' => 6.2, 'lon' => -75.5, 'type' => 'other']);
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $run))->assertRedirect();

        $this->assertSame(1, Camera::where('source_id', $source->id)->where('external_id', 'duplicate-1')->count());
        $this->assertSame('blocked', $item->fresh()->status);
    }

    public function test_allow_create_validates_reason_edges_and_preserves_plain_unicode_text(): void
    {
        [$run, $item] = $this->duplicateItem();
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        foreach ([null, '', '   '] as $reason) {
            $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->fresh()->updated_at->toISOString(), 'reason' => $reason])->assertRedirect()->assertSessionHasErrors('item');
            $this->assertSame('blocked', $item->fresh()->status);
        }
        $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->fresh()->updated_at->toISOString(), 'reason' => str_repeat('x', 1001)])->assertRedirect()->assertSessionHasErrors('reason');
        $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->fresh()->updated_at->toISOString(), 'reason' => str_repeat('x', 1000)])->assertRedirect();
        $this->assertSame(str_repeat('x', 1000), $item->fresh()->resolution['reason']);
        $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->fresh()->updated_at->toISOString(), 'reason' => 'Revisión Bogotá áéíóú'])->assertRedirect();
        $this->assertSame('Revisión Bogotá áéíóú', $item->fresh()->resolution['reason']);
    }

    public function test_resolution_route_rejects_cross_run_item_tampering(): void
    {
        [$run, , $source, $jurisdiction] = $this->duplicateItem(true);
        $service = app(CameraImportService::class);
        $otherRun = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('other.csv', "external_id,municipality_code,lat,lon,type\nother,05001,6.4,-75.5,other\n"), $source, 'delta', $jurisdiction));
        $otherItem = $otherRun->items()->firstOrFail();
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $otherItem]), ['action' => 'allow_create', 'updated_at' => $otherItem->updated_at->toISOString(), 'reason' => 'tamper', 'run_id' => $run->id, 'item_id' => $otherItem->id, 'analysis_generation' => 999, 'profile_sha256' => 'fake', 'file_sha256' => 'fake'])->assertNotFound();
        $this->assertSame('ready', $otherItem->fresh()->status);
    }

    public function test_allow_create_keeps_source_and_file_integrity_blocks_fail_closed(): void
    {
        [$run, $item, $source, $jurisdiction] = $this->duplicateItem(true);
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->updated_at->toISOString(), 'reason' => 'reviewed'])->assertRedirect();
        $before = Camera::count();
        $source->update(['is_active' => false]);
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $run))->assertRedirect();
        $this->assertSame('ready', $run->fresh()->status);
        $this->assertSame(['source_not_operational' => 1], $run->fresh()->error_summary);
        $this->assertSame($before, Camera::count());

        $source->update(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $fileRun = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('file.csv', "external_id,municipality_code,lat,lon,type\nfile-override,05001,6.2,-75.5,other\n"), $source, 'delta', $jurisdiction));
        $fileItem = $fileRun->items()->firstOrFail();
        $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$fileRun, $fileItem]), ['action' => 'allow_create', 'updated_at' => $fileItem->updated_at->toISOString(), 'reason' => 'reviewed'])->assertRedirect();
        Storage::disk('local')->put($fileRun->stored_path, 'tampered');
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $fileRun))->assertRedirect();
        $this->assertSame(['file_hash_mismatch' => 1], $fileRun->fresh()->error_summary);
        $this->assertSame($before, Camera::count());
    }

    public function test_allow_create_cannot_bypass_coverage_or_operational_exact_identity(): void
    {
        [$run, $item, $source, $jurisdiction, $municipality] = $this->duplicateItem(true);
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$run, $item]), ['action' => 'allow_create', 'updated_at' => $item->updated_at->toISOString(), 'reason' => 'reviewed'])->assertRedirect();
        $jurisdiction->geographicUnits()->detach($municipality->id);
        $before = Camera::count();
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $run))->assertRedirect();
        $this->assertSame($before, Camera::count());
        $this->assertSame('blocked', $item->fresh()->status);

        $jurisdiction->geographicUnits()->attach($municipality->id);
        foreach ([CameraStatus::Verified, CameraStatus::Active, CameraStatus::Inactive, CameraStatus::Retired] as $status) {
            $externalId = 'operational-'.$status->value;
            $service = app(CameraImportService::class);
            $next = $service->analyze($service->upload(UploadedFile::fake()->createWithContent("{$externalId}.csv", "external_id,municipality_code,lat,lon,type\n{$externalId},05001,6.2,-75.5,other\n"), $source, 'delta', $jurisdiction));
            $nextItem = $next->items()->firstOrFail();
            $this->actingAs($admin)->post(route('admin.camera-imports.items.resolve', [$next, $nextItem]), ['action' => 'allow_create', 'updated_at' => $nextItem->updated_at->toISOString(), 'reason' => 'reviewed'])->assertRedirect();
            $camera = app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => $externalId, 'lat' => 6.2, 'lon' => -75.5, 'type' => 'other']);
            $camera->forceFill(['status' => $status])->save();
            $this->actingAs($admin)->post(route('admin.camera-imports.apply', $next))->assertRedirect();
            $this->assertSame(1, Camera::where('source_id', $source->id)->where('external_id', $externalId)->count());
            $this->assertSame($status, $camera->fresh()->status);
            $this->assertSame('blocked', $nextItem->fresh()->status);
        }
    }

    private function item(): array
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('resolution.csv', "external_id,municipality_code,lat,lon,type\nresolution-1,05001,6.2,-75.5,other\n"), $source, 'delta', $jurisdiction));

        return [$run, $run->items()->firstOrFail()];
    }

    private function duplicateItem(bool $details = false): array
    {
        [$jurisdiction, $municipality] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'nearby', 'lat' => 6.20001, 'lon' => -75.5, 'type' => 'other']);
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('duplicate.csv', "external_id,municipality_code,lat,lon,type\nduplicate-1,05001,6.2,-75.5,other\n"), $source, 'delta', $jurisdiction));
        $result = [$run, $run->items()->firstOrFail(), $source, $jurisdiction, $municipality];

        return $details ? $result : array_slice($result, 0, 2);
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
