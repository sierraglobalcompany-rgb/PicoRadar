<?php

namespace App\Enums;

enum CameraType: string
{
    case Speed = 'speed';
    case RedLight = 'red_light';
    case Combined = 'combined';
    case Other = 'other';
    case Unknown = 'unknown';

    public function supportsSpeed(): bool
    {
        return in_array($this, [self::Speed, self::Combined], true);
    }
}
