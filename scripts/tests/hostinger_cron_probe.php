<?php

use App\Installation\SyntheticCronProbeJob;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;
use Illuminate\Support\Facades\DB;

if ($argc !== 4) {
    fwrite(STDERR, "Usage: php hostinger_cron_probe.php <private-root> <dispatch|dispatch-failure|status> <marker>\n");
    exit(2);
}

[, $privateRoot, $action, $marker] = $argv;
$domainRoot = dirname($privateRoot, 2);
$publicRoot = $domainRoot.DIRECTORY_SEPARATOR.'public_html'.DIRECTORY_SEPARATOR.'picoradar';
require $privateRoot.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';
$_SERVER['PICORADAR_PUBLIC_PATH'] = $publicRoot;
putenv('PICORADAR_PUBLIC_PATH='.$publicRoot);

/** @var Application $application */
$application = require $privateRoot.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'app.php';
$application->make(Kernel::class)->bootstrap();

if ($action === 'dispatch') {
    SyntheticCronProbeJob::dispatch($marker, false);
    echo "QUEUED\n";
} elseif ($action === 'dispatch-failure') {
    SyntheticCronProbeJob::dispatch($marker, true);
    echo "QUEUED_FAILURE\n";
} elseif ($action === 'status') {
    echo json_encode([
        'queued' => DB::table('jobs')->count(),
        'failed' => DB::table('failed_jobs')->count(),
        'marker' => is_file($marker) ? trim((string) file_get_contents($marker)) : null,
    ], JSON_THROW_ON_ERROR).PHP_EOL;
} else {
    fwrite(STDERR, "Unknown action.\n");
    exit(2);
}
