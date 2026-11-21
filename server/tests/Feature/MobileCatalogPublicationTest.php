<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\User;
use App\Services\DatasetPublisher;
use App\Services\DatasetReleaseValidator;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MobileCatalogPublicationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
    }

    public function test_three_catalogs_can_be_reviewed_published_and_rolled_back_without_rewriting_prior_assets(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $catalogs = ['cda_catalog', 'cda_geography', 'insurance_directory'];
        $assets = [];
        foreach ($catalogs as $key) {
            $dataset = Dataset::query()->create(['key' => $key, 'title' => $key, 'schema_version' => 1, 'enabled' => true]);
            $dataset->sources()->create(['title' => 'Official source', 'authority' => 'Verified catalog issuer', 'url' => 'https://example.org/catalogs', 'verified_at' => now(), 'is_active' => true]);
            foreach (['first', 'second'] as $version) {
                $release = $this->draft($dataset, $key, '2026.11.18-'.$version);
                $sourceBytes = Storage::disk('local')->get($release->draft_path);
                app(DatasetReleaseValidator::class)->validate($release, $reviewer);
                app(DatasetPublisher::class)->publish($release, $reviewer);
                $release->refresh();
                $this->assertSame(DatasetReleaseStatus::Published, $release->status);
                $this->assertSame(hash('sha256', $sourceBytes), $release->sha256);
                $this->assertSame($sourceBytes, Storage::disk('public')->get($release->asset_path));
                $assets[$key][$version] = $release;
            }
        }
        $manifest = $this->manifest();
        $this->assertCount(3, $manifest['datasets']);
        foreach ($catalogs as $key) {
            $this->assertSame($assets[$key]['second']->sha256, $manifest['datasets'][$key]['sha256']);
            app(DatasetPublisher::class)->rollback($assets[$key]['first']->dataset, $assets[$key]['first'], $reviewer);
            $this->assertSame($assets[$key]['first']->sha256, $this->manifest()['datasets'][$key]['sha256']);
            Storage::disk('public')->assertExists($assets[$key]['second']->asset_path);
        }
    }

    public function test_invalid_catalog_cannot_change_the_manifest_or_a_valid_release(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'insurance_directory', 'title' => 'Insurers', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Issuer', 'authority' => 'Issuer', 'url' => 'https://example.org/insurers', 'verified_at' => now(), 'is_active' => true]);
        $first = $this->draft($dataset, 'insurance_directory', '2026.11.18-valid');
        app(DatasetReleaseValidator::class)->validate($first, $reviewer);
        app(DatasetPublisher::class)->publish($first, $reviewer);
        $before = Storage::disk('public')->get('manifest/v1/manifest.json');
        $bad = $this->draft($dataset, 'insurance_directory', '2026.11.18-bad', true);
        try {
            app(DatasetReleaseValidator::class)->validate($bad, $reviewer);
            $this->fail('The unsafe insurance contact was validated.');
        } catch (DomainException) {
            $this->assertSame(DatasetReleaseStatus::Draft, $bad->refresh()->status);
            $this->assertSame($first->version, $dataset->refresh()->current_version);
            $this->assertSame($before, Storage::disk('public')->get('manifest/v1/manifest.json'));
        }
    }

    private function draft(Dataset $dataset, string $key, string $version, bool $unsafe = false): DatasetRelease
    {
        $file = match ($key) {
            'cda_catalog' => 'cda_catalog_v1.json',
            'cda_geography' => 'cda_geography_v1.json',
            'insurance_directory' => 'insurance_directory_v1.json',
        };
        $payload = json_decode(file_get_contents(dirname(base_path()).'/mobile/assets/catalogs/'.$file), true, 512, JSON_THROW_ON_ERROR);
        $payload['schemaVersion'] = 1;
        $payload['datasetKey'] = $key;
        $payload['version'] = $version;
        $payload['generatedAt'] = '2026-11-18T12:00:00Z';
        if ($unsafe) {
            $payload['entries'][0]['channels'][0]['value'] = 'https://bad.invalid/';
        }
        $path = "dataset-drafts/$key/$version.json";
        Storage::disk('local')->put($path, json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR));

        return $dataset->releases()->create(['version' => $version, 'status' => DatasetReleaseStatus::Draft, 'draft_path' => $path]);
    }

    /** @return array<string,mixed> */
    private function manifest(): array
    {
        return json_decode(Storage::disk('public')->get('manifest/v1/manifest.json'), true, 512, JSON_THROW_ON_ERROR);
    }
}
