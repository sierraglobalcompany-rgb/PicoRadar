# PicoRadar — Auditoría forense de M1C en diez pasadas

**Fecha:** 2026-11-07 · **Alcance:** orden M1C existente, R21 y evidencias M1B, GitHub (solo lectura inicial), fuentes oficiales actuales. **Tipo:** auditoría PRE-EJECUCIÓN, NO ejecución de M1C ni auditoría completa de runtime.

**Decisión:** corregir M1C V1 en **M1C V2, mismo lote y TASK_ID**, para eliminar una premisa falsa sobre el escritor del JSON runtime y riesgo de falso no-encontrado por sparse checkout. No abrir M1D, no reejecutar M1B, no crear arquitectura nueva.

| # | Control | Resultado | Evidencia | Acción única |
|---|---|---|---|---|
| 1 | Integridad de paquete M1C V1 | **PASS_DOCUMENTAL** | ZIP SHA f11c62...; CRC PASS; 5/5 miembros; sidecar de manifest válido | Conservar evidencia, no repetir entrada |
| 2 | Consistencia matriz 15 | **PASS_DOCUMENTAL** | 15 filas; 8 CORE; 7 pendientes; 15 runtime_publish_allowed=NO | No promocionar editorial a producción |
| 3 | Proveniencia y rama | **PASS HISTORICO; PENDIENTE EN CLON** | R21 H4 1b5badd9 tree dc2f2f..., PR71 0d3a6a2 previo a 101 WIP | Gate nuevo solo sobre clone aislado |
| 4 | Contrato seis leyes | **PASS PARCIAL** | AGENTS.md GitHub revisado; DOCX y leyes locales no leídas físicamente por director en este turno | Ejecutor debe leer originales/hashes; nunca inventar compliance |
| 5 | Dirección del generador | **ERROR MATERIAL CORREGIDO** | R21 confirma compile_pico_operational_catalog.py: workbook + runtime JSON → catálogo; NO runtime writer | No editar JSON generado ni crear nuevo motor; bloquear solo reglas con writer ausente |
| 6 | Sparse checkout y herramientas | **ERROR MATERIAL CORREGIDO** | R21 candidato sparse docs/mobile/server, scripts/data fuera de vista; rg solo visible produce falso NOT_FOUND | Usar git ls-tree/git show y sparse seguro sin Hostinger |
| 7 | Normas oficiales y fechas | **PASS NÚCLEOS; PARCIAL ÁMBITO** | Medellín, Bogotá, Cartagena, Dosquebradas, Villavicencio contrastados con medios oficiales 2026 | Tests de fecha local y excepciones; sin activar |
| 8 | Fronteras y seguridad vial | **RIESGO CONTROLADO** | Bogotá mes Nov/regional; Cartagena 2 franjas/moto centro; Villavicencio polígono; Medellín TTL | Unknown/stale si no hay perímetro/vigencia validado |
| 9 | No repetición de pruebas | **PASS EN CONTRATO** | No AOT/JNI/CI/Flutter global/R21 y 101 WIP profundos; solo tests de delta si procede | No reutilizar PASS de SHA distinto, release exige suite final |
| 10 | Plan final y GitHub | **LISTO PARA REGISTRO, NO EJECUTADO** | PR79 Draft documental, PR71 Draft intacto; M1C V2 único ZIP autocontenido | Actualizar plan/ledger en PR79; Codex solo después, un ZIP |

## Evidencia y conclusiones

- ZIP M1C V1: `f11c62efbac1913743ef17f66d1fa6cef0566cc914d94cdf2cce5f2548efd19a`; 7 entradas totales, 5 contenido, manifiesto validado 5/5, CRC PASS. ZIP M1B anidado `a7efa9a40bb2a273b2bd474e8166c5cae87ad297d85f51617897726464ecf991`.
- R21 V2 ZIP: `ffc3355569156f170e80ea7df4a886edef5afb351b097c179fada7fe3763e791`, local disponible e íntegro; R21 `FINAL_REPORT.md` documenta ausencia de writer reproducible de `restrictions_v1.json`, catálogo generado por `scripts/compile_pico_operational_catalog.py`.
- La matriz del director M1B tiene 15 filas, 8 núcleo publicados, 7 no cerrados, 15 `runtime_publish_allowed=NO`. No demuestra que el motor soporte zonas/reglas completas.
- Fuente GitHub de verdad: `AGENTS.md` y `docs/CURRENT.md` en rama moderna; PR79 es documental Draft y PR71 recuperación Draft con HEAD antiguo.

## Las correcciones V2 que sí ameritan edición de la orden

1. Crear tabla de **dirección del generador**: Excel + runtime JSON → catálogo, NO al revés. G2 del prompt original no puede exigir editar un writer no identificado.
2. Distinguir archivo no visible en sparse de archivo no rastreado en Git. No materializar script Hostinger ni ejecutar ese test.
3. G0 debe verificar los dos ZIP anidados y el manifiesto; no confundir SHA del insumo con SHA del paquete final.
4. Mantener 8 filas comparativas aunque haya bloqueos por fila con `NOT_COMPARED` explícito; no forzar `CORE_RULES_COMPARED=8` si no pasó G1.
5. No inferir región o tránsito libre: Cartagena motos centro, Bogotá regional, Villavicencio polígono y Medellín vías exentas siguen independientes.
6. Acotar tests a deltas y mantener `RELEASE=NOT_APPROVED`, sin nuevos CI/Android, antes de comparación de fuente real.

## Plan de salida

M1C V2: (A) validar base H4 / leer leyes, (B) comparar ocho núcleos contra runtime/generador, (C) aprobar cero cambios si match, o parche mínimo si existe writer preaprobado, (D) ejecutar tests focales sobre delta y demostrar no-falso-libre, (E) un ZIP final único. Si writer ausente, entregar decisión de director concreta y seguir a restantes sin inventar fuente. Luego M1 cobertura nacional resto → M2 agente/motor → M3 Laravel/Flutter/cámaras → M4 CI/QA física/firma/release.

**No realizados en esta auditoría:** revisión física de las seis leyes locales y dos DOCX de baseline; tests Flutter/Laravel; validación de GIT en Windows; comparación real de ocho IDs runtime; QA Android, CI y release. Esos estados permanecen `NOT_RUN` para M1C, no PASS.