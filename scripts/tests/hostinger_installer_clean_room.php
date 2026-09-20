<?php

use App\Installation\AtomicFileWriter;
use App\Installation\DatabaseCredentials;
use App\Installation\EmptyDatabaseVerifier;
use App\Installation\InstallationStage;
use App\Installation\InstallationStateStore;
use App\Installation\LaravelInstallationRunner;
use App\Installation\PackageManifestVerifier;
use App\Installation\StagingEnvironmentBuilder;

if ($argc !== 4) {
    fwrite(STDERR, "Usage: php hostinger_installer_clean_room.php <domain-root> <db-host> <db-port>\n");
    exit(2);
}

[$script, $domainRoot, $dbHost, $dbPort] = $argv;
$privateRoot = $domainRoot.DIRECTORY_SEPARATOR.'picoradar_app'.DIRECTORY_SEPARATOR.'current';
$publicRoot = $domainRoot.DIRECTORY_SEPARATOR.'public_html'.DIRECTORY_SEPARATOR.'picoradar';
$username = (string) getenv('PICORADAR_TEST_DB_USER');
$password = (string) getenv('PICORADAR_TEST_DB_PASSWORD');
$database = (string) getenv('PICORADAR_TEST_DB_NAME');
$operatorPassword = (string) getenv('PICORADAR_TEST_OPERATOR_PASSWORD');

require $privateRoot.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';

try {
    $config = json_decode((string) file_get_contents(
        $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'package.json',
    ), true, 16, JSON_THROW_ON_ERROR);
    $releaseId = (string) $config['releaseId'];
    $manifest = json_decode((string) file_get_contents($domainRoot.DIRECTORY_SEPARATOR.'package-manifest.json'), true, 32, JSON_THROW_ON_ERROR);
    $manifestReport = (new PackageManifestVerifier([
        'picoradar_app/current/artisan',
        'picoradar_app/current/vendor/autoload.php',
        'picoradar_app/current/bin/cron.php',
        'picoradar_app/current/deploy/hostinger/setup.php',
        'picoradar_app/current/deploy/hostinger/routing.htaccess',
        'public_html/picoradar/index.php',
        'public_html/picoradar/_setup/index.php',
    ]))->verify($domainRoot, $manifest, $releaseId);
    if (! $manifestReport->valid) {
        throw new RuntimeException('Package manifest failed before installation.');
    }

    $credentials = new DatabaseCredentials($dbHost, (int) $dbPort, $database, $username, $password);
    $pdo = new PDO($credentials->dsn(), $credentials->username, $credentials->password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);
    if (! (new EmptyDatabaseVerifier)->isEmpty($pdo)) {
        throw new RuntimeException('The disposable database was not empty.');
    }

    $environment = (new StagingEnvironmentBuilder)->build(
        $credentials,
        'base64:'.base64_encode(random_bytes(32)),
        'https://picoradar.bodegadigitalmedellin.com',
    );
    (new AtomicFileWriter)->write($privateRoot.DIRECTORY_SEPARATOR.'.env', $environment);
    $parsedEnvironment = Dotenv\Dotenv::parse($environment);
    if (($parsedEnvironment['DB_PASSWORD'] ?? null) !== $password) {
        throw new RuntimeException('The database password changed during environment serialization.');
    }
    $state = new InstallationStateStore(
        $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'installation-state.json',
        $releaseId,
    );
    $state->write(InstallationStage::Configured, $releaseId);

    $runner = new LaravelInstallationRunner($privateRoot, $publicRoot);
    $runner->migrate();
    $state->write(InstallationStage::Migrated, $releaseId);
    $runner->createInitialOperator(
        'Clean Room Owner',
        'owner@example.test',
        $operatorPassword,
        $operatorPassword,
    );
    $state->write(InstallationStage::OperatorCreated, $releaseId);
    $htaccess = $publicRoot.DIRECTORY_SEPARATOR.'.htaccess';
    file_put_contents($htaccess, "AuthType Basic\nAuthName \"Private staging\"\nRequire valid-user\n");
    $runner->prepareApplication();
    $state->write(InstallationStage::Completed, $releaseId);

    $lockPath = $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'installed.lock';
    (new AtomicFileWriter)->write($lockPath, json_encode([
        'releaseId' => $releaseId,
        'status' => 'completed',
    ], JSON_THROW_ON_ERROR).PHP_EOL);

    $operator = $pdo->query('SELECT email, role, is_active FROM users')->fetch(PDO::FETCH_ASSOC);
    if (! is_array($operator)
        || $operator['email'] !== 'owner@example.test'
        || $operator['role'] !== 'super_admin'
        || (int) $operator['is_active'] !== 1) {
        throw new RuntimeException('The initial operator contract failed.');
    }
    $foundationCounts = [
        'geographicUnits' => (int) $pdo->query('SELECT COUNT(*) FROM geographic_units')->fetchColumn(),
        'jurisdictions' => (int) $pdo->query('SELECT COUNT(*) FROM jurisdictions')->fetchColumn(),
        'restrictionDatasets' => (int) $pdo->query("SELECT COUNT(*) FROM datasets WHERE `key` = 'restrictions'")->fetchColumn(),
    ];
    if ($foundationCounts !== [
        'geographicUnits' => 1138,
        'jurisdictions' => 73,
        'restrictionDatasets' => 1,
    ]) {
        throw new RuntimeException('The clean installation did not bootstrap the administrative content foundation.');
    }
    foreach ([
        $publicRoot.DIRECTORY_SEPARATOR.'storage' => $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public',
        $publicRoot.DIRECTORY_SEPARATOR.'v1' => $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'manifest'.DIRECTORY_SEPARATOR.'v1',
    ] as $link => $target) {
        if (realpath($link) !== realpath($target)) {
            throw new RuntimeException('A required public link does not resolve to its private target.');
        }
    }
    $htaccessContents = (string) file_get_contents($htaccess);
    if (! str_contains($htaccessContents, 'AuthType Basic')
        || ! str_contains($htaccessContents, 'Require valid-user')
        || ! str_contains($htaccessContents, '# BEGIN PICORADAR ROUTING')) {
        throw new RuntimeException('The existing staging protection was not preserved.');
    }

    echo json_encode([
        'status' => 'OK',
        'releaseId' => $releaseId,
        'operator' => 'owner@example.test',
        'manifestFiles' => count($manifest['files'] ?? []),
        'foundation' => $foundationCounts,
    ], JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR).PHP_EOL;
} catch (Throwable $exception) {
    fwrite(STDERR, 'Clean-room installer failed: '.$exception->getMessage().PHP_EOL);
    exit(1);
}
