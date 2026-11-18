# PICORADAR — AUDITORÍA FORENSE INDEPENDIENTE M1F Y DECISIÓN DIRECTIVA D01

**Corte:** 2026-11-08, America/Bogota.  
**Objeto:** ZIP `PICORADAR_M1F_ACEPTACION_LOCAL_EVIDENCIAS_UNICAS_20261108.zip` realmente recibido.  
**Dictamen:** `M1F_PARTIAL_BOUNDARY`, **parche original conservado localmente**, pero **NO-GO para integrar/publicar el código** hasta corregir dos defectos demostrados de contrato temporal/frescura.  
**Responsable de arquitectura y siguientes decisiones:** ChatGPT. **Ejecutor eventual:** Codex Luna, solo orden D01. **RELEASE=NOT_APPROVED; PUBLISH_ALLOWED=NO**.

## 1. Identidad, integridad y procedencia

| Evidencia | Resultado |
|---|---|
| ZIP recibido en este chat | 23.497 bytes, SHA-256 `f94cdd7d5c103c5d49de7dc918dcfd58453a8d0207dca3b40ada7b7e6cc736d9` **calculado aquí** |
| ZIP contenido | 14 miembros, `ZipFile.testzip()=None`, CRC32 de los 14 OK |
| MANIFEST.json | SHA-256 `e2090ed0ba55233ed1698d24156ec1ac86c958e241f8bda686dfdb20b35f87dd`; `MANIFEST.sha256` coincide |
| 12 payloads manifestados | Tamaño, SHA-256 y CRC32 de cada uno comprobados contra los bytes presentes, PASS |
| PATCH_ACCEPTED.diff | SHA-256 `68d6a60026609ac38140a9f924d68289af5f8d2882ba8f58a59775d89de75a04`; modifica exactamente tres rutas: validador PHP y dos tests |
| Commit M1F | `a4e80fbcaa357c6ce84084e365507e974e087bab`, branch local `fix/m1e-calendar-overlap-acceptance-local`, **informado y respaldado por logs**, pero el ZIP no contiene objetos Git para comprobar por cuenta propia este SHA/tree |
| H4 base | `1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c`, tree reportado `dc2f2fdc5521af4cb4ad16969d76248b1e021688`, **no recuperable del PR71 remoto** |
| PHP tests | En `TEST_COMMANDS_RAW.log`: 25 unitarios/55 aserciones + 7 feature/31 aserciones, todos EXIT_CODE=0 (observación de logs **de Codex**, no repetición independiente de Laravel completo) |
| Flutter | `NOT_RUN`; sin toolchain y sin código H4 móvil en el ZIP |
| Checkout original y 101 WIP | Conservación del HEAD/estado **reportada**, contenidos de WIP `NOT_VERIFIED` |

## 2. Diez pasadas independientes y sus resultados

| # | Control | Resultado | Decisión exacta |
|---|---|---|---|
| 01 | Archivo y SHA externo | **PASS** | ZIP físico legible; hash externo coincide; no reconstruirlo ni pedir otro M1F. |
| 02 | CRC/manifiesto/SHA internos | **PASS** | 14 CRC OK; doce payloads SHA/size/CRC OK. Un ZIP íntegro no certifica la corrección del código. |
| 03 | Identidad Git/procedencia | **PARTIAL** | Commit local, base, árbol y original son hechos reportados en evidencia; no son commits vistos en GitHub ni se pueden verificar independientemente sus objetos con este ZIP. |
| 04 | Diff y arquitectura | **PASS estático** | Un único validador + dos tests, sin duplicación de Laravel ni migraciones; KISS conservado. |
| 05 | Semántica de calendario | **FAIL reproducido, P1** | Validador reconstruido aceptó solapamiento al leer `validUntil` solo como fecha; ver §3. Prohibida integración antes del fix. |
| 06 | Contrato de frescura | **FAIL reproducido, P1** | Resumen PHP usa `nextReviewAt` futuro e ignora `staleAfter` explícito vencido; ver §4. |
| 07 | Pruebas PHP/format/lint | **PASS reportado, sin ejecución Laravel independiente** | Logs crudos 32 tests/86 aserciones, Pint/lint PASS, pero suites no contemplaron el caso límite de §3 ni corrigen §4. |
| 08 | Flutter/estado visible | **NOT_RUN** | H4 Dart fue inspeccionado por Codex, no ejecutado ni entregado completo; no inferir estado verde real de un teléfono. |
| 09 | Legalidad, TTL y WIP | **PARTIAL/P1** | 19 coberturas: 7 `staleAfter` vencidos, 3 ausentes; Bogotá moto contradictoria. Original/WIP no rehasheado; no habilitar datasets. |
| 10 | Leyes, antipingpong, continuidad | **PLAN PASS / EJECUCIÓN PENDIENTE** | Dirección adopta una sola orden correctiva D01 sobre M1F; no repetir M1C/M1D/M1E, ni abrir M1G ni otro publicador. |

## 3. Nueva evidencia primaria: falso negativo en calendario (P1)

**Procedimiento del director:** se extrajo directamente del ZIP `BASELINE_H4_RestrictionContractValidator.php`; se aplicó solo el hunk del validador de `PATCH_ACCEPTED.diff` mediante `patch -p1` en un directorio temporal aislado; `php -l` pasó. Sobre esa clase PHP realmente reconstruida se ejecutó un fixture sintético con igual jurisdicción, servicio taxi, misma prioridad/dígitos/ventana horaria, `legalValidFrom=2025-12-25`, `legalValidUntil=null`, misma rotación octubre. Segunda regla comienza `2026-10-07T12:00:00-05:00`.

| Primera `validUntil` | Resultado real en PHP reconstruido | Esperado para calendario Flutter inclusivo |
|---|---|---|
| `2026-10-07` (solo fecha) | `ACCEPTED_NO_CONFLICT` | **REJECT**: el 7 de octubre aún pertenece a la regla 1 |
| `2026-10-07T23:59:59-05:00` | `REJECTED: Conflicting restriction rules...` | REJECT |
| `2026-10-06T23:59:59-05:00` | `ACCEPTED_NO_CONFLICT` | ACCEPT: intervalos efectivamente disjuntos |

**Causa:** `optionalScheduleDate()` llama a `date()`; una fecha sin hora se convierte en medianoche bogotana. `dateRangesOverlap()` compara instantes y usa ese instante como límite final, mientras el modelo de calendario móvil reportado trata **`scheduleValidUntil` como día inclusivo**. Esto permite clasificar como disjuntas dos reglas coincidentes durante el mismo día. **No se ha observado un estado incorrecto en un teléfono**; sí es un defecto comprobable del validador aislado.

**Diseño decidido:** contrastar primero el modelo H4 Flutter real y, si confirma esta semántica, normalizar solamente los límites de **calendario** por día local bogotano, con final inclusivo y comienzo inclusivo, antes de intersectar con vigencia legal/rotación. Mantener semántica instantánea/medio abierto de `legalValidUntilExclusive` y `rotationPeriodEndExclusive`; NO transformarlos en fechas inclusivas. Probar fecha corta y timestamp en el mismo día, zona/offset, límites adyacentes, cruces nocturnos y conflictos reales. Ninguna nueva librería ni motor general.

## 4. Nueva evidencia primaria: frescura contradicha (P1)

**Fixture director de PHP real, en validador reconstruido:** cobertura sintética `motorcycle/private`, `sourceCheckedAt=2026-10-24T23:17:18Z`, `staleAfter=2026-09-23T05:00:00Z`, `nextReviewAt=2026-11-24T05:00:00Z` y regla legal abierta válida. `validateJurisdiction(..., schemaVersion=2)` devolvió:

`summary_staleAfter=2026-11-24T05:00:00+00:00` aunque `explicit_coverage_staleAfter=2026-09-23T05:00:00Z`.

El validador H4 usa `dateEither(coverage, 'nextReviewAt', 'staleAfter')`; el informe Codex dice que el parser Flutter H4 prefiere igualmente `nextReviewAt` para `dataIsStale`. El contrato del agente y Plan Maestro diferencian **próxima revisión** y **TTL técnico**; la fecha más nueva de revisión no puede prorrogar una fecha de stale explícita. En 19 coberturas del candidato se registraron 7 `staleAfter` vencidos y 3 ausentes. `ALLOWED` real no fue demostrado; el riesgo es **falsa elegibilidad de datos para ser evaluados como frescos**, no una infracción ya observada en pantalla.

**Decisión conservadora acotada:** ningún consumidor ni validador puede derivar una frescura más tardía que `staleAfter` explícito. Para compatibilidad sin schema nuevo, cuando existan ambos campos y las normas superiores no lo prohíban, usar como corte efectivo **el más temprano** para el estado de seguridad; si hay solo uno, conservar fallback documentado; nunca modificar fechas fuente. La programación de próxima revisión permanece semánticamente distinta. Si un contrato superior prescribe reglas contradictorias, `DESIGN_CONTRACT_CONFLICT` y ningún cambio unilateral en esa superficie. Una cobertura con staleAfter anterior a sourceCheckedAt no debe disimular esa inconsistencia con el nextReviewAt futuro. Las suites podrán legítimamente identificar un asset H4 previamente aceptado como inválido/fuera de publicación; NO alterar JSON para forzar PASS.

## 5. Autoridad y decisiones ya fijadas

Orden de precedencia `AGENTS.md`, DOCX Cierre Global/Arquitectura, contrato Flutter y SOP del proyecto, seis leyes L1–L6 PingPongLaw; el contrato del agente tiene menor jerarquía y no reemplaza baselines. Laravel publicador único; Flutter local-first sin cuenta obligatoria; agente de fuentes solo propone; sin permisos automáticos de publicación. No se cambiarán cámara, geocercas, diseño visual, bases de datos, dependencias, JSON, URLs oficiales, fechas ni `main`/PR71 ni el checkout del usuario.

**Revisión de decisiones pasadas:** antes se aceptó M1E/M1F como candidato local. Esa aceptación sigue válida en cuanto al **falso positivo taxi Oct1/Oct7 resuelto** y preservación del parche, pero **NO cubre** los dos defectos adicionales descubiertos. `32/86 PASS` no se revoca ni se infla a certificación L5. No abrir un nuevo ciclo de auditoría general; solo D01 causal.

## 6. Instrucción de continuación única

**Orden canónica propuesta:** `docs/plans/CODEX_LUNA_PICORADAR_M1F_D01_CONTRATO_TEMPORAL_FRESCURA_20261108.md` con mismo candidato local y base `a4e80fbcaa357c6ce84084e365507e974e087bab`, en una rama local hija aislada si procede. No repetir M1F G0–G5. Dos contrapruebas RED ya proporcionadas, pero Codex debe registrar el RED **en su H4 real** y la concordancia con Dart real. Corregir el mínimo de funciones, PHP y Flutter solo si se ajusta a contrato superior, sin duplicar pipeline, sin nuevas dependencias. Ejecutar pruebas focales PHP y Dart si existe toolchain; lo no corrido es `NOT_RUN`. Uno solo ZIP con informe, diff, logs crudos, hashes/manifiesto, y matriz de estados de 19 coberturas; no crear commits remotos, no push, merge, release, Hostinger ni ADB.

**Salidas:** `PASS_LOCAL_SCOPE_ONLY` si todas las pruebas esenciales disponibles son PASS; `PARTIAL_FLUTTER_NOT_RUN` si falta Dart; `BLOCKED_CONTRACT` si autoridad superior prohíbe decisión; `FAIL` si algún caso RED permanece. En todos, `PUBLISH_ALLOWED=NO`, `RELEASE=NOT_APPROVED`. Después continúa **ChatGPT**, quien verificará evidencia y decidirá admisión remota de código sin transferir WIP arbitrarios.

## 7. Ruta de finalización sin rebajar alcance

| Fase existente | Entrega / gate |
|---|---|
| M1F-D01 (único delta urgente) | Evitar falso conflicto y falsa frescura en el mismo candidato local con pruebas comparables. No una fase nueva del Plan Maestro. |
| M1 nacional | Completar las 1.096 jurisdicciones no investigadas según denominador M1B, más fuentes/categorías parciales, priorizando autoridades y reutilizando URL verificadas sin rastrear innecesariamente. Una no investigada es UNKNOWN, no NO_MEASURE. |
| M2 | Fuentes → agente lector/propuesta con revisión humana → Laravel actual valida/versiona/publica solo autorizado; una fuente de verdad y rollback. |
| M3 | Contrato distribución Laravel–Flutter, firma/hash/manifiesto, motor offline y cámaras, UX/cuentas opcionales según baseline; tests reales y no hacer bypass de stale. |
| M4 | WIP 101 auditado antes de integración, CI real de SHA efectivo, tests móviles, seguridad, JNI/ADB/QA físico/firma y aprobación humana de lanzamiento. |

**No se autoriza un lanzamiento parcial nacional sin decisión expresa del propietario.** El TTL técnico Medellín reportado 2026-11-10 00:00 COT no se extiende por calendario ni revisión.

## 8. Continuidad del GitHub

**Repositorio:** `sierraglobalcompany-rgb/PicoRadar`, PR #79 rama `docs/plan-maestro-nacional-v2-20261107` Draft; PR #71 remoto antiguo `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` OPEN/DRAFT, `main` intacto. Esta auditoría y el prompt D01 deben guardarse como documentos en PR #79 y añadir checkpoint de hallazgo P1 al Plan Maestro/ledger sin modificar contrato funcional ni código. La auditoría GitHub acredita documentos y árboles remotos, **no** ejecución local H4 ni las 101 rutas WIP.

**NEXT_ACTOR=CODEX_LUNA** para una única ejecución D01 si todavía no comenzó; luego `NEXT_ACTOR=CHATGPT`. **NOT_RELEASE_APPROVED**.