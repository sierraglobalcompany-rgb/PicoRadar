<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\AuditLog;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RestrictionMaterialApprovalWorkflowTest extends TestCase
{
    use RefreshDatabase;

    private const SOURCE = 'https://example.test/synthetic-restrictions';

    private Dataset $dataset;

    private User $author;

    private User $admin;

    private RestrictionRuleVersion $version;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
        $this->withoutVite();
        $this->dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 2, 'enabled' => true,
        ]);
        $this->dataset->sources()->create([
            'title' => 'Synthetic restriction fixture', 'authority' => 'Synthetic test authority',
            'url' => self::SOURCE, 'verified_at' => now(), 'is_active' => true,
        ]);
        $this->author = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->version = $this->createValidatedVersion();
    }

    public function test_http_review_is_independent_append_only_and_separate_from_publish(): void
    {
        $preview = $this->actingAs($this->admin)
            ->get(route('admin.restrictions.publish.preview', ['versions' => [$this->version->id]]));
        $preview->assertOk()
            ->assertSee('NO_BASELINE')
            ->assertSee('restriction_rule_added')
            ->assertSee('Registrar aprobación editorial')
            ->assertSee('La aprobación es editorial');

        $this->assertContains('web', Route::getRoutes()->getByName('admin.restrictions.approve-material-change')->gatherMiddleware());

        $publishBeforeApproval = $this->post(route('admin.restrictions.publish'), [
            'versions' => [$this->version->id], 'publication_revision' => 0,
        ]);
        $publishBeforeApproval->assertRedirect();
        $publishBeforeApproval->assertSessionHasErrors('publication');
        $this->assertSame(0, $this->dataset->releases()->count());
        $this->assertSame([], Storage::disk('public')->allFiles());

        $this->version->update(['created_by_id' => $this->admin->id, 'updated_by_id' => $this->admin->id]);
        try {
            app(RestrictionPublicationService::class)->approveMaterialChange(
                $this->version->refresh(), 0, $this->admin, 'Revisión independiente de la regla', self::SOURCE,
            );
            $this->fail('An editor cannot approve its own version.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('author or last editor', $error->getMessage());
        }
        $this->assertSame(0, AuditLog::query()->where('action', 'restriction.material_change.approved')->count());
    }

    public function test_active_admin_approval_is_bound_to_exact_city_sha_sources_and_revision_then_published_separately(): void
    {
        $approvalUrl = route('admin.restrictions.approve-material-change', $this->version);
        $this->actingAs($this->admin)->post($approvalUrl, [
            'publication_revision' => 0,
            'reason' => 'Cambio revisado contra la fuente oficial vigente.',
            'evidence_url' => 'https://example.test/not-in-the-proposal',
        ])->assertRedirect()->assertSessionHasErrors('approval');
        $this->assertSame(0, AuditLog::query()->where('action', 'restriction.material_change.approved')->count());

        $approvalInput = [
            'publication_revision' => 0,
            'reason' => 'Cambio revisado contra la fuente oficial vigente.',
            'evidence_url' => self::SOURCE,
        ];
        $this->actingAs($this->admin)->post($approvalUrl, $approvalInput)->assertRedirect()->assertSessionHasNoErrors();
        $approval = AuditLog::query()->where('action', 'restriction.material_change.approved')->firstOrFail();
        $metadata = $approval->metadata;
        $this->assertSame('EDITORIAL_APPROVAL_ONLY', $metadata['classification']);
        $this->assertSame('NO_BASELINE', $metadata['baseCitySha256']);
        $this->assertSame(0, $metadata['publicationRevision']);
        $this->assertSame([$this->author->id, $this->author->id], [$metadata['authorId'], $metadata['updatedById']]);
        $this->assertSame($this->admin->id, $metadata['reviewerId']);
        $this->assertSame(0, $this->dataset->releases()->count());
        $this->assertSame([], Storage::disk('public')->allFiles());

        $this->actingAs($this->admin)->post($approvalUrl, $approvalInput)->assertRedirect()->assertSessionHasNoErrors();
        $this->assertSame(1, AuditLog::query()->where('action', 'restriction.material_change.approved')->count());

        $this->actingAs($this->admin)->post(route('admin.restrictions.publish'), [
            'versions' => [$this->version->id], 'publication_revision' => 0,
        ])->assertRedirect(route('admin.restrictions.history'))->assertSessionHasNoErrors();

        $this->assertSame(1, $this->dataset->refresh()->publication_revision);
        $release = $this->dataset->releases()->firstOrFail();
        $this->assertSame(DatasetReleaseStatus::Published, $release->status);
        $this->assertNotEmpty(Storage::disk('public')->get(config('datasets.manifest_path')));
        $this->assertSame(1, AuditLog::query()->where('action', 'restriction.material_change.approved')->count());
    }

    public function test_coverage_toggle_is_material_approved_and_restored_by_rollback(): void
    {
        $service = app(RestrictionPublicationService::class);
        $versions = app(RestrictionRuleVersionService::class);
        $service->approveMaterialChange(
            $this->version, 0, $this->admin,
            'Publicación inicial sintética revisada.', self::SOURCE,
        );
        $service->publish([$this->version->id], 0, $this->author);

        $jurisdiction = $this->version->jurisdiction()->firstOrFail();
        $disabledPayload = $this->version->payload;
        $disabledPayload['coverages'][0]['consultationEnabled'] = false;
        $disabled = $versions->validate(
            $versions->createDraft($jurisdiction, $disabledPayload, $this->author),
            $this->author,
        );
        $preview = $service->materialChangePreview($disabled, 1);
        $this->assertContains('coverage_metadata_changed', $preview['changes']);

        try {
            $service->publish([$disabled->id], 1, $this->author);
            $this->fail('A modality toggle was published without independent material approval.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('REVIEW_REQUIRED', $error->getMessage());
        }
        $this->assertSame(1, $this->dataset->refresh()->publication_revision);

        $service->approveMaterialChange(
            $disabled, 1, $this->admin,
            'Deshabilitación sintética revisada de forma independiente.', self::SOURCE,
        );
        $service->publish([$disabled->id], 1, $this->author);
        $publishedRelease = $this->dataset->releases()
            ->where('status', DatasetReleaseStatus::Published)
            ->latest('id')
            ->firstOrFail();
        $published = json_decode(Storage::disk('public')->get($publishedRelease->asset_path), true, 512, JSON_THROW_ON_ERROR);
        $publishedCoverage = collect($published['jurisdictions'])->firstWhere('id', $jurisdiction->key)['coverages'][0];
        $this->assertFalse($publishedCoverage['consultationEnabled']);
        $this->assertSame('partial', $publishedCoverage['coverageCompleteness']);
        $this->assertSame(
            $this->sortAssociativeKeysRecursively($this->version->payload['coverages'][0]['rules']),
            $this->sortAssociativeKeysRecursively($publishedCoverage['rules']),
        );

        $service->rollbackCity($this->version, 2, $this->author);
        $rollbackRelease = $this->dataset->releases()
            ->where('status', DatasetReleaseStatus::Published)
            ->latest('id')
            ->firstOrFail();
        $rollback = json_decode(Storage::disk('public')->get($rollbackRelease->asset_path), true, 512, JSON_THROW_ON_ERROR);
        $rolledBackCoverage = collect($rollback['jurisdictions'])->firstWhere('id', $jurisdiction->key)['coverages'][0];
        $this->assertTrue($rolledBackCoverage['consultationEnabled']);
        $this->assertSame(
            $this->sortAssociativeKeysRecursively($this->version->payload['coverages'][0]['rules']),
            $this->sortAssociativeKeysRecursively($rolledBackCoverage['rules']),
        );
        $this->assertSame(3, $this->dataset->refresh()->publication_revision);
    }

    public function test_http_editor_journey_publishes_and_rolls_back_only_through_authorized_admin(): void
    {
        $this->get(route('admin.restrictions.edit', $this->version))
            ->assertRedirect(route('login'));
        $this->assertSame(0, $this->dataset->releases()->count());

        $jurisdiction = $this->version->jurisdiction()->firstOrFail();
        $jurisdiction->geographicUnits()->attach($jurisdiction->primary_geographic_unit_id);
        $approvalInput = [
            'publication_revision' => 0,
            'reason' => 'Línea base sintética revisada de forma independiente.',
            'evidence_url' => self::SOURCE,
        ];
        $this->actingAs($this->admin)
            ->post(route('admin.restrictions.approve-material-change', $this->version), $approvalInput)
            ->assertRedirect()
            ->assertSessionHasNoErrors();
        $this->actingAs($this->admin)
            ->post(route('admin.restrictions.publish'), [
                'versions' => [$this->version->id],
                'publication_revision' => 0,
            ])
            ->assertRedirect(route('admin.restrictions.history'))
            ->assertSessionHasNoErrors();

        $baselineRelease = $this->dataset->releases()
            ->where('status', DatasetReleaseStatus::Published)
            ->firstOrFail();
        $baselineManifest = Storage::disk('public')->get(config('datasets.manifest_path'));
        $this->assertSame(1, $this->dataset->refresh()->publication_revision);

        $source = self::SOURCE;
        $formRule = [
            'id' => 'MEDELLIN_CAR_TEST_RULE',
            'priority' => '1000',
            'effect' => 'restrict',
            'valid_from' => '2026-11-03T06:00',
            'valid_until' => '2026-11-30T18:59',
            'weekdays' => '1',
            'date_parity' => '',
            'digit_position' => 'lastNumeric',
            'digits' => '3,4',
            'time_windows' => '07:00-09:00',
            'applies_on_holidays' => '0',
            'source_url' => $source,
            'verified_at' => '2026-11-09T19:00',
            'registration_origins' => '',
            'conditions_json' => '[]',
        ];
        $coverage = [
            'pair' => 'car|private',
            'verified_at' => '2026-11-09T19:00',
            'stale_after' => '2026-11-29T19:00',
            'source_urls' => $source,
            'rules' => [$formRule],
        ];
        $createInput = [
            'jurisdiction_id' => $jurisdiction->id,
            'municipality_codes' => '05001',
            'consultation_enabled' => '1',
            'coverages' => [$coverage],
        ];
        $this->actingAs($this->author)
            ->post(route('admin.restrictions.store'), $createInput)
            ->assertRedirect();
        $draft = RestrictionRuleVersion::query()->latest('id')->firstOrFail();
        $this->assertSame(RestrictionRuleVersionStatus::Draft, $draft->status);
        $this->assertSame(2, $draft->payload['schemaVersion']);

        $formRule['digits'] = '5,6';
        $coverage['rules'] = [$formRule];
        $editInput = [
            'municipality_codes' => '05001',
            'consultation_enabled' => '1',
            'coverages' => [$coverage],
        ];
        $this->actingAs($this->author)
            ->put(route('admin.restrictions.update', $draft), $editInput)
            ->assertRedirect()
            ->assertSessionHasNoErrors();
        $draft->refresh();
        $this->assertSame([5, 6], $draft->payload['coverages'][0]['rules'][0]['digits']);
        $this->assertSame(
            420,
            $draft->payload['coverages'][0]['rules'][0]['timeWindows'][0]['startMinute'],
        );
        $this->assertSame(
            540,
            $draft->payload['coverages'][0]['rules'][0]['timeWindows'][0]['endMinute'],
        );

        $this->actingAs($this->admin)
            ->post(route('admin.restrictions.validate', $draft))
            ->assertRedirect()
            ->assertSessionHasNoErrors();
        $draft->refresh();
        $this->assertSame(RestrictionRuleVersionStatus::Validated, $draft->status);
        $this->actingAs($this->admin)
            ->get(route('admin.restrictions.publish.preview', ['versions' => [$draft->id]]))
            ->assertOk()
            ->assertSee('restrictive_rule_changed')
            ->assertSee('car/private')
            ->assertSee('MEDELLIN_CAR_TEST_RULE');

        $manifestBeforeDeniedRequests = Storage::disk('public')->get(config('datasets.manifest_path'));
        $this->actingAs($this->author)
            ->post(route('admin.restrictions.publish'), [
                'versions' => [$draft->id],
                'publication_revision' => 1,
            ])
            ->assertForbidden();
        $this->actingAs($this->author)
            ->post(route('admin.restrictions.rollback', $this->version), [
                'publication_revision' => 1,
            ])
            ->assertForbidden();
        $this->assertSame(1, $this->dataset->refresh()->publication_revision);
        $this->assertSame(1, $this->dataset->releases()->count());
        $this->assertSame(
            $manifestBeforeDeniedRequests,
            Storage::disk('public')->get(config('datasets.manifest_path')),
        );

        $this->actingAs($this->admin)
            ->post(route('admin.restrictions.publish'), [
                'versions' => [$draft->id],
                'publication_revision' => 1,
            ])
            ->assertRedirect()
            ->assertSessionHasErrors('publication');
        $this->assertSame(1, $this->dataset->refresh()->publication_revision);
        $this->assertSame(1, $this->dataset->releases()->count());
        $this->assertSame(
            $manifestBeforeDeniedRequests,
            Storage::disk('public')->get(config('datasets.manifest_path')),
        );

        $this->actingAs($this->admin)
            ->post(route('admin.restrictions.approve-material-change', $draft), [
                'publication_revision' => 1,
                'reason' => 'Cambio sintético revisado de forma independiente.',
                'evidence_url' => $source,
            ])
            ->assertRedirect()
            ->assertSessionHasNoErrors();
        $this->actingAs($this->admin)
            ->post(route('admin.restrictions.publish'), [
                'versions' => [$draft->id],
                'publication_revision' => 1,
            ])
            ->assertRedirect(route('admin.restrictions.history'))
            ->assertSessionHasNoErrors();

        $publishedRelease = $this->dataset->releases()
            ->where('status', DatasetReleaseStatus::Published)
            ->latest('id')
            ->firstOrFail();
        $publishedBytes = Storage::disk('public')->get($publishedRelease->asset_path);
        $manifest = json_decode(
            Storage::disk('public')->get(config('datasets.manifest_path')),
            true,
            512,
            JSON_THROW_ON_ERROR,
        );
        $this->assertSame(hash('sha256', $publishedBytes), $publishedRelease->sha256);
        $this->assertSame($publishedRelease->sha256, $manifest['datasets']['restrictions']['sha256']);
        $this->assertSame($publishedRelease->version, $manifest['datasets']['restrictions']['version']);
        $this->assertSame(2, $this->dataset->refresh()->publication_revision);

        $this->actingAs($this->admin)
            ->post(route('admin.restrictions.rollback', $this->version), [
                'publication_revision' => 2,
            ])
            ->assertRedirect(route('admin.restrictions.history'))
            ->assertSessionHasNoErrors();
        $rollbackRelease = $this->dataset->releases()
            ->where('status', DatasetReleaseStatus::Published)
            ->latest('id')
            ->firstOrFail();
        $rollbackBytes = Storage::disk('public')->get($rollbackRelease->asset_path);
        $rollbackPayload = json_decode($rollbackBytes, true, 512, JSON_THROW_ON_ERROR);
        $rolledBackCity = collect($rollbackPayload['jurisdictions'])
            ->firstWhere('id', $jurisdiction->key);
        $rollbackManifest = json_decode(
            Storage::disk('public')->get(config('datasets.manifest_path')),
            true,
            512,
            JSON_THROW_ON_ERROR,
        );
        $this->assertSame([1, 2], $rolledBackCity['coverages'][0]['rules'][0]['digits']);
        $this->assertSame(hash('sha256', $rollbackBytes), $rollbackRelease->sha256);
        $this->assertSame($rollbackRelease->sha256, $rollbackManifest['datasets']['restrictions']['sha256']);
        $this->assertSame($rollbackRelease->version, $rollbackManifest['datasets']['restrictions']['version']);
        $this->assertSame(3, $this->dataset->refresh()->publication_revision);
        $this->assertSame('rollback', RestrictionPublication::query()->latest('id')->value('action'));
        $this->assertNotSame($baselineManifest, Storage::disk('public')->get(config('datasets.manifest_path')));
        $this->assertNotSame($baselineRelease->version, $rollbackRelease->version);
    }

    public function test_non_admin_or_inactive_operators_cannot_use_the_approval_route(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $inactiveAdmin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => false]);
        $url = route('admin.restrictions.approve-material-change', $this->version);
        $input = [
            'publication_revision' => 0,
            'reason' => 'Revisión externa de la fuente vigente.',
            'evidence_url' => self::SOURCE,
        ];

        $this->actingAs($reviewer)->post($url, $input)->assertForbidden();
        $this->actingAs($inactiveAdmin)->post($url, $input)->assertRedirect(route('login'));
        $this->assertSame(0, AuditLog::query()->where('action', 'restriction.material_change.approved')->count());
    }

    public function test_stale_revision_changed_payload_and_complete_scope_cannot_reuse_or_create_approval(): void
    {
        $service = app(RestrictionPublicationService::class);
        $validatedPayload = $this->version->payload;
        try {
            $service->materialChangePreview($this->version, 1);
            $this->fail('A stale publication revision was accepted for review.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('changed after review', $error->getMessage());
        }

        $this->version->update(['payload' => [...$this->version->payload, 'name' => 'Tampered after validation']]);
        try {
            $service->materialChangePreview($this->version->refresh(), 0);
            $this->fail('A changed validated payload was accepted for review.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('changed after validation', $error->getMessage());
        }
        $this->assertSame(0, AuditLog::query()->where('action', 'restriction.material_change.approved')->count());

        $payload = $validatedPayload;
        $payload['coverages'][0]['coverageCompleteness'] = 'complete';
        $completeVersion = app(RestrictionRuleVersionService::class)->validate(
            app(RestrictionRuleVersionService::class)->createDraft(
                $this->version->jurisdiction()->firstOrFail(),
                $payload,
                $this->author,
            ),
            $this->author,
        );
        try {
            $service->approveMaterialChange(
                $completeVersion, 0, $this->admin,
                'Review cannot certify a complete geographic scope.', self::SOURCE,
            );
            $this->fail('Editorial approval incorrectly certified complete coverage.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('COVERAGE_COMPLETE_REQUIRES_SPATIAL_QA', $error->getMessage());
        }
        $this->assertSame(0, AuditLog::query()->where('action', 'restriction.material_change.approved')->count());
    }

    public function test_inactive_reviewer_approval_no_longer_authorizes_publication(): void
    {
        $service = app(RestrictionPublicationService::class);
        $preview = $service->materialChangePreview($this->version, 0);
        $service->approveMaterialChange(
            $this->version, 0, $this->admin,
            'Cambio revisado contra la fuente oficial vigente.', self::SOURCE,
        );
        $this->admin->update(['is_active' => false]);

        try {
            $service->publish([$this->version->id], 0, $this->author);
            $this->fail('An inactive reviewer approval authorized publication.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('REVIEW_REQUIRED', $error->getMessage());
        }
        $this->assertSame(0, $this->dataset->releases()->count());
        $this->assertSame(0, AuditLog::query()->where('action', 'restriction.material_change.approved')->count() - 1);
        $this->assertSame('NO_BASELINE', $preview['baseCitySha256']);
    }

    public function test_availability_changes_are_reviewed_and_municipality_membership_is_required(): void
    {
        $service = app(RestrictionPublicationService::class);
        $service->approveMaterialChange(
            $this->version, 0, $this->admin,
            'Alta inicial revisada contra la fuente oficial.', self::SOURCE,
        );
        $service->publish([$this->version->id], 0, $this->author);

        $jurisdiction = $this->version->jurisdiction()->firstOrFail();
        $jurisdiction->geographicUnits()->attach($jurisdiction->primary_geographic_unit_id);
        $department = GeographicUnit::query()->where('level', 'department')->firstOrFail();
        $secondUnit = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'co-05002', 'level' => 'municipality', 'code' => '05002',
            'name' => 'Municipio sintético dos', 'normalized_name' => 'municipio sintetico dos',
            'is_active' => true, 'source_system' => 'DANE', 'source_version' => 'fixture-v1',
        ]);
        $jurisdiction->geographicUnits()->attach($secondUnit);

        $enabled = $this->createAvailabilityVersion(['municipalityCodes' => ['05001'], 'consultationEnabled' => true]);
        $preview = $service->materialChangePreview($enabled, 1);
        $this->assertContains('jurisdiction_availability_changed', $preview['changes']);
        try {
            $service->publish([$enabled->id], 1, $this->author);
            $this->fail('Availability metadata was published without independent approval.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('REVIEW_REQUIRED', $error->getMessage());
        }
        $this->assertSame(1, $this->dataset->releases()->count());

        $service->approveMaterialChange(
            $enabled, 1, $this->admin,
            'Habilitación de consulta revisada para el municipio vinculado.', self::SOURCE,
        );
        $service->publish([$enabled->id], 1, $this->author);

        $disabled = $this->createAvailabilityVersion(['municipalityCodes' => ['05001'], 'consultationEnabled' => false]);
        $this->assertContains('jurisdiction_availability_changed', $service->materialChangePreview($disabled, 2)['changes']);
        $codeChanged = $this->createAvailabilityVersion(['municipalityCodes' => ['05002'], 'consultationEnabled' => true]);
        $this->assertContains('jurisdiction_availability_changed', $service->materialChangePreview($codeChanged, 2)['changes']);
        $metadataRemoved = $this->createAvailabilityVersion([]);
        $this->assertContains('jurisdiction_availability_changed', $service->materialChangePreview($metadataRemoved, 2)['changes']);

        $unrelatedCode = $this->createAvailabilityVersion(['municipalityCodes' => ['99001'], 'consultationEnabled' => true]);
        try {
            $service->materialChangePreview($unrelatedCode, 2);
            $this->fail('A jurisdiction was reviewed with an unrelated DIVIPOLA code.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('municipalityCodes do not belong to the jurisdiction', $error->getMessage());
        }
        $this->assertSame(2, $this->dataset->releases()->count());

        $service->approveMaterialChange(
            $disabled, 2, $this->admin,
            'Deshabilitación de consulta revisada para la ciudad.', self::SOURCE,
        );
        $service->publish([$disabled->id], 2, $this->author);
        $service->rollbackCity($enabled, 3, $this->author);

        $release = $this->dataset->releases()->where('status', DatasetReleaseStatus::Published)->latest('id')->firstOrFail();
        $releaseBytes = Storage::disk('public')->get($release->asset_path);
        $published = json_decode($releaseBytes, true);
        $city = collect($published['jurisdictions'])->firstWhere('id', $jurisdiction->key);
        $this->assertSame(['05001'], $city['municipalityCodes']);
        $this->assertTrue($city['consultationEnabled']);
        $this->assertSame(4, $this->dataset->refresh()->publication_revision);

        $evidenceDirectory = getenv('PICORADAR_V1_METADATA_LAB_DIR');
        if (is_string($evidenceDirectory) && $evidenceDirectory !== '') {
            if (! is_dir($evidenceDirectory)) {
                mkdir($evidenceDirectory, 0777, true);
            }
            $manifestBytes = Storage::disk('public')->get(config('datasets.manifest_path'));
            file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'V1_SCHEMA2_PHP_RELEASE.json', $releaseBytes);
            file_put_contents($evidenceDirectory.DIRECTORY_SEPARATOR.'V1_SCHEMA2_PHP_MANIFEST.json', $manifestBytes);
        }
    }

    public function test_off_publication_blocks_on_publish_and_rollback_but_allows_reviewed_off_only_payload(): void
    {
        $service = app(RestrictionPublicationService::class);
        $service->approveMaterialChange(
            $this->version, 0, $this->admin,
            'Alta inicial revisada contra la fuente oficial.', self::SOURCE,
        );
        $service->publish([$this->version->id], 0, $this->author);

        $jurisdiction = $this->version->jurisdiction()->firstOrFail();
        $jurisdiction->geographicUnits()->attach($jurisdiction->primary_geographic_unit_id);
        $offPayload = $this->version->payload;
        $offPayload['municipalityCodes'] = ['05001'];
        $offPayload['consultationEnabled'] = false;
        foreach ($offPayload['coverages'] as &$coverage) {
            $coverage['consultationEnabled'] = false;
        }
        unset($coverage);
        $versions = app(RestrictionRuleVersionService::class);
        $offDraft = $versions->createDraft($jurisdiction, $offPayload, $this->author);
        $offVersion = $versions->validate($offDraft, $this->author);
        $jurisdiction->update(['enabled' => false]);
        $filesBeforeOnPublish = Storage::disk('public')->allFiles();

        try {
            $service->publish([$this->version->id], 1, $this->author);
            $this->fail('An OFF jurisdiction republished an ON payload.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('OFF jurisdiction', $error->getMessage());
        }
        $this->assertSame(1, $this->dataset->refresh()->publication_revision);
        $this->assertSame(1, $this->dataset->releases()->count());
        $this->assertEqualsCanonicalizing($filesBeforeOnPublish, Storage::disk('public')->allFiles());

        $service->approveMaterialChange(
            $offVersion, 1, $this->admin,
            'Desactivación de consulta revisada contra la fuente oficial.', self::SOURCE,
        );
        $service->publish([$offVersion->id], 1, $this->author);
        $this->assertFalse($jurisdiction->fresh()->enabled);
        $this->assertSame(2, $this->dataset->refresh()->publication_revision);
        $this->assertSame(2, $this->dataset->releases()->count());
        $release = $this->dataset->releases()->where('status', DatasetReleaseStatus::Published)->latest('id')->firstOrFail();
        $published = json_decode(Storage::disk('public')->get($release->asset_path), true);
        $publishedJurisdiction = collect($published['jurisdictions'])->firstWhere('id', $jurisdiction->key);
        $this->assertFalse($publishedJurisdiction['consultationEnabled']);
        $this->assertFalse($publishedJurisdiction['coverages'][0]['consultationEnabled']);
        $currentVersion = $this->dataset->current_version;
        $manifest = Storage::disk('public')->get(config('datasets.manifest_path'));
        $publicFilesBeforeRollback = Storage::disk('public')->allFiles();

        try {
            $service->rollbackCity($this->version, 2, $this->author);
            $this->fail('A rollback reactivated ON data for an OFF jurisdiction.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('OFF jurisdiction', $error->getMessage());
        }
        $this->assertSame(2, $this->dataset->refresh()->publication_revision);
        $this->assertSame($currentVersion, $this->dataset->current_version);
        $this->assertSame(2, $this->dataset->releases()->count());
        $this->assertSame($manifest, Storage::disk('public')->get(config('datasets.manifest_path')));
        $this->assertEqualsCanonicalizing($publicFilesBeforeRollback, Storage::disk('public')->allFiles());
    }

    /** @param array<string,mixed> $availability */
    private function createAvailabilityVersion(array $availability): RestrictionRuleVersion
    {
        $payload = $this->version->payload;
        unset($payload['municipalityCodes'], $payload['consultationEnabled']);
        $payload = [...$payload, ...$availability];
        $versions = app(RestrictionRuleVersionService::class);
        $draft = $versions->createDraft($this->version->jurisdiction()->firstOrFail(), $payload, $this->author);

        return $versions->validate($draft, $this->author);
    }

    private function createValidatedVersion(): RestrictionRuleVersion
    {
        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia', 'normalized_name' => 'colombia',
            'is_active' => true, 'source_system' => 'test-fixture', 'source_version' => 'v1',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05', 'name' => 'Antioquia',
            'normalized_name' => 'antioquia', 'is_active' => true, 'source_system' => 'test-fixture', 'source_version' => 'v1',
        ]);
        $unit = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'co-05001', 'level' => 'municipality', 'code' => '05001', 'name' => 'Medellín',
            'normalized_name' => 'medellin', 'is_active' => true, 'source_system' => 'DANE', 'source_version' => 'MGN 2025',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'co-ant-medellin', 'name' => 'Medellín', 'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id, 'enabled' => true, 'timezone' => 'America/Bogota',
        ]);
        $payload = [
            'schemaVersion' => 2,
            'id' => 'co-ant-medellin',
            'name' => 'Medellín',
            'coverages' => [[
                'vehicleKind' => 'car', 'serviceType' => 'private', 'coverageCompleteness' => 'partial',
                'consultationEnabled' => true,
                'verifiedAt' => '2026-11-10T00:00:00Z', 'staleAfter' => '2026-11-30T00:00:00Z',
                'sourceUrls' => [self::SOURCE],
                'rules' => [[
                    'id' => 'MEDELLIN_CAR_TEST_RULE', 'priority' => 100, 'effect' => 'restrict',
                    'validFrom' => '2026-11-03T05:00:00-05:00', 'validUntil' => '2026-11-30T23:59:59-05:00',
                    'weekdays' => [1], 'digitPosition' => 'lastNumeric', 'digits' => [1, 2],
                    'timeWindows' => [['startMinute' => 300, 'endMinute' => 1200]],
                    'appliesOnHolidays' => false, 'sourceUrl' => self::SOURCE, 'verifiedAt' => '2026-11-10T00:00:00Z',
                ]],
            ]],
        ];
        $versions = app(RestrictionRuleVersionService::class);
        $draft = $versions->createDraft($jurisdiction, $payload, $this->author);

        return $versions->validate($draft, $this->author);
    }

    /** @param array<array-key, mixed> $values */
    private function sortAssociativeKeysRecursively(array $values): array
    {
        foreach ($values as $key => $value) {
            if (is_array($value)) {
                $values[$key] = $this->sortAssociativeKeysRecursively($value);
            }
        }

        if (! array_is_list($values)) {
            ksort($values);
        }

        return $values;
    }
}
