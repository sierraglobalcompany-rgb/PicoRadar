<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

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
        ];
    }

    public function accessTokens(): HasMany
    {
        return $this->hasMany(AppAccessToken::class);
    }
}
