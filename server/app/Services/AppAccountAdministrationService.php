<?php

namespace App\Services;

use App\Models\AppUser;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class AppAccountAdministrationService
{
    public function changeStatus(
        AppUser $appUser,
        string $status,
        string $reason,
        ?Carbon $until,
        User $actor,
    ): void {
        if (! in_array($status, ['active', 'suspended', 'banned'], true) || trim($reason) === '') {
            throw new InvalidArgumentException('Invalid consumer account status change.');
        }
        if (($status !== 'suspended' && $until !== null) || ($until && ! $until->isAfter(now()))) {
            throw new InvalidArgumentException('Invalid consumer account status expiry.');
        }

        DB::transaction(function () use ($appUser, $status, $reason, $until, $actor): void {
            $appUser->refresh();
            $previous = $appUser->accountStatus();
            $changedAt = now();
            $appUser->forceFill([
                'account_status' => $status,
                'status_reason' => trim($reason),
                'status_changed_by' => $actor->id,
                'status_changed_at' => $changedAt,
                'status_until' => $until,
            ])->save();

            $revokedCount = 0;
            if ($status !== 'active') {
                $revokedCount = $appUser->accessTokens()
                    ->whereIn('purpose', ['session', 'suppression'])
                    ->whereNull('revoked_at')
                    ->update(['revoked_at' => $changedAt, 'updated_at' => $changedAt]);
            }

            AuditLog::query()->create([
                'actor_id' => $actor->id,
                'action' => 'app_users.status_changed',
                'subject_type' => AppUser::class,
                'subject_id' => $appUser->id,
                'metadata' => [
                    'from' => $previous,
                    'to' => $status,
                    'reason' => trim($reason),
                    'until' => $until?->toISOString(),
                    'sessions_revoked' => $revokedCount,
                ],
            ]);
        });
    }

    public function changePlan(
        AppUser $appUser,
        string $plan,
        ?Carbon $validFrom,
        ?Carbon $validUntil,
        ?string $reference,
        User $actor,
    ): void {
        if (! in_array($plan, ['free', 'pro'], true)) {
            throw new InvalidArgumentException('Invalid consumer account plan.');
        }
        if ($plan === 'pro' && (! $validFrom || ! $reference || trim($reference) === '')) {
            throw new InvalidArgumentException('Pro requires a server-side validity start and reference.');
        }
        if ($validUntil && (! $validFrom || ! $validUntil->isAfter($validFrom))) {
            throw new InvalidArgumentException('Pro validity end must follow its start.');
        }

        DB::transaction(function () use ($appUser, $plan, $validFrom, $validUntil, $reference, $actor): void {
            $appUser->refresh();
            $previous = $appUser->accountPlan();
            $source = $plan === 'pro' ? 'operator_grant' : 'default_free';
            $appUser->forceFill([
                'account_plan' => $plan,
                'plan_valid_from' => $plan === 'pro' ? $validFrom : null,
                'plan_valid_until' => $plan === 'pro' ? $validUntil : null,
                'plan_source' => $source,
                'plan_reference' => $plan === 'pro' ? trim((string) $reference) : null,
            ])->save();

            AuditLog::query()->create([
                'actor_id' => $actor->id,
                'action' => 'app_users.plan_changed',
                'subject_type' => AppUser::class,
                'subject_id' => $appUser->id,
                'metadata' => [
                    'from' => $previous,
                    'to' => $plan,
                    'source' => $source,
                    'valid_from' => $plan === 'pro' ? $validFrom?->toISOString() : null,
                    'valid_until' => $plan === 'pro' ? $validUntil?->toISOString() : null,
                    'reference_sha256' => $plan === 'pro' ? hash('sha256', trim((string) $reference)) : null,
                ],
            ]);
        });
    }
}
