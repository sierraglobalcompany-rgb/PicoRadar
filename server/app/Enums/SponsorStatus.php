<?php

namespace App\Enums;

enum SponsorStatus: string
{
    case Active = 'active';
    case Inactive = 'inactive';
    case Archived = 'archived';
}
