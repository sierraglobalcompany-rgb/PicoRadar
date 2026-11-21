<?php

namespace App\Models;

use App\Enums\PartnerInquiryStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'public_id',
    'idempotency_hash',
    'request_fingerprint',
    'business_name',
    'contact_name',
    'email',
    'phone',
    'city',
    'category',
    'message',
    'consent_version',
    'consented_at',
    'status',
])]
class PartnerInquiry extends Model
{
    protected function casts(): array
    {
        return [
            'consented_at' => 'datetime',
            'status' => PartnerInquiryStatus::class,
        ];
    }
}
