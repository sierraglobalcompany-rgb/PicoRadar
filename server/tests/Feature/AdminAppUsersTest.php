<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Mail\AppAccountMarketingMail;
use App\Mail\AppAccountOtpMail;
use App\Models\AppUser;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdminAppUsersTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        config([
            'app_accounts.enabled' => true,
            'app_accounts.privacy_url' => 'https://picoradar.test/privacidad',
            'app_accounts.privacy_version' => '2026-11-17',
            'app_accounts.transactional_email_enabled' => true,
            'app_accounts.marketing_send_enabled' => false,
        ]);
        Mail::fake();
    }

    public function test_only_active_super_admin_can_list_export_preview_or_dispatch(): void
    {
        foreach ([OperatorRole::Admin, OperatorRole::Editor, OperatorRole::Reviewer, OperatorRole::Commercial] as $role) {
            $this->actingAs(User::factory()->create(['role' => $role]))
                ->get('/admin/app-users')->assertForbidden();
            $this->actingAs(User::factory()->create(['role' => $role]))
                ->get('/admin/app-users/export')->assertForbidden();
            $this->actingAs(User::factory()->create(['role' => $role]))
                ->post('/admin/app-users/marketing/preview', ['user_ids' => []])->assertForbidden();
            $this->actingAs(User::factory()->create(['role' => $role]))
                ->post('/admin/app-users/marketing/dispatch', [])->assertForbidden();
        }

        $inactive = User::factory()->create(['role' => OperatorRole::SuperAdmin, 'is_active' => false]);
        $this->actingAs($inactive)->get('/admin/app-users')->assertRedirect('/login');
        $this->assertGuest();
    }

    public function test_super_admin_filters_and_exports_only_verified_customers_with_csv_formula_protection(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $verified = $this->appUser([
            'name' => "  \t=SUM(1,1)",
            'email' => 'safe@example.test',
            'phone' => '+571234567890',
            'municipality' => 'Medellín',
            'categories' => ['car'],
            'marketing_consent' => true,
        ]);
        $this->appUser(['email' => 'unverified@example.test', 'email_verified_at' => null]);

        $this->actingAs($admin)->get('/admin/app-users?municipality=Medell%C3%ADn&category=car&marketing=1')
            ->assertOk()->assertSee('safe@example.test')->assertDontSee('unverified@example.test');
        $csv = $this->actingAs($admin)->get('/admin/app-users/export?marketing=1')
            ->assertOk()->assertHeader('content-type', 'text/csv; charset=UTF-8')
            ->streamedContent();
        $this->assertStringContainsString("'  \t=SUM(1,1)", $csv);
        $this->assertStringContainsString('safe@example.test', $csv);
        $this->assertStringNotContainsString('unverified@example.test', $csv);
        $this->assertDatabaseHas('audit_logs', [
            'actor_id' => $admin->id,
            'action' => 'app_users.exported',
        ]);
        $audit = json_decode((string) \DB::table('audit_logs')->where('action', 'app_users.exported')->value('metadata'), true);
        $this->assertSame(['marketing'], $audit['filter_types']);
        $this->assertArrayNotHasKey('email', $audit);
    }

    public function test_marketing_preview_and_dispatch_recheck_current_opt_in_and_are_fake_only_by_default(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $optedIn = $this->appUser(['marketing_consent' => true]);
        $optedOut = $this->appUser(['email' => 'out@example.test', 'marketing_consent' => false]);
        $this->actingAs($admin)->post('/admin/app-users/marketing/preview', [
            'user_ids' => [$optedIn->id, $optedOut->id],
            'subject' => 'Novedades de prueba',
            'body' => 'Contenido sintético del correo.',
        ])->assertOk()->assertSee('1 destinatario')->assertDontSee('out@example.test');

        $this->actingAs($admin)->post('/admin/app-users/marketing/dispatch', [
            'user_ids' => [$optedIn->id, $optedOut->id],
            'subject' => 'Novedades de prueba',
            'body' => 'Contenido sintético del correo.',
        ])->assertRedirect('/admin/app-users')->assertSessionHas('status');
        Mail::assertSent(AppAccountMarketingMail::class, 1);
        $this->assertDatabaseHas('app_access_tokens', [
            'app_user_id' => $optedIn->id,
            'purpose' => 'unsubscribe',
        ]);
        $this->assertDatabaseMissing('app_access_tokens', [
            'app_user_id' => $optedOut->id,
            'purpose' => 'unsubscribe',
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'actor_id' => $admin->id,
            'action' => 'app_users.marketing_dispatched',
        ]);

        $mail = Mail::sent(AppAccountMarketingMail::class)->first();
        $this->assertNotNull($mail);
        $this->get($mail->unsubscribeUrl)->assertOk()->assertSee('Preferencias de correo');
        $this->post($mail->unsubscribeUrl)->assertRedirect();
        $this->assertDatabaseHas('app_users', ['id' => $optedIn->id, 'marketing_consent' => 0]);
        $this->actingAs($admin)->post('/admin/app-users/marketing/dispatch', [
            'user_ids' => [$optedIn->id],
            'subject' => 'Novedades de prueba',
            'body' => 'Contenido sintético del correo.',
        ])->assertRedirect('/admin/app-users');
        Mail::assertSent(AppAccountMarketingMail::class, 1);
    }

    public function test_consent_revoked_after_preview_is_excluded_at_dispatch_time(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $user = $this->appUser(['marketing_consent' => true]);
        $this->actingAs($admin)->post('/admin/app-users/marketing/preview', [
            'user_ids' => [$user->id], 'subject' => 'Mensaje de prueba', 'body' => 'Contenido sintético autorizado.',
        ])->assertOk()->assertSee('1 destinatario');
        $user->forceFill(['marketing_consent' => false])->save();

        $this->actingAs($admin)->post('/admin/app-users/marketing/dispatch', [
            'user_ids' => [$user->id], 'subject' => 'Mensaje de prueba', 'body' => 'Contenido sintético autorizado.',
        ])->assertRedirect('/admin/app-users');
        Mail::assertNothingOutgoing();
        $this->assertDatabaseCount('app_access_tokens', 0);
    }

    public function test_marketing_dispatch_remains_disabled_outside_tests_by_default(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $user = $this->appUser(['marketing_consent' => true]);
        app()->detectEnvironment(fn (): string => 'production');
        config([
            'app_accounts.marketing_send_enabled' => false,
            'app_accounts.transactional_email_enabled' => false,
            'mail.default' => 'array',
        ]);
        $this->get('/login')->assertOk();
        $csrfToken = session()->token();

        $this->actingAs($admin)->post('/admin/app-users/marketing/dispatch', [
            '_token' => $csrfToken,
            'user_ids' => [$user->id],
            'subject' => 'Mensaje de prueba',
            'body' => 'Contenido sintético autorizado.',
        ])->assertStatus(503);

        Mail::assertNothingOutgoing();
    }

    public function test_synthetic_account_to_super_admin_export_opt_out_and_suppression_e2e(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $this->postJson('/api/v1/app-accounts/otp', [
            'email' => 'e2e@example.test',
            'privacyAccepted' => true,
        ])->assertAccepted();
        $otp = Mail::sent(AppAccountOtpMail::class)->last();
        $this->assertNotNull($otp);

        $token = $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'e2e@example.test',
            'code' => $otp->code,
        ])->assertOk()->json('data.token');
        $profile = $this->withToken($token)->patchJson('/api/v1/app-account', [
            'name' => 'Cuenta sintética E2E',
            'categories' => ['car'],
        ])->assertOk();
        $this->withToken($token)->patchJson('/api/v1/app-account/marketing', [
            'marketingConsent' => true,
        ])->assertOk();
        $appUser = AppUser::query()->sole();

        $this->actingAs($admin)->get('/admin/app-users?marketing=1&category=car')
            ->assertOk()->assertSee('e2e@example.test')->assertSee('Cuenta sintética E2E');
        $csv = $this->actingAs($admin)->get('/admin/app-users/export?marketing=1&category=car')
            ->assertOk()->streamedContent();
        $this->assertStringContainsString('e2e@example.test', $csv);
        $payload = [
            'user_ids' => [$appUser->id],
            'subject' => 'Aviso sintético',
            'body' => 'Mensaje de prueba con consentimiento vigente.',
        ];
        $this->actingAs($admin)->post('/admin/app-users/marketing/preview', $payload)
            ->assertOk()->assertSee('1 destinatario');
        $this->actingAs($admin)->post('/admin/app-users/marketing/dispatch', $payload)
            ->assertRedirect('/admin/app-users');
        Mail::assertSent(AppAccountMarketingMail::class, 1);

        $marketingMail = Mail::sent(AppAccountMarketingMail::class)->first();
        $this->assertNotNull($marketingMail);
        $this->post($marketingMail->unsubscribeUrl)->assertRedirect();
        $this->assertDatabaseHas('app_users', ['id' => $appUser->id, 'marketing_consent' => 0]);
        $this->actingAs($admin)->post('/admin/app-users/marketing/dispatch', $payload)
            ->assertRedirect('/admin/app-users');
        Mail::assertSent(AppAccountMarketingMail::class, 1);

        $this->withToken($token)->deleteJson('/api/v1/app-account')->assertNoContent();
        $this->assertDatabaseCount('app_users', 0);
        $this->assertDatabaseCount('app_access_tokens', 0);
        $this->assertDatabaseHas('audit_logs', ['action' => 'app_account.suppressed', 'subject_id' => null]);
        $this->assertSame('e2e@example.test', $profile->json('data.profile.email'));
    }

    private function appUser(array $overrides = []): AppUser
    {
        return AppUser::query()->create(array_merge([
            'public_id' => (string) Str::uuid(),
            'name' => 'Cliente sintético',
            'email' => 'client-'.Str::random(8).'@example.test',
            'phone' => null,
            'municipality' => null,
            'categories' => [],
            'privacy_version' => '2026-11-17',
            'privacy_accepted_at' => now(),
            'privacy_purpose' => 'optional_account',
            'marketing_consent' => false,
            'email_verified_at' => now(),
        ], $overrides));
    }
}
