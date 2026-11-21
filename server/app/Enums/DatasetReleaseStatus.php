<?php

namespace App\Enums;

enum DatasetReleaseStatus: string
{
    case Draft = 'draft';
    case Validated = 'validated';
    case Published = 'published';
    case Retired = 'retired';
}
