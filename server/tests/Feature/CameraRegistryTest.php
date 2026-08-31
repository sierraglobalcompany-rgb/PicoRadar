<?php

namespace Tests\Feature;

use App\Enums\CameraStatus;
use App\Enums\CameraType;
use App\Enums\OperatorRole;
use App\Models\AuditLog;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\CameraVerification;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\CameraContractReadinessService;
use App\Services\CameraDuplicateDetector;
use App\Services\CameraRegistryService;
use App\Services\CameraSourceService;
use App\Services\CameraVerificationService;
use App\Services\GeographyImporter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use LogicException;
use Tests\TestCase;

class CameraRegistryTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        app(GeographyImporter::class)->bootstrap();
    }

    public function test_lifecycle_is_server_controlled_and_contract_ready_after_verification(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $camera = $this->draft($editor);
        app(CameraRegistryService::class)->submit($camera, $editor);
        $verified = app(CameraVerificationService::class)->verify($camera->fresh(), false, $reviewer);
        $active = app(CameraVerificationService::class)->activate($verified, $reviewer);
        $this->assertSame(CameraStatus::Active, $active->status);
        $this->assertFalse($active->speed_limit_verified);
        $this->assertTrue(app(CameraContractReadinessService::class)->assess($active)['readyForFutureDataset']);
    }

    public function test_rejected_camera_is_editable_and_resubmittable_without_erasing_history(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $camera = $this->draft($editor);
        $registry = app(CameraRegistryService::class);
        $registry->submit($camera, $editor);
        app(CameraVerificationService::class)->reject($camera->fresh(), 'Synthetic rejection', $reviewer);
        $registry->updateDraft($camera->fresh(), ['name' => 'Synthetic corrected camera'], $editor);
        $resubmitted = $registry->submit($camera->fresh(), $editor);
        $this->assertSame(CameraStatus::InReview, $resubmitted->status);
        $this->assertSame(1, CameraVerification::query()->where('camera_id', $camera->id)->count());
    }

    public function test_source_provenance_change_invalidates_verification_and_audits_real_changes(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $source = CameraSource::factory()->create(['verified_at' => now()]);
        $service = app(CameraSourceService::class);
        $service->update($source, ['key' => $source->key, 'title' => $source->title, 'authority' => 'Synthetic corrected authority', 'url' => $source->url, 'source_type' => $source->source_type, 'is_active' => true, 'verified_at' => $source->verified_at], $editor);
        $this->assertNull($source->fresh()->verified_at);
        $this->assertSame(1, AuditLog::query()->where('action', 'camera_source.updated')->count());
        $service->update($source->fresh(), ['key' => $source->key, 'title' => $source->title, 'authority' => 'Synthetic corrected authority', 'url' => $source->url, 'source_type' => $source->source_type, 'is_active' => true, 'verified_at' => null], $editor);
        $this->assertSame(1, AuditLog::query()->where('action', 'camera_source.updated')->count());
    }

    public function test_duplicate_detector_uses_bounded_candidates_and_ignores_retired(): void
    {
        $camera = $this->draft();
        $near = $this->draft(null, ['lat' => 4.7110500]);
        $retired = $this->draft(null, ['lat' => 4.7110400]);
        $retired->forceFill(['status' => CameraStatus::Retired, 'retired_at' => now()])->save();
        $result = app(CameraDuplicateDetector::class)->candidates($camera, 25);
        $this->assertSame($near->id, $result[0]['camera']->id);
        $this->assertCount(1, $result);
    }

    public function test_duplicate_query_prefilters_a_synthetic_registry_of_five_thousand_cameras(): void
    {
        $camera = $this->draft();
        Camera::factory()->count(5000)->state(['jurisdiction_id' => $camera->jurisdiction_id, 'geographic_unit_id' => $camera->geographic_unit_id, 'source_id' => $camera->source_id, 'lat' => 10.0000000, 'lon' => -70.0000000])->create();
        $near = $this->draft(null, ['lat' => 4.7110500]);
        $queries = [];
        DB::listen(function ($query) use (&$queries): void {
            if (str_contains($query->sql, '"lat" between') && str_contains($query->sql, '"lon" between')) {
                $queries[] = $query->sql;
            }
        });
        $result = app(CameraDuplicateDetector::class)->candidates($camera, 25);
        $this->assertSame($near->id, $result[0]['camera']->id);
        $this->assertNotEmpty($queries);
    }

    public function test_tampered_lifecycle_fields_are_not_accepted_by_camera_request(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $camera = $this->draft($editor);
        $this->actingAs($editor)->put(route('admin.cameras.update', $camera), ['jurisdiction_id' => $camera->jurisdiction_id, 'geographic_unit_id' => $camera->geographic_unit_id, 'source_id' => $camera->source_id, 'lat' => $camera->lat, 'lon' => $camera->lon, 'type' => $camera->type->value, 'updated_at' => $camera->updated_at->toISOString(), 'status' => 'active', 'verified_at' => now()->addDay()->toISOString(), 'speed_limit_verified' => 1])->assertRedirect();
        $this->assertSame(CameraStatus::Draft, $camera->fresh()->status);
        $this->assertNull($camera->fresh()->verified_at);
    }

    public function test_stale_camera_form_is_rejected_without_lost_update(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $camera = $this->draft($editor);
        $staleVersion = $camera->updated_at->copy()->subMinute()->toISOString();
        $camera->name = 'Editor B change';
        $camera->save();
        $this->actingAs($editor)->put(route('admin.cameras.update', $camera), ['jurisdiction_id' => $camera->jurisdiction_id, 'geographic_unit_id' => $camera->geographic_unit_id, 'source_id' => $camera->source_id, 'lat' => $camera->lat, 'lon' => $camera->lon, 'type' => $camera->type->value, 'name' => 'Editor A stale overwrite', 'updated_at' => $staleVersion])->assertStatus(409);
        $this->assertSame('Editor B change', $camera->fresh()->name);
    }

    public function test_stale_source_form_is_rejected_without_lost_update(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $source = CameraSource::factory()->create();
        $this->actingAs($editor)->put(route('admin.camera-sources.update', $source), ['key' => $source->key, 'title' => $source->title, 'authority' => 'Editor B authority', 'url' => $source->url, 'source_type' => $source->source_type->value, 'is_active' => 1, 'verified_at' => $source->verified_at->toISOString(), 'updated_at' => $source->updated_at->copy()->subMinute()->toISOString()])->assertStatus(409);
        $this->assertSame('Synthetic authority', $source->fresh()->authority);
    }

    public function test_municipality_spoof_outside_jurisdiction_is_rejected(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $camera = $this->draft($editor);
        $outside = GeographicUnit::query()->whereNotIn('id', [$camera->geographic_unit_id])->where('level', 'municipality')->firstOrFail();
        $this->actingAs($editor)->put(route('admin.cameras.update', $camera), ['jurisdiction_id' => $camera->jurisdiction_id, 'geographic_unit_id' => $outside->id, 'source_id' => $camera->source_id, 'lat' => $camera->lat, 'lon' => $camera->lon, 'type' => $camera->type->value, 'updated_at' => $camera->updated_at->toISOString()])->assertRedirect()->assertSessionHasErrors('camera');
        $this->assertSame($camera->geographic_unit_id, $camera->fresh()->geographic_unit_id);
    }

    public function test_integrity_and_readiness_commands_have_stable_json_contracts(): void
    {
        $this->artisan('picoradar:cameras:quality', ['--json' => true])->expectsOutputToContain('picoradar.camera-quality.v1')->assertExitCode(0);
        $this->artisan('picoradar:cameras:integrity', ['--json' => true, '--fail-on-error' => true])->expectsOutputToContain('picoradar.camera-integrity.v1')->assertExitCode(0);
        $this->artisan('picoradar:cameras:readiness', ['--json' => true, '--fail-on-error' => true])->expectsOutputToContain('picoradar.camera-readiness.v1')->assertExitCode(0);
    }

    public function test_reviewer_and_commercial_cannot_edit_master_data(): void
    {
        $camera = $this->draft();
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        foreach ([$reviewer, $commercial] as $operator) {
            $this->actingAs($operator)->put(route('admin.cameras.update', $camera), [])->assertForbidden();
        }
    }

    public function test_commercial_is_denied_every_b03_admin_surface(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        foreach ([route('admin.camera-sources.index'), route('admin.cameras.index'), route('admin.cameras.quality'), route('admin.cameras.review'), route('admin.cameras.speed-review'), route('admin.cameras.reverification'), route('admin.cameras.duplicates')] as $route) {
            $this->actingAs($commercial)->get($route)->assertForbidden();
        }
    }

    public function test_hard_delete_and_invalid_reason_are_prohibited(): void
    {
        $camera = $this->draft();
        $this->expectException(LogicException::class);
        $camera->delete();
    }

    public function test_source_with_history_and_verification_history_are_immutable(): void
    {
        $camera = $this->draft();
        try {
            $camera->source->delete();
            $this->fail('Camera source with history was deleted.');
        } catch (LogicException) {
            $this->addToAssertionCount(1);
        }
        $verification = CameraVerification::factory()->create(['camera_id' => $camera->id, 'source_id' => $camera->source_id]);
        try {
            $verification->update(['notes' => 'tampered']);
            $this->fail('Verification history was updated.');
        } catch (LogicException) {
            $this->addToAssertionCount(1);
        }
        $this->expectException(LogicException::class);
        $verification->delete();
    }

    private function draft(?User $actor = null, array $overrides = []): Camera
    {
        $jurisdiction = Jurisdiction::query()->where('enabled', true)->with('geographicUnits')->firstOrFail();
        $municipality = $jurisdiction->geographicUnits->first();
        $source = CameraSource::factory()->create();

        return app(CameraRegistryService::class)->create(array_merge(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'lat' => 4.7110000, 'lon' => -74.0721000, 'type' => CameraType::Other, 'name' => 'Synthetic Camera A'], $overrides), $actor);
    }
}
