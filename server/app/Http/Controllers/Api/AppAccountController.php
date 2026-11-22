<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\AppAccountOtpMail;
use App\Models\AppAccessToken;
use App\Models\AppLoginChallenge;
use App\Models\AppUser;
use App\Models\AuditLog;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Throwable;

class AppAccountController extends Controller
{
    private const CATEGORIES = ['car', 'motorcycle', 'taxi', 'public_service'];

    public function requestOtp(Request $request)
    {
        if (! $this->accountsEnabled() || ! $this->transactionalEmailAvailable()) {
            return $this->notConfigured();
        }

        if ($this->hasUnknownFields($request, ['email', 'privacyAccepted'])) {
            return $this->validationFailed();
        }

        $data = $request->validate([
            'email' => ['required', 'string', 'email:rfc', 'max:254'],
            'privacyAccepted' => ['sometimes', 'boolean'],
        ]);
        $email = mb_strtolower(trim($data['email']));
        $user = AppUser::query()->where('email', $email)->first();
        $privacyVersion = $this->privacyVersion();
        $privacyUrl = $this->privacyUrl();
        $accepted = ($data['privacyAccepted'] ?? false) === true || ($data['privacyAccepted'] ?? null) === 1 || ($data['privacyAccepted'] ?? null) === '1';
        $needsCurrentConsent = $user && $privacyVersion && $privacyUrl && $user->privacy_version !== $privacyVersion;
        $isNewAccount = ! $user;

        // An unknown address receives the same response; no PII is stored until the policy is configured and accepted.
        if (($isNewAccount && (! $privacyVersion || ! $privacyUrl || ! $accepted)) || ($needsCurrentConsent && ! $accepted)) {
            return response()->json(['data' => ['status' => 'accepted']], 202);
        }

        $email = $user?->email ?? $email;
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $consentVersion = ($isNewAccount || $needsCurrentConsent) ? $privacyVersion : null;

        try {
            $challenge = DB::transaction(function () use ($email, $code, $consentVersion): AppLoginChallenge {
                $this->purgeExpired();
                AppLoginChallenge::query()->where('email', $email)->delete();

                return AppLoginChallenge::query()->create([
                    'email' => $email,
                    'otp_hash' => Hash::make($code),
                    'attempts' => 0,
                    'privacy_version' => $consentVersion,
                    'privacy_accepted_at' => $consentVersion ? now() : null,
                    'expires_at' => now()->addMinutes(10),
                ]);
            });
            Mail::to($email)->send(new AppAccountOtpMail($code));
        } catch (Throwable) {
            if (isset($challenge)) {
                $challenge->delete();
            }

            return $this->notConfigured();
        }

        return response()->json(['data' => ['status' => 'accepted']], 202);
    }

    public function verifyOtp(Request $request)
    {
        if (! $this->accountsEnabled() || ! $this->transactionalEmailAvailable()) {
            return $this->notConfigured();
        }
        if ($this->hasUnknownFields($request, ['email', 'code'])) {
            return $this->validationFailed();
        }

        $data = $request->validate([
            'email' => ['required', 'string', 'email:rfc', 'max:254'],
            'code' => ['required', 'string', 'regex:/^\d{6,8}$/D'],
        ]);
        $email = mb_strtolower(trim($data['email']));

        try {
            $result = DB::transaction(function () use ($email, $data): array {
                $this->purgeExpired();
                $challenge = AppLoginChallenge::query()->where('email', $email)->lockForUpdate()->first();
                if (! $challenge || $challenge->consumed_at || $challenge->expires_at->isPast() || $challenge->attempts >= 5) {
                    return [];
                }
                if (! Hash::check($data['code'], $challenge->otp_hash)) {
                    $challenge->increment('attempts');

                    return [];
                }

                $challenge->update(['consumed_at' => now()]);
                $user = AppUser::query()->where('email', $email)->lockForUpdate()->first();
                if ($user && $user->isAccessBlocked()) {
                    $plainToken = bin2hex(random_bytes(32));
                    $expiresAt = now()->addMinutes(10);
                    AppAccessToken::query()->create([
                        'app_user_id' => $user->id,
                        'purpose' => 'suppression',
                        'token_hash' => hash('sha256', $plainToken),
                        'expires_at' => $expiresAt,
                    ]);
                    AuditLog::query()->create([
                        'actor_id' => null,
                        'action' => 'app_account.suppression_access_issued',
                        'subject_type' => AppUser::class,
                        'subject_id' => $user->id,
                        'metadata' => ['purpose' => 'suppression_only', 'expires_at' => $expiresAt->toISOString()],
                    ]);
                    $challenge->delete();

                    return ['token' => $plainToken, 'purpose' => 'suppression', 'user' => $user->fresh()];
                }
                if (! $user) {
                    if (! $challenge->privacy_version || ! $challenge->privacy_accepted_at || ! $this->privacyUrl()) {
                        return [];
                    }
                    $user = AppUser::query()->create([
                        'public_id' => (string) Str::uuid(),
                        'email' => $email,
                        'categories' => [],
                        'privacy_version' => $challenge->privacy_version,
                        'privacy_accepted_at' => $challenge->privacy_accepted_at,
                        'privacy_purpose' => 'optional_account',
                        'marketing_consent' => false,
                        'email_verified_at' => now(),
                    ]);
                } elseif ($challenge->privacy_version && $challenge->privacy_version !== $user->privacy_version) {
                    $user->forceFill([
                        'privacy_version' => $challenge->privacy_version,
                        'privacy_accepted_at' => $challenge->privacy_accepted_at,
                        'privacy_purpose' => 'optional_account',
                    ])->save();
                }

                $plainToken = bin2hex(random_bytes(32));
                AppAccessToken::query()->create([
                    'app_user_id' => $user->id,
                    'purpose' => 'session',
                    'token_hash' => hash('sha256', $plainToken),
                    'expires_at' => now()->addDays(30),
                ]);
                $challenge->delete();

                return ['token' => $plainToken, 'purpose' => 'session', 'user' => $user->fresh()];
            });
        } catch (QueryException) {
            return $this->invalidCode();
        }

        if (! isset($result['user'])) {
            return $this->invalidCode();
        }

        return response()->json(['data' => [
            'token' => $result['token'],
            'tokenPurpose' => $result['purpose'],
            'profile' => $result['purpose'] === 'suppression'
                ? $this->suppressionAccessData($result['user'])
                : $this->profileData($result['user']),
        ]]);
    }

    public function show(Request $request)
    {
        return response()->json(['data' => ['profile' => $this->profileData($this->account($request))]]);
    }

    public function update(Request $request)
    {
        if ($this->hasUnknownFields($request, ['name', 'phone', 'municipality', 'categories'])) {
            return $this->validationFailed();
        }
        $data = $request->validate([
            'name' => ['sometimes', 'nullable', 'string', 'max:120'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:24'],
            'municipality' => ['sometimes', 'nullable', 'string', 'max:120'],
            'categories' => ['sometimes', 'array', 'max:4'],
            'categories.*' => ['string', 'distinct', 'in:'.implode(',', self::CATEGORIES)],
        ]);
        $user = $this->account($request);
        $user->fill($data)->save();

        return response()->json(['data' => ['profile' => $this->profileData($user->fresh())]]);
    }

    public function updateMarketing(Request $request)
    {
        if ($this->hasUnknownFields($request, ['marketingConsent'])) {
            return $this->validationFailed();
        }
        $data = $request->validate(['marketingConsent' => ['required', 'boolean']]);
        $user = $this->account($request);
        $consent = (bool) $data['marketingConsent'];
        $user->forceFill([
            'marketing_consent' => $consent,
            'marketing_version' => $consent ? config('app_accounts.marketing_version') : null,
            'marketing_consented_at' => $consent ? now() : null,
        ])->save();

        return response()->json(['data' => ['marketingConsent' => $consent]]);
    }

    public function logout(Request $request)
    {
        $request->attributes->get('appAccountToken')?->delete();

        return response()->noContent();
    }

    public function destroy(Request $request)
    {
        $user = $this->account($request);
        DB::transaction(function () use ($user): void {
            AppLoginChallenge::query()->where('email', $user->email)->delete();
            AuditLog::query()->create([
                'actor_id' => null,
                'action' => 'app_account.suppressed',
                'subject_type' => AppUser::class,
                'subject_id' => null,
                'metadata' => ['reason' => 'self_service_suppression'],
            ]);
            $user->delete();
        });

        return response()->noContent();
    }

    private function account(Request $request): AppUser
    {
        return $request->attributes->get('appAccount');
    }

    private function profileData(AppUser $user): array
    {
        return [
            'id' => $user->public_id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'municipality' => $user->municipality,
            'categories' => $user->categories ?? [],
            'privacyVersion' => $user->privacy_version,
            'privacyAcceptedAt' => $user->privacy_accepted_at?->toISOString(),
            'marketingConsent' => $user->marketing_consent,
            'accountStatus' => $user->accountStatus(),
            'entitlement' => [
                'plan' => $user->accountPlan(),
                'status' => $user->entitlementStatus(),
                'validFrom' => $user->plan_valid_from?->toISOString()
                    ?? ($user->accountPlan() === 'free' ? $user->created_at?->toISOString() : null),
                'validUntil' => $user->plan_valid_until?->toISOString(),
                'source' => $user->plan_source ?: ($user->accountPlan() === 'free' ? 'default_free' : null),
            ],
        ];
    }

    private function suppressionAccessData(AppUser $user): array
    {
        return [
            'id' => $user->public_id,
            'accountStatus' => $user->accountStatus(),
            'entitlement' => [
                'plan' => 'unknown',
                'status' => 'unknown',
                'validFrom' => null,
                'validUntil' => null,
                'source' => null,
            ],
        ];
    }

    private function accountsEnabled(): bool
    {
        return (bool) config('app_accounts.enabled');
    }

    private function transactionalEmailAvailable(): bool
    {
        return (app()->environment('testing') && config('mail.default') === 'array') || (
            config('app_accounts.transactional_email_enabled')
            && ! in_array(config('mail.default'), ['log', 'array', 'null'], true)
        );
    }

    private function privacyVersion(): ?string
    {
        $value = config('app_accounts.privacy_version');

        return is_string($value) && trim($value) !== '' ? trim($value) : null;
    }

    private function privacyUrl(): ?string
    {
        $value = config('app_accounts.privacy_url');
        if (! is_string($value) || trim($value) === '') {
            return null;
        }
        $parts = parse_url($value);

        return ($parts['scheme'] ?? null) === 'https'
            && isset($parts['host'])
            && array_intersect(array_keys($parts), ['user', 'pass', 'query', 'fragment']) === []
            ? $value
            : null;
    }

    private function purgeExpired(): void
    {
        AppLoginChallenge::query()->where('expires_at', '<=', now())->delete();
        AppAccessToken::query()->where('expires_at', '<=', now())->delete();
    }

    private function hasUnknownFields(Request $request, array $allowed): bool
    {
        return array_diff(array_keys($request->all()), $allowed) !== [];
    }

    private function validationFailed()
    {
        return response()->json(['error' => ['code' => 'validation_failed']], 422);
    }

    private function invalidCode()
    {
        return response()->json(['error' => ['code' => 'invalid_or_expired_code']], 422);
    }

    private function notConfigured()
    {
        return response()->json(['error' => ['code' => 'not_configured']], 503);
    }
}
