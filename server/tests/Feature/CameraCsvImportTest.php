<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\CameraStatus;
use App\Enums\OperatorRole;
use App\Models\AuditLog;
use App\Models\Camera;
use App\Models\CameraCsvImport;
use App\Models\CameraSource;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\CameraCsvImportService;
use App\Services\CameraRegistryService;
use App\Services\DatasetAuditLogger;
use App\Services\GeographyImporter;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Tests\TestCase;

class CameraCsvImportTest extends TestCase
{
    use RefreshDatabase;

    private CameraSource $source;
    private Jurisdiction $jurisdiction;
    private string $municipalityCode;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Storage::fake('local');
        app(GeographyImporter::class)->bootstrap();
        $this->source = CameraSource::factory()->create();
        $this->jurisdiction = Jurisdiction::query()->where('enabled', true)->with('geographicUnits')->firstOrFail();
        $this->municipalityCode = (string) $this->jurisdiction->geographicUnits->first()->code;
        $this->admin = User::factory()->create(['role' => OperatorRole::Admin]);
    }

    public function test_upload_is_private_and_only_previews_rows_without_creating_cameras(): void
    {
        $batch = $this->upload();
        self::assertSame('review', $batch->status);
        self::assertSame('create_ready', app(CameraCsvImportService::class)->load($batch)['preview']['rows'][0]['status']);
        self::assertSame(0, Camera::query()->count());
        Storage::disk('local')->assertExists([$batch->original_path, $batch->analysis_path]);
        self::assertSame(64, strlen($batch->original_sha256));
        $this->actingAs($this->admin)->get(route('admin.camera-csv-imports.show', $batch))->assertOk();
    }

    public function test_admin_can_apply_new_cameras_as_draft_and_repeat_is_idempotent(): void
    {
        $batch = $this->upload();
        $request = ['analysis_sha256' => $batch->analysis_sha256, 'records' => ['2']];
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), $request)->assertRedirect();
        $camera = Camera::query()->where('external_id', 'QA-001')->firstOrFail();
        self::assertSame(CameraStatus::Draft, $camera->status);
        self::assertFalse($camera->speed_limit_verified);
        self::assertNull($camera->verified_at);
        self::assertSame('applied', $batch->fresh()->status);
        $audits = AuditLog::query()->where('action', 'camera.created')->count();
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), $request)->assertRedirect();
        self::assertSame(1, Camera::query()->count());
        self::assertSame($audits, AuditLog::query()->where('action', 'camera.created')->count());
    }

    public function test_viewer_editor_and_reviewer_cannot_unilaterally_apply(): void
    {
        $batch = $this->upload();
        $payload = ['analysis_sha256' => $batch->analysis_sha256, 'records' => ['2']];
        foreach ([OperatorRole::Editor, OperatorRole::Reviewer, OperatorRole::Commercial] as $role) {
            $user = User::factory()->create(['role' => $role]);
            $this->actingAs($user)->post(route('admin.camera-csv-imports.apply', $batch), $payload)->assertForbidden();
        }
        self::assertSame(0, Camera::query()->count());
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $this->actingAs($reviewer)->get(route('admin.camera-csv-imports.create'))->assertForbidden();
    }

    public function test_source_changed_after_analysis_fails_with_409_and_no_writes(): void
    {
        $batch = $this->upload();
        $this->source->update(['verified_at' => null]);
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256, 'records' => ['2'],
        ])->assertStatus(409);
        self::assertSame(0, Camera::query()->count());
        self::assertSame('review', $batch->fresh()->status);
    }

    public function test_tampered_private_original_fails_closed(): void
    {
        $batch = $this->upload();
        Storage::disk('local')->put($batch->original_path, 'changed');
        $this->actingAs($this->admin)->get(route('admin.camera-csv-imports.show', $batch))->assertStatus(409);
        self::assertSame(0, Camera::query()->count());
    }

    public function test_multiple_rows_are_all_rolled_back_if_one_is_stale(): void
    {
        $batch = $this->upload(
            "QA-001,{$this->municipalityCode},4.7110,-74.0721,other,First\n".
            "QA-002,{$this->municipalityCode},4.7150,-74.0750,other,Second\n"
        );
        $unit = $this->jurisdiction->geographicUnits->first();
        app(CameraRegistryService::class)->create([
            'source_id' => $this->source->id,
            'jurisdiction_id' => $this->jurisdiction->id,
            'geographic_unit_id' => $unit->id,
            'external_id' => 'QA-002',
            'lat' => '4.7150000', 'lon' => '-74.0750000', 'type' => 'other',
        ], $this->admin);
        $before = Camera::count();
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256, 'records' => ['2', '3'],
        ])->assertStatus(409);
        self::assertSame($before, Camera::count());
        self::assertDatabaseMissing('cameras', ['external_id' => 'QA-001']);
    }

    public function test_failed_final_audit_rolls_back_camera_and_batch_state(): void
    {
        $batch = $this->upload();
        app()->instance(DatasetAuditLogger::class, new class extends DatasetAuditLogger
        {
            public function log(?User $actor, string $action, Model $subject, array $metadata = []): void
            {
                if ($action === 'camera_csv_import.applied') {
                    throw new RuntimeException('Injected audit failure');
                }
                parent::log($actor, $action, $subject, $metadata);
            }
        });

        $this->withoutExceptionHandling();
        try {
            $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
                'analysis_sha256' => $batch->analysis_sha256, 'records' => ['2'],
            ]);
            self::fail('Expected the audit transaction to roll back.');
        } catch (RuntimeException $failure) {
            self::assertSame('Injected audit failure', $failure->getMessage());
        }
        self::assertSame(0, Camera::count());
        self::assertSame('review', $batch->fresh()->status);
        self::assertSame(0, AuditLog::query()->where('action', 'camera.created')->count());
    }

    public function test_unknown_lifecycle_column_is_rejected_without_storing_batch(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $this->actingAs($editor)->post(route('admin.camera-csv-imports.store'), [
            'source_id' => $this->source->id,
            'jurisdiction_id' => $this->jurisdiction->id,
            'mode' => 'delta',
            'csv' => UploadedFile::fake()->createWithContent('bad.csv',
                "external_id,municipality_code,lat,lon,type,status\nQA-001,{$this->municipalityCode},4.711,-74.0721,other,active\n"),
        ])->assertRedirect()->assertSessionHasErrors('csv');
        self::assertSame(0, CameraCsvImport::count());
    }

    public function test_report_escapes_formula_cells(): void
    {
        $batch = $this->upload(
            "\"=HYPERLINK(\"\"https://invalid.test\"\",\"\"click\"\")\",{$this->municipalityCode},4.711,-74.0721,other,Synthetic\n"
        );
        $report = $this->actingAs($this->admin)->get(route('admin.camera-csv-imports.report', $batch));
        $report->assertOk();
        self::assertStringContainsString("'=HYPERLINK", $report->getContent());
    }

    public function test_report_retains_normalized_negative_longitudes_as_numeric_csv_cells(): void
    {
        $batch = $this->upload();
        $response = $this->actingAs($this->admin)->get(
            route('admin.camera-csv-imports.report', $batch)
        );
        $response->assertOk();
        $csv = $response->getContent();
        self::assertStringContainsString(',4.7110000,-74.0721000,', $csv);
        self::assertStringNotContainsString("'-74.0721000", $csv);
    }

    public function test_existing_draft_is_updated_without_verification_or_new_camera(): void
    {
        $unit = $this->jurisdiction->geographicUnits->first();
        $camera = app(CameraRegistryService::class)->create([
            'source_id' => $this->source->id, 'jurisdiction_id' => $this->jurisdiction->id,
            'geographic_unit_id' => $unit->id, 'external_id' => 'QA-001',
            'lat' => '4.7110000', 'lon' => '-74.0721000', 'type' => 'other', 'name' => 'Before',
        ], $this->admin);
        $batch = $this->upload("QA-001,{$this->municipalityCode},4.7110,-74.0721,other,After\n");
        self::assertSame('update_ready', app(CameraCsvImportService::class)->load($batch)['preview']['rows'][0]['status']);
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256, 'records' => ['2'],
        ])->assertRedirect();
        self::assertSame('After', $camera->fresh()->name);
        self::assertSame(CameraStatus::Draft, $camera->fresh()->status);
        self::assertFalse($camera->fresh()->speed_limit_verified);
        self::assertSame(1, Camera::count());
    }

    public function test_wrong_analysis_fingerprint_fails_with_http_409(): void
    {
        $batch = $this->upload();
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => str_repeat('a', 64), 'records' => ['2'],
        ])->assertStatus(409);
        self::assertSame('review', $batch->fresh()->status);
        self::assertSame(0, Camera::count());
    }

    public function test_comparison_rejects_a_batch_from_another_source(): void
    {
        $first = $this->upload();
        $otherSource = CameraSource::factory()->create();
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.store'), [
            'source_id' => $otherSource->id,
            'jurisdiction_id' => $this->jurisdiction->id,
            'mode' => 'delta',
            'csv' => UploadedFile::fake()->createWithContent('other.csv',
                "external_id,municipality_code,lat,lon,type,name\n". 
                "QA-002,{$this->municipalityCode},4.715,-74.075,other,Second\n"),
        ])->assertRedirect();
        $second = CameraCsvImport::query()->latest('id')->firstOrFail();

        $this->actingAs($this->admin)->get(
            route('admin.camera-csv-imports.show', $first).'?compare='.$second->id
        )->assertNotFound();
    }

    public function test_snapshot_missing_rows_are_only_advisory(): void
    {
        $unit = $this->jurisdiction->geographicUnits->first();
        $existing = app(CameraRegistryService::class)->create([
            'source_id' => $this->source->id, 'jurisdiction_id' => $this->jurisdiction->id,
            'geographic_unit_id' => $unit->id, 'external_id' => 'OLDER',
            'lat' => '4.7900000', 'lon' => '-74.1500000', 'type' => 'other',
        ], $this->admin);
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.store'), [
            'source_id' => $this->source->id,
            'jurisdiction_id' => $this->jurisdiction->id,
            'mode' => 'snapshot',
            'csv' => UploadedFile::fake()->createWithContent('snapshot.csv',
                "external_id,municipality_code,lat,lon,type,name\n".
                "QA-001,{$this->municipalityCode},4.7110,-74.0721,other,New\n"),
        ])->assertRedirect();
        $batch = CameraCsvImport::query()->latest('id')->firstOrFail();
        $preview = app(CameraCsvImportService::class)->load($batch)['preview'];
        self::assertSame(1, $preview['missing_advisory']);
        self::assertSame(CameraStatus::Draft, $existing->fresh()->status);
        self::assertSame(1, Camera::count());
    }

    public function test_review_lock_prevents_editing_camera_submitted_after_analysis(): void
    {
        $unit = $this->jurisdiction->geographicUnits->first();
        $camera = app(CameraRegistryService::class)->create([
            'source_id' => $this->source->id,
            'jurisdiction_id' => $this->jurisdiction->id,
            'geographic_unit_id' => $unit->id,
            'external_id' => 'QA-001', 'lat' => '4.7110000',
            'lon' => '-74.0721000', 'type' => 'other', 'name' => 'Before',
        ], $this->admin);

        $batch = $this->upload("QA-001,{$this->municipalityCode},4.711,-74.0721,other,After\n");
        self::assertSame('update_ready', app(CameraCsvImportService::class)->load($batch)['preview']['rows'][0]['status']);
        app(CameraRegistryService::class)->submit($camera, $this->admin);

        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['2'],
        ])->assertStatus(409);

        self::assertSame(CameraStatus::InReview, $camera->fresh()->status);
        self::assertSame('Before', $camera->fresh()->name);
        self::assertSame('review', $batch->fresh()->status);
    }

    public function test_only_explicitly_selected_rows_are_applied(): void
    {
        $batch = $this->upload(
            "QA-001,{$this->municipalityCode},4.711,-74.0721,other,First\n".
            "QA-002,{$this->municipalityCode},4.720,-74.0900,other,Second\n"
        );
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['2'],
        ])->assertRedirect();

        self::assertSame(1, Camera::count());
        self::assertDatabaseHas('cameras', ['external_id' => 'QA-001', 'status' => 'draft']);
        self::assertDatabaseMissing('cameras', ['external_id' => 'QA-002']);
    }

    public function test_repeating_applied_batch_with_different_selection_returns_409(): void
    {
        $batch = $this->upload(
            "QA-001,{$this->municipalityCode},4.711,-74.0721,other,First\n".
            "QA-002,{$this->municipalityCode},4.720,-74.0900,other,Second\n"
        );
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['2'],
        ])->assertRedirect();

        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['3'],
        ])->assertStatus(409);

        self::assertSame(1, Camera::count());
        self::assertDatabaseMissing('cameras', ['external_id' => 'QA-002']);
        self::assertSame(64, strlen($batch->fresh()->applied_selection_sha256));
    }

    public function test_deleted_private_analysis_returns_conflict_without_mutating_cameras(): void
    {
        $batch = $this->upload();
        Storage::disk('local')->delete($batch->analysis_path);
        $this->actingAs($this->admin)->get(route('admin.camera-csv-imports.show', $batch))
            ->assertStatus(409);
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['2'],
        ])->assertStatus(409);

        self::assertSame('review', $batch->fresh()->status);
        self::assertSame(0, Camera::count());
    }

    public function test_applied_batch_replay_rechecks_private_checksums_before_idempotent_ack(): void
    {
        $batch = $this->upload();
        $request = ['analysis_sha256' => $batch->analysis_sha256, 'records' => ['2']];
        $this->actingAs($this->admin)->post(
            route('admin.camera-csv-imports.apply', $batch), $request
        )->assertRedirect();
        self::assertSame(1, Camera::count());

        Storage::disk('local')->put($batch->original_path, 'tampered after apply');
        $this->actingAs($this->admin)->post(
            route('admin.camera-csv-imports.apply', $batch), $request
        )->assertStatus(409);
        self::assertSame(1, Camera::count());
        self::assertSame('applied', $batch->fresh()->status);
    }

    public function test_reversed_selected_row_order_is_an_idempotent_replay(): void
    {
        $batch = $this->upload(
            "QA-001,{$this->municipalityCode},4.711,-74.0721,other,First\n".
            "QA-002,{$this->municipalityCode},4.720,-74.0900,other,Second\n"
        );

        // Deliberately send reverse order on the FIRST apply. The service
        // must persist and audit in canonical CSV record order.
        $first = ['analysis_sha256' => $batch->analysis_sha256, 'records' => ['3', '2']];
        $second = ['analysis_sha256' => $batch->analysis_sha256, 'records' => ['2', '3']];
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), $first)->assertRedirect();
        self::assertSame(
            ['QA-001', 'QA-002'],
            Camera::query()->orderBy('id')->pluck('external_id')->all()
        );
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), $second)->assertRedirect();

        self::assertSame(2, Camera::count());
        self::assertSame(2, AuditLog::query()->where('action', 'camera.created')->count());
        self::assertSame('applied', $batch->fresh()->status);
    }

    public function test_empty_optional_cell_does_not_clear_a_draft_camera_field(): void
    {
        $unit = $this->jurisdiction->geographicUnits->first();
        $camera = app(CameraRegistryService::class)->create([
            'source_id' => $this->source->id,
            'jurisdiction_id' => $this->jurisdiction->id,
            'geographic_unit_id' => $unit->id,
            'external_id' => 'QA-001',
            'lat' => '4.7110000', 'lon' => '-74.0721000',
            'type' => 'other', 'name' => 'Must stay',
        ], $this->admin);
        $batch = $this->upload("QA-001,{$this->municipalityCode},4.711,-74.0721,other,\n");
        $preview = app(CameraCsvImportService::class)->load($batch)['preview'];
        self::assertSame('noop', $preview['rows'][0]['status']);
        self::assertSame(1, $preview['counts']['noop']);

        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256, 'records' => ['2'],
        ])->assertStatus(409);
        self::assertSame('Must stay', $camera->fresh()->name);
        self::assertSame('review', $batch->fresh()->status);
    }

    public function test_reverified_source_with_changed_authority_stales_original_review(): void
    {
        $batch = $this->upload();
        $this->source->update([
            'authority' => 'Different synthetic authority',
            'verified_at' => now(),
        ]);
        self::assertTrue($this->source->fresh()->is_active);
        self::assertNotNull($this->source->fresh()->verified_at);

        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['2'],
        ])->assertStatus(409);
        self::assertSame(0, Camera::count());
        self::assertSame('review', $batch->fresh()->status);
    }

    public function test_changed_jurisdiction_metadata_stales_the_analyzed_batch(): void
    {
        $batch = $this->upload();
        $this->jurisdiction->update(['name' => 'Renamed synthetic jurisdiction']);

        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['2'],
        ])->assertStatus(409);

        self::assertSame(0, Camera::count());
        self::assertSame('review', $batch->fresh()->status);
    }

    public function test_coverage_attached_after_preview_invalidates_the_older_review(): void
    {
        $batch = $this->upload();
        $existingCoverageIds = $this->jurisdiction->geographicUnits()
            ->pluck('geographic_units.id')->all();
        $otherUnit = \App\Models\GeographicUnit::query()
            ->where('level', 'municipality')
            ->whereNotIn('id', $existingCoverageIds)
            ->firstOrFail();

        app(\App\Services\JurisdictionService::class)
            ->attachCoverage($this->jurisdiction, $otherUnit, $this->admin);

        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['2'],
        ])->assertStatus(409);

        self::assertSame(0, Camera::count());
        self::assertSame('review', $batch->fresh()->status);
    }

    public function test_jurisdiction_rename_is_stale_even_if_timestamp_is_unchanged(): void
    {
        $batch = $this->upload();
        $stamp = $this->jurisdiction->updated_at;
        $this->jurisdiction->name = 'Renamed without timestamp advancement';
        $this->jurisdiction->timestamps = false;
        $this->jurisdiction->save();
        $this->jurisdiction->timestamps = true;
        self::assertSame($stamp->toISOString(), $this->jurisdiction->fresh()->updated_at->toISOString());

        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256,
            'records' => ['2'],
        ])->assertStatus(409);

        self::assertSame(0, Camera::count());
        self::assertSame('review', $batch->fresh()->status);
    }

    public function test_csv_mutation_routes_are_throttled_per_minute_not_per_hour(): void
    {
        $upload = \Illuminate\Support\Facades\Route::getRoutes()
            ->getByName('admin.camera-csv-imports.store');
        $apply = \Illuminate\Support\Facades\Route::getRoutes()
            ->getByName('admin.camera-csv-imports.apply');

        self::assertNotNull($upload);
        self::assertNotNull($apply);
        self::assertContains('throttle:6,1', $upload->gatherMiddleware());
        self::assertContains('throttle:30,1', $apply->gatherMiddleware());
    }

    public function test_numeric_external_id_stays_distinct_from_leading_zero_id(): void
    {
        $unit = $this->jurisdiction->geographicUnits->first();
        app(CameraRegistryService::class)->create([
            'source_id' => $this->source->id,
            'jurisdiction_id' => $this->jurisdiction->id,
            'geographic_unit_id' => $unit->id,
            'external_id' => '00123',
            'lat' => '4.9000000', 'lon' => '-74.1000000',
            'type' => 'other',
        ], $this->admin);

        $batch = $this->upload(
            "123,{$this->municipalityCode},4.7110,-74.0721,other,Numeric\n".
            "123ABC,{$this->municipalityCode},4.7400,-74.1000,other,Alphanumeric\n"
        );
        $preview = app(CameraCsvImportService::class)->load($batch)['preview'];
        self::assertSame(2, $preview['counts']['create_ready']);

        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.apply', $batch), [
            'analysis_sha256' => $batch->analysis_sha256, 'records' => ['2', '3'],
        ])->assertRedirect();

        self::assertSame(3, Camera::count());
        foreach (['00123', '123', '123ABC'] as $identity) {
            self::assertSame(1, Camera::query()->where('source_id', $this->source->id)
                ->where('external_id', $identity)->count());
        }
    }

    private function upload(?string $body = null): CameraCsvImport
    {
        $csv = "external_id,municipality_code,lat,lon,type,name\n".
            ($body ?? "QA-001,{$this->municipalityCode},4.7110,-74.0721,other,Synthetic\n");
        $this->actingAs($this->admin)->post(route('admin.camera-csv-imports.store'), [
            'source_id' => $this->source->id,
            'jurisdiction_id' => $this->jurisdiction->id,
            'mode' => 'delta',
            'csv' => UploadedFile::fake()->createWithContent('cameras.csv', $csv),
        ])->assertRedirect();

        return CameraCsvImport::query()->latest('id')->firstOrFail();
    }
}
