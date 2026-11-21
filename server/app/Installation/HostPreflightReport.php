<?php

namespace App\Installation;

readonly class HostPreflightReport
{
    /** @param list<string> $blockers */
    public function __construct(
        public bool $ready,
        public array $blockers,
    ) {}
}
