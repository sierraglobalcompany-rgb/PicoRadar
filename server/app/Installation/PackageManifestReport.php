<?php

namespace App\Installation;

readonly class PackageManifestReport
{
    /** @param list<string> $errors */
    public function __construct(
        public bool $valid,
        public array $errors,
    ) {}
}
