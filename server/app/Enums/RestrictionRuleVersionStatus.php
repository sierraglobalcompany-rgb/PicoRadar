<?php

namespace App\Enums;

enum RestrictionRuleVersionStatus: string
{
    case Draft = 'draft';
    case Validated = 'validated';
    case Archived = 'archived';
}
