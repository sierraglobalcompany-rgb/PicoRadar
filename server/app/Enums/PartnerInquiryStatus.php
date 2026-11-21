<?php

namespace App\Enums;

enum PartnerInquiryStatus: string
{
    case Pending = 'pending';
    case Reviewing = 'reviewing';
    case Contacted = 'contacted';
    case Approved = 'approved';
    case Rejected = 'rejected';

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pending',
            self::Reviewing => 'Reviewing',
            self::Contacted => 'Contacted',
            self::Approved => 'Approved',
            self::Rejected => 'Rejected',
        };
    }
}
