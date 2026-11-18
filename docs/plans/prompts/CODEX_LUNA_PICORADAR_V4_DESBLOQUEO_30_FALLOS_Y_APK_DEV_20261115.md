# CODEX LUNA — PICORADAR V4 · RESOLUCIÓN DE 30 FALLOS AGRUPADOS + APK DEV · UN SOLO MACROBLOQUE

**TASK_ID:** `PICORADAR-N1-V4-CLOSE-FAILURE-CLUSTERS-OTA-APK-20261115`  
**ACTOR:** CODEX LUNA (manos), bajo dirección de ChatGPT Director.  
**ORDEN ACTIVA:** ESTA V4 sustituye SOLO la siguiente orden operativa posterior al V3 ya ejecutado; **NO** volver a ejecutar V3, N1-R1, V6R4, RC2 ni auditorías previas.  
**PROPÓSITO:** quitar los bloqueos concretos del código V3, cerrar QA móvil real en lo que sea posible, ejercitar OTA sin datos de producción y **entregar una APK DEV si el build es técnicamente viable**. Evitar diez rondas de preflight: un solo lote resolutivo, un único ZIP final.  
**NO CONFUNDIR:** una APK DEV compilada no es un release aprobado ni prueba física. No publicar, instalar sobre el Mi A3, hacer merge o subir código mientras `HOLD_SECURITY` no esté resuelto y los gates pertinentes no estén aprobados.

## 0. ESTADO V3 CONFIRMADO POR AUDITORÍA DEL DIRECTOR — NO VOLVER A AUDITARLO

- ZIP recibido `PICORADAR_N1_V3_CIERRE_VERTICAL_EVIDENCIA_UNICA.zip`: **96.141 bytes**, SHA-256 `6f7cd6de923c0e4fbbab751afc39b71ae1d34f03e987bbaebfd3144ae80324d0`; CRC PASS; 14 entradas; manifiesto 13/13 SHA/tamaño/CRC PASS.
- Árbol producto **reconstruido directamente** del bundle RC2 + parche V3: `829f202b27348c93d354acc4658e9fc0f7e939a8` EXACTO; base RC2 `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`. Parche de V3 SHA-256 `01207d5bdcf62a3c12928de1400af4177f9e0eff204ef7f92a8d3b2234970c27`. Commit local Windows `c38141fb5043ce87b0cf7974ec7c1855004d440e` es **REPORTADO**, no recuperado por reconstrucción ni visible en GitHub; no exigir que el SHA del commit sea idéntico cuando el TREE sí coincide.
- V3 vs N1: 15 rutas delta, no un motor nuevo. Viaje pasó **3/3** pruebas de ancla; Drift focal **3/3**; presentación Pico **68/68**; `flutter analyze` PASS; 405 Dart rastreados `dart format` PASS; N1 focal 221 PASS y una falla por evidencia R2 ausente; OTA Cliente 15 PASS + 3 fallas por evidencia histórica; PHP 13/37 **reutilizado de N1 sin modificar código PHP**. **No repetir estos PASS por protocolo si no cambia el contrato cubierto.**
- Suite móvil V3 **3315 PASS / 13 SKIP / 30 FAIL**; `APK_BUILT=NO`, `OTA_E2E=NOT_RUN_ENV`; `PRODUCT_RELEASE=NO_GO`. Los 30 fallos están identificados abajo; no mandar otra auditoría ni correr de inmediato las 3315 pruebas ya aprobadas.
- V3 contiene datos Cartagena carro `validUntil` hasta **2027-01-22** sustentados por publicación oficial de la Alcaldía/DATT de octubre; se mantiene `coverageCompleteness=partial` y `staleAfter=2026-11-19` para revisión. **No** activar la temporada 24 horas sin confirmación editorial posterior inequívoca. No tocar cifras/horarios de datos LAB para pasar tests.
- Documentación GitHub: PR #79 Draft no es código publicado. Producto V3 no está remoto por `HOLD_SECURITY`. Se puede documentar un resultado; no subir el bundle privado, no hacer push inseguro ni aseverar CI remoto.

## 1. PRECONDICIÓN ÚNICA, EN MENOS DE UN RECORRIDO

**Candidato reportado:** `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`, rama reportada `feat/picoradar-n1-schema2-cartagena-lab`. Sin escritor concurrente. Antes de editar, ejecutar **una vez**: `git status --short`, `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git diff --check`, versión `flutter --version`, disponibilidad del `mobile/.dart_tool/package_config.json`. Comparar TREE con `829f202b27348c93d354acc4658e9fc0f7e939a8`; si hay WIP de otra persona o árbol distinto, **no borrar, resetear, limpiar, crear branch sobre WIP ni sobrescribir**: conservar evidencia, salir `TREE_CONFLICT` y regresar control al Director. Si el commit V3 reportado existe con ese TREE, usarlo sin restaurar nada.

**Recuperación SOLO si el árbol está ausente:** base RC2 exacta del ZIP de continuidad ya entregado + `RECOVERY/RC2_TO_FINAL.patch` del ZIP V3, en **clon aislado nuevo**; `git apply --check`, `git apply`, `git add -A`, `git write-tree` igual al SHA V3. No tocar el checkout original ni pedir otro bundle de 85 MB.

Leer `AGENTS.md` y aplicar **seis leyes PingPongLaw (L1 KISS, L2 Antirruido, L3 Antiparches, L4 Diseño humano, L5 Verificación, L6 Antipingpong)** sin instalar skills, agentes o hooks por ritual. No agregar dependencias, motor por ciudad, capa nueva, scripts duplicados, QA artificial ni cambios legales para forzar PASS.

**Entorno:** Flutter 3.47.9 / Dart 3.13.7 ya estuvo disponible en V3. `flutter pub get --offline` falló por symlinks de Windows, pero `flutter test` y `flutter analyze` corrieron. **No cambiar Developer Mode, antivirus, sistema, enlaces globales o `pubspec.lock` sin permiso.** Si el `package_config` existente funciona, priorizar pruebas y `flutter build apk --debug --no-pub` cuando aplique; si no es viable, `BUILD_ENV_BLOCKED` con comando y error, no otro ciclo de cinco preflights.

## 2. ÚNICA MATRIZ DE LOS 30 FALLOS — ATACAR CAUSAS, NO TESTS EN SERIE

**Grupo A — 6 migraciones históricas (riesgo real P0 de datos):**
- `mobile/test/core/database/alert_settings_migration_test.dart` (1).
- `mobile/test/core/database/app_database_test.dart` (2: v1 y v2).
- `mobile/test/core/database/wallet_migration_test.dart` (1).
- `mobile/test/core/database/wallet_preparation_migration_test.dart` (2: v6 y v7).
- **Evidencia V3:** `SqliteException: no such table restriction_coverages` o `duplicate column name coverage_completeness`, con instrucción `ALTER TABLE ... ADD COLUMN` de `mobile/lib/core/database/app_database.dart` en la transición v9→v10. La app ya declara **schemaVersion 11**. Antes de tocar runtime, comparar **los SQL históricos reales** y fixtures artificiales de cada prueba con la cadena `_upgrade` v1→11. Cuando el fixture use versión marcada pero carezca de tablas que esa versión real ya tenía, **completar el fixture con el esquema real**, no alterar producción para aprobar un fixture inválido. Si se comprueba una migración real afectada, corregir **la causa mínima en el migrador** y añadir prueba de preservación de vehículos, obligaciones, notificaciones y documentos, incluyendo `PRAGMA user_version=11` y `PRAGMA foreign_key_check`. No silenciar SQLite, ignorar errores, bajar versión o perder datos. Probar **solo estos cuatro archivos** primero; un arreglo compartido para seis fallos.

**Grupo B — 6 pruebas dependientes de evidencia histórica exacta (P0 de inputs, NO bug certificado):**
- `mobile/test/core/sync/restriction_g2_same_bytes_test.dart` **3**: variables `PICORADAR_G2_V3_EVIDENCE_DIR`, `PICORADAR_V1_METADATA_LAB_DIR`, `PICORADAR_G34_LAB_EVIDENCE_DIR`.
- `mobile/test/features/pico_placa/data/g1_laravel_flutter_same_bytes_test.dart` **1**: G1 + R2.
- `mobile/test/features/pico_placa/data/restriction_g2_r2_schema1_regression_test.dart` **1**: `PICORADAR_G2_R2_RELEASE` y SHA histórico explícito.
- `mobile/test/features/pico_placa/data/restriction_g2_schema_test.dart` **1**: test mixto R2/schema2 con `expect(releasePath, isNotNull)`.
- Buscar **solo una vez** artefactos auténticos en `D:\codex\_REPORTES\PicoRadar`, carpetas de evidencia conocidas G1/G2/G34/R2 y ZIPs históricos que estén presentes; comprobar ruta real, archivos internos y SHA original del test. Si una prueba usa `Platform.environment` darle variables de entorno del proceso; si usa `String.fromEnvironment`, usar `--dart-define` correcto. **Prohibido crear falso R2, cambiar hash esperado, hacer skip oculto o sustituir por datos LAB N1.** Ejecutar la selección solo cuando existan sus inputs. Si no se encuentra el artefacto exacto tras esa búsqueda acotada, dejar **`INPUT_MISSING_VERIFIED`**, preservar los tests y detallar por nombre+hash qué adjunto se necesitaría: avanzar con grupos independientes y el build DEV sin declarar `flutter test` global PASS.

**Grupo C — 16 pruebas visuales Viaje con mismo síntoma:**
- `mobile/test/features/trip/presentation/trip_visual_evidence_test.dart`, **16 `pumpAndSettle timed out`** desde helper `_pumpScreen` línea aproximada 427. V3 NO prueba 16 defects del motor: todos comparten un helper de prueba que espera estabilización de frames.
- Reproducir primero **un solo caso** con traza limitada del scheduler/provider/animación pendiente. Revisar `AppShell`, `TripScreen`, el harness, tiempo mock/fake, streams y `AppDatabase` / Riverpod en `test`. Identificar el productor de frames antes de tocar código. **Una corrección focal del harness o del consumidor, según causa demostrada**, y ejecutar el archivo completo una vez. No aumentar `pumpAndSettle` a ciegas, no ocultar excepciones, no deshabilitar 16 asserts ni retirar capturas/referencias aprobadas. Si el test necesita evidencias/font/íconos, usar los `--dart-define` presentes en el propio test, sin inventar recurso. Documentar si el bucle es solo de pruebas o de UI real.

**Grupo D — 2 fallos independientes pequeños:**
- `mobile/test/features/pico_placa/data/four_city_consumption_audit_test.dart`: `Binding has not yet been initialized` al cargar asset del catálogo por `PlatformAssetBundle`/`picoJurisdictionCatalogProvider`; inicializar el `TestWidgetsFlutterBinding` en el punto correcto del test, **sin** modificar runtime por conveniencia.
- `mobile/test/features/settings/presentation/settings_screen_test.dart`: diagnóstico espera `schemaVersion=9` mientras la BD real dice `schemaVersion=11`. Actualizar **solo la expectativa desactualizada** si coincide con `AppDatabase.currentSchemaVersion`, conservando prueba de **cero PII** en el contenido copiado; no cambiar la versión de producción.

**Total: 6 + 6 + 16 + 2 = 30.** No crear más de cuatro ramas de investigación. Si una prueba revela falla de seguridad o pérdida real, dar prioridad a esa causa y registrar impacto; no priorizar el contador artificial de tests.

## 3. SECUENCIA EFICIENTE DE EJECUCIÓN (MISMO MACROBLOQUE)

**Paso 1 — Reparación causal focal:** Ejecutar SOLO los archivos fallidos de A, C y D, agrupados por causa. Hacer 1 diagnóstico y 1 arreglo integrador por causa, con regresión de éxito/error. No ejecutar las 3315 aprobadas mientras todavía haya fallos focales conocidos. No tocar PHP/Python, 14 jurisdicciones, 33 códigos, 22 parciales y 120 reglas salvo corrección material justificada.

**Paso 2 — Evidencia exacta B:** Localizar una vez, verificar hashes y correr los 6 tests de entrada solo si disponemos de los artefactos reales. Si falta entrada histórica, mantenerla sin modificar y consignar `NOT_RUN_INPUT`; NO confundirla con fallo de motor. Confirmar que el motor `schemaVersion=2` y ventanas fullDay, Viaje y `NO_FALSE_ALLOWED` continúan seguros **mediante sus tests existentes** solo si el nuevo delta afectó dichos contratos.

**Paso 3 — Prueba global de cumplimiento:** `dart format --output=none --set-exit-if-changed` para rutas rastreadas afectadas; para el recorrido raíz, no recorrer `mobile/build` ignorado/dangling que produjo un error artificial en V3; anotar equivalencia o el límite sin borrar archivos WIP. `flutter analyze` y **UNA** ejecución nueva de `flutter test` global después de resolver los grupos A/C/D y montar los inputs B que realmente existan. Obtener resumen con SHA/TREE, **PASS/FAIL/SKIP/INPUT_HOLD**; no falsificar la regla de `AGENTS.md` de QA global. Con árbol nuevo, los resultados V3 no se trasladan automáticamente a rutas tocadas; revalidar delta y críticos.

**Paso 4 — OTA real, solo ambiente QA aislado:** El servidor Laravel y el cliente ya tienen `RestrictionPublicationService`, publicador/manifest SHA y `DatasetSyncService`; NO crear segundo servicio/panel/editor. Si existe servidor QA limpio y configuración permitida, activar un solo recorrido test real: **fuente oficial aprobada → snapshot COMPLETO por autoridades → manifest/revisión/hash → cliente/Drift → resultado motor → reabrir app → SHA incorrecto/rollback/last-good → no falsa autorización en localidad sin cobertura**. Usar `PICORADAR_B07_BASE_URL` solo si es realmente server QA; no producción, Hostinger, credenciales ni usuarios reales. Si no existe QA ejecutable, crear un entorno temporal local **solo si se dispone ya de las dependencias gratis** y sin impactos externos; de lo contrario `OTA_E2E=NOT_RUN_ENV` y continuar al build DEV. No presentar los PHP 13/37 reusados como E2E.

**Paso 5 — APK DEV PRODUCTIVA EN CÓDIGO, NO RELEASE:** La compilación **no depende** de que los seis archivos históricos de R2/G1/G2/G34 estén presentes si los tests de seguridad y compatibilidad de código actual sí pasaron. Con `flutter analyze` y pruebas críticas focales verdes, **INTENTAR una vez** `flutter build apk --debug --no-pub` desde `mobile`, en candidato aislado, sin modificar firma ni `versionCode` para forzar instalación. Si hay fallo por plugin/symlink/Gradle, un único diagnóstico y reparación mecánica **local, segura, sin permisos globales**; si persiste, `APK_BUILD=NOT_RUN_ENV|FAIL` con error real. Si compila, verificar `aapt`/`apksigner` cuando disponibles, paquete/versionCode/firma, SHA256, tamaño, **INCLUIR APK BINARIA en el ZIP único de retorno**; clasificar claramente `DEV_BUILD_ONLY / NOT_RELEASED` cuando suite global o OTA física no hayan cerrado. **No instalar Mi A3** en este lote si queda QA de migraciones, firma, compatibilidad o autorización pendiente; NO `adb uninstall`, `pm clear`, borrar vehículos ni exportar datos personales. Android físico posterior sobre APK exacta, según controles previos.

**Paso 6 — Seguridad/GitHub:** No modificar código remoto ni `main` mientras `HOLD_SECURITY` continúe. Un escaneo del **diff V4** evita introducir secretos nuevos, pero **no resuelve por sí mismo** el historial afectado; registrar evidencia exacta de la causa pendiente y el camino seguro para solucionarla, sin reportar un issue inexistente como cierre. No `push`, PR nuevo, merge, publicar bundle privado, desplegar o generar APK release firmada con debug por reflejo. Conservar código V4 recuperable para futura sincronización segura. El avance documental PR79 puede actualizarlo el Director sin mezclarlo con producto.

## 4. INVARIANTES DEL PRODUCTO (NO CAMBIARLOS PARA PASAR QA)

- Un **solo** motor nacional Flutter+Laravel por `schemaVersion=2`, alimentado por archivos oficiales actualizables por autoridad/departamento/municipio/ciudad/pueblo/modalidad/condición, con habilitar/deshabilitar, dígitos, par/impar, días, festivos, horarios, vigencia, zonas/exenciones evidenciadas. El cambio ordinario es **datos del servidor + OTA**, no APK ni motor por ciudad.
- `UNKNOWN/STALE` cuando jurisdicción, modalidad, fuente, vigencia, ámbito o excepción no estén demostrados. **No** cambiar `coverageCompleteness` de partial a complete para eliminar hold.
- Vehículos identificables, placas, fotos de matrículas, cédulas, contratos y documentos privados **permanecen locales**; ninguna placa o GPS en ZIP/log/telemetría. Conservación garantizada en migraciones.
- Registro opcional de usuarios, consentimientos, módulo admin de clientes, categorías vehiculares agregadas, emails/exportación, CDA, SOAT, aliados y publicidad **son alcance pendiente del producto**, previamente inventariado en `PICORADAR_AUDITORIA_ARQUITECTURA_NACIONAL_DATOS_USUARIOS_ADMIN_20261115.md`; **no construir todo eso durante V4** ni declarar producto 100 % final al compilar APK. Respetar Free 1.0 y publicidad OFF según `AGENTS.md` salvo decisión posterior expresa.
- Publicaciones oficiales de alcaldía/gobernación/secretaría bastan para los campos expresos aunque no se adjunte PDF de decreto; no inventar jurisdicción, ámbito, exenciones ni temporada Cartagena 24h.

## 5. CRITERIOS DE SALIDA — UN SOLO RETORNO, NO OTRO PREFLIGHT

La salida real debe registrar **por árbol final**:

```
TASK_ID=PICORADAR-N1-V4-CLOSE-FAILURE-CLUSTERS-OTA-APK-20261115
V3_BASE_TREE=829f202b27348c93d354acc4658e9fc0f7e939a8
FINAL_HEAD=<SHA real local o NOT_COMMITTED>
FINAL_TREE=<SHA real de git write-tree>
MIGRATION_SIX=PASS|FAIL|HOLD
HISTORICAL_INPUT_SIX=PASS|INPUT_MISSING_VERIFIED|FAIL
TRIP_VISUAL_16=PASS|FAIL|HOLD
BINDING_SETTINGS_TWO=PASS|FAIL
DART_CRITICAL=PASS_SCOPED|FAIL|NOT_RUN_ENV
FLUTTER_ANALYZE=PASS|FAIL
MOBILE_FULL_QA=PASS_<num_tests>_SKIP_<num>|FAIL_<num>|INPUT_HOLD
OTA_SERVER=PASS_SCOPED_REUSED|FAIL_IF_CHANGED
OTA_E2E=PASS_LAB|FAIL|NOT_RUN_ENV
APK_BUILD=PASS|FAIL|NOT_RUN_ENV
APK_DELIVERED=YES|NO
ANDROID=NOT_INSTALLED_SAFE|PASS_IF_AUTHORIZED_AFTER_ALL_GATES
GITHUB_PRODUCT=HOLD_SECURITY|SAFE_TO_PUSH_SUBJECT_TO_AUTHORIZATION
PRODUCT_RELEASE=NO_GO
NEXT_ACTOR=CHATGPT_DIRECTOR
```

**Entrega física obligatoria:** **UN SOLO ARCHIVO ZIP** dentro de `D:\codex\_REPORTES\PicoRadar\<TASK_ID>\delivery\` que contenga: (1) `FINAL_REPORT.md` (hallazgos por cuatro grupos, qué se corrigió y por qué); (2) `GATES.csv` resumido con comandos/exit/árbol; (3) `MANIFEST_SHA256.csv` y CRC verificados; (4) logs **focales** de errores/soluciones, más resumen final de global QA; (5) `RECOVERY/RC2_TO_FINAL.patch` reproducible sobre RC2 con TREE final y SHA del parche; (6) **APK DEV binaria dentro del mismo ZIP** solo si la compilación realmente pasó, con SHA/firma/versionCode y clara etiqueta NO_RELEASE. No incluir bundle RC2 duplicado, APK antigua, secretos, DB real, placas, fotos, identificadores personales, dumps completos innecesarios o 20 archivos dispersos. Comprobar `ZIP testzip/CRC` y manifiesto SHA; devolver **un único enlace de Windows y SHA256 del ZIP**. No hacer otro ZIP de protocolo si el mismo cumple.

**Regla de parada:** ante conflicto de worktree, peligro real de pérdida de datos o permisos inseguros, **detener solo acción peligrosa**, completar las independientes y devolver el ZIP con estados honestos. No quedarse bloqueado por falta de 6 evidencias históricas si la APK DEV se puede compilar con gates críticos seguros. No redefinir los requisitos ya acordados, no declarar PASS sobre pruebas no corridas, no solicitar permiso para errores mecánicos triviales y no generar otro plan maestro.

**LEY FINAL:** código real + regresión válida + APK DEV físicamente recuperable si es posible. **CERO pingpong, CERO motor por ciudad, CERO release ficticio.**
