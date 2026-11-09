# CODEX LUNA — PICORADAR M1F-D01 / CONTINUACIÓN C1: CIERRE DEL CONTRATO DE CALENDARIO SIN PING-PONG

**TASK_ID SIN CAMBIOS:** `PICORADAR-M1F-D01-TEMPORAL-FRESHNESS-SAFETY-20261108-DIRECTOR`  
**ETIQUETA DOCUMENTAL DE CONTINUACIÓN:** `D01-C1`; **NO** es un nuevo lote M1G, D02 ni una repetición de M1F.  
**DIRECTOR / RESPONSABLE DE DECISIONES:** ChatGPT. **EJECUTOR LIMITADO:** Codex Luna.  
**OBJETIVO:** finalizar la corrección mínima del límite de fecha de calendario a partir del **mismo candidato local** que ya contiene los cinco cambios D01 de frescura. Preservar los avances y exponer de forma honesta los bloqueos de entorno y de datos.  
**RELEASE=NOT_APPROVED; PUBLISH_ALLOWED=NO; NO PUSH, MERGE, DEPLOY, HOSTINGER, APK, ADB NI QA FÍSICA.**  
**SALIDA OBLIGATORIA:** **UN SOLO ZIP**, con todos los informes y evidencias en su interior. `NEXT_ACTOR=CHATGPT`.

## 0. Estado y decisiones inalterables del director

1. El ZIP D01 recibido físicamente se llama `PICORADAR_M1F_D01_CONTRATO_TEMPORAL_FRESCURA_EVIDENCIA_UNICA_20261108.zip`. Su SHA-256 recalculado es `83ebd895d29d0150f1bb235407cf465ebf94530b9fcaa56220602cf69a639b98`; 19.612 bytes; 11 miembros con CRC correcto; nueve payloads comprobados frente al manifiesto. `MANIFEST.json` SHA-256 `52845570776304f3615bf69bdfaf1d28f729f84ff545d272691b32342f530e79` y `PATCH_D01.diff` SHA-256 `99541a9be4160bfeb9dc662ffbe18e1120dc1dca85b147810fe5c037b52fc4f3`. No repetir validaciones de paquetes históricos salvo inconsistencias materiales nuevas.
2. **Rama actual en el candidato Codex:** `fix/m1f-d01-temporal-freshness-local`; **HEAD inalterado:** `a4e80fbcaa357c6ce84084e365507e974e087bab`, árbol `0a55c0a1e3f0b268a22ed69deb990dede3ca5f4c`; rama creada a partir del M1F aceptado. En esta rama existen **exactamente cinco archivos de trabajo modificados, no staged ni commit**. **Conservarlos**: no revertir, resetear, `clean`, stash, copiar y sobrescribir ni reconstruir el parche. Verificar hashes y diffs primero; si cambió el estado, detener y entregar evidencia causal, nunca restaurar a ciegas.
3. **Clon candidato aislado:** `D:\codex\_CANDIDATOS\PicoRadar-M1E-Calendar-Overlap-20261108`. No tiene remotos, no agregarlos. **Original protegido:** `D:\codex\PicoRadar`, rama `recovery/20261019-modern`, HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, árbol `04a01f15475dd25fbcd40597120e6e44722b0504`, con el borrado histórico preexistente de `scripts/tests/test_hostinger_installer_browser.ps1`. Original solo lectura; 101 rutas WIP `NOT_VERIFIED`, no inspeccionarlas ni tocarlas.
4. **M1E/M1F permanece conservado:** fix local de falso conflicto entre taxis de Bogotá de 1 y 7 de octubre; no eliminar ni alterar las reglas. D01 ya modificó validador PHP y parser Flutter para usar el corte técnico más temprano de `staleAfter` y `nextReviewAt`, con fallback de un campo y fail-closed cuando faltan ambos. **No reimplementar D2**.
5. D01 real fue `D01_BLOCKED_CONTRACT`. `30 tests / 69 assertions` unitarios PHP reportados PASS; lint/Pint/diff-check PASS reportados. Siete tests feature `ERROR` al iniciar `RefreshDatabase` por falta del driver `pdo_sqlite`, **cero aserciones**. Flutter/Dart `NOT_RUN`, sin SDK ni `mobile/.dart_tool/package_config.json`. El validador directo schema2 examinó diez jurisdicciones: **9 PASS, 1 FAIL Bogotá moto** porque `staleAfter=2026-09-23T05:00:00Z` precede a `sourceCheckedAt=2026-10-24T23:17:18Z`; `nextReviewAt=2026-11-24T05:00:00Z` NO renueva ese corte. **No cambiar datos ni fechas para lograr PASS.**
6. Antes de escribir, consultar solo los apartados relevantes de `AGENTS.md`, Cierre Global, Arquitectura Android-first, `docs/CURRENT.md`, `docs/DESIGN_CONTRACT.md`, `docs/SOP.md`, leyes L1–L6 y archivos H4 del punto 4. El contrato del agente distingue expresamente `next_review_at` de `dataset_stale_after`. No modificar baselines. El PR #79 es documental Draft y su checkpoint es mantenido por ChatGPT. PR #71 y `main` se preservan. **Sin escrituras de Codex en GitHub.**

## 1. Decisión de diseño ya tomada por ChatGPT — no delegar arquitectura

**D1. Límite de calendario operativo:** cuando una regla de schema2 contiene `legalValidFrom` (lo que indica que `validFrom`/`validUntil` delimitan el calendario operativo) y `validUntil` es **una fecha ISO `YYYY-MM-DD` sin componente horario**, su fecha de fin **incluye ese día completo en `America/Bogota`**. Expresar esa inclusión mediante un límite de fin de día para comparación de instantes (por ejemplo `23:59:59.999999` o el límite matemáticamente equivalente antes del inicio del día siguiente), sin expandir otras vigencias. `validFrom` de solo fecha comienza a las 00:00 del día, como hoy.

**D1.1 Timestamp explícito:** si `validUntil` incluye hora y/o offset, conservar estrictamente ese instante; no convertirlo en fin de día, no truncarlo. Conservar semántica de `legalValidFrom`, `legalValidUntil`, `legalValidUntilExclusive` y `rotationPeriodEndExclusive`. Este último es **exclusivo**, no prorrogarlo ni por un microsegundo. No reinterpretar permisos, ámbitos, dígitos o fuentes.

**D1.2 La discrepancia hallada NO obliga a reescribir el resumen diario.** El motor responde si una regla aplica **en un instante**; el resumen diario responde si una regla **interseca un día**. Las dos consultas pueden diferir legítimamente fuera del horario. Lo obligatorio es que coincidan sobre la presencia/ausencia del calendario en las fechas de borde. Corregir únicamente el parseo del valor `scheduleValidUntil` que consume el motor si hace falta, más `optionalScheduleDate` del validador PHP. **No cambiar** el resumen diario por analogía; si una prueba real evidencia un defecto material en ese resumen, escribirlo como `DESIGN_DECISION_REQUIRED` en el único ZIP, no expandir rutas automáticamente.

**D1.3 Fijación independiente del director:** en una **copia temporal fuera del repositorio**, ChatGPT reconstruyó `RestrictionContractValidator.php` aplicando el patch M1E y el D01, y ensayó que `optionalScheduleDate` normalice una fecha `validUntil` corta al final del día de Bogotá. PHP 8.4 lint PASS. En tres fixtures iguales salvo el límite: `2026-10-07` + segunda regla al mediodía => **REJECT**, timestamp 7/oct 23:59:59 => **REJECT**, fin 6/oct => **ACCEPT**. Con el dataset candidato inmutable: **9 jurisdicciones PASS / Bogotá FAIL** por fecha técnica contradictoria. Este resultado **NO** certifica Dart, tests Laravel, ni un arreglo aplicado al candidato Codex. Codex solo implementa y verifica el delta acotado según código H4 real.

**D2. Frescura:** mantener exactamente la corrección D01 existente del **mínimo de ambos cortes** cuando hay dos, fallback compatible si solo hay uno y fail-closed si faltan ambos, siempre sujeto a normas superiores. `sourceCheckedAt > staleAfter` se rechaza; `nextReviewAt` no justifica extenderlo. El usuario no autorizó sobrescribir fechas publicadas. El éxito PHP D2 no equivale a prueba móvil D2.

## 2. Máximo de archivos permitidos, siempre sobre el mismo candidato

**Se autorizan como MÁXIMO estas cinco rutas totales**, ya modificadas por D01:

1. `server/app/Services/RestrictionContractValidator.php` — ajustar `optionalScheduleDate` exclusivamente para `validUntil` de **fecha corta**, con condición de calendario `legalValidFrom` ya presente. D2 intacto.
2. `mobile/lib/features/pico_placa/data/restriction_dataset.dart` — normalizar **solo** el `scheduleValidUntil` que corresponde al `validUntil` de **fecha corta** en schema2, reutilizando `_optionalDate` o el parser local existente. Conservar `DateTime.parse` exacto para timestamps explícitos y el corte de frescura D2. Usar la misma representación de fecha/hora del contexto del motor; comprobar manejo de zona Bogotá y dispositivos en otras zonas.
3. `server/tests/Unit/RestrictionContractValidatorTest.php` — añadir RED/GREEN de fecha corta; mantener todos los tests D2 y M1E.
4. `server/tests/Feature/RestrictionPublicationServiceTest.php` — mantener rechazo seguro de Bogotá moto y prueba aislada de publicación/rollback, solo ajustar un assertion justificado dentro del mismo archivo si hace falta.
5. `mobile/test/features/pico_placa/data/restriction_dataset_test.dart` — añadir casos del parser de fecha corta, timestamp explícito, transición siguiente día, equivalencia de offset, fin de día y frescura D2.

**NO AUTORIZADO:** tocar `restriction_rule.dart`, `restriction_engine.dart`, `city_restriction_summary.dart`, cualquier JSON, `composer.lock`, pubspec, dependencias, rutas API, migrations, bases reales, docs baseline, diseño, modelos, screenshots o nuevos archivos de producto. **Si el delta exige una sexta ruta para no dejar una inconsistencia real, STOP solo esa modificación y entregar decisión fundada, no crear refactor.** Los harness/logs de verificación pueden vivir *fuera* del repositorio, dentro de la carpeta de reportes.

## 3. Secuencia operativa G0–G6 — una sola ejecución, sin ping-pong

### G0 — Precisión de punto de partida (solo lectura; no preflight global)

- Confirmar `git rev-parse HEAD = a4e80fbc...`, branch `fix/m1f-d01-temporal-freshness-local`, cero remotos y **exactamente cinco** rutas modificadas D01. `git diff --name-only`, `git diff --check`, `git status --porcelain=v1`; registrar SHA-256 de cada ruta antes y después. Si el estado no coincide, no resetear: `SOURCE_DRIFT` en informe, detener escritura.
- Inspeccionar únicamente los 5 archivos anteriores más los **tres archivos de dominio H4 en modo lectura**: `restriction_rule.dart`, `restriction_engine.dart` y `city_restriction_summary.dart`, especialmente `_parseRule`, `restrictionRuleMatchesScheduleDates`, `scheduleValidUntil` y el resumen por día. Confirmar qué tipo de `DateTime` usa la comparación del motor. No abrir otra auditoría de 73 ciudades.
- Revisar la última orden en PR #79 y leyes L1–L6 solo en secciones aplicables. El clon H4 no contiene el PR documental; consultar fuentes sin alterar el clon ni invocar `git remote add`.

### G1 — Reproducir dos RED anteriores y fijar pruebas del contrato con *estos* límites

- Reutilizar `RED_RAW.log` D01 y su script si existe; probar sobre una copia temporal del **HEAD M1F antes del arreglo D1**, sin resetear el candidato actual. No gastar tiempo releyendo todos los ZIP. Guardar comando, stdout/stderr y exit code crudos.
- Caso `C1-01`: reglas mismo servicio/priority/dígitos/rotación: A `validUntil=2026-10-07` y B comienza 7/oct 12:00 Colombia => **conflicto** en PHP.
- `C1-02`: A termina 6/oct => **sin conflicto**. `C1-03`: A termina timestamp 7/oct 23:59:59 => **conflicto**. `C1-04`: A termina 7/oct 00:00 timestamp explícito y B comienza al mediodía => **sin conflicto**; prueba que NO se reinterpretan timestamps.
- `C1-05`: horario que cruza medianoche, `validUntil=2026-10-07` y cola nocturna 8/oct 01:00 con fecha efectiva 7/oct: debe pertenecer al horario de 7/oct, no activar arbitrariamente un día siguiente. Confirmar en engine H4; si Dart no disponible, lectura estática + `MOBILE_NOT_RUN`.
- `C1-06`: comparar UTC/offset `2026-10-08T04:59:59.999999Z` con 7/oct 23:59:59.999999 de Bogotá: equivalencia exacta en PHP y en parser si ejecutable.
- `C1-07`: fin legal y fin de rotación exclusivo permanecen intactos, incluidos casos de frontera; también evitar falso positivo donde las reglas comparten solo fecha nominal pero no un instante efectivo.
- `C1-08`: `staleAfter` septiembre / `nextReviewAt` noviembre / `sourceCheckedAt` octubre => resultado **rechazado** en Laravel y **stale** móvil si logra importarse en pruebas sintéticas; nunca verde por inferencia.
- `C1-09`: D2 ambos cortes presentes (anterior, posterior, mismo instante y offsets equivalentes), fallback de uno, ausencia de ambos => conservar PASS existentes.
- `C1-10`: validación de jurisdicciones **con el dataset intacto** => 9/10; Bogotá moto rechazada por su contradicción. No presentar 10/10 como criterio obligatorio que lleve a falsificar fuente.

### G2 — Implementar D1 mínimo sin tocar D2

- En `optionalScheduleDate($rule, 'validUntil')`, si `legalValidFrom` existe y el valor original es exactamente `YYYY-MM-DD`, usar día **Bogotá** completo. Para PHP se admite `DateTimeImmutable::setTime(23, 59, 59, 999999)` cuando ello respete el contrato y las pruebas. **No** alterar `date()` global ni `legalValidUntilInclusive()` ni `dateRangesOverlap` salvo demostración indispensable y previa autorización del director.
- En `restriction_dataset.dart`, si `legalValidFrom` activa el calendario operativo y el `validUntil` original es exactamente `YYYY-MM-DD`, convertir a fin del mismo día usando el tipo/localidad temporal que ya usa la aplicación. Se admite una función local muy pequeña, no clase nueva. Timestamps con hora conservar el parseo previo; no cambies la semántica de `scheduleValidFrom` ni de `legalValidUntilExclusive`.
- Cuidado con `DateTime.parse('YYYY-MM-DD')`, que toma medianoche; usar fin de día **sin depender de la zona del teléfono**, en el mismo eje de calendario Bogotá que emplea el motor. No construir un instante UTC diferente de los demás `DateTime` si eso rompe comparaciones; las pruebas deben revelar la conversión exacta.
- No tocar semántica del resumen diario por adelantado. Si `city_restriction_summary.dart` ya responde por intersección de día, esa es la operación prevista, no un bug por sí mismo.

### G3 — Gates exactos con honestidad y sin trucos de entorno

- PHP: ejecutar unit tests focales del validador (incluidas todas las regresiones M1E y D01), `php -l` de las tres rutas PHP, Pint `--test` sobre alcance permitido y `git diff --check`. Guardar comandos completos, salida y exit code. **PASS únicamente de prueba ejecutada, jamás por expectativa.**
- SQLite: primero `php --ini`, `php -r 'print_r(PDO::getAvailableDrivers());'` y comprobación read-only de las extensiones PDO SQLite disponibles para **ese** PHP. Si hay PHP **portable** confiable con SQLite instalado o Docker/WSL **ya existente y offline**, usarlo en entorno aislado, sin instalar global, cambiar `php.ini` del sistema, sin red y sin DB real. **Máximo una exploración acotada de alternativas verificables.** Si no hay driver, marcar `BLOCKED_ENV_SQLITE`; los 7 feature tests son **NOT_RUN funcionalmente / 7 ERROR setup / 0 assertions**, no fallo lógico de la API ni PASS. No repetir el mismo stacktrace siete veces en el informe; guardar log crudo una vez.
- Dart/Flutter: identificar si existe una instalación local preexistente y compatible con `pubspec.lock` **solo en rutas conocidas o PATH**. No descargas de SDK, paquetes de Internet ni cambios en otro proyecto. Si es viable, ejecutar los tests focales de parser, motor/resumen de calendario y freshness; después format/analyze focales. Si no existe toolchain, `BLOCKED_ENV_FLUTTER` con comprobación exacta; no convertir la inspección estática en prueba móvil.
- Dataset H4: prohibido modificarlo. Reportar `9/10 PASS + BOGOTÁ BLOCKED_STALE_BEFORE_VERIFICATION` si se mantiene así; cualquier otro resultado nuevo se investiga dentro del mismo ZIP. Conservar su SHA-256 `ce95abacc2968bc4267d3edaef6bf9320dba1d99d40daf56b6c7e7cc46e38341` o marcar `SOURCE_DRIFT` si cambia.

### G4 — Seguridad de Git y criterio de commit

- Las cinco rutas autorizadas son el límite total; no versionar harness ni logs. No se tocan original ni 101 WIP. No `git clean`, `reset --hard`, `checkout --`, `stash`, `gc`, merge, push o PR.
- Si **todos los gates necesarios para un commit de código seguro** pasan y existe certeza de procedencia, como máximo **UN COMMIT LOCAL** en la misma rama hija (contendrá **solo** los cinco archivos) y registrar HEAD/tree/diff/firma e historial padre. No atribuir a CI ni a móvil pruebas no ejecutadas.
- Si falta Flutter o SQLite, **no forzar commit** para simular un aprobado. Conservar el parche en working tree sin stage, registrar SHA/estado y entregar `D01_CANDIDATE_PHP_PASS_ENV_BLOCKED` si los tests PHP reales pasan. Ese estado es una entrega válida y terminal de este encargo, no excusa para crear otra fase en la misma máquina.
- Si una prueba revela una incompatibilidad superior real que requiere sexta ruta o cambio de contrato, terminar `D01_BLOCKED_DESIGN_CONFLICT`, explicar qué ley/archivo/valor contradice el plan y proponer una alternativa focal en el ZIP, sin aplicarla.

### G5 — Informe forense y antiping-pong (una sola entrega)

Preparar en una sola carpeta temporal de reportes (fuera del repo):

- `FINAL_REPORT.md`: outcome, qué se resolvió y qué sigue bloqueado; estado PHP unit, PHP feature, Flutter, dataset por separado; tabla de diez gates; versiones/SHAs, branch y HEAD, estado Git antes/después y `NEXT_ACTOR=CHATGPT`.
- `PATCH_CUMULATIVE.diff`: diff reversible completo de D01 + C1 respecto del HEAD M1F (`a4e80f...`). **No un parche que dependa de otro ZIP que quizá falte**.
- `TEST_COMMANDS_RAW.log`: comandos exactos, stdout/stderr íntegros, exit codes y entorno; nunca ocultar errores de `pdo_sqlite` ni declarar 7 tests feature PASS.
- `CALENDAR_CONTRACT_MATRIX.csv`: mínimo diez escenarios C1-01…C1-10 con esperado, observado, ejecutado/no ejecutado, fuente/archivo y SHA de entrada.
- `STALE_MATRIX.csv`: las 19 coberturas con estado real de corte, sin declarar que `reviewAt` equivale a vigencia legal ni que `FRESH` significa permiso.
- `SCOPE_GIT_PROVENANCE.txt`: diff de rutas, hashes de archivos, SHA base, estado del original, confirmación de no remotos y de los 101 WIP `NOT_VERIFIED`.
- `AUDIT_10.csv`: diez pasadas distintas con PASS/FAIL/BLOCKED/NOT_RUN precisos y evidencia primaria.
- `MANIFEST.json` con para cada payload nombre, bytes, SHA-256, CRC32; `MANIFEST.sha256`; opcional `ENV_BLOCKERS.md` si faltan herramientas.

### G6 — ZIP ÚNICO Y CRITERIO DE PARADA

1. Crear **un solo ZIP** nombrado `PICORADAR_M1F_D01_C1_CIERRE_EVIDENCIA_UNICA_20261108.zip`. No crear varios ZIP ni ZIPs dentro de ZIP. Validar CRC (`testzip`), tamaños, SHA-256 de payloads contra manifiesto, SHA-256 de `MANIFEST.json` contra `MANIFEST.sha256`; calcular SHA-256 del ZIP completo. Si falla integridad, corregir el mismo ZIP antes de cerrar, no crear otra entrega.
2. En el mensaje final de Codex, indicar resultado de cada gate en 6–12 líneas, la ruta completa del ZIP en `D:\codex\_REPORTES\PicoRadar\...`, tamaño, SHA, una URL local de descarga si UI permite y `NEXT_ACTOR=CHATGPT`. Entregar **un ZIP físico** que el usuario pueda adjuntar al chat; no presentar únicamente enlaces `D:` como prueba de que ChatGPT tiene los bytes.
3. **Terminar ahí.** No solicitar otro prompt para un problema ya reconocido. Un bloqueo de toolchain queda como bloqueo y se reabre en CI/entorno aprobado cuando ChatGPT autorice la integración, sin reiniciar M1F ni ampliar trabajo. `RELEASE=NOT_APPROVED`.

## 4. Errores y decisiones que NO deben repetirse

- No afirmar `10/10 jurisdicciones PASS`: la causa de Bogotá moto es **de datos**, no del selector D2.
- No modificar `staleAfter`, `sourceCheckedAt`, `nextReviewAt`, `verifiedAt`, dígitos ni fuentes para hacer pasar tests. La próxima revisión no extiende la vida técnica.
- No borrar taxi de octubre ni reintroducir el falso positivo M1D. El fix M1E/M1F continúa válido en su alcance, sujeto al límite de fecha corta.
- No interpretar como ERROR de negocio un fallo `pdo_sqlite` en `RefreshDatabase` antes de cualquier aserción.
- No decir Flutter PASS sin ejecutar el SDK real. No usar un clon de GitHub remoto viejo como sustituto de H4 local.
- No convertir `UNKNOWN`/`STALE` en `ALLOWED` automáticamente; no declarar que un día sin coincidencia significa ausencia de medida.
- No crear un segundo publicador, microservicio, API, esquema o motor de fechas; Laravel permanece como publicador único y Flutter como consumidor local-first.
- No añadir tareas de cámaras, peajes, tarifas, GPS, JNI, firma, alertas, 73 ciudades o producción en este delta.
- No volver a redactar órdenes D01 V2/V3 sin contraprueba material nueva. Esta C1 **es la decisión final de diseño del director para la misma ejecución**.

## 5. Ruta de cierre del proyecto tras C1 (NO ejecutar fuera de alcance)

- **Aceptación de código M1:** ChatGPT audita el ZIP único, permite integración GitHub únicamente tras procedencia y tests necesarios; si Flutter/SQLite inaccesibles localmente, define una ejecución **CI/QA aislada** en fase de integración autorizada, sin repetir diagnóstico de D1/D2.
- **M1 cobertura nacional:** recuperar fuentes oficiales y validar categorías/ciudades pendientes; conservar estado desconocido donde falten fuentes, ámbitos o frescura. Medellín tiene corte técnico declarado `2026-11-10T05:00:00Z` (00:00 Colombia): no prorrogarlo automáticamente.
- **M2 agente:** solo lee/verifica/propone; Laravel valida y publica con aprobación humana.
- **M3 integración:** versión/hash de datasets, consumo Flutter offline, cámaras locales, cuentas opcionales, privacidad y rollback; sin microservicios duplicados.
- **M4 cierre:** CI completo sobre SHA final, revisión de 101 WIP, tests físicos Android/JNI/firma, seguridad, permisos, QA y GO humano. Nunca llamar release antes de esos gates.

**CIERRE DEL PROMPT PARA CODEX LUNA. `NEXT_ACTOR_AFTER_ZIP=CHATGPT`.**