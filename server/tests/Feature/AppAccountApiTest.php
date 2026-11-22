<?php

namespace Tests\Feature;

use App\Mail\AppAccountOtpMail;
use App\Models\AppAccessToken;
use App\Models\AppLoginChallenge;
use App\Models\AppUser;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Tests\TestCase;

class AppAccountApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'app.url' => 'https://api.picoradar.test',
            'app_accounts.enabled' => true,
            'app_accounts.privacy_url' => 'https://picoradar.test/privacidad',
            'app_accounts.privacy_version' => '2026-11-17',
            'app_accounts.transactional_email_enabled' => true,
            'app_accounts.marketing_send_enabled' => false,
        ]);
        Mail::fake();
    }

    public function test_guest_can_consult_without_account_and_disabled_registration_fails_closed(): void
    {
        config(['app_accounts.enabled' => false]);

        $this->postJson('/api/v1/app-accounts/otp', ['email' => 'person@example.test'])
            ->assertStatus(503)
            ->assertExactJson(['error' => ['code' => 'not_configured']]);

        $this->assertDatabaseCount('app_users', 0);
        $this->assertDatabaseCount('users', 0);
    }

    public function test_registration_requires_policy_acceptance_before_challenge_and_creates_account_only_after_otp(): void
    {
        $this->postJson('/api/v1/app-accounts/otp', [
            'email' => ' PERSON@example.test ',
            'privacyAccepted' => false,
        ])->assertAccepted()->assertExactJson(['data' => ['status' => 'accepted']]);

        $this->assertDatabaseCount('app_login_challenges', 0);
        Mail::assertNothingOutgoing();

        $this->requestCode(' PERSON@example.test ')->assertAccepted();
        $this->assertDatabaseCount('app_users', 0);
        $challenge = AppLoginChallenge::query()->sole();
        $this->assertSame('person@example.test', $challenge->email);
        $this->assertSame('2026-11-17', $challenge->privacy_version);
        $this->assertMatchesRegularExpression('/^\$2y\$/', $challenge->otp_hash);
        Mail::assertSent(AppAccountOtpMail::class, 1);

        $response = $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'person@example.test',
            'code' => $this->mailCode(),
        ])->assertOk()
            ->assertJsonPath('data.profile.email', 'person@example.test')
            ->assertJsonPath('data.profile.accountStatus', 'active')
            ->assertJsonPath('data.profile.entitlement.plan', 'free')
            ->assertJsonPath('data.profile.entitlement.status', 'active')
            ->assertJsonPath('data.profile.entitlement.source', 'default_free');

        $this->assertDatabaseCount('app_users', 1);
        $this->assertDatabaseCount('users', 0);
        $user = AppUser::query()->sole();
        $this->assertSame('2026-11-17', $user->privacy_version);
        $this->assertTrue($user->privacy_accepted_at !== null);
        $this->assertFalse($user->marketing_consent);
        $this->assertDatabaseHas('app_access_tokens', [
            'app_user_id' => $user->id,
            'purpose' => 'session',
            'token_hash' => hash('sha256', $response->json('data.token')),
        ]);
    }

    public function test_existing_account_login_does_not_invent_or_repeat_consent(): void
    {
        $token = $this->verifiedToken();
        $user = AppUser::query()->sole();
        $originalConsentAt = $user->privacy_accepted_at->toISOString();

        $this->postJson('/api/v1/app-accounts/otp', [
            'email' => 'person@example.test', 'privacyAccepted' => false,
        ])->assertAccepted()->assertExactJson(['data' => ['status' => 'accepted']]);
        $challenge = AppLoginChallenge::query()->sole();
        $this->assertNull($challenge->privacy_version);
        $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'person@example.test', 'code' => $this->mailCode(),
        ])->assertOk();

        $this->assertSame($originalConsentAt, $user->fresh()->privacy_accepted_at->toISOString());
        $this->assertNotSame('', $token);
    }

    public function test_expired_reused_and_five_attempt_challenges_are_rejected(): void
    {
        $this->requestCode();
        $challenge = AppLoginChallenge::query()->sole();
        $challenge->update(['expires_at' => now()->subSecond()]);
        $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'person@example.test', 'code' => $this->mailCode(),
        ])->assertStatus(422);

        $this->requestCode();
        $code = $this->mailCode();
        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->postJson('/api/v1/app-accounts/otp/verify', [
                'email' => 'person@example.test', 'code' => '000000',
            ])->assertStatus(422);
        }
        $this->assertSame(5, AppLoginChallenge::query()->sole()->attempts);
        $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'person@example.test', 'code' => $code,
        ])->assertStatus(422);
        $this->assertDatabaseCount('app_users', 0);
    }

    public function test_existing_operator_session_is_not_an_app_account_and_otp_requests_are_rate_limited(): void
    {
        $operator = User::factory()->create();
        $this->actingAs($operator)->getJson('/api/v1/app-account')->assertUnauthorized();
        $this->assertDatabaseCount('app_users', 0);

        RateLimiter::clear('app-account-otp-ip|'.hash('sha256', '127.0.0.1'));
        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->postJson('/api/v1/app-accounts/otp', [
                'email' => 'limited@example.test', 'privacyAccepted' => true,
            ])->assertAccepted();
        }
        $this->postJson('/api/v1/app-accounts/otp', [
            'email' => 'limited@example.test', 'privacyAccepted' => true,
        ])->assertStatus(429);
        $this->assertDatabaseCount('app_login_challenges', 1);
    }

    public function test_unverified_customer_cannot_use_a_session_token(): void
    {
        $user = AppUser::query()->create([
            'public_id' => (string) Str::uuid(),
            'email' => 'unverified@example.test',
            'categories' => [],
            'privacy_version' => '2026-11-17',
            'privacy_accepted_at' => now(),
            'privacy_purpose' => 'optional_account',
            'marketing_consent' => false,
            'email_verified_at' => null,
        ]);
        $plain = bin2hex(random_bytes(32));
        AppAccessToken::query()->create([
            'app_user_id' => $user->id,
            'purpose' => 'session',
            'token_hash' => hash('sha256', $plain),
            'expires_at' => now()->addDay(),
        ]);

        $this->withToken($plain)->getJson('/api/v1/app-account')->assertUnauthorized();
    }

    public function test_missing_privacy_configuration_does_not_store_or_email_a_new_address(): void
    {
        config(['app_accounts.privacy_url' => null, 'app_accounts.privacy_version' => null]);
        $this->postJson('/api/v1/app-accounts/otp', [
            'email' => 'new@example.test', 'privacyAccepted' => true,
        ])->assertAccepted()->assertExactJson(['data' => ['status' => 'accepted']]);

        $this->assertDatabaseCount('app_login_challenges', 0);
        $this->assertDatabaseCount('app_users', 0);
        Mail::assertNothingOutgoing();
    }

    public function test_logout_revokes_only_account_session_token(): void
    {
        $token = $this->verifiedToken();
        $this->withToken($token)->postJson('/api/v1/app-account/logout')->assertNoContent();
        $this->withToken($token)->getJson('/api/v1/app-account')->assertUnauthorized();
        $this->assertDatabaseCount('app_users', 1);
        $this->assertDatabaseCount('app_access_tokens', 0);
    }

    public function test_profile_is_whitelisted_and_consent_is_separate_and_reversible(): void
    {
        $token = $this->verifiedToken();

        $this->withToken($token)->patchJson('/api/v1/app-account', [
            'name' => 'Nombre de prueba',
            'municipality' => 'Medellín',
            'categories' => ['car', 'motorcycle'],
        ])->assertOk()->assertJsonPath('data.profile.categories.1', 'motorcycle');

        $this->withToken($token)->patchJson('/api/v1/app-account', [
            'email' => 'other@example.test', 'plate' => 'MED124',
        ])->assertStatus(422);
        $this->withToken($token)->patchJson('/api/v1/app-account', [
            'account_plan' => 'pro', 'entitlement' => ['status' => 'active'],
        ])->assertStatus(422);
        $this->withToken($token)->patchJson('/api/v1/app-account/marketing', [
            'marketingConsent' => true,
        ])->assertOk()->assertJsonPath('data.marketingConsent', true);
        $this->withToken($token)->patchJson('/api/v1/app-account/marketing', [
            'marketingConsent' => false,
        ])->assertOk()->assertJsonPath('data.marketingConsent', false);

        $this->assertDatabaseMissing('app_users', ['email' => 'other@example.test']);
        $this->assertDatabaseHas('app_users', ['email' => 'person@example.test', 'marketing_consent' => 0]);
    }

    public function test_suppression_revokes_sessions_and_same_email_restarts_without_old_profile_or_consent(): void
    {
        $token = $this->verifiedToken();
        $this->withToken($token)->patchJson('/api/v1/app-account', [
            'name' => 'Perfil anterior', 'categories' => ['taxi'],
        ])->assertOk();
        $this->withToken($token)->patchJson('/api/v1/app-account/marketing', [
            'marketingConsent' => true,
        ])->assertOk();
        $this->withToken($token)->deleteJson('/api/v1/app-account')->assertNoContent();
        $this->withToken($token)->getJson('/api/v1/app-account')->assertUnauthorized();
        $this->assertDatabaseCount('app_users', 0);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'app_account.suppressed',
            'subject_id' => null,
        ]);

        $this->requestCode();
        $newToken = $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'person@example.test', 'code' => $this->mailCode(),
        ])->assertOk()->json('data.token');
        $fresh = $this->withToken($newToken)->getJson('/api/v1/app-account')->assertOk();
        $this->assertNull($fresh->json('data.profile.name'));
        $this->assertSame([], $fresh->json('data.profile.categories'));
        $this->assertFalse($fresh->json('data.profile.marketingConsent'));
    }

    public function test_remote_http_is_rejected_and_requests_do_not_enumerate_accounts(): void
    {
        $this->requestCode()->assertExactJson(['data' => ['status' => 'accepted']]);
        $this->assertDatabaseCount('app_login_challenges', 1);
        $this->assertSame(1, Mail::sent(AppAccountOtpMail::class)->count());

        $this->postJson('http://remote.example.test/api/v1/app-accounts/otp', [
            'email' => 'other@example.test', 'privacyAccepted' => true,
        ])->assertStatus(400);
        $this->assertDatabaseCount('app_users', 0);
    }

    private function requestCode(string $email = 'person@example.test')
    {
        return $this->postJson('/api/v1/app-accounts/otp', [
            'email' => $email,
            'privacyAccepted' => true,
        ]);
    }

    private function mailCode(): string
    {
        $mail = Mail::sent(AppAccountOtpMail::class)->last();
        $this->assertNotNull($mail);

        return $mail->code;
    }

    private function verifiedToken(): string
    {
        $this->requestCode()->assertAccepted();

        return $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'person@example.test', 'code' => $this->mailCode(),
        ])->assertOk()->json('data.token');
    }
}
