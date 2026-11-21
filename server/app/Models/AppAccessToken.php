<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['app_user_id', 'purpose', 'token_hash', 'expires_at', 'used_at', 'revoked_at'])]
class AppAccessToken extends Model
{
    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'used_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public function appUser(): BelongsTo
    {
        return $this->belongsTo(AppUser::class);
    }
}
