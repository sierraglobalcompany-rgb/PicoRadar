# PicoRadar — auditoría forense del resultado M1E, diez pasadas y ruta crítica M1F

**Fecha:** 2026-11-08, zona America/Bogota. **Director:** ChatGPT. **Código ejecutado:** solo por Codex Luna en clon local. **Revisión de ChatGPT:** independiente de los hashes, manifiesto, contenido del diff, consistencia documental y muestreo JSON; **NO reproduce PHP ni Flutter H4**, cuyos bytes íntegros y dependencias no vinieron en el ZIP. **Release:** `NOT_APPROVED`. **Publicación:** `PUBLISH_ALLOWED=NO`.

## 0. Evidencia examinada y procedencia

ZIP adjunto físicamente: `PICORADAR_M1E_CALENDAR_OVERLAP_20261108.zip`, SHA-256 `7affcdfe60bc313bf416a4b4625057a3f506d4a7934c3eeb5da903dda38a2291`, 19.629 bytes, 12 miembros, `testzip()` PASS. `MANIFEST.json` SHA-256 `82bf548ab31f5482c8a6d133a96fcc7c0884c558d0122c5de61323a0e9bd4ae6`; 10/10 payloads con SHA-256, bytes y CRC32 correctos. `MANIFEST.sha256` apunta al digest efectivo del manifiesto.

Archivos: `FINAL_REPORT.md`, `PATCH_CANDIDATE.diff`, `ROOT_CAUSE_H4.md`, `BOGOTA_NOV_CANDIDATE.json`, `BOGOTA_FULL_CITY_CANDIDATE_GATE.md`, `CALENDAR_CONFLICT_MATRIX.csv`, `PHP_TEST_RESULTS.csv`, `VERIFICATION_LOG.txt`, `TREE_AND_PRESERVATION.txt`, `AUDIT_10_M1E.csv`, `MANIFEST.json`, `MANIFEST.sha256`.

Base H4 **declarada por Codex**: `1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c`, tree `dc2f2fdc5521af4cb4ad16969d76248b1e021688`. No está resuelta en el remoto PR71 que consultamos: `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`. No se debe dar por verificada la procedencia del H4 solo por su mención en un reporte.

El parche mide 26.659 bytes, SHA-256 `68d6a60026609ac38140a9f924d68289af5f8d2882ba8f58a59775d89de75a04`. Cambia 3 rutas: `server/app/Services/RestrictionContractValidator.php`, `server/tests/Unit/RestrictionContractValidatorTest.php`, `server/tests/Feature/RestrictionPublicationServiceTest.php`; **único comportamiento productivo modificado: validador PHP**. Sin librerías, migración, ampliación de modelo, nuevo publicador ni JSON runtime editado.

## 1. Diez pasadas con resultados diferenciados

| ID | Control | Resultado | Evidencia y decisión |
| --- | --- | --- | --- |
| 01 | ZIP y transferencia | `PASS` | Archivo físico examinado; SHA externo igual al declarado; 12 CRC sin error. |
| 02 | Manifiesto y hashes internos | `PASS` | 10/10 miembros listados con tamaño, SHA256, CRC comprobados y manifiesto firmado por digest. |
| 03 | Alcance y KISS/Ponytail | `PASS_ESTÁTICO` | Un validador PHP + dos tests; 438 inserciones/7 eliminaciones declaradas, mayoría en pruebas; no se crea segundo motor. |
| 04 | Causa raíz y calendario | `PASS_ESTÁTICO_LIMITADO` | La propuesta intersecta límite legal, rotación y `scheduleValidFrom/Until` cuando hay `legalValidFrom`. Rechaza límites invertidos. Falta demostrar las semánticas completas del H4 en ejecución independiente. |
| 05 | Controles contra falso negativo | `PASS_REPORTADO / NO_REEJECUTADO` | Tests del ZIP sobre intervalos iguales, parciales, inclusivos, ausentes, adyacentes, offset, madrugada, diferentes servicios. En el motor remoto Flutter la vigencia temporal se comprueba antes de ventanas de tiempo; confirmar en H4. |
| 06 | Pruebas y herramientas | `PASS_REPORTADO / NO_REEJECUTADO` | 25 tests/55 aserciones unitarias + 7/31 feature, 32/86 total; lint 3 PHP, Pint y `git diff --check`. ZIP incluye resúmenes, no salidas crudas de cada PHPUnit ni el árbol H4. Flutter `NOT_RUN`. |
| 07 | JSON candidato y Bogotá | `PASS_ESTRUCTURA_NO_LEGAL` | JSON SHA `33b4eec352c1799e7f32af56cd89438dea3ca2e8bcbcbbe1f42a549ad3d0eb33`; schema2 10 jurisdicciones. Se verificaron independientemente reglas de particulares en seis días de noviembre; concordancia con boletín oficial Bogotá. Festivos regionales son reglas separadas. |
| 08 | Vigencia y cobertura nacional | `BLOCKED_FRESHNESS` | En **Bogotá** la cobertura particular tiene staleAfter 2026-12-01T05Z, pero moto 2026-09-23T05Z y taxi 2026-11-01T05Z (ambas vencidas a 2026-11-08). De 19 coberturas del JSON, 7 tienen `staleAfter` vencido y 3 no incluyen ese campo; estos totales son inspección estática, NO dictamen legal ni de runtime. Medellín 2 coberturas vencen 2026-11-10T05Z. |
| 09 | Proveniencia y WIP | `PARTIAL` | Checkout original declarado sin cambios salvo borrado preexistente de script Hostinger; 101 WIP históricos `NOT_VERIFIED`, no afirmar inmutabilidad byte a byte. PR71 aún no incluye parche H4 ni el fix. |
| 10 | L1–L6, antipingpong y entrega | `PASS_DE_DIRECCIÓN` | M1E se cierra como candidato, NO como release; siguiente lote limitado M1F para preservar y aceptar parche local, sin rehacer M1E, sin push/deploy, un ZIP. Camino M1→M2→M3→M4 intacto. |

**No presentar `PASS_REPORTADO` como ejecución independiente.** Este es el principio L5 de PingPongLaw: los resultados reportados por Codex son evidencia secundaria, mientras nuestras verificaciones SHA/JSON/diff sí son directas.

## 2. Decisiones de arquitectura cerradas

- **M1E = `PASS_CANDIDATE_LOCAL` y cierre de tarea**, sin autorizar el parche para `main`, PR71, release o backend de producción. No crear M1E V2 ni repetir M1D.
- **Conservar `RestrictionPublicationService` y `DatasetPublisher` Laravel**, único mecanismo de validación y publicación; el JSON estático Flutter no tiene writer paralelo autorizado. Agente de fuentes solo lee y propone.
- **No modificar reglas ni datos taxi**, ampliar TTL, inventar exenciones o zonas, ni marcar ciudad completa como READY por un contrato schema2 PASS.
- El fix debe ser **revisado en el mismo H4**, con reproducción independiente de la diferencia RED→GREEN y test de coincidencias reales. Antes de integrar, comprobar que `validFrom` y `validUntil` son límites efectivos compatibles con parser Flutter H4; no usar el motor remoto antiguo como prueba H4.
- Existe diferencia entre `validUntil` inclusivo y `rotationPeriodEndExclusive`; exigir prueba de frontera y zona America/Bogota si aparece cualquier cambio adicional. No inventar algoritmo temporal complejo.
- La fecha `staleAfter` **técnica**, el fin jurídico de la medida y `nextReviewAt` son tres conceptos distintos; fail-closed bajo incertidumbre. Medellín vencimiento técnico previsto 2026-11-10 00:00 COT, no renovar automáticamente.

## 3. Siguiente lote mínimo M1F — aceptación y preservación local, no otra auditoría M1E

**TASK_ID:** `PICORADAR-M1F-ACCEPT-M1E-PATCH-PROVENANCE-KISS-20261108-DIRECTOR`.

Objetivo: crear un candidato de código **trazable y reproducible** basado en H4 (rama local aislada), conservar el parche M1E de tres rutas, ejecutar gates focales con logs completos y probar que los datos vencidos no habilitan `ALLOWED`. Si todo pasa, un único commit **local** en la rama exclusiva sin push, bajo norma de autorización de commits locales; si no, entregar diff reversible sin commit y blocker puntual. No recalcular la investigación M1B/M1C/M1D/M1E.

El resultado debe separar explícitamente `CODE_PATCH_ACCEPTED_LOCAL`, `FLUTTER_NOT_RUN`, `DATA_STALE`, `PROVENANCE_UNVERIFIED`, `CODE_DIFF_NOT_ALLOWED`, `BLOCKED` según corresponda. El cierre funcional del código no equivale a cobertura nacional ni release. El siguiente gate remoto de PR de código depende de aprobación y procedencia, no se ejecuta por inercia.

**Entrada mínima:** clon candidato real `D:\codex\_CANDIDATOS\PicoRadar-M1E-Calendar-Overlap-20261108`, ZIP M1E original SHA anterior; si Codex posee ya el candidato y su diff exacto con el mismo SHA, no pedir volver a transferir ZIP. Original `D:\codex\PicoRadar` en solo lectura; no borrar ni tocar sus WIP. Código permitido: exactamente validador + 2 tests ya autorizados.

**Entrega:** exactamente un ZIP con informe y resultados reales, `PATCH_ACCEPTED.diff`, SHA/manifiesto/CRC, procedencia Git, PHP test raw logs y matrix de vigencias. Si un bloqueo impide el commit, reportarlo sin inventar solución y sin otro pingpong.

## 4. Camino de finalización del producto, sin porcentajes inventados

| Orden | Puerta de salida objetiva |
| --- | --- |
| M1F aceptación del parche | Misma base H4 identificada; diff 3 archivos; gates PHP reproducidos y pruebas negativas; un ZIP de evidencia; ningún remote alterado. |
| M1 investigación nacional | Autoridades y estado de fuentes por jurisdicción y categoría, 1.096 municipios no revisados en M1B a cubrir por lotes y prioridades; nunca inferir `NO_MEASURE` de `NOT_SEARCHED`. Reglas y frescura por fuente. |
| M2 motor y agente lector | Capacidades motor en vez de parches por ciudad, agente propone fuente/rotación; Laravel revisa y publica solo bajo autoridad. |
| M3 distribución y producto | Manifiesto/versiones y sync Flutter atómico, offline/fail-closed, cámaras con evidencia, cuenta optativa según baseline, pruebas de rollback. |
| M4 cierre | Revisión de 101 WIP y Git, CI real por SHA, QA Android/JNI/firma/datos reales con permiso, privacidad/seguridad, aprobación humana y release/rollback. |

## 5. Continuidad, jerarquía y próximos roles

**Ley 1:** KISS+Ponytail. **L2:** antirruido. **L3:** antiparches. **L4:** diseño humano y contratos. **L5:** verificación independiente y sin falsos PASS. **L6:** director ChatGPT, Codex solo ejecutor. Repositorio remoto `sierraglobalcompany-rgb/PicoRadar`, PR documental #79 Draft, PR71 Draft separado; no cambiar `AGENTS.md`, baselines ni contratos de producto.

**NEXT_ACTOR:** CODEX LUNA solo M1F si no se ha ejecutado ese lote. **POST_NEXT:** ChatGPT audita un único ZIP y decide qué puede registrarse como código aprobado y cómo retomar M1 nacional. **NO PUSH / MERGE / PRODUCCIÓN / RELEASE.**