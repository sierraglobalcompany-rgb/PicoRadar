# CODEX LUNA — PICORADAR N5-R5-R1 · INTEGRACIÓN ÚNICA N4-R2 + N5/01–04, CORRECCIÓN CAUSAL, QA Y APK SEGURA

**TASK_ID:** `PICORADAR-N5R5R1-CIERRE-INTEGRADO-20261119`  
**ACTOR:** Codex Luna, ejecutor. **DIRECCIÓN:** ChatGPT Director. **OBJETIVO:** terminar un bloque de producto integrado, no abrir otra auditoría. **UNA sola ejecución y UN solo ZIP de regreso.**  
**ADJUNTOS:** (1) ESTE Markdown R1; (2) `PICORADAR_N5R5_INTEGRACION_N4_N5_UNICA_20261119.zip`. **NO** enviar a Codex los cinco ZIP históricos ni el N5-R5 antiguo. Dentro del ZIP existe una copia del prompt N5-R5 **SUPERADO**: IGNORARLA. Este R1 sustituye por completo esa instrucción y no modifica los parches ya verificados.

**IDENTIDADES CONGELADAS (comprobadas por el Director, en clon independiente):**

| Ítem | Identidad |
|---|---|
| ZIP de entrada | SHA-256 `6315c56bfc55ad162730eb68f61bb0697e45695214307ae8562ff80302fab03c` (155.381 bytes; CRC y 6/6 entradas del manifiesto PASS) |
| BASE RC2 | commit `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289` |
| BASE alternativa N3-R1 | tree `a883b64fffb53d3d9ec263739c169561ddf8b49d` |
| N4-R2 individual | tree `1e57a8363bdcf9c6bbf453ba21e8e3022edc54b2`, tests focales previos PASS, suite global con fixtures faltantes |
| N5/04 individual | tree `46da2c96277a46f90f4198d081f0d96c3802057e`, código/tests preparados, **QA Flutter pendiente** |
| **ÁRBOL INTEGRADO CANDIDATO** | `986a24831aef2bcc6d261be771839f71c1129d40` (61 rutas N4+N5 desde N3; 104 rutas desde RC2) |
| Parche preferente RC2 → integrado | `PATCHES/RC2_TO_N4R2_N504_INTEGRADO.patch`, SHA-256 `1c67468d5555d915137640332b1c203900b76582db5322b4e9ec7628b278d5eb` |
| Parche alternativo N3 → integrado | `PATCHES/N3R1_TO_N4R2_N504_INTEGRADO.patch`, SHA-256 `04b23709133b1b6fb02e6bea7c9b735305d8670c223b8df319602a3862a1b19b` |

**RESULTADO YA PROBADO Y NO REPETIR:** el Director aplicó el parche RC2 a un clon LIMPIO, `git apply --check` y `git diff --cached --check` pasaron, `git write-tree` fue exactamente `986a2483…`. Los otros parches de N3/N4/N5 y su historia ya fueron contrastados. No rehacer 10+10 auditorías, comparar otra vez los ZIP anteriores ni revalidar todos los archivos legales y municipales.

## 0. Seguridad, privacidad y ámbito

1. **No tocar el checkout real con WIP de Codex**: reportado HEAD `182a8821…`, índice `24408f30…`, 43 entradas modificadas y tres ficheros protegidos. PROHIBIDOS `reset --hard`, `clean -fd`, `stash` automático, `git add -A` o `checkout` en ese checkout; no borrar staging ni caches globales. Trabajar en `D:\codex\_isolated\PICORADAR-N5R5R1-20261119` o clon equivalente nuevo y sin modificaciones. Si ya hay ejecución activa, NO iniciar escritor paralelo.
2. `GITHUB_PRODUCT=HOLD_SECURITY`: el repo público `main` **no contiene** la base productiva moderna; la rama `director/n5-modality-safe-20261118` conserva **parches y documentación**, NO código de producción integrado. No push productivo, merge, PR de implementación, release, Actions, credenciales ni despliegue. Se preservan todos los SHA locales para resolver la publicación segura después.
3. Baseline Free 1.0: la app funciona **sin cuenta**. Cuentas, marketing y publicidad **OFF por defecto**, incluso si los paneles de preparación ya existen. No correo real ni activar proveedores comerciales; `Mail::fake()` es solo QA. Placas, VIN, GPS, cédulas, matrículas, fotos y documentos siempre locales. `UNKNOWN/STALE` cuando falta cobertura legal; suspender una consulta NO es permiso para circular.
4. Un motor nacional `schemaVersion=2`, editor/publicador Laravel existente y `DatasetSyncService` existente. NO nuevo motor por ciudad, API paralela, segundo sincronizador, segundo CRM o microservicios. Una web institucional de alcaldía/gobernación/autoridad **basta para lo que publique expresamente**, sin exigir PDF de decreto rutinariamente y sin inferir excepciones ausentes.

## 1. Recuperación única, determinista y sin ping-pong

1. Verificar una sola vez ZIP SHA-256/CRC y `MANIFEST.csv`. Extraer a carpeta temporal aislada. Elegir **EXACTAMENTE UN** parche; no aplicar ambos.
2. **RUTA RÁPIDA PREFERIDA: RC2.** Crear un clon LOCAL NUEVO del repositorio con objeto RC2 disponible (`git clone --no-local <ruta_repositorio_local> <ruta_aislada>`; si Windows no admite esa opción, usar `git clone` normal). Dentro del CLON, comprobar `git cat-file -e 7e2e1f3f311b18e29f63d3a5e05e9439a11c4289^{commit}` y `git switch --detach 7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`. Asegurar `git status --porcelain` vacío **en el clon**. Aplicar SOLO `PATCHES/RC2_TO_N4R2_N504_INTEGRADO.patch` con `git apply --check` seguido de `git apply`.
3. Si no existe RC2, realizar **una** búsqueda del `RC2_BASE_full-final.bundle` histórico y agregarlo **solo al clon aislado**, nunca sobrescribir repositorio real. Si lo único disponible es la base N3-R1 exacta y LIMPIA, usar la ruta N3 con el segundo parche. La identidad de árbol del **índice** por sí sola NO prueba que el *worktree* esté limpio: verificar ambos antes de aplicar. Ante falta real de ambos objetos `BLOCKED_BASE_EXACT` y devolver evidencia, sin inventar una base con GitHub `main` ni iterar preflights.
4. **Solo en el clon:** `git add -A` → `git diff --cached --check` → `git write-tree`. Gate obligatorio `INTEGRATED_BASE_TREE=986a24831aef2bcc6d261be771839f71c1129d40`. Si no coincide, **STOP_SOURCE_TREE** y reporte del primer archivo divergente; no reescribir parches a ojo. Capturar WIP del checkout real como hash/estado sin tocarlo.
5. **NO confundir 61 con 104 rutas:** el cambio N4+N5 es de 61 rutas relativo a N3, pero el parche rápido desde RC2 también contiene V4/V5/R2/N3 y modifica 104 rutas. Para determinar las pruebas del DELTA usar `SOURCE_FILES.csv` y los cambios N4/N5, no volver a testear todo RC2→N3.
6. Antes de corregir código, registrar árbol integrado exacto. DESPUÉS de correcciones focales, `FINAL_TREE` puede cambiar: eso NO es un fallo del gate de base. Registrar solo el delta `INTEGRATED_BASE_TREE→FINAL_TREE` en el ZIP final.

## 2. QA nuevo y correcciones causales — una ejecución acotada

**A. PHP/Laravel (primer gate; no repetir pruebas históricas verdes):** en `server` usar entorno LOCAL/QA y dependencias del lock existente, jamás BD real o producción. Si `vendor` falta, **un** intento acotado de instalación desde lock compatible; si el driver SQLite/PHP falta, `NOT_RUN_ENV` específico y continuar con lo independiente. Ejecutar en un grupo los tests existentes del cambio (archivos comprobados en el árbol candidato):

```
php artisan test tests/Feature/AppAccountApiTest.php tests/Feature/AdminAppUsersTest.php tests/Feature/MobileCatalogPublicationTest.php tests/Feature/RestrictionSchemaV2LabRoundTripTest.php tests/Feature/CampaignCatalogPublisherTest.php tests/Feature/CampaignAdminControllerTest.php tests/Unit/MobileCatalogPayloadValidatorTest.php tests/Unit/RestrictionFormPayloadBuilderTest.php
```

Añadir `CampaignOperationsTest.php`/`CampaignRouteIntegrationTest.php` solo si cambió su contrato o hay fallo focal relacionado. Comprobar `php -l` sobre PHP modificados y Pint check exclusivamente en el delta. Gate funcional: cuentas sin login obligatorio; OTP/consentimientos/CSV saneado; N5/01 pausa de UNA modalidad preserva las otras y produce `UNKNOWN`, nunca `ALLOWED`; Laravel publica CDA, geografía y aseguradoras con SHA y rollback; campañas reales apagadas por defecto y republicación administrativa segura. Si aparece un error de código, reproducirlo UNA vez, corrección mínima KISS, volver a pasar solo el test afectado. No maquillar tests.

**B. Flutter (segundo gate; código N5/03 y N5/04 NO probado aún):** en `mobile`, comprobar una vez SDK/paquetes del lock; no gastar tokens en reinstalar herramientas o `pub get` en bucle. Ejecutar **focales del delta N4/N5**:

```
flutter test --no-pub test/features/account/data/app_account_client_test.dart test/features/account/data/app_account_config_test.dart test/features/settings/presentation/settings_screen_test.dart test/app/mobile_catalog_ota_test.dart test/app/dataset_sync_composition_test.dart test/features/home/application/home_partner_catalog_provider_test.dart test/features/home/data/home_partner_catalog_test.dart
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test
```

En caso de incompatibilidad del CLI con la lista de archivos, ejecutar esos tests por grupos funcionales (cuentas, catálogos/OTA, publicidad) **sin repetir grupos verdes**. Si formato o análisis identifica código nuevo, arreglar solo rutas nuevas o cambiadas. No ejecutar `dart format .` a ciegas: en V4/N4 se bloqueó por ruta ignorada bajo `mobile/build`; registrar excepción ambiental frente a `AGENTS.md`, sin ocultarla. No alterar formato del legado.

**C. Prueba de integración decisiva, sin otro motor ni test inventado:** exigir pruebas efectivas, reales y distinguibles: (i) backend devuelve datos CDA/geografía/aseguradoras con `datasetKey`, versión y hash compatible; cliente instala o vuelve al asset al no haber CDN, rechaza hash malo, repara copia alterada y queda offline; (ii) tres banderas OFF en servidor/móvil mantienen anónima la app y sin publicidad real; (iii) `schema2` conserva cobertura cuando se suspende modalidad, sin falsos `ALLOWED`; (iv) fallo en un catálogo NO destruye la última publicación íntegra. **La prueba HTTP simulada de Flutter más PHPUnit no es HTTPS E2E Android.** Si existe QA con Laravel SQLite y transporte seguro, verificar mismo byte publicado→Dio/Drift; si no, `BRIDGE=PASS_SCOPED_COMPONENTS` o `NOT_RUN_ENV` fundamentado. No abrir otro proyecto de infraestructura, no subir datos reales.

**D. Los 6 fallos externos N4 son requisitos de datos, NO fallos del motor demostrados:** antes de lanzar suite global revisar UNA vez disponibilidad real de fixtures G1/G2/G34/R2 mediante los env vars existentes `PICORADAR_G2_V3_EVIDENCE_DIR`, `PICORADAR_V1_METADATA_LAB_DIR`, `PICORADAR_G34_LAB_EVIDENCE_DIR`, `PICORADAR_G1_EVIDENCE_DIR`, `PICORADAR_R2_EVIDENCE_DIR` y `PICORADAR_G2_R2_RELEASE`. V4 recuperó insumos auténticos; probar rutas/hash y copiar solo a QA temporal, sin modificar originales ni crear evidencia sintética para reemplazarlos. Si falta algún fixture, ejecutar solo los tests históricos afectados **que puedan pasar con datos auténticos**; NO repetir global con seis fallos ambientales conocidos.

**E. SUITE GLOBAL: MÁXIMO UNA CORRIDA** después de resolver focales y disponer de fixtures auténticos, porque el árbol móvil N4+N5 es distinto del que produjo los 3349 PASS/14 SKIP/6 FAIL. `flutter test --no-pub --reporter json` una vez; si no se puede por fixtures ausentes, `MOBILE_GLOBAL=PARTIAL_EXTERNAL_FIXTURES` y no atribuir la suite V4/N4 a este árbol. Si falla por nuevo código, arreglar causa y ejecutar focal correspondiente; si es necesario repetir global por ese cambio, declararlo excepcional y justificado, no iniciar un ciclo automático.

## 3. APK DEV final SOLO si memoria segura, sin afectar Mi A3

1. El N4 reportó margen de memoria comprometida **4,45 GiB**, inferior al piso seguro de **6 GiB**. Medir de nuevo memoria/RAM/compromiso antes de Gradle. Si margen <6 GiB, `APK_BUILD=BLOCKED_RESOURCE_GATE`, no forzar Gradle ni limpiar caché o memoria ajena; **NO bloquear la entrega del trabajo y sus tests**. Si margen ≥6 GiB y gates críticos verdes, intentar **un** build DEV del árbol FINAL mediante receta Kotlin documentada para C:↔D: y `flutter build apk --flavor dev --debug --no-pub`. Sin builds repetidos, release firmado con debug ni instalación sobre Mi A3 sin plan de datos/firma.
2. Con `CDN_BASE_URL` vacío la app conserva catálogos offline y NO se certifica actualización remota en APK. Cuentas/ads OFF por defecto, no habilitar SMTP real ni anuncios. Si se consigue APK nueva, inspeccionar package/flavor/version/firma/SHA256 y adjuntar SOLO esa APK, nunca la vieja 245 MB. Si falla por recurso o dependencias, documentar causa exacta sin degradar datos ni instalar herramientas comerciales.

## 4. Entrega obligatoria: UN ZIP pequeño y relevo

Empaquetar exactamente **un** `PICORADAR_N5R5R1_RETORNO_UNICO.zip` con `FINAL_REPORT.md`, `GATES.csv`, `MANIFEST.csv` (tamaño, SHA-256, CRC32), logs resumidos y **solo evidencia nueva de N4/N5**; parche **INTEGRATED_BASE_TREE→FINAL_TREE** si hubo fixes, o `FINAL_TREE==INTEGRATED_BASE_TREE` si no. No volver a adjuntar el ZIP integrado, bundles ni la APK V5. APK nueva solamente si se compiló. Incluir evidencia de árbol y que WIP real se preservó, sin paths secretos, usuarios, emails reales, GPS, documentos o credenciales. Validar CRC/hash del único ZIP.

**Campos explícitos y sin plantillas sin interpolar**: `TASK_ID`, `SOURCE_RC2_COMMIT`, `SOURCE_N3_TREE` (si usado), `INTEGRATED_BASE_TREE`, `FINAL_TREE`, `DELTA_PATHS`, `PHP_FOCAL`, `FLUTTER_FOCAL`, `FLUTTER_ANALYZE`, `FORMAT`, `FIXTURES_6`, `MOBILE_GLOBAL`, `CDA_OTA`, `MODALITY_DISABLE`, `ACCOUNTS_OFF`, `ADS_OFF`, `CATALOGS_SERVER`, `BRIDGE`, `OTA_HTTPS_QA`, `APK_BUILD`, `APK_SHA256` si aplica, `WIP_PRESERVED`, `GITHUB_PRODUCT=HOLD_SECURITY`, `PRODUCT_RELEASE=NO_GO`, `NEXT_ACTOR=CHATGPT_DIRECTOR`. Estados admisibles `PASS`, `PASS_SCOPED`, `FAIL_CODE`, `PARTIAL_EXTERNAL_FIXTURES`, `NOT_RUN_ENV`, `BLOCKED_RESOURCE_GATE`; nunca inventar un PASS.

**CRITERIO DE SALIDA:** conseguir el árbol integrado exacto, pruebas causales del código nuevo y correcciones mínimas que permitan avanzar hacia release; cualquier bloqueo ambiental debe ser específico y no debe reabrir trabajos N3/V3/V4. No gastar tokens rehaciendo arquitectura, investigando todas las alcaldías o repitiendo auditores. Completar lo que sí corre y entregar el ZIP en esta sesión.

**TRABAJO POSTERIOR DEL DIRECTOR (NO HACER EN ESTE BLOQUE):** QA HTTPS y Android con dispositivo y firma válidos, seguridad de GitHub y publicación autorizada, ampliación editorial real por ciudad/departamento/municipio con fuente institucional, decisiones comerciales de cuentas/ads. No confundir catálogo geográfico de 1.104 localidades con todas sus normas verificadas.

# 🔴 SIGUE: CODEX LUNA — EJECUTAR N5-R5-R1. AL DEVOLVER EL ZIP: SIGUE CHATGPT DIRECTOR. 🔴