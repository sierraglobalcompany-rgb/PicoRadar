<?php

namespace App\Enums;

enum GeographicUnitLevel: string
{
    case Country = 'country';
    case Department = 'department';
    case Municipality = 'municipality';
}
