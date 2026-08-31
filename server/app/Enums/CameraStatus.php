<?php

namespace App\Enums;

enum CameraStatus: string
{
    case Draft = 'draft';
    case InReview = 'in_review';
    case Verified = 'verified';
    case Active = 'active';
    case Inactive = 'inactive';
    case Rejected = 'rejected';
    case Retired = 'retired';
}
