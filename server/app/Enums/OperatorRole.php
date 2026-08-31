<?php

namespace App\Enums;

enum OperatorRole: string
{
    case SuperAdmin = 'super_admin';
    case Admin = 'admin';
    case Editor = 'editor';
    case Reviewer = 'reviewer';
    case Commercial = 'commercial';

    public function label(): string
    {
        return match ($this) {
            self::SuperAdmin => 'Super administrator',
            self::Admin => 'Administrator',
            self::Editor => 'Editor',
            self::Reviewer => 'Reviewer',
            self::Commercial => 'Commercial',
        };
    }
}
