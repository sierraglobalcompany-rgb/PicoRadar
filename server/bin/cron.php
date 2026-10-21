<?php

use App\Installation\HostingerCronRunner;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$privateRoot = dirname(__DIR__);
$domainRoot = dirname($privateRoot, 2);
$publicRoot = $domainRoot.DIRECTORY_SEPARATOR.'public_html'.DIRECTORY_SEPARATOR.'picoradar';
$lockPath = $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'framework'.DIRECTORY_SEPARATOR.'picoradar-cron.lock';
$installedLock = $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'installed.lock';

require $privateRoot.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';

$result = (new HostingerCronRunner($lockPath))->run(function () use ($privateRoot, $publicRoot, $installedLock): void {
    if (! is_file($installedLock)) {
        throw new RuntimeException('Installation is incomplete.');
    }

    $_SERVER['PICORADAR_PUBLIC_PATH'] = $publicRoot;
    putenv('PICORADAR_PUBLIC_PATH='.$publicRoot);

    /** @var Application $application */
    $application = require $privateRoot.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'app.php';
    $kernel = $application->make(Kernel::class);
    $kernel->bootstrap();

    if ($kernel->call('schedule:run', ['--no-interaction' => true]) !== 0) {
        throw new RuntimeException('Schedule failed.');
    }
    if ($kernel->call('queue:work', [
        '--stop-when-empty' => true,
        '--max-time' => 40,
        '--tries' => 1,
        '--sleep' => 1,
        '--no-interaction' => true,
    ]) !== 0) {
        throw new RuntimeException('Queue failed.');
    }
});

echo $result.PHP_EOL;
exit($result === 'OK' || $result === 'SKIPPED_LOCKED' ? 0 : 1);
