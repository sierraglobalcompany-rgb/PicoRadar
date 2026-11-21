<?php

namespace App\Enums;

enum RestrictionImportStatus: string
{
    case Analyzed = 'analyzed';
    case Confirmed = 'confirmed';
    case Rejected = 'rejected';
}
