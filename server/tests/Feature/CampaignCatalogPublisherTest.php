<?php

namespace Tests\Feature;

use App\Enums\CampaignScope;
use App\Enums\CampaignStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\OperatorRole;
use App\Enums\SponsorStatus;
use App\Http\Controllers\Api\CampaignCatalogController;
use App\Models\Campaign;
use App\Models\GeographicUnit;
use App\Models\Sponsor;
use App\Models\User;
use App\Services\CampaignCatalogPublisher;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CampaignCatalogPublisherTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        config([
            'campaigns.public_disk' => 'public',
            'campaigns.public_base_url' => 'https://cdn.picoradar.test/storage',
            'campaigns.catalog_manifest_path' => 'campaigns/v1/catalog.json',
            'campaigns.catalog_release_directory' => 'campaigns/v1/releases',
            'campaigns.cache_ttl_seconds' => 3600,
        ]);
        $this->travelTo('2026-09-20 15:00:00');
    }

    public function test_catalog_is_versioned_sorted_sanitized_and_filters_unavailable_campaigns(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $activeSponsor = $this->sponsor('Aliado vigente', SponsorStatus::Active);
        $inactiveSponsor = $this->sponsor('Aliado inactivo', SponsorStatus::Inactive);
        $department = $this->department();

        $this->campaign($activeSponsor, 'national-low', 20);
        $this->campaign($activeSponsor, 'department-first', 5, [
            'scope' => CampaignScope::Department,
            'geographic_unit_id' => $department->id,
        ]);
        $this->campaign($activeSponsor, 'scheduled', 10, [
            'starts_at' => now()->addMinutes(30),
        ]);
        $this->campaign($activeSponsor, 'paused', 1, [
            'status' => CampaignStatus::Paused,
        ]);
        $this->campaign($activeSponsor, 'expired', 1, [
            'ends_at' => now()->subSecond(),
        ]);
        $this->campaign($inactiveSponsor, 'inactive-sponsor', 1);

        $release = app(CampaignCatalogPublisher::class)->publish($admin);

        $this->assertSame(1, $release->version);
        $this->assertSame(3, $release->campaign_count);
        Storage::disk('public')->assertExists($release->asset_path);
        Storage::disk('public')->assertExists('campaigns/v1/catalog.json');

        $manifest = json_decode(Storage::disk('public')->get('campaigns/v1/catalog.json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame(1, $manifest['schemaVersion']);
        $this->assertSame(1, $manifest['version']);
        $this->assertSame($release->sha256, $manifest['sha256']);
        $this->assertSame('https://cdn.picoradar.test/storage/'.$release->asset_path, $manifest['url']);

        $catalogBytes = Storage::disk('public')->get($release->asset_path);
        $this->assertSame($release->sha256, hash('sha256', $catalogBytes));
        $catalog = json_decode($catalogBytes, true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame(['department-first', 'scheduled', 'national-low'], array_column($catalog['campaigns'], 'id'));
        $this->assertSame([
            'scope' => 'department',
            'code' => '05',
            'key' => 'co-antioquia',
        ], $catalog['campaigns'][0]['territory']);
        $this->assertStringNotContainsString('privado@example.test', $catalogBytes);
        $this->assertStringNotContainsString('+57', $catalogBytes);
        $this->assertStringNotContainsString('Contacto Privado', $catalogBytes);
        $this->assertStringNotContainsString('paused', $catalogBytes);
        $this->assertStringNotContainsString('expired', $catalogBytes);
        $this->assertStringNotContainsString('inactive-sponsor', $catalogBytes);
    }

    public function test_each_publication_is_immutable_and_static_controller_supports_etag(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = $this->sponsor('Aliado vigente', SponsorStatus::Active);
        $this->campaign($sponsor, 'one', 10);
        $publisher = app(CampaignCatalogPublisher::class);

        $first = $publisher->publish($admin);
        $firstBytes = Storage::disk('public')->get($first->asset_path);
        $this->campaign($sponsor, 'two', 20);
        $second = $publisher->publish($admin);

        $this->assertSame(2, $second->version);
        $this->assertSame($firstBytes, Storage::disk('public')->get($first->asset_path));
        $this->assertDatabaseCount('campaign_catalog_releases', 2);

        $controller = app(CampaignCatalogController::class);
        $response = $controller(new Request);
        $this->assertSame(200, $response->getStatusCode());
        $etag = $response->headers->get('ETag');
        $this->assertNotNull($etag);
        $this->assertStringContainsString('max-age=3600', (string) $response->headers->get('Cache-Control'));

        $notModified = $controller(Request::create('/api/v1/campaign-catalog', 'GET', server: ['HTTP_IF_NONE_MATCH' => $etag]));
        $this->assertSame(304, $notModified->getStatusCode());
    }

    public function test_invalid_next_release_keeps_last_static_catalog_available(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = $this->sponsor('Aliado vigente', SponsorStatus::Active);
        $this->campaign($sponsor, 'valid', 10);
        $publisher = app(CampaignCatalogPublisher::class);
        $publisher->publish($admin);
        $lastManifest = Storage::disk('public')->get('campaigns/v1/catalog.json');

        $corrupt = $this->campaign($sponsor, 'corrupt', 1);
        Storage::disk('public')->put($corrupt->public_image_path, 'changed-after-validation');

        try {
            $publisher->publish($admin);
            $this->fail('A corrupt campaign image was published.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }

        $this->assertSame($lastManifest, Storage::disk('public')->get('campaigns/v1/catalog.json'));
        $this->assertDatabaseCount('campaign_catalog_releases', 1);
    }

    private function sponsor(string $name, SponsorStatus $status): Sponsor
    {
        return Sponsor::query()->create([
            'public_id' => 'sp_'.strtolower(str_replace(' ', '_', $name)),
            'name' => $name,
            'contact_name' => 'Contacto Privado',
            'contact_email' => 'privado@example.test',
            'contact_phone' => '+57 300 000 0000',
            'status' => $status,
        ]);
    }

    private function department(): GeographicUnit
    {
        $country = GeographicUnit::query()->create([
            'key' => 'co',
            'level' => GeographicUnitLevel::Country,
            'code' => 'CO',
            'name' => 'Colombia',
            'normalized_name' => 'colombia',
            'source_system' => 'synthetic',
            'source_version' => 'test-v1',
        ]);

        return GeographicUnit::query()->create([
            'parent_id' => $country->id,
            'key' => 'co-antioquia',
            'level' => GeographicUnitLevel::Department,
            'code' => '05',
            'name' => 'Antioquia',
            'normalized_name' => 'antioquia',
            'source_system' => 'synthetic',
            'source_version' => 'test-v1',
        ]);
    }

    /** @param array<string, mixed> $overrides */
    private function campaign(Sponsor $sponsor, string $publicId, int $priority, array $overrides = []): Campaign
    {
        $path = 'campaigns/assets/'.$publicId.'.png';
        Storage::disk('public')->put($path, $publicId);

        return Campaign::query()->create($overrides + [
            'public_id' => $publicId,
            'sponsor_id' => $sponsor->id,
            'status' => CampaignStatus::Active,
            'eyebrow' => 'PATROCINADO',
            'title' => 'Campana '.$publicId,
            'subtitle' => 'Fixture sintetico.',
            'cta_text' => 'Conocer mas',
            'cta_url' => 'https://example.test/'.$publicId,
            'placement' => 'home_c11',
            'priority' => $priority,
            'scope' => CampaignScope::National,
            'geographic_unit_id' => null,
            'starts_at' => now()->subHour(),
            'ends_at' => now()->addDay(),
            'source_image_path' => 'campaign-images/'.$publicId.'/source/'.$publicId.'.png',
            'public_image_path' => $path,
            'image_sha256' => hash('sha256', $publicId),
            'image_mime' => 'image/png',
            'image_width' => 1440,
            'image_height' => 360,
            'image_bytes' => 1024,
        ]);
    }
}
