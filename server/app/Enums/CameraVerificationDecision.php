<?php

namespace App\Enums;

enum CameraVerificationDecision: string
{
    case Verified = 'verified';
    case Rejected = 'rejected';
}
