<?php

declare(strict_types=1);

use App\Enums\CampaignScope;
use App\Enums\CampaignStatus;
use App\Enums\JurisdictionKind;
use App\Enums\OperatorRole;
use App\Enums\SponsorStatus;
use App\Models\AppUser;
use App\Models\AuditLog;
use App\Models\Campaign;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Models\Sponsor;
use App\Models\User;
use App\Services\AppAccountAdministrationService;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

const C27_GEO_SOURCE = 'qa-c27';

function c27NormalizePath(string $path): string
{
    return strtolower(rtrim(str_replace('/', DIRECTORY_SEPARATOR, str_replace('\\', DIRECTORY_SEPARATOR, $path)), DIRECTORY_SEPARATOR));
}

function c27PathWithin(string $path, string $root): bool
{
    $normalizedPath = c27NormalizePath($path);
    $normalizedRoot = c27NormalizePath($root);

    return $normalizedPath === $normalizedRoot
        || str_starts_with($normalizedPath, $normalizedRoot.DIRECTORY_SEPARATOR);
}

function c27Sanitize(string $message): string
{
    $message = preg_replace('/[A-Za-z]:[\\\\\/][^\s,;\"\']+/', '<PATH>', $message) ?? '<MESSAGE_REDACTED>';
    $message = preg_replace('/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i', '<EMAIL>', $message) ?? '<MESSAGE_REDACTED>';
    $message = preg_replace('/(?i)(password|token|secret|app_key|reference|db_database)\s*[:=]\s*[^\s,;]+/', '$1=<REDACTED>', $message) ?? '<MESSAGE_REDACTED>';
    $message = preg_replace('/base64:[A-Z0-9+\/]{40,}={0,2}/i', '<SECRET_REDACTED>', $message) ?? '<MESSAGE_REDACTED>';
    $message = preg_replace('/Bearer\s+[A-Z0-9._~+\/=-]+/i', 'Bearer <REDACTED>', $message) ?? '<MESSAGE_REDACTED>';
    $message = preg_replace('/\$2[aby]\$[0-9]{2}\$[.\/A-Za-z0-9]{53}/', '<HASH_REDACTED>', $message) ?? '<MESSAGE_REDACTED>';
    $message = preg_replace('/\b[a-f0-9]{32,}\b/i', '<REDACTED>', $message) ?? '<MESSAGE_REDACTED>';
    $message = preg_replace('/\s+/', ' ', trim($message)) ?? '<MESSAGE_REDACTED>';

    return substr($message, 0, 240);
}

function c27RelativeFile(string $file, string $repoRoot, string $serverRoot): string
{
    $normalizedFile = c27NormalizePath($file);
    foreach ([[$serverRoot, 'server'], [$repoRoot, 'repo']] as [$root, $label]) {
        $normalizedRoot = c27NormalizePath($root);
        $prefix = $normalizedRoot.DIRECTORY_SEPARATOR;
        if (str_starts_with($normalizedFile, $prefix)) {
            return $label.'/'.str_replace(DIRECTORY_SEPARATOR, '/', substr($normalizedFile, strlen($prefix)));
        }
    }

    return '<external>/'.basename($file);
}

function c27Emit(string $stage, string $status, string $class, string $message, string $file, int $line, int $exitCode, array $extra = []): void
{
    $record = [
        'STAGE' => $stage,
        'STATUS' => $status,
        'CLASS' => $class,
        'MESSAGE_SANITIZED' => c27Sanitize($message),
        'FILE_REL' => $file,
        'LINE' => $line,
        'EXIT_CODE' => $exitCode,
    ] + $extra;

    $parts = [];
    foreach ($record as $key => $value) {
        $encoded = is_scalar($value) || $value === null
            ? json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)
            : json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        $parts[] = $key.'='.$encoded;
    }

    fwrite(STDOUT, implode(' ', $parts).PHP_EOL);
    fflush(STDOUT);
}

function c27Require(bool $condition, string $message): void
{
    if (! $condition) {
        throw new RuntimeException($message);
    }
}

function c27DatabasePath(): array
{
    $database = getenv('DB_DATABASE');
    $qaRoot = getenv('C27_QA_ROOT');
    c27Require(is_string($database) && $database !== '', 'DB_DATABASE_REQUIRED');
    c27Require(is_string($qaRoot) && $qaRoot !== '', 'C27_QA_ROOT_REQUIRED');
    c27Require(is_dir($qaRoot), 'C27_QA_ROOT_MISSING');

    $realQaRoot = realpath($qaRoot);
    $realDatabaseParent = realpath(dirname($database));
    c27Require(is_string($realQaRoot) && is_string($realDatabaseParent), 'DATABASE_PARENT_UNRESOLVED');
    c27Require(basename($realQaRoot) === '_QA_LOCAL' && basename(dirname($realQaRoot)) === 'C27-V2-20261123', 'QA_ROOT_NOT_C27_REPORT_FOLDER');
    c27Require(c27NormalizePath($realQaRoot) === c27NormalizePath($realDatabaseParent), 'DATABASE_OUTSIDE_C27_QA_ROOT');
    c27Require(preg_match('/^c27-qa-[a-f0-9]{32}\.sqlite$/i', basename($database)) === 1, 'DATABASE_NAME_NOT_UNIQUE_C27');
    c27Require(strtolower(pathinfo($database, PATHINFO_EXTENSION)) === 'sqlite', 'DATABASE_EXTENSION_INVALID');
    c27Require(! is_link($database), 'DATABASE_SYMLINK_FORBIDDEN');

    $canonicalDatabase = $realQaRoot.DIRECTORY_SEPARATOR.basename($database);
    $c26Database = 'D:\\codex\\_REPORTES\\PicoRadar\\C26-V2-20261123\\_QA_LOCAL\\c26-fixture-20261123.sqlite';
    c27Require(c27NormalizePath($canonicalDatabase) !== c27NormalizePath($c26Database), 'C26_DATABASE_FORBIDDEN');

    return [$canonicalDatabase, $realQaRoot];
}

function c27Bootstrap(string $repoRoot): array
{
    $serverRoot = realpath($repoRoot.DIRECTORY_SEPARATOR.'server');
    c27Require(is_string($serverRoot), 'SERVER_ROOT_UNRESOLVED');
    c27Require(is_file($serverRoot.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php'), 'COMPOSER_VENDOR_MISSING');
    c27Require(! file_exists($serverRoot.DIRECTORY_SEPARATOR.'.env') && ! file_exists($serverRoot.DIRECTORY_SEPARATOR.'.env.testing'), 'ENV_FILE_FORBIDDEN');
    c27Require(! file_exists($serverRoot.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'cache'.DIRECTORY_SEPARATOR.'config.php'), 'CACHED_CONFIG_FORBIDDEN');

    require $serverRoot.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';
    $app = require $serverRoot.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'app.php';
    $kernel = $app->make(Kernel::class);
    $kernel->bootstrap();

    return [$app, $serverRoot];
}

function c27Preflight(string $repoRoot, string $mode): array
{
    [$database, $qaRoot] = c27DatabasePath();
    $mustExist = $mode === 'retry';
    c27Require(file_exists($database) === $mustExist, $mustExist ? 'RETRY_DATABASE_MISSING' : 'NEW_DATABASE_ALREADY_EXISTS');
    c27Require($mustExist ? is_file($database) : ! file_exists($database), 'DATABASE_FILE_TYPE_INVALID');
    c27Require(getenv('APP_ENV') === 'testing', 'APP_ENV_MUST_BE_TESTING');
    c27Require(strtolower((string) getenv('APP_DEBUG')) === 'false', 'APP_DEBUG_MUST_BE_FALSE');
    c27Require(getenv('DB_CONNECTION') === 'sqlite', 'DB_CONNECTION_MUST_BE_SQLITE');
    c27Require(getenv('MAIL_MAILER') === 'array', 'MAIL_MAILER_MUST_BE_ARRAY');
    c27Require(getenv('QUEUE_CONNECTION') === 'sync', 'QUEUE_MUST_BE_SYNC');
    c27Require(getenv('CAMPAIGN_PUBLIC_CATALOG_ENABLED') === 'false', 'PUBLIC_CAMPAIGN_CATALOG_MUST_BE_OFF');
    c27Require(getenv('PICORADAR_C27_QA') === '1', 'C27_QA_MARKER_REQUIRED');
    c27Require(getenv('SESSION_DRIVER') === 'file', 'SESSION_MUST_BE_FILE');
    c27Require(getenv('CACHE_STORE') === 'file', 'CACHE_MUST_BE_FILE');
    c27Require(getenv('FILESYSTEM_DISK') === 'local', 'FILESYSTEM_MUST_BE_LOCAL');
    c27Require(getenv('LOG_CHANNEL') === 'single', 'LOG_MUST_BE_SINGLE_FILE');
    $appKey = (string) getenv('APP_KEY');
    c27Require(str_starts_with($appKey, 'base64:'), 'EPHEMERAL_APP_KEY_REQUIRED');
    $decodedAppKey = base64_decode(substr($appKey, 7), true);
    c27Require(is_string($decodedAppKey) && strlen($decodedAppKey) === 32, 'EPHEMERAL_APP_KEY_INVALID');
    c27Require(in_array('sqlite', PDO::getAvailableDrivers(), true), 'PDO_SQLITE_MISSING');
    c27Require(trim((string) getenv('DB_URL')) === '' && trim((string) getenv('DATABASE_URL')) === '', 'REMOTE_DATABASE_URL_FORBIDDEN');
    foreach (['APP_CONFIG_CACHE', 'APP_ROUTES_CACHE', 'APP_EVENTS_CACHE', 'APP_SERVICES_CACHE', 'APP_PACKAGES_CACHE', 'VIEW_COMPILED_PATH'] as $cacheOverride) {
        c27Require(trim((string) getenv($cacheOverride)) === '', 'CACHE_PATH_OVERRIDE_FORBIDDEN_'.$cacheOverride);
    }

    [$app, $serverRoot] = c27Bootstrap($repoRoot);
    c27Require(file_exists($database) === $mustExist, 'DATABASE_STATE_CHANGED_DURING_BOOTSTRAP');
    c27Require(c27NormalizePath($app->basePath()) === c27NormalizePath($serverRoot), 'BOOTSTRAPPED_BASE_PATH_MISMATCH');
    c27Require($app->environment() === 'testing' && config('app.debug') === false, 'BOOTSTRAPPED_APP_CONFIG_MISMATCH');
    c27Require(config('database.default') === 'sqlite', 'BOOTSTRAPPED_DB_DEFAULT_MISMATCH');
    $sqliteUrl = config('database.connections.sqlite.url');
    c27Require($sqliteUrl === null || $sqliteUrl === '', 'SQLITE_URL_FORBIDDEN');
    c27Require(c27NormalizePath((string) config('database.connections.sqlite.database')) === c27NormalizePath($database), 'BOOTSTRAPPED_DB_PATH_MISMATCH');
    c27Require(config('mail.default') === 'array', 'BOOTSTRAPPED_MAIL_CONFIG_MISMATCH');
    c27Require(config('queue.default') === 'sync', 'BOOTSTRAPPED_QUEUE_CONFIG_MISMATCH');
    c27Require(config('session.driver') === 'file', 'BOOTSTRAPPED_SESSION_CONFIG_MISMATCH');
    c27Require(config('cache.default') === 'file', 'BOOTSTRAPPED_CACHE_CONFIG_MISMATCH');
    c27Require(config('filesystems.default') === 'local', 'BOOTSTRAPPED_FILESYSTEM_CONFIG_MISMATCH');
    c27Require(config('campaigns.public_catalog_enabled') === false, 'BOOTSTRAPPED_CAMPAIGN_CATALOG_NOT_OFF');

    $storageRoot = storage_path();
    c27Require(c27PathWithin($storageRoot, $serverRoot), 'STORAGE_OUTSIDE_RUNTIME');
    $cacheRoot = $serverRoot.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'cache';
    c27Require(c27PathWithin($app->getCachedPackagesPath(), $cacheRoot), 'PACKAGES_CACHE_OUTSIDE_RUNTIME');
    c27Require(c27PathWithin($app->getCachedServicesPath(), $cacheRoot), 'SERVICES_CACHE_OUTSIDE_RUNTIME');
    $writePaths = [
        (string) config('session.files'),
        (string) config('cache.stores.file.path'),
        (string) config('view.compiled'),
        (string) config('logging.channels.single.path'),
        (string) config('filesystems.disks.local.root'),
        (string) config('filesystems.disks.public.root'),
    ];
    foreach ($writePaths as $path) {
        c27Require($path !== '' && c27PathWithin($path, $storageRoot), 'WRITE_PATH_OUTSIDE_QA_STORAGE');
    }

    return [$app, $serverRoot, $database, $qaRoot];
}

/** @return array<string, int> */
function c27Counts(): array
{
    $tables = [
        'users', 'geographic_units', 'jurisdictions', 'jurisdiction_geographic_unit',
        'datasets', 'restriction_rule_versions', 'restriction_publications', 'dataset_releases',
        'app_users', 'audit_logs', 'sponsors', 'campaigns',
    ];
    if (Schema::hasTable('campaign_catalog_releases')) {
        $tables[] = 'campaign_catalog_releases';
    }

    $counts = [];
    foreach ($tables as $table) {
        $counts[$table] = Schema::hasTable($table) ? DB::table($table)->count() : -1;
    }

    return $counts;
}

function c27RequireTablesEmpty(array $names): void
{
    foreach ($names as $table) {
        c27Require(Schema::hasTable($table), 'EXPECTED_TABLE_MISSING_'.$table);
        c27Require(DB::table($table)->count() === 0, 'STAGE_TABLE_NOT_EMPTY_'.$table);
    }
}

function c27GeoUnit(?GeographicUnit $parent, string $level, string $code, string $label, string $key): GeographicUnit
{
    return GeographicUnit::query()->create([
        'parent_id' => $parent?->id,
        'key' => $key,
        'level' => $level,
        'code' => $code,
        'name' => $label,
        'normalized_name' => mb_strtolower($label),
        'is_active' => true,
        'source_system' => C27_GEO_SOURCE,
        'source_version' => '1',
    ]);
}

function c27Operators(): void
{
    c27RequireTablesEmpty(['users']);
    $credentials = [
        ['name' => 'QA C27 SuperAdmin', 'email' => 'c27-superadmin@example.invalid', 'env' => 'C27_SUPERADMIN_PASSWORD', 'role' => OperatorRole::SuperAdmin],
        ['name' => 'QA C27 Editor', 'email' => 'c27-editor@example.invalid', 'env' => 'C27_EDITOR_PASSWORD', 'role' => OperatorRole::Editor],
        ['name' => 'QA C27 Commercial', 'email' => 'c27-commercial@example.invalid', 'env' => 'C27_COMMERCIAL_PASSWORD', 'role' => OperatorRole::Commercial],
    ];

    foreach ($credentials as $credential) {
        $password = getenv($credential['env']);
        c27Require(is_string($password) && strlen($password) >= 32, 'OPERATOR_PASSWORD_ENV_INVALID');
        User::factory()->create([
            'name' => $credential['name'],
            'email' => $credential['email'],
            'password' => Hash::make($password),
            'role' => $credential['role'],
            'is_active' => true,
        ]);
    }

    $users = User::query()->orderBy('email')->get();
    c27Require($users->count() === 3, 'OPERATORS_COUNT_MISMATCH');
    $expected = [
        'c27-commercial@example.invalid' => OperatorRole::Commercial,
        'c27-editor@example.invalid' => OperatorRole::Editor,
        'c27-superadmin@example.invalid' => OperatorRole::SuperAdmin,
    ];
    foreach ($users as $user) {
        c27Require(isset($expected[$user->email]) && $user->role === $expected[$user->email] && $user->is_active, 'OPERATOR_POSTCONDITION_FAILED');
        c27Require(str_ends_with($user->email, '.invalid'), 'OPERATOR_EMAIL_DOMAIN_INVALID');
    }
}

function c27Geography(): void
{
    c27RequireTablesEmpty([
        'geographic_units', 'jurisdictions', 'jurisdiction_geographic_unit', 'datasets',
        'dataset_releases', 'restriction_publications', 'restriction_rule_versions',
    ]);

    $country = c27GeoUnit(null, 'country', 'CO', 'QA SINTÉTICO: Colombia', 'qa-c27-country-co');
    $departments = [];
    foreach (['05', '11', '76'] as $code) {
        $departments[$code] = c27GeoUnit($country, 'department', $code, 'QA SINTÉTICO: Departamento '.$code, 'qa-c27-department-'.$code);
    }

    $municipalities = [];
    foreach ([['05001', '05'], ['11001', '11'], ['76001', '76']] as [$code, $departmentCode]) {
        $municipalities[$code] = c27GeoUnit(
            $departments[$departmentCode],
            'municipality',
            $code,
            'QA SINTÉTICO: Municipio '.$code,
            'qa-c27-municipality-'.$code,
        );
    }

    $jurisdictions = [];
    foreach (['05001' => false, '11001' => true] as $code => $enabled) {
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'co-qa-c27-'.$code,
            'name' => 'QA SINTÉTICO: Jurisdicción '.$code,
            'kind' => JurisdictionKind::City,
            'primary_geographic_unit_id' => $municipalities[$code]->id,
            'enabled' => $enabled,
            'timezone' => 'America/Bogota',
        ]);
        $municipalities[$code]->jurisdictions()->attach($jurisdiction->id);
        $jurisdictions[$code] = $jurisdiction;
    }

    $dataset = Dataset::query()->create([
        'key' => 'restrictions',
        'title' => 'QA SINTÉTICO: Restricciones',
        'schema_version' => 2,
        'enabled' => true,
    ]);

    c27Require(GeographicUnit::query()->where('source_system', C27_GEO_SOURCE)->where('level', 'municipality')->count() === 3, 'MUNICIPALITY_COUNT_MISMATCH');
    c27Require(Jurisdiction::query()->count() === 2, 'JURISDICTION_COUNT_MISMATCH');
    c27Require(Jurisdiction::query()->where('enabled', false)->count() === 1 && Jurisdiction::query()->where('enabled', true)->count() === 1, 'JURISDICTION_STATE_COUNT_MISMATCH');
    c27Require(DB::table('jurisdiction_geographic_unit')->count() === 2, 'JURISDICTION_PIVOT_COUNT_MISMATCH');
    c27Require($municipalities['76001']->jurisdictions()->count() === 0, 'UNASSIGNED_MUNICIPALITY_LINKED');
    c27Require($jurisdictions['05001']->primary_geographic_unit_id === $municipalities['05001']->id, 'OFF_PRIMARY_LINK_MISMATCH');
    c27Require($jurisdictions['11001']->primary_geographic_unit_id === $municipalities['11001']->id, 'ON_PRIMARY_LINK_MISMATCH');
    c27Require($dataset->schema_version === 2 && $dataset->current_version === null, 'DATASET_SCHEMA_OR_RELEASE_MISMATCH');
    c27Require(DatasetRelease::query()->count() === 0 && RestrictionPublication::query()->count() === 0 && RestrictionRuleVersion::query()->count() === 0, 'GEO_PUBLICATION_OR_RULE_CREATED');
}

function c27NewAppUser(string $name, string $email): AppUser
{
    $now = Carbon::now('America/Bogota');

    return AppUser::query()->create([
        'public_id' => (string) Str::uuid(),
        'name' => $name,
        'email' => $email,
        'categories' => [],
        'privacy_version' => 'QA-C27-SYNTHETIC',
        'privacy_accepted_at' => $now,
        'privacy_purpose' => 'optional_account',
        'marketing_consent' => false,
    ]);
}

function c27AppUsers(): void
{
    c27RequireTablesEmpty(['app_users', 'audit_logs']);
    $actor = User::query()->where('email', 'c27-superadmin@example.invalid')->firstOrFail();
    c27Require($actor->role === OperatorRole::SuperAdmin && $actor->is_active, 'SUPERADMIN_AUDIT_ACTOR_INVALID');

    $free = c27NewAppUser('QA C27 FREE', 'c27-free@example.invalid');
    $pro = c27NewAppUser('QA C27 PRO', 'c27-pro@example.invalid');
    $banned = c27NewAppUser('QA C27 BANNED', 'c27-banned@example.invalid');
    $now = Carbon::now('America/Bogota');

    $administration = app(AppAccountAdministrationService::class);
    $administration->changePlan($pro, 'pro', $now->copy()->startOfDay(), $now->copy()->addYear(), 'QA-C27-SYNTHETIC-NO-PAYMENT', $actor);
    $administration->changeStatus($banned, 'banned', 'QA C27 synthetic UAT account', null, $actor);

    $free->refresh();
    $pro->refresh();
    $banned->refresh();
    c27Require($free->accountPlan() === 'free' && $free->accountStatus() === 'active', 'FREE_ACCOUNT_STATE_MISMATCH');
    c27Require($pro->accountPlan() === 'pro' && $pro->accountStatus() === 'active' && $pro->hasActiveProEntitlement($now), 'PRO_ENTITLEMENT_MISMATCH');
    c27Require($pro->plan_source === 'operator_grant' && is_string($pro->plan_reference) && $pro->plan_reference !== '', 'PRO_SERVER_GRANT_FIELDS_MISSING');
    c27Require($banned->accountPlan() === 'free' && $banned->accountStatus() === 'banned' && $banned->isAccessBlocked(), 'BANNED_ACCOUNT_STATE_MISMATCH');
    c27Require($banned->accessTokens()->count() === 0, 'UNEXPECTED_BANNED_ACCOUNT_TOKENS');
    c27Require(AuditLog::query()->where('actor_id', $actor->id)->where('action', 'app_users.plan_changed')->where('subject_type', AppUser::class)->where('subject_id', $pro->id)->count() === 1, 'PRO_AUDIT_LOG_MISSING');
    c27Require(AuditLog::query()->where('actor_id', $actor->id)->where('action', 'app_users.status_changed')->where('subject_type', AppUser::class)->where('subject_id', $banned->id)->count() === 1, 'BANNED_AUDIT_LOG_MISSING');
}

function c27Campaign(): void
{
    $emptyTables = ['sponsors', 'campaigns'];
    if (Schema::hasTable('campaign_catalog_releases')) {
        $emptyTables[] = 'campaign_catalog_releases';
    }
    c27RequireTablesEmpty($emptyTables);
    c27Require(config('campaigns.public_catalog_enabled') === false, 'PUBLIC_CAMPAIGN_CATALOG_NOT_OFF');

    $sponsor = Sponsor::query()->create([
        'public_id' => 'sponsor-c27-synthetic',
        'name' => 'QA SINTÉTICO: Patrocinador C27',
        'status' => SponsorStatus::Inactive,
    ]);
    $now = Carbon::now('America/Bogota');
    $campaign = Campaign::query()->create([
        'public_id' => 'campaign-c27-synthetic',
        'sponsor_id' => $sponsor->id,
        'status' => CampaignStatus::Draft,
        'placement' => config('campaigns.placement'),
        'eyebrow' => 'QA SINTÉTICO',
        'title' => 'QA SINTÉTICO: Campaña C27',
        'subtitle' => 'Borrador privado de verificación; publicidad OFF.',
        'cta_text' => 'Ver información',
        'cta_url' => 'https://example.test/campaign',
        'priority' => 100,
        'scope' => CampaignScope::National,
        'geographic_unit_id' => null,
        'starts_at' => $now->copy()->startOfDay()->subDay(),
        'ends_at' => $now->copy()->addDay()->endOfDay(),
        'source_image_path' => 'qa-c27/synthetic/source.png',
        'public_image_path' => null,
        'image_sha256' => str_repeat('a', 64),
        'image_mime' => 'image/png',
        'image_width' => 1440,
        'image_height' => 360,
        'image_bytes' => 1024,
    ]);

    c27Require($campaign->status === CampaignStatus::Draft && $campaign->scope === CampaignScope::National, 'CAMPAIGN_DRAFT_SCOPE_MISMATCH');
    c27Require($sponsor->status === SponsorStatus::Inactive, 'CAMPAIGN_SPONSOR_NOT_INACTIVE');
    c27Require($campaign->starts_at->lessThanOrEqualTo($now) && $campaign->ends_at->greaterThan($now), 'CAMPAIGN_WINDOW_EXCLUDES_QA_DATE');
    c27Require(Campaign::query()->count() === 1 && Campaign::query()->where('status', CampaignStatus::Draft->value)->count() === 1, 'CAMPAIGN_COUNT_MISMATCH');
    c27Require(config('campaigns.public_catalog_enabled') === false, 'PUBLIC_CAMPAIGN_CATALOG_NOT_OFF');
    if (Schema::hasTable('campaign_catalog_releases')) {
        c27Require(DB::table('campaign_catalog_releases')->count() === 0, 'CAMPAIGN_CATALOG_RELEASE_CREATED');
    }
}

/** @return array{bool, bool} */
function c27RetryMarkerPath(string $qaRoot, string $database, string $stage, string $marker): string
{
    return $qaRoot.DIRECTORY_SEPARATOR.basename($database).'.'.$stage.'.'.$marker;
}

function c27CreateMarker(string $path): bool
{
    $handle = @fopen($path, 'x+b');
    if (! is_resource($handle)) {
        return false;
    }
    fclose($handle);

    return true;
}

function c27RunStage(string $stage, callable $operation, string $repoRoot, string $serverRoot, string $qaRoot, string $database): array
{
    $before = [];
    $beforeCaptured = false;
    try {
        $before = c27Counts();
        $beforeCaptured = true;
        DB::transaction($operation);
        $after = c27Counts();
        c27Emit($stage, 'PASS', 'none', 'postconditions_pass', 'none', 0, 0, [
            'COUNTS_BEFORE' => $before,
            'COUNTS_AFTER' => $after,
            'ROLLBACK' => 'not_applicable',
        ]);

        return [true, true];
    } catch (Throwable $error) {
        try {
            $after = c27Counts();
            $rollbackVerified = $beforeCaptured && $after === $before;
        } catch (Throwable) {
            $after = ['verification' => -1];
            $rollbackVerified = false;
        }

        c27Emit($stage, 'FAIL', $error::class, $error->getMessage(), c27RelativeFile($error->getFile(), $repoRoot, $serverRoot), $error->getLine(), 1, [
            'COUNTS_BEFORE' => $beforeCaptured ? $before : ['verification' => -1],
            'COUNTS_AFTER' => $after,
            'ROLLBACK' => $rollbackVerified ? 'VERIFIED' : 'UNVERIFIED',
            'RETRY_AVAILABLE' => $rollbackVerified && c27CreateMarker(c27RetryMarkerPath($qaRoot, $database, $stage, 'retry-available')),
        ]);

        return [false, $rollbackVerified];
    }
}

function c27OperatorsPass(): bool
{
    if (! Schema::hasTable('users') || User::query()->count() !== 3) {
        return false;
    }
    $expected = [
        'c27-commercial@example.invalid' => OperatorRole::Commercial,
        'c27-editor@example.invalid' => OperatorRole::Editor,
        'c27-superadmin@example.invalid' => OperatorRole::SuperAdmin,
    ];
    foreach (User::query()->get() as $user) {
        if (! isset($expected[$user->email]) || $user->role !== $expected[$user->email] || ! $user->is_active) {
            return false;
        }
    }

    return true;
}

function c27RunStages(?string $retryStage, string $repoRoot, string $serverRoot, string $qaRoot, string $database): int
{
    $stages = [
        'OPERATORS' => static function (): void {
            c27Operators();
        },
        'GEO' => static function (): void {
            c27Geography();
        },
        'APP_USERS' => static function (): void {
            c27AppUsers();
        },
        'CAMPAIGN' => static function (): void {
            c27Campaign();
        },
    ];
    $selected = $retryStage === null ? array_keys($stages) : [$retryStage];
    $allPassed = true;
    $rollbackSafe = true;

    foreach ($selected as $stage) {
        if ($stage === 'APP_USERS') {
            try {
                $operatorsPass = c27OperatorsPass();
            } catch (Throwable $error) {
                c27Emit('APP_USERS', 'FAIL', $error::class, $error->getMessage(), c27RelativeFile($error->getFile(), $repoRoot, $serverRoot), $error->getLine(), 1, ['ROLLBACK' => 'NOT_STARTED']);
                $allPassed = false;
                continue;
            }
            if (! $operatorsPass) {
                c27Emit($stage, 'NOT_RUN_DEPENDENCY', 'none', 'OPERATORS_PASS_REQUIRED', 'none', 0, 1);
                $allPassed = false;
                continue;
            }
        }
        if ($retryStage !== null) {
            $available = c27RetryMarkerPath($qaRoot, $database, $stage, 'retry-available');
            $used = c27RetryMarkerPath($qaRoot, $database, $stage, 'retry-used');
            if (! is_file($available) || is_link($available) || ! c27CreateMarker($used)) {
                c27Emit($stage, 'RETRY_BLOCKED', 'RuntimeException', 'ONE_RETRY_REQUIRES_VERIFIED_ROLLBACK_AND_IS_LIMITED', 'none', 0, 1);

                return 1;
            }
        }
        if (! $rollbackSafe) {
            c27Emit($stage, 'NOT_RUN_UNVERIFIED_ROLLBACK', 'none', 'DATABASE_RETAINED_FOR_REVIEW', 'none', 0, 1);
            $status[$stage] = false;
            $allPassed = false;
            continue;
        }

        [$passed, $rollbackVerified] = c27RunStage($stage, $stages[$stage], $repoRoot, $serverRoot, $qaRoot, $database);
        $allPassed = $allPassed && $passed;
        $rollbackSafe = $rollbackSafe && $rollbackVerified;
    }

    return $allPassed ? 0 : 1;
}

function c27Initialize(string $repoRoot, string $serverRoot, string $database): int
{
    $handle = @fopen($database, 'x+b');
    if (! is_resource($handle)) {
        c27Emit('DB_CREATE', 'FAIL', 'RuntimeException', 'EXCLUSIVE_CREATE_FAILED', 'none', 0, 1);

        return 1;
    }
    fclose($handle);

    try {
        DB::purge('sqlite');
        $pdo = DB::connection('sqlite')->getPdo();
        $mainDatabase = null;
        foreach ($pdo->query('PRAGMA database_list') as $row) {
            if (($row['name'] ?? null) === 'main') {
                $mainDatabase = $row['file'] ?? null;
                break;
            }
        }
        c27Require(is_string($mainDatabase) && c27NormalizePath($mainDatabase) === c27NormalizePath($database), 'SQLITE_TARGET_NOT_EXPECTED_NEW_FILE');
        $objects = (int) $pdo->query("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")->fetchColumn();
        c27Require($objects === 0, 'SQLITE_FILE_NOT_EMPTY_BEFORE_MIGRATION');

        $migrationExit = Artisan::call('migrate', [
            '--database' => 'sqlite',
            '--force' => true,
            '--no-interaction' => true,
        ]);
        if ($migrationExit !== 0) {
            c27Emit('MIGRATIONS', 'FAIL', 'MigrationFailed', 'migrate_command_exit_nonzero', 'server/database/migrations', 0, 1);

            return 1;
        }

        $tableCount = (int) DB::connection('sqlite')->selectOne("SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")->count;
        c27Require($tableCount === 36, 'MIGRATION_TABLE_COUNT_MISMATCH_'.$tableCount);
        foreach (['users', 'geographic_units', 'jurisdictions', 'datasets', 'restriction_rule_versions', 'restriction_publications', 'dataset_releases', 'app_users', 'audit_logs', 'sponsors', 'campaigns'] as $table) {
            c27Require(DB::table($table)->count() === 0, 'BUSINESS_TABLE_NOT_EMPTY_AFTER_MIGRATION_'.$table);
        }
        c27Emit('MIGRATIONS', 'PASS', 'none', 'single_migrate_36_tables_business_rows_zero', 'none', 0, 0, ['TABLES' => $tableCount]);
    } catch (Throwable $error) {
        c27Emit('MIGRATIONS', 'FAIL', $error::class, $error->getMessage(), c27RelativeFile($error->getFile(), $repoRoot, $serverRoot), $error->getLine(), 1, ['DATABASE_RETAINED' => true]);

        return 1;
    }

    return c27RunStages(null, $repoRoot, $serverRoot, dirname($database), $database);
}

$repoRoot = dirname(__DIR__, 3);
$serverRoot = $repoRoot.DIRECTORY_SEPARATOR.'server';
$mode = 'preflight';
$retryStage = null;
foreach (array_slice($argv, 1) as $argument) {
    if ($argument === '--preflight' && $mode === 'preflight') {
        $mode = 'preflight';
    } elseif ($argument === '--init' && $mode === 'preflight') {
        $mode = 'init';
    } elseif (str_starts_with($argument, '--retry=')) {
        if ($mode !== 'preflight' || $retryStage !== null) {
            c27Emit('ARGUMENTS', 'FAIL', 'InvalidArgumentException', 'MULTIPLE_MODES_FORBIDDEN', 'none', 0, 2);
            exit(2);
        }
        $mode = 'retry';
        $retryStage = strtoupper(substr($argument, strlen('--retry=')));
    } else {
        c27Emit('ARGUMENTS', 'FAIL', 'InvalidArgumentException', 'MODE_INVALID', 'none', 0, 2);
        exit(2);
    }
}

if ($mode === 'retry' && ! in_array($retryStage, ['OPERATORS', 'GEO', 'APP_USERS', 'CAMPAIGN'], true)) {
    c27Emit('ARGUMENTS', 'FAIL', 'InvalidArgumentException', 'RETRY_STAGE_INVALID', 'none', 0, 2);
    exit(2);
}

try {
    [$app, $serverRoot, $database, $qaRoot] = c27Preflight($repoRoot, $mode);
    c27Emit('PREFLIGHT', 'PASS', 'none', 'environment_and_paths_verified_no_database_write', 'none', 0, 0, [
        'DB_TARGET' => 'external_c27_qa',
        'DB_EXISTS' => file_exists($database),
        'PDO_SQLITE' => true,
        'APP_ENV' => 'testing',
        'APP_DEBUG' => false,
        'PUBLIC_CAMPAIGN_CATALOG' => 'OFF',
    ]);
} catch (Throwable $error) {
    c27Emit('PREFLIGHT', 'FAIL', $error::class, $error->getMessage(), c27RelativeFile($error->getFile(), $repoRoot, $serverRoot), $error->getLine(), 1);
    exit(1);
}

if ($mode === 'preflight') {
    exit(0);
}

if ($mode === 'init') {
    exit(c27Initialize($repoRoot, $serverRoot, $database));
}

try {
    DB::purge('sqlite');
    $pdo = DB::connection('sqlite')->getPdo();
    $mainDatabase = null;
    foreach ($pdo->query('PRAGMA database_list') as $row) {
        if (($row['name'] ?? null) === 'main') {
            $mainDatabase = $row['file'] ?? null;
            break;
        }
    }
    c27Require(is_string($mainDatabase) && c27NormalizePath($mainDatabase) === c27NormalizePath($database), 'RETRY_SQLITE_TARGET_MISMATCH');
    $tableCount = (int) $pdo->query("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")->fetchColumn();
    c27Require($tableCount === 36, 'RETRY_SCHEMA_TABLE_COUNT_MISMATCH');
    c27Emit('RETRY_PREFLIGHT', 'PASS', 'none', 'existing_c27_database_verified_no_migration', 'none', 0, 0, ['TABLES' => $tableCount]);
} catch (Throwable $error) {
    c27Emit('RETRY_PREFLIGHT', 'FAIL', $error::class, $error->getMessage(), c27RelativeFile($error->getFile(), $repoRoot, $serverRoot), $error->getLine(), 1, ['DATABASE_RETAINED' => true]);
    exit(1);
}

exit(c27RunStages($retryStage, $repoRoot, $serverRoot, dirname($database), $database));
