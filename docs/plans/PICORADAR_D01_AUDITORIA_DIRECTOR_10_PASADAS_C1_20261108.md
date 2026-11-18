# PicoRadar — Auditoría forense D01, diez pasadas, decisión causal C1 y plan de cierre

**Fecha de corte:** 2026-11-08 (America/Bogota). **Director:** ChatGPT. **Ámbito:** ZIP real M1F-D01 + contraste de GitHub/contrato temporal, no release.  
**Resultado del ejecutor:** `D01_BLOCKED_CONTRACT`; **dictamen del director:** `D01_PARTIAL_VERIFIED_WITH_DESIGN_DECISION_C1`.  
**Próximo actor:** Codex Luna **solo para continuar el mismo D01 en la misma rama hija**, y después ChatGPT. **Sin publicación, push, merge ni despliegue.**

## Evidencia primaria e independencia

- Archivo ZIP **recibido y abierto**, 19.612 bytes, SHA256 `83ebd895d29d0150f1bb235407cf465ebf94530b9fcaa56220602cf69a639b98`. `ZipFile.testzip()` retorna `None`; 11 miembros sin rutas peligrosas, nueve payloads con tamaño, SHA y CRC correcto. `MANIFEST.json` SHA `52845570776304f3615bf69bdfaf1d28f729f84ff545d272691b32342f530e79`, concordante con `MANIFEST.sha256`. Patch `99541a9be4160bfeb9dc662ffbe18e1120dc1dca85b147810fe5c037b52fc4f3`.
- Se inspeccionaron `FINAL_REPORT.md`, `GIT_LOCAL_PROVENANCE.txt`, `SCOPE_AND_LAWS.md`, `PATCH_D01.diff`, `TEST_COMMANDS_RAW.log`, `RED_RAW.log`, `TEMPORAL_CONTRACT_MATRIX.csv`, `COVERAGE_STALENESS_MATRIX_D01.csv` y `AUDIT_10_D01.csv` del ZIP; no se sustituyeron sus afirmaciones por un PASS global.
- Se reconstruyó *independientemente* una clase PHP usando `BASELINE_H4_RestrictionContractValidator.php` + `PATCH_ACCEPTED.diff` del ZIP M1F y `PATCH_D01.diff` del ZIP D01. `git apply --check`/aplicación del hunk del validador y `php -l` PASS sobre la copia temporal. No equivale a construir Laravel completo ni probar el dispositivo.
- El director aplicó **solo en esa copia** una normalización de `validUntil` de fecha corta (calendario) a 23:59:59.999999 de `America/Bogota`, conservando los timestamps explícitos. PHPUnit no fue usado en esa prueba: se ejecutó la clase PHP directamente. Tres escenarios: fin 7/oct en fecha corta + inicio 7/oct 12:00 → conflicto rechazado; fin timestamp 7/oct 23:59:59 + inicio 12:00 → rechazado; fin 6/oct → aceptado. Dataset schema2 inmutable: 9 jurisdicciones PASS, Bogotá FAIL `staleAfter must be later than verifiedAt.` Ningún archivo del usuario ni su repositorio local fue modificado por ChatGPT.
- El GitHub PR #79 contiene el Plan Maestro, contrato del agente y libro SRC; PR #71 remoto es más antiguo que el código local H4. No se atribuye este arreglo local a GitHub como código integrado.

## Diez pasadas distintas, con resultado

| # | Control | Estado | Observación y decisión |
|---|---|---|---|
| 1 | Autenticidad de ZIP | **PASS** | SHA externo, tamaño, CRC de 11 entradas. |
| 2 | Manifiesto/payloads | **PASS** | 9/9 SHA/CRC/tamaños coinciden; no hay artefacto de publicación. |
| 3 | Git y alcance | **PARCIAL** | HEAD local M1F informado `a4e80fbc...`, branch hija limpia de remotos, cinco archivos modificados sin stage/commit. El ZIP prueba diff/hash, no permite consultar objetos Git del host. 101 WIP `NOT_VERIFIED`. |
| 4 | D2 PHP, código | **PASS estático/reconstruido** | Corte más temprano entre `staleAfter` y `nextReviewAt` existe; rechaza TTL anterior a sourceCheckedAt. |
| 5 | Pruebas PHPUnit D2 | **PASS reportado** | Log del ejecutor: 30 unit tests, 69 assertions y exit 0; no llamarlo suite Laravel completa. |
| 6 | D1 fin de calendario | **P1 ABIERTO, solución mínima comprobada en copia** | El RED sobre parent M1F permite solape por fecha corta. Copia PHP del director rechaza correctamente 7/oct y acepta 6/oct. No se ha implementado ni probado en Flutter H4. |
| 7 | Compatibilidad motor/resumen | **PENDIENTE** | H4 local, según fuente aportada, usa DateTime instante en motor y cruce con día en resumen; son preguntas distintas. Normalizar fin de calendario solo donde se interpreta esa fecha; tests Flutter aún NOT_RUN. |
| 8 | Feature test / toolchain | **BLOCKED_ENV** | 7/7 feature errors en RefreshDatabase antes de aserciones, `pdo_sqlite` ausente, no fallo de API. Dart/Flutter NOT_RUN. La máquina del director tampoco tiene PDO SQLite ni Flutter. |
| 9 | Vigencia y datos | **FAIL de datos, NO del selector** | JSON runtime SHA `ce95ab...e38341` sin cambios. Bogotá moto: staleAfter 23/sep < sourceCheckedAt 24/oct, reviewAt 24/nov. Se debe rechazar; no renovar ni falsificar fechas. Matriz D01: nueve coberturas frescas y diez stale al corte de 8/nov según selector técnico, **no** operación legal aprobada. |
| 10 | L1–L6, finalización/continuidad | **PASS de dirección documental** | KISS/Ponytail; sin duplicados ni parches nuevos innecesarios; UX/arquitectura intactas; L5 no confunde ejecutado, reportado y NOT_RUN; L6 concentra C1 en mismo D01, una sola salida ZIP, sin abrir M1G. |

## Corrección de rumbo decidida

**No abrir nueva fase.** D01-C1 es continuación de `PICORADAR-M1F-D01-TEMPORAL-FRESHNESS-SAFETY-20261108-DIRECTOR`, misma rama y cinco rutas existentes.

1. **Contrato de calendario:** en schema2 con `legalValidFrom`, `validUntil` de solo fecha define final **inclusivo del día completo** en Colombia (instante antes de las 00:00 del día siguiente); timestamps explícitos conservan sus horas. `legalValidUntilExclusive` y `rotationPeriodEndExclusive` continúan **exclusivos**. Aplicar en validador PHP y parser Flutter, no reescribir motor ni resumen por analogía. Probar medianoche y fines de día con offsets.
2. **Contrato de frescura:** conservar fix D2 de `min(staleAfter,nextReviewAt)` cuando ambos existen; fallback legacy solo si uno existe, falta de ambos es fail-closed; rechazar `cutoff <= sourceCheckedAt`; no editar los JSON de fuente ni autorizar cirulación. Una fecha de revisión es distinta del TTL técnico.
3. **Entorno bloqueado:** una comprobación acotada de PHP SQLite y Flutter locales (PATH y herramientas previamente instaladas); si faltan, marcar BLOCKED y completar C1 sin falsificar PASS ni repetir este diagnóstico. El director decidirá luego CI/QA autorizado.
4. **Protección:** cinco rutas máximas existentes; sin cambios a original, 101 WIP, datos, API, dependencia, baseline, GitHub código, PR71, `main`, publicación o Android físico.
5. **Un ZIP** con patch acumulativo, hashes, logs crudos, pruebas, matriz de 19 coberturas, estado Git, auditoría de diez puntos y manifiesto. Actor posterior ChatGPT.

## Ruta de finalización del producto

| Paso | Salida necesaria | Bloqueo legítimo, no repetir trabajo |
|---|---|---|
| **D01-C1**, actual | Parser y PHP coherentes para fecha corta; PHP unit, pruebas Flutter/feature si entorno accesible; ZIP único. | Sin SDK/SQLite, reportar NOT_RUN/ENV_BLOCKED, sin reabrir diagnóstico. |
| **Admisión técnica del parche** | ChatGPT audita diff+SHA; GitHub code branch/CI solo con autorización explícita. | No confundir documento PR79 con código integrado. |
| **M1 nacional** | Cobertura por fuente oficial, clase, dígitos, horario, geografía, excepciones, vigencia y próximos chequeos. | `UNKNOWN` y `STALE` no significan libre circulación; no prorrogar corte Medellín `2026-11-10T05:00Z`. |
| **M2** | Agente solo lector/proponente, Laravel único validador/publicador aprobado. | Sin writer Python paralelo ni microservicios. |
| **M3** | Versionado/hash, manifiesto, Flutter offline y cámaras, cuentas opcionales, rollback e integridad. | Sin modificar UX/producto aprobado. |
| **M4** | CI completo en SHA final, 101 WIP, QA Android/JNI, firma, seguridad, permisos y GO humano. | Un test local no equivale a release ni certificación móvil. |

**RELEASE=NOT_APPROVED / PUBLISH_ALLOWED=NO.** Informe de auditoría forense y decisión directiva, no declaración de que Codex ejecutó C1 ni que la aplicación está lista.