<?php

$publicRoot = (string) getenv('PICORADAR_TEST_PUBLIC_ROOT');
if ($publicRoot === '' || ! is_dir($publicRoot)) {
    http_response_code(500);
    exit('Test public root unavailable.');
}

$_SERVER['HTTPS'] = 'on';
$_SERVER['SERVER_PORT'] = 443;

$requestPath = rawurldecode((string) parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH));
$candidate = realpath($publicRoot.DIRECTORY_SEPARATOR.ltrim($requestPath, '/'));
$root = realpath($publicRoot);

if ($candidate !== false && $root !== false && str_starts_with($candidate, $root.DIRECTORY_SEPARATOR)) {
    if (is_file($candidate)) {
        if (pathinfo($candidate, PATHINFO_EXTENSION) === 'php') {
            require $candidate;

            return true;
        }

        return false;
    }
    if (is_dir($candidate) && is_file($candidate.DIRECTORY_SEPARATOR.'index.php')) {
        require $candidate.DIRECTORY_SEPARATOR.'index.php';

        return true;
    }
}

require $publicRoot.DIRECTORY_SEPARATOR.'index.php';

return true;
