<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

#[Fillable([
    'public_id', 'name', 'email', 'phone', 'municipality', 'categories',
    'privacy_version', 'privacy_accepted_at', 'privacy_purpose',
    'marketing_consent', 'marketing_version', 'marketing_consented_at', 'email_verified_at',
])]
#[Hidden(['email'])]
class AppUser extends Model
{
    protected function casts(): array
    {
        return [
            'categories' => 'array',
            'privacy_accepted_at' => 'datetime',
            'marketing_consent' => 'boolean',
            'marketing_consented_at' => 'datetime',
            'email_verified_at' => 'datetime',
            'plan_valid_from' => 'datetime',
            'plan_valid_until' => 'datetime',
            'status_changed_by' => 'integer',
            'status_changed_at' => 'datetime',
            'status_until' => 'datetime',
        ];
    }

    public function accessTokens(): HasMany
    {
        return $this->hasMany(AppAccessToken::class);
    }

    public function statusChangedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'status_changed_by');
    }

    public function accountStatus(): string
    {
        $status = $this->getAttribute('account_status') ?? 'active';

        return in_array($status, ['active', 'suspended', 'banned'], true)
            ? $status
            : 'unknown';
    }

    public function accountPlan(): string
    {
        $plan = $this->getAttribute('account_plan') ?? 'free';

        return in_array($plan, ['free', 'pro'], true) ? $plan : 'unknown';
    }

    public function isAccessBlocked(): bool
    {
        return in_array($this->accountStatus(), ['suspended', 'banned', 'unknown'], true);
    }

    public function entitlementStatus(?Carbon $at = null): string
    {
        if ($this->accountPlan() === 'free') {
            return 'active';
        }
        if ($this->accountPlan() !== 'pro') {
            return 'unknown';
        }

        $validFrom = $this->getAttribute('plan_valid_from');
        $validUntil = $this->getAttribute('plan_valid_until');
        $source = $this->getAttribute('plan_source');
        $reference = $this->getAttribute('plan_reference');
        if (! $validFrom || ! is_string($source) || trim($source) === '' || ! is_string($reference) || trim($reference) === '') {
            return 'unverified';
        }

        $at ??= now();
        if ($validFrom->isAfter($at)) {
            return 'pending';
        }
        if ($validUntil && ! $validUntil->isAfter($at)) {
            return 'expired';
        }

        return 'active';
    }

    public function hasActiveProEntitlement(?Carbon $at = null): bool
    {
        return $this->accountPlan() === 'pro'
            && $this->accountStatus() === 'active'
            && $this->entitlementStatus($at) === 'active';
    }
}
