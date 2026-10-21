# B04 CSV — checkpoint real en GitHub (2026-10-21)

Estado: PARSER_AND_PREVIEW_WRITTEN / BATCH_SCHEMA_WRITTEN / NO_HTTP / NO_APPLY / RUNTIME_QA_PENDING.

Base: recovery/20261019-modern @ 0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a. Contrato completo: codex/lots/B04_CSV_CAMERA_IMPORT.md en PR documental #74, todavía Draft. Este PR funcional #75 es independiente y también Draft.

## Código publicado

- CameraCsvParser: CSV UTF-8/BOM/RFC4180 con 5 MiB, 2000 filas, encabezados cerrados, campos seguros, WGS84, números, formula injection al exportar.
- CameraCsvPreviewService: análisis de create_ready, update_ready, noop, invalid, duplicate, blocked; fuente activa/verificada, cobertura municipal y jurisdicción habilitada; prohíbe estados de cámara no editables y cambios peligrosos; duplicados del registro y proximidad entre filas, scanCapped fail-closed; snapshot ausentes solo advisory. Preview jamás guarda cámaras.
- CameraCsvImport: modelo de lote + migración separada camera_csv_imports para fuente, jurisdicción, rutas privadas y SHA-256, counts, actor y estado. La migración NO está aplicada en ningún entorno por este chat.
- PHPUnit: 8 pruebas unitarias de parser y 5 Feature de preview, SOLO ESCRITAS; no ejecutadas en Laravel (CI GitHub reportó jobs sin pasos por bloqueo de cuota).
- Corrección auditada para lotes con 3+ candidatos próximos: el conjunto completo se clasifica bloqueado.

## Bloqueos y NEXT exacto

P0 pendiente: almacenamiento privado de snapshot inmutable; controlador y tres Blade; reportes y comparación; Gate edit+review; token revisión SHA; relectura anti-stale 409 dentro de transacción; locks, rollback e idempotencia; escritura SOLO por CameraRegistryService con lista cerrada sin camera_id/status/verificación; pruebas de permisos, concurrencia, migración y Laravel global.
NO exponer rutas POST Apply ni conectar el modelo a una UI hasta resolver esos P0. Implementar en EL MISMO PR #75 sin hacer merge ni tocar main/Hostinger/C:/D:/Android.

Validar con php -l, PHPUnit focal y Pint en PHP 8.3–8.5 con dependencias reconstruidas; luego una suite Laravel completa y prueba MariaDB aislada. No afirmar PASS de runtime hasta disponer de salidas reales.
