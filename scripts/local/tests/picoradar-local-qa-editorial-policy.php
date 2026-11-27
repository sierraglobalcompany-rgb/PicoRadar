<?php

declare(strict_types=1);

$repo = dirname(__DIR__, 3);
$router = $repo.DIRECTORY_SEPARATOR.'scripts'.DIRECTORY_SEPARATOR.'local'.DIRECTORY_SEPARATOR.'picoradar-local-qa.php';

$cases = [
    ['default GET remains available', ['method' => 'GET', 'path' => '/admin/restrictions', 'editorial' => false], true],
    ['GET query method override is rejected', ['method' => 'GET', 'path' => '/admin/restrictions', 'editorial' => true, 'query' => ['_method' => 'POST']], false],
    ['HEAD header method override is rejected', ['method' => 'HEAD', 'path' => '/admin/restrictions', 'editorial' => true, 'server' => ['HTTP_X_HTTP_METHOD_OVERRIDE' => 'POST']], false],
    ['default login POST remains available', ['method' => 'POST', 'path' => '/login', 'editorial' => false], true],
    ['default blocks editorial POST', ['method' => 'POST', 'path' => '/admin/restrictions', 'editorial' => false], false],
    ['default blocks logout POST', ['method' => 'POST', 'path' => '/logout', 'editorial' => false], false],
    ['editorial login remains a form POST', ['method' => 'POST', 'path' => '/login', 'editorial' => true, 'content_type' => 'application/x-www-form-urlencoded'], true],
    ['editorial logout is exact', ['method' => 'POST', 'path' => '/logout', 'editorial' => true, 'content_type' => 'application/x-www-form-urlencoded'], true],
    ['editorial import route is exact multipart form', ['method' => 'POST', 'path' => '/admin/restrictions/imports', 'editorial' => true, 'content_type' => 'multipart/form-data; boundary=qa'], true],
    ['editorial confirm route requires positive decimal id', ['method' => 'POST', 'path' => '/admin/restrictions/imports/12/confirm', 'editorial' => true, 'content_type' => 'application/x-www-form-urlencoded'], true],
    ['editorial validate route is exact', ['method' => 'POST', 'path' => '/admin/restrictions/12/validate', 'editorial' => true, 'content_type' => 'application/x-www-form-urlencoded'], true],
    ['editorial approve route is exact', ['method' => 'POST', 'path' => '/admin/restrictions/12/approve-material-change', 'editorial' => true, 'content_type' => 'application/x-www-form-urlencoded'], true],
    ['editorial publish route is exact', ['method' => 'POST', 'path' => '/admin/restrictions/publish', 'editorial' => true, 'content_type' => 'application/x-www-form-urlencoded'], true],
    ['editorial create route is exact', ['method' => 'POST', 'path' => '/admin/restrictions', 'editorial' => true, 'content_type' => 'application/x-www-form-urlencoded'], true],
    ['editorial form update accepts only PUT override', [
        'method' => 'POST', 'path' => '/admin/restrictions/12', 'editorial' => true,
        'content_type' => 'application/x-www-form-urlencoded', 'post' => ['_method' => 'PUT'],
        'raw_body' => '_token=csrf&_method=PUT',
    ], true],
    ['suffix route is rejected', ['method' => 'POST', 'path' => '/admin/restrictions/12/validate/extra', 'editorial' => true], false],
    ['zero and leading-zero ids are rejected', ['method' => 'POST', 'path' => '/admin/restrictions/0/validate', 'editorial' => true], false],
    ['path traversal is rejected', ['method' => 'POST', 'path' => '/admin/restrictions/../publish', 'editorial' => true], false],
    ['encoded paths are rejected', ['method' => 'POST', 'path' => '/admin/restrictions/%2fpublish', 'editorial' => true], false],
    ['non-allowlisted POST is rejected', ['method' => 'POST', 'path' => '/admin/operators', 'editorial' => true], false],
    ['JSON form mutation is rejected', ['method' => 'POST', 'path' => '/admin/restrictions/publish', 'editorial' => true, 'content_type' => 'application/json'], false],
    ['direct PUT is rejected', ['method' => 'PUT', 'path' => '/admin/restrictions/12', 'editorial' => true], false],
    ['update without form override is rejected', ['method' => 'POST', 'path' => '/admin/restrictions/12', 'editorial' => true], false],
    ['override on a different route is rejected', [
        'method' => 'POST', 'path' => '/admin/operators/12', 'editorial' => true,
        'content_type' => 'application/x-www-form-urlencoded', 'post' => ['_method' => 'PUT'], 'raw_body' => '_method=PUT',
    ], false],
    ['non-PUT method override is rejected', [
        'method' => 'POST', 'path' => '/admin/restrictions/12', 'editorial' => true,
        'content_type' => 'application/x-www-form-urlencoded', 'post' => ['_method' => 'PATCH'], 'raw_body' => '_method=PATCH',
    ], false],
    ['query method override is rejected', [
        'method' => 'POST', 'path' => '/admin/restrictions/12', 'editorial' => true,
        'content_type' => 'application/x-www-form-urlencoded', 'post' => ['_method' => 'PUT'],
        'query' => ['_method' => 'PUT'], 'raw_body' => '_method=PUT',
    ], false],
    ['header method override is rejected', [
        'method' => 'POST', 'path' => '/admin/restrictions/12', 'editorial' => true,
        'content_type' => 'application/x-www-form-urlencoded', 'post' => ['_method' => 'PUT'],
        'server' => ['HTTP_X_HTTP_METHOD_OVERRIDE' => 'PUT'], 'raw_body' => '_method=PUT',
    ], false],
    ['JSON method override is rejected', [
        'method' => 'POST', 'path' => '/admin/restrictions/12', 'editorial' => true,
        'content_type' => 'application/json', 'post' => ['_method' => 'PUT'], 'raw_body' => '{"_method":"PUT"}',
    ], false],
    ['array method override is rejected', [
        'method' => 'POST', 'path' => '/admin/restrictions/12', 'editorial' => true,
        'content_type' => 'application/x-www-form-urlencoded', 'post' => ['_method' => ['PUT']], 'raw_body' => '_method%5B%5D=PUT',
    ], false],
    ['duplicate method override is rejected', [
        'method' => 'POST', 'path' => '/admin/restrictions/12', 'editorial' => true,
        'content_type' => 'application/x-www-form-urlencoded', 'post' => ['_method' => 'PUT'], 'raw_body' => '_method=PUT&_method=PUT',
    ], false],
];

$failures = [];
foreach ($cases as [$name, $request, $expected]) {
    $encoded = base64_encode(json_encode($request, JSON_THROW_ON_ERROR));
    $process = proc_open(
        [PHP_BINARY, $router, 'route-policy', $encoded],
        [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']],
        $pipes,
        $repo,
    );
    if (! is_resource($process)) {
        throw new RuntimeException('Unable to start the PHP CLI policy probe.');
    }
    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $exitCode = proc_close($process);
    $result = json_decode($stdout, true);
    $validResult = is_array($result) && array_key_exists('allowed', $result) && is_bool($result['allowed']);
    $actual = $validResult ? $result['allowed'] : null;
    if ($exitCode !== 0 || ! $validResult || $actual !== $expected) {
        $failures[] = sprintf('%s: expected %s, got exit=%d output=%s error=%s', $name, $expected ? 'allow' : 'block', $exitCode, trim($stdout), trim($stderr));
    }
}

if ($failures !== []) {
    fwrite(STDERR, implode(PHP_EOL, $failures).PHP_EOL);
    exit(1);
}

printf("PASS: %d editorial route-policy cases\n", count($cases));
