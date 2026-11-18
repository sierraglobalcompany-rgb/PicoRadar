# CODEX LUNA — PICORADAR · OTA QA R2 · EJECUCIÓN ÚNICA SIN PING-PONG

**TASK_ID:** `PICORADAR-V5R1-OTA-QA-R2-UNICO-20261116`  
**ESTADO:** orden nueva pendiente; **sustituye totalmente** `CODEX_LUNA_PICORADAR_CIERRE_OTA_QA_SIN_REPETIR_V5R1_20261116.md`. No repetir V5-R1 ni arrancar otro escritor.  
**RESPONSABLE:** Codex Luna implementa y comprueba en Windows; ChatGPT Director acepta el ZIP. El propietario autoriza por separado operaciones irreversibles, distribución y producción.

## OBJETIVO Y CRITERIO DE CIERRE

Cerrar en **un solo lote** el residuo real: (A) corregir preparación de los tres tests históricos, (B) comprobar si los errores 400 de tiles implican tráfico externo o intercepción del framework, y (C) obtener, **si es posible con un entorno QA aislado**, una prueba vertical de **artefactos publicados por Laravel → manifest + asset servidos por HTTP exclusivamente local → `DatasetSyncService` real → Drift → selector/motor y recuperación ante errores**. No crear motor ni APK por ciudad, no implementar un publicador paralelo, no instalar en Mi A3 y **no declarar release**.

**Prioridad:** un avance de producto demostrable, no otra ronda de auditorías o instalación de herramientas. Una prueba de HTTP local **no** es prueba de OTA HTTPS en el producto/Android.

### Baseline inmóvil y pruebas reutilizables

- Base código V4-R1: `24408f305f7a977cf30e426ce3925cca19f981ad`. Candidato V5-R1 (dos tests añadidos, sin cambios de producto): `10ab7af9d07ea6ea941ba54289c9c0455b6d1f70`, reconstruido exactamente en aislamiento por ChatGPT. HEAD Windows `182a8821bba688b28a6e223a1e956df748f7948b` **reportado local**, no remoto. No equiparar HEAD, índice y árbol de archivos.
- Custodia V5-R1: ZIP `PICORADAR_V5R1_APK_OTA_NACIONAL_RETORNO_UNICO.zip` SHA-256 `481fa5608e7ca2cf6966d4d4b72c982fcdfdb0552b42a09a6d90f951dc33532d`. APK DEV ya construida, `co.picoradar.app.dev`, `1.0.1+2`, SHA-256 `02d565db08f3779528e6f1c68de4cd75f1494b7c58ac6d46baf397f58f3c75d6`, **OTA desactivada por no existir CDN_BASE_URL**. No recompilar ni reenviar 245 MB si fuentes/configuración móvil no cambian.
- V4-R1: suite completa **3.347 PASS / 11 SKIP / 0 FAIL**, según logs del árbol V4. V5-R1: **175 focales PASS**, `flutter analyze PASS`; su corrida global fue **incompleta** (1.897 PASS, 10 SKIP, 3 FAIL_INPUT de evidencia ausente, no veredicto global final). **No convertir resultados de un árbol en otro.** No repetir suites ni las 15 migraciones/16 pruebas visuales que ya pasaron sin delta.
- Motor nacional existente `schemaVersion=2`: reglas habilitables por autoridad/departamento/municipio/ciudad/pueblo y modalidad, dígitos, paridad, días, festivos, ventanas y vigencia; clasificar falta de prueba como `UNKNOWN/STALE`, nunca circulación permitida. El catálogo geográfico no demuestra cobertura legal. LAB N1: 14 autoridades/33 códigos/22 coberturas parciales/120 reglas, no todas las normas de Colombia.
- Seguridad: `GITHUB_PRODUCT=HOLD_SECURITY`; **no push/merge de código producto, no publicar dataset LAB, no CDN/Hostinger/servicio real, no ADB, no borrar datos, no modificar firma ni exponer documentos personales**. Las seis leyes PingPongLaw L1–L6 y `AGENTS.md` aplican.

## F0. IDENTIDAD Y ÚNICO PRE-FLIGHT (breve)

1. Trabajar únicamente en el candidato aislado V5-R1, si no hay escritor concurrente. Una vez comprobar `git rev-parse HEAD`, `git status --porcelain=v1` y el **árbol efectivo de los archivos** con índice alterno temporal, sin tocar índice real ni WIP. Si ya coincide `10ab7af...`, continuar; si no, **no** aplicar un parche sobre otro árbol por intuición. Consultar el ZIP y la recuperación documentada antes de restaurar **solo en directorio nuevo**. El parche V5 tiene CRLF: si hace falta usar una copia temporal LF, nunca alterar el original.
2. Leer solamente `AGENTS.md`, contrato `README.md` relativo a PHP y las rutas focales abajo. No reinstalar skills, hooks, Flutter, Gradle o SDK; no `git clean`, `reset --hard`, cambios globales ni nueva auditoría 10×10.
3. Si el árbol difiere por trabajo nuevo de otro agente: `HOLD_CONCURRENT_WRITER`, no colisionar; continuar únicamente con inspección no invasiva y reportar la diferencia. **No adivinar** existencia o limpieza de `D:\codex` desde GitHub.

## F1. ELIMINAR LOS TRES `FAIL_INPUT` (sin tocar producto)

**Archivo real comprobado:** `mobile/test/core/sync/restriction_g2_same_bytes_test.dart`. La ruta antigua `mobile/test/features/pico_placa/data/restriction_g2_same_bytes_test.dart` **NO EXISTE**; no crearla. El test consulta estas variables en líneas cercanas a 46, 279 y 413:

- `PICORADAR_G2_V3_EVIDENCE_DIR`: archivos `PHP_G2_V3_REAL_LAB_RELEASE.json` y `PHP_G2_V3_REAL_LAB_MANIFEST.json`; release SHA `826e59877ee454102b01502cc2030ec0faae9d26196fab37f99a451f5d27d1f6`.
- `PICORADAR_V1_METADATA_LAB_DIR`: `V1_SCHEMA2_PHP_RELEASE.json` / `V1_SCHEMA2_PHP_MANIFEST.json`; release SHA `3b99adca0db33a1cd8bb179f3dd51c5737fa80ab0b6f360f2dd110c8809ed362`.
- `PICORADAR_G34_LAB_EVIDENCE_DIR`: usar nombres **exactos que el test exige**, comprobando el archivo y hash original G34 antes de extraer; release SHA `04e339bbcbcc7b9263f3b52a53d72726f45969b676fb9c05000dd2c62b63eadf`.

Los miembros auténticos ya se recuperaron en V4-R1, según `logs/historical_inputs_sanitized.log` del ZIP V4-R1. **No son fuentes jurídicas nuevas; son fixtures históricos de regresión.** Una sola búsqueda en las rutas de reportes ya conocidas y ZIPs históricos. Comprobar SHA de fuente y vínculo manifest/release. **Copiar los miembros a tres directorios temporales NUEVOS:** ese test genera `FLUTTER_SAME_BYTES_IMPORT_RESULT.md` dentro del directorio de evidencia, así que **nunca apuntar las variables a originales inmutables ni a archivos dentro de otros trabajos**. Las tres variables apuntan a esas copias QA.

Ejecutar **una vez solo ese archivo de tests**, con Flutter/Dart y lockfile actuales, registrar exit y casos. Si falta un artefacto auténtico después de la búsqueda acotada: `HISTORICAL_3=FAIL_INPUT`, sin inventar sustitutos ni quitar aserciones, y continuar F2. No repetir las 3.347 pruebas de V4 por protocolo.

## F2. TILES Y RED: DEMOSTRAR ANTES DE CORREGIR

El log V5 indica respuestas HTTP 400 sobre URLs `tile.openstreetmap.org`, **no prueba por sí solo tráfico real a Internet**: `flutter_test` puede interceptar `HttpClient`. Identificar el test/harness exacto y comprobar mediante logs/overrides si hubo salida externa. Si la intercepción ya previene tráfico: `TILES=INTERCEPTED_SAFE`, sin cambiar nada. Si realmente hay salida: reutilizar fake/override HTTP **solo en el harness**, con respuesta determinista y cero tráfico público; una prueba focal RED→GREEN. No alterar provider, URL, API ni mapas de producto. Si el aislamiento no puede garantizarse, detener **solamente el test afectado** y registrar `TILES=UNSAFE_UNRESOLVED`; no atribuir automáticamente fallos del motor.

No ejecutar suite global por inercia. Solo si se cambia infraestructura de test compartida o código de producto, realizar **una suite global final** cuando las precondiciones estén satisfechas; si no, consignar explícitamente `FULL_QA=V4_PASS_REUSED+V5_FOCAL_PASS+F1_STATUS`, **no** declarar `FULL_QA_V5=PASS` sin corrida completa en ese árbol.

## F3. PUBLICACIÓN → DESCARGA → DRIFT: UNA PRUEBA VERTICAL

### Una sola elección de entorno QA gratuito

- Preferencia: PHP/Composer actuales con `pdo_sqlite/sqlite3` activos o activables desde binarios **ya instalados**, con SQLite en archivo temporal propio. Alternativa: MariaDB QA **ya instalado y configurable sin alterar datadir ajeno**, según `README.md`. **Máximo una vía de reparación ambiental razonable**; no bucle entre PHP portátil, Docker, MariaDB, ediciones `.env` y reintentos. No descargar o instalar PHP/DB por rutina ni modificar PATH global. Si ninguna opción es viable, registrar causa exacta (`QA_DB=NOT_AVAILABLE` y qué extensión/base falta) y avanzar a F4; ninguna simulación debe llamarse E2E Laravel.
- En entorno disponible, crear usuario/base/archivos **sintéticos y efímeros**; `APP_ENV=testing`, clave efímera, Storage QA separado, HTTPS externo **no requerido para esta prueba de transporte local**, cero cuentas, placas, documentos y secretos reales. Mantener autorización editorial vigente; dos roles/personas sintéticas distintas cuando el validador exija revisión independiente. No desactivar los gates de publicación para fabricar un PASS.

### Reutilización exacta: no otro motor ni publicador

Reutilizar `server/app/Services/RestrictionPublicationService.php`, `DatasetPublisher.php`, `DatasetReleaseValidator.php`, `server/tests/Feature/RestrictionPublicationServiceTest.php`, `DatasetPublisherTest.php`, y del cliente `mobile/lib/core/sync/dataset_sync_service.dart`, `mobile/lib/app/app_providers.dart`, `mobile/test/core/sync/dataset_sync_service_test.dart`, `mobile/test/app/dataset_sync_composition_test.dart`, `mobile/test/app/restriction_availability_providers_test.dart`, `mobile/test/features/pico_placa/domain/restriction_national_data_driven_test.dart`. Extender **solo el test existente más próximo** o agregar un test único de integración si hace falta; no duplicar suites ni inventar endpoints.

1. Con Laravel REAL en QA, producir artefactos publicados de un dataset `schemaVersion=2` **sintético** por las clases existentes. Dos jurisdicciones ficticias A/B con códigos válidos de prueba: A v1 habilitada → v2 deshabilitada → v3 habilitada con otros dígitos, días/ventanas; B debe permanecer intacta. Cada revisión publicada usa **snapshot completo A+B**, versión/revisión nueva y hash SHA-256 real. Revisiones/validaciones editoriales se respetan: si el flujo de aprobación de schema2 bloquea un caso material sin fuente admisible, **no** falsear una autorización oficial; usar el patrón de fixtures de test aceptado o registrar ese gate pendiente con su causa.
2. Servir por HTTP **loopback aislado** los bytes que Laravel generó realmente (manifest + asset), no JSON escrito manualmente que se haga pasar por publicación. Puede ser un servidor temporal de archivos con los artefactos exactos publicados, si no existe ruta Laravel HTTP QA utilizable; etiquetar la procedencia: `LARAVEL_GENERATED_ASSET_OVER_LOCAL_HTTP` no equivale a despliegue Laravel/CDN real. Verificar byte hash y misma revisión.
3. El transporte debe pasar por **`DatasetSyncService.sync()` real con `AppConfig` de laboratorio inyectada directamente**, no por importación manual a Drift ni por mocks que devuelvan datos ya importados. `AppConfig` permite HTTP para tests; **`datasetSyncServiceProvider` de producto invoca `_validateProductDatasetConfig` y EXIGE HTTPS y origen del manifest igual al CDN**. No modificar ni hacer bypass del provider productivo para permitir HTTP. En F3 se prueba SOLO transporte de laboratorio. Mantener las pruebas negativas de configuración productiva (`HTTP` y origen distinto rechazados).
4. Aserciones causales: importar A+B; seleccionar/consultar A y B; cambiar A habilitada→deshabilitada→habilitada y variar últimos dígitos/días/horarios **solo por archivos publicados**, sin cambiar Dart/engine/APK; persistencia de versión en Drift al reabrir; Garaje/vehículos/notificaciones sintéticas conservados; ciudad nueva que no esté en las 73 editoriales pero figure en el catálogo geográfico; ausencia o caducidad explícita = `UNKNOWN/STALE`, nunca `ALLOWED`. No marcar `coverageCompleteness=complete` sin certificación espacial/legal.
5. Prueba negativa de SHA de asset y/o manifest alterado: rechazar actualización y conservar última versión válida y las filas del usuario. Cubrir ETag/304 solo si el servidor QA realmente lo emite; no fabricar su resultado. Evitar capturas/exports con placas o datos reales.
6. Registrar la **matriz de pruebas por eslabón**: publicación Laravel de revisión (real o NOT_RUN), bytes/SHA (real o NOT_RUN), transporte HTTP local (real o NOT_RUN), importación Drift y reversión (real o NOT_RUN), selector/cálculo (real o NOT_RUN), configuración de OTA **HTTPS de producto** (NOT_RUN salvo un origen HTTPS autorizado y certificado). Una prueba de `DatasetSyncService` en HTTP local **no certifica** OTA dentro de la APK actual, que sigue `DISABLED_NO_CDN`.

Si se reproduce un defecto real, corregir solo causa e integrar tests mínimos, sin rediseñar motor. Con cambio de producto ejecutar focales + `flutter analyze`; suite global una vez si es pertinente por riesgo. Con cambio Dart/Android recompilar APK DEV del **árbol final** con receta Kotlin de `README.md`; si no hay cambio de producto, no recompilar ni adjuntar la APK anterior.

## F4. CIERRE, EVIDENCIA Y LÍMITES

**Un solo ZIP pequeño y verificable**, con `FINAL_REPORT.md`, `GATES.csv`, registro compacto de comandos/exits/versiones/árbol, manifiesto por archivo con tamaño y SHA-256 (y CRC si aplica), datos **sintéticos mínimos de integración** sin secretos, y parche recuperable **solo si cambia el código/tests**. No adjuntar bundle RC2 ni APK vieja de 245 MB. El ZIP contiene la APK nueva solo si fue necesario recompilar y el build pasó. Evitar decenas de logs repetidos; sanear rutas sensibles, tokens, placas, identificaciones.

No hacer push de producto mientras `HOLD_SECURITY` esté pendiente; ChatGPT Director mantiene el **Plan Maestro y este prompt** en el PR documental #79. No abrir otro PR, no ampliar trabajo a datos nacionales sin fuente vigente. Publicación oficial en alcaldía/gobernación sirve para los **campos expresos** incluso sin PDF de decreto; ninguna fuente ausente permite inventar exenciones o declarar vía libre.

**NO se consideran implementados por este lote:** sincronización HTTPS en una APK real, instalación/UAT física, firma release, saneamiento de GitHub, registro opcional y panel/exportaciones con consentimiento, CDA/SOAT/aliados/publicidad. Quedan en backlog de cierre del producto, no se ocultan ni se mezclan con OTA QA. La app sigue funcionando sin cuenta. Placas, fotos de matrículas, cédulas, contratos y demás documentos quedan local-only.

### GATES sin engañar el resultado

```text
TASK_ID=PICORADAR-V5R1-OTA-QA-R2-UNICO-20261116
BASE_V5_TREE=10ab7af9d07ea6ea941ba54289c9c0455b6d1f70
FINAL_TREE=<SHA real del árbol, con método>|NOT_VERIFIED
HISTORICAL_3=PASS|FAIL_INPUT|NOT_RUN_ENV
TILES=INTERCEPTED_SAFE|OUTBOUND_FIXED|UNSAFE_UNRESOLVED|NOT_VERIFIED
QA_DB=READY|NOT_AVAILABLE
LARAVEL_PUBLICATION=PASS_SYNTHETIC_QA|FAIL|NOT_RUN_ENV
LARAVEL_ARTIFACT_SHA=PASS|FAIL|NOT_RUN_ENV
HTTP_LOCAL_REAL_BYTES=PASS|FAIL|NOT_RUN_ENV
DRIFT_SYNC_LAST_GOOD=PASS|FAIL|NOT_RUN_ENV
NATIONAL_SWITCH_A_B=PASS_SCOPED|FAIL|NOT_RUN_ENV
OTA_PRODUCT_HTTPS=PASS_AUTHORIZED_ONLY|NOT_RUN_ENV
FULL_QA=PASS_FINAL_TREE|REUSED_PRIOR_PLUS_FOCAL_NOT_GLOBAL|FAIL|NOT_RUN
APK=REUSED_V5_OFFLINE|NEW_DEV_DELIVERED|NEW_DEV_FAILED
ANDROID=NOT_INSTALLED_SAFE
GITHUB_PRODUCT=HOLD_SECURITY
RELEASE=NO_GO
NEXT_ACTOR=CHATGPT_DIRECTOR
```

**Éxito del bloque**: una sola entrega que permita al Director decidir qué está demostrado y qué infraestructura de publicación real falta. Si QA DB no existe, **NO** crear un segundo prompt de preflight: entregar diagnóstico específico y el trabajo independiente concluido. Al terminar: `SIGUE: CHATGPT DIRECTOR` y ZIP único.