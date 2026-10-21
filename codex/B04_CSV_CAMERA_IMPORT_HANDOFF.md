# PicoRadar B04-CSV — único checkpoint de implementación (2026-10-21)

**Estado: IMPLEMENTED_DRAFT / REMOTE_STATIC_REVIEWED / LOCAL_QA_BLOCKED / RUNTIME_QA_NOT_RUN / NO_MERGE.**

- Repositorio: sierraglobalcompany-rgb/PicoRadar, base recovery/20261019-modern @ 0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a.
- PR funcional: #75 Draft a recovery/20261019-modern. PR de contrato/portabilidad: #74 Draft, separado (no dependencias de runtime). NO trabajar desde main histórico.
- Únicamente cambios Laravel: un servicio parser, un preview, un servicio de importación, un controlador admin, un modelo y una migración de lote, tres Blade, link de cámaras, rutas web, pruebas; cero dependencias, Flutter/Hostinger/cámaras en producción intocados.

## Función B04 escrita (todavía no validada con PHP/Laravel)

1. Carga CSV UTF-8/BOM RFC4180, 5 MiB/2000 filas, encabezados estrictos; municipio 5 dígitos textuales, WGS84, tipos actuales y lista blanca de columnas.
2. Preview clasificado: create_ready, update_ready, noop, invalid, blocked, duplicate; fuentes verificadas, cobertura municipal, snapshots ausentes advisory, duplicado en cámara existente y entre filas; scanCapped fail-closed.
3. Persistencia de lote nuevo aislado: camera_csv_imports; archivos privados en el disco local, rutas aleatorias y hash SHA256 original/análisis, auditoría, estado review/applied. No crear otras tablas ni índices de cámaras: migración histórica ya declara UNIQUE(source_id,external_id); falta comprobar el índice del motor real.
4. Panel admin con tres vistas (batches, upload, review); GET template/report; comparación solo misma source/jurisdiction. Report neutraliza fórmulas; DANE conserva ceros iniciales para hojas de cálculo.
5. POST Apply exige Gate cameras.edit **y** cameras.review. Selección explícita, SHA de revisión, nueva clasificación dentro de DB transaction y locks; valida todas las seleccionadas antes de mutación, después crea por CameraRegistryService::create con lista cerrada sin campos de ciclo de vida, actualiza solo draft/rejected por updateDraft. 409 ante stale; idempotencia si lote ya aplicado; rollback de DB si falla una fila/auditoría. NO verifica, activa, retira ni publica cámaras.
6. 11 unit parser, 8 preview Feature y 18 import Feature: **37 métodos B04 escritos pero aún NO EJECUTADOS**... Casos adicionales: identidad case-fold, bytes originales únicos, controles en ID, cámara en revisión posterior al preview, selección parcial, reintento con selección distinta. No CI verde: Actions tiene bloqueo de cuota con zero steps.

## Gates y bloqueos reales

- **Correcciones P0 incorporadas al PR #75:** parseBytes del mismo blob guardado/hasheado (sin segundo read); bloqueo conservador de external_id duplicados con diferencias de mayúsculas según collation MariaDB; huella aplicada de selección ordenada para idempotencia exacta y 409 con selección distinta.
- **Verificador local único:** scripts/qa_b04_csv.ps1 en la propia rama. Debe ejecutarse solo en un clon limpio aislado y con dependencias instaladas, nunca en C:/D: en uso; realiza preflight read-only, php -l, rutas, Pint, tests B04 focales y suite Laravel global. Un PASS solo certifica SQLite/PHP de ese clon, no MariaDB ni Android. No se ejecutó aquí porque faltan Composer, mbstring y pdo_sqlite.
- **P0 QA requerido antes de merge/despliegue:** php -l de archivos nuevos/modificados PHP; php artisan route:list y Blade compile; php artisan test --filter=CameraCsv; Pint; full php artisan test UNA vez; fresh migration/rollback sobre DB sintética; MariaDB 11.8.8 isolated, controles sobre índice UNIQUE, bloqueo en concurrencia, roles, stale-409, rollback inducido, archivos privados, CSV malformado, comparación/report.
- No afirmar atomicidad de filesystem (archivos primero, DB después, limpieza solo de folder propio). Transacción garantizable exclusivamente para mutaciones DB.
- **Concurrencia residual a examinar:** dos importadores usan locks de lotes/fuente/jurisdicción y UNIQUE de identidad, pero creación manual simultánea fuera de este servicio requiere verificar comportamiento del detector de proximidad. No certificar ese escenario hasta prueba en MariaDB; si falla, corregir origen común en Registry, no parche en importador.
- CI remota no gastable mientras cuota siga agotada. El bloqueo local Windows exFAT/symlinks de B06/B07 es separado; no sustituir con copia ni alterar worktrees.
- Sin alterar usuario Android, datasets/releases o camera status activo, sin despliegue Hostinger ni main, sin merges automáticos ni exportar archivos privados a git.

## NEXT único

**Ejecutar validación local restringida del PR #75 en clon seguro**, comprobar sintaxis y runtime; corregir solo fallos evidenciados en el MISMO PR; completar verificación de MariaDB y auditoría de seguridad antes de cualquier merge. Evitar volver a construir documentación en paralelo o reejecutar suite Flutter sin cambios móviles. Si no hay entorno, estado PARTIAL y no declarar funcionalmente listo.


## Una sola intervención local en Codex (cuando se autorice ejecutar QA)

Objetivo: certificar PR #75 sin ping-pong y sin tocar worktrees históricos. Codex debe clonar `feat/B04-csv-safe-parser` a una carpeta nueva disponible en disco compatible, SIN `reset`, `clean`, `stash` ni sobreescribir C:/D:. Antes de instalar, inventariar read-only el WIP y worktrees previos y preservar hallazgos. Leer este handoff, `AGENTS.md`, `docs/SOP.md`, contrato B04 del PR #74, `README.md`.

Aprovisionar PHP 8.3–8.5, extensiones y Composer sin actualizar lockfiles; en el **nuevo clon únicamente**, instalar dependencias del `server/composer.lock`. Ejecutar `pwsh -File scripts/qa_b04_csv.ps1` con salida, código de retorno y rutas registradas. El script ya verifica lint, rutas, Pint, B04 focal y suite Laravel completa; no repetir suites innecesariamente. Completar en MariaDB 11.8.8 **sintética y aislada** pruebas de migración+rollback, UNIQUE fuente/external_id, permisos, 409, rollback de doble operación y carrera de dos operadores (también versus alta manual). Nunca usar DB real/Hostinger.

Si las pruebas revelan fallos: reparar **origen y consumidores**, no añadir parches ni permisos falsos; actualizar el **mismo PR #75**, sin merge, recoger SHA final y dar un **único informe** con comandos, PASS/FAIL, defectos corregidos, evidencias, bloqueo real y NEXT. Si hay bloqueo de ambiente no eludirlo ni certificar PASS. Sin tocar Android, main o PR #71.


## Hallazgos centrales y compatibilidad ANSV (última auditoría)

**P0 resuelto en código, no certificado en runtime:**
- `CameraRegistryService::create()` rechazaba antes indirectamente cero campos de ciclo de vida: el operador PHP `$data + [...]` permitía que `status`, `camera_id` y autorías del llamador ganaran. Ahora verifica `Camera::getFillable()`, rechaza cualquier campo ajeno y aplica obligatoriamente `status=draft`, `camera_id` e IDs de auditoría desde el servidor.
- Importador oficial ANSV **requiere** `camera_id=cam_` seguido de los primeros 26 hex de `source_row_identity`. Se conserva mediante el **tercer argumento interno** `create($attributes, null, $trustedId)`; no debe exponerse como campo HTTP. El método valida `^cam_[0-9a-f]{26}$`. La prueba histórica `AnsvRichCameraImportTest::test_idempotent_reimport_keeps_b03_master_and_provenance_stable` comprueba la identidad determinista y DEBE pasar con la suite global.
- Para evitar altas manuales entre Preview y Apply, creación y modificación de cámaras adquieren locks en **orden fijo**: fuentes por ID, jurisdicciones por ID, luego cámara. Apply ya bloquea fuente y jurisdicción; también cubre fuentes diferentes que reportan cámaras cercanas en la misma jurisdicción. Probar dos conexiones MariaDB: source-source, intersource same-jurisdiction, source move, manual create vs CSV apply, estatus transition y ANSV import. Las pruebas SQLite no certifican locking.
- Preview compara proximidad dentro de la misma jurisdicción aunque los códigos de municipio difieran (municipios fronterizos de una cobertura). Se añadió la prueba de regresión.
- Las 11 + 8 + 18 = **37 pruebas B04** son nuevas; hay **3 regresiones adicionales** en `CameraRegistryTest` sobre rechazo de campos reservados, autoría y preservación ANSV: **40 pruebas nuevas de esta implementación** (además de 33 métodos históricos en `AnsvRichCameraImportTest`). No se ha ejecutado ninguna de estas pruebas en este chat.

## QA pendiente innegociable

En el MISMO clon QA aislado de Codex, ejecutar el script `scripts/qa_b04_csv.ps1` (incluye lint de Registry y CameraRegistryTest), y la suite Laravel completa que **también cubre ANSV**. Hacer las carreras de MariaDB en dos conexiones reales sobre datos sintéticos y confirmar bloqueo de filas/orden, unicidad y rollback. Si aparecen errores de deadlock/locking, reparar la causa y consumidores en este PR antes de declarar cualquier PASS. No aprobar ni fusionar PR #74/#75 de forma automática.

## Auditoría de ejecución y seguridad — último avance

- Rendimiento SQL: Preview conserva `LOWER(external_id)` con parámetros para SQLite, y emplea `whereIn(external_id)` indexable en MariaDB/MySQL bajo el `utf8mb4_unicode_ci` configurado. La semántica de collation **real** todavía debe validarse en MariaDB aislada; no asumir índice o cobertura Unicode sin EXPLAIN y pruebas.
- Conflictos: Apply traduce SQLSTATE de unicidad/deadlock y los errores de transición de CameraRegistryService a `409`; toda mutación ocurre bajo `DB::transaction`. Las condiciones de carrera deben certificarse mediante conexiones reales.
- Integridad histórica: la repetición idempotente de un lote ya aplicado **también** verifica original y análisis privados contra SHA-256 antes de informar éxito. Un archivo alterado responde `409`; se agregó prueba de regresión.
- **Inventario exacto:** 11 Unit Parser + 8 Feature Preview + 18 Feature Import = 37 métodos B04; más 3 nuevas regresiones dentro de CameraRegistryTest = **40 métodos de prueba nuevos**, todavía no ejecutados. La suite global también debe incluir AnsvRichCameraImportTest, sin cambiar identidad determinista.
- **Estado:** GitHub/static verificado, ejecución PHP/Laravel, rollback MariaDB y QA de UI reales **pendientes**. No CI PASS, no merge, no despliegue.
