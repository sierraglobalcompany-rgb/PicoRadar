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
