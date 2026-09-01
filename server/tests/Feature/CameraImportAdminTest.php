<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Enums\OperatorRole;
use App\Models\Camera;
use App\Models\CameraImportItem;
use App\Models\CameraImportRun;
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

class CameraImportAdminTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_editor_can_upload_and_analyze_but_only_an_administrator_can_apply(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->get(route('admin.camera-imports.index'))->assertOk();
        $this->actingAs($editor)->post(route('admin.camera-imports.store'), ['source_id' => $source->id, 'default_jurisdiction_id' => $jurisdiction->id, 'import_mode' => 'delta', 'file' => UploadedFile::fake()->createWithContent('operator.csv', "external_id,municipality_code,lat,lon,type\noperator-1,05001,6.2442,-75.5812,other\n")])->assertRedirect();
        $run = CameraImportRun::query()->firstOrFail();
        $this->actingAs($editor)->post(route('admin.camera-imports.analyze', $run))->assertRedirect();
        $this->actingAs($editor)->post(route('admin.camera-imports.apply', $run))->assertForbidden();
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $run))->assertRedirect();
        $this->assertSame('applied', $run->fresh()->status);
    }

    public function test_commercial_is_denied_and_a_stale_skip_resolution_returns_conflict(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);
        $this->actingAs($commercial)->get(route('admin.camera-imports.index'))->assertForbidden();
        $service = app(CameraImportService::class);
        $run = $service->analyze($service->upload(UploadedFile::fake()->createWithContent('conflict.csv', "external_id,municipality_code,lat,lon,type\nconflict-1,05001,6.2442,-75.5812,other\nconflict-1,05001,6.2443,-75.5812,other\n"), $source, 'delta', $jurisdiction));
        $item = CameraImportItem::where('run_id', $run->id)->firstOrFail();
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->actingAs($admin)->post(route('admin.camera-imports.items.skip', [$run, $item]), ['updated_at' => $item->updated_at->copy()->subSecond()->toISOString()])->assertStatus(409);
        $this->assertSame('blocked', $item->fresh()->status);
    }

    public function test_http_role_matrix_enforces_view_edit_and_apply_server_side(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $run = $this->readyRun($source, $jurisdiction, 'roles-1');
        foreach ([OperatorRole::SuperAdmin, OperatorRole::Admin] as $role) {
            $operator = User::factory()->create(['role' => $role, 'is_active' => true]);
            $this->actingAs($operator)->get(route('admin.camera-imports.index'))->assertOk();
            $this->actingAs($operator)->post(route('admin.camera-imports.apply', $run))->assertRedirect();
            $run->refresh()->update(['status' => 'ready', 'apply_finished_at' => null]);
        }
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->get(route('admin.camera-imports.index'))->assertOk();
        $this->actingAs($editor)->get(route('admin.camera-imports.create'))->assertOk();
        $this->actingAs($editor)->post(route('admin.camera-imports.apply', $run))->assertForbidden();
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $this->actingAs($reviewer)->get(route('admin.camera-imports.index'))->assertOk();
        $this->actingAs($reviewer)->get(route('admin.camera-imports.create'))->assertForbidden();
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);
        $this->actingAs($commercial)->get(route('admin.camera-imports.index'))->assertForbidden();
    }

    public function test_upload_request_ignores_tampered_server_controlled_fields(): void
    {
        [$jurisdiction] = $this->geography();
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->post(route('admin.camera-imports.store'), ['source_id' => $source->id, 'default_jurisdiction_id' => $jurisdiction->id, 'import_mode' => 'delta', 'file' => UploadedFile::fake()->createWithContent('../../unsafe.csv', "external_id,municipality_code,lat,lon,type\ntamper-1,05001,6.2,-75.5,other\n"), 'status' => 'applied', 'classification' => 'create_ready', 'file_sha256' => 'fake', 'applied_camera_id' => 99, 'resolved_by_id' => 99, 'resolved_at' => now()->addDay(), 'analysis_generation' => 999, 'profile_sha256' => 'fake', 'analysis_result_hash' => 'fake'])->assertRedirect();
        $run = CameraImportRun::query()->latest('id')->firstOrFail();

        $this->assertSame('uploaded', $run->status);
        $this->assertSame(0, $run->analysis_generation);
        $this->assertNotSame('fake', $run->file_sha256);
        $this->assertNotSame('fake', $run->profile_sha256);
        $this->assertStringNotContainsString('..', $run->stored_path);
        $this->assertStringNotContainsString('..', $run->original_filename);
    }

    public function test_http_apply_returns_controlled_recovery_responses_without_camera_mutation(): void
    {
        [$jurisdiction] = $this->geography();
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $source = CameraSource::factory()->create(['is_active' => true, 'verified_at' => now()]);
        $disabled = $this->readyRun($source, $jurisdiction, 'disabled-http');
        $source->update(['is_active' => false]);
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $disabled))->assertRedirect();
        $this->assertSame('ready', $disabled->fresh()->status);
        $this->assertSame(['source_not_operational' => 1], $disabled->fresh()->error_summary);
        $this->assertSame(0, Camera::where('external_id', 'disabled-http')->count());
        $source->update(['is_active' => true, 'verified_at' => now()]);
        $unverified = $this->readyRun($source, $jurisdiction, 'unverified-http');
        $source->update(['verified_at' => null]);
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $unverified))->assertRedirect();
        $this->assertSame(['source_not_operational' => 1], $unverified->fresh()->error_summary);
        $this->assertSame(0, Camera::where('external_id', 'unverified-http')->count());
        $source->update(['verified_at' => now()]);
        $claimed = $this->readyRun($source, $jurisdiction, 'claimed-http');
        $municipality = GeographicUnit::query()->where('code', '05001')->firstOrFail();
        app(CameraRegistryService::class)->create(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'external_id' => 'claimed-http', 'lat' => 6.2, 'lon' => -75.5, 'type' => 'other']);
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $claimed))->assertRedirect();
        $this->assertSame('blocked', $claimed->items()->firstOrFail()->fresh()->status);
        $this->assertSame(1, Camera::where('external_id', 'claimed-http')->count());
        $missing = $this->readyRun($source, $jurisdiction, 'missing-http');
        Storage::disk('local')->delete($missing->stored_path);
        $this->actingAs($admin)->post(route('admin.camera-imports.apply', $missing))->assertRedirect();
        $this->assertSame(['file_hash_mismatch' => 1], $missing->fresh()->error_summary);
        $this->assertSame(0, Camera::where('external_id', 'missing-http')->count());
    }

    private function readyRun(CameraSource $source, Jurisdiction $jurisdiction, string $externalId): CameraImportRun
    {
        $service = app(CameraImportService::class);

        return $service->analyze($service->upload(UploadedFile::fake()->createWithContent("{$externalId}.csv", "external_id,municipality_code,lat,lon,type\n{$externalId},05001,6.2,-75.5,other\n"), $source, 'delta', $jurisdiction));
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
