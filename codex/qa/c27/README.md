# C27 V2 — fixture local y UAT

Este runner crea una sola SQLite sintética y nueva bajo `_QA_LOCAL` del paquete C27. Nunca reutiliza o elimina una base existente, no usa `migrate:fresh` y no publica datos ni campañas.

## Ejecución segura

Ejecutar `seed.php` desde la copia aislada de runtime que contiene `codex/qa/c27/` y `server/`. Antes de `--init`, definir en el proceso:

- `APP_ENV=testing`, `APP_DEBUG=false` y un `APP_KEY` efímero;
- `DB_CONNECTION=sqlite` y `DB_DATABASE` con nombre `c27-qa-<32 hex>.sqlite` dentro del `_QA_LOCAL` C27;
- `C27_QA_ROOT` con la ruta canónica de ese `_QA_LOCAL`;
- `MAIL_MAILER=array`, `QUEUE_CONNECTION=sync`, `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false`, `PICORADAR_C27_QA=1`;
- `SESSION_DRIVER=file`, `CACHE_STORE=file`, `FILESYSTEM_DISK=local`, `LOG_CHANNEL=single`;
- `APP_CONFIG_CACHE`, `APP_ROUTES_CACHE`, `APP_EVENTS_CACHE`, `APP_SERVICES_CACHE`, `APP_PACKAGES_CACHE`, `VIEW_COMPILED_PATH`, `DB_URL` and `DATABASE_URL` unset (do not set the cache overrides to an empty string).
- `C27_SUPERADMIN_PASSWORD`, `C27_EDITOR_PASSWORD` y `C27_COMMERCIAL_PASSWORD` con credenciales sintéticas efímeras.

Primero ejecutar `php -d extension=pdo_sqlite codex/qa/c27/seed.php --preflight`. Debe devolver `PREFLIGHT PASS` y `DB_EXISTS=false`. Solo entonces ejecutar una vez `--init`. El modo init crea el archivo en exclusiva, comprueba SQLite vacía, ejecuta una migración y corre las etapas transaccionales OPERATORS, GEO, APP_USERS y CAMPAIGN.

Cada etapa informa estado, excepción sanitizada, ubicación relativa y conteos anteriores/posteriores. Si una etapa falla y el rollback queda verificado, el runner crea marcadores externos sin secretos que habilitan un solo `--retry` de esa etapa. Revisar la causa y aplicar una única corrección causal antes de repetir con `--retry=OPERATORS|GEO|APP_USERS|CAMPAIGN`. El marcador de consumo impide un segundo reintento. No repetir etapas PASS. Si el rollback no queda verificado, retener la base y no reintentar.

Las contraseñas y la llave de aplicación nunca se escriben en archivos ni en el repositorio. La base SQLite, `.env`, logs crudos y credenciales no se empaquetan. Para el HTTP local, usar `php -d extension=pdo_sqlite -S 127.0.0.1:<puerto> -t public` dentro del runtime aislado, con las mismas variables y la misma DB; mantener `APP_DEBUG=false` y detener solo ese proceso al terminar.

## Datos esperados

- OPERATORS: tres operadores activos con rol SuperAdmin, Editor y Commercial.
- GEO: CO, departamentos 05/11/76, municipios sintéticos 05001/11001/76001, dos jurisdicciones vinculadas por FK y pivot, dataset schema 2, sin versiones, publicaciones ni releases.
- APP_USERS: Free activo, Pro activo con concesión y auditoría, y Banned/Free con auditoría.
- CAMPAIGN: una campaña National en Draft con sponsor Inactive; catálogo público y releases permanecen OFF/cero.

Los valores geográficos son fixtures de QA y no representan cobertura jurídica ni restricciones reales.
