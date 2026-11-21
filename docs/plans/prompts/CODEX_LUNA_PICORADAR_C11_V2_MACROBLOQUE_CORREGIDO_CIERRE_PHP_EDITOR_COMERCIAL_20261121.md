# CODEX LUNA — PICORADAR C11-V2: EJECUTAR PHP REAL + CERTIFICAR EDITOR NACIONAL + CERRAR MAPPER COMERCIAL + PUENTE SEGURO A MAIN

**DESTINATARIO: CODEX LUNA. ESTE C11-V2 SUSTITUYE POR COMPLETO EL C11 ORIGINAL SI TODAVÍA NO SE HA INICIADO. EJECUTA UN MACROBLOQUE DE IMPLEMENTACIÓN Y CERTIFICACIÓN, NO OTRA AUDITORÍA.**

- `TASK_ID=PICORADAR_C11_V2_20261121`
- `NEXT_ACTOR=CODEX_LUNA`
- **BASE REMOTA VERIFICADA**: rama `feat/C11-docker-bootstrap-cache-fix-20261121`, HEAD **`7d843d39bb57519b3b9b9e2430f578d9e09cf228`**. **No usar** el HEAD obsoleto `db1e28545a9de7d221d42fb85b4e8c68ccf42551` del C11 anterior.
- **PRODUCCIÓN**: `PRODUCT_RELEASE=NO_GO` hasta pasar los gates de servidor, Android físico, HTTPS y reglas oficiales. Ningún test estático es una certificación de producción.
- **C10 protegido**: `77dd816445ee1d0234f9a54ff965f4b5dd99fbcb`, PR [#88](https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/88) `OPEN/DRAFT`, base C9. No cambiar base ni fusionar por rutina.
- **MAIN**: HEAD de referencia `e9ef37511df3110ffb0fc006ef06be781df432ac` observado por el director; actualizar lectura **una vez**, sin alterar `main`.

## 1. Lo que YA está hecho: prohibido cobrarlo otra vez como progreso

1. Código fuente C10-V2 del Super Admin: municipalidad → creación de jurisdicción → botón «Crear borrador de restricciones» → formulario nacional `schema2`, preselección GET, DIVIPOLA y `consultationEnabled` independientes, creación de Draft sin publicación. **Implementado, pero PHP todavía no ejecutado**.
2. Código móvil C10-V2: `campaign_territory_mapper.dart` utiliza `municipalityCodes` de OTA cuando es un único DIVIPOLA válido; ante código ausente, múltiple, ambiguo o inválido usa una referencia conservadora; fallback histórico solo por ID exacto. **Siete pruebas Dart escritas, ninguna ejecutada en C10**. Publicidad pública permanece apagada.
3. Selector Pico C9: **1.104/1.104 municipios colombianos seleccionables**, probado en C9. **NO** equivale a que existan 1.104 reglas jurídicas verificadas. C9 Flutter: **29 PASS, 1 SKIP, 0 FAIL**; OTA y consentimiento tienen PASS focal anterior. No repetir esos tests si sus blobs no cambiaron.
4. C8/C9/C10 PHP: **cero ejecuciones de PHPUnit** debido a bloqueos Docker anteriores, no porque las pruebas hayan fallado. C10 introdujo `libsqlite3-dev`; el director C11 adelantó la creación de `bootstrap/cache` antes del `composer install`, más la prueba de orden.
5. El director corrigió en C11 **dos familias de aserciones HTML incompatibles** con la vista verdadera: `<strong id="jurisdiction-management-state">` y las opciones con `data-management-state="activa"`. Las **cinco coincidencias** de `data-municipality-code="..." selected>` fueron sustituidas (incluida una comprobación negativa potencialmente falsa). **No reescribir esas aserciones** salvo si una ejecución real demuestra otro problema.
6. Archivos GitHub C11 verificados en HEAD exacto: `server/Dockerfile.qa` (blob `136983d65c9478528f934957aae1a75b2af5a07d`), `scripts/tests/test_picoradar_docker_isolation.py` (blob `c41ca7f5df19e5321152e2cd5859c0cf41818298`), `server/tests/Feature/C10NationalEditorEntryTest.php` (blob **`ce28482bd0515dc1b098c929ec151bbe1d5d7a10`**). No cambiar estas piezas por prejuicio.
7. C11 tiene 10/10 **comprobaciones estáticas de contenido** del director. No confundir con `python unittest`, Docker, migraciones o PHPUnit ejecutados en el PC.
8. Servidor Laravel, motor nacional, visor de cobertura editorial/publicada, matriz municipal, publicación y rollback, campañas de administración y controles del Super Admin **ya existen**. Aprovecharlos; no crear un cuarto catálogo, otro editor ni otro servicio.

### Barreras de arquitectura innegociables

- Director ChatGPT decide y audita solo deltas; Codex Luna ejecuta. KISS, un solo flujo de estado territorial, fuente oficial por municipio/categoría/vigencia, esquema OTA nacional único verificable, sin reglas hardcodeadas por ciudad en Flutter.
- `UNKNOWN / PARTIAL / STALE` **no significan** “puede circular”. Una ciudad sin restricción solo puede declararse **verificadamente sin restricción** con fuente y vigencia suficientes; una jurisdicción administrativa habilitada **no es** consulta pública habilitada.
- Placas y documentos (cédula, contrato, fotografías) no deben ir al servidor; mantenerlos solo donde esté diseñado el almacenamiento local seguro.
- Free 1.0: campañas, marketing, publicidad pública, pagos y módulos comerciales **apagados** por defecto. Se puede terminar administración y targeting sin publicarlos ni fingir revenue.
- El computador Windows tiene **varios proyectos Codex simultáneos**. PHP/MariaDB solo en Docker Compose **por proyecto y por ejecución**: redes/volúmenes/secretos aislados, sin puertos publicados, sin mounts de otros repositorios, sin tocar servicios PHP/MariaDB del host, sin `docker system prune`, `docker volume prune`, `docker compose down -v`, reset/force push ni borrar caches globales de Docker.
- Todos los cambios en rama C11 o ramas de agente nacidas de C11. No tocar `main`, PR #79/#86/#87/#88, worktrees protegidos ni las 43 rutas WIP. Preservar evidencia y código en GitHub para recuperación en otro chat.

## 2. Decisión de ejecución: **un solo build y un solo filtro PHP tras consolidar agentes**

**Problema corregido del C11 original:** ordenar al agente A ejecutar PHPUnit y después pedir al agente B que agregue otro test obligaba a reconstruir el checkout/imagen o repetir la suite. Ahora los trabajos se preparan en paralelo y se aplica **una barrera de integración**: el integrador reúne primero los cambios de B, congela un worktree limpio, y **solo entonces** dispara el runner PHP. La falta de Docker nunca paraliza el trabajo independiente de Dart o documentación verificable.

### P0 — Preflight corto y comprobable

1. `git fetch` solo del repositorio PicoRadar; confirmar `HEAD` remoto de `feat/C11-docker-bootstrap-cache-fix-20261121`. Si cambió respecto a `7d843d39…`, examinar únicamente el delta nuevo, no reiniciar ni pisar otros commits. Crear worktrees o clones **nuevos y aislados**, sin limpiar ramas WIP ni carpetas de proyectos ajenos; cada agente mantiene su propia rama/propiedad. Si existe checkout sucio, crear otro worktree, **no** `reset --hard`.
2. Confirmar por blob los tres archivos corregidos, verificar que `server/Dockerfile.qa` cree `bootstrap/cache` **antes** de Composer, que `pdo_sqlite` y `libsqlite3-dev` estén presentes, y que el runner fuerce `DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:` y `DB_URL=` para modo test.
3. Comprobar disponibilidad **sin instalar nada global**: Docker Engine, `docker compose`, PowerShell permitido (`pwsh` o PowerShell de Windows) y Flutter/Dart existente. Si un binario falta, registrar `BLOCKED_ENV` y ejecutar los demás frentes; no repetir búsquedas largas ni instalar SDK de otros proyectos.
4. Crear agentes en paralelo con propiedad de archivos estricta: **A infraestructura/QA, B editor nacional, C mapper Flutter y D puente `main` de solo lectura**. Solo el **integrador** aplica los commits y hace push a C11.

### Agente A — infraestructura sin reconstruir imágenes todavía

**Propiedad:** `server/Dockerfile.qa`, `scripts/run_picoradar_docker_qa.ps1`, `scripts/tests/test_picoradar_docker_isolation.py` solo si aparece un fallo nuevo causado por esos archivos. No tocar código de negocio.

- Desde un worktree C11 limpio ejecutar **una sola vez** `python -m unittest scripts/tests/test_picoradar_docker_isolation.py` o `py -3 -m unittest ...` con Python disponible. Esperado **10 casos**; registrar número real, exit code. Si Python falta, registrar `STATIC_PY_BLOCKED` y seguir. No confundir el 10/10 de chequeos GitHub previos con esta ejecución.
- Inspeccionar **una sola vez** si Docker Engine y Compose funcionan. No reconstruir todavía: el integrador ejecutará Docker **solo cuando B haya terminado sus cambios** y el árbol final esté limpio.
- Si está permitido ejecutar Docker, entregar al integrador el comando listo, sin secretos ni parámetros ajenos. Si hay prohibición de política o falla de red en `apt-get`/Composer, reportar etapa exacta, código de salida y líneas saneadas; **no instalar PHP o MariaDB en el host**, no apagar ni limpiar otros contenedores. Solo cabe **una corrección causal mínima** y un reintento en el lote, no bucle de builds.
- No cambiar `name`, `networks` o `tmpfs` a valores compartidos. El launcher ya genera un nombre de proyecto efímero, guarda secretos en el proceso y limpia exclusivamente recursos propios.

### Agente B — cierre funcional del editor, sin duplicar pruebas

**Propiedad:** `server/tests/Feature/C10NationalEditorEntryTest.php` y, **si falta una transición material**, un único `server/tests/Feature/C11NationalEditorialFlowTest.php`; controladores/vistas **solo si** un defecto concreto es demostrable por el test. No tocar infraestructura ni mobile.

1. Revisar **solo** los métodos de `C9JurisdictionOnboardingTest.php` y `C10NationalEditorEntryTest.php` para identificar la cobertura ya presente; no rehacer auditoría PHP. Ambas suites ya tienen pruebas de permisos, creación, preselección, DIVIPOLA, selector vacío, consulta OFF y Draft no publicado.
2. Un caso de integración nuevo está permitido **solamente** si falta cubrir de forma conjunta el recorrido municipio sin jurisdicción → alta desde matriz → ficha → botón crear borrador → `schema2` → Draft no publicado. Reutilizar fixtures simples de `GeographicUnit`, `Jurisdiction`, `Dataset`, `User`; sin fuentes jurídicas inventadas, HTTP saliente ni DB real. Si los C9/C10 ya prueban todas esas transiciones con suficiente garantía, **no crear otro test**. En ambos casos B debe entregar un resultado concreto `FLOW_ALREADY_COVERED` o `NEW_TEST_WRITTEN` con los métodos que sustentan la decisión.
3. Cuando proceda crear test, comprobar que rol **Editor** funciona; **Reviewer** y **Commercial** no pueden guardar borradores; municipio sin DIVIPOLA no habilita consulta; un GET no crea datos; un POST autorizado no publica `DatasetRelease` ni `RestrictionPublication`. Una única prueba focal de integración puede concentrar recorrido + observaciones esenciales: no duplicar toda C9/C10.
4. El GET preselecciona la jurisdicción solo si existe y está habilitada. El `<option>` incluye **ambos** `data-municipality-code` y `data-management-state`; no volver a usar expectativas HTML obsoletas. Asegurar que al cambiar de municipio el DIVIPOLA visible se actualiza, `consultation_enabled` se desmarca y la opción inválida nunca autoriza consulta. El payload POST/servicio existente es la autoridad final, no confiar en el checkbox JS como seguridad.
5. Si aparece un defecto real al ejecutar PHPUnit, corregir **solo el flujo afectado**, conservar dos roles separados para revisión/publicación y documentar efecto en SHA. No inventar normativa ni convertir alta administrativa en publicación.
6. **No ejecutar PHPUnit ni Docker durante el trabajo paralelo**. Hacer commit independiente; el integrador incorpora B y lo ejecuta **una vez en el lote final**.

### Agente C — finalizar segmentación comercial del motor OTA

**Propiedad:** `mobile/lib/features/home/domain/campaign_territory_mapper.dart`, `mobile/test/features/home/domain/campaign_territory_mapper_test.dart` y una línea de integración Home **solo si un caso real falla**. No editar servidor.

1. Los siete tests están escritos desde C10. No volver a programar mapper sin correrlos. Desde la raíz `mobile` usar, si SDK instalado: `dart format --output=none --set-exit-if-changed lib/features/home/domain/campaign_territory_mapper.dart test/features/home/domain/campaign_territory_mapper_test.dart`, y `flutter test test/features/home/domain/campaign_territory_mapper_test.dart`. Si hay análisis focal disponible, realizarlo solamente sobre archivos cambiados; no disparar toda la suite.
2. Registrar **resultado real** `7/N PASS`, número exacto si difiere, SKIP/FAIL y exit code. Si falta SDK, `DART_BLOCKED_ENV`; **no se convierte en PASS por revisión visual**. No descargar toolchain no autorizada ni cambiar PATH global.
3. Comprobar caso de localidad nueva que llega por OTA con único DIVIPOLA; múltiples/ambiguos/invalidación quedan sin segmentación municipal positiva; fallback histórico solo por id exacto; no inferir municipio por nombre ni guardar placa; sin activación de publicidad pública. Cambiar código **solo** si un test ejecutado o defecto reproducible lo requiere.
4. No repetir Flutter C9 (29 PASS/1 SKIP), OTA, consentimiento, selector 1.104 o pruebas comerciales PHP anteriores con blobs intactos.

### Agente D — integración hacia `main` sin reabrir 1.078 rutas

**Solo lectura mientras A/B/C trabajan.** Usar el preflight Git ya creado en el proyecto si está presente, pero **no volver a recorrer diez auditorías históricas**. Confirmar `main` actual, su historia y si el árbol nacional es descendiente de un backup huérfano. Identificar como máximo: (i) la rama fuente C11, (ii) rama base `main`, (iii) archivos exclusivos de `main` que no deben perderse y (iv) la primera dependencia real que impide una integración segura.

No cambiar `main`, no hacer merge de historias no relacionadas, no copiar todo el árbol ni mover 43 rutas protegidas. Si tras PHP/Dart `PASS` y dependencias completas resulta viable crear rama nueva **descendiente de `main`** para una reconciliación pequeña, pasar al integrador un plan de archivos de alcance acotado con precondiciones verificables; en caso contrario reportar `MAIN_BRIDGE_HOLD` y **una única siguiente acción**. **No crear PR Draft adicional por producir un diagnóstico**.

## 3. Barrera única del integrador y puertas de aceptación

**Orden obligatorio:** A/B/C/D trabajan en paralelo → B y otros agentes publican commits en sus ramas aisladas → integrador revisa solamente esos deltas y los aplica sobre C11 → verifica worktree limpio y SHA exacto → **una sola ejecución PHP conjunta**. No dejar que el agente A construya Docker sobre una rama provisional y después repetir todo por cambios del agente B.

### Comandos de aceptación, desde el checkout C11 ya consolidado y limpio

1. `git diff --check` + `git status --porcelain`; si el trabajo está sin commitear, primero un commit normal en la rama aislada C11 (no force push). Docker `COPY . .` debe ver el mismo código que GitHub certificará.
2. Prueba PHP focal, **un solo filtro conjunto**, invocando `pwsh` si existe y la política lo permite; en Windows PowerShell también puede usarse `powershell.exe -NoProfile -File ...` sin eludir políticas:

```powershell
pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode test -Filter 'C8RestrictionCurrentCoverageTest|C9JurisdictionOnboardingTest|C10NationalEditorEntryTest|C11NationalEditorialFlowTest'
```

`C11NationalEditorialFlowTest` es **opcional**: si no existe, omitir ese patrón y usar únicamente los tres primeros. Ejecutar el comando **una vez** desde worktree limpio. El runner crea un Docker Compose nuevo, no usa MariaDB del host, construye PHP en imagen y fuerza SQLite en memoria para PHPUnit. Registrar `PHPSUITE_PASS` solo si hay **test count >0**, cero fallos y código de salida 0; capturar nombres de clases y número real de tests/aserciones. Un filtro que no encuentra pruebas **NO es PASS**.

3. Si falla la construcción, clasificar exactamente `BLOCKED_DOCKER_ENGINE`, `BLOCKED_DOCKER_NETWORK`, `BLOCKED_DOCKER_BUILD`, `BLOCKED_POLICY` o `FAIL_TEST`. Capturar etapa concreta (`apt`, extensiones, Composer, package-discover, PHPUnit) y una línea raíz saneada; no confundir fallos de test con entorno. **Máximo una corrección causal mínima y una nueva ejecución**; si sigue bloqueado, seguir publicando el código B/C que haya pasado sus gates independientes, sin inventar PHP PASS.
4. **Solo tras PHP SQLite PASS** ejecutar `-Mode schema` una vez en otro proyecto Compose efímero aislado para MariaDB, registrar resultado de `migrate` y `migrate:status`. Si falla MariaDB, separar `PHP_SQLITE_PASS` de `MARIADB_SCHEMA_BLOCKED`; no borrar volúmenes ajenos ni desactivar otras instancias.
5. Para Dart, aceptar exclusivamente el resultado de ejecución del agente C, no ejecutar por duplicado. Integrar solo código/test nuevo realmente necesario y verificar que los switches comerciales públicos sigan OFF.
6. Hacer un push **normal**, no forzado, de la rama C11, verificar HEAD/tree/blobs remotos; cambios GitHub son obligatorios. **No merge a `main`, no deploy, no APK/AAB, no publicar reglas legales o campañas**. PR #88 continúa Draft; si no hay preparación de main suficientemente segura, no crear un quinto Draft sin valor.

### Condiciones explícitas de aceptación

| Gate | Para pasar | Si no pasa |
|---|---|---|
| `SOURCE` | GitHub C11 HEAD y archivos exactos, worktree limpio, commits identificados | `BLOCKED_SOURCE` |
| `STATIC_DOCKER` | unittest focal con conteo >0 y exit 0 | `FAIL_STATIC` o `BLOCKED_ENV` |
| `DOCKER_IMAGE` | build real finaliza con código 0 | `BLOCKED_DOCKER_BUILD` |
| `PHP_C8_C9_C10` | tests focales reales de las tres clases con conteo >0, 0 FAIL | `FAIL_TEST` o `BLOCKED_ENV` |
| `EDITOR_NACIONAL` | GET/POST/roles/DIVIPOLA/Draft cubiertos por PHP focal que pasó | `IMPLEMENTED_UNEXECUTED` |
| `MARIADB_SCHEMA` | migrations/migrate:status sobre entorno aislado aprobado | `BLOCKED_ENV` / `FAIL_SCHEMA` |
| `COMMERCIAL_DART` | 7 casos del mapper ejecutados con 0 FAIL (conteo real) | `BLOCKED_ENV` / `FAIL_TEST` |
| `GITHUB` | C11 HEAD remoto verificado, sin modificar main/PRs anteriores | `FAIL_GIT` |
| `MAIN_BRIDGE` | propuesta segura y acotada con dependencias demostradas o HOLD causal | `HOLD`, nunca «merged» inventado |
| `FREE_1_0` | No aprobado sin Android físico, HTTPS, legalidad y firma verificados | `NO_GO` |

## 4. Alcance de producto y porcentajes — progreso real, no maquillaje

**Hechos comprobados hasta la recepción de C10:**

- Geografía selector Pico: **1.104 de 1.104 = 100 % territorial seleccionable**. Esto **no** significa 100 % de restricciones nacionales verificadas; tampoco garantiza cobertura GPS municipal por polígonos.
- Flutter C9: **29 PASS, 1 SKIP, 0 FAIL**. No autoriza afirmar 100 % de la app.
- PHP C8/C9/C10: **0 de 3 clases ejecutadas en Docker**, por bloqueo previo; objetivo de C11-V2: **3/3 clases ejecutadas con PASS** (y C11 si se justifica una prueba adicional).
- Mapper de campañas: **0/7 pruebas Dart ejecutadas**; objetivo **7/7 PASS**. Segmentación interna no equivale a activar anuncios o pagos.
- Migraciones MariaDB: **0 certificados en el Docker QA de C11**, objetivo un PASS aislado, sin producción.
- Evidencia histórica global: **61/100**, cifra no recalculada. **58 % integral / 83 % núcleo** fueron estimaciones históricas, no mediciones vigentes. No sumes puntos por crear este prompt ni por pasar diez comprobaciones estáticas.
- Estado servidor/editor: implementación C8–C10 presente pero falta gate PHP. Núcleo OTA nacional existe y ya pasó algunas pruebas focales; cobertura jurídica por categoría sigue parcial. Super Admin, editores y campañas no deben confundirse con funcionalidades publicadas y certificadas.

**La meta de este macrobloque no es inventar «100 % de la app»: es convertir trabajo funcional C8–C10 en evidencia ejecutada, mantener motor nacional seguro, preparar realmente el lanzamiento y eliminar la causa de una cuarta vuelta de Docker.** Si A sigue bloqueado por algo externo, B/C no se frenan: entregar funciones verificadas y bloqueo concreto, no un informe kilométrico sin cambios.

## 5. Entrega: exactamente un ZIP ligero; no pedir archivos dispersos

Crear **un único** `D:\codex\_REPORTES\PicoRadar\C11-V2-20261121\PICORADAR_C11V2_RETORNO_UNICO_LIGERO.zip`, ideal <1 MB, límite **5 MB**. Contiene solo:

1. `FINAL_REPORT.md`: delta nuevo, tareas por agente, prueba real vs no ejecutada, fallos de raíz y tratamiento, `NEXT_ACTOR=CHATGPT_DIRECTOR`.
2. `GATES.csv`: filas SOURCE, STATIC_DOCKER, DOCKER_IMAGE, PHP_C8_C9_C10, EDITOR_NACIONAL, MARIADB_SCHEMA, COMMERCIAL_DART, MAIN_BRIDGE, GITHUB, RELEASE; columnas status, evidencia, comando, exit code, clases/test count, limitación.
3. `QA/RESULTS.csv` y, si hace falta, **un único** `QA/ERROR_SNIPPET.txt` con fragmento breve depurado del primer fallo. No logs gigantes ni secretos.
4. `CHANGED_PATHS.csv`: ruta y blob SHA de cada cambio **nuevo** en C11-V2; no repetir el inventario completo de 1.104 municipios.
5. `GITHUB_STATUS.md`: rama, HEAD, tree, parent, PR #88 intacto, `main` intacto, siguiente paso de integración.
6. `MANIFEST.csv`: tamaño, SHA-256 y CRC de cada entrada. Verificar manifiesto y ZIP SHA-256 antes de informar. El ZIP no incluye APK, AAB, TAR, base de datos, `.env`, tokens, imágenes o fuentes enteras.

**Respuesta final compacta de Codex:** `TASK=PICORADAR_C11_V2 | RESULT=... | PHP=... | EDITOR=... | COMMERCIAL_DART=... | DOCKER=... | MAIN_BRIDGE=... | GITHUB_HEAD=... | PR=88_DRAFT | RELEASE=NO_GO | ZIP_PATH=... | ZIP_SHA256=... | NEXT=CHATGPT_DIRECTOR`.

## 6. Auditoría adversarial del director sobre este C11-V2 — **NO repetir en Codex**

Estas son **verificaciones del prompt y del código visible**; no son pruebas Docker/PHP realizadas aquí.

| Vuelta | Verdugo: problema buscado o detectado | Corrección o control |
|---|---|---|
| V1 | C11 original anclado al HEAD anterior, que no incluía el arreglo de cinco expectativas HTML | Ancla exacta `7d843d39…` y blobs actualizados |
| V2 | Prueba PHP compara `<option>` sin `data-management-state`, generando FAIL falso | Corregidas cinco coincidencias en código GitHub, incluidas aserciones negativas |
| V3 | A corre Docker antes de que B commitee prueba nueva; provoca segundo build | Una barrera final y **un solo filtro** sobre árbol limpio |
| V4 | Revisión de test PHP confunde defecto del HTML con fallo del producto | Coincidencia de atributos y expectativa real controlada |
| V5 | Otro editor o catálogo para 1.104 municipios duplicaría arquitectura | Reutilizar matriz C9, selector C9 y editor C10 |
| V6 | Repetir Flutter 29 PASS/1 SKIP y OTA sin cambios desperdicia recursos | Solo siete tests nuevos del mapper y PHP no ejecutado |
| V7 | Programar `docker compose down -v` o puertos globales afectaría otros proyectos | Compose efímero, sin puertos ni volúmenes persistentes, prohibiciones explícitas |
| V8 | SDK ausente se reporta como PASS tras leer código | `DART_BLOCKED_ENV`, 0/7 ejecutados hasta verificar |
| V9 | Puente gigante a `main` huérfano revierte o borra archivos | D solo lectura, sin merge ni nuevo PR de rutina |
| V10 | `UNKNOWN` sin norma y anuncios OFF pasan por permisos/revenue | Fail-closed, editor Draft independiente de difusión |

| Vuelta | Juez: criterio de aprobación del prompt | Veredicto |
|---|---|---|
| J1 | Base GitHub C11 exacta, PR #88 estable | PASS de verificación de HEAD actual |
| J2 | Corregir expectativas de HTML en lugar de editar vista correcta | PASS de coincidencia de texto fuente; PHP pendiente |
| J3 | Contrato Docker mantiene `bootstrap/cache` antes de Composer | PASS de verificación de código; build pendiente |
| J4 | Tests C8/C9/C10 ejecutados juntos tras integrar B | Orden determinado, pendiente de Codex |
| J5 | Caso E2E nuevo solo si faltan transiciones | Sin repetición innecesaria |
| J6 | Ad target OTA preserva privacidad y bloqueo público | Contrato explícito sin activación |
| J7 | 1.104 municipios ≠ 1.104 reglas verificadas | Distinción legal explícita |
| J8 | Sin invadir Docker/PHP/MariaDB de otros proyectos | Límites de procesos/redes/volúmenes descritos |
| J9 | Evidencias PASS/FAIL/BLOCKED no se suplantan con tests escritos | Contrato verificable con exit code |
| J10 | Cierre orientado a Free 1.0 sin merge huérfano ni ronda de auditoría | Macrobloque ejecutable con ZIP único |

**SIGUE AHORA: CODEX LUNA — EJECUTAR C11-V2. NO REINICIAR CODEX POR RUTINA. NO USAR EL C11 ORIGINAL SI TODAVÍA NO HABÍA EMPEZADO.**

**SIGUE DESPUÉS DEL ZIP: CHATGPT DIRECTOR — ACEPTAR SOLO DELTAS Y PLANEAR EL PASO SIGUIENTE HACIA FREE 1.0.**
