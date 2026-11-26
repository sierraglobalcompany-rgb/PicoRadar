# C29-V3 A0 — PHP runtime

## Estado

`PHP_READY=PASS` para A0. Checkout candidato `D:\codex\_build\PicoRadar-C29-V3\repo`, rama `codex/c29-v3`, base `e9bb44ae08b5edff6f698c662e6d7b064b24aaad`; el commit funcional `HEAD_CODE=9fa14a40c50f66b9b072819ad16590110937f593` incluye la corrección A1 y los tests C29.

## PHP y SQLite

- Binario elegido por el orden indicado: `C:\xampphp\php\php.exe` (PHP 8.5.8, CLI, x64).
- INI leído por PHP: `C:\xampphp\php\php.ini`; no fue modificado.
- Flags usados solo en procesos de comprobación: `-d extension_dir=C:\xampphp\php\ext -d extension=php_sqlite3.dll -d extension=php_pdo_sqlite.dll`. El `PATH` del proceso se antepuso con `C:\xampphp\php` y `C:\xampphp\php\ext`; no hubo cambios persistentes.
- `sqlite3` y `pdo_sqlite` cargados. `PDO('sqlite::memory:')` y `SELECT sqlite_version()` pasaron; SQLite 3.53.2.

## Composer y autoload del candidato

- `server/composer.lock` SHA-256: `7469B7EB9E72A79C92C69908AB22B7965FCB3E39019B1BBF6C6CB1C84423B983`, igual al SHA histórico y al lock del donante C17.
- Donante comprobado: `D:\codex\PicoRadar-C17-V2\server\vendor`. Su `installed.json` coincide byte a byte con el del candidato (SHA-256 `F7901C82ADC611726CADD42E8F8B209F43A9B17A0D3F5496CC9B74254596330A`). Comparación lock/installed: 77 paquetes runtime + 31 dev; 108 instalados; cero faltantes, extras, versiones distintas o diferencias en el conjunto dev. `dev=true`.
- `require`, `require-dev`, `autoload`, `autoload-dev` y `config` del `composer.json` del donante coinciden con los del candidato.
- `realpath(server/vendor)` y `realpath(server/vendor/autoload.php)` apuntan dentro del candidato. `FileAttributes.ReparsePoint=False` para ambos; son directorio/archivo locales, no junctions ni symlinks.
- `vendor/autoload.php` tiene `LastWriteTime=2026-11-22 13:54:25`, igual al archivo del donante. La marca temporal no demuestra que el vendor estuviera en el candidato antes de A0; el primer sondeo del agente lo encontró ausente.
- Reflexión cargando exclusivamente `server/vendor/autoload.php` del candidato: `App\Models\User` → `server/app/Models/User.php`, PASS; `Tests\TestCase` → `server/tests/TestCase.php`, PASS. No se cargó el autoload del donante.
- Nota de integración: el primer sondeo no encontró `server/vendor` y se inició una copia; al recibir la actualización se interrumpió. La reflexión reveló que el árbol local estaba incompleto (`symfony/deprecation-contracts/function.php` ausente). Se completó el árbol dentro del candidato desde el donante ya verificado, sin borrar archivos; Robocopy copió los archivos que faltaban/cambiaron y reportó 0 errores. No se ejecutó `composer install` porque existe ahora un `vendor` compatible.

## Aislamiento de pruebas

- No existe `server/.env`; no se creó.
- Preparados dentro del candidato: `server/bootstrap/cache`, `server/storage/framework/cache/data`, `sessions`, `views`, `testing` y `server/storage/logs`.
- `server/phpunit.xml` configura `APP_ENV=testing`, `DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:`, `DB_URL=""`, `CACHE_STORE=array`, `SESSION_DRIVER=array`, `MAIL_MAILER=array` y `QUEUE_CONNECTION=sync`.
- No se creó ni accedió a una base de datos persistente ni a archivos de datos de producto. PHPUnit usó SQLite `:memory:`; no se ejecutaron migraciones ni seeders. A1 y B1 se ejecutaron con la CLI y el entorno aislado descritos arriba.

## Alcance y estado del worktree

- `DATE=PASS_FIXED`: A1 falló inicialmente de forma reproducible (1 test, 4 assertions; 2026-11-24 mostrado para 00:30 UTC) y pasó tras el cambio mínimo (1 test, 11 assertions). Se preservaron las fechas almacenadas UTC. La vista ahora indica `Alta (Bogotá)`.
- `PHP_EXPORT=PASS`: B1 pasó (1 test, 37 assertions) y escribió únicamente a `D:\codex\_REPORTES\PicoRadar\C29-V3-20261124\bridge-3587c616-d672-49a4-8a5b-2249793e919f`. `restrictions.json`: 936 bytes, SHA-256 `AF1955879EDC63725FB8C8332CDDD627C6D8B5116A15BD0FEEFB1ECC358CFD7E`; `manifest.json`: 424 bytes, SHA-256 `F244CEB0CEE6C56AB3D1F7FFB72EA78190BE14AA0D38804052A107EF1F0676FA`. Schema 2/1, versión `r2-7f969a248a68`, revisión 2, `generatedAt=2026-11-23T12:00:00Z`, `minAppVersion=1.0.0`, OFF/partial, un rule conservado, ruta relativa `/storage/`. No hay campo global `expiresAt`; el límite de frescura de cobertura es `staleAfter=2026-12-20T00:00:00Z`. Los asserts B1 atan hash de release, payload y manifest y revisión persistida.
- `PHP_LINT=PASS` para los dos tests PHP focales. El export usa solo fake disks y datos sintéticos; sin base persistente o servicio real.
- Sin cambios de PHP INI global, checkout original, DB o datos. El commit funcional `9fa14a40c50f66b9b072819ad16590110937f593` se empujó por fast-forward normal a `feat/platform-integral-national-20261122`; verificación remota exacta, `main` sin cambio.
- Los tests A1 y B1 ya forman parte del commit funcional verificado; no quedaron archivos PHP untracked en el worktree.
- Este runbook y `codex/C29_V3_HANDOFF.md` documentan el entorno y los gates A0/A1/B1/B2/B3/C1. `server/vendor` permanece local/ignorado y fuera del commit. Los directorios de runtime conservan sus `.gitignore`.
