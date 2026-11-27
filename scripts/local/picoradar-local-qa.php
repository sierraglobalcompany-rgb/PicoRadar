<?php

declare(strict_types=1);

use App\Enums\CampaignScope;
use App\Enums\CampaignStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\JurisdictionKind;
use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
use App\Enums\SponsorStatus;
use App\Models\AppUser;
use App\Models\Campaign;
use App\Models\Dataset;
use App\Models\DatasetSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Models\Sponsor;
use App\Models\User;
use App\Services\AppAccountAdministrationService;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

$repo = dirname(__DIR__, 2);
$server = $repo.DIRECTORY_SEPARATOR.'server';
$runtime = getenv('PICORADAR_INSTANCE_ROOT') ?: '';
$action = $argv[1] ?? '';

function c30Fail(string $reason): never
{
    fwrite(STDERR, "C30_BLOCKED={$reason}\n");
    exit(2);
}

function c30SamePath(string $left, string $right): bool
{
    $normalize = static fn (string $path): string => strtolower(rtrim(str_replace('/', DIRECTORY_SEPARATOR, $path), DIRECTORY_SEPARATOR));

    return $normalize($left) === $normalize($right);
}

function c30Within(string $path, string $root): bool
{
    $path = strtolower(rtrim(str_replace('/', DIRECTORY_SEPARATOR, $path), DIRECTORY_SEPARATOR));
    $root = strtolower(rtrim(str_replace('/', DIRECTORY_SEPARATOR, $root), DIRECTORY_SEPARATOR));

    return $path === $root || str_starts_with($path, $root.DIRECTORY_SEPARATOR);
}

function c30SafeRequestPath(string $path): bool
{
    return $path !== '' && ! str_contains($path, '%') && ! str_contains($path, '\\') && ! str_contains($path, "\0")
        && ! str_contains($path, '//') && preg_match('~(?:^|/)\.{1,2}(?:/|$)~', $path) !== 1
        && preg_match('~(^|/)\.[^/]*~', $path) !== 1;
}

function c31HasMethodOverrideKey(array $values): bool
{
    foreach (array_keys($values) as $key) {
        if ($key === '_method' || (is_string($key) && str_starts_with($key, '_method['))) {
            return true;
        }
    }

    return false;
}

function c31IsEditorialFormContentType(string $contentType): bool
{
    return in_array(strtolower(trim(explode(';', $contentType, 2)[0])), [
        'application/x-www-form-urlencoded', 'multipart/form-data',
    ], true);
}

function c31HasOnlyPutFormOverride(array $post, array $query, array $server, string $contentType, string $rawBody): bool
{
    if (c31HasMethodOverrideKey($query) || array_key_exists('HTTP_X_HTTP_METHOD_OVERRIDE', $server)) {
        return false;
    }
    if (! array_key_exists('_method', $post) || ! is_string($post['_method']) || $post['_method'] !== 'PUT') {
        return false;
    }
    if (strtolower(trim(explode(';', $contentType, 2)[0])) !== 'application/x-www-form-urlencoded') {
        return false;
    }

    $matches = 0;
    $bodyMethod = null;
    foreach (preg_split('/[&;]/', $rawBody) ?: [] as $pair) {
        [$key, $value] = array_pad(explode('=', $pair, 2), 2, '');
        $decodedKey = urldecode($key);
        if ($decodedKey === '_method' || str_starts_with($decodedKey, '_method[')) {
            $matches++;
            if ($decodedKey === '_method') {
                $bodyMethod = urldecode($value);
            }
        }
    }

    return $matches === 1 && $bodyMethod === 'PUT';
}

function c30RouteMethodAllowed(
    string $method,
    string $path,
    bool $editorial,
    array $post = [],
    array $query = [],
    array $server = [],
    string $contentType = '',
    string $rawBody = '',
): bool {
    $method = strtoupper($method);
    if (! c30SafeRequestPath($path)) {
        return false;
    }
    if ($method === 'GET' || $method === 'HEAD') {
        return ! c31HasMethodOverrideKey($post) && ! c31HasMethodOverrideKey($query)
            && ! array_key_exists('HTTP_X_HTTP_METHOD_OVERRIDE', $server);
    }
    if ($method !== 'POST') {
        return false;
    }

    $hasOverride = c31HasMethodOverrideKey($post) || c31HasMethodOverrideKey($query)
        || array_key_exists('HTTP_X_HTTP_METHOD_OVERRIDE', $server);
    if ($path === '/login') {
        return ! $hasOverride && (! $editorial || c31IsEditorialFormContentType($contentType));
    }
    if (! $editorial) {
        return false;
    }
    if ($hasOverride) {
        return preg_match('~^/admin/restrictions/[1-9][0-9]*$~D', $path) === 1
            && c31HasOnlyPutFormOverride($post, $query, $server, $contentType, $rawBody);
    }

    $allowed = $path === '/logout'
        || $path === '/admin/restrictions/imports'
        || preg_match('~^/admin/restrictions/imports/[1-9][0-9]*/confirm$~D', $path) === 1
        || preg_match('~^/admin/restrictions/[1-9][0-9]*/(?:validate|approve-material-change)$~D', $path) === 1
        || $path === '/admin/restrictions/publish'
        || $path === '/admin/restrictions';

    return $allowed && c31IsEditorialFormContentType($contentType);
}

function c31EditorialMarker(string $runtime, string $instanceId): ?array
{
    if (getenv('PICORADAR_EDITORIAL_QA') !== '1') {
        return null;
    }
    $instance = json_decode((string) @file_get_contents($runtime.DIRECTORY_SEPARATOR.'instance.json'), true);
    $markerPath = $runtime.DIRECTORY_SEPARATOR.'runtime'.DIRECTORY_SEPARATOR.'editorial-qa.json';
    if (is_link($markerPath)) {
        return null;
    }
    $marker = json_decode((string) @file_get_contents($markerPath), true);
    $expectedId = getenv('PICORADAR_EDITORIAL_EXPECTED_INSTANCE_ID') ?: '';
    $entryMode = getenv('PICORADAR_EDITORIAL_ENTRY_MODE') ?: '';
    if (! is_array($instance) || ! is_array($marker)
        || ($instance['format'] ?? null) !== 'picoradar-local-qa/1'
        || ($instance['backend'] ?? null) !== 'sqlite' || ($instance['state'] ?? null) !== 'initialized'
        || ($instance['scope'] ?? null) !== 'NON_PRODUCTION_SYNTHETIC'
        || ($instance['id'] ?? null) !== $instanceId || $expectedId === '' || $expectedId !== $instanceId
        || ! in_array($entryMode, ['RESTORED', 'FRESH_ISOLATED'], true)
        || ($marker['format'] ?? null) !== 'picoradar-editorial-qa/1'
        || ($marker['scope'] ?? null) !== 'NON_PRODUCTION_SYNTHETIC'
        || ($marker['prepared'] ?? null) !== true || ($marker['instance_id'] ?? null) !== $instanceId
        || ($marker['entry_mode'] ?? null) !== $entryMode) {
        return null;
    }

    return $marker;
}

function c31VerifyEditorialState(array $marker, string $instanceId, string $entryMode): array
{
    if (($marker['format'] ?? null) !== 'picoradar-editorial-qa/1'
        || ($marker['scope'] ?? null) !== 'NON_PRODUCTION_SYNTHETIC'
        || ($marker['prepared'] ?? null) !== true
        || ($marker['instance_id'] ?? null) !== $instanceId
        || ($marker['entry_mode'] ?? null) !== $entryMode) {
        c30Fail('EDITORIAL_MARKER_MISMATCH');
    }

    $country = GeographicUnit::query()->where('key', 'c31-synthetic-country')->first();
    $department = GeographicUnit::query()->where('key', 'c31-synthetic-department')->first();
    $municipality = GeographicUnit::query()->where('key', 'c31-synthetic-municipality')->first();
    $jurisdiction = Jurisdiction::query()->where('key', 'c31-synthetic-off')->first();
    $dataset = Dataset::query()->where('key', 'restrictions')->first();
    $editor = User::query()->where('email', 'editor-c31@picoradar.test')->first();
    $superAdmin = User::query()->where('email', 'superadmin@picoradar.test')->first();
    $source = DatasetSource::query()
        ->where('dataset_id', $dataset?->id)
        ->where('title', 'C31 synthetic source')
        ->where('url', 'https://example.test/c31-synthetic-restrictions')
        ->first();

    $geographyMatches = $country !== null && $country->code === 'CO' && $country->level === GeographicUnitLevel::Country
        && $country->parent_id === null && $country->name === 'C31 Synthetic Country'
        && $country->normalized_name === 'c31 synthetic country' && $country->is_active
        && $country->source_system === 'c31-qa-synthetic' && $country->source_version === '1'
        && $department !== null && $department->code === '99' && $department->level === GeographicUnitLevel::Department
        && (int) $department->parent_id === (int) $country->id && $department->name === 'C31 Synthetic Department'
        && $department->normalized_name === 'c31 synthetic department' && $department->is_active
        && $department->source_system === 'c31-qa-synthetic' && $department->source_version === '1'
        && $municipality !== null && $municipality->code === '99999' && $municipality->level === GeographicUnitLevel::Municipality
        && (int) $municipality->parent_id === (int) $department->id && $municipality->name === 'C31 Synthetic Municipality'
        && $municipality->normalized_name === 'c31 synthetic municipality' && $municipality->is_active
        && $municipality->source_system === 'c31-qa-synthetic' && $municipality->source_version === '1';
    $jurisdictionMatches = $jurisdiction !== null && $jurisdiction->name === 'C31 Synthetic Jurisdiction OFF'
        && $jurisdiction->kind === JurisdictionKind::City && (int) $jurisdiction->primary_geographic_unit_id === (int) $municipality?->id
        && ! $jurisdiction->enabled && $jurisdiction->timezone === 'America/Bogota'
        && $municipality !== null && $municipality->jurisdictions()->whereKey($jurisdiction->id)->exists();
    $datasetMatches = $dataset !== null && $dataset->schema_version === 2 && $dataset->enabled
        && $dataset->current_version === null && (int) $dataset->publication_revision === 0
        && $dataset->releases()->count() === 0;
    $sourceMatches = $source !== null && $source->authority === 'C31 synthetic authority' && $source->is_active
        && (int) $source->dataset_id === (int) $dataset?->id
        && $source->verified_at !== null && ! $source->verified_at->isFuture()
        && DatasetSource::query()->where('dataset_id', $dataset?->id)->where('title', 'C31 synthetic source')
            ->where('url', 'https://example.test/c31-synthetic-restrictions')->count() === 1;
    $editorMatches = $editor !== null && $editor->role === OperatorRole::Editor && $editor->is_active
        && Hash::check((string) (getenv('PICORADAR_EDITOR_PASSWORD') ?: ''), (string) $editor->password);
    $superAdminMatches = $superAdmin !== null && $superAdmin->role === OperatorRole::SuperAdmin && $superAdmin->is_active;
    $releaseCount = $dataset?->releases()->count() ?? 0;
    $publicationCount = $dataset === null ? 0 : RestrictionPublication::query()
        ->whereHas('datasetRelease', static fn ($query) => $query->where('dataset_id', $dataset->id))->count();
    $ruleCount = $jurisdiction?->restrictionRuleVersions()->count() ?? 0;

    if (! $geographyMatches || ! $jurisdictionMatches || ! $datasetMatches || ! $sourceMatches
        || ! $editorMatches || ! $superAdminMatches || $publicationCount !== 0 || $ruleCount !== 0
        || (int) ($marker['dataset_id'] ?? 0) !== (int) $dataset?->id
        || (int) ($marker['country_id'] ?? 0) !== (int) $country?->id
        || (int) ($marker['department_id'] ?? 0) !== (int) $department?->id
        || (int) ($marker['jurisdiction_id'] ?? 0) !== (int) $jurisdiction?->id
        || (int) ($marker['municipality_id'] ?? 0) !== (int) $municipality?->id
        || (int) ($marker['editor_id'] ?? 0) !== (int) $editor?->id
        || (int) ($marker['source_id'] ?? 0) !== (int) $source?->id) {
        c30Fail('EDITORIAL_PREPARED_STATE_MISMATCH');
    }

    return [
        'status' => 'PASS', 'prepared' => true, 'idempotent' => true,
        'instance_id' => $instanceId, 'entry_mode' => $entryMode,
        'dataset_id' => (int) $dataset->id, 'schema_version' => 2, 'dataset_enabled' => true,
        'current_version' => null, 'publication_revision' => 0,
        'country_code' => 'CO', 'department_code' => '99', 'municipality_code' => '99999',
        'municipality_id' => (int) $municipality->id, 'jurisdiction_id' => (int) $jurisdiction->id,
        'jurisdiction_enabled' => false, 'editor_id' => (int) $editor->id, 'source_id' => (int) $source->id,
        'release_count' => $releaseCount, 'publication_count' => $publicationCount, 'rule_count' => $ruleCount,
    ];
}

function c31PrepareEditorial(string $runtime, string $expectedId, string $password, string $entryMode): array
{
    $runtimeRoot = realpath($runtime);
    $instancePath = $runtime.DIRECTORY_SEPARATOR.'instance.json';
    $instance = json_decode((string) @file_get_contents($instancePath), true);
    $instanceId = (string) (getenv('PICORADAR_INSTANCE_ID') ?: '');
    if (! is_string($runtimeRoot) || is_link($runtime) || ! is_array($instance)
        || ! preg_match('/^[0-9a-f]{8}-[0-9a-f-]{27}$/i', $expectedId)
        || $expectedId === '' || $instanceId !== $expectedId || ($instance['id'] ?? null) !== $expectedId
        || ($instance['format'] ?? null) !== 'picoradar-local-qa/1'
        || ($instance['backend'] ?? null) !== 'sqlite' || ($instance['state'] ?? null) !== 'initialized'
        || ($instance['scope'] ?? null) !== 'NON_PRODUCTION_SYNTHETIC'
        || getenv('PICORADAR_EDITORIAL_QA') !== '0'
        || ! in_array($entryMode, ['RESTORED', 'FRESH_ISOLATED'], true)
        || strlen($password) < 32) {
        c30Fail('EDITORIAL_IDENTITY_OR_INPUT_INVALID');
    }

    $markerPath = $runtimeRoot.DIRECTORY_SEPARATOR.'runtime'.DIRECTORY_SEPARATOR.'editorial-qa.json';
    if (is_link($markerPath)) {
        c30Fail('EDITORIAL_MARKER_REPARSE_POINT');
    }
    if (is_file($markerPath)) {
        $marker = json_decode((string) file_get_contents($markerPath), true);
        if (! is_array($marker)) {
            c30Fail('EDITORIAL_MARKER_INVALID');
        }

        return c31VerifyEditorialState($marker, $expectedId, $entryMode);
    }
    if (file_exists($markerPath)) {
        c30Fail('EDITORIAL_MARKER_PATH_INVALID');
    }

    if (! Schema::hasColumn('datasets', 'publication_revision')
        || ! Schema::hasTable('users') || ! Schema::hasTable('datasets') || ! Schema::hasTable('sources')
        || ! Schema::hasTable('geographic_units') || ! Schema::hasTable('jurisdictions')
        || ! Schema::hasTable('jurisdiction_geographic_unit') || ! Schema::hasTable('dataset_releases')
        || ! Schema::hasTable('restriction_rule_versions') || ! Schema::hasTable('restriction_publications')) {
        c30Fail('EDITORIAL_REQUIRED_SCHEMA_MISSING');
    }
    $existingEditor = User::query()->where('email', 'editor-c31@picoradar.test')->exists();
    $existingC31Geography = GeographicUnit::query()->whereIn('key', [
        'c31-synthetic-country', 'c31-synthetic-department', 'c31-synthetic-municipality',
    ])->orWhereIn('code', ['CO', '99', '99999'])->orWhereIn('normalized_name', [
        'c31 synthetic country', 'c31 synthetic department', 'c31 synthetic municipality',
    ])->exists();
    $existingJurisdiction = Jurisdiction::query()->where('key', 'c31-synthetic-off')->exists();
    $existingSource = DatasetSource::query()->where('title', 'C31 synthetic source')
        ->orWhere('url', 'https://example.test/c31-synthetic-restrictions')->exists();
    if ($existingEditor || $existingC31Geography || $existingJurisdiction || $existingSource) {
        c30Fail('EDITORIAL_PARTIAL_STATE_WITHOUT_MARKER');
    }

    $superAdmin = User::query()->where('email', 'superadmin@picoradar.test')->first();
    if ($superAdmin === null || $superAdmin->role !== OperatorRole::SuperAdmin || ! $superAdmin->is_active) {
        c30Fail('EDITORIAL_SUPERADMIN_PRECONDITION');
    }

    $dataset = Dataset::query()->where('key', 'restrictions')->first();
    if ($dataset !== null && ($dataset->schema_version !== 2 || $dataset->current_version !== null
        || (int) $dataset->publication_revision !== 0 || $dataset->releases()->exists()
        || RestrictionPublication::query()->whereHas('datasetRelease', static fn ($query) => $query->where('dataset_id', $dataset->id))->exists())) {
        c30Fail('EDITORIAL_DATASET_NOT_EMPTY_SCHEMA2_OFF');
    }

    try {
        $created = DB::transaction(static function () use ($password, $dataset): array {
            if (GeographicUnit::query()->whereIn('key', [
                'c31-synthetic-country', 'c31-synthetic-department', 'c31-synthetic-municipality',
            ])->orWhereIn('code', ['CO', '99', '99999'])->orWhereIn('normalized_name', [
                'c31 synthetic country', 'c31 synthetic department', 'c31 synthetic municipality',
            ])->lockForUpdate()->exists()
                || Jurisdiction::query()->where('key', 'c31-synthetic-off')->lockForUpdate()->exists()
                || User::query()->where('email', 'editor-c31@picoradar.test')->lockForUpdate()->exists()
                || DatasetSource::query()->where('title', 'C31 synthetic source')
                    ->orWhere('url', 'https://example.test/c31-synthetic-restrictions')->lockForUpdate()->exists()) {
                throw new RuntimeException('EDITORIAL_SYNTHETIC_IDENTITY_COLLISION');
            }

            $lockedDataset = Dataset::query()->where('key', 'restrictions')->lockForUpdate()->first();
            if (($dataset?->id ?? null) !== ($lockedDataset?->id ?? null)
                || ($lockedDataset !== null && ($lockedDataset->schema_version !== 2 || $lockedDataset->current_version !== null
                    || (int) $lockedDataset->publication_revision !== 0 || $lockedDataset->releases()->exists()
                    || RestrictionPublication::query()->whereHas('datasetRelease', static fn ($query) => $query->where('dataset_id', $lockedDataset->id))->exists()))) {
                throw new RuntimeException('EDITORIAL_DATASET_STATE_CHANGED');
            }

            $country = GeographicUnit::query()->create([
                'key' => 'c31-synthetic-country', 'level' => GeographicUnitLevel::Country, 'code' => 'CO',
                'name' => 'C31 Synthetic Country', 'normalized_name' => 'c31 synthetic country',
                'is_active' => true, 'source_system' => 'c31-qa-synthetic', 'source_version' => '1',
            ]);
            $department = GeographicUnit::query()->create([
                'parent_id' => $country->id, 'key' => 'c31-synthetic-department',
                'level' => GeographicUnitLevel::Department, 'code' => '99',
                'name' => 'C31 Synthetic Department', 'normalized_name' => 'c31 synthetic department',
                'is_active' => true, 'source_system' => 'c31-qa-synthetic', 'source_version' => '1',
            ]);
            $municipality = GeographicUnit::query()->create([
                'parent_id' => $department->id, 'key' => 'c31-synthetic-municipality',
                'level' => GeographicUnitLevel::Municipality, 'code' => '99999',
                'name' => 'C31 Synthetic Municipality', 'normalized_name' => 'c31 synthetic municipality',
                'is_active' => true, 'source_system' => 'c31-qa-synthetic', 'source_version' => '1',
            ]);
            $jurisdiction = Jurisdiction::query()->create([
                'key' => 'c31-synthetic-off', 'name' => 'C31 Synthetic Jurisdiction OFF',
                'kind' => JurisdictionKind::City, 'primary_geographic_unit_id' => $municipality->id,
                'enabled' => false, 'timezone' => 'America/Bogota',
            ]);
            $municipality->jurisdictions()->attach($jurisdiction->id);

            $currentDataset = $lockedDataset ?? Dataset::query()->create([
                'key' => 'restrictions', 'title' => 'Pico y placa restrictions', 'schema_version' => 2,
                'enabled' => true, 'current_version' => null, 'publication_revision' => 0,
            ]);
            if ($lockedDataset !== null && ! $lockedDataset->enabled) {
                $lockedDataset->forceFill(['enabled' => true])->save();
                $currentDataset = $lockedDataset->refresh();
            }
            $source = DatasetSource::query()->create([
                'dataset_id' => $currentDataset->id, 'title' => 'C31 synthetic source',
                'authority' => 'C31 synthetic authority', 'url' => 'https://example.test/c31-synthetic-restrictions',
                'verified_at' => Carbon::now('America/Bogota')->subDay(), 'is_active' => true,
                'notes' => 'Synthetic QA source; never fetch or treat as legal authority.',
            ]);
            $editor = User::query()->create([
                'name' => 'C31 Synthetic Editor', 'email' => 'editor-c31@picoradar.test',
                'password' => Hash::make($password), 'role' => OperatorRole::Editor, 'is_active' => true,
            ]);

            return [
                'dataset_id' => (int) $currentDataset->id, 'country_id' => (int) $country->id,
                'department_id' => (int) $department->id, 'municipality_id' => (int) $municipality->id,
                'jurisdiction_id' => (int) $jurisdiction->id, 'editor_id' => (int) $editor->id,
                'source_id' => (int) $source->id,
            ];
        }, 1);
    } catch (Throwable $exception) {
        c30Fail('EDITORIAL_TRANSACTION_'.$exception::class);
    }

    $marker = [
        'format' => 'picoradar-editorial-qa/1', 'scope' => 'NON_PRODUCTION_SYNTHETIC',
        'prepared' => true, 'instance_id' => $expectedId, 'entry_mode' => $entryMode,
        'dataset_id' => $created['dataset_id'], 'country_id' => $created['country_id'],
        'department_id' => $created['department_id'], 'municipality_id' => $created['municipality_id'],
        'jurisdiction_id' => $created['jurisdiction_id'], 'editor_id' => $created['editor_id'],
        'source_id' => $created['source_id'], 'created_at_utc' => Carbon::now('UTC')->toIso8601String(),
    ];
    $verified = c31VerifyEditorialState($marker, $expectedId, $entryMode);
    $handle = @fopen($markerPath, 'x');
    if (! is_resource($handle)) {
        c30Fail('EDITORIAL_MARKER_CREATE_FAILED_AFTER_COMMIT');
    }
    try {
        $json = json_encode($marker, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR).PHP_EOL;
        if (fwrite($handle, $json) !== strlen($json) || ! fflush($handle)) {
            c30Fail('EDITORIAL_MARKER_WRITE_FAILED_AFTER_COMMIT');
        }
    } finally {
        fclose($handle);
    }

    return array_replace($verified, ['idempotent' => false]);
}

function c30Boot(string $server): \Illuminate\Foundation\Application
{
    if (! is_file($server.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php')) {
        c30Fail('CANDIDATE_VENDOR_MISSING');
    }
    if (file_exists($server.DIRECTORY_SEPARATOR.'.env') || file_exists($server.DIRECTORY_SEPARATOR.'.env.testing')) {
        c30Fail('CANDIDATE_ENV_FILE_FORBIDDEN');
    }

    require_once $server.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';
    $app = require $server.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'app.php';
    $app->make(Kernel::class)->bootstrap();

    return $app;
}

function c30Preflight(\Illuminate\Foundation\Application $app, string $server, string $runtime, bool $readDatabase = true, bool $requireAbsentDatabase = false): array
{
    $instance = realpath($runtime);
    $expectedStorage = realpath($runtime.DIRECTORY_SEPARATOR.'storage');
    $expectedPublic = realpath($server.DIRECTORY_SEPARATOR.'public');
    $database = $runtime.DIRECTORY_SEPARATOR.'data'.DIRECTORY_SEPARATOR.'picoradar.sqlite';
    $instanceCache = $runtime.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'cache';
    if (! is_string($instance) || ! is_string($expectedStorage) || ! is_string($expectedPublic)) {
        c30Fail('ROOTS_NOT_CANONICAL');
    }
    if (! c30SamePath($app->basePath(), $server) || ! c30SamePath($app->storagePath(), $expectedStorage) || ! c30SamePath($app->publicPath(), $expectedPublic)) {
        c30Fail('LARAVEL_ROOT_SCOPE_MISMATCH');
    }
    if ($app->environment() !== 'local' || config('app.debug') !== false || config('database.default') !== 'sqlite') {
        c30Fail('RUNTIME_CONFIG_MISMATCH');
    }
    if (trim((string) config('database.connections.sqlite.url')) !== '' || ! c30SamePath((string) config('database.connections.sqlite.database'), $database)) {
        c30Fail('DATABASE_CONFIG_SCOPE_MISMATCH');
    }
    if (config('mail.default') !== 'array' || config('queue.default') !== 'sync' || config('session.driver') !== 'file' || config('cache.default') !== 'file' || config('filesystems.default') !== 'local') {
        c30Fail('SIDE_EFFECT_CONFIG_MISMATCH');
    }
    if (config('campaigns.public_catalog_enabled') !== false || getenv('PICORADAR_ACCOUNT_EMAIL_ENABLED') !== 'false' || getenv('PICORADAR_MARKETING_SEND_ENABLED') !== 'false') {
        c30Fail('PUBLIC_OR_EXTERNAL_FEATURE_NOT_OFF');
    }

    $paths = [
        'config_cache' => $app->getCachedConfigPath(),
        'routes_cache' => $app->getCachedRoutesPath(),
        'events_cache' => $app->getCachedEventsPath(),
        'packages_cache' => $app->getCachedPackagesPath(),
        'services_cache' => $app->getCachedServicesPath(),
        'sessions' => (string) config('session.files'),
        'cache' => (string) config('cache.stores.file.path'),
        'views' => (string) config('view.compiled'),
        'logs' => (string) config('logging.channels.single.path'),
        'private_disk' => (string) config('filesystems.disks.local.root'),
        'public_disk' => (string) config('filesystems.disks.public.root'),
    ];
    foreach ($paths as $name => $path) {
        $resolved = realpath($path);
        if ($resolved === false && is_dir(dirname($path))) {
            $resolved = realpath(dirname($path)).DIRECTORY_SEPARATOR.basename($path);
        }
        if (! is_string($resolved) || ! c30Within($resolved, $name === 'config_cache' || str_ends_with($name, '_cache') ? $instanceCache : $expectedStorage)) {
            c30Fail('WRITE_PATH_SCOPE_MISMATCH_'.$name);
        }
        $paths[$name] = $resolved;
    }
    $mainFile = null;
    if ($readDatabase) {
        if (! is_file($database) || is_link($database)) {
            c30Fail('DATABASE_FILE_NOT_INITIALIZED_OR_LINK');
        }
        $pdo = new PDO('sqlite:file:'.str_replace('\\', '/', $database).'?mode=ro');
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $databaseList = $pdo->query('PRAGMA database_list')->fetchAll(PDO::FETCH_ASSOC);
        $main = array_values(array_filter($databaseList, static fn (array $row): bool => ($row['name'] ?? '') === 'main'))[0] ?? null;
        if (! is_array($main) || ! c30SamePath((string) ($main['file'] ?? ''), $database)) {
            c30Fail('PDO_DATABASE_LIST_SCOPE_MISMATCH');
        }
        $pdo->query('PRAGMA query_only = ON');
        $mainFile = (string) $main['file'];
        $tableCount = (int) $pdo->query("SELECT count(*) FROM sqlite_master WHERE type='table'")->fetchColumn();
    } elseif ($requireAbsentDatabase && (file_exists($database) || is_link($database))) {
        c30Fail('DATABASE_ALREADY_EXISTS_BEFORE_SCOPE_PREFLIGHT');
    } else {
        $tableCount = null;
    }

    return [
        'base_path' => $app->basePath(),
        'storage_path' => $app->storagePath(),
        'public_path' => $app->publicPath(),
        'database' => $database,
        'pdo_main' => $mainFile,
        'sqlite_table_count' => $tableCount,
        'paths' => $paths,
        'config' => [
            'environment' => $app->environment(),
            'debug' => config('app.debug'),
            'database' => config('database.default'),
            'mail' => config('mail.default'),
            'queue' => config('queue.default'),
            'session' => config('session.driver'),
            'cache' => config('cache.default'),
            'filesystem' => config('filesystems.default'),
            'campaign_catalog' => config('campaigns.public_catalog_enabled'),
        ],
    ];
}

function c30Seed(): array
{
    $password = getenv('PICORADAR_OPERATOR_PASSWORD') ?: '';
    if (strlen($password) < 32) {
        c30Fail('OPERATOR_PASSWORD_NOT_AVAILABLE');
    }
    foreach (['users', 'geographic_units', 'jurisdictions', 'datasets', 'restriction_rule_versions', 'app_users', 'sponsors', 'campaigns'] as $table) {
        if (! Schema::hasTable($table) || DB::table($table)->count() !== 0) {
            c30Fail('SEED_TABLE_NOT_EMPTY_OR_MISSING_'.$table);
        }
    }

    $operator = DB::transaction(static fn (): User => User::query()->create([
        'name' => 'C30 Synthetic SuperAdmin',
        'email' => 'superadmin@picoradar.test',
        'password' => Hash::make($password),
        'role' => OperatorRole::SuperAdmin,
        'is_active' => true,
    ]));

    [$country, $department, $municipality, $jurisdiction, $dataset, $draft] = DB::transaction(static function () use ($operator): array {
        $country = GeographicUnit::query()->create([
            'key' => 'c30-synthetic-country', 'level' => GeographicUnitLevel::Country,
            'code' => 'C30', 'name' => 'Synthetic C30 country', 'normalized_name' => 'synthetic c30 country',
            'is_active' => true, 'source_system' => 'c30-qa-synthetic', 'source_version' => '1',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'c30-synthetic-department', 'level' => GeographicUnitLevel::Department,
            'code' => 'C30D', 'name' => 'Synthetic C30 department', 'normalized_name' => 'synthetic c30 department',
            'is_active' => true, 'source_system' => 'c30-qa-synthetic', 'source_version' => '1',
        ]);
        $municipality = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'c30-synthetic-municipality', 'level' => GeographicUnitLevel::Municipality,
            'code' => 'C30M', 'name' => 'Synthetic C30 municipality', 'normalized_name' => 'synthetic c30 municipality',
            'is_active' => true, 'source_system' => 'c30-qa-synthetic', 'source_version' => '1',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'c30-synthetic-off', 'name' => 'Synthetic C30 jurisdiction OFF',
            'kind' => JurisdictionKind::City, 'primary_geographic_unit_id' => $municipality->id,
            'enabled' => false, 'timezone' => 'America/Bogota',
        ]);
        $municipality->jurisdictions()->attach($jurisdiction->id);
        $dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'C30 synthetic schema 2 fixture', 'schema_version' => 2,
            'enabled' => false,
        ]);
        $payload = ['schema_version' => 2, 'coverage' => 'partial', 'rules' => [], 'fixture' => 'synthetic-only; not a legal source'];
        $draft = RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id, 'version' => 1,
            'status' => RestrictionRuleVersionStatus::Draft,
            'payload' => $payload,
            'payload_sha256' => hash('sha256', json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)),
            'base_publication_revision' => 0, 'vehicle_kinds' => [],
            'created_by_id' => $operator->id, 'updated_by_id' => $operator->id,
        ]);

        return [$country, $department, $municipality, $jurisdiction, $dataset, $draft];
    });

    [$free, $pro, $banned] = DB::transaction(static function () use ($operator): array {
        $now = Carbon::now('America/Bogota');
        $make = static fn (string $name, string $email): AppUser => AppUser::query()->create([
            'public_id' => (string) Str::uuid(), 'name' => $name, 'email' => $email, 'categories' => [],
            'privacy_version' => 'C30-SYNTHETIC', 'privacy_accepted_at' => $now,
            'privacy_purpose' => 'optional_account', 'marketing_consent' => false,
        ]);
        $free = $make('C30 Synthetic Free', 'free@picoradar.test');
        $pro = $make('C30 Synthetic Pro', 'pro@picoradar.test');
        $banned = $make('C30 Synthetic Banned', 'banned@picoradar.test');
        app(AppAccountAdministrationService::class)->changePlan($pro, 'pro', $now->copy()->startOfDay(), $now->copy()->addYear(), 'C30-SYNTHETIC-NO-PAYMENT', $operator);
        app(AppAccountAdministrationService::class)->changeStatus($banned, 'banned', 'C30 synthetic QA account', null, $operator);

        return [$free->refresh(), $pro->refresh(), $banned->refresh()];
    });

    [$sponsor, $campaign] = DB::transaction(static function () use ($municipality): array {
        $sponsor = Sponsor::query()->create([
            'public_id' => 'sponsor-c30-synthetic', 'name' => 'C30 Synthetic sponsor', 'status' => SponsorStatus::Inactive,
        ]);
        $now = Carbon::now('America/Bogota');
        $campaign = Campaign::query()->create([
            'public_id' => 'campaign-c30-synthetic', 'sponsor_id' => $sponsor->id,
            'status' => CampaignStatus::Draft, 'placement' => config('campaigns.placement'),
            'eyebrow' => 'C30 SYNTHETIC', 'title' => 'C30 Synthetic draft',
            'subtitle' => 'Private synthetic fixture; campaign catalog OFF.', 'cta_text' => 'View information',
            'cta_url' => 'https://example.test/c30', 'priority' => 100, 'scope' => CampaignScope::Municipality,
            'geographic_unit_id' => $municipality->id, 'starts_at' => $now->copy()->startOfDay()->subDay(),
            'ends_at' => $now->copy()->addDay()->endOfDay(), 'source_image_path' => 'c30/synthetic/source.png',
            'public_image_path' => null, 'image_sha256' => str_repeat('a', 64), 'image_mime' => 'image/png',
            'image_width' => 1440, 'image_height' => 360, 'image_bytes' => 1024,
        ]);

        return [$sponsor, $campaign];
    });

    return [
        'operator_id' => $operator->id,
        'app_users' => [
            ['id' => $free->id, 'email' => $free->email, 'plan' => $free->accountPlan(), 'status' => $free->accountStatus()],
            ['id' => $pro->id, 'email' => $pro->email, 'plan' => $pro->accountPlan(), 'status' => $pro->accountStatus()],
            ['id' => $banned->id, 'email' => $banned->email, 'plan' => $banned->accountPlan(), 'status' => $banned->accountStatus()],
        ],
        'municipality_id' => $municipality->id,
        'jurisdiction_id' => $jurisdiction->id,
        'jurisdiction_enabled' => $jurisdiction->enabled,
        'dataset_id' => $dataset->id,
        'dataset_schema_version' => $dataset->schema_version,
        'dataset_enabled' => $dataset->enabled,
        'draft_rule_version_id' => $draft->id,
        'draft_rule_status' => $draft->status->value,
        'sponsor_id' => $sponsor->id,
        'sponsor_status' => $sponsor->status->value,
        'campaign_id' => $campaign->id,
        'campaign_status' => $campaign->status->value,
        'campaign_catalog_releases' => Schema::hasTable('campaign_catalog_releases') ? DB::table('campaign_catalog_releases')->count() : 0,
    ];
}

if (PHP_SAPI === 'cli-server' || $action === 'router') {
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    $rawUri = $_SERVER['REQUEST_URI'] ?? '/';
    $path = parse_url($rawUri, PHP_URL_PATH);
    $path = is_string($path) ? $path : '';
    $notFound = static function (): never { http_response_code(404); header('Content-Type: text/plain; charset=utf-8'); echo 'Not found'; exit; };
    $editorial = c31EditorialMarker($runtime, (string) (getenv('PICORADAR_INSTANCE_ID') ?: '')) !== null;
    $contentType = (string) ($_SERVER['CONTENT_TYPE'] ?? '');
    $rawBody = '';
    if ($method === 'POST' && preg_match('~^/admin/restrictions/[1-9][0-9]*$~D', $path) === 1 && array_key_exists('_method', $_POST)) {
        $rawBody = (string) file_get_contents('php://input');
    }
    if (! c30RouteMethodAllowed($method, $path, $editorial, $_POST, $_GET, $_SERVER, $contentType, $rawBody)) {
        http_response_code(404);
        exit;
    }
    if ($method !== 'POST' && preg_match('~\.php(?:/|$)~i', $path) === 1) {
        $notFound();
    }

    $static = null;
    if ($path === '/v1/manifest.json') {
        $static = $runtime.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'manifest'.DIRECTORY_SEPARATOR.'v1'.DIRECTORY_SEPARATOR.'manifest.json';
    } elseif (preg_match('~^/storage/datasets/[A-Za-z0-9._/-]+$~', $path) === 1) {
        $static = $runtime.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, substr($path, strlen('/storage/')));
    } elseif (preg_match('~^/build/[A-Za-z0-9._/-]+\.(?:css|js|mjs|svg|png|jpg|jpeg|webp|woff2?)$~i', $path) === 1) {
        $static = $server.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $path);
    }
    if ($static !== null) {
        $real = realpath($static);
        $allowedRoot = str_starts_with($path, '/build/') ? realpath($server.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'build') : realpath($runtime.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public');
        if (! is_string($real) || ! is_string($allowedRoot) || ! c30Within($real, $allowedRoot) || ! is_file($real) || is_link($static)) {
            $notFound();
        }
        $mime = match (strtolower(pathinfo($real, PATHINFO_EXTENSION))) {
            'css' => 'text/css; charset=utf-8', 'js', 'mjs' => 'text/javascript; charset=utf-8', 'svg' => 'image/svg+xml',
            'png' => 'image/png', 'jpg', 'jpeg' => 'image/jpeg', 'webp' => 'image/webp', 'woff' => 'font/woff', 'woff2' => 'font/woff2',
            default => 'application/octet-stream',
        };
        header('Content-Type: '.$mime);
        header('X-Content-Type-Options: nosniff');
        header('Content-Length: '.(string) filesize($real));
        if ($method !== 'HEAD') { readfile($real); }
        exit;
    }
    $public = realpath($server.DIRECTORY_SEPARATOR.'public');
    if (! is_string($public)) { $notFound(); }
    $_SERVER['DOCUMENT_ROOT'] = $public;
    $_SERVER['SCRIPT_FILENAME'] = $public.DIRECTORY_SEPARATOR.'index.php';
    $_SERVER['SCRIPT_NAME'] = '/index.php';
    $_SERVER['PHP_SELF'] = '/index.php';
    require $public.DIRECTORY_SEPARATOR.'index.php';
    exit;
}

if ($action === 'route-policy') {
    $encoded = $argv[2] ?? '';
    $decoded = base64_decode($encoded, true);
    $request = is_string($decoded) ? json_decode($decoded, true) : null;
    if (! is_array($request)) {
        c30Fail('ROUTE_POLICY_INPUT_INVALID');
    }
    $allowed = c30RouteMethodAllowed(
        (string) ($request['method'] ?? ''),
        (string) ($request['path'] ?? ''),
        ($request['editorial'] ?? false) === true,
        is_array($request['post'] ?? null) ? $request['post'] : [],
        is_array($request['query'] ?? null) ? $request['query'] : [],
        is_array($request['server'] ?? null) ? $request['server'] : [],
        (string) ($request['content_type'] ?? ''),
        (string) ($request['raw_body'] ?? ''),
    );
    echo json_encode(['allowed' => $allowed], JSON_THROW_ON_ERROR).PHP_EOL;
    exit;
}

if (! in_array($action, ['paths', 'scope', 'create-db', 'preflight', 'seed', 'counts', 'prepare-editorial'], true)) {
    c30Fail('UNKNOWN_ACTION');
}

$app = c30Boot($server);
if ($action === 'paths' || $action === 'scope' || $action === 'preflight') {
    try {
        $result = c30Preflight($app, $server, $runtime, $action === 'preflight', $action === 'paths');
        echo json_encode(['status' => 'PASS', 'evidence' => $result], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR).PHP_EOL;
    } catch (Throwable $exception) {
        c30Fail('PREFLIGHT_'.$exception::class);
    }
    exit;
}

if ($action === 'create-db') {
    $database = $runtime.DIRECTORY_SEPARATOR.'data'.DIRECTORY_SEPARATOR.'picoradar.sqlite';
    if (file_exists($database) || is_link($database) || ! extension_loaded('sqlite3')) {
        c30Fail('DATABASE_CREATE_PRECONDITION_FAILED');
    }
    $sqlite = new SQLite3($database, SQLITE3_OPEN_READWRITE | SQLITE3_OPEN_CREATE);
    $sqlite->close();
    echo json_encode(['status' => 'PASS', 'database_file' => $database], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR).PHP_EOL;
    exit;
}

if ($action === 'prepare-editorial') {
    try {
        c30Preflight($app, $server, $runtime);
        $result = c31PrepareEditorial(
            $runtime,
            (string) (getenv('PICORADAR_EDITORIAL_EXPECTED_INSTANCE_ID') ?: ''),
            (string) (getenv('PICORADAR_EDITOR_PASSWORD') ?: ''),
            (string) (getenv('PICORADAR_EDITORIAL_ENTRY_MODE') ?: ''),
        );
        echo json_encode($result, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR).PHP_EOL;
    } catch (Throwable $exception) {
        c30Fail('EDITORIAL_PREPARE_'.$exception::class);
    }
    exit;
}

if ($action === 'seed') {
    try {
        $result = c30Seed();
        echo json_encode(['status' => 'PASS', 'fixture' => $result], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR).PHP_EOL;
    } catch (Throwable $exception) {
        c30Fail('SEED_'.$exception::class);
    }
    exit;
}

$tables = ['users', 'geographic_units', 'jurisdictions', 'datasets', 'restriction_rule_versions', 'app_users', 'audit_logs', 'sponsors', 'campaigns', 'campaign_catalog_releases', 'migrations'];
$counts = [];
foreach ($tables as $table) {
    $counts[$table] = Schema::hasTable($table) ? DB::table($table)->count() : null;
}
echo json_encode(['status' => 'PASS', 'counts' => $counts], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR).PHP_EOL;
