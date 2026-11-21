<?php

namespace App\Installation;

use InvalidArgumentException;

readonly class DeploymentLayout
{
    public function __construct(
        public string $domainRoot,
        public string $publicRoot,
        public string $privateRoot,
    ) {}

    public static function fromSetupDirectory(string $setupDirectory): self
    {
        $setupDirectory = rtrim(str_replace('\\', '/', $setupDirectory), '/');
        if (basename($setupDirectory) !== '_setup') {
            throw new InvalidArgumentException('The installer must run from the _setup directory.');
        }

        $publicRoot = dirname($setupDirectory);
        $domainRoot = dirname($publicRoot, 2);

        return new self(
            domainRoot: $domainRoot,
            publicRoot: $publicRoot,
            privateRoot: $domainRoot.'/picoradar_app/current',
        );
    }
}
