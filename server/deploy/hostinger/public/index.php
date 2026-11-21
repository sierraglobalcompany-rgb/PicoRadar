<?php

use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

$domainRoot = dirname(__DIR__, 2);
$privateRoot = $domainRoot.DIRECTORY_SEPARATOR.'picoradar_app'.DIRECTORY_SEPARATOR.'current';
$_SERVER['PICORADAR_PUBLIC_PATH'] = __DIR__;
putenv('PICORADAR_PUBLIC_PATH='.__DIR__);

if (file_exists($maintenance = $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'framework'.DIRECTORY_SEPARATOR.'maintenance.php')) {
    require $maintenance;
}

require $privateRoot.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';

/** @var Application $app */
$app = require_once $privateRoot.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'app.php';
$app->handleRequest(Request::capture());
