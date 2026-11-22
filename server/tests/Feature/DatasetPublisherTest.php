<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\DatasetSource;
use App\Models\User;
use App\Services\DatasetAuditLogger;
use App\Services\DatasetPublisher;
use App\Services\DatasetReleaseValidator;
use App\Services\ManifestPublisher;
use DomainException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class DatasetPublisherTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
    }

    public function test_restrictions_publish_rollback_and_manifest_are_safe(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $first = $this->draft($dataset, '2026.08.27-pilot');
        app(DatasetReleaseValidator::class)->validate($first, $operator);
        app(DatasetPublisher::class)->publish($first, $operator);
        $first->refresh();
        $this->assertSame(DatasetReleaseStatus::Published, $first->status);
        Storage::disk('public')->assertExists($first->asset_path);
        $this->assertSame($first->sha256, hash('sha256', Storage::disk('public')->get($first->asset_path)));
        $second = $this->draft($dataset, '2026.08.28-pilot');
        app(DatasetReleaseValidator::class)->validate($second, $operator);
        app(DatasetPublisher::class)->publish($second, $operator);
        $this->assertSame($second->version, $dataset->refresh()->current_version);
        app(DatasetPublisher::class)->rollback($dataset, $first, $operator);
        $this->assertSame($first->version, $dataset->refresh()->current_version);
        Storage::disk('public')->assertExists($first->asset_path);
        Storage::disk('public')->assertExists($second->refresh()->asset_path);
        $manifest = json_decode(Storage::disk('public')->get('manifest/v1/manifest.json'), true);
        $this->assertSame(['schemaVersion', 'generatedAt', 'minAppVersion', 'datasets', 'features'], array_keys($manifest));
        $this->assertSame($first->version, $manifest['datasets']['restrictions']['version']);
        $this->assertSame(3, $manifest['datasets']['restrictions']['publicationRevision'] ?? null);
        $this->assertSame(3, $dataset->refresh()->publication_revision);
        $this->assertSame('/storage/'.$first->asset_path, $manifest['datasets']['restrictions']['url']);
        $this->assertSame($first->sha256, $manifest['datasets']['restrictions']['sha256']);
        $this->assertFalse($manifest['features']['ads']);
        $this->assertDatabaseHas('audit_logs', ['action' => 'dataset.rollback']);
        $this->assertArrayNotHasKey('payload', DatasetRelease::query()->findOrFail($first->id)->metadata ?? []);
        $dataset->update(['enabled' => false]);
        app(ManifestPublisher::class)->regenerate();
        $disabledManifest = json_decode(Storage::disk('public')->get('manifest/v1/manifest.json'), true);
        $this->assertArrayNotHasKey('restrictions', $disabledManifest['datasets']);
    }

    public function test_published_release_is_immutable_and_republish_is_idempotent(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $release = $this->draft($dataset, '2026.08.27-pilot');
        app(DatasetReleaseValidator::class)->validate($release, $operator);
        app(DatasetPublisher::class)->publish($release, $operator);
        $sha = $release->refresh()->sha256;
        app(DatasetPublisher::class)->publish($release, $operator);
        $this->assertSame($sha, $release->refresh()->sha256);
        $this->expectException(\LogicException::class);
        $release->metadata = ['changed' => true];
        $release->save();
    }

    public function test_publish_can_guard_the_reviewed_publication_revision(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $release = $this->draft($dataset, '2026.09.20-reviewed');
        app(DatasetReleaseValidator::class)->validate($release, $operator);

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('The dataset changed after review; refresh the publication preview.');
        app(DatasetPublisher::class)->publish($release, $operator, 9);
    }

    public function test_validation_requires_an_active_verified_source(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $release = $this->draft($dataset, '2026.08.29-pilot');
        $this->expectException(DomainException::class);
        app(DatasetReleaseValidator::class)->validate($release, $operator);
    }

    public function test_service_provider_publish_rechecks_the_same_validated_source_before_mutating_pointer_or_manifest(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create([
            'key' => 'service_providers',
            'title' => 'Service providers',
            'schema_version' => 1,
            'enabled' => true,
        ]);
        $reviewedAt = now()->subHour();
        $sourceUrl = 'https://authority.example.test/providers';
        $source = $dataset->sources()->create([
            'title' => 'Synthetic source',
            'authority' => 'Synthetic authority',
            'url' => $sourceUrl,
            'verified_at' => $reviewedAt,
            'valid_from' => now()->subDay(),
            'valid_until' => now()->addYear(),
            'is_active' => true,
        ]);
        $publisher = app(DatasetPublisher::class);
        $baseline = $this->validatedProviderRelease($dataset, $source, 'source-guard-baseline');
        $publisher->publish($baseline, $operator);
        $baselineManifest = Storage::disk('public')->get('manifest/v1/manifest.json');
        $this->assertSame($baseline->version, $dataset->refresh()->current_version);

        $scenarios = [
            'disabled' => ['is_active' => false],
            'expired' => ['valid_until' => now()->subSecond()],
            'url_changed' => ['url' => 'https://replacement.example.test/providers'],
            'verification_changed' => ['verified_at' => now()->addMinute()],
        ];
        foreach ($scenarios as $label => $change) {
            $source->update([
                'authority' => 'Synthetic authority',
                'url' => $sourceUrl,
                'verified_at' => $reviewedAt,
                'valid_from' => now()->subDay(),
                'valid_until' => now()->addYear(),
                'is_active' => true,
            ]);
            $release = $this->validatedProviderRelease($dataset, $source->fresh(), 'source-guard-'.$label);
            $source->update($change);
            if ($label === 'url_changed') {
                $dataset->sources()->create([
                    'title' => 'Unapproved replacement',
                    'authority' => 'Replacement authority',
                    'url' => 'https://replacement.example.test/providers',
                    'verified_at' => now()->subMinute(),
                    'valid_from' => now()->subDay(),
                    'valid_until' => now()->addYear(),
                    'is_active' => true,
                ]);
            }

            try {
                $publisher->publish($release, $operator);
                $this->fail("Publishing succeeded after the validated source was {$label}.");
            } catch (DomainException $error) {
                $this->assertStringContainsString('approved during validation', $error->getMessage());
            }

            $this->assertSame(DatasetReleaseStatus::Validated, $release->refresh()->status);
            $this->assertSame($baseline->version, $dataset->refresh()->current_version);
            $this->assertSame($baselineManifest, Storage::disk('public')->get('manifest/v1/manifest.json'));
            $this->assertNull($release->asset_path);
            $assetPath = "datasets/service_providers/{$release->version}/service_providers-{$release->version}.json";
            $this->assertFalse(Storage::disk('public')->exists($assetPath));
        }

        $source->update([
            'authority' => 'Synthetic authority',
            'url' => $sourceUrl,
            'verified_at' => $reviewedAt,
            'valid_from' => now()->subDay(),
            'valid_until' => now()->addYear(),
            'is_active' => true,
        ]);
        $current = $this->validatedProviderRelease($dataset, $source->fresh(), 'source-guard-current');
        $publisher->publish($current, $operator);
        $this->assertSame($current->version, $dataset->refresh()->current_version);
    }

    public function test_service_provider_publish_rejects_missing_approved_source_metadata(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create([
            'key' => 'service_providers',
            'title' => 'Service providers',
            'schema_version' => 1,
            'enabled' => true,
        ]);
        $source = $dataset->sources()->create([
            'title' => 'Synthetic source',
            'authority' => 'Synthetic authority',
            'url' => 'https://authority.example.test/providers',
            'verified_at' => now()->subHour(),
            'valid_from' => now()->subDay(),
            'valid_until' => now()->addYear(),
            'is_active' => true,
        ]);
        $release = $this->validatedProviderRelease($dataset, $source, 'source-metadata-missing');
        DB::table('dataset_releases')->where('id', $release->id)->update([
            'metadata' => json_encode(['sources' => []], JSON_THROW_ON_ERROR),
        ]);

        try {
            app(DatasetPublisher::class)->publish($release->fresh(), $operator);
            $this->fail('Publishing succeeded without source approval metadata.');
        } catch (DomainException $error) {
            $this->assertStringContainsString('approved during validation', $error->getMessage());
        }

        $this->assertNull($dataset->refresh()->current_version);
        $this->assertSame(DatasetReleaseStatus::Validated, $release->refresh()->status);
        $this->assertFalse(Storage::disk('public')->exists('manifest/v1/manifest.json'));
    }

    public function test_publish_aborts_when_an_immutable_path_has_different_bytes(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $release = $this->draft($dataset, '2026.08.30-pilot');
        app(DatasetReleaseValidator::class)->validate($release, $operator);
        $path = "datasets/restrictions/{$release->version}/restrictions-{$release->version}.json";
        Storage::disk('public')->put($path, 'different bytes');
        $this->expectException(DomainException::class);
        app(DatasetPublisher::class)->publish($release, $operator);
    }

    public function test_rollback_rejects_retired_or_corrupt_assets_and_current_release_cannot_retire(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $first = $this->publish($dataset, '2026.08.31-first', $operator);
        $second = $this->publish($dataset, '2026.08.31-second', $operator);
        try {
            app(DatasetPublisher::class)->retire($dataset, $second, $operator);
            $this->fail('Current release was retired.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        app(DatasetPublisher::class)->retire($dataset, $first, $operator);
        try {
            app(DatasetPublisher::class)->rollback($dataset, $first, $operator);
            $this->fail('Retired release was used as a rollback target.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
        $third = $this->publish($dataset, '2026.08.31-third', $operator);
        Storage::disk('public')->put($second->asset_path, 'corrupt');
        $this->expectException(DomainException::class);
        app(DatasetPublisher::class)->rollback($dataset, $second, $operator);
    }

    public function test_controller_enabled_toggle_rebuilds_manifest(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $this->publish($dataset, '2026.08.31-toggle', $operator);
        $this->withoutVite();
        $this->actingAs($operator)->put(route('admin.datasets.update', $dataset), ['title' => 'Restrictions', 'enabled' => false])->assertRedirect();
        $disabled = json_decode(Storage::disk('public')->get('manifest/v1/manifest.json'), true);
        $this->assertArrayNotHasKey('restrictions', $disabled['datasets']);
        $this->actingAs($operator)->put(route('admin.datasets.update', $dataset), ['title' => 'Restrictions', 'enabled' => true])->assertRedirect();
        $enabled = json_decode(Storage::disk('public')->get('manifest/v1/manifest.json'), true);
        $this->assertArrayHasKey('restrictions', $enabled['datasets']);
    }

    public function test_database_commit_is_recoverable_when_post_commit_manifest_regeneration_fails(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $first = $this->publish($dataset, '2026.08.31-recovery-one', $operator);
        $second = $this->draft($dataset, '2026.08.31-recovery-two');
        app(DatasetReleaseValidator::class)->validate($second, $operator);
        $failingManifest = new class extends ManifestPublisher
        {
            public function mutateAndRegenerate(\Closure $mutation): mixed
            {
                $result = $mutation();
                throw new DomainException('Manifest regeneration failed after commit.');
            }
        };
        try {
            (new DatasetPublisher($failingManifest, app(DatasetAuditLogger::class)))->publish($second, $operator);
            $this->fail('Post-commit manifest failure was not reported.');
        } catch (DomainException) {
            $this->assertSame(DatasetReleaseStatus::Published, $second->refresh()->status);
            $this->assertSame($second->version, $dataset->refresh()->current_version);
            $previousManifest = json_decode(Storage::disk('public')->get('manifest/v1/manifest.json'), true);
            $this->assertSame($first->version, $previousManifest['datasets']['restrictions']['version']);
            app(ManifestPublisher::class)->regenerate();
            $recoveredManifest = json_decode(Storage::disk('public')->get('manifest/v1/manifest.json'), true);
            $this->assertSame($second->version, $recoveredManifest['datasets']['restrictions']['version']);
        }
    }

    public function test_publish_rollback_and_retire_remain_atomic_when_audit_fails(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);
        $draft = $this->draft($dataset, '2026.08.31-audit-draft');
        app(DatasetReleaseValidator::class)->validate($draft, $operator);
        $failingAudit = new class extends DatasetAuditLogger
        {
            public function log(?User $actor, string $action, Model $subject, array $metadata = []): void
            {
                throw new \RuntimeException('Audit insert failed.');
            }
        };
        $failingPublisher = new DatasetPublisher(app(ManifestPublisher::class), $failingAudit);
        try {
            $failingPublisher->publish($draft, $operator);
            $this->fail('Publish was committed without an audit event.');
        } catch (\RuntimeException) {
            $this->assertSame(DatasetReleaseStatus::Validated, $draft->refresh()->status);
            $this->assertNull($dataset->refresh()->current_version);
        }
        $first = $this->publish($dataset, '2026.08.31-audit-one', $operator);
        $second = $this->publish($dataset, '2026.08.31-audit-two', $operator);
        try {
            $failingPublisher->rollback($dataset, $first, $operator);
            $this->fail('Rollback was committed without an audit event.');
        } catch (\RuntimeException) {
            $this->assertSame($second->version, $dataset->refresh()->current_version);
        }
        try {
            $failingPublisher->retire($dataset, $first, $operator);
            $this->fail('Retirement was committed without an audit event.');
        } catch (\RuntimeException) {
            $this->assertSame(DatasetReleaseStatus::Published, $first->refresh()->status);
        }
    }

    private function publish(Dataset $dataset, string $version, User $operator): DatasetRelease
    {
        $release = $this->draft($dataset, $version);
        app(DatasetReleaseValidator::class)->validate($release, $operator);
        app(DatasetPublisher::class)->publish($release, $operator);

        return $release->refresh();
    }

    private function validatedProviderRelease(Dataset $dataset, DatasetSource $source, string $version): DatasetRelease
    {
        $bytes = json_encode([
            'schemaVersion' => 1,
            'datasetKey' => 'service_providers',
            'version' => $version,
            'generatedAt' => now()->toAtomString(),
            'providers' => [],
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        $path = "dataset-drafts/service_providers/$version.json";
        Storage::disk('local')->put($path, $bytes);
        $release = $dataset->releases()->create([
            'version' => $version,
            'status' => DatasetReleaseStatus::Draft,
            'draft_path' => $path,
            'expires_at' => now()->addYear(),
        ]);
        $release->forceFill([
            'status' => DatasetReleaseStatus::Validated,
            'sha256' => hash('sha256', $bytes),
            'generated_at' => now(),
            'verified_at' => $source->verified_at,
            'validated_at' => now(),
            'metadata' => [
                'sources' => [[
                    'id' => $source->id,
                    'authority' => $source->authority,
                    'url' => $source->url,
                    'verifiedAt' => $source->verified_at->toAtomString(),
                ]],
            ],
        ])->save();

        return $release->refresh();
    }

    private function draft(Dataset $dataset, string $version): DatasetRelease
    {
        $payload = ['schemaVersion' => 1, 'datasetKey' => 'restrictions', 'version' => $version, 'generatedAt' => '2026-08-27T00:00:00Z', 'jurisdictions' => [[
            'id' => 'co-test', 'name' => 'Test', 'coverages' => [[
                'vehicleKind' => 'car', 'serviceType' => 'private', 'verifiedAt' => '2026-08-27T00:00:00Z', 'staleAfter' => '2027-01-01T00:00:00Z', 'sourceUrls' => ['https://example.test/rules'], 'rules' => [[
                    'id' => 'rule-1', 'priority' => 1, 'effect' => 'restrict', 'validFrom' => '2026-08-27T00:00:00Z', 'timeWindows' => [], 'appliesOnHolidays' => false, 'sourceUrl' => 'https://example.test/rules', 'verifiedAt' => '2026-08-27T00:00:00Z',
                ]],
            ]],
        ]]];
        $path = "dataset-drafts/restrictions/$version.json";
        Storage::disk('local')->put($path, json_encode($payload));

        return $dataset->releases()->create(['version' => $version, 'status' => DatasetReleaseStatus::Draft, 'draft_path' => $path]);
    }
}
