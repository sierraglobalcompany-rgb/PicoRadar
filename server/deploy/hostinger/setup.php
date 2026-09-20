<?php

use App\Installation\AtomicFileWriter;
use App\Installation\DatabaseCredentials;
use App\Installation\DatabaseProbeReceipt;
use App\Installation\DatabaseReadinessProbe;
use App\Installation\DeploymentLayout;
use App\Installation\HostPreflightCollector;
use App\Installation\InstallationMutationLock;
use App\Installation\InstallationStage;
use App\Installation\InstallationStateStore;
use App\Installation\InstallAttemptLimiter;
use App\Installation\InstallTokenGuard;
use App\Installation\LaravelInstallationRunner;
use App\Installation\PackageManifestVerifier;
use App\Installation\StagingEnvironmentBuilder;
use Illuminate\Validation\ValidationException;

if (! isset($privateRoot, $publicRoot) || ! is_string($privateRoot) || ! is_string($publicRoot)) {
    http_response_code(500);
    exit('Installer layout is unavailable.');
}

$lockPath = $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'installed.lock';
if (is_file($lockPath)) {
    http_response_code(404);
    exit;
}

require_once $privateRoot.DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';

$layout = new DeploymentLayout(dirname($publicRoot, 2), $publicRoot, $privateRoot);

$configPath = $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'package.json';
$config = is_file($configPath) ? json_decode((string) file_get_contents($configPath), true) : null;
if (! is_array($config)
    || ! isset($config['releaseId'], $config['tokenHash'], $config['tokenExpiresAt'], $config['appUrl'], $config['manifestPath'])) {
    http_response_code(503);
    exit('Installer configuration is unavailable.');
}

$trustedProxyIps = isset($config['trustedProxyIps']) && is_array($config['trustedProxyIps'])
    ? array_values(array_filter($config['trustedProxyIps'], 'is_string'))
    : [];
$preflightCollector = new HostPreflightCollector($privateRoot, $publicRoot, $trustedProxyIps);
if (! $preflightCollector->transportIsSecure($_SERVER)) {
    http_response_code(426);
    header('Content-Type: text/plain; charset=UTF-8');
    exit('HTTPS is required before using the installer.');
}

header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header('Permissions-Policy: camera=(), geolocation=(), microphone=()');
header("Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'");
header('Cache-Control: no-store, max-age=0');

session_name('picoradar_setup');
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/_setup/',
    'secure' => true,
    'httponly' => true,
    'samesite' => 'Strict',
]);
session_start();
$_SESSION['csrf'] ??= bin2hex(random_bytes(32));

$escape = static fn (mixed $value): string => htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
$redirect = static function (): never {
    header('Location: ./', true, 303);
    exit;
};
$message = $_SESSION['message'] ?? null;
$error = $_SESSION['error'] ?? null;
unset($_SESSION['message'], $_SESSION['error']);

$csrfValid = static fn (): bool => isset($_POST['_token'])
    && is_string($_POST['_token'])
    && hash_equals((string) $_SESSION['csrf'], $_POST['_token']);

$releaseId = (string) $config['releaseId'];
$authorizedAt = $_SESSION['authorized_at'] ?? null;
$authorized = ($_SESSION['authorized_release'] ?? null) === $releaseId
    && is_int($authorizedAt)
    && $authorizedAt >= time() - 1800;
if (! $authorized) {
    unset($_SESSION['authorized_release'], $_SESSION['authorized_at'], $_SESSION['db_probe']);
}
$clientIp = (string) ($_SERVER['REMOTE_ADDR'] ?? 'unknown');
$clientKey = hash_hmac('sha256', $clientIp, (string) $config['tokenHash']);
$limiter = new InstallAttemptLimiter(
    $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'attempts.json',
);

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'unlock') {
    if (! $csrfValid()) {
        http_response_code(419);
        exit('Invalid request.');
    }
    if (! $limiter->allows($clientKey)) {
        $_SESSION['error'] = 'Demasiados intentos. Espera 15 minutos.';
        $redirect();
    }

    try {
        $expiresAt = new DateTimeImmutable((string) $config['tokenExpiresAt']);
    } catch (Throwable) {
        $expiresAt = new DateTimeImmutable('@0');
    }

    if (! (new InstallTokenGuard)->verify((string) ($_POST['install_token'] ?? ''), (string) $config['tokenHash'], $expiresAt)) {
        $limiter->recordFailure($clientKey);
        $_SESSION['error'] = 'Token inválido o vencido.';
        $redirect();
    }

    $limiter->clear($clientKey);
    session_regenerate_id(true);
    $_SESSION['authorized_release'] = $releaseId;
    $_SESSION['authorized_at'] = time();
    $_SESSION['csrf'] = bin2hex(random_bytes(32));
    $_SESSION['message'] = 'Acceso verificado.';
    $redirect();
}

if (! $authorized) {
    installer_page('Acceso al instalador', $message, $error, static function () use ($escape): void {
        ?>
        <p>Introduce el token guardado en tu computador. No se enviará en la URL.</p>
        <form method="post" autocomplete="off">
            <input type="hidden" name="_token" value="<?= $escape($_SESSION['csrf']) ?>">
            <input type="hidden" name="action" value="unlock">
            <label>Token de instalación
                <input name="install_token" type="password" required autofocus autocomplete="off">
            </label>
            <button type="submit">Verificar acceso</button>
        </form>
        <?php
    });
    exit;
}

$manifestPath = $layout->domainRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, (string) $config['manifestPath']);
$manifest = is_file($manifestPath) ? json_decode((string) file_get_contents($manifestPath), true) : null;
$manifestReport = is_array($manifest)
    ? (new PackageManifestVerifier([
        'picoradar_app/current/artisan',
        'picoradar_app/current/vendor/autoload.php',
        'picoradar_app/current/bin/cron.php',
        'picoradar_app/current/deploy/hostinger/setup.php',
        'picoradar_app/current/deploy/hostinger/routing.htaccess',
        'public_html/picoradar/index.php',
        'public_html/picoradar/_setup/index.php',
    ]))->verify($layout->domainRoot, $manifest, $releaseId)
    : null;
$preflight = $preflightCollector->collect($_SERVER);
$statePath = $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'installation-state.json';
$stateStore = new InstallationStateStore($statePath, $releaseId);
$state = $stateStore->read();
$effectiveStage = $state->stage === InstallationStage::Failed
    ? ($state->retryStage ?? InstallationStage::New)
    : $state->stage;

$databaseFields = is_array($_SESSION['db_fields'] ?? null)
    ? $_SESSION['db_fields']
    : ['host' => 'localhost', 'port' => 3306, 'database' => '', 'username' => ''];
$operatorFields = is_array($_SESSION['operator_fields'] ?? null)
    ? $_SESSION['operator_fields']
    : ['name' => '', 'email' => ''];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') !== 'unlock') {
    if (! $csrfValid()) {
        http_response_code(419);
        exit('Invalid request.');
    }
    if ($manifestReport === null || ! $manifestReport->valid || ! $preflight->ready) {
        $_SESSION['error'] = 'El diagnóstico o la integridad del paquete bloquean la instalación.';
        $redirect();
    }

    $action = (string) ($_POST['action'] ?? '');
    $mutationLock = new InstallationMutationLock(
        $privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'installer'.DIRECTORY_SEPARATOR.'mutation.lock',
    );
    try {
        $mutationLock->acquire();
        $state = $stateStore->read();
        $effectiveStage = $state->stage === InstallationStage::Failed
            ? ($state->retryStage ?? InstallationStage::New)
            : $state->stage;

        if (in_array($action, ['probe_database', 'configure'], true)) {
            $databaseFields = [
                'host' => trim((string) ($_POST['db_host'] ?? '')),
                'port' => (int) ($_POST['db_port'] ?? 3306),
                'database' => trim((string) ($_POST['db_database'] ?? '')),
                'username' => trim((string) ($_POST['db_username'] ?? '')),
            ];
            $_SESSION['db_fields'] = $databaseFields;
        }
        if ($action === 'operator') {
            $operatorFields = [
                'name' => trim((string) ($_POST['operator_name'] ?? '')),
                'email' => strtolower(trim((string) ($_POST['operator_email'] ?? ''))),
            ];
            $_SESSION['operator_fields'] = $operatorFields;
        }

        if ($action === 'probe_database' && $effectiveStage === InstallationStage::New) {
            $credentials = new DatabaseCredentials(
                (string) $databaseFields['host'],
                (int) $databaseFields['port'],
                (string) $databaseFields['database'],
                (string) $databaseFields['username'],
                (string) ($_POST['db_password'] ?? ''),
            );
            $pdo = new PDO($credentials->dsn(), $credentials->username, $credentials->password, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 5,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]);
            (new DatabaseReadinessProbe)->assertReady($pdo);
            $_SESSION['db_probe'] = (new DatabaseProbeReceipt((string) $config['tokenHash']))
                ->issue($credentials);
            $_SESSION['message'] = 'Conexión, base vacía y permisos comprobados. Vuelve a escribir la contraseña para guardar.';
        } elseif ($action === 'configure' && $effectiveStage === InstallationStage::New) {
            $credentials = new DatabaseCredentials(
                (string) $databaseFields['host'],
                (int) $databaseFields['port'],
                (string) $databaseFields['database'],
                (string) $databaseFields['username'],
                (string) ($_POST['db_password'] ?? ''),
            );
            $receipt = is_array($_SESSION['db_probe'] ?? null) ? $_SESSION['db_probe'] : [];
            if (! (new DatabaseProbeReceipt((string) $config['tokenHash']))->verify($credentials, $receipt)) {
                throw new RuntimeException('database_probe_expired');
            }

            $pdo = new PDO($credentials->dsn(), $credentials->username, $credentials->password, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 5,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]);
            (new DatabaseReadinessProbe)->assertReady($pdo);

            $environmentPath = $privateRoot.DIRECTORY_SEPARATOR.'.env';
            if (is_file($environmentPath)) {
                $existing = Dotenv\Dotenv::parse((string) file_get_contents($environmentPath));
                $expected = [
                    'APP_ENV' => 'staging',
                    'APP_URL' => (string) $config['appUrl'],
                    'DB_HOST' => $credentials->host,
                    'DB_PORT' => (string) $credentials->port,
                    'DB_DATABASE' => $credentials->database,
                    'DB_USERNAME' => $credentials->username,
                    'DB_PASSWORD' => $credentials->password,
                ];
                foreach ($expected as $key => $value) {
                    if (($existing[$key] ?? null) !== $value) {
                        throw new RuntimeException('existing_environment_mismatch');
                    }
                }
            } else {
                $appKey = 'base64:'.base64_encode(random_bytes(32));
                $environment = (new StagingEnvironmentBuilder)->build($credentials, $appKey, (string) $config['appUrl']);
                (new AtomicFileWriter)->write($environmentPath, $environment);
            }
            $stateStore->write(InstallationStage::Configured, $releaseId);
            unset($_SESSION['db_probe']);
            $_SESSION['message'] = 'Configuración privada creada. La contraseña no fue guardada en el estado del instalador.';
        } elseif ($action === 'migrate' && $effectiveStage === InstallationStage::Configured) {
            (new LaravelInstallationRunner($privateRoot, $publicRoot))->migrate();
            $stateStore->write(InstallationStage::Migrated, $releaseId);
            $_SESSION['message'] = 'Migraciones completadas.';
        } elseif ($action === 'operator' && $effectiveStage === InstallationStage::Migrated) {
            $runner = new LaravelInstallationRunner($privateRoot, $publicRoot);
            if (! $runner->initialOperatorMatches((string) $operatorFields['email'])) {
                $runner->createInitialOperator(
                    (string) $operatorFields['name'],
                    (string) $operatorFields['email'],
                    (string) ($_POST['operator_password'] ?? ''),
                    (string) ($_POST['operator_password_confirmation'] ?? ''),
                );
            }
            $stateStore->write(InstallationStage::OperatorCreated, $releaseId);
            unset($_SESSION['operator_fields']);
            $_SESSION['message'] = 'Primer operador creado.';
        } elseif ($action === 'finalize' && in_array($effectiveStage, [InstallationStage::OperatorCreated, InstallationStage::Completed], true)) {
            (new LaravelInstallationRunner($privateRoot, $publicRoot))->prepareApplication();
            $stateStore->write(InstallationStage::Completed, $releaseId);
            (new AtomicFileWriter)->write($lockPath, json_encode([
                'releaseId' => $releaseId,
                'installedAt' => (new DateTimeImmutable)->format(DATE_ATOM),
                'status' => 'completed',
            ], JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR).PHP_EOL);
            $message = 'Instalación completada. El instalador quedó bloqueado.';
            $effectiveStage = InstallationStage::Completed;
            $state = $stateStore->read();
        } else {
            throw new RuntimeException('invalid_stage');
        }
    } catch (ValidationException $exception) {
        $first = collect($exception->errors())->flatten()->first();
        $_SESSION['error'] = is_string($first) ? $first : 'Los datos del operador no son válidos.';
        $stateStore->fail($effectiveStage, $releaseId, 'validation_failed');
    } catch (Throwable $exception) {
        $code = match ($action) {
            'probe_database' => match ($exception->getMessage()) {
                'database_not_empty' => 'database_not_empty',
                'database_privileges_insufficient' => 'database_privileges_insufficient',
                default => 'database_connection_failed',
            },
            'configure' => match ($exception->getMessage()) {
                'database_probe_expired' => 'database_probe_expired',
                'database_not_empty' => 'database_not_empty',
                'database_privileges_insufficient' => 'database_privileges_insufficient',
                'existing_environment_mismatch' => 'existing_environment_mismatch',
                default => 'configuration_failed',
            },
            'migrate' => 'migration_failed',
            'operator' => 'operator_failed',
            'finalize' => 'finalization_failed',
            default => 'invalid_action',
        };
        $_SESSION['error'] = match ($code) {
            'database_not_empty' => 'La base contiene tablas. Usa una base exclusiva y vacía.',
            'database_privileges_insufficient' => 'El usuario no tiene los permisos mínimos de lectura y escritura.',
            'database_connection_failed' => 'No fue posible conectar con esos datos. Revisa host, puerto, base y usuario.',
            'database_probe_expired' => 'La comprobación venció o cambió algún dato. Comprueba la conexión nuevamente.',
            'existing_environment_mismatch' => 'Ya existe una configuración privada diferente. No fue sobrescrita.',
            'configuration_failed' => 'No fue posible validar la base vacía o guardar la configuración.',
            'migration_failed' => 'La migración falló. No se eliminaron tablas; usa una base nueva y vacía antes de reiniciar.',
            'operator_failed' => 'No fue posible crear el primer operador.',
            'finalization_failed' => 'No fue posible completar enlaces, cachés o comprobaciones internas.',
            default => 'La acción no corresponde a la etapa actual.',
        };
        if (! in_array($code, [
            'database_not_empty',
            'database_privileges_insufficient',
            'database_connection_failed',
            'database_probe_expired',
        ], true)) {
            $retryStage = $code === 'migration_failed'
                ? InstallationStage::New
                : $effectiveStage;
            $stateStore->fail($retryStage, $releaseId, $code);
        }
    } finally {
        $mutationLock->release();
    }

    if (! is_file($lockPath)) {
        $redirect();
    }
}

$manifestErrors = $manifestReport?->errors ?? ['manifest_unavailable'];
$blockers = array_values(array_unique(array_merge($preflight->blockers, $manifestErrors)));

installer_page('Instalación privada de PicoRadar', $message, $error, static function () use (
    $escape,
    $releaseId,
    $effectiveStage,
    $state,
    $blockers,
    $privateRoot,
    $databaseFields,
    $operatorFields,
): void {
    ?>
    <div class="meta"><span>Release <?= $escape($releaseId) ?></span><span>Etapa: <?= $escape($state->stage->value) ?></span></div>
    <?php if ($blockers !== []) { ?>
        <section class="blocked">
            <h2>Instalación bloqueada</h2>
            <p>Corrige estos puntos antes de tocar la base de datos:</p>
            <ul><?php foreach ($blockers as $blocker) { ?><li><?= $escape($blocker) ?></li><?php } ?></ul>
        </section>
    <?php } elseif ($effectiveStage === InstallationStage::New) { ?>
        <h2>1. Base de datos exclusiva y vacía</h2>
        <p>Primero se comprueban conexión, base vacía y permisos. Este paso no escribe <code>.env</code> ni crea tablas permanentes.</p>
        <form method="post" autocomplete="off">
            <?= installer_hidden('probe_database', $escape) ?>
            <div class="grid">
                <label>Host<input name="db_host" required value="<?= $escape($databaseFields['host'] ?? 'localhost') ?>"></label>
                <label>Puerto<input name="db_port" type="number" min="1" max="65535" required value="<?= $escape($databaseFields['port'] ?? 3306) ?>"></label>
            </div>
            <label>Base de datos<input name="db_database" required autocomplete="off" value="<?= $escape($databaseFields['database'] ?? '') ?>"></label>
            <label>Usuario<input name="db_username" required autocomplete="off" value="<?= $escape($databaseFields['username'] ?? '') ?>"></label>
            <label>Contraseña<input name="db_password" type="password" required autocomplete="new-password"></label>
            <button type="submit">Probar conexión y base vacía</button>
        </form>
        <?php if (is_array($_SESSION['db_probe'] ?? null)) { ?>
            <section class="notice">
                <strong>Comprobación vigente.</strong> Para guardar la configuración, vuelve a escribir la misma contraseña.
                <form method="post" autocomplete="off">
                    <?= installer_hidden('configure', $escape) ?>
                    <input type="hidden" name="db_host" value="<?= $escape($databaseFields['host'] ?? '') ?>">
                    <input type="hidden" name="db_port" value="<?= $escape($databaseFields['port'] ?? 3306) ?>">
                    <input type="hidden" name="db_database" value="<?= $escape($databaseFields['database'] ?? '') ?>">
                    <input type="hidden" name="db_username" value="<?= $escape($databaseFields['username'] ?? '') ?>">
                    <label>Confirmar contraseña<input name="db_password" type="password" required autocomplete="new-password"></label>
                    <button type="submit">Guardar configuración privada</button>
                </form>
            </section>
        <?php } ?>
    <?php } elseif ($effectiveStage === InstallationStage::Configured) { ?>
        <h2>2. Crear estructura</h2>
        <p>La conexión ya fue comprobada. Las migraciones comenzarán únicamente al confirmar.</p>
        <form method="post"><?= installer_hidden('migrate', $escape) ?><button type="submit">Ejecutar migraciones</button></form>
    <?php } elseif ($effectiveStage === InstallationStage::Migrated) { ?>
        <h2>3. Primer operador</h2>
        <p>Se creará un único superadministrador activo. Esto no habilita cuentas móviles.</p>
        <form method="post" autocomplete="off">
            <?= installer_hidden('operator', $escape) ?>
            <label>Nombre<input name="operator_name" required maxlength="255" value="<?= $escape($operatorFields['name'] ?? '') ?>"></label>
            <label>Correo<input name="operator_email" type="email" required maxlength="255" value="<?= $escape($operatorFields['email'] ?? '') ?>"></label>
            <label>Contraseña<input name="operator_password" type="password" minlength="12" required autocomplete="new-password"></label>
            <label>Confirmación<input name="operator_password_confirmation" type="password" minlength="12" required autocomplete="new-password"></label>
            <button type="submit">Crear operador</button>
        </form>
    <?php } elseif ($effectiveStage === InstallationStage::OperatorCreated) { ?>
        <h2>4. Preparación final</h2>
        <p>Se crearán los enlaces públicos, las cachés y se comprobarán internamente Health y Login.</p>
        <form method="post"><?= installer_hidden('finalize', $escape) ?><button type="submit">Completar y bloquear instalador</button></form>
    <?php } else { ?>
        <h2>Instalación completada</h2>
        <p>El bloqueo privado fue creado. Elimina ahora <code>public_html/picoradar/_setup</code> desde File Manager.</p>
        <h3>Cron en hPanel</h3>
        <p>Tipo PHP, cada cinco minutos, zona horaria UTC:</p>
        <code><?= $escape($privateRoot.DIRECTORY_SEPARATOR.'bin'.DIRECTORY_SEPARATOR.'cron.php') ?></code>
        <p><a href="../login">Abrir acceso administrativo</a></p>
    <?php } ?>
    <?php
});

function installer_hidden(string $action, callable $escape): string
{
    return '<input type="hidden" name="_token" value="'.$escape($_SESSION['csrf']).'">'
        .'<input type="hidden" name="action" value="'.$escape($action).'">';
}

function installer_page(string $title, ?string $message, ?string $error, callable $content): void
{
    $safeTitle = htmlspecialchars($title, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    ?><!doctype html>
    <html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title><?= $safeTitle ?></title>
    <style>
        :root{color-scheme:light;--navy:#0b3159;--teal:#008f86;--line:#d7e2eb;--muted:#56708b;--danger:#a52a2a}
        *{box-sizing:border-box}body{margin:0;background:#f4f7f9;color:var(--navy);font:16px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}
        main{width:min(680px,calc(100% - 32px));margin:40px auto;background:#fff;border:1px solid var(--line);border-radius:8px;padding:28px}
        h1{font-size:26px;margin:0 0 8px}h2{font-size:20px;margin:24px 0 8px}h3{font-size:17px}.lead{color:var(--muted);margin-top:0}
        .meta{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}.meta span{background:#e8f6f4;border-radius:999px;padding:5px 10px;font-size:13px}
        .notice,.error,.blocked{border:1px solid;padding:12px 14px;border-radius:6px;margin:16px 0}.notice{border-color:#9bd5ce;background:#effbf9}.error,.blocked{border-color:#e4aaaa;background:#fff5f5;color:#741d1d}
        label{display:grid;gap:6px;font-weight:650;margin:14px 0}input{min-height:48px;border:1px solid #9fb2c4;border-radius:6px;padding:10px 12px;font:inherit;color:var(--navy)}
        input:focus{outline:3px solid #89d7d1;outline-offset:1px}.grid{display:grid;grid-template-columns:2fr 1fr;gap:12px}
        button{min-height:48px;border:0;border-radius:6px;background:var(--teal);color:#fff;font:700 16px inherit;padding:12px 18px;cursor:pointer}
        code{display:block;overflow-wrap:anywhere;background:#edf2f6;padding:10px;border-radius:4px}a{color:#007d75;font-weight:700}
        @media(max-width:520px){main{margin:16px auto;padding:20px}.grid{grid-template-columns:1fr}h1{font-size:22px}}
    </style></head><body><main><h1><?= $safeTitle ?></h1><p class="lead">Asistente de primer uso para staging privado.</p>
    <?php if ($message) { ?><div class="notice"><?= htmlspecialchars($message, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') ?></div><?php } ?>
    <?php if ($error) { ?><div class="error"><?= htmlspecialchars($error, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') ?></div><?php } ?>
    <?php $content(); ?></main></body></html><?php
}
