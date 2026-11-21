<?php

$domainRoot = dirname(__DIR__, 3);
$privateRoot = getenv('PICORADAR_PRIVATE_ROOT') ?: $domainRoot.DIRECTORY_SEPARATOR.'picoradar_app'.DIRECTORY_SEPARATOR.'current';
$publicRoot = dirname(__DIR__);
$entrypoint = $privateRoot.DIRECTORY_SEPARATOR.'deploy'.DIRECTORY_SEPARATOR.'hostinger'.DIRECTORY_SEPARATOR.'setup.php';

if (! is_file($entrypoint)) {
    http_response_code(503);
    header('Content-Type: text/plain; charset=UTF-8');
    echo 'PicoRadar installer package is incomplete.';
    exit;
}

require $entrypoint;
