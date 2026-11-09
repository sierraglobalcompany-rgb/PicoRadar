# PICORADAR — Auditoría directiva C1: 10 pasadas, cierre de bucle y retorno a M1.3

**Corte:** 2026-11-08, América/Bogotá. **Estado técnico C1:** `D01_CANDIDATE_PHP_PASS_ENV_BLOCKED`. **Release:** `NOT_APPROVED`.

## Evidencia primaria recibida y contrastada

- ZIP C1 adjunto: `PICORADAR_M1F_D01_C1_CIERRE_EVIDENCIA_UNICA_20261108.zip`; 25.837 bytes; SHA256 `ae33efd1515214e9848806eb94d86ca133adc42e30eb2dee61972f8e38a1903e`; 13 miembros, CRC PASS; 11/11 payload SHA/CRC/tamaño PASS; manifiesto SHA `5afa731649ff71504d14685fb5df59e78c2f7734def559bed2cb861d92288d05`.
- Patch acumulado de cinco archivos SHA `d7317989e1ba756d563ea4a0d685f9127218f2f5b7b9141a2c3d1fac9d2cc244` y base PHP M1F proporcionada en ZIP SHA `19b447d1436cf68c8a4d3837f7b8a362d8d0f74c40165bf336130f9eacc517f2`. **ChatGPT reconstituyó independientemente PHP de la base + el diff y ejecutó en PHP 8.4.24 el harness `calendar_repro.php`:** antes: C1-01/C1-06 incorrectos y frescura extendida; después: C1-01/C1-06/conflicto y `staleAfter` rechazado como corresponde; PHP lint PASS. No atribuir este ensayo a Flutter ni a Laravel integrado.
- Logs de Codex: 36 tests PHP/75 assertions y 7 feature/32 assertions PASS; Pint/lint/diff-check PASS; SQLite resuelto de forma aislada; Flutter/Dart `NOT_RUN`, no APK/CI real. C1 no creó commit; cinco cambios sin stage en clon local. 101 WIP no verificados.
- Datos: 10 jurisdicciones, 19 coberturas; contrato 9/10 PASS, Bogotá moto FAIL porque staleAfter precede fecha de comprobación. 9 coberturas frescas, 9 stale y 1 stale-before-verification al corte. No implican regla operativa nacional.
- GitHub: PR79 solo documental Draft; PR71/main inalterados. Los commits H4 `1b5badd9...` y local M1F `a4e80fbc...` no son objetos recuperables por el conector remoto (GitHub 422). No afirmar código remotamente integrado.

## Diez pasadas — resultado por dimensión

| # | Objeto auditado | Resultado | Limitación / decisión |
|---|---|---|---|
| 1 | ZIP externo | PASS | SHA, tamaño, CRC verificados en bytes físicos adjuntos. |
| 2 | Manifiesto | PASS | 11 archivos SHA/CRC/tamaño coinciden; no inventar fuente ajena. |
| 3 | Alcance del parche | PASS estático | Cinco rutas exactas, sin JSON, motor o resumen modificados. |
| 4 | Calendario RED→GREEN | PASS focal independiente | PHP reconstruido; falla antes y pasa después, timestamps explícitos intactos. No equivale a Dart. |
| 5 | Frescura | PASS focal PHP | Corte conservador más temprano, rechazo de `staleAfter < sourceCheckedAt`. Flutter pendiente. |
| 6 | Laravel test | PASS reportado | 36/75 unit, 7/32 feature con SQLite. No se replicó la suite Laravel completa aquí. |
| 7 | Flutter | BLOCKED/NOT_RUN | Pruebas de parser/motor/resumen y otras QA pendientes; el código es candidato, no release. |
| 8 | Calidad de datos | FAIL focal | 9/10 validador, Bogotá moto con fechas contradictorias; no corregir JSON por código. |
| 9 | Historia y WIP | PARTIAL | C1 sin commit; H4 no está publicado en GitHub; 101 WIP no verificados. |
| 10 | Leyes y rumbo | CORRECCIÓN DE RUMBO | L1–L6: dejar de iterar validador y reanudar M1.3 independiente según Plan Maestro D/I. |

## Por qué estábamos desviándonos

El Plan Maestro definió en noviembre M1.1–M1.3 y el avance nacional con 73 municipios semilla/219 clases, 179 fuentes y 159 pendientes de revalidación. Posteriormente se invirtieron numerosas rondas M1C–C1 en un único falso conflicto de calendario. Esta ruta mejoró un componente, **pero ya no debía ser el cuello de botella de M1.3**: la dependencia jurídica/fuente puede avanzar sin Flutter, JNI o deploy, según el Plan Maestro §§D/F/I.

## Decisión del director — única, sin ping-pong

1. **Cerrar la investigación del calendario por ahora.** C1 es `PHP_CANDIDATE_PASS`, pero Flutter y admisión Git todavía pendientes. No enviar C2/D02/M1G ni pedir repetir PHPUnit.
2. **Preservar el parche C1 sin contaminar GitHub ni WIP.** Se conserva ZIP canónico y candidato local protegido; admisión y QA Flutter se resuelven en integración M4/CI, no en el próximo lote de datos.
3. **Próximo lote operativo:** M1.3 descubrimiento nacional por autoridad y fuentes, reutilizando M1A/M1B, sin reeditar las mismas 179 filas. Hacer un lote con fuentes nacionales, bloqueos honestos y un único ZIP.
4. **Barrera de release:** Bogotá moto sigue `FAIL_SOURCE_FRESHNESS`, Medellín próximo TTL no se renueva sin revisión. Motor `UNKNOWN/STALE` y publicación `NO` donde falte evidencia.
5. **Después:** M1.4/1.5 completitud y revisión, M2 motor y agente lector, M3 publicación Laravel→Flutter/cámaras, M4 CI final/Flutter/101 WIP/Android físico/firma/GO humano. No cambiar arquitectura Flutter+Laravel monolito.

**Próximo actor:** Codex Luna solo M1.3 investigación nacional con orden descargable `CODEX_LUNA_PICORADAR_M1_3_REENFOQUE_FUENTES_NACIONALES_20261108.md`, un ZIP; después ChatGPT director. **Sin aprobación de release, push, merge ni despliegue.**