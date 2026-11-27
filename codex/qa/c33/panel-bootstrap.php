<?php

declare(strict_types=1);

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

try {
    $serverRoot = (string) getenv('PICORADAR_QA_SERVER_ROOT');
    require $serverRoot.'/vendor/autoload.php';
    $app = require $serverRoot.'/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();

    $identity = DB::selectOne(
        'SELECT DATABASE() AS db, @@port AS port, @@datadir AS datadir, CURRENT_USER() AS account'
    );
    $normalize = static fn ($value): string => strtolower(rtrim(
        str_replace('/', '\\', (string) $value),
        '\\'
    ));

    if ($identity->db !== getenv('PICORADAR_QA_EXPECT_DB')
        || (int) $identity->port !== (int) getenv('PICORADAR_QA_EXPECT_PORT')
        || $normalize($identity->datadir) !== $normalize(getenv('PICORADAR_QA_EXPECT_DATADIR'))
        || $identity->account !== getenv('PICORADAR_QA_EXPECT_USER')) {
        throw new RuntimeException('DB_IDENTITY');
    }

    $privateRoot = realpath((string) getenv('PICORADAR_QA_PRIVATE_ROOT'));
    $paths = [
        'storage' => storage_path(),
        'views' => (string) config('view.compiled'),
        'sessions' => storage_path('framework/sessions'),
        'cache' => storage_path('framework/cache/data'),
        'logs' => storage_path('logs'),
        'public' => public_path(),
    ];

    foreach ($paths as $name => $path) {
        $realPath = realpath($path);
        if ($privateRoot === false
            || $realPath === false
            || ! str_starts_with(strtolower($realPath), strtolower($privateRoot.DIRECTORY_SEPARATOR))
            || ! is_writable($realPath)) {
            throw new RuntimeException('WRITE_ROOT');
        }
        $paths[$name] = $realPath;
    }

    if (rtrim(str_replace('\\', '/', public_path()), '/') !== rtrim(
        str_replace('\\', '/', (string) getenv('PICORADAR_PUBLIC_PATH')),
        '/'
    )) {
        throw new RuntimeException('PUBLIC_ROOT');
    }

    foreach ([
        'CAMPAIGN_PUBLIC_CATALOG_ENABLED',
        'PICORADAR_ACCOUNTS_ENABLED',
        'PICORADAR_ACCOUNT_EMAIL_ENABLED',
        'PICORADAR_MARKETING_SEND_ENABLED',
        'PICORADAR_SPONSORED_CAMPAIGNS_ENABLED',
    ] as $flag) {
        if (getenv($flag) !== 'false') {
            throw new RuntimeException('FEATURE_FLAG');
        }
    }

    $userCount = DB::table('users')->count();
    $action = (string) ($argv[1] ?? 'preflight');

    if ($action === 'preflight') {
        echo json_encode([
            'ok' => true,
            'db' => $identity->db,
            'port' => (int) $identity->port,
            'account' => $identity->account,
            'users' => $userCount,
            'paths' => $paths,
            'flags' => 'OFF',
        ], JSON_THROW_ON_ERROR);
        exit(0);
    }

    if ($action !== 'create' || $userCount !== 0) {
        throw new RuntimeException('ADMIN_PRECONDITION');
    }

    $credentialsPath = (string) getenv('PICORADAR_QA_CREDENTIAL_FILE');
    $credentials = json_decode(
        (string) file_get_contents($credentialsPath),
        true,
        512,
        JSON_THROW_ON_ERROR
    );
    $user = $app->make(\App\Actions\Admin\InitialOperatorCreator::class)->create(
        (string) $credentials['name'],
        (string) $credentials['email'],
        (string) $credentials['password'],
        (string) $credentials['password']
    );
    $user->refresh();

    if (DB::table('users')->count() !== 1
        || $user->role->value !== 'super_admin'
        || ! $user->is_active) {
        throw new RuntimeException('ADMIN_VERIFY');
    }

    echo json_encode([
        'ok' => true,
        'admin_created' => true,
        'role' => $user->role->value,
        'active' => (bool) $user->is_active,
        'users' => 1,
    ], JSON_THROW_ON_ERROR);
    exit(0);
} catch (Throwable $exception) {
    $reason = $exception->getMessage();
    foreach ([getenv("DB_PASSWORD"), getenv("APP_KEY")] as $secret) {
        if (is_string($secret) && $secret !== "") { $reason = str_replace($secret, "[redacted]", $reason); }
    }
    $reason = preg_replace("/[\r\n|]+/", " ", $reason);
    fwrite(STDERR, get_class($exception)."|".substr($reason, 0, 300)."\n");
    exit(23);
}