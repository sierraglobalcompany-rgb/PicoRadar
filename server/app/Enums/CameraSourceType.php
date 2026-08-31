<?php

namespace App\Enums;

enum CameraSourceType: string
{
    case Official = 'official';
    case OpenData = 'open_data';
    case Partner = 'partner';
    case Reference = 'reference';
}
