<?php
declare(strict_types=1);

use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

$repo = dirname(__DIR__, 3);
$server = $repo.DIRECTORY_SEPARATOR.'server';
chdir($server);
require $server.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';
$app = require $server.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'app.php';
$app->make(Kernel::class)->bootstrap();

$requireValue = static function (bool $condition, string $code): void {
    if (! $condition) {
        throw new \RuntimeException($code);
    }
};

$expectedDatabase = (string) getenv('PICORADAR_C32_EXPECTED_DB');
$expectedDatadir = (string) getenv('PICORADAR_C32_EXPECTED_DATADIR');
$expectedStorage = (string) getenv('PICORADAR_C32_EXPECTED_STORAGE');
$expectedCacheRoot = (string) getenv('PICORADAR_C32_EXPECTED_CACHE');
$database = config('database.connections.mariadb');
$requireValue(getenv('APP_ENV') === 'local' && getenv('APP_DEBUG') === 'false', 'BLOCKED_APP_ENV');
$requireValue(config('database.default') === 'mariadb' && is_array($database), 'BLOCKED_DB_CONNECTION');
$requireValue(($database['host'] ?? null) === '127.0.0.1' && (int) ($database['port'] ?? 0) > 1024 && (int) $database['port'] !== 3306, 'BLOCKED_DB_ENDPOINT');
$requireValue(($database['database'] ?? null) === $expectedDatabase && str_starts_with($expectedDatabase, 'picoradar_c32_qa_'), 'BLOCKED_DB_NAME');
$requireValue(($database['username'] ?? null) !== '' && str_starts_with((string) $database['username'], 'picoradar_c32_'), 'BLOCKED_DB_USER');
$requireValue(($database['unix_socket'] ?? '') === '' && getenv('DB_SOCKET') === '', 'BLOCKED_DB_SOCKET');
$normalizePath = static fn (string $path): string => strtolower(rtrim(str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $path), DIRECTORY_SEPARATOR));
$requireValue($normalizePath($app->storagePath()) === $normalizePath($expectedStorage), 'BLOCKED_STORAGE_PATH');

$canonicalFile = static function (string $path) use ($normalizePath): string {
    $directory = realpath(dirname($path));
    return $normalizePath(($directory === false ? dirname($path) : $directory).DIRECTORY_SEPARATOR.basename($path));
};
$expectedCacheFiles = [
    'config' => $expectedCacheRoot.DIRECTORY_SEPARATOR.'config.php',
    'routes' => $expectedCacheRoot.DIRECTORY_SEPARATOR.'routes-v7.php',
    'events' => $expectedCacheRoot.DIRECTORY_SEPARATOR.'events.php',
    'packages' => $expectedCacheRoot.DIRECTORY_SEPARATOR.'packages.php',
    'services' => $expectedCacheRoot.DIRECTORY_SEPARATOR.'services.php',
];
$actualCacheFiles = [
    'config' => $app->getCachedConfigPath(),
    'routes' => $app->getCachedRoutesPath(),
    'events' => $app->getCachedEventsPath(),
    'packages' => $app->getCachedPackagesPath(),
    'services' => $app->getCachedServicesPath(),
];
foreach ($expectedCacheFiles as $name => $path) {
    $requireValue($canonicalFile($actualCacheFiles[$name]) === $canonicalFile($path), 'BLOCKED_CACHE_PATH');
}

$pdo = DB::connection('mariadb')->getPdo();
$identity = $pdo->query('SELECT DATABASE() AS db, @@port AS port, @@datadir AS datadir, CURRENT_USER() AS account')->fetch(PDO::FETCH_ASSOC);
$expectedAccount = (string) $database['username'].'@127.0.0.1';
$requireValue(($identity['db'] ?? null) === $expectedDatabase, 'BLOCKED_ACTUAL_DB');
$requireValue((int) ($identity['port'] ?? 0) === (int) $database['port'], 'BLOCKED_ACTUAL_PORT');
$requireValue(($identity['account'] ?? null) === $expectedAccount, 'BLOCKED_ACTUAL_ACCOUNT');
$requireValue($normalizePath((string) ($identity['datadir'] ?? '')) === $normalizePath($expectedDatadir), 'BLOCKED_ACTUAL_DATADIR');
$requireValue(Schema::hasColumn('datasets', 'publication_revision'), 'BLOCKED_SCHEMA2_COLUMN');
$requireValue(DB::table('migrations')->count() === 26, 'BLOCKED_MIGRATION_COUNT');

$result = DB::transaction(static function () use ($requireValue): array {
    $dataset = Dataset::query()->where('key', 'restrictions')->lockForUpdate()->first();

    if ($dataset !== null) {
        $matches = $dataset->title === 'Restricciones'
            && (int) $dataset->schema_version === 2
            && $dataset->enabled === false
            && $dataset->current_version === null
            && (int) $dataset->publication_revision === 0;
        $requireValue($matches, 'BLOCKED_EXISTING_DATASET_MISMATCH');
        $status = 'EXISTING_EXACT';
    } else {
        $requireValue(DatasetRelease::query()->count() === 0, 'BLOCKED_RELEASES_PRESENT');
        $requireValue(RestrictionRuleVersion::query()->count() === 0, 'BLOCKED_RULES_PRESENT');
        $requireValue(RestrictionPublication::query()->count() === 0, 'BLOCKED_PUBLICATIONS_PRESENT');
        $dataset = Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Restricciones',
            'schema_version' => 2,
            'enabled' => false,
            'current_version' => null,
            'publication_revision' => 0,
        ]);
        $status = 'CREATED';
    }

    $requireValue(DatasetRelease::query()->count() === 0, 'BLOCKED_RELEASES_AFTER');
    $requireValue(RestrictionRuleVersion::query()->count() === 0, 'BLOCKED_RULES_AFTER');
    $requireValue(RestrictionPublication::query()->count() === 0, 'BLOCKED_PUBLICATIONS_AFTER');

    return ['status' => $status, 'dataset_id' => (int) $dataset->id];
});

$verified = Dataset::query()->where('key', 'restrictions')->firstOrFail();
$requireValue($verified->title === 'Restricciones'
    && (int) $verified->schema_version === 2
    && $verified->enabled === false
    && $verified->current_version === null
    && (int) $verified->publication_revision === 0, 'BLOCKED_POST_VERIFY');

echo json_encode([
    'gate' => 'B_SCHEMA2_READY',
    'status' => $result['status'],
    'database' => $expectedDatabase,
    'dataset_id' => $result['dataset_id'],
    'key' => $verified->key,
    'title' => $verified->title,
    'schema_version' => (int) $verified->schema_version,
    'enabled' => (bool) $verified->enabled,
    'current_version' => $verified->current_version,
    'publication_revision' => (int) $verified->publication_revision,
    'releases' => DatasetRelease::query()->count(),
    'rules' => RestrictionRuleVersion::query()->count(),
    'publications' => RestrictionPublication::query()->count(),
], JSON_THROW_ON_ERROR).PHP_EOL;