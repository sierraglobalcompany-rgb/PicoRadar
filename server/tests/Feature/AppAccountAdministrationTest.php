<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Mail\AppAccountOtpMail;
use App\Models\AppAccessToken;
use App\Models\AppUser;
use App\Models\AuditLog;
use App\Models\User;
use App\Services\AppAccountAdministrationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Str;
use Tests\TestCase;

class AppAccountAdministrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->ensurePlatformAccountColumns();
        config([
            'app.url' => 'https://api.picoradar.test',
            'app_accounts.enabled' => true,
            'app_accounts.privacy_url' => 'https://picoradar.test/privacidad',
            'app_accounts.privacy_version' => '2026-11-21',
            'app_accounts.transactional_email_enabled' => true,
            'mail.default' => 'array',
        ]);
        Mail::fake();
    }

    public function test_status_change_audits_and_revokes_sessions_without_reactivating_them(): void
    {
        $actor = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $appUser = $this->appUser();
        $sessionToken = $this->token($appUser, 'session');
        $unsubscribeToken = $this->token($appUser, 'unsubscribe');
        $service = app(AppAccountAdministrationService::class);

        $service->changeStatus($appUser, 'banned', 'Solicitud de soporte #A-1234', null, $actor);

        $this->assertSame('banned', $appUser->fresh()->accountStatus());
        $this->assertNotNull($sessionToken->fresh()->revoked_at);
        $this->assertNull($unsubscribeToken->fresh()->revoked_at);
        $this->assertDatabaseHas('audit_logs', [
            'actor_id' => $actor->id,
            'action' => 'app_users.status_changed',
            'subject_type' => AppUser::class,
            'subject_id' => $appUser->id,
        ]);

        $audit = AuditLog::query()->where('action', 'app_users.status_changed')->sole();
        $this->assertSame('active', $audit->metadata['from']);
        $this->assertSame('banned', $audit->metadata['to']);
        $this->assertSame('Solicitud de soporte #A-1234', $audit->metadata['reason']);
        $this->withToken($this->plainTokens[$sessionToken->id])
            ->getJson('/api/v1/app-account')
            ->assertUnauthorized();

        $service->changeStatus($appUser, 'active', 'Revisión completada #A-1234', null, $actor);
        $this->assertNotNull($sessionToken->fresh()->revoked_at);
        $this->withToken($this->plainTokens[$sessionToken->id])
            ->getJson('/api/v1/app-account')
            ->assertUnauthorized();
    }

    public function test_blocked_account_otp_issues_only_a_short_suppression_token(): void
    {
        $actor = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $appUser = $this->appUser();
        $this->postJson('/api/v1/app-accounts/otp', [
            'email' => 'person@example.test',
            'privacyAccepted' => false,
        ])->assertAccepted();
        $mail = Mail::sent(AppAccountOtpMail::class)->last();
        $this->assertNotNull($mail);

        app(AppAccountAdministrationService::class)->changeStatus(
            $appUser,
            'suspended',
            'Revisión manual #B-44',
            now()->addDay(),
            $actor,
        );

        $response = $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'person@example.test',
            'code' => $mail->code,
        ])->assertOk()
            ->assertJsonPath('data.tokenPurpose', 'suppression')
            ->assertJsonPath('data.profile.accountStatus', 'suspended')
            ->assertJsonMissingPath('data.profile.email');
        $suppressionToken = $response->json('data.token');
        $this->assertDatabaseHas('app_access_tokens', [
            'app_user_id' => $appUser->id,
            'purpose' => 'suppression',
            'token_hash' => hash('sha256', $suppressionToken),
            'revoked_at' => null,
        ]);
        $this->assertDatabaseMissing('app_access_tokens', [
            'app_user_id' => $appUser->id,
            'purpose' => 'session',
        ]);
        $this->withToken($suppressionToken)
            ->getJson('/api/v1/app-account')
            ->assertForbidden()
            ->assertExactJson(['error' => ['code' => 'suppression_action_only']]);
    }

    public function test_unrevoked_session_on_a_blocked_account_cannot_read_profile(): void
    {
        $appUser = $this->appUser();
        $token = $this->token($appUser, 'session');
        $appUser->forceFill(['account_status' => 'suspended'])->save();

        $this->withToken($this->plainTokens[$token->id])
            ->getJson('/api/v1/app-account')
            ->assertForbidden()
            ->assertExactJson(['error' => ['code' => 'account_suspended']]);
    }

    public function test_blocked_account_keeps_the_existing_self_service_deletion_path(): void
    {
        $actor = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $appUser = $this->appUser();
        $sessionToken = $this->token($appUser, 'session');
        app(AppAccountAdministrationService::class)->changeStatus(
            $appUser,
            'banned',
            'Solicitud de eliminación #D-17',
            null,
            $actor,
        );

        $this->withToken($this->plainTokens[$sessionToken->id])
            ->deleteJson('/api/v1/app-account')
            ->assertUnauthorized();

        $this->postJson('/api/v1/app-accounts/otp', [
            'email' => 'person@example.test',
            'privacyAccepted' => false,
        ])->assertAccepted();
        $mail = Mail::sent(AppAccountOtpMail::class)->last();
        $this->assertNotNull($mail);
        $suppressionToken = $this->postJson('/api/v1/app-accounts/otp/verify', [
            'email' => 'person@example.test',
            'code' => $mail->code,
        ])->assertOk()
            ->assertJsonPath('data.tokenPurpose', 'suppression')
            ->json('data.token');

        $this->withToken($suppressionToken)
            ->getJson('/api/v1/app-account')
            ->assertForbidden()
            ->assertExactJson(['error' => ['code' => 'suppression_action_only']]);
        $this->withToken($suppressionToken)
            ->deleteJson('/api/v1/app-account')
            ->assertNoContent();
        $this->assertDatabaseMissing('app_users', ['id' => $appUser->id]);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'app_account.suppressed',
            'subject_type' => AppUser::class,
        ]);
    }

    public function test_pro_entitlement_is_server_authoritative_and_requires_current_validity_and_reference(): void
    {
        $actor = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $appUser = $this->appUser();
        $token = $this->token($appUser, 'session');
        $service = app(AppAccountAdministrationService::class);
        $service->changePlan(
            $appUser,
            'pro',
            now()->subDay(),
            now()->addDays(30),
            'CASE-2026-001',
            $actor,
        );

        $this->assertTrue($appUser->fresh()->hasActiveProEntitlement());
        $this->withToken($this->plainTokens[$token->id])
            ->getJson('/api/v1/app-account')
            ->assertOk()
            ->assertJsonPath('data.profile.entitlement.plan', 'pro')
            ->assertJsonPath('data.profile.entitlement.status', 'active')
            ->assertJsonPath('data.profile.entitlement.source', 'operator_grant');

        $service->changePlan(
            $appUser,
            'pro',
            now()->subDays(3),
            now()->subDay(),
            'CASE-2026-002',
            $actor,
        );
        $this->assertFalse($appUser->fresh()->hasActiveProEntitlement());
        $this->withToken($this->plainTokens[$token->id])
            ->getJson('/api/v1/app-account')
            ->assertOk()
            ->assertJsonPath('data.profile.entitlement.status', 'expired');
    }

    public function test_consumer_panel_filters_free_pro_active_suspended_and_banned(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::SuperAdmin]);
        $free = $this->appUser(['email' => 'free@example.test']);
        $proBanned = $this->appUser(['email' => 'pro-banned@example.test']);
        $proBanned->forceFill([
            'account_plan' => 'pro',
            'account_status' => 'banned',
            'plan_valid_from' => now()->subDay(),
            'plan_valid_until' => now()->addDay(),
            'plan_source' => 'operator_grant',
            'plan_reference' => 'CASE-2026-003',
        ])->save();

        $this->actingAs($admin)
            ->get('/admin/app-users?plan=pro&status=banned')
            ->assertOk()
            ->assertSee('pro-banned@example.test')
            ->assertDontSee('free@example.test')
            ->assertSee('Baneada');
        $this->assertSame('free', $free->fresh()->accountPlan());
    }

    private function appUser(array $overrides = []): AppUser
    {
        return AppUser::query()->create(array_merge([
            'public_id' => (string) Str::uuid(),
            'email' => 'person@example.test',
            'categories' => [],
            'privacy_version' => '2026-11-21',
            'privacy_accepted_at' => now(),
            'privacy_purpose' => 'optional_account',
            'marketing_consent' => false,
            'email_verified_at' => now(),
        ], $overrides));
    }

    private array $plainTokens = [];

    private function token(AppUser $appUser, string $purpose): AppAccessToken
    {
        $plain = bin2hex(random_bytes(32));
        $token = AppAccessToken::query()->create([
            'app_user_id' => $appUser->id,
            'purpose' => $purpose,
            'token_hash' => hash('sha256', $plain),
            'expires_at' => now()->addDays(30),
        ]);
        $this->plainTokens[$token->id] = $plain;

        return $token;
    }

    private function ensurePlatformAccountColumns(): void
    {
        Schema::table('app_users', function (Blueprint $table): void {
            if (! Schema::hasColumn('app_users', 'account_plan')) {
                $table->string('account_plan', 16)->default('free');
            }
            if (! Schema::hasColumn('app_users', 'account_status')) {
                $table->string('account_status', 16)->default('active');
            }
            if (! Schema::hasColumn('app_users', 'plan_valid_from')) {
                $table->timestamp('plan_valid_from')->nullable();
            }
            if (! Schema::hasColumn('app_users', 'plan_valid_until')) {
                $table->timestamp('plan_valid_until')->nullable();
            }
            if (! Schema::hasColumn('app_users', 'plan_source')) {
                $table->string('plan_source', 40)->nullable();
            }
            if (! Schema::hasColumn('app_users', 'plan_reference')) {
                $table->string('plan_reference', 120)->nullable();
            }
            if (! Schema::hasColumn('app_users', 'status_reason')) {
                $table->text('status_reason')->nullable();
            }
            if (! Schema::hasColumn('app_users', 'status_changed_by')) {
                $table->unsignedBigInteger('status_changed_by')->nullable();
            }
            if (! Schema::hasColumn('app_users', 'status_changed_at')) {
                $table->timestamp('status_changed_at')->nullable();
            }
            if (! Schema::hasColumn('app_users', 'status_until')) {
                $table->timestamp('status_until')->nullable();
            }
        });
    }
}
