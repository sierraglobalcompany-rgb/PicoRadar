<?php

namespace App\Services;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;

class CampaignAccess
{
    public function authorizeView(?User $user): void
    {
        $this->authorize($user, [OperatorRole::SuperAdmin, OperatorRole::Admin, OperatorRole::Reviewer, OperatorRole::Commercial]);
    }

    public function authorizeEdit(?User $user): void
    {
        $this->authorize($user, [OperatorRole::SuperAdmin, OperatorRole::Admin, OperatorRole::Commercial]);
    }

    public function authorizePublish(?User $user): void
    {
        $this->authorize($user, [OperatorRole::SuperAdmin, OperatorRole::Admin]);
    }

    /** @param list<OperatorRole> $roles */
    private function authorize(?User $user, array $roles): void
    {
        if (! $user || ! $user->isActive() || ! in_array($user->role, $roles, true)) {
            throw new AuthorizationException('This operator cannot perform the campaign action.');
        }
    }
}
