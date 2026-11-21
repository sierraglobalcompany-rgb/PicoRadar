<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['email', 'otp_hash', 'attempts', 'privacy_version', 'privacy_accepted_at', 'expires_at', 'consumed_at'])]
class AppLoginChallenge extends Model
{
    protected function casts(): array
    {
        return [
            'attempts' => 'integer',
            'privacy_accepted_at' => 'datetime',
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
        ];
    }
}
