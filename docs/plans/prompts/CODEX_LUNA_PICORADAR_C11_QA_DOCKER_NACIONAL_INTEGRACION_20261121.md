# CODEX LUNA — PICORADAR C11: DESBLOQUEO REAL PHP/DOCKER + CIERRE DE EDITOR NACIONAL + INTEGRACIÓN CONTROLADA

**DESTINATARIO: CODEX LUNA. EJECUTA ESTE MACROBLOQUE COMPLETO EN UN SOLO TURNO DE TRABAJO CON AGENTES PARALELOS. NO REPITAS C7, C8, C9 NI C10.**

`TASK_ID=PICORADAR-C11-QA-EDITOR-NATIONAL-20261121` · `NEXT_ACTOR=CODEX_LUNA` · `PRODUCT_RELEASE=NO_GO` hasta gates reales · `SOURCE_HEAD_VERIFIED=db1e28545a9de7d221d42fb85b4e8c68ccf42551`

## 0. Decisión del director basada en C10-V2 y GitHub

El director abrió, leyó y verificó el ZIP `PICORADAR_C10V2_RETORNO_UNICO_LIGERO.zip`: SHA-256 `6f7e1852082a531c3b2ccb277860a8cd6574fb339616c07775c7f68418cd1baa`, 7/7 archivos en manifiesto con bytes/SHA-256/CRC correctos, sin errores ZIP. GitHub confirmó C10 HEAD `77dd816445ee1d0234f9a54ff965f4b5dd99fbcb`, PR #88 **OPEN/DRAFT**, base C9. El árbol C10 presenta ocho rutas alteradas en el macrobloque: tres móviles (mapper y su prueba, Home), cuatro del editor (controlador, dos vistas y test) y Dockerfile. `main` observado en `e9ef37511df3110ffb0fc006ef06be781df432ac`; PR #87 Draft sigue. No merge realizado.

C10 entregó **EDITOR=IMPLEMENTED_UNEXECUTED**, **COMMERCIAL=IMPLEMENTED_UNEXECUTED**, **PHP=BLOCKED_DOCKER_BUILD** y **RELEASE=NO_GO**. C10 intentó PHP dos veces: (1) `pdo_sqlite` carecía de `sqlite3.pc`; corrigió añadiendo `libsqlite3-dev`; (2) Composer ejecutó `package:discover` antes de que existiera `/workspace/bootstrap/cache`. **0 tests PHP ejecutados**. No le atribuyas un fallo a Laravel por un fallo de build. Dart no estaba disponible: 7 casos del mapper comercial **escritos, no ejecutados**. La segmentación comercial pública, campañas, pagos, marketing y cuentas permanecen OFF. El selector Pico **1.104/1.104 municipios** pasó antes en C9, no implica 1.104 normas legales verificadas. C9 Flutter **29 PASS, 1 SKIP**, OTA y consentimiento ya tuvieron PASS focal: **NO REPETIR si los blobs cubiertos no cambiaron**.

**El director YA IMPLEMENTÓ en una rama descendiente de C10, no debes reimplementarlo:**

- `feat/C11-docker-bootstrap-cache-fix-20261121` HEAD **`db1e28545a9de7d221d42fb85b4e8c68ccf42551`**, parent C10.
- `server/Dockerfile.qa`: `mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache` **ANTES** de `composer install`, preservando `libsqlite3-dev`, `pdo_mysql`, `pdo_sqlite`, Composer 2 y PHP 8.3.
- `scripts/tests/test_picoradar_docker_isolation.py`: nueva prueba estática `test_bootstrap_cache_exists_before_composer_scripts` que verifica el orden causal. **No** reescribas el launcher ni Compose salvo fallo nuevo real.
- `server/tests/Feature/C10NationalEditorEntryTest.php`: expectativa de `strong id="jurisdiction-management-state"` sincronizada con Blade. Antes buscaba una etiqueta sin atributos y habría generado un fallo falso.
- Los tres blobs GitHub fueron reconfirmados: Dockerfile `136983d65c9478528f934957aae1a75b2af5a07d`; suite Python `c41ca7f5df19e5321152e2cd5859c0cf41818298`; test PHP `2cc2a07bfe0885dbf83844b0eb9b403097da3dba`.
- Contrato de contenido examinado contra GitHub: **10/10 chequeos estáticos PASS** (orden, libsqlite3-dev, extensiones, exclusión de cache, sin puertos, proyecto único, secretos locales, SQLite, nueva prueba, selector HTML). **NO** son ejecuciones de Docker/PHPUnit/Python del equipo.

### Leyes de desarrollo que nunca se omiten

ChatGPT = director; Codex Luna = implementador. Arquitectura KISS, sin servicios ni dependencias nuevos por costumbre, sin editor duplicado, motor municipal generalizable, archivo OTA nacional único firmado/verificado, estatus de reglas y vehículos por municipio/categoría, regla desconocida = UNKNOWN/STALE/PARTIAL jamás ALLOWED por ausencia de fuente. No se almacenan placas/fotos/cédulas/contratos en servidor; documentos sensibles solo local en app. Publicidad, aliados y pagos **desactivados en Free 1.0**, configuración de campañas solo interna, consentimiento real verificado; jamás activar por defecto. No transformar `Jurisdiction.enabled` (administración) en `consultationEnabled` (publicación). Criterio de fuente legal por ciudad/categoría/vigencia; no publicar restricciones inferidas. No introducir un cuarto catálogo nacional: reutilizar los 1.104 del Viaje y el selector ya cerrado. Este bloque no requiere consulta jurídica externa ni cambio de reglas si no se detecta fallo nuevo concreto.

Hay varios proyectos y varias instancias Codex en el mismo Windows: **Docker totalmente aislado por proyecto/ejecución**, sin puertos globales, sin tocar PHP/MariaDB host, Docker Desktop de otras instancias, contenedores/volúmenes/redes ajenos ni WIP protegido. No `docker system prune`, `docker volume prune`, `docker compose down -v`, reset/force push. No interferir con antivirus, otros repositorios o agentes. Imágenes descargadas/cachés globales son compartidas por el daemon y no deben limpiarse.

## 1. Preflight mínimo, sin más auditorías

1. Crear un worktree/clon nuevo **solo para C11**, rama desde `feat/C11-docker-bootstrap-cache-fix-20261121` y HEAD exacto indicado, sin sobrescribir la rama C10 ni su PR #88. Si C11 remoto avanzó, revisar **solo commits nuevos** y trabajar desde la punta vigente; no resetear. Confirmar `git status --porcelain` limpio. Mantener intactos el checkout `recovery/20261019-modern`, el worktree operativo Bogotá y las 43 rutas WIP conocidas. No usar `D:\codex` como lugar común de archivos de trabajo de proyectos distintos; usar carpeta exclusiva PicoRadar.
2. Verificar una vez `docker version`, `docker compose version`, `pwsh` y `git` **sin imprimir tokens ni variables secretas**. En Docker, inspeccionar solo recursos del nuevo proyecto cuando se arranque. Si alguna política lo bloquea, reportar `BLOCKED_POLICY` y **continuar los frentes independientes**. No tratar de eludir controles.
3. Confirmar hashes de los **tres cambios del director** indicados y que el runner aún tiene `-e DB_CONNECTION=sqlite`, `-e DB_DATABASE=:memory:`, `-e DB_URL=`. No editar esas rutas sin una causa posterior.
4. Asignar trabajo a **agente A (Docker + PHP runtime)**, **agente B (editor nacional, prueba end-to-end)** y **agente C (mapper comercial Dart)**, cada uno en worktree y archivos distintos; integrador único. Agente A puede probar la punta C11 limpia; agente B no debe editar Dockerfile, A no edita vistas ni mapper, C no edita servidor.

## 2. Agente A — desbloqueo con ejecución real (primero, una sola vez)

**Ficheros de propiedad:** `server/Dockerfile.qa`, `scripts/run_picoradar_docker_qa.ps1`, `scripts/tests/test_picoradar_docker_isolation.py` y solo ajustes de infraestructura estrictamente causales. No editar por rutina, no instalar PHP/MariaDB del host.

A1. Ejecutar desde el checkout limpio `python -m unittest scripts/tests/test_picoradar_docker_isolation.py` **una sola vez**. Esperado 10 pruebas, no una garantía. Reportar exit code y `testsRun` reales. Las 9 de C10 ya pasaron sobre versión anterior: ejecutar solo porque el nuevo test/archivo Dockerfile cambió.

A2. Ejecutar, desde **worktree ya commiteado/limpio**, este filtro CONJUNTO en el runner existente, una vez:

```powershell
pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode test -Filter 'C8RestrictionCurrentCoverageTest|C9JurisdictionOnboardingTest|C10NationalEditorEntryTest'
```

El launcher construye la imagen, crea proyecto Compose **nuevo**, fuerza SQLite in-memory **dentro del contenedor de test**, no utiliza MariaDB local y limpia **solo su proyecto**. Ejecutar una sola imagen para el filtro compuesto, no crear un contenedor por test ni repetir Flutter C9. Registrar resumen saneado de pasos de Docker build y PHPUnit, exit code, PASS/FAIL/SKIP y número de aserciones reales.

A3. Si el fallo es de red/repositorio de paquetes, permisos de Docker o falta de imagen y no está permitido resolverlo sin afectar otros proyectos, conservar `BLOCKED_DEPENDENCY` / `BLOCKED_POLICY` **sin nuevos intentos triviales**. Si existe **un error causal NUEVO y concreto** (no repetir `bootstrap/cache`, ya corregido), aplicar una única corrección mínima, generar commit y ejecutar una sola repetición focal. Si se reproduce, `BLOCKED_DOCKER_BUILD` con etapa exacta. No borrar cachés Docker del host ni deshabilitar protecciones. Si sí arranca PHPUnit y falla una aserción, **FAIL_TEST** con archivo/línea y corrección focal, no `BLOCKED_ENV`.

A4. Si pasa PHP con SQLite, correr en **otro proyecto Compose efímero aislado y con datadir tmpfs** `-Mode schema` una vez, para `migrate`/`migrate:status` en MariaDB. Se trata de una comprobación real de esquema, no autoriza despliegue. Si no pasa, registrar por separado `PHP_SQLITE_PASS`, `MARIADB_SCHEMA_BLOCKED`.

A5. Preservar `Dockerfile.qa` con directorio creado antes de Composer, `libsqlite3-dev`, exclusión de `.env`, sin puertos publicados, sin montajes persistentes, sin `docker compose down -v`. La validación estática no cuenta como PHP/Docker PASS.

## 3. Agente B — flujo nacional completo verificado, sin reescribir la UI

**Propiedad exclusiva:** `server/tests/Feature/C10NationalEditorEntryTest.php` y un **nuevo test de flujo** `server/tests/Feature/C11NationalEditorialFlowTest.php` si el flujo no está cubierto por C9/C10; **solo** controladores/vistas afectados ante falla funcional reproducible, nunca nuevos controladores ni endpoint. No tocar archivos del agente A/C.

B1. Leer C9 `C9JurisdictionOnboardingTest.php` y C10 `C10NationalEditorEntryTest.php` para identificar qué cubren y **no duplicar pruebas**. El código C9 ya implementó CTA «Preparar jurisdicción» desde matriz; C10 implementó desde la jurisdicción «Crear borrador», preselección GET, select vacío, DIVIPOLA sincronizado, checkbox consulta OFF, roles. Todo esto **está escrito**, no se solicita reimplementar.

B2. Preparar, solo si aporta cobertura nueva, **un test de integración mínimo** que recorra en SQLite aislado:

- usuario Editor obtiene municipio activo sin jurisdicción en matriz y puede acceder al alta ya existente;
- crea jurisdicción ligada al DIVIPOLA correcto, sin publicar ni activar consulta;
- navega al nuevo formulario desde la ficha de jurisdicción y observa la ciudad correcta, DIVIPOLA y control desmarcado;
- guarda un borrador `schema2` **sintético**, no una regla jurídica real: estado Draft, sin `DatasetRelease` publicado, sin `RestrictionPublication` nueva y sin solicitud HTTP externa;
- usuario Reviewer/Commercial no puede crear el borrador, municipio ausente o sin evidencia nunca resulta autorizado para circular;
- construir fixtures de país/departamento/municipio, dataset, roles y cobertura requeridos dentro de test. No modificar datos reales, tablas persistentes ni catálogo nacional.

B3. Si el test C10 ya prueba una transición, no duplicarla en C11. Si alguna transición requiere fixture grande o cambio de arquitectura, omitir nuevo test y usar los tres filtros PHP de A; **más código sin verificación no es avance**. Agente B no corre por segunda vez los tests focales que ya cubre A. Entregar commit solo si existe diferencia funcional o prueba nueva indispensable; jamás reabrir C7/C8/C9.

B4. Si PHPUnit está disponible en A tras integrar, el **integrador** ejecuta únicamente el nuevo test C11 sobre **worktree final limpio**, una vez, si fue creado. Si Docker sigue bloqueado, se entrega `IMPLEMENTED_UNEXECUTED`, nunca PASS. No depende de B1 para que A pruebe los tres tests existentes.

## 4. Agente C — prueba nueva de publicidad territorial (NO activar campañas)

**Propiedad exclusiva:** solo `mobile/lib/features/home/domain/campaign_territory_mapper.dart`, `mobile/test/features/home/domain/campaign_territory_mapper_test.dart` y, si defecto focal, una llamada en `mobile/lib/features/home/presentation/home_screen.dart`. Evitar modificar otros tests móviles.

C1. El mapper puro **ya está implementado**. C10 escribió **7 casos de test**, pero Dart no estaba instalado. Verificar disponibilidad del SDK Flutter/Dart desde una instalación existente en el mismo equipo sin cambiar PATH global, SDK de otros proyectos ni descargar toolchain no autorizado. Si está disponible, correr `dart format --output=none --set-exit-if-changed` sobre solo esos dos archivos (o formato focal), `flutter analyze` focal según disponibilidad y **solo** `flutter test mobile/test/features/home/domain/campaign_territory_mapper_test.dart` desde directorio `mobile` con ruta acorde. Reportar conteos.

C2. Si Dart sigue ausente, no reescribir los tests ni todo Home: reportar `DART_BLOCKED_ENV` y dejar C10 como `IMPLEMENTED_UNEXECUTED`. El mapper es fail-closed: DIVIPOLA único válido de OTA permite municipio; varios, inválidos o ambiguos no infieren ubicación; fallback por ID exacto histórico; ningún GPS ni placas al servidor. Publicidad pública y marketing OFF, sin nuevas llamadas HTTP.

C3. Si una prueba real falla, corregir únicamente el defecto focal. No repetir C9 (29 PASS y 1 SKIP) ni suites de OTA/consentimiento si los blobs relacionados son idénticos.

## 5. Integración GitHub y preparación real hacia `main`

I1. Integrador único aplica commits de B/C (si los hay) sobre C11, sin cambios concurrentes de rama. A aporta solamente infraestructura causal y logs. Mantener un worktree `C11` limpio antes de invocar el runner. Hacer un único push normal a `feat/C11-docker-bootstrap-cache-fix-20261121` tras el lote y verificar SHA remoto, tree, los blobs cambiados y `git diff --check` con `core.whitespace=cr-at-eol` para los Dart CRLF históricos.

I2. Solo si A/B/C alcanzan los gates que pueden ejecutar, preparar **un candidato de conciliación desde un descendiente de `main`**, no desde la rama backup orphan. Comprobar el HEAD y árbol reales de `main` nuevamente; reutilizar el comparador Git preflight read-only ya diseñado en el proyecto si está presente. Hacer un inventario preciso de rutas de C6/C7/C8/C9/C10/C11 que difieren y de las 43 rutas WIP protegidas. No copiar automáticamente todo el árbol C11 sobre `main`, no intentar merge normal del backup huérfano, no borrar los 2 ficheros exclusivos de `main`. Ejecutar un cherry-pick/traslado de rutas **solo** si dependencias y tests dejan un candidato coherente; en caso contrario `MAIN_BRIDGE_HOLD` con la causa concreta y siguiente acción, sin crear PR de fusión engañoso. Priorizar avance de verdad, no otra auditoría de 1.078 rutas.

I3. El PR #88 está OPEN/DRAFT C10 → C9. No hacer merge ni alterar su base. C11 puede tener **un solo PR Draft C11 → C10** si el delta está razonablemente verificado; si no, conservar rama con HEAD GitHub y sin nuevo PR. No tocar `main`, #79, #86 ni #87. No publicar APK, AAB, campañas, nuevos decretos, servidor ni despliegue. `RELEASE=NO_GO` hasta HTTPS real + legalidad de reglas vigentes + Android físico + artefacto firmado + gate mínimo de servidor.

I4. **Prohibido afirmar fin del producto** basándose en sintaxis, 1.104 municipios seleccionables o tests escritos sin ejecutar. Informar cada gate con estado `PASS`, `FAIL_TEST`, `BLOCKED_ENV`, `IMPLEMENTED_UNEXECUTED`, `NOT_RUN` o `NO_GO` y denominador apropiado.

## 6. Entrega obligatoria: un ZIP único ligero

Entregar exactamente **UN SOLO** `D:\codex\_REPORTES\PicoRadar\C11-20261121\PICORADAR_C11_RETORNO_UNICO_LIGERO.zip`, ideal <1 MB, máximo 5 MB. Contenido:

- `FINAL_REPORT.md`: cambios nuevos, decisiones, gate por agente, riesgos remanentes, `NEXT_ACTOR=CHATGPT_DIRECTOR`.
- `GATES.csv`: SOURCE, DOCKER_IMAGE, PHP_C8_C9_C10, MARIADB_SCHEMA, EDITOR_E2E, COMMERCIAL_DART, CONSENT_OTA_RETAINED, GITHUB, MAIN_BRIDGE, RELEASE.
- `QA/RESULTS.csv`: comando exacto, exit code, tests PASS/FAIL/SKIP reales, cantidad de aserciones, motivo de no ejecución; logs **breves y saneados**, sin secretos.
- `CHANGED_PATHS.csv`: SHA de blobs remotos para **solo deltas C11**; no incluir código fuente, APK ni tar.
- `GITHUB_STATUS.md`: rama, HEAD/tree/parent, PR(s), `main` y worktrees intactos, objetivo de merge.
- `MANIFEST.csv`: bytes/SHA-256/CRC de cada entrada. Validar ZIP y SHA-256 externo antes de respuesta.

No adjuntar fotos, placas, credenciales, `.env`, dumps SQL, carpetas `vendor`, contenedores, backups ni archivos dispersos. No apagar/borrar contenedores ajenos, no reintentos indefinidos. No pedir que el usuario descargue la APK para estos tests; utilizar instalación local solo si QA física se planifica después de pasar el servidor.

**Respuesta de Codex resumida:** `TASK=PICORADAR_C11 | RESULT=... | PHP=... | EDITOR=... | COMMERCIAL_DART=... | DOCKER=... | MAIN_BRIDGE=... | GITHUB_HEAD=... | PR=... | RELEASE=NO_GO | ZIP_PATH=... | ZIP_SHA256=... | NEXT=CHATGPT_DIRECTOR`.

## 7. Métricas verificables, sin falsos porcentajes

- Selector geográfico Pico: **1.104/1.104 = 100 % de opciones territoriales**, NO cobertura jurídica nacional.
- Flutter C9 histórico: **29 PASS, 1 SKIP, 0 FAIL**. No repitas ese conjunto sin cambio causal.
- PHP C8/C9/C10 en C10: **0 tests ejecutados**, porque falla imagen QA antes de PHPUnit. C11 busca ejecutar tres filtros nuevos juntos, sin repetir después.
- Campaña C10: **7 tests Dart escritos / 0 ejecutados**, no confundir con 7 PASS.
- Docker C10: **9 tests estáticos** ejecutados; C11 director hizo **10/10 verificaciones de contenido GitHub**, pero el nuevo test Python no se ejecutó en el PC.
- Rúbrica previa **61/100 de evidencia**, histórica e independiente del porcentaje de código; estimaciones previas **58 % integral / 83 % núcleo** obsoletas, NO presentarlas como medida actual. La aprobación de estos gates podrá sustentar un nuevo corte medido, nunca sumando puntos automáticamente por un prompt.
- Publicidad: plataforma y administración existen pero difusión pública intencionalmente OFF; falta activación controlada para una edición comercial futura, **no bloqueo de Free 1.0**.
- Release Free 1.0: **NO_GO** por pruebas PHP/Dart pendientes, fuentes jurídicas parciales, HTTPS, firma y QA Android físico.

## 8. Autocontrol del prompt ya hecho por el director (NO repetir como tarea)

1. Verifiqué ZIP C10 7/7 SHA/CRC; evita buscar otra vez el paquete histórico.
2. Contrasté commit C10 y PR #88 en GitHub; evita crear ramas desde refs obsoletos.
3. Localicé el fallo real `package:discover` por orden Composer/cache, no por Laravel o Docker compartido.
4. Arreglé Dockerfile sin introducir servicio nuevo ni usar MariaDB global.
5. Añadí prueba que falla si Composer vuelve a preceder la creación del cache.
6. Detecté aserción HTML incompatible con el id añadido por Blade, y la corregí.
7. Verifiqué los tres blobs cambiados desde la rama C11; no mandé repetir esos cambios.
8. Validé 10 condiciones estáticas de seguridad y coherencia (no tests Docker).
9. Limité PHP a C8/C9/C10 y Dart a 7 casos nuevos, sin retest C9 nacional.
10. Impedí que infraestructura bloquee cierre B/C y que un puente orphan a `main` provoque pérdida de rutas.

**QUIÉN SIGUE AHORA: CODEX LUNA — EJECUTAR C11.**

**QUIÉN SIGUE DESPUÉS DEL ZIP ÚNICO: CHATGPT DIRECTOR — ACEPTAR SOLO EVIDENCIA NUEVA, PLANEAR MERGE SEGURO Y CERRAR FREE 1.0.**
