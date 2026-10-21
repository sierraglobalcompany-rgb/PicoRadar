<?php

namespace Tests\Feature;

use App\Enums\CampaignStatus;
use App\Enums\OperatorRole;
use App\Http\Controllers\Admin\CampaignController;
use App\Http\Controllers\Admin\SponsorController;
use App\Models\Campaign;
use App\Models\Sponsor;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CampaignAdminControllerTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Storage::fake('local');
        Storage::fake('public');
        config([
            'campaigns.private_disk' => 'local',
            'campaigns.public_disk' => 'public',
            'campaigns.public_base_url' => 'https://cdn.picoradar.test/storage',
        ]);
        $this->registerModuleRoutes();
    }

    public function test_commercial_operator_can_manage_drafts_preview_and_duplicate_but_cannot_publish(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $this->actingAs($commercial)->post(route('admin.sponsors.store'), [
            'name' => 'Aliado sintetico',
            'contact_name' => 'Contacto privado',
            'contact_email' => 'privado@example.test',
            'contact_phone' => '+57 300 000 0000',
            'notes' => 'Fixture de prueba.',
        ])->assertRedirect();
        $sponsor = Sponsor::query()->sole();

        $this->post(route('admin.campaigns.store'), $this->campaignData($sponsor) + [
            'image' => $this->syntheticPng('campaign.png', 1440, 360),
        ])->assertRedirect();
        $campaign = Campaign::query()->sole();

        $this->get(route('admin.campaigns.preview', $campaign))
            ->assertOk()
            ->assertSee('Vista previa C11')
            ->assertSee('Campana sintetica')
            ->assertSee('PATROCINADO');
        $this->get(route('admin.campaigns.image', $campaign))
            ->assertOk()
            ->assertHeader('Cache-Control', 'no-store, private')
            ->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->post(route('admin.campaigns.duplicate', $campaign))->assertRedirect();
        $this->assertDatabaseCount('campaigns', 2);

        $this->post(route('admin.campaigns.activate', $campaign))->assertForbidden();
        $this->assertSame(CampaignStatus::Draft, $campaign->refresh()->status);
    }

    public function test_admin_can_activate_pause_and_archive_through_module_controllers(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin]);
        $this->actingAs($admin);
        $this->post(route('admin.sponsors.store'), [
            'name' => 'Aliado sintetico',
            'contact_email' => 'privado@example.test',
        ])->assertRedirect();
        $sponsor = Sponsor::query()->sole();
        $this->post(route('admin.campaigns.store'), $this->campaignData($sponsor) + [
            'image' => $this->syntheticPng('campaign.png', 1440, 360),
        ])->assertRedirect();
        $campaign = Campaign::query()->sole();

        $this->post(route('admin.campaigns.activate', $campaign))->assertRedirect();
        $this->assertSame(CampaignStatus::Active, $campaign->refresh()->status);
        Storage::disk('public')->assertExists('campaigns/v1/catalog.json');

        $this->post(route('admin.campaigns.pause', $campaign))->assertRedirect();
        $this->assertSame(CampaignStatus::Paused, $campaign->refresh()->status);

        $this->delete(route('admin.campaigns.archive', $campaign))->assertRedirect();
        $this->assertSame(CampaignStatus::Archived, $campaign->refresh()->status);
    }

    public function test_campaign_form_rejects_unapproved_placement_insecure_target_and_invalid_image(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $sponsor = Sponsor::query()->create([
            'public_id' => 'sp_synthetic',
            'name' => 'Aliado sintetico',
            'status' => 'active',
        ]);

        $response = $this->actingAs($commercial)->post(route('admin.campaigns.store'), array_replace($this->campaignData($sponsor), [
            'placement' => 'bottom_banner',
            'cta_url' => 'http://unsafe.example.test',
            'image' => UploadedFile::fake()->createWithContent('campaign.png', '<html>not an image</html>'),
        ]));

        $response->assertSessionHasErrors(['placement', 'cta_url', 'image']);
        $this->assertDatabaseCount('campaigns', 0);
    }

    public function test_campaign_form_reports_a_c11_ratio_error_without_a_server_failure(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $sponsor = Sponsor::query()->create([
            'public_id' => 'sp_ratio_error',
            'name' => 'Aliado sintetico',
            'status' => 'active',
        ]);

        $this->actingAs($commercial)->from(route('admin.campaigns.create'))->post(
            route('admin.campaigns.store'),
            $this->campaignData($sponsor) + [
                'image' => $this->syntheticPng('square.png', 720, 720),
            ],
        )->assertRedirect(route('admin.campaigns.create'))->assertSessionHasErrors('image');

        $this->assertDatabaseCount('campaigns', 0);
    }

    /** @return array<string, mixed> */
    private function campaignData(Sponsor $sponsor): array
    {
        return [
            'sponsor_id' => $sponsor->id,
            'eyebrow' => 'PATROCINADO',
            'title' => 'Campana sintetica',
            'subtitle' => 'Contenido sintetico sin oferta real.',
            'cta_text' => 'Conocer mas',
            'cta_url' => 'https://example.test/campana',
            'placement' => 'home_c11',
            'priority' => 20,
            'scope' => 'national',
            'geographic_unit_id' => null,
            'starts_at' => now()->subHour()->format('Y-m-d H:i:s'),
            'ends_at' => now()->addDay()->format('Y-m-d H:i:s'),
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

    private function registerModuleRoutes(): void
    {
        Route::middleware('web')->prefix('/test-admin')->group(function (): void {
            Route::get('/sponsors', [SponsorController::class, 'index'])->name('admin.sponsors.index');
            Route::get('/sponsors/create', [SponsorController::class, 'create'])->name('admin.sponsors.create');
            Route::post('/sponsors', [SponsorController::class, 'store'])->name('admin.sponsors.store');
            Route::get('/sponsors/{sponsor}', [SponsorController::class, 'show'])->name('admin.sponsors.show');
            Route::get('/sponsors/{sponsor}/edit', [SponsorController::class, 'edit'])->name('admin.sponsors.edit');
            Route::put('/sponsors/{sponsor}', [SponsorController::class, 'update'])->name('admin.sponsors.update');
            Route::delete('/sponsors/{sponsor}', [SponsorController::class, 'archive'])->name('admin.sponsors.archive');

            Route::get('/campaigns', [CampaignController::class, 'index'])->name('admin.campaigns.index');
            Route::get('/campaigns/create', [CampaignController::class, 'create'])->name('admin.campaigns.create');
            Route::post('/campaigns', [CampaignController::class, 'store'])->name('admin.campaigns.store');
            Route::get('/campaigns/{campaign}', [CampaignController::class, 'show'])->name('admin.campaigns.show');
            Route::get('/campaigns/{campaign}/edit', [CampaignController::class, 'edit'])->name('admin.campaigns.edit');
            Route::put('/campaigns/{campaign}', [CampaignController::class, 'update'])->name('admin.campaigns.update');
            Route::post('/campaigns/{campaign}/duplicate', [CampaignController::class, 'duplicate'])->name('admin.campaigns.duplicate');
            Route::get('/campaigns/{campaign}/preview', [CampaignController::class, 'preview'])->name('admin.campaigns.preview');
            Route::get('/campaigns/{campaign}/image', [CampaignController::class, 'image'])->name('admin.campaigns.image');
            Route::post('/campaigns/{campaign}/activate', [CampaignController::class, 'activate'])->name('admin.campaigns.activate');
            Route::post('/campaigns/{campaign}/pause', [CampaignController::class, 'pause'])->name('admin.campaigns.pause');
            Route::delete('/campaigns/{campaign}', [CampaignController::class, 'archive'])->name('admin.campaigns.archive');
        });
        Route::getRoutes()->refreshNameLookups();
        Route::getRoutes()->refreshActionLookups();
    }
}
