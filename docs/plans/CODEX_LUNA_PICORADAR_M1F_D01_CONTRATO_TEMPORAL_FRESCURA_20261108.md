# CODEX LUNA — PICORADAR M1F-D01 · DOS FALLAS TEMPORALES DEMOSTRADAS · CORRECCIÓN CAUSAL KISS + PONYTAIL

**TASK_ID EXACTO:** `PICORADAR-M1F-D01-TEMPORAL-FRESHNESS-SAFETY-20261108-DIRECTOR`.  
**AUTORIDAD:** ChatGPT, director técnico responsable de decisiones, alcance, seguridad y cierre. Codex Luna es únicamente ejecutor acotado.  
**ESTADO ANTERIOR:** M1F `M1F_PARTIAL_BOUNDARY` cerrado; commit **LOCAL** `a4e80fbcaa357c6ce84084e365507e974e087bab` en `fix/m1e-calendar-overlap-acceptance-local`. **NO repetir M1C, M1D, M1E o M1F**.  
**PROPÓSITO ÚNICO:** reparar en el mismo candidato (1) falso negativo de solapamiento de fechas calendarias y (2) falsificación involuntaria de frescura por prioridad `nextReviewAt` sobre `staleAfter`, según las contrapruebas independientes del director. **NO es M1G ni una nueva fase arquitectónica**.  
**OBLIGACIÓN:** entregar físicamente **un único archivo ZIP** con todas las evidencias, sin archivos dispersos. **PUBLISH_ALLOWED=NO**, **RELEASE=NOT_APPROVED**. **NEXT_ACTOR_AFTER_ZIP=CHATGPT**.

## A. Contexto forense cerrado: NO VOLVER A INVESTIGAR LOS MISMOS HECHOS

1. ZIP M1F realmente recibido y calculado: `PICORADAR_M1F_ACEPTACION_LOCAL_EVIDENCIAS_UNICAS_20261108.zip`, tamaño 23.497 bytes, SHA-256 `f94cdd7d5c103c5d49de7dc918dcfd58453a8d0207dca3b40ada7b7e6cc736d9`; **14 CRC PASS**, doce payloads con CRC/SHA/size PASS, `MANIFEST.json` SHA `e2090ed0ba55233ed1698d24156ec1ac86c958e241f8bda686dfdb20b35f87dd`. Su entrega no necesita otro preflight. Si hay clon M1F y ZIP en el host Codex, reutilizarlos directamente. Si el ZIP no está físicamente pero existe el clon/commit SHA verificado, usar el clon y marcar `SOURCE_ZIP_NOT_ON_HOST`, **no** pedir entrada repetida.
2. Base H4 local `1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c`, tree `dc2f2fdc5521af4cb4ad16969d76248b1e021688`, commit local M1F `a4e80fbcaa357c6ce84084e365507e974e087bab`, tree `0a55c0a1e3f0b268a22ed69deb990dede3ca5f4c`. Branch candidata `fix/m1e-calendar-overlap-acceptance-local`; ruta `D:\codex\_CANDIDATOS\PicoRadar-M1E-Calendar-Overlap-20261108`. **No hay remoto en el clon; no inventar upstream ni sustituir con main histórico.** El parche M1E/M1F preservado tiene SHA-256 `68d6a60026609ac38140a9f924d68289af5f8d2882ba8f58a59775d89de75a04` y sólo toca `RestrictionContractValidator.php` + dos tests. Es la base de este delta, no algo que se deba reimplementar.
3. Original protegido `D:\codex\PicoRadar`, rama `recovery/20261019-modern`, HEAD observado `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, tree `04a01f15475dd25fbcd40597120e6e44722b0504`, borrado rastreado preexistente `D scripts/tests/test_hostinger_installer_browser.ps1`; **READ ONLY**. Sin reset, clean, stash, checkout, add, merge, restore, commit, `git gc`, borrado, instalación en ese checkout. Los 101 WIP históricos `NOT_VERIFIED`: no tocarlos ni declarar que se han protegido por hash.
4. Logs M1F con **32 pruebas/86 aserciones PHP `PASS_REPORTED`**, lint PHP, Pint y `git diff --check`; evaluación schema2 de 10 jurisdicciones. Todo en entorno sintético SQLite `:memory:` y `Storage::fake`. Flutter/Dart `NOT_RUN`. No confundir esos PASS con tests que faltaban para los dos escenarios D01. La validez estructural de un conjunto no garantiza datos jurídicos actualizados, ni autorización de publicación.
5. PR #79 de PicoRadar `docs/plan-maestro-nacional-v2-20261107` **documental Draft**, PR #71 antiguo `0d3a6a2...`, `main` intacto. ChatGPT gestionará checkpoint documental. **Codex NO escribe ni hace push a GitHub, no crea PR de código ni usa credenciales remotas**.
6. Instrucciones superiores: `AGENTS.md` → Cierre Global DOCX → Arquitectura Android-first DOCX → flujos y diseño correspondiente → SOP → Plan Maestro → documentos operativos. Seis leyes PingPongLaw L1 KISS/Ponytail, L2 antirruido, L3 antiparches, L4 UX aprobada, L5 verificación de triple evidencia, L6 antipingpong. Leer apartados pertinentes ya presentes en H4; NO cambiar baselines. Si una norma superior contradice el contrato D01 propuesto, **detener SOLO ese subcambio**, registrarlo y continuar los controles no conflictivos.

## B. DOS EVIDENCIAS RED QUE YA HA PROBADO EL DIRECTOR EN PHP REAL

**No tratar esto como hipótesis de un comentario ni repetir auditoría nacional.** El director extrajo `BASELINE_H4_RestrictionContractValidator.php` del ZIP M1F y aplicó el hunk exacto de producción de `PATCH_ACCEPTED.diff` a un directorio temporal sin tocar H4. El PHP reconstruido pasó `php -l`. Ejecutó estos fixtures con igual cobertura `car/taxi`, misma prioridad, misma rotación, legal desde 2025-12-25 y misma ventana 06:00–20:00:

### RED-01 — Calendario por día (P1)

- Regla A `validFrom=2026-10-01T00:00:00-05:00`, `validUntil=2026-10-07` (solo fecha; se espera **DÍA 7 INCLUSIVO** en semántica de calendario). Regla B comienza `2026-10-07T12:00:00-05:00`. **VALOR OBSERVADO:** `ACCEPTED_NO_CONFLICT`; **ESPERADO:** rechazarlas por coexistencia el 7/oct.
- Control positivo del defecto: si A termina `2026-10-07T23:59:59-05:00`, PHP **RECHAZA** por conflicto; si A termina `2026-10-06T23:59:59-05:00`, PHP correctamente **ACEPTA**.
- Ruta causal: `server/app/Services/RestrictionContractValidator.php`, `optionalScheduleDate` -> `date` -> `dateRangesOverlap`. La fecha corta de fin queda en medianoche y provoca falso negativo cuando la segunda regla empieza más tarde ese mismo día. Comprobar en el **código H4 móvil real** que `scheduleValidUntil` es fecha de calendario inclusiva (como documentó M1F), antes de tocar su producción. El código H4 antiguo no está en PR71 remoto.

### RED-02 — Frescura ignorada (P1)

- Cobertura esquema 2 sintética: `sourceCheckedAt=2026-10-24T23:17:18Z`, `staleAfter=2026-09-23T05:00:00Z`, `nextReviewAt=2026-11-24T05:00:00Z`. **SALIDA PHP REAL:** `summary_staleAfter=2026-11-24T05:00:00+00:00`; el vencimiento explícito del 23/sept fue ignorado.
- Ruta causal PHP: `RestrictionContractValidator.php` invoca `dateEither($coverage,'nextReviewAt','staleAfter')`, dando prioridad al campo de revisión. Ruta Flutter H4 reportada: `mobile/lib/features/pico_placa/data/restriction_dataset.dart` prefiere igualmente `nextReviewAt` para el instante de `dataIsStale` persistido, usado por `restriction_store.dart` y el motor.
- Documento de autoridad inferior pero relevante: `docs/agents/PICORADAR_SOURCE_AGENT_OPERATING_CONTRACT_V1.md` distingue literalmente `next_review_at` (vigilancia) y `dataset_stale_after` (TTL técnico). El Plan Maestro exige preservar la semántica de `staleAfter`. **Ningún próximo review puede prolongar un staleAfter explícito ya caducado**. Esto NO equivale a afirmar que el teléfono ya mostró `ALLOWED`.

**Dos defectos de contrato distintos; UN ÚNICO DELTA acotado.** NO tocar municipio, dígitos, fuente legal, geocerca o permiso de circulación. No intentar solucionarlo extendiendo o inventando fechas de los archivos JSON.

## C. ÁMBITO POSITIVO — QUÉ PUEDE MODIFICAR CODEX

Dentro de una **rama hija local y aislada**, nacida **exclusivamente** de `a4e80fbcaa357c6ce84084e365507e974e087bab` ya aceptado (o mismo clon en nueva branch sin cambiar la original ni el checkout usuario), se autorizan **máximo cinco rutas existentes**, sujetas a `git ls-tree`/lectura antes de escribir:

1. `server/app/Services/RestrictionContractValidator.php` — normalización segura del calendario + tratamiento seguro de dos fechas de frescura.
2. `server/tests/Unit/RestrictionContractValidatorTest.php` — RED/GREEN de ambos casos, regresiones de bordes y sourceCheckedAt.
3. `server/tests/Feature/RestrictionPublicationServiceTest.php` — gate sin publicación (solo si la nueva validación impacta el candidato con una incongruencia real).
4. `mobile/lib/features/pico_placa/data/restriction_dataset.dart` — selector de frescura del parser **solo si** el contrato H4 y las normas superiores confirman ese punto. Sin cambio de esquema/Drift.
5. **Test móvil EXISTENTE** correspondiente al parser de restricciones; ubicar el path exacto con `git ls-tree`/`rg` y usar esa ruta, NO crear estructura nueva. Si no existe un test apropiado, registrar `TEST_LOCATION_NOT_FOUND` y no inventar un componente nuevo; como alternativa mínima se autoriza un test junto a los tests existentes, explicitando la ruta final en el reporte.

**No más de dos archivos de producción, ningún archivo de datos ni de infraestructura, y solo tests directamente necesarios.** Si una tercera ruta productiva resulta imprescindible o un contrato superior discrepa, **NO ampliarla por cuenta propia**: terminar `BLOCKED_SCOPE_OR_CONTRACT` en el mismo ZIP, adjuntando la causa. No modificar `AGENTS`, baselines, leyes, `composer.lock`, schema, APIs, `datasets`, `mobile/assets`, `.env`, teléfono, CI, publicidad, cámaras o escritor/editor Laravel. No crear clases paralelas, librerías calendáricas, cron/jobs ni base de datos nueva.

## D. CONTRATO DE SOLUCIÓN DECIDIDO POR CHATGPT — SIN CAMBIAR NORMAS SUPERIORES

### D1. Calendario

- La vigencia **legal** `legalValidFrom` / `legalValidUntil` y su `...Exclusive`, y la **rotación** `rotationPeriodStart` / `rotationPeriodEndExclusive`, conservan su significado de H4. No normalizar a un mismo tipo con atajos indiscriminados.
- Para los campos de **calendario** `validFrom`/`validUntil` de reglas con `legalValidFrom`, normalizar el intervalo por **DÍAS calendario efectivos en `America/Bogota`** solo si el modelo Dart confirma inclusividad de la fecha de fin. En comparación de solapamiento, el `validUntil` de fecha corta `2026-10-07` debe cubrir todo el 7/oct. Para timestamp, cotejar contra la proyección a día que **realmente haga H4 móvil**, no suponer que `12:00` recorta un calendario por horas.
- Mantener las intersecciones ya existentes de intervalos legales y rotación; rechazar conflictos de la misma prioridad/ámbito realmente simultáneos. Reglas taxi de Bogotá Oct1 y Oct7 con calendario disjunto siguen siendo válidas. Los días adyacentes no son necesariamente conflictivos. Bounds ausentes/ambigüos NO permiten asumir disjunción.
- Para horarios que cruzan medianoche, comprobar cómo Flutter ancla la parte posterior a la fecha efectiva. Si la equivalencia no es demostrable, escoger regla conservadora de NO permitir falso negativo y reportar diferencia; NO construir motor complejo sin necesidad.

### D2. Frescura y revisión

- `staleAfter` explícito es tope técnico de frescura. **NUNCA** desplazarlo hacia adelante al encontrar un `nextReviewAt` posterior, y NO usar validación jurídica como extensión de TTL. `nextReviewAt` es fecha programada de revisión, campo semánticamente distinto.
- **Guardia conservadora mínima, sin schema nuevo:** si ambos campos existen y son válidos, el corte usado para `dataIsStale`/seguridad debe ser **el más temprano de ambos**, nunca el más tardío; preserva el comportamiento actual cuando `nextReviewAt` vence antes y corrige el riesgo cuando `staleAfter` vence primero. Con un solo campo, conservar el fallback legítimo existente y marcar en informe que es legado/incompleto; sin campo, **nunca marcar fresco por omisión**.
- El PHP de validación/summary y el consumidor Flutter deben coincidir en esa guardia si el contrato superior la permite. Si `staleAfter` ya venció antes de `sourceCheckedAt`, NO ocultar esa inconsistencia con una fecha posterior; puede **fallar legítimamente la validación del dataset**. No corregir JSON para convertir ese FAIL en PASS. Separar error de procedencia/datos de error algorítmico.
- Si una norma superior explícita obliga un significado distinto, **STOP ese subcambio** con cita ruta+sección+SHA y alternativa conservadora acotada en el ZIP. No sobrescribir normas ni hacer greenwashing.

**No se autoriza un algoritmo genérico nuevo de vigencias ni un segundo publicador.** Reusar funciones/clases existentes y el primer camino completo Ponytail.

## E. GATES DE UNA SOLA EJECUCIÓN — SÓLO LOS NUEVOS

### G0. Candidato y contratos — NO REHACER PREVIO

1. Verificar una sola vez `git cat-file -t a4e80f...`, tree/branch, `git status --short`, `git show --format=fuller --stat`, `git diff a4e80f...^ a4e80f... --name-only` y hash de tres rutas; tomar SHA del estado H4 móvil **real**. Guardar evidencia en `GIT_LOCAL_PROVENANCE.txt`. Si usuario modificó el candidato después de M1F, NO pisarlo; registrar `INPUT_CHANGED` y terminar a menos que una rama nueva limpia desde commit verificado sea posible sin escrituras destructivas.
2. Leer solo fragmentos pertinentes de `AGENTS.md`, baselines DOCX, `docs/CURRENT.md`, `docs/SOP.md`, Plan Maestro, `RestrictionContractValidator.php` y el modelo móvil H4 `scheduleValidFrom`/`scheduleValidUntil`, `restrictionRuleMatchesScheduleDates`, parser `_stringEither` y `dataIsStale`. No usar el remoto PR71 como sustituto H4. Dejar `NORM_PRECEDENCE_REPORT` con rutas y hechos comprobados.
3. Si el clon M1F no está disponible pero el ZIP de evidencias sí: **el ZIP solo incluye baseline/diff, no árbol Git completo**. No reconstruir un supuesto HEAD válido; `BLOCKED_LOCAL_COMMIT_INPUT` en un ZIP y terminar. No solicitar de nuevo 101 WIP, ni repetir fuentes M1.

### G1. Contraprueba RED H4 — exactamente dos casos

1. Añadir pruebas focales **sin modificar datos**: calendario A termina `2026-10-07` (día inclusivo), B inicia 7/oct a las 12:00 mismo ámbito/prioridad: el código M1F **debe** demostrar aceptación errónea; con timestamp explícito fin 23:59:59 rechaza; fin 6/oct acepta. Atribuir el resultado a PHP real H4/commit M1F, no a mera opinión de informe.
2. Frescura: con ambos campos discordantes, PHP debe demostrar resumen preferido 24/nov sobre vencimiento 23/sep. En Dart, crear test equivalente si Dart ya funciona; si no, `DART_RED_NOT_RUN`, no inventar pantalla verde.
3. Guardar `RED_RAW.log` con comandos, cwd, versión, exit codes y motivo de que un caso RED sea EXPECTED_FAIL. **Una prueba RED que detecta el bug no es un fallo de G1**.

### G2. Implementar causa mínima (si G0/G1 y normas permiten)

1. Cambiar el menor número de líneas posible. Preferir una pequeña normalización de límites calendarios dentro del validador PHP existente (sin mover `legalValidUntilExclusive` ni `rotationPeriodEndExclusive`) y tests muy focales.
2. Corregir prioridad de campos frescura en PHP y parser Flutter siguiendo D2, **solo** donde actualmente decide estado y summary. Si hay una sola fuente real para esa selección, editar una sola función. No renombrar API ni migrar datos.
3. Añadir casos GREEN: los tres del director; límites fecha corta `validUntil` frente a un segundo inicio dentro del mismo día; mismo caso como timestamp; día siguiente; dos reglas realmente simultáneas; incertidumbre/missing; offset y madrugada. Para frescura: ambos iguales, staleAfter anterior, nextReviewAt anterior, solo un campo cada vez, ambos ausentes, `sourceCheckedAt` posterior al TTL, instante exacto UTC del límite y `UNKNOWN/STALE` en motor si hay test ejecutable.
4. Cualquier cambio que provoque FAIL esperado de la jurisdicción Bogotá completa **por datos incoherentes** se etiqueta `DATA_BLOCKED_EXPECTED` y se deja sin publicarse; no ajustar fechas ni forzar el test a PASS. Prueba de contrato del JSON = `PASS/FAIL` real, no greenwashing.
5. No introducir nuevas dependencias, módulos, esquema, tablas, sincronizadores, cron o validadores paralelos. **Un único delta local**: no reabrir M1E ni preparar un segundo parche sucesivo si este gate queda parcial.

### G3. Pruebas y regresiones con trazabilidad

- Ejecutar `php -l` de archivos PHP tocados, `vendor/bin/pint --test` en el scope mínimo, `git diff --check`, PHPUnit **unitario del validador** y **feature de publicación** solo cuando corresponda; guardar stdout+stderr completos y exit codes, versión PHP/PHPUnit/Pint, rutas, SHA del árbol bajo prueba. `Storage::fake` y SQLite `:memory:` solamente.
- Si Flutter/Dart está disponible **en el entorno ya instalado**, ejecutar test del parser/frescura y test de scheduleDate aplicable; anotar versión y exit. Si no está, **NO instalar global ni ejecutar ADB/QA físico**; `DART_TESTS=NOT_RUN`, `RELEASE=NOT_APPROVED`. Revisar bytes del código H4 en modo read-only aun sin SDK.
- Reutilizar las 32 pruebas previas solo si sus entradas/implementaciones no cambiaron materialmente; como aquí cambia la producción PHP, sí correr las suites PHP focales nuevas. No disparar 3.000+ Flutter tests ni CI externo para un delta de prueba PHP.
- Comprobar que 1) conflicto taxi Oct1 y Oct7 sigue resuelto, 2) solape real con día inclusivo REJECT, 3) dato moto con staleAfter vencido NO puede resultar fresco solo por próxima revisión, 4) una fecha ausente no se convierte en `ALLOWED`, 5) el publicador Laravel sigue siendo único y no se publica nada.
- Comparar efectos con `M1F` padre y SHA de datos; si una prueba material falla, resultado `PARTIAL`/`FAIL`, NO commit que se declare aprobado y NO ampliación de scope. Registrar bloqueo directo sin otro preflight.

### G4. Preservar código sin escribir a remotos

- Si G0–G3 mínimos pasan y el ámbito es ≤5 rutas, realizar **máximo un commit local nuevo** en una rama hija separada de `a4e80f...`; nombre sugerido `fix/m1f-d01-temporal-freshness-local`. Si ya existe un commit equivalente bajo mismo SHA, reusar y no hacer segundo commit.
- Registrar `git show --name-status --format=fuller`, parent y tree, `git diff a4e80f..HEAD --check`, hashes por archivo y diff **exacto** del delta, no del M1E completo. No `git add .`, limpiar, resetear, modificar original o remotos. Si hay failure/contrato superior, conservar diff reversible sin commit y entregar ZIP.
- Proteger checkout original `D:\codex\PicoRadar` con lectura de HEAD/tree/status pre/post no invasiva; WIP 101 sigue `NOT_VERIFIED` si no se lee, pero **no se debe inspeccionar en esta orden**.

### G5. Matriz de frescura y decisiones

- Reutilizar `COVERAGE_STALENESS_MATRIX.csv` M1F, 19 filas, y clasificar cada cobertura con `staleAfter`, `nextReviewAt`, `effective_cutoff`, `as_of`, `coverage_status`, `source_note`, `risk`, sin mutar el dataset. `NOT_RUN` donde no hubo evaluación móvil. Incluir Bogotá moto y taxi, Medellín ambos (TTL técnico 2026-11-10 00:00 COT), Cartagena y Dosquebradas con campo ausente, no declarar ciudades READY.
- Registrar separado: `DATASET_CONTRACT_PASS/FAIL`, `MOBILE_SOURCE_STATIC_PASS/FAIL`, `MOBILE_RUNTIME_PASS/NOT_RUN`, `PUBLISH_ALLOWED=NO` y `CI=NOT_RUN`. Nunca mezclar.
- Mantener M1 nacional→M2 lector con revisión Laravel→M3 Flutter/cámaras→M4 CI/QA físico/firma; este delta no replanifica ni sustituye los hitos existentes.

### G6. ÚNICO ZIP DE SALIDA; SIN ARCHIVOS DISPERSOS

Crear exactamente **un** `PICORADAR_M1F_D01_CONTRATO_TEMPORAL_FRESCURA_EVIDENCIA_UNICA_20261108.zip` en directorio de reportes nuevo **fuera de Git y fuera del checkout original**, con las entradas mínimas:

- `FINAL_REPORT.md`: TASK_ID, parent SHA, resultado por G0–G5, estado de los dos casos RED/GREEN, decisiones y limitaciones, `NEXT_ACTOR=CHATGPT`, `PUBLISH_ALLOWED=NO`, `RELEASE=NOT_APPROVED`.
- `RED_RAW.log`: reproducción directa de dos defectos sobre commit M1F antes del delta; comandos/exit code y expected behavior.
- `TEST_COMMANDS_RAW.log`: pruebas PHP y Dart ejecutadas o NOT_RUN y motivo, stdout/stderr íntegros, versiones y SHA bajo prueba.
- `GIT_LOCAL_PROVENANCE.txt`: parent/HEAD/trees/local branch, SHA de módulos, remotes none, original pre/post, 101 WIP NOT_VERIFIED.
- `PATCH_D01.diff`: delta relativo a `a4e80f...`, con `SHA256`, rutas exactas y estadística; NO duplicar el diff M1E de 438 líneas innecesariamente.
- `TEMPORAL_CONTRACT_MATRIX.csv`: matriz de los casos GREEN y FAIL/NOT_RUN con evidencia por test.
- `COVERAGE_STALENESS_MATRIX_D01.csv`: 19 filas (u número real con denominador explícito) y decisiones de fecha sin editar fuentes.
- `SCOPE_AND_LAWS.md`: tabla L1–L6, baselines leídos, archivos tocados y razón de cada uno.
- `AUDIT_10_D01.csv`: diez verificaciones con PASS/FAIL/BLOCKED/NOT_RUN y evidencias reales.
- `MANIFEST.json`, `MANIFEST.sha256` con bytes, SHA-256, CRC32 para payloads. Verificar `zipfile.testzip()` o equivalente y manifiesto después de cerrar ZIP. Reportar SHA-256 del ZIP externo.

**UN SOLO ARCHIVO ZIP adjuntado como bytes en ChatGPT** (no basta enlace `D:\...` o log impreso). No incluir `vendor`, `.env`, PII, secretos, SDK, bases de datos reales, ni fuentes históricas enormes. Limpiar solo temporales **creados por esta ejecución** si es seguro, jamás originales.

## F. DECISIÓN DE SALIDA SIN PINGPONG

| Situación demostrada | Resultado terminal de este ÚNICO DELTA | Siguiente actor |
|---|---|---|
| RED y GREEN PHP/Freshness PASS, H4 Dart test ejecutado PASS, código local acotado | `D01_PASS_LOCAL_SCOPE` (NO release) | ChatGPT |
| PHP PASS pero Dart no disponible | `D01_PARTIAL_DART_NOT_RUN` (NO publicación) | ChatGPT |
| Contrato superior desautoriza D2, o H4 Dart semántica difiere y requiere decisión | `D01_BLOCKED_CONTRACT` con punto y alternativa mínima | ChatGPT |
| Falla de prueba material o nueva regresión | `D01_FAIL_REPRODUCED` con diff/log, sin declararlo PASS | ChatGPT |
| El delta ya existe con commits y fuentes verificables | `D01_REUSE_EXISTING` sin nuevo commit ni otra tarea | ChatGPT |

Codex **NO crea M1G, no pide otra auditoría general ni amplía el alcance**, nunca altera políticas/leyes o datos para que pase un test. Si falta un comando sencillo, máximo un reintento controlado en el mismo gate, después registrar causa. No prometer trabajo asíncrono ni publicar remotamente.

**FIN DE ORDEN PARA CODEX LUNA. CHATGPT CONSERVA DIRECCIÓN, RESPONSABILIDAD Y SIGUIENTE DECISIÓN.**