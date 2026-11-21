<?php

namespace App\Enums;

enum CampaignScope: string
{
    case National = 'national';
    case Department = 'department';
    case Municipality = 'municipality';
}
