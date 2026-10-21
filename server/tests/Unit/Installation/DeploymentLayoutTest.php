<?php

namespace Tests\Unit\Installation;

use App\Installation\DeploymentLayout;
use PHPUnit\Framework\TestCase;

class DeploymentLayoutTest extends TestCase
{
    public function test_it_derives_only_the_dedicated_private_and_public_roots(): void
    {
        $layout = DeploymentLayout::fromSetupDirectory(
            '/home/account/domains/example.test/public_html/picoradar/_setup',
        );

        $this->assertSame('/home/account/domains/example.test', $layout->domainRoot);
        $this->assertSame('/home/account/domains/example.test/public_html/picoradar', $layout->publicRoot);
        $this->assertSame('/home/account/domains/example.test/picoradar_app/current', $layout->privateRoot);
    }
}
