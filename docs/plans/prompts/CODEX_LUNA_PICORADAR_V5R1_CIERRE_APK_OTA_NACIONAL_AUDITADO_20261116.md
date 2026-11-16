# CODEX LUNA — PICORADAR V5-R1 · UNA EJECUCIÓN PARA APK DEV, OTA Y MOTOR NACIONAL DATA-ONLY

**TASK_ID:** `PICORADAR-V5R1-FINAL-APK-OTA-NATIONAL-DATA-20261116`  
**ÚNICA ORDEN ACTIVA:** este documento sustituye **por completo** `CODEX_LUNA_PICORADAR_V5_CIERRE_APK_OTA_MOTOR_NACIONAL_20261116.md`. No ejecutar V5 ni V3/V4/V4-R1 como órdenes. **Si ya existe una ejecución V5 en progreso, no abrir escritor paralelo: terminar o reconducir en el mismo worktree de manera no destructiva, sin repetir lo pasado.**  
**EJECUTOR:** Codex Luna, sobre el worktree de Windows del proyecto; **DIRECTOR/ACEPTACIÓN:** ChatGPT; **propietario:** cualquier autorización irreversible, publicación, acceso productivo o instalación física.  
**META REAL:** un solo motor de restricciones `schemaVersion=2` alimentado exclusivamente por datos aprobados y versionados, con cambios de dígitos/paridad, días, horarios, habilitación territorial y modalidades sin nueva APK. Entregar la **APK DEV nueva del árbol FINAL**, un E2E OTA verificable en el alcance que realmente permita el entorno y **UN SOLO ZIP** de evidencia. **No es autorización de release.**

## 1. Verdad verificada y prohibiciones contra el ping-pong

**Base exacta:** V4-R1 `FINAL_TREE=24408f305f7a977cf30e426ce3925cca19f981ad`; reconstrucción independiente desde RC2 `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289` + `RECOVERY/RC2_TO_FINAL.patch` del ZIP `PICORADAR-N1-V4R1-QA-CAUSAL-APK-UNICO-20261116.zip` SHA256 `8de3d702d451ddd50e6c59b902522ce7c818f459469cb4655c7bdad2a05169d2`. Commit Windows reportado `182a8821bba688b28a6e223a1e956df748f7948b`, **no encontrado en GitHub**; no confundir HEAD, árbol de índice y árbol de worktree.

**Ya acreditado para ese tree por logs de Codex:** Flutter 3.47.9/Dart 3.13.7; 3.347 pruebas PASS, 11 SKIP documentadas, 0 FAIL, exit 0; `flutter analyze` PASS; migraciones 15 PASS, pruebas Viaje 16 PASS y evidencia histórica recuperada. Son **resultados reportados/logueados por Codex**, no nueva ejecución independiente en este chat. No volver a auditarlos ni ejecutar global completo sobre el **mismo** tree sin delta de Dart. Flutter `format global` estuvo bloqueado por ruta ignorada bajo `mobile/build`, formato rastreado PASS. No eliminar datos/cachés para satisfacer formato.

**Fallo real pendiente de APK:** `:android_file_picker:compileDebugKotlin` con `this and base files have different roots` entre caché Pub en C: y worktree en D:. No es evidencia de fallo del motor Dart. **El README de este mismo repositorio YA documenta un comando para esta situación**; usarlo primero, antes de modificar `gradle.properties`.

**Brechas estáticas concretas observadas por el Director sobre V4-R1, a confirmar con test focal antes de editar:**

- En `mobile/lib/app/app_providers.dart`, `restrictionJurisdictionsProvider` **filtra** las jurisdicciones `consultationEnabled=false`; `PicoDetailScreen` pasa ese resultado filtrado a `PicoJurisdictionCatalog.withRuntimeAvailability`. Una ciudad inicial entre las 5 habilitadas podría **seguir figurando disponible tras desactivación OTA**, porque el estado `false` no llega al selector. Viaje usa el listado completo en `tripRestrictionMappedMunicipalitiesProvider`; no dañar esa ruta.
- `PicoJurisdictionCatalog.withRuntimeAvailability` agrega jurisdicciones runtime sobre 73 registros, pero un mismo ID puede representarse con `id` y `engineJurisdictionId`; probar identidad y evitar duplicación **si realmente se reproduce**.
- `datasetSyncConfigProvider` devuelve `null` cuando **no se define `CDN_BASE_URL`**: la APK resultante es offline, NO una APK con OTA habilitada. `_validateProductDatasetConfig` exige **HTTPS y mismo origen CDN/manifest**. Un loopback `http://127.0.0.1` puede ser ensayo **de servicio** en test, pero NO prueba el cableado productivo/Android con HTTPS. **No desactivar TLS ni mentir con el nombre E2E.**

**Leyes L1–L6 y seguridad:** aplicar `AGENTS.md`, Baseline, especificaciones aplicables, KISS/Ponytail, antirruido, antiparches, diseño aprobado, verificación con evidencia y antiping-pong. No motor por ciudad, schema3, nuevos microservicios, panel paralelo, librerías no justificadas, publicidad activada ni publicación. Placas, VIN, cédulas, matrículas, contratos, imágenes privadas, GPS identificable y datos de vehículos **permanecen locales**; nada de enviarlos al backend/ZIP/logs. Trabajo editorial usa fuente institucional oficial para lo que afirma expresamente, sin exigir siempre PDF ni inventar ámbito/exenciones.

**Bloqueos de seguridad sin reinterpretación:** `GITHUB_PRODUCT=HOLD_SECURITY`, `PRODUCT_RELEASE=NO_GO`. No push de código, merge, force push, Hostinger, CDN productivo, GitHub Actions pagas, signing release, instalación/desinstalación/`pm clear` en Mi A3. La continuidad documental se mantiene en PR #79; el código local se conserva con parche restaurable. No intentar superar el hold subiendo el bundle privado a una rama documental.

## 2. F0 — Preflight mínimo, una sola vez

1. Confirmar una sola ejecución/escritor y la raíz real; localizar el worktree V4-R1 sin sobrescribir WIP ni acciones de otro agente. Registrar `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git status --porcelain=v1`, `git write-tree` **solo como árbol del índice actual**, `git diff --name-status` y `git diff --cached --name-status`. Comprobar contenido de árbol de trabajo y compare con `24408f...` si no hay cambios; **no aceptar `HEAD=RC2` como fallo si el parche V4 está staged con tree exacto**. Si hay WIP ajeno o divergencias, trabajar en clon aislado del bundle existente; nunca `reset --hard`, `clean -fdx`, checkout forzado ni edición del árbol ajeno.
2. Leer **solo lo pertinente al delta** en `AGENTS.md` y Baseline; no releer 15 auditorías, ni cambiar la jerarquía de autoridad. Rutas principales: `mobile/README.md` si existe, **`README.md` raíz** (receta de build Windows), `mobile/android/gradle.properties`, `mobile/lib/app/app_providers.dart`, `mobile/lib/features/pico_placa/data/restriction_store.dart`, `mobile/lib/features/pico_placa/data/pico_jurisdiction_catalog.dart`, `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart`, `mobile/lib/features/trip/data/trip_municipality_catalog.dart`, `mobile/lib/core/sync/dataset_sync_service.dart`, `mobile/lib/core/config/app_config.dart`, `server/app/Services/DatasetPublisher.php`, `server/app/Services/ManifestPublisher.php`, `server/app/Services/RestrictionPublicationService.php` y pruebas existentes relevantes.
3. Herramientas: usar Flutter/Dart/JDK/Android SDK de V4, sin reinstalar ni `pub get` automático; comprobar recursos y espacio, y dos salidas diferenciadas (pruebas y entrega). No crear artefactos pesados hasta la compilación final. Dejar disponibles los logs/hashes V4 como evidencias **reutilizadas**, nunca como PASS V5 si cambió el tree.
4. **Pruebas existentes — reutilizar, no inventar archivos:** `mobile/test/app/restriction_availability_providers_test.dart`, `mobile/test/features/pico_placa/data/pico_jurisdiction_catalog_test.dart`, `mobile/test/features/pico_placa/presentation/pico_detail_screen_test.dart`, `mobile/test/features/trip/data/trip_municipality_catalog_test.dart`, `mobile/test/features/pico_placa/domain/restriction_national_data_driven_test.dart`, `mobile/test/core/sync/dataset_sync_service_test.dart`, `mobile/test/app/dataset_sync_composition_test.dart`; servidor: `server/tests/Feature/RestrictionPublicationServiceTest.php` y `server/tests/Feature/DatasetPublisherTest.php`. Extender **solo las pruebas cuya cobertura causal falte**; reutilizar fixtures sintéticos existentes.

## 3. F1 — Cerrar motor nacional DATA-ONLY con dos fallos causales, SIN REFACTORIZAR

**Este paso antecede a la APK FINAL.** Construir primero y luego modificar Dart produciría una APK anterior al árbol final: PROHIBIDO entregarla como V5-R1 final. El objetivo no es investigar toda Colombia; son **dos pruebas focales**, arreglos mínimos si RED y persistencia offline.

### F1.1 Deshabilitación y reactivación REAL en Pico y Placa

1. Crear/ajustar **un test focal** en la suite existente de provider/selector (NO suite nueva por cada pantalla). Dataset `schemaVersion=2` **sintético**, dos jurisdicciones A/B (A de las 5 semillas habilitadas y B de las 1.104 conocidas pero fuera de las 73 editoriales). Precondiciones claras: ambas tienen datos del contrato válidos, `municipalityCodes` y `consultationEnabled`, categorías/servicios y período sintético. Verificar A `true→false→true` entre **versiones de dataset distintas**, sin reinstalar/recompilar APK: en `false`, **selector Pico debe desactivar A**, Inicio y detalle no deben dar `ALLOWED`, Viaje no puede evaluarla como activa y las alertas no deben seguir indicando permiso; al reactivar recupera cálculo con datos nuevos. B debe conservarse en todas las revisiones.
2. Probar específicamente `restrictionJurisdictionsProvider` (filtrado intencional para consumidores activos) **versus** la entrada sin filtrar que requiere `PicoJurisdictionCatalog.withRuntimeAvailability`. Si se reproduce, transportar la disponibilidad `false` al selector a través del `RestrictionStore.listJurisdictions`/provider existente, **sin convertir en activos los consumidores que filtran**. Preferir resolver con lectura/provider de disponibilidad mínimamente separado, sin copiar listas ni cambiar engine. Asegurar invalidación tras `onDatasetCommitted(restrictions)`; probar actualización sin reiniciar proveedor y tras reapertura.
3. No confundir **`dataset.enabled=false`** del manifest global (que puede omitir la entrada y dejar instalado el snapshot previo) con **`consultationEnabled=false` por jurisdicción**. Para deshabilitar una ciudad publicar un **snapshot completo nuevo con A false**, no simplemente retirar el dataset entero del manifest ni publicar solo A. Estado de ciudad desconocida/sin cobertura ≠ libertad de circulación.

### F1.2 Ciudad nueva, identidad y rotaciones por datos

4. Usar catálogo geográfico offline de **1.104 códigos** (nombres/departamentos) más 73 entradas editoriales como **apoyo visual**, no fuente de reglas. Con jurisdicción B (DIVIPOLA conocido pero no entre las 73): comprobar búsqueda en **Viaje y Pico**, nombre y departamento correctos donde exista mapeo, categoría/servicio, cambio de dígitos o paridad, día y horario entre dos versiones de snapshot; ausencia de falsos `ALLOWED`, `UNKNOWN/STALE` para cobertura parcial o caducada, y ninguna modificación del motor por ciudad. Distinguir «habilitar consulta» de «declarar que no hay medida».
5. Si `withRuntimeAvailability` duplica alguna ciudad por diferencias `id`/`engineJurisdictionId`, demostrar RED para ese caso y reparar solo deduplicación/resolución de identidad; **no** crear tabla geográfica paralela o redefinir los IDs nacionales. Si no falla, no tocar.
6. Verificar que tras OTA/version nueva persistan A y B, categorías/servicios y datos de Garaje; importar dos snapshots consecutivos, modo offline y reinicio de proveedor/base. Usar los helpers de test/Drift ya existentes; **no** almacenar placas ni documentos en evidencias.

**Salida F1:** `NATIONAL_DATA_ONLY=PASS|PARTIAL|FAIL`; `DISABLE_UI=PASS|FIXED_PASS|FAIL`; `NEW_MUNICIPALITY=PASS|FIXED_PASS|PARTIAL`; `UNKNOWN_NOT_ALLOWED=PASS|FAIL`. Si el cambio requerido afecta `app_providers.dart`/Dart, ejecutar pruebas focales RED→GREEN y preparar QA global **una sola vez en el árbol final**. Si esos escenarios ya pasan, conservar código tal cual.

## 4. F2 — OTA QA verdadero, separado de configuración HTTPS del producto

**Independiente de compilación Android. No inventar TLS ni un «E2E real» mediante stubs.** Utilizar servicios existentes Laravel (`DatasetPublisher`, `ManifestPublisher`, `RestrictionPublicationService`) y cliente `DatasetSyncService`/Drift. No modificar un ambiente de producción ni sacar una base de datos real.

1. Comprobar **una vez** disponibilidad de PHP, driver BD QA (SQLite si las migraciones lo admiten), Composer/vendor y almacenamiento QA efímero. Si falta, `OTA_LARAVEL_HTTP=NOT_RUN_ENV`; continuar F3 sin pedir otros prompts de preflight. Sin descargas masivas, Docker nuevo ni alterar `.env` real.
2. Si hay entorno, usar **únicamente datos sintéticos**: aprobación/revisión simuladas según las validaciones existentes (sin bypass de `DatasetReleaseValidator` ni `coverageCompleteness=complete` ficticia en datos legales), publicar snapshot total A+B, generar manifest con SHA256/revisión/versiones distintas, servir el recurso real desde Laravel **HTTP loopback QA**, descargar los bytes a través del **DatasetSyncService real instanciado en el test** e importar/consultar con Drift. No usar tests que inyecten respuestas predeterminadas y denominarlo E2E HTTP.
3. Publicar segunda versión **completa** cambiando A `consultationEnabled true→false`, dígitos/días/horas; mantener B; importar y validar pantalla/consulta/offline según F1. Rehabilitar A con tercera versión si el alcance de tiempo es razonable, SIN inventar cambios normativos de Colombia.
4. Negativos focales con una sola matriz ya existente: SHA corrupto, manifest 304 con instalación local inconsistente, revisión/version conflictiva, `staleAfter` y desconexión. Validar preservación last-good, no borrado de vehículos, no circulación libre por falta de datos. **Nunca deshabilitar validación de certificados/HTTPS de producción**.
5. Clasificar evidencias sin confundir planos: `OTA_SERVER_PUBLISH`, `OTA_SYNC_SERVICE_HTTP_QA`, `OTA_UI_AFTER_SYNC` y `OTA_PRODUCT_HTTPS_CONFIG`. La instancia normal de `datasetSyncServiceProvider` **rechaza HTTP** y exige CDN/manifest **HTTPS del mismo origen**. Un servicio HTTP loopback que pasó demuestra E2E a nivel **servicio en QA**, **no** que el producto Android se conecte a un CDN real. El gate `OTA_PRODUCT_HTTPS_CONFIG=PASS` solo si se prueba con URL HTTPS autorizada/certificada, sin desactivar TLS. Si no, `NOT_RUN_ENV`; ello no impide compilar una APK DEV offline.
6. PHP tests solo si hubo cambios PHP; Dart focales cuando corresponda. No repetir 3.347 tests por un ajuste exclusivamente a Laravel o configuración de entorno. Si faltan dependencias, registrar causa real, seguir lo independiente y **no fabricar PASS**.

## 5. F3 — Compilar APK DEV del árbol FINAL con corrección Kotlin YA documentada

**No editar `gradle.properties` antes del primer intento.** `README.md` del repositorio ya establece la receta para Windows C:/D:; mantenerla. **No** `flutter clean`, borrar caché Pub, rotar firma, cambiar Gradle, Kotlin, Flutter, API, flavor ni Android package. **No instalar sobre Mi A3**.

1. Cerrar cambios de código de F1/F2, formato puntual y pruebas focales. Capturar `FINAL_TREE` del contenido exacto que se va a construir (commit local aislado después de verificar o índice válido). No incluir override temporal en el tree final. Si hay modificaciones Dart, completar después la suite global de F4 antes de declarar build utilizable.
2. Ejecutar **un intento principal**, desde `mobile` y con Flutter/Java/SDK V4, según **receta del README**, sin inventar flags:
   ```powershell
   flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev --no-pub --no-android-gradle-daemon --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process
   ```
   Si el CLI instalado no acepta algún flag, registrar la ayuda/exit y pasar **una sola vez** a alternativa de propiedad local reversible (guardar bytes originales de `mobile/android/gradle.properties`, configurar `kotlin.incremental=false`, restaurar bytes al finalizar). Si la misma causa C:/D: persiste, permitir **un único intento adicional causal** con caché temporal de tarea en D: si es técnicamente seguro (sin borrar/mover caché global), no una sucesión ilimitada de builds. Omitir la alternativa si el primer intento ya compila. Nunca limpiar un APK anterior sin preservar procedencia.
3. **Configuración OTA de esa APK:** antes del build registrar `CDN_BASE_URL`, `MANIFEST_URL` y `APP_ENV` **sin exponer credenciales**. Si hay **un CDN HTTPS de QA autorizado, real y accesible**, con manifest del mismo origen y certificados válidos, pasar solo esas URLs no sensibles como `--dart-define` y verificar contra `datasetSyncConfigProvider`/`_validateProductDatasetConfig`. **No inventar una URL, no usar loopback HTTP como CDN de producto, no desactivar HTTPS.** Si no existe, compilar igual la APK DEV de funcionamiento offline y declarar explícitamente `APK_OTA_CONFIG=DISABLED_NO_CDN`, **no afirmar que prueba OTA en dispositivo**. El build con solo `APP_ENV=dev` es de uso interno y OTA está deshabilitada por diseño.
4. Si compila, **copiar la APK recién creada** desde la ruta real `mobile/build/app/outputs/flutter-apk/app-dev-debug.apk` (o output confirmado) a `delivery/`, registrar SHA256, bytes, package/flavor/versionCode/cert (apksigner/aapt si están disponibles) y árbol Git exacto **antes/después**; comparar con APK anterior y evitar etiquetar la vieja como nueva. La APK generada debe corresponder al **mismo tree final tras cualquier reparación Dart**. Si se cambia código después del build, el APK es obsoleto; **una sola recompilación final justificada** o `APK_STALE_NOT_DELIVERED` (no confundir con artefacto final).
5. Si falla, clasificar `APK_BUILD=FAIL_ENV|FAIL_CODE` con tarea/causa precisa y log sanitizado; **no** publicar APK anterior. Continuar cierre de evidencia F4 aun si el build falla. No extender a APK release, signing de distribución, permisos reales ni instalación.

## 6. F4 — QA final proporcional, protección de datos y ÚNICO ZIP

1. QA de **árbol FINAL**: si cambió Dart/Flutter, `dart format --output=none --set-exit-if-changed` sobre rutas tocadas y el gate global de `AGENTS.md` **una sola vez**, gestionando la ruta ignorada `mobile/build` de manera no destructiva; `flutter analyze --no-pub` y **una sola** suite `flutter test --no-pub` global en el árbol final (con 11 skips explicados o resultado nuevo real). Si **no** cambió Dart, reutilizar `MOBILE_FULL_QA=PASS_REUSED_EXACT_V4_TREE` y ejecutar únicamente nuevas pruebas OTA/UI sobre el mismo código; no declarar que ese PASS cubre código distinto. Si cambia servidor, sólo tests PHP/formatter afectados; si cambió únicamente procedimiento Gradle, test de build basta, no ejecutar 3.347 por inercia. Respetar siempre QA obligatoria según `AGENTS.md` para el ámbito realmente cambiado.
2. Verificar que no se exponen ni registran datos personales, tokens, claves, placas, documentos, GPS ni WIP. Una comprobación **focal** de secretos sobre el diff saliente si la herramienta está disponible (sin instalar herramientas por ritual), registrar `GITHUB_HOLD_SECURITY=UNRESOLVED` si el histórico sigue pendiente: **NO hacer push producto** ni inventar cumplimiento.
3. Reportar con distinción estricta de PASS evidenciado, PASS reutilizado, FAIL y NOT_RUN_ENV. `FINAL_REPORT.md` conciso con cambios de producto, rutas, `HEAD/INDEX_TREE/FINAL_TREE`, prueba causal A false, nuevo municipio, OTA HTTP, límites HTTPS, build y SHA, QA final, riesgos de usuario/seguridad y próximos entregables. `GATES.csv` con entradas mínimas; logs sanitizados; manifiesto SHA256/CRC/tamaños; patch **reproducible RC2→FINAL_TREE** solo si se cambió código o código/config rastreado. Incluir pruebas que cambiaron sin duplicar todo el historial.
4. Devolver **UN SOLO ZIP** `PICORADAR_V5R1_APK_OTA_NACIONAL_RETORNO_UNICO.zip` en `D:\codex\_REPORTES\PicoRadar\<TASK_ID>\delivery\`, con **APK DEV binaria nueva** si se generó y es del FINAL_TREE, `FINAL_REPORT.md`, `GATES.csv`, logs/manifest/patch necesarios; si no hay APK, solo evidencia y diagnóstico preciso. Verificar ZIP CRC y hashes; no incluir bundle RC2 (~82 MB), ZIP V4, cachés/build completo, bases privadas, archivos personales ni APK obsoleta. Al retornar escribir **ruta ABSOLUTA Windows**, SHA256 del único ZIP y resumen de una línea. **No dar URL `sandbox:` ni enlace `/D:/` como si fuera descargable en ChatGPT**: el usuario adjuntará físicamente el ZIP.
5. Conservar WIP y repos ajenos; no reiniciar otro lote. Un README/continuidad dentro del mismo ZIP basta. Sin PR nuevo ni documentación repetida si no aporta delta. Después del ZIP `NEXT_ACTOR=CHATGPT_DIRECTOR`; no preguntar «qué hago ahora», no más prompts de preflight ni nuevas auditorías históricas.

### Gates obligatorios a reportar

```text
TASK_ID=PICORADAR-V5R1-FINAL-APK-OTA-NATIONAL-DATA-20261116
BASE_TREE=24408f305f7a977cf30e426ce3925cca19f981ad
FINAL_HEAD=<SHA REAL, indicar si local>
FINAL_TREE=<SHA REAL>
DISABLE_UI=PASS|FIXED_PASS|FAIL|NOT_RUN_ENV
NEW_MUNICIPALITY=PASS|FIXED_PASS|PARTIAL|NOT_RUN_ENV
NATIONAL_DATA_ONLY=PASS|PARTIAL|FAIL|NOT_RUN_ENV
UNKNOWN_NOT_ALLOWED=PASS|FAIL|NOT_RUN_ENV
OTA_SERVER_PUBLISH=PASS|FAIL|NOT_RUN_ENV
OTA_SYNC_SERVICE_HTTP_QA=PASS|FAIL|NOT_RUN_ENV
OTA_UI_AFTER_SYNC=PASS|FAIL|NOT_RUN_ENV
OTA_PRODUCT_HTTPS_CONFIG=PASS|NOT_RUN_ENV|FAIL
APK_BUILD=PASS|FAIL_ENV|FAIL_CODE
APK_OTA_CONFIG=ENABLED_AUTHORIZED_HTTPS|DISABLED_NO_CDN
APK_DELIVERED=YES|NO
APK_TREE_MATCH=YES|NO|NOT_APPLICABLE
MOBILE_FULL_QA=PASS_NEW|PASS_REUSED_EXACT_V4_TREE|FAIL|NOT_RUN_ENV
ANDROID=NOT_INSTALLED_SAFE
GITHUB_PRODUCT=HOLD_SECURITY
PRODUCT_RELEASE=NO_GO
ZIP=<ruta absoluta Windows y SHA256>
NEXT_ACTOR=CHATGPT_DIRECTOR
```

**Cierre V5-R1 útil:** APK DEV del **tree final**, estado de OTA correctamente desglosado, municipio nuevo y deshabilitación demostrados mediante datos, con `UNKNOWN/STALE` seguros. **No significa APP_COMPLETE.** Después quedan, de manera separada y ya documentada, QA física Android, seguridad/signing y publicación, registro opcional/consentimiento y panel de usuarios/exportación, CDA/SOAT/aliados/ads conforme Baseline. No inventar 1.104 normas ni implementar un motor por ciudad.