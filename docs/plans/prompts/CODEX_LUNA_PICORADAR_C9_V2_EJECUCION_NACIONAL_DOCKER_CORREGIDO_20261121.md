# CODEX LUNA — PICORADAR C9 V2 · MACROBLOQUE NACIONAL, DOCKER CORREGIDO Y ENTREGA FUNCIONAL

**DESTINATARIO ÚNICO: CODEX LUNA. DIRECTOR: CHATGPT.** Fecha de preparación: **21 de noviembre de 2026**, Colombia. `TASK_ID=PICORADAR-C9-V2-MACROBLOQUE-NACIONAL-20261121`.

**REEMPLAZA AL MARKDOWN C9 ORIGINAL SI TODAVÍA NO HA COMENZADO.** No ejecutar dos versiones ni interrumpir una ejecución de C9 ya iniciada. El objetivo es **desarrollar funcionalidades nuevas y cerrarlas con evidencia diferencial**, no reabrir auditorías. Ejecuta un solo macrobloque de agentes concurrentes cuando puedan usar directorios aislados; un integrador único combina y publica resultados. No pedir al propietario acciones evitables ni escribir otro prompt. Ninguna orden aquí autoriza tocar otro proyecto en el PC.

## 0. Insumos cerrados, fuente exacta y preflight mínimo de una sola pasada

- Repositorio: `sierraglobalcompany-rgb/PicoRadar` (acceso autorizado). **Rama C9 existente y ya preparada:** `feat/C9-national-delivery-candidate-20261121`. Al redactar esta orden el HEAD remoto confirmado es **`1e81d9cd44685bf89d337d7b6f8bfa90bfd429ce`**, árbol **`11c9166f248805c2bae8331f38ae4cd3a4955225`**. No crear otra rama de partida ni reaplicar parches de otras ramas. Si la rama cambió legítimamente, comprobar **solo** el delta desde ese SHA y continuar, nunca reiniciar.
- Su ancestro funcional C8-V2 es `c8664cd4f3105d945d17b5ded95c8e8e149283c6`; C8 escribió 5 archivos nuevos/modificados, pero sus pruebas PHP/Dart quedaron **escritas y sin ejecutar**. ZIP C8 de 12 miembros verificado, SHA-256 `2fdbe0ca76a0b3eada1b2656d52b8fb15e79df54982a5481cf4c40c5f6edf187`. **No volver a auditar ese ZIP.** C7 municipal UI ya pasó 3 pruebas/41 aserciones, no repetirlas sin cambio causal.
- C9 YA INCLUYE 10 archivos independientes de OTA (zonas horarias y 2 pruebas), Android 16 KB (verificador y 7 tests sintéticos), Docker QA (Compose/runner/PHP y test estático). **No cherry-pick ni reprogramar estos módulos.** Ya existe consentimiento explícito de aliados y prueba focal escrita en C8.
- **Corrección funcional del director introducida antes de este C9 V2:** en `scripts/run_picoradar_docker_qa.ps1` el modo `test` ahora fuerza `DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:` y `DB_URL=` dentro de `docker compose run -e`. Sin esto heredaba MariaDB del Compose mientras el modo test NO levantaba MariaDB: PHPUnit XML NO sobreescribe variables existentes por defecto. Blobs Git contrastados: runner `7a95f8f742c8668e125e8d44f0cd9340e7445456`; test de aislamiento `37f92db38a0e1d977c70ba9d997b3d3c550f07f7`. **8/8 tests estáticos Python PASS en la revisión del director; Docker real NO ejecutado.** No volver a corregir esto ni afirmar PHPUnit PASS todavía.
- `main` histórico `e9ef37511df3110ffb0fc006ef06be781df432ac` en último corte; PR #86 C7 abierto Draft, basado en `backup/picoradar-c6-source-20261120`; PR #79 histórico Draft. La rama C9 es la fuente de este macrobloque. **Ni `main`, ni PR #79/#86, ni `backup` se editan/mergean.** Evitar GitHub Actions por cuota reportada agotada.
- Checkout protegido del propietario `D:\codex\PicoRadar` (43 rutas WIP históricas): **no escribir, instalar, resetear, limpiar ni restaurar allí.** Trabajar en clon limpio independiente `D:\codex\_isolated\PICORADAR-C9V2\...` o destino equivalente libre; sin junctions a proyectos vecinos. Verificar una sola vez HEAD y estado antes de trabajar. No inspeccionar otros repositorios, worktrees, servicios, claves ni bases de datos del computador.
- Leer `AGENTS.md`, el contrato/base vigente del repo y los archivos indicados abajo solo cuando sea necesario para implementar. **No hacer un inventario general nuevo ni 10+10 en Codex.** Las 20 revisiones adversariales del director están al final de este archivo.

## 1. Contrato de producto inmutable y límites de release

Flutter + Riverpod + Drift y control Laravel 13, navegación **Inicio · Garaje · Apps · Viaje · Conducir**, modo **Free 1.0 sin cuenta obligatoria**. No introducir servidor para placas/fotos/GPS continuos. El motor evalúa localmente reglas publicadas de pico y placa; el servidor administra publicación nacional OTA firmemente versionada, hash, permisos y rollback. Responder `UNKNOWN`, `STALE` o «No hay información verificada» donde falte evidencia. **NUNCA concluir que un vehículo puede circular por ausencia de norma o porque un municipio aparezca en el catálogo.** No activar comercialmente anuncios, pagos, premium, cuentas, WhatsApp ni leads. No editar ni publicar normas inventadas.

**Prioridad de C9 V2: (A) selector nacional real, (B) Super Admin alto asistido y CSV correcto, (C) validación Docker/Flutter focal, (D) tres fuentes oficiales nuevas si sobra capacidad.** Un fallo externo de C NO bloquea que A/B programen, integren y publiquen código con `IMPLEMENTED_UNEXECUTED` honesto.

## 2. Reparto entre subagentes sin colisiones y orden de integración

En Codex, crear como máximo tres subagentes de IMPLEMENTACIÓN y uno de fuentes de solo lectura si está disponible. **Cada agente usa una copia/worktree exclusivo, un branch local exclusivo, y NO comparte `build/`, `.dart_tool`, `vendor`, base Docker o índice Git con otro agente.** Un coordinador único combina cambios, ejecuta pruebas causales tras la integración y hace push/PR. Si no soporta subagentes, hacer A→B→C→D dentro del mismo encargo, sin nuevos prompts.

| Responsable | Puede escribir | Entrega material | No hacer |
|---|---|---|---|
| **A Flutter nacional** | `mobile/lib/features/pico_placa/data/pico_jurisdiction_catalog.dart`, `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart`, pruebas específicas Pico nuevas/afectadas | Selector Pico de 1.104 DIVIPOLA, búsqueda estable, estado conservador, widget tests | No tocar dataset fuente de 73, JSON nacional de Viaje, OTP/OTA, Trip, Home/Ads, PHP |
| **B Laravel/admin** | `server/app/Http/Controllers/Admin/JurisdictionController.php`, `server/app/Http/Controllers/Admin/RestrictionRuleController.php`, `server/resources/views/admin/jurisdictions/create.blade.php`, `server/resources/views/admin/restrictions/municipalities.blade.php`, menú/link de exportación en `server/resources/views/admin/restrictions/index.blade.php` si es causal, tests focales C9 | Alta asistida, tres CSV semánticamente claros, protecciones/rollback | No nuevas tablas, migraciones, API, roles, cambios al DatasetPublisher, servicio de normas ni campañas |
| **C QA/infra** | Solo wrapper Docker/scripts de QA si hay error causal, tests propios, evidencia | Arranque Docker sintético y gates focales PHP/Flutter; diagnóstico máximo uno por bloqueo | No tocar rutas A/B, datos reales, PHP/MariaDB global, `docker system prune`, otros contenedores |
| **D jurídico/comercial (optativo)** | Solo reporte CSV corto de fuentes, sin cambios runtime | Hasta tres actos oficiales NUEVOS completos o `UNVERIFIED`, estado flags Ads OFF | No repetir C7 Medellín/Bogotá/Cali sin novedad, no publicar reglas, no activar publicidad |
| **Integrador único** | Rama C9, PR Draft, ZIP/manifiesto/QA y documentación mínima | HEAD GitHub verificable, resultados materiales de A/B y bloqueos correctos | No ejecutar una auditoría de 1.882 rutas, no forzar merge ni refactorizar códigos ajenos |

**Orden:** A y B se implementan en paralelo; C valida infraestructura paralelamente; D no bloqueante. Integrador recibe UNA entrega por agente, compara paths, integra A+B una sola vez, ejecuta pruebas **después de integrar**, corrige solo fallos nuevos y publica. No se requiere nuevo prompt por resultado parcial externo.

## 3. A: selector Pico y Placa de 1.104 municipios sin inventar restricciones

**Evidencia exacta del repo:** `mobile/assets/catalogs/colombia_trip_municipalities_v1.json` tiene **1.104 registros/1.104 códigos de cinco dígitos**; su modelo `mobile/lib/features/trip/data/trip_municipality_catalog.dart::TripMunicipalityCatalog` y provider ya existen. En cambio `mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json` contiene **73 municipios/219 categorías históricas**; `PicoJurisdictionCatalog.fromJson` valida intencionalmente 73 filas y exactamente 5 `engineEnabled` de ese dataset histórico. El selector `_CitySelectorSheet` en `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart` consume solo ese catálogo Pico.

1. **Preservar estrictamente** JSON de 73, su validador y contratos. Crear una **función/adaptador puro muy pequeño** que tome catálogo Pico + los 1.104 de Viaje, combine por **código DIVIPOLA exacto** y devuelva 1.104 opciones únicas. No modificar JSON, No crear un cuarto asset, no introducir otro parser nacional ni endpoint ni esquema OTA. Las 73 entradas conservan ID, estado, fuente, fecha y categoría; las otras **1.031** opciones son `pending`, `engineEnabled=false`, sin acto verificado ni ID de motor inventado. ID interno neutro estable `co-mun-<5 digitos>` sin colisión con los existentes; NO usar `TripMunicipality.jurisdictionId` estático como autorización a circular.
2. **Habilitación estricta:** consultar el dataset local publicado y la información efectiva de categoría/servicio/vigencia; **no** activar motor porque `consultationEnabled` por sí solo sea true, ni porque la opción exista en el catálogo, ni por el estado estático `verified` de un asset histórico. Si la UI ya tiene un chequeo de cobertura local, reutilizarlo, no duplicarlo. Opción consultable conserva navegación actual y evaluador local; si no hay datos suficientes, mostrar hoja existente «No hay información verificada para determinar si tiene restricción»; estados `UNKNOWN`/`STALE` nunca se convierten a `ALLOWED` ni a indicador verde. No habilitar nuevos IDs nacionales de forma automática.
3. **Unir providers en el selector, no en una nueva capa global.** Reutilizar `tripMunicipalityCatalogProvider` junto con `picoJurisdictionCatalogProvider`. Si el nacional no carga, mostrar los 73 previos con aviso discreto de alcance limitado; si Pico falla pero Viaje carga, mostrar opciones neutras sin consultar motor hasta verificar estado, nunca crashear. No construir 1.104 tiles de golpe: antes de buscar, mostrar conjunto acotado de opciones conocidas más invitación a buscar; después de buscar, un límite de 60–80 resultados o `ListView.builder`. Mantener accesibilidad, ValueKeys, selección y botones anteriores.
4. **Búsqueda completa:** nombre y acentos normalizados, departamento, código; búsquedas `La Unión` deben mostrar por separado **05400 Antioquia, 52399 Nariño, 70400 Sucre, 76400 Valle del Cauca**; código exacto encuentra la ciudad correcta. No perder Medellín (`05001`), Cali o Bogotá. Asegurar que no se ejecuten 1.104 consultas Drift; solo leer cobertura del conjunto runtime que ya está instalado.
5. **Tests focales de aceptación A** usando archivos de test ya existentes y un test nuevo solo si hace falta: combinación 73+1.104 produce 1.104 códigos únicos, no 1.177; opciones nuevas son neutras; homónimos + DIVIPOLA; ciudad sin norma abre aviso seguro y no evalúa en verde; ciudad con cobertura realmente disponible conserva ruta existente; errores de proveedor no causan crash. No reejecutar toda la suite Flutter. Registrar tests ejecutados y aserciones donde la herramienta lo reporte.

`A_NATIONAL_SELECTOR=PASS` solo si código integrado **y** prueba focal de datos/selector corrió y pasó. Si no hay SDK, `IMPLEMENTED_UNEXECUTED` con paths y evidencia estática; seguir con B/GitHub.

## 4. B1: flujo mínimo de creación de jurisdicción desde la matriz

El servicio, el formulario y la ruta **YA EXISTEN**: `JurisdictionController.create/store`, `JurisdictionService.create`, `admin.jurisdictions.create` y permisos `jurisdictions.edit`. No crear otro editor ni otra tabla.

1. En `server/resources/views/admin/restrictions/municipalities.blade.php`, mostrar acción **«Preparar jurisdicción»** para filas `NO_JURISDICTION` exclusivamente cuando `auth()->user()->can('jurisdictions.edit')`. Enlazar a `route('admin.jurisdictions.create', ['primary_geographic_unit_id' => $municipality->id])`. Los demás perfiles ven solo el estado de lectura.
2. `JurisdictionController.create` acepta ID opcional de query **solo escalar entero positivo**; verificar que corresponde a municipio `GeographicUnit` activo, nivel `Municipality`; si es array, 0, departamento, inexistente, cadena muy larga, etc., no precargar y **no retornar 500**. Pasar a la vista un valor `preselectedMunicipalityId` o nombre equivalente. **No mutar** nada en GET; `store()` sigue validando POST y operando por `JurisdictionService`, conserva las restricciones de negocio existentes.
3. En `server/resources/views/admin/jurisdictions/create.blade.php`, `old('primary_geographic_unit_id')` escalar válido tiene prioridad sobre la preselección; marcar una única `<option selected>` o ninguna, y mantener selección manual. El enlace no debe crear jurisdicción ni marcarla activa sin completar el formulario, validar permisos y guardar explícitamente.
4. Tests: actor `jurisdictions.edit` sí ve CTA; rol solo visor/no autorizado no lo ve; GET de precarga usa ID correcto; GET con array/otro nivel/inexistente no arroja 500 ni modifica DB; POST sigue usando validación existente. **No repetir todo `GeographyJurisdictionTest` si basta una prueba del nuevo flujo.**

`B_ADMIN=PASS` solo con ruta, permisos, formulario y pruebas ejecutadas que acrediten el flujo.

## 5. B2: CSV en tres ámbitos y fuente explícita (sin alterar OTA)

**Defecto C8 demostrado:** `RestrictionRuleController::streamEditorialCoverage()` etiqueta `scope=editorial` pero lee `currentCoverageSummaries()` desde el asset del release nacional vigente. En C6/C7 `editorial` era la cobertura de la versión editorial más reciente. Hay que corregir la ambigüedad **sin falsos positivos ni romper el consumidor CSV existente**.

1. Extender exclusivamente el parámetro público de consulta `/admin/restrictions/coverage/export` con estos valores: `editorial`, `published`, `municipalities`. Otros valores: `422` (ya existe validación). No cambiar ruta, cabeceras existentes, orden de columnas ni protección antifórmulas. El campo añadido en C8 `source_editor_version` permanece.
2. **`scope=editorial`**: para cada jurisdicción, última versión editorial y su estado/coberturas; borrador v2 sigue borrador aunque release público sea v1. **No llamar PUBLISHED a esa cobertura editorial**; las columnas de release/estado, cuando estén presentes, se describen como metadatos de referencia no fuente de esa fila. Si no hay versión, `UNKNOWN`/`NO_EDITOR_VERSION` —no completar con publicado por conveniencia.
3. **`scope=published`**: solo el asset verificado que señala `Dataset.current_version`; hash/estado comprobados usando `currentRestrictionSnapshot()` C8. Borradores y publicaciones históricas **NO** cambian el dato público actual. Si release falta/corrupto, `UNKNOWN` y `publication_state=UNKNOWN`, nunca datos de editor como sustituto. Rollback al release v1 cambia esta vista sin inventar nueva revisión editorial. Mantener seguridad de fórmulas CSV.
4. **`scope=municipalities`**: listado nacional por DIVIPOLA, incluyendo `NO_JURISDICTION` y estados oficiales desconocidos. Mantener semántica C8 como cobertura actual y comparación con editor, con etiqueta clara en la vista. No eliminar categorías vigentes de otros municipios al publicar un cambio individual.
5. Ajustar el enlace visible en `index.blade.php` o documentación mínima **solo si hace falta** para distinguir «CSV editorial» y «CSV publicado», sin duplicar enlaces inutilmente. Ajustar `C8RestrictionCurrentCoverageTest` cuando su aserción vieja asuma que `editorial` es `published` (es un cambio causal legítimo); agregar caso focal v1 publicado/v2 borrador, rollback y asset corrupto, usuarios sin `datasets.view` 403, CSV fórmula escapada. No copiar el test entero a un nuevo archivo ni rerun de C7 sin cambios.

`B_CSV=PASS` solo con los tres scopes acordes, filtros/permiso preservados y PHPUnit focal realmente ejecutado. **No modificar `DatasetPublisher`, `RestrictionPublicationService`, estructura de releases o motor OTA para corregir un CSV.**

## 6. C: validación reproducible y aislada (sin secuestrar el macrobloque)

### 6.1 PHP y MariaDB — Docker obligatorio

- Código YA INTEGRADO: `infra/docker/compose.qa.yml`, `server/Dockerfile.qa`, `server/.dockerignore`, `scripts/run_picoradar_docker_qa.ps1`; red privada `internal`, datadir MariaDB en `tmpfs`, sin `ports`, `container_name` ni bind mounts; identificador aleatorio por invocación. No tocar servicios PHP/MariaDB/MySQL globales, bases de otros proyectos, ni puertos/caches Docker ajenos. `down` exclusivamente del identificador único; jamás `down -v`, `system prune` o `volume prune`. Flags anuncios/aliados/cuentas OFF.
- **IMPORTANTE: defecto ya corregido en C9 por el director.** `-Mode test` fuerza `DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:`, `DB_URL=` vía `docker compose run -e` **porque** Compose da `DB_CONNECTION=mariadb` y PHPunit XML no sobrescribe variables existentes. Confirmar en comando/salida una sola vez. `-Mode schema` sí usa MariaDB sintética temporal. No volver a diseñar el runner ni cambiar `phpunit.xml` por rutina.
- Docker run usa únicamente un **clon limpio/commit ya integrado** (el wrapper rechaza worktree con WIP). Si A/B todavía no están comiteados, primero crear commits locales y consolidar en la copia QA aislada, no cambiar código protegido ni ejecutar contra fuente antigua. El integrador controla la secuencia.
- **Una sola invocación para migraciones:** `pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode schema`. **Una invocación focal para PHPUnit:** `pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode test -Filter 'C8RestrictionCurrentCoverageTest|C9NationalAdminTest|C9JurisdictionOnboardingTest'` (usar nombres reales creados; NO correr suite completa). Cada invocación crea un proyecto nuevo; el runner reconstruye imagen en ese proyecto, por eso **agrupar filtros** en una sola ejecución cuando se pueda. El grupo debe incluir el test de CSV modificado, el test de admin nuevo y el caso C8 afectado, no pruebas ajenas.
- Si falla descarga de imágenes/Composer/extensiones, hacer **un diagnóstico focal y una corrección causal** dentro del bloque. No invocar PHP/Composer global del host como salida. Si no se recupera, registrar `DOCKER_BLOCKED_ENV` y continuar A/B/D/GitHub; no declarar PHPUnit PASS. Las pruebas estáticas del wrapper pasaron **8/8** con el delta actual; no repetirse salvo edición del runner.

### 6.2 Flutter, OTA y consentimiento

- Buscar SDK Flutter autorizado en PATH, `FLUTTER_ROOT`, caché aprobada `D:\codex\_tool-cache` y ruta de herramientas del proyecto. Si está en otro proyecto, no lo modificar, no borrar caches, no mover ejecutables. Ejecutar desde copia aislada, sin cambiar PATH global. C6 tuvo compilación Android, C8 no encontró SDK en su clon: no asumir que está instalado ni obligar descargas riesgosas. Si sigue ausente, `FLUTTER_ENV_BLOCKED` y ejecutar desarrollo A igualmente.
- **Pruebas focales cuando haya SDK:** `bogota_scope_notice_test.dart` (C8), `partner_inquiry_client_test.dart` (consentimiento), las 2 pruebas de `dataset_sync_service_test.dart` sobre `generatedAt`/`expiresAt` (OTA), y tests del selector nacional nuevos/afectados. No repetir suite Flutter completa, no reinstalar codegen si no cambió entrada, no compilar APK solo para marcar un gate. Formato/análisis limitados a archivos tocados.
- Tests Android 16 KB sintéticos previos **7/7 ya realizados**; no repetir salvo editar el script. Verificador sobre APK/AAB local solo si corresponde al HEAD **actual**, sin copiarlo al ZIP ni presentarlo como certificación Google Play. Sin APK C9, `ANDROID_16K_REAL_ARTIFACT=NOT_RUN`; teléfono/HTTPS no se ejecutan sin autorización.

### 6.3 Evidencia que C debe entregar

Registrar por test: comando exacto, SHA de código bajo prueba, resultado, exit code, count y errores acotados; diferenciar `PHPUNIT_SQLITE_MEMORY`, `MARIADB_MIGRATIONS`, `DART_FLUTTER`, `ANDROID_16K_STATIC` y `ANDROID_ON_DEVICE` (este último sigue `NOT_RUN`). Docker real es `PASS` solo si **arranca** y termina el test o migración objetivo con exit 0; el parsing YAML y 8/8 Python no bastan.

## 7. D: trabajo nacional jurídico y publicidad sin distraer A/B

- Mantener legalidad estricta. Opcionalmente un agente de solo lectura busca **hasta tres municipios diferentes a Medellín/Bogotá/Cali ya tratados por C7**, con acto oficial completo, categoría, horarios, perímetro, excepciones, fecha de vigencia, URL, emisor, y registra `FULL_ACT_VERIFIED` o `SOURCE_INCOMPLETE` en `LEGAL_SOURCES_DELTA.csv`. **No publicar ni marcar reglas activas automáticamente.** Sin fuente completa, documentar bloqueo en una fila; no crear un proyecto de investigación de 1.104 ciudades en C9.
- Campañas, sponsors, permisos, catálogo y revisión ya están implementados. Confirmar SOLO que Free 1.0 sigue desactivado (señales actuales del repo `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false`, `PARTNER_INQUIRIES_ENABLED=false`, cuentas y marketing OFF). No construir otra plataforma comercial en este bloque por tener publicidad OFF. No cambiar consentimiento existente salvo que falle su test focal. Trabajos futuros de monetización requieren decisión del dueño, HTTPS y privacidad.

## 8. Integración GitHub, alcance controlado y condición para `main`

1. Un **solo integrador** recibe A y B, hace diff focal de caminos modificados, integra a la **rama C9 existente** mediante commit normal y push convencional. Si C9 HEAD remoto cambió desde `1e81d9cd…`, comprobar el delta y no sobrescribir trabajo ajeno. Sin force-push, sin cherry-pick de los tres módulos preparatorios, sin merge/despliegue a `main`, PR #79, PR #86 ni respaldo C6. No tocar los 43 WIP del checkout de propiedad.
2. Cuando A/B ya tengan cambios materiales, crear o actualizar **un único Draft PR de C9 contra `feat/C8-national-release-hardening-20261121`**, detallando pruebas PASS/FAIL/BLOCKED, sin merge. C9 ya tiene diez archivos adicionales de QA/OTA/Android: indicarlos como **previos a este bloque**, no como implementados por agentes A/B.
3. **No ejecutar en C9 el merge de dos padres ni reemplazar el árbol de `main`.** Aunque la técnica de primer padre main/segundo C9 es posible, necesita revisión de 1.078 rutas y autorización del propietario para una sustitución tan amplia. Durante C9 producir **solo un registro liviano de preparación**: HEAD de main y C9, conteo exacto del diff por tipo, dos paths exclusivos main con decisión `REMOVE_CANDIDATE_UNVERIFIED` salvo revisión, protección de firma/secretos, y `MAIN_BRIDGE=HOLD_OWNER_AND_RELEASE_GATES`. Este inventario NO bloquea la entrega A/B y NO crea un nuevo PR contra main. La aprobación de un puente debe ser un paso posterior deliberado, no un efecto secundario de pruebas unitarias locales.
4. Verificación final con `git diff --check`, `git status`, hashes de HEAD remoto, secretos en delta y exclusión de `.env`/APK/AAB/dumps/llaves/fotos/placas. No ejecutar Actions sin cuota ni instalar APK en el Xiaomi Mi A3. Si los tests de A/B no se ejecutaron por bloqueo externo, aún se publica código y PR Draft como `IMPLEMENTED_UNEXECUTED`, nunca `PASS` o `RELEASE_GO`.

## 9. Gates no negociables y cómo contar avance

| Gate | Pasa SOLO si... | En caso contrario |
|---|---|---|
| `G0_SOURCE` | HEAD/árbol C9 y clones aislados verificados una vez | `HOLD_SOURCE`, no tocar WIP |
| `G1_PICO_1104` | UI Pico con 1.104 DIVIPOLA únicos + tests de fusión, búsqueda, neutralidad y flujo | `IMPLEMENTED_UNEXECUTED` o `FAIL_CAUSAL` |
| `G2_ADMIN` | CTA seguro, GET no mutante, permisos y preselección pasan pruebas | Estado acotado y código integrado si existe |
| `G3_CSV` | Editorial corresponde al editor; published al asset vigente; municipios mantienen matriz y CSV seguro | `FAIL_CAUSAL`/`BLOCKED_ENV` |
| `G4_C8_TESTS` | Tests C8 modificados realmente ejecutados; diferenciar PHP/Dart | No sustituir por php -l |
| `G5_OTA` | Parseo fechas sin zona rechazado + offsets aceptados, test Dart ejecutado | Código escrito no implica PASS |
| `G6_DOCKER` | Docker real MariaDB migra; PHPUnit con SQLite explícito corre en contenedor | Estático 8/8 NO implica runtime PASS |
| `G7_ANDROID` | Script estático con artifact C9 válido y revisión 16 KB si artefacto existe | `NOT_RUN`, NO_GO Play físico |
| `G8_GITHUB` | Push normal C9, árbol/code-diff, un PR Draft, no main merge | `BLOCKED_GITHUB` honesto |
| `G9_RELEASE` | Normas vigentes suficientes, QA Android físico, HTTPS permitido y aprobación release | **`RELEASE=NO_GO`** |

**Métricas sin engaño** (último corte verificable):

- **61/100** = puntuación histórica de evidencias, **NO porcentaje de app lista**. No cambiarla sin volver a aplicar la misma rúbrica y pruebas nuevas. C7 ya demostró su pantalla pero la matriz no fue recalculada.
- **58 % integral y 83 % núcleo** = estimaciones históricas sin denominador documentado. NO declarar 59/65/90 ni proyección automática.
- **1.104/1.104** = catálogo geográfico de Viaje (datos presentes), NO leyes vigentes. **73/1.104 = 6,61 %** = cobertura del *catálogo previo de opciones Pico*, NO cobertura jurídica. C9 pretende **1.104/1.104 opciones de selección**, manteniendo exactamente 73 fichas históricas y 1.031 nuevas neutrales; tal 100 % de selección **no equivale a Free 1.0 al 100 % ni al motor nacional normativamente completo**.
- Resultados útiles de C9: **2 entregables funcionales visibles (selector + alta asistida)** y **1 contrato CSV corregido**, más cierre de gates C8 si es ejecutable; no llamar a cada test un módulo terminado.

**Prohibido terminar C9 solamente con nuevos informes.** Si hay bloqueo Docker/Flutter, A y B deben seguir implementando y publicando lo posible, sin falsificar QA. A cada `FAIL` nuevo le corresponde una sola corrección causal y un único reintento focal, no una décima auditoría de prompts.

## 10. Entrega ÚNICA para ChatGPT Director — ligera y verificable

Crear exactamente **un ZIP ligero** `PICORADAR_C9V2_RETORNO_UNICO_LIGERO.zip`, objetivo menor a 2 MB, límite 5 MB, y anexar solo:

- `FINAL_REPORT.md`: resumen de cambios A/B, estado/diagnóstico C, estado D, commits y comparación; especificar implementación y qué se verificó de verdad.
- `GATES.csv`: cada gate, PASS/FAIL/BLOCKED/NOT_RUN, tests ejecutados, no porcentajes inventados.
- `CHANGED_PATHS.csv`: rutas, dueño, commit/blob SHA, estado.
- `GITHUB_STATUS.md`: HEAD/tree remoto de C9, un PR Draft contra C8, main no modificado, estado de branch limpio, sin secretos.
- `QA/` limitado: comandos, cwd, exit codes, conteos y fragmento relevante, si realmente se ejecutaron; **no** traces enormes ni logs secretos.
- `LEGAL_SOURCES_DELTA.csv` solo si D encontró fuentes nuevas verificables; con URLs y fecha.
- `MANIFEST.csv` de los demás miembros (nombre, SHA256, CRC32, bytes) y verificación del ZIP. Patch sanitizado solo si es muy pequeño y útil; GitHub guarda todo el código.

**NO incluir APK/AAB, TAR, copias de repo, Docker images, bases SQLite/MariaDB, dumps, `vendor/`, `.dart_tool`, SDK, informes antiguos, llaves, documentos, fotos, placas, credenciales ni enlaces locales inservibles como prueba única.** Si se menciona un archivo en `D:\`, el usuario debe poder adjuntar el ZIP, no la ruta Windows desde ChatGPT. Respuesta final de Codex solo una línea:

`TASK=PICORADAR_C9_V2 | RESULT=<PASS_SCOPED|PARTIAL> | A_SELECTOR=<...> | B_ADMIN=<...> | B_CSV=<...> | C8_PHP=<...> | C8_DART=<...> | DOCKER=<...> | OTA=<...> | MAIN_BRIDGE=HOLD | GITHUB_HEAD=<sha> | PR=<n> | RELEASE=NO_GO | ZIP_PATH=<ruta_local> | ZIP_SHA256=<sha> | NEXT=CHATGPT_DIRECTOR`

## 11. Auditoría adversarial del director — 10 VERDUGO (realizadas, NO repetir en Codex)

| Pasada | Problema comprobado al auditar el C9 original | Decisión y por qué |
|---|---|---|
| **V1** | El `test` Docker heredaba `DB_CONNECTION=mariadb` del Compose sin servicio DB levantado; PHPUnit no fuerza `<env>` existente | **Corregí el runner en GitHub** con `-e DB_CONNECTION=sqlite`, `-e DB_DATABASE=:memory:`, `-e DB_URL=`; test estático nuevo 8/8 |
| **V2** | C9 decía que el Docker ya permitía tests PHP aunque nunca se ejecutó | Exigir contenedor real y exit 0; separar estático, migración MariaDB y PHPUnit SQLite |
| **V3** | El wrapper rechaza checkouts sucios: probar agentes sobre WIP sería imposible | Consolidar cambios en copia QA limpia antes de invocarlo; no debilitar protección |
| **V4** | C9 ordenaba un puente main de 2 padres con árbol C9 aun siendo 1.078 rutas distintas | Retener integración destructiva hasta firma/aprobación; solo informe de reconciliación focal |
| **V5** | El gate nacional podía habilitar jurisdicciones solo por `consultationEnabled` o ID estático de Viaje | Exigir cobertura efectiva/vigente por categoría y preservar `UNKNOWN` y `STALE` |
| **V6** | El validador de Pico exige 73 registros y 5 elegibles; extender JSON a 1.104 rompería fuente histórica | Fusión pura en UI; asset original y validador intactos |
| **V7** | 1.104 tiles iniciales y búsquedas sin desambiguación pueden congelar UI o elegir municipio incorrecto | Limitar/lazy resultados; probar cuatro «La Unión» por DIVIPOLA |
| **V8** | El CSV `editorial` en C8 provenía del release vigente; devolverlo como editorial resulta engañoso | Restaurar editorial real y añadir `published` explícito; actualizar test C8 afectado |
| **V9** | C8 no ejecutó tests y C9 podía repetir la misma excusa con php -l / análisis estático | Estados `IMPLEMENTED_UNEXECUTED`, `BLOCKED_ENV` y QA por área, no falso PASS |
| **V10** | El encargo ponía demasiada energía en Docker, puente main y revisión legal, marginando producto | A/B obligatorios y prioritarios; C/D paralelos no bloqueantes; un único integrador y ZIP |

## 12. Auditoría adversarial del director — 10 JUEZ (realizadas, NO repetir en Codex)

| Pasada | Criterio de aceptación y contraste | Resolución defendible |
|---|---|---|
| **J1** | El arreglo Docker no debe causar que los tests manipulen MariaDB de otros proyectos | `docker compose run -e` sobrescribe solo proceso aislado, no entorno host; scripts Python 8/8 PASS, Docker real pendiente |
| **J2** | ¿Es correcto contabilizar 1.104 municipios como leyes? | No: son 1.104 ubicaciones para buscar; legalidad se mide por acto/categoría/perímetro/vigencia y sigue incierta |
| **J3** | ¿Se puede permitir crear jurisdicción con solo abrir la matriz? | No: GET precarga únicamente; POST existente exige permisos/validación y acción explícita |
| **J4** | ¿Es seguro publicar el CSV de borrador como release activo? | No: editorial y published deben tener fuente/estado distintos, incluido rollback y asset corrupto |
| **J5** | ¿Quedan protegidas reglas nacionales y vehículo offline? | Sí si solo se cambia selector, admin y CSV, y no se altera motor/OTA ni fuente histórica; nuevos tests verifican seguridad |
| **J6** | ¿Basta el test estático Docker y la imagen descargable? | No: se exige Docker real, migración, PHPUnit y sus exit codes; sin ellos BLOCKED_ENV |
| **J7** | ¿Conviene obligar Flutter inexistente o reconstruir APK cada ciclo? | No: desarrollo se integra con `UNEXECUTED` si no hay SDK; físico/Play permanecen NO_GO |
| **J8** | ¿El C9 realmente puede trabajar en paralelo con otros proyectos? | Sí en diseño: worktrees exclusivos, Docker proyecto efímero sin puertos ni volúmenes compartidos; funcionamiento Windows aún requiere prueba |
| **J9** | ¿PR C9 contra C8 y no `main` preserva continuidad y evita reemplazo accidental de historia? | Sí: Draft PR trazable con código y gates; `main` permanece protegido hasta aprobación de reconciliación |
| **J10** | ¿Tenemos una salida medible sin perseguir otro prompt? | Sí: dos capacidades visibles + CSV, tests focales, único ZIP ≤5 MB, SHA/HEAD/PR; no rondas de auditoría adicional |

## 13. Siguiente actor, fin explícito y prohibiciones de repetición

**SIGUE AHORA: CODEX LUNA — EJECUTAR ESTE C9 V2 COMPLETO (NO EL C9 ORIGINAL).** No reiniciar por rutina; si C9 ya empezó, **no interrumpirlo** para cargar V2: terminar el encargo vigente y entregar su ZIP primero.

**SIGUE DESPUÉS: CHATGPT DIRECTOR — REVISAR DIFERENCIALMENTE EL ZIP, ACEPTAR/RECHAZAR GATES NUEVOS Y ORGANIZAR EL SIGUIENTE CIERRE FREE 1.0, SIN REABRIR C2–C8.**
