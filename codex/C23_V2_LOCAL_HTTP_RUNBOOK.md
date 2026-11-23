# C23-V2 — smoke HTTP Laravel local

## Resultado observado

- Fuente: checkout limpio `f4f6c9a3ce8e9ae764c131db5e7d34194e78642c`, en una copia desechable ubicada íntegramente en D:.
- `server/composer.lock`: SHA-256 `7469B7EB9E72A79C92C69908AB22B7965FCB3E39019B1BBF6C6CB1C84423B983`. Se reutilizó el `vendor` local mediante junction; no se ejecutó Composer. El lock coincide, aunque el vendor local contiene registros de paquetes adicionales; no se presenta como instalación limpia.
- Sin `.env`. SQLite vacío nuevo, dentro de `server/database/database.sqlite`; no se ejecutaron migraciones ni seeders.
- PHP 8.5.8; `pdo_sqlite` y `sqlite3` cargados solo en los procesos de preflight/servidor. `APP_KEY` aleatoria solo en el entorno de esos procesos, nunca guardada en archivo o log.
- Gate de bootstrap PASS: `base_path`, `storage_path`, `bootstrap/cache/{packages,services}.php` y el archivo abierto por `PRAGMA database_list` quedaron bajo la copia D:, escribibles; no se usaron overrides de caché entre unidades.

## Tanda HTTP

| Ruta anónima | Resultado | Criterio |
|---|---:|---|
| `/login` | **200** | página Blade de acceso renderizada |
| `/admin/operations/national` | **302** a `/login` | autenticación requerida; no expuso datos |
| `/api/v1/campaign-catalog` | **404** | catálogo de campañas OFF |

Servidor `php -S` ligado solo a `127.0.0.1`. En la única repetición, el PID propietario del listener fue 40480 en el puerto 49742. Se detuvo ese PID; el puerto quedó cerrado. No hubo cookies, migraciones, seeders ni solicitudes externas.

## Ajuste de harness y límite

La primera tanda obtuvo `/login=500`, `/admin/operations/national=302`, catálogo `404`. El error era `ViteManifestNotFoundException`: el checkout limpio no contiene `public/build/manifest.json`. Un build local de frontend no era posible sin descargar paquetes: el caché npm solo tenía 87 de 158 URLs fijadas por `package-lock.json`. No se instalaron paquetes ni se contactó el registry.

Para la única repetición permitida se creó dentro de la copia ignorada un manifiesto Vite temporal con las dos entradas que pide `login.blade.php` (`resources/css/app.css`, `resources/js/app.js`). SHA-256 del fixture: `BEED62E806F04C98A4C8AE25C43CA12990A5519339B7545323B8857898039FB0`. La repetición verificó proceso, router, middleware y render del HTML. **No verificó entrega de CSS/JS ni comportamiento visual del frontend.** El fixture y toda la copia son temporales, no se versionan.

## Receta mínima

1. Crear una copia limpia de la revisión y mantener código, `vendor`, SQLite, cachés y vistas en la misma unidad. No cargar `.env` del desarrollador.
2. Confirmar el SHA del lock antes de enlazar `vendor`. Crear en la copia `bootstrap/cache`, `storage/framework/{cache/data,sessions,views,testing}`, `storage/logs` y una DB SQLite vacía.
3. Ejecutar el preflight con el mismo PHP, extensiones y entorno que el servidor. Arrancar la app mediante `bootstrap/app.php` y `Illuminate\Contracts\Console\Kernel::bootstrap()`. Confirmar `base_path()`, `storage_path()`, `getCachedPackagesPath()`, `getCachedServicesPath()`, permisos de escritura y `PRAGMA database_list`; exigir que todo quede bajo la copia.
4. Entorno del proceso: `APP_ENV=local`, `APP_DEBUG=false`, clave efímera, `APP_URL=http://127.0.0.1:<puerto>`, `DB_CONNECTION=sqlite`, `DB_URL=''`, `DB_DATABASE=<ruta-a-la-copia>/server/database/database.sqlite`, `SESSION_DRIVER=file`, `CACHE_STORE=file`, `MAIL_MAILER=array`, `QUEUE_CONNECTION=sync`, `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false`. Quitar `APP_*_CACHE` y `VIEW_COMPILED_PATH` heredados; no apuntarlos a otra unidad.
5. Si no existe el bundle Vite y no es posible construirlo offline, registrar la causa y, solo para el smoke de ruta/HTML, crear un manifiesto temporal en `public/build/manifest.json` con las entradas CSS/JS requeridas. Informar que los assets no se probaron; no incluir ese fixture en el commit.
6. Ejecutar un solo servidor `php -d extension=<pdo_sqlite> -d extension=<sqlite3> -S 127.0.0.1:<puerto> -t public <router-temporal.php>`. El router temporal carga el autoloader del vendor fijado y antepone PSR-4 `App\` hacia `server/app` de la copia antes de requerir `public/index.php`.
7. Una tanda GET sin cookies: `/login`, `/admin/operations/national` y `/api/v1/campaign-catalog`; verificar status y `Location`. Detener exclusivamente el PID propio y confirmar listener cerrado.

Este smoke local no valida credenciales, funciones SuperAdmin, acceso a servicios externos ni publicación. C2/C3 históricos no se repitieron.
