# C22-V2 — Runbook de Laravel local (Carril B)

## Estado de esta ejecución

- Base: `0fc292db2938744c40bf8d51a0503cbd3fec8562`; rama no seleccionada en este worktree.
- PHP CLI: 8.5.8. `pdo_sqlite` no viene cargado en la configuración global; el DLL local se carga por proceso con `php -d extension=pdo_sqlite`.
- `server/vendor/autoload.php` no está en este worktree. Se reutilizó de un checkout local cuyo `composer.lock` tiene el mismo SHA-256 (`7469B7EB9E72A79C92C69908AB22B7965FCB3E39019B1BBF6C6CB1C84423B983`); no se ejecutó Composer.
- `php artisan route:list --except-vendor`: PASS, exit 0 con runner temporal y cachés direccionadas a QA.
- Smoke HTTP inicial: tres respuestas HTTP 500. Causa comprobada de configuración Windows: `Application::normalizeCachePath()` no trata `D:\...` como prefijo absoluto y lo concatena con `basePath`; `PackageManifest::write()` falla porque el directorio resultante no existe/escribible. El error posterior `Target class [view] does not exist` es cascada del bootstrap fallido.
- Un intento de usar rutas extendidas `\\?\D:\...` pasó `is_dir`, pero `file_put_contents` no pudo crear el archivo. No hubo re-smoke. No se demostró una ruta externa segura compatible con el bootstrap HTTP.
- Estado: **LOCAL_HTTP=BLOCKED_ENV_PATH**. No es evidencia de defecto de producto. `artisan serve` se detuvo con Ctrl+C y el puerto quedó sin listener.

## Precondiciones de seguridad

1. Usar una carpeta nueva bajo `D:\codex\_REPORTES\PicoRadar\C22-V2-20261122\local-qa`; DB SQLite, storage, sessions, cache, compiled views, logs y manifests deben resolverse allí.
2. Comprobar en el proceso PHP la versión y `pdo_sqlite`; verificar el DSN y `PRAGMA database_list` antes de considerar migraciones. Estos smokes no requirieron migrar.
3. Confirmar lock de Composer idéntico si se reutiliza un `vendor` existente. No ejecutar Composer ni cambiar lock.
4. No leer `.env`, usar DB real, cache/config cache del checkout ni una clave persistente. Generar `APP_KEY` solo en el entorno del proceso; nunca mostrarla, guardarla en archivos/logs o incluirla en ZIP/Git.
5. No arrancar mientras Laravel no pueda escribir y resolver cada `APP_*_CACHE` en el directorio QA externo desde el proceso HTTP hijo. En Laravel 13 bajo Windows, `D:\...` fue unido a `basePath`; `\\?\D:\...` falló en la prueba de escritura. Detenerse ante cualquiera de esos resultados. No crear cache en `server/bootstrap/cache` para sortearlo.
6. Solo `127.0.0.1`, puerto libre. `APP_DEBUG=false`, `APP_ENV=local`, SQLite, `DB_URL` vacío, sesiones/cache en archivo, mail log, queue sync, campañas públicas OFF.

## Inicio (solo cuando las precondiciones anteriores pasan)

En PowerShell, con el worktree C22 como directorio actual, preparar una carpeta QA única y las subcarpetas `storage/framework/{sessions,cache/data,views}`, `storage/logs` y `bootstrap-cache`. Configurar por proceso, sin persistir valores:

```powershell
$Qa = 'D:\codex\_REPORTES\PicoRadar\C22-V2-20261122\local-qa\<run-unico>'
$env:APP_ENV = 'local'
$env:APP_KEY = 'base64:' + [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$env:APP_DEBUG = 'false'
$env:APP_URL = 'http://127.0.0.1:<puerto>'
$env:DB_CONNECTION = 'sqlite'
$env:DB_URL = ''
$env:DB_DATABASE = Join-Path $Qa 'http-smoke.sqlite'
$env:SESSION_DRIVER = 'file'
$env:CACHE_STORE = 'file'
$env:MAIL_MAILER = 'log'
$env:QUEUE_CONNECTION = 'sync'
$env:CAMPAIGNS_PUBLIC_CATALOG_ENABLED = 'false'
```

También dirigir `LARAVEL_STORAGE_PATH` y los cinco paths `APP_CONFIG_CACHE`, `APP_EVENTS_CACHE`, `APP_PACKAGES_CACHE`, `APP_ROUTES_CACHE`, `APP_SERVICES_CACHE` a la carpeta QA. **La traducción a ruta absoluta que funcione en el proceso HTTP hijo sigue sin resolverse en esta ejecución; no lanzar hasta validarla.** El runner `artisan serve` debe transmitir explícitamente las variables de entorno que Laravel filtra en Windows. Arranque esperado una vez validado el harness:

```powershell
php -d extension=pdo_sqlite <runner-temporal-externo> serve --host=127.0.0.1 --port=<puerto-libre> --no-reload
```

El runner debe cargar el autoloader del `vendor` con lock idéntico y el `server/bootstrap/app.php` de este checkout; no debe cambiar código del proyecto.

## Smoke HTTP (solo una corrida, después del gate de aislamiento)

```powershell
curl.exe -sS --max-time 15 -D <headers-login> -o NUL -w '%{http_code}' http://127.0.0.1:<puerto>/login
curl.exe -sS --max-time 15 -D <headers-admin> -o NUL -w '%{http_code}' http://127.0.0.1:<puerto>/admin/operations/national
curl.exe -sS --max-time 15 -D <headers-campaigns> -o NUL -w '%{http_code}' http://127.0.0.1:<puerto>/api/v1/campaign-catalog
```

Criterios: `/login` accesible; la ruta administrativa sin sesión redirige a `/login`; el catálogo responde 404 con flag OFF. Un redireccionamiento sin sesión solo prueba middleware HTTP, nunca autorización positiva. Los roles se prueban in-process por carril C.

## Detener y limpiar

- En la misma terminal del servidor: `Ctrl+C`; confirmar que el puerto registrado ya no tiene listener. No usar `Stop-Process -Name php`.
- Borrar únicamente la carpeta única `local-qa\<run-unico>` creada en esa corrida y retirar cualquier junction temporal solo si su destino coincide exactamente con el `vendor` verificado. Conservar logs sanitizados fuera del repo.
- No tocar `.env`, caches ajenos, datos, migraciones, permisos, flags comerciales, servicios externos ni archivos de otros worktrees.

La ejecución de este runbook aún requiere resolver y verificar la traducción de los paths de caché externos para el proceso HTTP. El estado actual no acredita servidor listo ni auth positiva.

## Evidencia adicional del runner Windows

El runner temporal aplicó `Application::addAbsoluteCachePathPrefix('D:')`; esto hizo pasar `route:list` (exit 0), pero no al proceso PHP CLI-server hijo de `artisan serve`. El hijo vuelve a cargar `public/index.php` y su propio `bootstrap/app.php`, sin heredar el prefijo de la instancia Laravel del runner. La única corrida HTTP (tres rutas) mantuvo 500 por la misma concatenación de `D:\...` con `basePath`. La ruta extendida `\\?\D:\...` no pasó escritura (`file_put_contents` falló), así que no se hizo un segundo grupo de requests.

Limpieza del DB/runner/storage QA y de la junction temporal `server/vendor` quedó pendiente: el revisor automático rechazó la operación explícita de borrado con `blocked by policy`. No se usó alternativa destructiva. Solo el runbook aparece en `git status`; la junction y las dos carpetas temporales están fuera del índice/ignoradas.
