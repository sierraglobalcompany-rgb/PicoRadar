# PicoRadar B04 — importador CSV de cámaras

**Estado:** `B04_PARTIAL` · **sin merge / sin deploy** · 2026-10-21
Este es el único handoff vigente del lote. Los registros antiguos se resumen en “Historial de evidencia”; sus recuentos pendientes quedan reemplazados por la ejecución final descrita aquí.

## Estado y Git

- Repositorio: `sierraglobalcompany-rgb/PicoRadar`; PR [#75](https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/75), abierto y Draft.
- Rama: `feat/B04-csv-safe-parser`; base `recovery/20261019-modern` en `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`.
- HEAD remoto al reanudar: `90e6ea68507def1f43dae1e58472f5f7981e3e02`. HEAD de código probado: `43dc4379c548564d5c8c0dfa2e6827e5b3bff927`; tree `1cc1790e0b99c093205a675c80ffd1927e20e1bb`.
- Publicación autenticada y fast-forward sin force: Git local rechazó autenticación (`Repository not found`), por lo que se publicaron vía GitHub API commits aditivos con mismos contenidos y árboles. Mapeo de commits locales→GitHub: `99fec06`→`4ebed6e3b0fc45246a49ab7dca47d470710dc51e` (tree `16e54981d2b41547860ce124f0fd3a8af05f8dcd`); `6bf3e1b`→`3411f5b076e6e8aae6d9cda708938b8b59de89aa` (tree `99b0dc943bd24ae67e49eb1c8f4447be8e28cfe1`); `22e0adf`→`8c8a2a1d1956c65b9077685f0e7ec0590b0a572e` (tree `a94e040ccb7a33a12f03ec4de1a63d1daa99baf4`); `43dc437`→`725ee7af9645b1183863b478cb8f348473f5496e` (tree `1cc1790e0b99c093205a675c80ffd1927e20e1bb`); `72ea2b3`→`e3c10cdd27b99be82ba0ecc452ec0f7a461bc294` (tree `30514334200a5d2a3d9f11fed77c27b09a85b6dd`); `8c6be05`→`a16c30cf7a9dbfd6fae8a36ae1b611e7c98a6c82` (tree `04f75f30e94425063bb067ae3ca0b97b9d2a2d2c`); `531061d`→`3a6f059389c05da5154cb4cbe942b48d29a3dd79` (tree `be109561edf2c890a8f126bd5a75b70508159654`). Cada tree remoto coincidió con su objeto local antes de mover la rama. Último head verificado antes de esta actualización documental: `3a6f059389c05da5154cb4cbe942b48d29a3dd79`, tree `be109561edf2c890a8f126bd5a75b70508159654`; PR #75 abierto/Draft, base `recovery/20261019-modern` sin cambios, 83 commits y 22 archivos.
- El checkout de trabajo antes de esta actualización documental estaba limpio en `531061db308519f18a1e489e0d3a55abb7ba7aac`, tree `be109561edf2c890a8f126bd5a75b70508159654`; `ahead 7` frente al tracking local obsoleto en `90e6ea...`. `git diff --check HEAD~7..HEAD` pasó. La referencia remota se movió por fast-forward y se verificó por separado.
- PR #75 conserva su base y estado Draft. No se fusionó, no se hizo force-push, no se modificó `main` ni el branch base.
- QA final: clon limpio desechable, independiente del checkout original; runtime PHP aislado en Docker, SQLite `:memory:`. Los logs y fixtures sintéticos permanecen en evidencia local privada, fuera del repositorio.

## Resultado

B04 sigue sin publicar cámaras ni releases. La carga analiza bytes privados y genera preview; Apply exige selección, permisos y huella de análisis, revalida estado bajo locks y usa el servicio de registro para crear o actualizar únicamente borradores. No se cambió el móvil ni se añadió dependencia.

Se corrigió un defecto reproducido: una selección que queda obsoleta devuelve HTTP 409, pero el controlador dejaba que Laravel mostrara su error genérico. Ahora devuelve una vista B04 con explicación, acción de reanálisis y garantía visible de que esa petición no aplicó cambios. La regresión comprueba el estado, el texto y la ausencia de escrituras.

Commits nuevos de código: `22e0adf` (respuesta operable al 409) y `43dc437` (orden de imports requerido por Pint). Se conservaron los commits previos `99fec06` y `6bf3e1b` de esta misma rama.

## Gates G0–G6

| Gate | Estado | Evidencia / límite |
|---|---|---|
| G0 — Protección Git | PASS | Rama y base identificadas; clon de QA independiente, limpio antes de ejecutar el script. No se modificaron otros worktrees. |
| G1 — PHP / Laravel | PASS con avisos | `scripts/qa_b04_csv.ps1` terminó con `B04_LOCAL_SQLITE_QA_PASS`, exit 0 y 24 checks. PHP 8.5.12; 15 `php -l`, siete nombres+métodos de ruta, Pint 258 archivos, suite focal y completa. El entorno limpio no tenía `.env`; el runner reportó 436 warnings, incluidas lecturas Dotenv fallidas de `/repo/server/.env`, sin fallos de aserción; resultado global 220 passed, 1 skipped, 3.017 assertions, 432,78 s. No se ocultaron ni se suprimieron avisos. |
| G2 — MariaDB | PASS | MariaDB 11.8.8 sintética y aislada: 103 tests / 459 assertions; `migrate:fresh` y rollback/migrate del lote; InnoDB + `utf8mb4_unicode_ci`; UNIQUE `(source_id, external_id)` confirmado y `EXPLAIN` usa ese índice (`const`, 1 fila). Casos `00123`, `123` y `123ABC` incluidos. |
| G3 — Concurrencia | PASS | M1–M5: dos conexiones simultáneas observadas esperando locks; una sola cámara/auditoría o conflicto 409 según caso. M6: fuente obsoleta durante espera → 409 y cero mutaciones/auditorías. M7: fallo de auditoría revierte la transacción; replay concurrente aplica una sola vez. Sin `sleep` para sincronizar. |
| G4 — UX/UI | PASS con alcance visual acotado | Navegador local sintético validó preview batch #2 con 2.000 `create_ready` y stale Apply con página de conflicto/`role=alert` en 1440×900, 768×1024, 390×844 y 360×800. El documento no tuvo overflow; en móvil el scroll horizontal quedó dentro de la tabla (390 px: tabla 558 / wrapper 310; 360 px: 558 / 280). La respuesta explica que no hubo cambios y ofrece reanálisis/retorno. Métricas durables en evidencia privada local; capturas renderizadas en el transcript, no exportadas a imagen. No se encontró mockup aprobado del administrador (`NO_APPROVED_B04_ADMIN_MOCKUP`), por lo que no se declara pixel-perfect. |
| G5 — Seguridad / regresión | PASS | Permisos, CSRF, reporte CSV, datos privados, stale/409, Registry y ANSV cubiertos por las suites; IDs sintéticos; no se encontraron secretos nuevos en el delta. Apply no activa, verifica, retira ni publica cámaras. Sin cambios de schema/dependencias en esta corrección. |
| G6 — Handoff / PR | PASS tras publicar este commit | Solo cambia el handoff existente como documentación. PR #75 se mantiene Draft y abierto, base intacta. Diff revisado; no merge ni deploy. No se inició manualmente ni se reintentó Actions. |

## Comandos y resultados exactos

- `pwsh -NoProfile -File scripts/qa_b04_csv.ps1` en el clon limpio, usando `php` del contenedor aislado `picoradar-b04-fullqa-php-20261021`: exit 0; 24 checks. El contenedor aportó `mbstring`, `pdo_sqlite` y `fileinfo`; no se alteró PHP global de Windows.
- `php artisan test --filter=CameraCsvImportTest` con SQLite explícita: 29 passed / 152 assertions.
- Filtro final `CameraCsv`: 52 métodos ejecutados; 13 passed y 39 warnings por el `.env` inexistente; 218 assertions.
- Suite Laravel completa: 220 passed, 436 warnings, 1 skipped; 3.017 assertions, exit 0. Los warnings de Dotenv se reportan como tales, no como un resultado sin advertencias.
- MariaDB focal: 103 passed / 459 assertions. Concurrencia: matriz M1–M7 completa.
- `php artisan route:list --json --path=admin/cameras/imports`: siete rutas y métodos esperados. `php vendor/bin/pint --test`: 258 archivos, pass. `npm run build`/Vite: pass.
- CI: no se inició manualmente ni se reintentó. El push disparó automáticamente Server CI run #192 (`https://github.com/sierraglobalcompany-rgb/PicoRadar/actions/runs/39711261522`), que terminó `failure`; cuatro jobs fallaron y el conector no expuso pasos (`steps=0`). No se atribuye causa sin logs ni se reporta CI verde. La cuota de Actions sigue sin disponibilidad.

## Cambios y alcance

- `server/app/Http/Controllers/Admin/CameraCsvImportController.php`: convertir solo el HTTP 409 stale en respuesta operable; otros errores se vuelven a lanzar.
- `server/resources/views/admin/camera-imports/conflict.blade.php`: explicación accesible con acción para analizar CSV de nuevo y volver a lotes.
- `server/tests/Feature/CameraCsvImportTest.php`: verifica 409, copy útil y cero altas/cambios.
- `codex/B04_CSV_CAMERA_IMPORT_HANDOFF.md`: este único handoff actualizado.
- Sin migración nueva, paquetes, cambios Flutter, publicación de datasets, producción, Hostinger ni Mi A3.

## Historial de evidencia y recuentos reconciliados

Los checkpoints anteriores alternaban entre “54” y “55 pruebas nuevas escritas” y contenían smokes de parser/detector que no eran PHPUnit. Al reanudar había 55 métodos nuevos: 13 Parser + 10 Preview + 29 Import + 3 Registry. Los filtros y la suite final ahora los ejecutaron; el estado exacto (passed/warnings/skipped) se conserva arriba. Los smokes históricos de parser (28 casos con sustitutos de mbstring) y detector (9 escenarios con consultas simuladas) quedan como evidencia previa, no sustituyen PHPUnit/MariaDB. La evidencia de concurrencia y esquema listada en G2/G3 es de la base sintética de esta auditoría. Los logs extensos, fixtures y métricas visuales permanecen locales y no se añadieron al Git. Las capturas de esta sesión se mostraron inline, pero no quedaron exportadas como imágenes.

## Riesgos, QA manual y dispositivo

- G4 quedó cerrado en la instancia sintética local. Fixture 2.000 filas SHA-256 `39d184987647a6b87dab9064da064ee656eec0ba425a45aaa79440c7f52e8db9`; batch #2 conserva 2.000 filas en `review`, `applied_at=null`; contador de cámaras `B04-SPREAD-*`=0. Fuente `b04-ui-demo` restaurada a `Synthetic authority` y verificada; `updated_at` avanzó por la mutación controlada y su restauración.
- El primer batch (#1) usó coordenadas idénticas y quedó correctamente con 2.000 filas bloqueadas por proximidad; es ruido sintético de esta QA, no defecto del producto. No se modificaron cámaras.
- Última limitación: no hay mockup administrador aprobado y las imágenes no se exportaron. La evidencia de métricas está en el archivo local privado `browser-b04-visual-evidence.txt`; no se incluyó su ruta local en Git.
- QA físico Android: `Not required` para este lote de Laravel; no se conectó ni probó Mi A3.
- Los avisos Dotenv de la suite completa provienen de no tener `.env` en el clon recién creado. No se copió un `.env` ni se guardó una clave; el script proveyó `APP_KEY` efímera por proceso y SQLite en memoria.
- Dependencias añadidas/cambiadas: ninguna. Datos de prueba: únicamente sintéticos.
- El límite de cuota de Actions impide certificar CI; la evidencia local no se presenta como Actions.

## NEXT ÚNICO

Con cuota disponible, inspeccionar una sola ejecución de Server CI sobre el HEAD vigente de PR #75; leer los logs completos, corregir solo fallos reproducibles y dejar la suite verde. Mantener el PR en Draft y sin merge. Después de revisión humana, seleccionar y delimitar el siguiente lote funcional desde el HEAD moderno conforme a `docs/CURRENT.md`.
