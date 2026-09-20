<?php

namespace Tests\Feature;

use App\Enums\CampaignScope;
use App\Enums\CampaignStatus;
use App\Enums\OperatorRole;
use App\Enums\SponsorStatus;
use App\Models\Campaign;
use App\Models\PartnerInquiry;
use App\Models\Sponsor;
use App\Models\User;
use App\Services\CampaignAccess;
use App\Services\CampaignCatalogPublisher;
use App\Services\CampaignImageStore;
use App\Services\CampaignService;
use App\Services\DatasetAuditLogger;
use App\Services\SponsorService;
use DomainException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CampaignOperationsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
        config([
            'campaigns.private_disk' => 'local',
            'campaigns.public_disk' => 'public',
            'campaigns.public_base_url' => 'https://cdn.picoradar.test/storage',
        ]);
    }

    public function test_schema_preserves_private_contacts_and_versioned_catalog_history(): void
    {
        $this->assertTrue(Schema::hasColumns('sponsors', [
            'public_id', 'name', 'contact_name', 'contact_email', 'contact_phone',
            'status', 'created_by_id', 'updated_by_id', 'archived_at',
        ]));
        $this->assertTrue(Schema::hasColumns('campaigns', [
            'public_id', 'sponsor_id', 'status', 'placement', 'priority',
            'scope', 'geographic_unit_id', 'starts_at', 'ends_at',
            'source_image_path', 'public_image_path', 'image_sha256',
        ]));
        $this->assertTrue(Schema::hasColumns('campaign_catalog_releases', [
            'version', 'asset_path', 'sha256', 'campaign_count',
            'generated_at', 'expires_at', 'published_by_id',
        ]));
    }

    public function test_commercial_operator_manages_drafts_but_only_admin_publishes(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = app(SponsorService::class)->create($this->sponsorData(), $commercial);
        $campaign = app(CampaignService::class)->create(
            $this->campaignData($sponsor),
            $this->syntheticPng('campaign.png', 1440, 360),
            $commercial,
        );

        $this->assertSame(SponsorStatus::Active, $sponsor->status);
        $this->assertSame(CampaignStatus::Draft, $campaign->status);
        Storage::disk('local')->assertExists($campaign->source_image_path);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'sponsor.created',
            'subject_type' => Sponsor::class,
            'subject_id' => $sponsor->id,
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'campaign.created',
            'subject_type' => Campaign::class,
            'subject_id' => $campaign->id,
        ]);

        $this->expectException(AuthorizationException::class);
        app(CampaignAccess::class)->authorizePublish($commercial);

        app(CampaignAccess::class)->authorizePublish($admin);
    }

    public function test_campaign_can_be_edited_duplicated_activated_paused_and_archived_with_audit(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = app(SponsorService::class)->create($this->sponsorData(), $admin);
        $service = app(CampaignService::class);
        $campaign = $service->create(
            $this->campaignData($sponsor),
            $this->syntheticPng('campaign.png', 1440, 360),
            $admin,
        );

        $updated = $service->update($campaign, ['title' => 'Campana sintetica editada'], null, $admin);
        $duplicate = $service->duplicate($updated, $admin);
        $active = $service->activate($updated, $admin);
        $paused = $service->pause($active, $admin);
        $archived = $service->archive($paused, $admin);

        $this->assertSame('Campana sintetica editada', $updated->title);
        $this->assertSame(CampaignStatus::Draft, $duplicate->status);
        $this->assertNotSame($updated->public_id, $duplicate->public_id);
        $this->assertNotSame($updated->source_image_path, $duplicate->source_image_path);
        Storage::disk('local')->assertExists($duplicate->source_image_path);
        $this->assertSame(CampaignStatus::Archived, $archived->status);
        $this->assertNotNull($archived->archived_at);

        $actions = DB::table('audit_logs')
            ->where('subject_type', Campaign::class)
            ->where('subject_id', $campaign->id)
            ->pluck('action')
            ->all();
        $this->assertSame([
            'campaign.created',
            'campaign.updated',
            'campaign.activated',
            'campaign.paused',
            'campaign.archived',
        ], $actions);

        $this->expectException(DomainException::class);
        $service->update($archived, ['title' => 'No permitido'], null, $admin);
    }

    public function test_operational_status_distinguishes_scheduled_active_expired_and_paused(): void
    {
        $this->travelTo('2026-09-20 15:00:00');
        $campaign = new Campaign([
            'status' => CampaignStatus::Active,
            'starts_at' => now()->addHour(),
            'ends_at' => now()->addDay(),
        ]);
        $this->assertSame('scheduled', $campaign->operationalStatus(now()));

        $campaign->starts_at = now()->subHour();
        $this->assertSame('active', $campaign->operationalStatus(now()));

        $campaign->ends_at = now()->subSecond();
        $this->assertSame('expired', $campaign->operationalStatus(now()));

        $campaign->status = CampaignStatus::Paused;
        $this->assertSame('paused', $campaign->operationalStatus(now()));
    }

    public function test_image_validation_uses_real_bytes_dimensions_and_size(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = app(SponsorService::class)->create($this->sponsorData(), $admin);
        $service = app(CampaignService::class);

        foreach ([
            UploadedFile::fake()->createWithContent('payload.png', '<html>not an image</html>'),
            $this->syntheticPng('too-small.png', 320, 80),
        ] as $image) {
            try {
                $service->create($this->campaignData($sponsor), $image, $admin);
                $this->fail('Unsafe campaign image was accepted.');
            } catch (DomainException) {
                $this->addToAssertionCount(1);
            }
        }

        $this->assertDatabaseCount('campaigns', 0);
    }

    public function test_image_validation_accepts_the_approved_c11_ratio(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = app(SponsorService::class)->create($this->sponsorData(), $admin);

        $campaign = app(CampaignService::class)->create(
            $this->campaignData($sponsor),
            $this->syntheticPng('c11-approved.png', 1200, 480),
            $admin,
        );

        $this->assertSame(1200, $campaign->image_width);
        $this->assertSame(480, $campaign->image_height);
    }

    public function test_rejected_edit_with_identical_image_keeps_validated_source(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = app(SponsorService::class)->create($this->sponsorData(), $admin);
        $service = app(CampaignService::class);
        $campaign = $service->create(
            $this->campaignData($sponsor),
            $this->syntheticPng('campaign.png', 1440, 360),
            $admin,
        );
        $service->activate($campaign, $admin);

        try {
            $service->update(
                $campaign->refresh(),
                ['title' => 'No permitido mientras esta activa'],
                $this->syntheticPng('same-campaign.png', 1440, 360),
                $admin,
            );
            $this->fail('An active campaign was edited.');
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }

        Storage::disk('local')->assertExists($campaign->source_image_path);
    }

    public function test_archive_uses_locked_state_to_remove_campaign_from_catalog(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = app(SponsorService::class)->create($this->sponsorData(), $admin);
        $service = app(CampaignService::class);
        $campaign = $service->create(
            $this->campaignData($sponsor),
            $this->syntheticPng('campaign.png', 1440, 360),
            $admin,
        );
        $staleDraft = $campaign->fresh();
        $service->activate($campaign, $admin);

        $service->archive($staleDraft, $admin);

        $manifest = json_decode(Storage::disk('public')->get('campaigns/v1/catalog.json'), true, flags: JSON_THROW_ON_ERROR);
        $catalogPath = parse_url($manifest['url'], PHP_URL_PATH);
        $catalogPath = preg_replace('#^/storage/#', '', $catalogPath);
        $catalog = json_decode(Storage::disk('public')->get($catalogPath), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame([], $catalog['campaigns']);
    }

    public function test_partner_inquiry_never_creates_a_sponsor_or_campaign(): void
    {
        PartnerInquiry::query()->create([
            'public_id' => 'pi_aaaaaaaaaaaaaaaaaaaaaaaa',
            'idempotency_hash' => hash('sha256', 'request'),
            'request_fingerprint' => hash('sha256', 'payload'),
            'business_name' => 'Solicitud sintetica',
            'contact_name' => 'Contacto',
            'email' => 'contacto@example.test',
            'phone' => '+57 300 000 0000',
            'city' => 'Medellin',
            'category' => 'workshop',
            'consent_version' => 'test-v1',
            'consented_at' => now(),
            'status' => 'approved',
        ]);

        $this->assertDatabaseCount('sponsors', 0);
        $this->assertDatabaseCount('campaigns', 0);
    }

    public function test_failed_catalog_publication_does_not_leave_campaign_paused(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $sponsor = app(SponsorService::class)->create($this->sponsorData(), $admin);
        $campaign = app(CampaignService::class)->create(
            $this->campaignData($sponsor),
            $this->syntheticPng('campaign.png', 1440, 360),
            $admin,
        );
        app(CampaignService::class)->activate($campaign, $admin);

        $publisher = \Mockery::mock(CampaignCatalogPublisher::class);
        $publisher->shouldReceive('publish')->once()->andThrow(new DomainException('Synthetic catalog failure.'));
        $service = new CampaignService(
            app(CampaignImageStore::class),
            $publisher,
            app(DatasetAuditLogger::class),
        );

        try {
            $service->pause($campaign->refresh(), $admin);
            $this->fail('The synthetic publication failure was not propagated.');
        } catch (DomainException $error) {
            $this->assertSame('Synthetic catalog failure.', $error->getMessage());
        }

        $this->assertSame(CampaignStatus::Active, $campaign->refresh()->status);
        $this->assertDatabaseMissing('audit_logs', [
            'action' => 'campaign.paused',
            'subject_type' => Campaign::class,
            'subject_id' => $campaign->id,
        ]);
    }

    /** @return array<string, mixed> */
    private function sponsorData(): array
    {
        return [
            'name' => 'Aliado Sintetico SAS',
            'contact_name' => 'Contacto Privado',
            'contact_email' => 'privado@example.test',
            'contact_phone' => '+57 300 000 0000',
            'notes' => 'Fixture sintetico.',
        ];
    }

    /** @return array<string, mixed> */
    private function campaignData(Sponsor $sponsor): array
    {
        return [
            'sponsor_id' => $sponsor->id,
            'eyebrow' => 'PATROCINADO',
            'title' => 'Campana sintetica',
            'subtitle' => 'Contenido de prueba sin oferta comercial real.',
            'cta_text' => 'Conocer mas',
            'cta_url' => 'https://example.test/campana',
            'placement' => 'home_c11',
            'priority' => 20,
            'scope' => CampaignScope::National->value,
            'geographic_unit_id' => null,
            'starts_at' => now()->subHour(),
            'ends_at' => now()->addDay(),
        ];
    }

    private function syntheticPng(string $name, int $width, int $height): UploadedFile
    {
        $chunk = static fn (string $type, string $data): string => pack('N', strlen($data))
            .$type.$data.pack('N', crc32($type.$data));
        $scanline = "\0".str_repeat("\0", $width * 3);
        $bytes = "\x89PNG\r\n\x1a\n"
            .$chunk('IHDR', pack('NNCCCCC', $width, $height, 8, 2, 0, 0, 0))
            .$chunk('IDAT', gzcompress(str_repeat($scanline, $height), 9))
            .$chunk('IEND', '');

        return UploadedFile::fake()->createWithContent($name, $bytes);
    }
}
