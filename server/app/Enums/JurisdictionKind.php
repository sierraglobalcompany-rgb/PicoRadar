<?php

namespace App\Enums;

enum JurisdictionKind: string
{
    case City = 'city';
    case District = 'district';
    case MetroArea = 'metro_area';
    case Region = 'region';
}
