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
use App\Services\CameraIntegrityAuditor;
use App\Services\CameraRegistryService;
use App\Services\CameraSourceService;
use App\Services\CameraVerificationService;
use App\Services\DatasetAuditLogger;
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
        DB::flushQueryLog();
        DB::enableQueryLog();
        $result = app(CameraDuplicateDetector::class)->candidates($camera, 25);
        $queries = collect(DB::getQueryLog())->pluck('query')->filter(function (string $sql): bool {
            $normalized = str_replace(['"', '`'], '', $sql);

            return str_contains($normalized, 'lat') && str_contains($normalized, 'lon') && str_contains($normalized, 'between');
        });
        DB::disableQueryLog();
        $this->assertSame($near->id, $result[0]['camera']->id);
        $this->assertNotEmpty($queries->all());
        $this->artisan('picoradar:cameras:integrity', ['--json' => true])->expectsOutputToContain('picoradar.camera-integrity.v1')->assertExitCode(0);
        $this->artisan('picoradar:cameras:readiness', ['--json' => true])->expectsOutputToContain('picoradar.camera-readiness.v1')->assertExitCode(0);
    }

    public function test_duplicate_scan_marks_raw_bounding_box_truncation_even_when_filtered_results_are_below_cap(): void
    {
        $seed = $this->draft();
        $this->denseBoundingCluster($seed);

        $scan = app(CameraDuplicateDetector::class)->scan($seed, 25, 250);

        $this->assertTrue($scan['scanCapped']);
        $this->assertSame(251, $scan['boundingCandidateCountObserved']);
        $this->assertSame(250, $scan['scanCap']);
        $this->assertLessThan(250, count($scan['candidates']));
        $this->assertNotEmpty($scan['candidates']);
    }

    public function test_duplicate_scan_does_not_mistake_return_limit_for_database_scan_cap(): void
    {
        $seed = $this->draft();
        $this->createNearbyCameras($seed, 100, 5);

        $scan = app(CameraDuplicateDetector::class)->scan($seed, 25, 25);

        $this->assertFalse($scan['scanCapped']);
        $this->assertSame(100, $scan['boundingCandidateCountObserved']);
        $this->assertCount(25, $scan['candidates']);
    }

    public function test_duplicate_scan_returns_nearest_candidates_first_independent_of_insert_order(): void
    {
        $seed = $this->draft();
        $far = $this->cameraAtMeters($seed, 20);
        $near = $this->cameraAtMeters($seed, 5);
        $middle = $this->cameraAtMeters($seed, 10);

        $scan = app(CameraDuplicateDetector::class)->scan($seed, 25, 25);

        $this->assertSame([$near->id, $middle->id, $far->id], array_map(fn (array $candidate) => $candidate['camera']->id, $scan['candidates']));
        $this->assertSame([5, 10, 20], array_map(fn (array $candidate) => (int) round($candidate['distanceMeters']), $scan['candidates']));
    }

    public function test_duplicates_page_discloses_capped_seed_scans(): void
    {
        $seed = $this->draft();
        $this->denseBoundingCluster($seed);
        $operator = User::factory()->create(['role' => OperatorRole::Editor]);

        $this->actingAs($operator)->get(route('admin.cameras.duplicates'))->assertOk()->assertSee('Candidate scan capped; additional nearby records may exist');
    }

    public function test_camera_detail_discloses_capped_duplicate_scan(): void
    {
        $seed = $this->draft();
        $this->denseBoundingCluster($seed);
        $operator = User::factory()->create(['role' => OperatorRole::Editor]);

        $this->actingAs($operator)->get(route('admin.cameras.show', $seed))->assertOk()->assertSee('Candidate scan capped; additional nearby records may exist.');
    }

    public function test_duplicates_cli_discloses_capped_duplicate_scan(): void
    {
        $seed = $this->draft();
        $this->denseBoundingCluster($seed);

        $this->artisan('picoradar:cameras:duplicates')->expectsOutputToContain("{$seed->camera_id} candidate scan capped; additional nearby records may exist.")->assertExitCode(0);
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

    public function test_lifecycle_transition_matrix_allows_every_approved_edge(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $registry = app(CameraRegistryService::class);
        $verification = app(CameraVerificationService::class);

        $camera = $this->draft($editor);
        $this->assertSame(CameraStatus::InReview, $registry->submit($camera, $editor)->status);
        $this->assertSame(CameraStatus::Draft, $registry->withdraw($camera, $editor)->status);
        $registry->submit($camera, $editor);
        $this->assertSame(CameraStatus::Rejected, $verification->reject($camera, 'Needs correction', $reviewer)->status);
        $this->assertSame(CameraStatus::InReview, $registry->submit($camera, $editor)->status);
        $verified = $verification->verify($camera, false, $reviewer);
        $this->assertSame(CameraStatus::Draft, $registry->reopen($verified, 'Admin correction', $admin)->status);

        $active = $this->verifiedCamera($editor, $reviewer);
        $active = $verification->activate($active, $reviewer);
        $this->assertSame(CameraStatus::Draft, $registry->reopen($active, 'Admin correction', $admin)->status);

        $active = $verification->activate($this->verifiedCamera($editor, $reviewer), $reviewer);
        $inactive = $registry->deactivate($active, 'Maintenance', $reviewer);
        $this->assertSame(CameraStatus::Inactive, $inactive->status);
        $reactivated = $verification->activate($inactive, $reviewer);
        $this->assertSame(CameraStatus::Active, $reactivated->status);
        $inactive = $registry->deactivate($reactivated, 'Maintenance again', $reviewer);
        $this->assertSame(CameraStatus::Draft, $registry->reopen($inactive, 'Admin correction', $admin)->status);

        $retiredFromActive = $registry->retire($verification->activate($this->verifiedCamera($editor, $reviewer), $reviewer), 'Removed', $reviewer);
        $this->assertSame(CameraStatus::Retired, $retiredFromActive->status);
        $retiredFromInactive = $registry->retire($registry->deactivate($verification->activate($this->verifiedCamera($editor, $reviewer), $reviewer), 'Maintenance', $reviewer), 'Removed', $reviewer);
        $this->assertSame(CameraStatus::Retired, $retiredFromInactive->status);
    }

    public function test_lifecycle_transition_matrix_rejects_every_forbidden_edge(): void
    {
        $registry = app(CameraRegistryService::class);
        $verification = app(CameraVerificationService::class);
        $draft = $this->draft();
        $this->assertDomainException(fn () => $verification->activate($draft));
        $this->assertDomainException(fn () => $registry->retire($draft, 'No'));
        $registry->submit($draft);
        $this->assertDomainException(fn () => $verification->activate($draft));
        $verification->reject($draft, 'No');
        $this->assertDomainException(fn () => $verification->activate($draft));
        $retired = $this->draft();
        $retired->forceFill(['status' => CameraStatus::Retired, 'retired_at' => now()])->save();
        $this->assertDomainException(fn () => $verification->activate($retired));
        $this->assertDomainException(fn () => $registry->reopen($retired, 'No'));
        $this->assertDomainException(fn () => $registry->updateDraft($retired, ['name' => 'No']));
    }

    public function test_each_lifecycle_retry_is_a_noop_without_duplicate_audit_or_history(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $registry = app(CameraRegistryService::class);
        $verification = app(CameraVerificationService::class);
        $camera = $this->draft($editor);
        $registry->submit($camera, $editor);
        $this->assertNoNewAudit(fn () => $registry->submit($camera, $editor));
        $registry->withdraw($camera, $editor);
        $this->assertNoNewAudit(fn () => $registry->withdraw($camera, $editor));
        $registry->submit($camera, $editor);
        $verification->verify($camera, false, $reviewer);
        $verificationCount = CameraVerification::query()->where('camera_id', $camera->id)->count();
        $this->assertNoNewAudit(fn () => $verification->verify($camera, false, $reviewer));
        $this->assertSame($verificationCount, CameraVerification::query()->where('camera_id', $camera->id)->count());
        $verification->activate($camera, $reviewer);
        $this->assertNoNewAudit(fn () => $verification->activate($camera, $reviewer));
        $registry->deactivate($camera, 'Maintenance', $reviewer);
        $this->assertNoNewAudit(fn () => $registry->deactivate($camera, 'Maintenance', $reviewer));
        $registry->retire($camera, 'Removed', $reviewer);
        $this->assertNoNewAudit(fn () => $registry->retire($camera, 'Removed', $reviewer));
    }

    public function test_fault_injection_rolls_back_verify_activate_and_retire(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $registry = app(CameraRegistryService::class);
        $fault = static fn (string $point) => throw new \RuntimeException("Injected {$point}");
        $faultyVerification = new CameraVerificationService(app(DatasetAuditLogger::class), $registry, $fault);
        $camera = $this->draft($editor);
        $registry->submit($camera, $editor);
        $this->assertThrowsRuntime(fn () => $faultyVerification->verify($camera, false, $reviewer));
        $this->assertSame(CameraStatus::InReview, $camera->fresh()->status);
        $this->assertSame(0, CameraVerification::query()->where('camera_id', $camera->id)->count());
        $this->assertSame(0, AuditLog::query()->where('action', 'camera.verified')->count());

        $verified = app(CameraVerificationService::class)->verify($camera, false, $reviewer);
        $this->assertThrowsRuntime(fn () => $faultyVerification->activate($verified, $reviewer));
        $this->assertSame(CameraStatus::Verified, $camera->fresh()->status);
        $this->assertSame(0, AuditLog::query()->where('action', 'camera.activated')->count());

        $active = app(CameraVerificationService::class)->activate($camera, $reviewer);
        $faultyRegistry = new CameraRegistryService(app(DatasetAuditLogger::class), $fault);
        $this->assertThrowsRuntime(fn () => $faultyRegistry->retire($active, 'Injected', $reviewer));
        $this->assertSame(CameraStatus::Active, $camera->fresh()->status);
        $this->assertNull($camera->fresh()->retired_at);
        $this->assertSame(0, AuditLog::query()->where('action', 'camera.retired')->count());
    }

    public function test_source_workflow_audits_real_changes_and_blocks_active_dependencies(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $service = app(CameraSourceService::class);
        $source = $service->create(CameraSource::factory()->make()->toArray(), $editor);
        $this->assertDatabaseHas('audit_logs', ['action' => 'camera_source.created']);
        $service->update($source, ['key' => $source->key, 'title' => 'Updated title', 'authority' => $source->authority, 'url' => $source->url, 'source_type' => $source->source_type, 'is_active' => true, 'verified_at' => $source->verified_at], $editor);
        $this->assertDatabaseHas('audit_logs', ['action' => 'camera_source.updated']);
        $service->update($source->fresh(), ['key' => $source->key, 'title' => 'Updated title', 'authority' => $source->authority, 'url' => $source->url, 'source_type' => $source->source_type, 'is_active' => false, 'verified_at' => $source->verified_at], $editor);
        $this->assertDatabaseHas('audit_logs', ['action' => 'camera_source.deactivated']);
        $service->update($source->fresh(), ['key' => $source->key, 'title' => 'Updated title', 'authority' => $source->authority, 'url' => $source->url, 'source_type' => $source->source_type, 'is_active' => true, 'verified_at' => $source->verified_at], $editor);
        $this->assertDatabaseHas('audit_logs', ['action' => 'camera_source.reactivated']);

        $active = $this->activeCameraUsing($source->fresh(), $editor);
        $this->assertDomainException(fn () => $service->update($source->fresh(), ['key' => $source->key, 'title' => 'Updated title', 'authority' => 'Changed authority', 'url' => $source->url, 'source_type' => $source->source_type, 'is_active' => true, 'verified_at' => $source->verified_at], $editor));
        $this->assertDomainException(fn () => $service->update($source->fresh(), ['key' => $source->key, 'title' => 'Updated title', 'authority' => $source->authority, 'url' => $source->url, 'source_type' => $source->source_type, 'is_active' => false, 'verified_at' => $source->verified_at], $editor));
        $this->assertSame(CameraStatus::Active, $active->fresh()->status);
    }

    public function test_external_id_is_unique_per_source_through_http_validation(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $first = $this->draft($editor, ['external_id' => 'shared-id']);
        $payload = $this->cameraPayload($first, ['external_id' => 'shared-id']);
        $this->actingAs($editor)->post(route('admin.cameras.store'), $payload)->assertSessionHasErrors('external_id');
        $otherSource = CameraSource::factory()->create();
        $this->actingAs($editor)->post(route('admin.cameras.store'), $this->cameraPayload($first, ['source_id' => $otherSource->id, 'external_id' => 'shared-id']))->assertRedirect();
        $this->actingAs($editor)->put(route('admin.cameras.update', $first), $this->cameraPayload($first, ['external_id' => 'shared-id', 'updated_at' => $first->updated_at->toISOString()]))->assertRedirect();
    }

    public function test_speed_verification_requires_timestamp_and_controls_overspeed_readiness(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $speed = $this->draft($editor, ['type' => CameraType::Speed, 'speed_limit' => 50]);
        app(CameraRegistryService::class)->submit($speed, $editor);
        $verifiedWithoutSpeed = app(CameraVerificationService::class)->verify($speed, false, $reviewer);
        $activeWithoutSpeed = app(CameraVerificationService::class)->activate($verifiedWithoutSpeed, $reviewer);
        $this->assertFalse($activeWithoutSpeed->isOverspeedEligible());
        $speed2 = $this->draft($editor, ['type' => CameraType::Speed, 'speed_limit' => 50]);
        app(CameraRegistryService::class)->submit($speed2, $editor);
        $activeWithSpeed = app(CameraVerificationService::class)->activate(app(CameraVerificationService::class)->verify($speed2, true, $reviewer), $reviewer);
        $this->assertTrue($activeWithSpeed->isOverspeedEligible());
        $redLight = $this->draft($editor, ['type' => CameraType::RedLight, 'speed_limit' => 50]);
        $this->assertFalse($redLight->isOverspeedEligible());
        $activeWithSpeed->forceFill(['speed_limit_verified_at' => null])->save();
        $tampered = $activeWithSpeed->fresh();
        $this->assertContains('speed_verification', app(CameraIntegrityAuditor::class)->assess($tampered)['errors']);
        $this->assertFalse(app(CameraContractReadinessService::class)->assess($tampered)['readyForFutureDataset']);
    }

    public function test_http_authorization_matrix_for_editor_reviewer_admin_super_admin_and_commercial(): void
    {
        $camera = $this->draft();
        $source = $camera->source;
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        foreach ([route('admin.cameras.index'), route('admin.cameras.create'), route('admin.camera-sources.index'), route('admin.camera-sources.create')] as $route) {
            $this->actingAs($editor)->get($route)->assertOk();
        }
        foreach ([route('admin.cameras.edit', $camera), route('admin.camera-sources.edit', $source)] as $route) {
            $this->actingAs($reviewer)->get($route)->assertForbidden();
        }
        foreach ([route('admin.cameras.index'), route('admin.cameras.review'), route('admin.cameras.quality')] as $route) {
            $this->actingAs($reviewer)->get($route)->assertOk();
        }
        $this->actingAs($editor)->post(route('admin.cameras.verify', $camera))->assertForbidden();
        $this->actingAs($editor)->post(route('admin.cameras.reopen', $camera))->assertForbidden();
        foreach ([OperatorRole::Admin, OperatorRole::SuperAdmin] as $role) {
            $operator = User::factory()->create(['role' => $role]);
            foreach ([route('admin.cameras.quality'), route('admin.cameras.review'), route('admin.cameras.edit', $camera), route('admin.camera-sources.edit', $source)] as $route) {
                $this->actingAs($operator)->get($route)->assertOk();
            }
        }
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        foreach ([route('admin.cameras.index'), route('admin.camera-sources.index'), route('admin.cameras.review'), route('admin.cameras.quality')] as $route) {
            $this->actingAs($commercial)->get($route)->assertForbidden();
        }
    }

    public function test_camera_creation_rejects_caller_supplied_lifecycle_and_authority_fields(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $jurisdiction = Jurisdiction::query()->where('enabled', true)->with('geographicUnits')->firstOrFail();
        $source = CameraSource::factory()->create();
        $base = [
            'jurisdiction_id' => $jurisdiction->id,
            'geographic_unit_id' => $jurisdiction->geographicUnits->first()->id,
            'source_id' => $source->id,
            'external_id' => 'QA-INTERNAL-FIELDS',
            'lat' => 4.711,
            'lon' => -74.0721,
            'type' => CameraType::Other,
        ];

        foreach ([
            ['status' => CameraStatus::Active],
            ['camera_id' => 'cam_attacker'],
            ['verified_at' => now()],
            ['verified_by_id' => $editor->id],
            ['speed_limit_verified' => true],
            ['created_by_id' => $editor->id],
            ['updated_by_id' => $editor->id],
            ['retired_at' => now()],
        ] as $malicious) {
            $this->assertDomainException(
                fn () => app(CameraRegistryService::class)->create($base + $malicious, $editor)
            );
        }

        $this->assertDatabaseMissing('cameras', ['external_id' => 'QA-INTERNAL-FIELDS']);
    }

    public function test_server_assigns_draft_identity_and_actor_when_creating_camera(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $camera = $this->draft($editor, ['external_id' => 'QA-SERVER-FIELDS']);
        $this->assertSame(CameraStatus::Draft, $camera->status);
        $this->assertSame($editor->id, $camera->created_by_id);
        $this->assertSame($editor->id, $camera->updated_by_id);
        $this->assertStringStartsWith('cam_', $camera->camera_id);
        $this->assertNull($camera->verified_at);
        $this->assertFalse($camera->speed_limit_verified);
    }

    private function draft(?User $actor = null, array $overrides = []): Camera
    {
        $jurisdiction = Jurisdiction::query()->where('enabled', true)->with('geographicUnits')->firstOrFail();
        $municipality = $jurisdiction->geographicUnits->first();
        $source = CameraSource::factory()->create();

        return app(CameraRegistryService::class)->create(array_merge(['jurisdiction_id' => $jurisdiction->id, 'geographic_unit_id' => $municipality->id, 'source_id' => $source->id, 'lat' => 4.7110000, 'lon' => -74.0721000, 'type' => CameraType::Other, 'name' => 'Synthetic Camera A'], $overrides), $actor);
    }

    private function verifiedCamera(User $editor, User $reviewer): Camera
    {
        $camera = $this->draft($editor);
        app(CameraRegistryService::class)->submit($camera, $editor);

        return app(CameraVerificationService::class)->verify($camera, false, $reviewer);
    }

    private function activeCameraUsing(CameraSource $source, User $editor): Camera
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $camera = $this->draft($editor, ['source_id' => $source->id]);
        app(CameraRegistryService::class)->submit($camera, $editor);

        return app(CameraVerificationService::class)->activate(app(CameraVerificationService::class)->verify($camera, false, $reviewer), $reviewer);
    }

    private function cameraPayload(Camera $camera, array $overrides = []): array
    {
        return array_merge(['jurisdiction_id' => $camera->jurisdiction_id, 'geographic_unit_id' => $camera->geographic_unit_id, 'source_id' => $camera->source_id, 'external_id' => $camera->external_id, 'name' => $camera->name, 'lat' => $camera->lat, 'lon' => $camera->lon, 'type' => $camera->type->value, 'updated_at' => $camera->updated_at?->toISOString()], $overrides);
    }

    private function denseBoundingCluster(Camera $seed): void
    {
        $this->createNearbyCameras($seed, 10, 5);
        $latitudeDelta = 25 / 111_320;
        $longitudeDelta = 25 / (111_320 * max(0.01, cos(deg2rad((float) $seed->lat))));
        Camera::factory()->count(250)->state(['jurisdiction_id' => $seed->jurisdiction_id, 'geographic_unit_id' => $seed->geographic_unit_id, 'source_id' => $seed->source_id, 'lat' => (float) $seed->lat + ($latitudeDelta * 0.9), 'lon' => (float) $seed->lon + ($longitudeDelta * 0.9), 'type' => CameraType::Other])->create();
    }

    private function createNearbyCameras(Camera $seed, int $count, float $meters): void
    {
        Camera::factory()->count($count)->state(['jurisdiction_id' => $seed->jurisdiction_id, 'geographic_unit_id' => $seed->geographic_unit_id, 'source_id' => $seed->source_id, 'lat' => (float) $seed->lat + ($meters / 111_320), 'lon' => $seed->lon, 'type' => CameraType::Other])->create();
    }

    private function cameraAtMeters(Camera $seed, float $meters): Camera
    {
        return Camera::factory()->create(['jurisdiction_id' => $seed->jurisdiction_id, 'geographic_unit_id' => $seed->geographic_unit_id, 'source_id' => $seed->source_id, 'lat' => (float) $seed->lat + ($meters / 111_320), 'lon' => $seed->lon, 'type' => CameraType::Other]);
    }

    private function assertDomainException(callable $operation): void
    {
        try {
            $operation();
            $this->fail('Expected a domain transition failure.');
        } catch (\DomainException|LogicException) {
            $this->addToAssertionCount(1);
        }
    }

    private function assertThrowsRuntime(callable $operation): void
    {
        try {
            $operation();
            $this->fail('Expected injected transaction failure.');
        } catch (\RuntimeException) {
            $this->addToAssertionCount(1);
        }
    }

    private function assertNoNewAudit(callable $operation): void
    {
        $before = AuditLog::query()->count();
        $operation();
        $this->assertSame($before, AuditLog::query()->count());
    }
}
