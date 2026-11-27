<?php

declare(strict_types=1);

$notFound = static function (): never {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Not found';
    exit;
};

$remote = (string) ($_SERVER['REMOTE_ADDR'] ?? '');
if (! in_array($remote, ['127.0.0.1', '::1'], true)) {
    $notFound();
}

$method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? ''));
$requestUri = (string) ($_SERVER['REQUEST_URI'] ?? '/');
$uri = parse_url($requestUri);
$path = is_array($uri) ? ($uri['path'] ?? null) : null;
$queryValues = [];
parse_str(is_array($uri) ? (string) ($uri['query'] ?? '') : '', $queryValues);
$overrideHeaders = ['HTTP_X_HTTP_METHOD_OVERRIDE', 'HTTP_X_METHOD_OVERRIDE', 'HTTP_X_HTTP_METHOD'];
$hasMethodOverride = array_key_exists('_method', $queryValues) || array_key_exists('_method', $_POST);
foreach ($overrideHeaders as $headerName) {
    if (isset($_SERVER[$headerName]) && (string) $_SERVER[$headerName] !== '') {
        $hasMethodOverride = true;
    }
}
if ($hasMethodOverride) {
    $notFound();
}
if (! is_string($path)
    || $path === ''
    || $path[0] !== '/'
    || str_contains($path, '%')
    || str_contains($path, '\\')
    || str_contains($path, '//')
    || preg_match('~(?:^|/)\.{1,2}(?:/|$)~', $path) === 1
    || ($path !== '/' && str_ends_with($path, '/'))
) {
    $notFound();
}

$allowed = [
    'GET' => [
        '/up',
        '/login',
        '/admin',
        '/admin/operations/national',
        '/admin/restrictions/municipalities',
        '/admin/app-users',
        '/admin/campaigns/planning',
        '/api/v1/campaign-catalog',
    ],
    'POST' => ['/login', '/logout'],
];

if (in_array($path, $allowed[$method] ?? [], true)) {
    $appRoot = getenv('PICORADAR_QA_SERVER_ROOT');
    if (! is_string($appRoot) || $appRoot === '' || is_link($appRoot)) {
        $notFound();
    }
    $candidate = $appRoot.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'index.php';
    $index = realpath($candidate);
    $expectedRoot = realpath($appRoot.DIRECTORY_SEPARATOR.'public');
    if (! is_string($index)
        || ! is_string($expectedRoot)
        || ! is_file($index)
        || is_link($candidate)
        || ! str_starts_with(strtolower($index), strtolower($expectedRoot.DIRECTORY_SEPARATOR))
    ) {
        $notFound();
    }
    $_SERVER['SCRIPT_NAME'] = '/index.php';
    $_SERVER['SCRIPT_FILENAME'] = $index;
    require $index;
    exit;
}

if ($method === 'GET'
    && preg_match('~^/build/assets/[A-Za-z0-9][A-Za-z0-9._-]*\.(?:css|js|woff2|svg|png|jpg|webp)$~', $path) === 1
) {
    $documentRoot = realpath((string) ($_SERVER['DOCUMENT_ROOT'] ?? ''));
    $asset = realpath((string) ($_SERVER['DOCUMENT_ROOT'] ?? '').$path);
    if (! is_string($documentRoot)
        || ! is_string($asset)
        || ! is_file($asset)
        || is_link((string) ($_SERVER['DOCUMENT_ROOT'] ?? '').$path)
        || ! str_starts_with(strtolower($asset), strtolower($documentRoot.DIRECTORY_SEPARATOR))
    ) {
        $notFound();
    }
    return false;
}

$notFound();
