# PicoRadar B04-CSV — único checkpoint de implementación (2026-10-21)

**Estado: IMPLEMENTED_DRAFT / REMOTE_STATIC_QA_PENDING / RUNTIME_QA_NOT_RUN / NO_MERGE.**

- Repositorio: sierraglobalcompany-rgb/PicoRadar, base recovery/20261019-modern @ 0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a.
- PR funcional: #75 Draft a recovery/20261019-modern. PR de contrato/portabilidad: #74 Draft, separado (no dependencias de runtime). NO trabajar desde main histórico.
- Únicamente cambios Laravel: un servicio parser, un preview, un servicio de importación, un controlador admin, un modelo y una migración de lote, tres Blade, link de cámaras, rutas web, pruebas; cero dependencias, Flutter/Hostinger/cámaras en producción intocados.

## Función B04 escrita (todavía no validada con PHP/Laravel)

1. Carga CSV UTF-8/BOM RFC4180, 5 MiB/2000 filas, encabezados estrictos; municipio 5 dígitos textuales, WGS84, tipos actuales y lista blanca de columnas.
2. Preview clasificado: create_ready, update_ready, noop, invalid, blocked, duplicate; fuentes verificadas, cobertura municipal, snapshots ausentes advisory, duplicado en cámara existente y entre filas; scanCapped fail-closed.
3. Persistencia de lote nuevo aislado: camera_csv_imports; archivos privados en el disco local, rutas aleatorias y hash SHA256 original/análisis, auditoría, estado review/applied. No crear otras tablas ni índices de cámaras: migración histórica ya declara UNIQUE(source_id,external_id); falta comprobar el índice del motor real.
4. Panel admin con tres vistas (batches, upload, review); GET template/report; comparación solo misma source/jurisdiction. Report neutraliza fórmulas; DANE conserva ceros iniciales para hojas de cálculo.
5. POST Apply exige Gate cameras.edit **y** cameras.review. Selección explícita, SHA de revisión, nueva clasificación dentro de DB transaction y locks; valida todas las seleccionadas antes de mutación, después crea por CameraRegistryService::create con lista cerrada sin campos de ciclo de vida, actualiza solo draft/rejected por updateDraft. 409 ante stale; idempotencia si lote ya aplicado; rollback de DB si falla una fila/auditoría. NO verifica, activa, retira ni publica cámaras.
6. 8 unit parser, 5 preview Feature, 13 import Feature: **26 métodos de prueba escritos pero aún NO EJECUTADOS**. No CI verde: Actions tiene bloqueo de cuota con zero steps.

## Gates y bloqueos reales

- **P0 QA requerido antes de merge/despliegue:** php -l de archivos nuevos/modificados PHP; php artisan route:list y Blade compile; php artisan test --filter=CameraCsv; Pint; full php artisan test UNA vez; fresh migration/rollback sobre DB sintética; MariaDB 11.8.8 isolated, controles sobre índice UNIQUE, bloqueo en concurrencia, roles, stale-409, rollback inducido, archivos privados, CSV malformado, comparación/report.
- No afirmar atomicidad de filesystem (archivos primero, DB después, limpieza solo de folder propio). Transacción garantizable exclusivamente para mutaciones DB.
- **Concurrencia residual a examinar:** dos importadores usan locks de lotes/fuente/jurisdicción y UNIQUE de identidad, pero creación manual simultánea fuera de este servicio requiere verificar comportamiento del detector de proximidad. No certificar ese escenario hasta prueba en MariaDB; si falla, corregir origen común en Registry, no parche en importador.
- CI remota no gastable mientras cuota siga agotada. El bloqueo local Windows exFAT/symlinks de B06/B07 es separado; no sustituir con copia ni alterar worktrees.
- Sin alterar usuario Android, datasets/releases o camera status activo, sin despliegue Hostinger ni main, sin merges automáticos ni exportar archivos privados a git.

## NEXT único

**Ejecutar validación local restringida del PR #75 en clon seguro**, comprobar sintaxis y runtime; corregir solo fallos evidenciados en el MISMO PR; completar verificación de MariaDB y auditoría de seguridad antes de cualquier merge. Evitar volver a construir documentación en paralelo o reejecutar suite Flutter sin cambios móviles. Si no hay entorno, estado PARTIAL y no declarar funcionalmente listo.
