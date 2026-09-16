<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\User;
use App\Services\DatasetReleaseValidator;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Fixtures\TaxCalendarPayload;
use Tests\TestCase;

class TaxCalendarReleaseValidationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
        $this->withoutVite();
    }

    public function test_tax_fixture_validates_without_changing_version_generated_at_or_bytes(): void
    {
        $dataset = $this->dataset();
        $payload = TaxCalendarPayload::valid();
        $release = $this->draft($dataset, $payload);
        $bytes = Storage::disk('local')->get($release->draft_path);
        $actor = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);

        try {
            $validated = app(DatasetReleaseValidator::class)->validate($release, $actor);
        } catch (DomainException $exception) {
            $this->fail('The frozen tax contract was rejected: '.$exception->getMessage());
        }

        $this->assertSame(DatasetReleaseStatus::Validated, $validated->status);
        $this->assertSame('2026.09.13-test', $validated->version);
        $this->assertSame('2026-09-13T12:00:00+00:00', $validated->generated_at->toAtomString());
        $this->assertSame(hash('sha256', $bytes), $validated->sha256);
        $this->assertSame($bytes, Storage::disk('local')->get($release->draft_path));
        $this->assertCount(1, $validated->metadata['sources']);
        $this->assertDatabaseHas('audit_logs', ['action' => 'release.validated']);
        $this->assertNull($dataset->refresh()->current_version);
        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_existing_b01_roles_publish_immutable_tax_bytes_and_rollback_manifest(): void
    {
        $dataset = $this->dataset();
        $first = $this->draft($dataset, TaxCalendarPayload::valid('2026.09.13-first'));
        $second = $this->draft($dataset, TaxCalendarPayload::valid('2026.09.13-second'));
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);

        foreach ([OperatorRole::Editor, OperatorRole::Commercial] as $role) {
            $operator = User::factory()->create(['role' => $role, 'is_active' => true]);
            foreach (['validate', 'publish', 'rollback'] as $action) {
                $this->actingAs($operator)->post(route("admin.datasets.releases.$action", [$dataset, $first]))->assertForbidden();
            }
        }

        foreach ([$first, $second] as $release) {
            $this->actingAs($reviewer)->post(route('admin.datasets.releases.validate', [$dataset, $release]))->assertRedirect()->assertSessionHasNoErrors();
            $this->actingAs($reviewer)->post(route('admin.datasets.releases.publish', [$dataset, $release]))->assertRedirect()->assertSessionHasNoErrors();
            $release->refresh();
            $this->assertSame(DatasetReleaseStatus::Published, $release->status);
            $this->assertSame(Storage::disk('local')->get($release->draft_path), Storage::disk('public')->get($release->asset_path));
        }

        $this->actingAs($reviewer)->post(route('admin.datasets.releases.publish', [$dataset, $second]))->assertSessionHasNoErrors();
        $this->assertSame(2, $dataset->refresh()->publication_revision);
        $this->actingAs($reviewer)->post(route('admin.datasets.releases.rollback', [$dataset, $first]))->assertRedirect()->assertSessionHasNoErrors();
        $manifest = json_decode(Storage::disk('public')->get('manifest/v1/manifest.json'), true, 512, JSON_THROW_ON_ERROR);
        $this->assertSame($first->version, $dataset->refresh()->current_version);
        $this->assertSame($first->version, $manifest['datasets']['tax_calendars']['version']);
        $this->assertSame(3, $manifest['datasets']['tax_calendars']['publicationRevision']);
        $this->assertSame($first->sha256, $manifest['datasets']['tax_calendars']['sha256']);
        Storage::disk('public')->assertExists($first->asset_path);
        Storage::disk('public')->assertExists($second->asset_path);
        $this->assertDatabaseHas('audit_logs', ['action' => 'dataset.rollback']);
    }

    public function test_real_bundled_mobile_tax_asset_satisfies_the_server_contract(): void
    {
        $path = dirname(base_path()).'/mobile/assets/catalogs/tax_calendars_v1.json';
        $this->assertFileExists($path, 'The repository checkout must include the shared mobile tax fixture.');
        $bytes = file_get_contents($path);
        $this->assertNotFalse($bytes);
        $payload = json_decode($bytes, true, 512, JSON_THROW_ON_ERROR);
        $this->assertNotEmpty($payload['authorities']);
        $this->assertNotEmpty($payload['calendars']);
        $dataset = Dataset::query()->create(['key' => 'tax_calendars', 'title' => 'Bundled tax calendars', 'schema_version' => 1, 'enabled' => true]);
        $authority = collect($payload['authorities'])->first(fn (array $entry): bool => ($entry['reviewedAt'] ?? null) !== null);
        $this->assertIsArray($authority, 'The bundled fixture must retain a reviewed source for B01 validation.');
        $dataset->sources()->create([
            'title' => $authority['name'],
            'authority' => $authority['name'],
            'url' => $authority['sourceUrls'][0],
            'verified_at' => $authority['reviewedAt'],
            'is_active' => true,
        ]);
        $release = $this->draft($dataset, $payload);
        Storage::disk('local')->put($release->draft_path, $bytes);
        $actor = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);

        $validated = app(DatasetReleaseValidator::class)->validate($release, $actor);

        $this->assertSame(DatasetReleaseStatus::Validated, $validated->status);
        $this->assertSame($payload['version'], $validated->version);
        $this->assertSame(hash('sha256', $bytes), $validated->sha256);
        $this->assertSame($bytes, Storage::disk('local')->get($validated->draft_path));
        $this->assertNull($dataset->refresh()->current_version);
        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    #[DataProvider('invalidReleases')]
    public function test_tax_rejection_preserves_draft_without_audit_or_publication(array $changes, array $sourceChanges = [], array $datasetChanges = []): void
    {
        $dataset = $this->dataset();
        $dataset->update($datasetChanges);
        $dataset->sources()->update($sourceChanges);
        $payload = TaxCalendarPayload::valid();
        foreach ($changes as $path => $value) {
            Arr::set($payload, $path, $value);
        }
        $release = $this->draft($dataset, $payload);
        $bytes = Storage::disk('local')->get($release->draft_path);
        $actor = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        try {
            app(DatasetReleaseValidator::class)->validate($release, $actor);
            $this->fail('Invalid tax draft was validated.');
        } catch (DomainException) {
            $this->assertSame(DatasetReleaseStatus::Draft, $release->refresh()->status);
            $this->assertNull($release->sha256);
            $this->assertNull($release->validated_at);
            $this->assertNull($dataset->refresh()->current_version);
            $this->assertSame($bytes, Storage::disk('local')->get($release->draft_path));
            $this->assertSame([], Storage::disk('public')->allFiles());
            $this->assertDatabaseMissing('audit_logs', ['action' => 'release.validated']);
        }
    }

    public static function invalidReleases(): iterable
    {
        yield 'generic verified source cannot replace event evidence' => [['calendars.0.events.0.sourceUrls' => []]];
        yield 'unsafe event evidence' => [['calendars.0.events.0.sourceUrls' => ['https://hacienda.example.org/?placa=ABC123']]];
        yield 'invalid civil date' => [['calendars.0.events.0.date' => '2026-02-30']];
        yield 'registry source without authority' => [[], ['authority' => '']];
        yield 'inactive registry source' => [[], ['is_active' => false]];
        yield 'wrong key' => [['datasetKey' => 'restrictions']];
        yield 'mismatched schema' => [['schemaVersion' => 2]];
        yield 'unknown schema even when registry agrees' => [['schemaVersion' => 2], [], ['schema_version' => 2]];
        yield 'invalid generatedAt' => [['generatedAt' => '2026-02-30T00:00:00Z']];
        yield 'JSON object is not a calendars array' => [['calendars' => new \stdClass]];
        yield 'JSON object is not an events array' => [['calendars.0.events' => new \stdClass]];
    }

    public function test_payload_version_must_match_existing_release_version(): void
    {
        $release = $this->draft($this->dataset(), TaxCalendarPayload::valid());
        Storage::disk('local')->put($release->draft_path, json_encode(TaxCalendarPayload::valid('different'), JSON_THROW_ON_ERROR));
        $actor = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $this->expectException(DomainException::class);
        app(DatasetReleaseValidator::class)->validate($release, $actor);
    }

    private function dataset(): Dataset
    {
        $dataset = Dataset::query()->create(['key' => 'tax_calendars', 'title' => 'Tax calendars', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Fixture source', 'authority' => 'Fixture authority', 'url' => 'https://hacienda.example.org/resolucion-2026', 'verified_at' => now(), 'is_active' => true]);

        return $dataset;
    }

    private function draft(Dataset $dataset, array $payload): DatasetRelease
    {
        $path = "dataset-drafts/tax_calendars/{$payload['version']}.json";
        Storage::disk('local')->put($path, json_encode($payload, JSON_THROW_ON_ERROR));

        return $dataset->releases()->create(['version' => $payload['version'], 'status' => DatasetReleaseStatus::Draft, 'draft_path' => $path]);
    }
}
