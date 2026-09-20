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
    $manifest = json_decode((string) file_get_contents($domainRoot.DIRECTORY_SEPARATOR.'package-manifest.json'), true, 32, JSON_THROW_ON_ERROR);
    $manifestReport = (new PackageManifestVerifier)->verify($domainRoot, $manifest);
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

    $config = json_decode((string) file_get_contents(
        $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'package.json',
    ), true, 16, JSON_THROW_ON_ERROR);
    $releaseId = (string) $config['releaseId'];
    $state = new InstallationStateStore(
        $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'installation-state.json',
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
    if (! is_link($publicRoot.DIRECTORY_SEPARATOR.'storage')
        || ! is_link($publicRoot.DIRECTORY_SEPARATOR.'v1')) {
        throw new RuntimeException('The required public links were not created.');
    }

    echo json_encode([
        'status' => 'OK',
        'releaseId' => $releaseId,
        'operator' => 'owner@example.test',
        'manifestFiles' => count($manifest['files'] ?? []),
    ], JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR).PHP_EOL;
} catch (Throwable $exception) {
    fwrite(STDERR, 'Clean-room installer failed: '.$exception->getMessage().PHP_EOL);
    exit(1);
}
