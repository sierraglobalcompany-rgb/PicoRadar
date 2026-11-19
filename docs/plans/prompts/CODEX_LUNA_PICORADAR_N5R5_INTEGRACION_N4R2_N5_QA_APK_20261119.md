# CODEX LUNA — PICORADAR N5-R5 · INTEGRACIÓN N4-R2 + N5/01–04, QA DIRIGIDA Y APK DEV SI ES SEGURA

**TASK_ID:** `PICORADAR-N5R5-INTEGRACION-N4R2-N501-N504-QA-APK-20261119`  
**DIRECTOR:** ChatGPT. **EJECUTOR:** Codex Luna. **TIPO:** un único macrobloque de desarrollo, integración y cierre de pruebas; **NO otra auditoría histórica**.  
**ENTRADA OBLIGATORIA:** adjunto `PICORADAR_N5R5_INTEGRACION_N4_N5_UNICA_20261119.zip` (contiene los dos parches equivalentes, README y manifiesto). Si el archivo no se adjuntó, leer su ubicación en el mensaje; nunca sustituirlo por código remoto desactualizado.  
**BASE HISTÓRICA RC2:** commit `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`.  
**BASE N3-R1 VERIFICADA:** TREE `a883b64fffb53d3d9ec263739c169561ddf8b49d`.  
**N4-R2:** TREE `1e57a8363bdcf9c6bbf453ba21e8e3022edc54b2` (31 rutas, 17 PHP tests / 189 asserts + Flutter focal/analyze PASS según evidencia de N4).  
**N5/04:** TREE `46da2c96277a46f90f4198d081f0d96c3802057e` (N5/01–04, candidato aislado, pruebas Flutter pendientes).  
**TREE ÚNICO YA FUSIONADO POR DIRECTOR:** `986a24831aef2bcc6d261be771839f71c1129d40`, **61 archivos, 0 conflictos pendientes**, 4.184 inserciones / 35 eliminaciones frente a N3-R1. El único archivo común fue `server/.env.example`, fusionado automáticamente sin pérdida de flags.

## 0. Reglas innegociables y prohibiciones

1. **No vuelvas a desarrollar N4 ni N5 desde cero.** El Director reconstruyó RC2→V4→V5→R2→N3, aplicó N4 y N5 en ramas independientes y fusionó ambos; el ZIP entrega un parche único que crea el árbol resultante. No rehacer 10×10 auditorías, 3347 pruebas antiguas, inventario nacional ni código ya implementado.
2. **Respetar WIP:** Codex reportó HEAD local `182a8821…`, índice real `24408f30…` y **43 entradas WIP** protegidas. Inspecciona identidad y estado, pero **no cambies checkout/índice real**, no `reset --hard`, `clean -fd`, `stash` automático, `checkout` sobre el original, force push ni eliminación recursiva. Trabaja en clon/worktree **AISLADO** dentro de `D:\codex\_isolated\PICORADAR-N5R5-20261119` o equivalente sin colisionar.
3. **Seguridad GitHub:** `HOLD_SECURITY` persiste. **No push de commits de producto**, merge, release, edición de secretos, publicación de usuarios reales ni GitHub Actions. El `main` público es antiguo; no utilizarlo como base. La rama documental `director/n5-modality-safe-20261118` guarda los parches N5, no contiene la integración del producto.
4. **KISS:** un motor de restricciones `schemaVersion=2` nacional, un Laravel editor/publicador ya existente, un `DatasetSyncService`; no motor ni dashboard por ciudad, no microservicios, nueva biblioteca de anuncios, segunda base de usuarios administrativos ni parches para silenciar tests.
5. **Privacidad:** placas, documentos, VIN, fotos y GPS siguen **solo locales**. Cuenta de cliente final voluntaria y separada de operadores; mensajes comerciales y cuentas OFF por defecto; sin correo real, sin importación de datos privados ni anuncios en Conducir/HUD/documentos. Consulta no acreditada = `UNKNOWN/STALE`, jamás `ALLOWED`.
6. **Pruebas sin usuario:** tú ejecutas lo que pueda correr tu entorno, sin pedir al propietario que instale herramientas, ejecute tests o valide GitHub. Si el entorno sigue insuficiente, regresa evidencia específica y avanza lo independiente. Un solo ZIP de retorno.

## 1. Integración recuperable: aplicar UNA sola ruta

**Primero** verificar CRC/SHA del ZIP de entrada según `MANIFEST.csv` y conservarlo inmutable. Descomprimir en el directorio de trabajo aislado. Elegir exactamente una variante:

- **Preferida si puedes recuperar N3-R1 exacto:** sobre un clon aislado con `git write-tree == a883b64fffb53d3d9ec263739c169561ddf8b49d`, aplicar `PATCHES/N3R1_TO_N4R2_N504_INTEGRADO.patch`.
- **Alternativa más directa si solo tienes RC2:** sobre clon aislado del `RC2_BASE_full-final.bundle` conocido (o repositorio local que contenga el objeto RC2), `git switch --detach 7e2e1f3…` y aplicar `PATCHES/RC2_TO_N4R2_N504_INTEGRADO.patch`. El bundle histórico local contiene el objeto RC2; NO hay que generar otro bundle de 85 MB. Si el objeto no está disponible, localizar el bundle original por nombre una vez y reportar el bloqueo exacto en lugar de crear otra cadena de recuperación.

En ambos casos: `git apply --check <parche>`; `git apply <parche>`; `git add -A` **solo en clon aislado**; `git diff --cached --check`; **`git write-tree` DEBE ser `986a24831aef2bcc6d261be771839f71c1129d40`**. Un SHA diferente es `STOP_CONFLICT_BASE`; no arreglarlo con un parche improvisado ni descartar WIP. No aplicar ambos parches (son alternativas equivalentes). Conserva hash de árbol antes de cualquier ajuste adicional. No requiere commit para correr QA local; uno local aislado está permitido si resulta útil y queda documentado.

**Contenido ya entregado, sin tareas de programación repetidas:**
- N4: API de cliente opcional, OTP/tokens, perfil, consentimiento/baja, CSV seguro, panel Super Admin y Ajustes Flutter.
- N5/01: suspender una consulta por modalidad conservando cobertura parcial y `UNKNOWN`.
- N5/02–03: validar y publicar catálogos CDA, geografía y aseguradoras en Laravel, consumirlos por el OTA existente con SHA/last-good/fallback y sin CDN cuando la función está OFF.
- N5/04: publicidad y catálogo patrocinado apagados por defecto, publicación manual sin Actions y control HTTPS para activación futura.

## 2. QA causal y arreglo focal, una sola pasada del árbol integrado

**Prioridad A — tests nuevos/cambiados; cero repeticiones vacías.** Sin cambiar dependencias ni hacer `pub get`/`composer install` repetitivo, usar las ya instaladas (si faltan, una instalación local offline/desde lock autorizada, nunca entornos productivos). Ejecutar por agrupación:

- **Laravel/PHP:** `tests/Feature/AppAccountApiTest.php`, `AdminAppUsersTest.php`, `MobileCatalogPublicationTest.php`, `RestrictionSchemaV2LabRoundTripTest.php`, `CampaignCatalogPublisherTest.php`, `CampaignAdminControllerTest.php`, `tests/Unit/MobileCatalogPayloadValidatorTest.php`, `RestrictionFormPayloadBuilderTest.php`; incluir `CampaignOperationsTest.php` o `CampaignRouteIntegrationTest.php` **solo si existen y son necesarios por el delta**. Correr Pint y PHP lint SOLO sobre archivos modificados, sin reformatear legado.
- **Flutter:** `test/features/account/data/app_account_client_test.dart`, `app_account_config_test.dart`, `test/features/settings/presentation/settings_screen_test.dart`, `test/app/mobile_catalog_ota_test.dart`, `test/app/dataset_sync_composition_test.dart`, `test/features/home/application/home_partner_catalog_provider_test.dart`, `test/features/home/data/home_partner_catalog_test.dart`. Ejecutar `flutter analyze --no-pub` y `dart format --output=none --set-exit-if-changed lib test`. **No `dart format .`**, porque atraviesa una ruta Gradle ignorada/inexistente bajo `mobile/build`.
- Verificar combinaciones reales entre módulos: flags de cuentas y anuncios OFF por defecto; API de cuentas independiente de CDN; `CDA/geografía/insurers` caen al asset si no hay dataset; OTA con hash válido, hash roto, 304, last-good y reinicio offline; cambiar modalidad no produce falso `ALLOWED`; el servidor no expone lista publicitaria si no está autorizado; consentimiento no autoriza spam ni envía PII de vehículos.
- Si falla una prueba **nueva**, reproducir causa exacta, corregir lo mínimo en los archivos afectos, rerun focal de ese error. Evitar falsear tests o reclasificar bugs reales como fixtures. Tras ajustes significativos Dart, ejecutar **una única suite global al final**. Si no cambia Dart, focal/analyze más evidencia previa son suficientes hasta cerrar el gate global.

**Prioridad B — seis fallos históricos de fixtures.** N4 registró `3349 PASS / 14 SKIP / 6 FAIL` por insumos externos genuinos ausentes: `PICORADAR_G2_V3_EVIDENCE_DIR`, `PICORADAR_V1_METADATA_LAB_DIR`, `PICORADAR_G34_LAB_EVIDENCE_DIR`, `PICORADAR_G1_EVIDENCE_DIR`, `PICORADAR_R2_EVIDENCE_DIR`, `PICORADAR_G2_R2_RELEASE`. En V4 estas evidencias históricas se habían recuperado y pasado; localizar las originales **una sola vez** por ruta, hash y versiones, sin alterar originales ni fabricarlas. Copias de solo lectura en QA. Ejecutar **únicamente los seis tests afectados** después de configurar el entorno; si faltan, dejar `GLOBAL_PARTIAL_EXTERNAL_FIXTURES` con la ruta y hash que falta. No bloquear módulos nuevos por un archivo externo ausente.

**Prioridad C — E2E de datos:** con SQLite/Laravel QA aislado **si el driver existe**, comprobar en una prueba focal integración editor/publicador→manifest firmado por SHA→HTTP loopback→`DatasetSyncService`→Drift→proveedores de CDA/aseguradoras, preservación de otras jurisdicciones y rollback. No proclamar `OTA_HTTPS_PRODUCT=PASS` por prueba HTTP. HTTPS QA con mismo origen solo si hay endpoint seguro autorizado; sin endpoint `NOT_RUN_ENV` y continuar. No agregar API ni esquema alterno solo para pasar la prueba.

## 3. APK y cierre técnico (solo cuando sea seguro)

No confundir APK V5 DEV anterior, **sin CDN**, con el árbol integrado nuevo. Antes de compilar, comprobar margen real de memoria comprometida y RAM; N4 tuvo **4,45 GiB disponibles para commit, por debajo del piso de seguridad 6 GiB**. Si sigue por debajo, **no ejecutar Gradle** ni limpiar cachés destructivamente ni bajar el umbral arbitrariamente: `APK=BLOCKED_RESOURCE_GATE`, conservar evidencia y pasar a empaquetar. Si hay ≥6 GiB y el código crítico pasa, intentar **UNA** compilación `devDebug` del árbol final usando la receta existente de README para Kotlin en Windows; no firmar release con debug key ni instalar encima del Mi A3 con certificado diferente. Con `CDN_BASE_URL` ausente, dejar OTA deshabilitada y declararlo. Cuentas reales y publicidad **OFF**. Si construyes APK nueva, incluir únicamente esa APK y su hash/certificado/package/version en el ZIP final; no duplicar la APK vieja de 245 MB.

## 4. Entrega ÚNICA obligatoria y relevo

Preparar **un solo ZIP** `PICORADAR_N5R5_INTEGRACION_QA_UNICO.zip`, sin carpetas sueltas para adjuntar. Debe contener, cuando existan: `FINAL_REPORT.md`, `GATES.csv`, `MANIFEST.csv` con SHA-256/tamaño/CRC32, logs compactos focales y solo de los fallos, **parche incremental desde TREE integrado** `986a2483…` hacia `FINAL_TREE` si corriges código, o parche final completo desde N3-R1 si es más portable, y la APK nueva **solo si se compiló**. No adjuntar tokens/credenciales, email real, documentos ni bundle antiguo. Verificar ZIP CRC y hashes antes de declarar entrega.

El informe, con respuestas explícitas y sin placeholders, debe reportar: `TASK_ID`, `SOURCE_N3_TREE`, `INTEGRATED_BASE_TREE`, `FINAL_TREE`, `FILES_DELTA`, `PHP_FOCAL`, `FLUTTER_FOCAL`, `FLUTTER_ANALYZE`, `FORMAT`, `HISTORICAL_6`, `CATALOG_OTA`, `MODALITY_DISABLE`, `ADS_OFF`, `ACCOUNTS_OFF`, `OTA_HTTPS_QA`, `APK_BUILD`, `APK_SHA256` si aplica, `WIP_PRESERVED`, `GITHUB_PRODUCT=HOLD_SECURITY`, `PRODUCT_RELEASE=NO_GO` salvo autorización separada real y `NEXT_ACTOR=CHATGPT_DIRECTOR`. Distinguir `PASS_SCOPED`, `NOT_RUN_ENV`, `BLOCKED_RESOURCE_GATE` y `FAIL_CODE`; no inventar porcentajes ni resultados.

**Condición de salida:** un único lote terminado sobre 61 archivos integrados, pruebas focales del delta y cualquier bug causal corregido; no reabrir V3/V4/N3 ni pedir nuevos prompts para continuar el mismo trabajo. **No pedir intervención del propietario ni esperar nuevas tareas; terminar y devolver ZIP.**

# 🔴 SIGUE: CODEX LUNA. DESPUÉS DEL ZIP: CHATGPT DIRECTOR. 🔴