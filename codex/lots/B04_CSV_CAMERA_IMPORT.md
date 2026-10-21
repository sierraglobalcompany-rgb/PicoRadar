# B04-CSV-KISS — Importación revisable de cámaras (plan único)

**Estado:** IMPLEMENTED_DRAFT_PR75 / RUNTIME_QA_NOT_RUN / NO_MERGE. El contrato no certifica la corrección del código.
**Fecha:** 2026-10-21. **Base autorizada:** `recovery/20261019-modern`; fotografía al planificar `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`.
**Alcance:** un lote Laravel administrativo, CSV solamente. Nuevo PR **Draft** hacia la rama moderna, **sin merge ni deploy**. Este archivo consolida el contrato B04 CSV V5 y la auditoría de seguridad V5.1, que eran adjuntos externos al repositorio. No es evidencia de código ejecutado.

## 1. Preflight y fuente de verdad

1. Leer `AGENTS.md`, baselines 11 y 12 de `docs/baseline/`, `docs/CURRENT.md`, `docs/DESIGN_CONTRACT.md`, `docs/SOP.md`, y servicios reales de cámaras. Las reglas de precedencia de AGENTS prevalecen sobre este lote.
2. Verificar HEAD remoto moderno, PR #71 y posibles ramas/PR B04 CSV creados desde esta fotografía; si existen, inspeccionar delta y continuar, sin duplicar PR. **Nunca** partir de `main` histórico ni integrar masivamente `recovery/20261019-pending-b04` (divergente, 43 archivos de diferencia al corte).
3. Antes de modificar el PC: `git status --porcelain=v1 -uall`, `git branch -vv`, `git worktree list --porcelain`, `git log -1`, fetch y comparación contra HEAD remoto. No suponer ausencia de WIP. C: y los 13 worktrees históricos se preservan; D: actual es exFAT. No `reset --hard`, `clean`, `stash` ni `git add -A`. Respetar el archivo PS1 denegado.
4. Usar checkout aislado seguro para el nuevo lote. Una rama `feat/B04-CSV-camera-import-kiss`, **un PR Draft** a `recovery/20261019-modern`. Si el checkout tiene WIP, no sobrescribir ni restaurar archivos ajenos.
5. Prohibido tocar Hostinger, teléfono físico, `main`, despliegue, Actions con cuota agotada, Flutter/C11, ANSV/B07, publicador, datos reales o secretos. Si un paso está bloqueado, documentar `PARTIAL` y continuar solo partes seguras.

## 2. Contrato CSV v1 cerrado

- Un lote = **una fuente** seleccionada en servidor, **una jurisdicción** habilitada, modo `snapshot` o `delta`, archivo privado CSV; corregir errores reimportando, no edición libre de filas.
- Cabecera obligatoria exacta: `external_id,municipality_code,lat,lon,type`. Opcionales: `name,direction,bearing,corridor,speed_limit,notes`. Sin alias, columnas repetidas/desconocidas ni autodetección heurística.
- `external_id` texto no vacío 1–255, único dentro de CSV y estable por fuente. `municipality_code` texto, conservar ceros (ej. `05001`); resolver municipio **y cobertura** en servidor, no por nombre libre.
- `lat/lon` WGS84 decimales con punto, finitos, [-90,90] y [-180,180]; rechazar `NaN`, `INF`, NUL, formatos ambiguos, longitudes excesivas. `bearing` entero 0–359; `speed_limit` entero 1–200; velocidad cargada jamás implica verificación.
- `type` exacto en enum vigente: `speed`, `red_light`, `combined`, `other`, `unknown`. Valores desconocidos => inválido.
- CSV UTF-8 con BOM opcional, RFC4180 (coma, comillas, CRLF, comas y saltos dentro de campo); `fgetcsv` con escape explícito compatible y probado. Límite **5 MiB y 2.000 filas no vacías**, validado mientras se analiza; contar filas vacías ignoradas y errores por fila.
- Celdas opcionales vacías no borran valores existentes. Reportes CSV neutralizan fórmula tras whitespace/control inicial (`= + - @`) sin mutar CSV fuente. Fixture sintético `server/tests/Fixtures/camera_csv_import_sample.csv`: no afirmar posiciones reales.

## 3. Flujo UI: 3 vistas Blade existentes o mínimas

1. **Importaciones:** listado paginado de lotes, fuente, fecha, estado, conteos y enlace a crear.
2. **Nueva:** fuente, jurisdicción, modo y archivo privado, ayuda de cabecera y plantilla; permiso `cameras.edit`, auth/CSRF.
3. **Revisión:** conteos y diagnóstico por fila (nueva, changed, noop, invalid, blocked, duplicate, suspicious), diferencias antes/después, comparación con otro lote de **misma** fuente/jurisdicción, selección explícita de filas seguras y confirmación. Sin cuarto SPA, sin rediseño móvil.
- Ordenar rutas literales `/admin/cameras/imports` **antes** de `/admin/cameras/{camera}`; reutilizar layout/comportamiento del admin; responsive, foco, teclado, mensajes de errores legibles, sin tablas infinitas.
- Gates actuales `cameras.view/edit/review` solamente, no permisos `camera_imports.*`. **Apply** exige `cameras.edit` **y** `cameras.review` en servidor; no basarse en botón oculto.

## 4. Clasificación fail-closed e invariantes

- Crear `create_ready` solo si `source_id + external_id` no existe, fuente activa y verificada, municipio/jurisdicción válidos y cubiertos, y detector de duplicados completo, sin candidatos y **sin `scanCapped`**.
- `noop`: equivalencia normalizada, sin escritura ni auditoría de mutación.
- `update_ready`: identidad exacta de misma fuente y estado **draft/rejected**; cambios permitidos por `CameraRegistryService::updateDraft`. Otros estados `in_review/verified/active/inactive/retired` => blocked/manual_review sin mutar.
- Bloquear cambios de cobertura o municipio, geografía ambigua, saltos relevantes de posición, cambio peligroso de tipo, fuente sin verificar, duplicados cercanos o detector truncado. `snapshot` ausentes solo `missing_advisory`, **jamás retiro automático**; `delta` sin bajas implícitas. Comparación cross-source se rechaza.
- **Mutación exclusiva de cámaras por `CameraRegistryService::create/updateDraft`.** `create()` usa `forceFill($data + [...])`; el primer array tiene prioridad en PHP. Construir **whitelist cerrada**: `source_id,jurisdiction_id,geographic_unit_id,external_id,name,lat,lon,type,direction,bearing,corridor,speed_limit,notes`; los IDs de fuente/geografía se resuelven en servidor. Nunca pasar `camera_id,status,verified_at,created_by_id,updated_by_id`, campos de activación/verificación ni request/CSV íntegro. Altas obligatoriamente `draft`, ID servidor y `speed_limit_verified=false`.
- La migración **versionada** `2026_08_31_030100_create_cameras_table.php` **ya declara** UNIQUE(`source_id`,`external_id`). No crear otro índice por inercia: comprobar esquema e índice **real** en motor operativo (incluida MariaDB) y concurrencia de operadores. Si exige migración sobre tablas existentes, detener esa decisión, informar efectos/rollback y avanzar solo partes seguras.

## 5. Persistencia, integridad, atomicidad

- Reutilizar `Camera`, `CameraSource`, `Jurisdiction`, `GeographicUnit`, `CameraDuplicateDetector`, `DatasetAuditLogger`; no reimplementar ANSV/B07. Como máximo **una tabla** de lote `camera_csv_imports` y modelo equivalentes si no existe capacidad semánticamente idéntica. Un servicio y controlador pequeños, tres Blade, pruebas focales; cero dependencias nuevas, colas, cron o importadores XLSX/GeoJSON/NDJSON.
- Original y análisis normalizado: almacenamiento privado con nombres opacos, SHA-256 y versionado inmutable. Guardar en DB solo metadatos/referencias/contadores/versión/token; no archivos públicos ni logs con CSV crudo o datos personales. DB y filesystem **NO comparten una transacción**: escritura segura y limpieza solo temporales propios, sin prometer rollback del archivo.
- Selección identificada por **lote + versión/huella de análisis + fila inmutable**. POST Apply con auth+CSRF, revalidar permisos, SHA original/análisis, fuente, estado, autoridad, cobertura, identidad, colisiones/duplicados y filas **dentro de transacción DB** con locks adecuados; payload cliente no es autoridad. Si una seleccionada queda stale/insegura: **HTTP 409 y cero mutaciones en la selección**.
- Crear/actualizar/auditar cámaras y marcar lote aplicado en **una transacción DB**; error inducido => rollback completo de DB. Doble click, reupload y dos operadores => idempotencia demostrada en motor disponible; SQLite no certifica concurrencia real MariaDB. No permitir `applied` falso.
- NO editar ni publicar automáticamente `verified/active/inactive/retired`, NO cambiar datasets/releases/manifests, ni escribir datos móviles. La importación no acredita oficialidad.

## 6. Rutas previstas y QA

- Ajustar mínimamente `server/routes/web.php` y enlace `server/resources/views/admin/cameras/index.blade.php`. Nuevos `CameraCsvImportController`, `CameraCsvImportService`, `CameraCsvImport`, migración única justificada, `server/resources/views/admin/camera-imports/{index,create,show}.blade.php` y test Feature del flujo; no tocar `CameraRegistryService` salvo defecto demostrable con revisión explícita.
- Pruebas sintéticas: roles viewer/editor/reviewer/admin, CSRF/403, cabeceras/BOM/CRLF/comillas/multiline/codificación, límites 5MiB/2.000, ceros, rango/NaN, inyección fórmula, fuente/cobertura, duplicados/scanCapped, create/update/noop/blocked/invalid, snapshot/delta, comparación entre lotes, hashes stale/409, selección de otro lote, concurrencia/doble submit, rollback inducido, **cero publicación**, smoke Blade móvil/desktop.
- Tests focales primero: `php artisan test --filter=CameraCsvImport`; Pint `vendor/bin/pint --test` (en Windows usar `php vendor/bin/pint --test` según instalación); **una** suite Laravel completa final `php artisan test` con exit real, migraciones fresh/rollback en **DB sintética** y diff/secretos. Registrar PHP, motor SQLite/MariaDB y limitaciones exactas. No repetir los 3.253 tests Flutter si no se toca `mobile/**`.
- Condición `CSV_IMPORT_LOCAL_PASS`: flujo HTTP sintético, roles, idempotencia/concurrencia certificada para motor indicado, rollback, P0 cerrados, suite Laravel exit 0, cero publicaciones; de lo contrario `PARTIAL`, sin fingir PASS. CI de GitHub bloqueada por cuota no se intenta ni declara verde.

## 7. Leyes, bloqueos, entrega

- **KISS:** eficaz y simple, modular monolith; no capas redundantes. **Antirruido:** evidencia de consumidores antes de unir/eliminar, una sola fuente del contrato. **Antiparches:** solucionar origen/consumidores, no bypass, `sleep`, catches silenciosos, skips. **Diseño UX/UI Pro:** `docs/DESIGN_CONTRACT.md` y layout admin; sin skill no comprobada ni cambios owner/Flutter.
- Stop: índice/schema productivo de riesgo, ampliación de gates, pérdida de WIP, activación/publicación, integración histórica masiva, cambios C11/Flutter, dinero/CI, Hostinger, teléfono o modificación de `main`. Avanzar partes seguras y declarar bloqueos separados.
- Bloqueos heredados no incluidos: `REMOTE_CI_BLOCKED_QUOTA`; B06/B07 MariaDB/symlinks exFAT; archivo PS1 de navegador denegado; Android físico; #71 draft hacia main; WIP Windows desconocido.
- Resultado: **un solo PR Draft** nuevo hacia la rama moderna, un único `codex/B04_CSV_CAMERA_IMPORT_HANDOFF.md` con SHA/tree, permisos, cambios, tests, motor DB, bloqueos y NEXT. Ningún merge/deploy. **No afirmar código B04 terminado hasta tener commit y QA.**
