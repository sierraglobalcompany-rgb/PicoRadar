<?php

namespace Tests\Unit\Installation;

use Illuminate\Foundation\Application;
use PHPUnit\Framework\TestCase;

class PublicPathBootstrapTest extends TestCase
{
    public function test_bootstrap_accepts_the_package_public_path_override(): void
    {
        $path = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-public-test';
        $previous = $_SERVER['PICORADAR_PUBLIC_PATH'] ?? null;
        $_SERVER['PICORADAR_PUBLIC_PATH'] = $path;

        try {
            /** @var Application $application */
            $application = require dirname(__DIR__, 3).DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'app.php';
            $this->assertSame($path, $application->publicPath());
        } finally {
            if ($previous === null) {
                unset($_SERVER['PICORADAR_PUBLIC_PATH']);
            } else {
                $_SERVER['PICORADAR_PUBLIC_PATH'] = $previous;
            }
        }
    }
}
