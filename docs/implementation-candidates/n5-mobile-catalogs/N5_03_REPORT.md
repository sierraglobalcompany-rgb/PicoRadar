# PicoRadar — Director N5/03: consumo OTA de CDA, geografía CDA y aseguradoras

**Corte:** 18 de noviembre de 2026, Colombia. **Estado:** `CODE_READY_STATIC_ONLY` / `PRODUCT_RELEASE=NO_GO`.

## Cambio de producto

Se conectaron los tres catálogos que N5/02 validó/publicó en Laravel al `DatasetSyncService` existente del cliente Flutter. El almacenamiento es **un único adaptador genérico** `PublishedCatalogStore<T>` (no un sincronizador por catálogo ni motor por ciudad), que usa el registro Drift `dataset_versions` actual y archivos por SHA-256 en el directorio privado de soporte de la aplicación. Los proveedores de CDA y aseguradoras leen la versión instalada verificada o, si falta CDN/archivo íntegro, mantienen el asset original. Los proveedores se invalidan solo tras una importación confirmada. No se tocan vehículos, matrículas, documentos, GPS ni N4-R2.

**Contratos:** `cda_catalog`, `cda_geography`, `insurance_directory` (schemaVersion 1, payload con `datasetKey`/`version`/`generatedAt`). Laravel N5/02 prepara/publica el manifest, el cliente N5/03 consume las mismas claves mediante el protocolo ya existente; URLs solo del mismo origen permitido y TLS de producción intactos. Los tres catálogos siguen siendo independientes del motor nacional de restricciones.

**Seguridad/consistencia:** el servicio principal descarga y verifica SHA-256 y metadatos; el nuevo adaptador verifica nuevamente los bytes antes de preparar el snapshot, los decodifica con el parser de cada módulo y publica archivos inmutables por hash. La transacción de `dataset_versions` determina qué archivo está vigente; un fallo mantiene la versión anterior. Un archivo corrupto hace fallback al asset empaquetado, y se añadió reparación atómica al reimportar el hash aprobado. La respuesta 304 ahora comprueba los datasets realmente presentes en el último manifest guardado, evitando repetir descargas por catálogos opcionales que nunca fueron publicados.

## Integridad de recuperación

- **Base exigida N5/02:** `f8e1305624c664e8d02856eb853f7f366d365711`.
- **Árbol N5/03 reconstruido por Git:** `8060cc1211344bc71c51c74fa6979215f38579b2`.
- **Parche:** `N5_02_TO_N5_03_CATALOG_OTA_FLUTTER.patch` (solo siete archivos Dart/tests).
- **SHA-256 del parche:** `a7c0f0b6b1d632115b647d52e0181da6b3446fe5a2f64faf39073a82c4d7ac6f`.
- `git diff --check=PASS`; `git apply --cached --check=PASS`, recreación exacta de árbol `PASS` desde copia nueva. Chequeo estático de 51 imports relativos `PASS`. No se repitieron los 25 smoke PHP N5/02 ni tests históricos cerrados.
- Assets reales inspeccionados: 964 CDA, 866 sitios geográficos, 16 aseguradoras; IDs sin duplicación; metadatos sintéticos para verificar contrato de schema1: `PASS` en Python.

## Pruebas añadidas PERO NO ejecutadas en Dart

Archivo `mobile/test/app/mobile_catalog_ota_test.dart` contempla lectura de los tres bundles sin CDN, HTTP de QA simulado (sin red pública) y manifest con SHA, invalidez de proveedor, persistencia offline, 304 sin recargas, SHA fraudulento y recuperación de un archivo local adulterado. Se actualizó **una** aserción de composición existente para incluir los tres importadores. Las pruebas Laravel N5/02 ya estaban redactadas pero **siguen no ejecutadas en este entorno** por ausencia de sus dependencias.

**No hay SDK Flutter/Dart en este entorno.** Por tanto `dart format`, `flutter analyze`, tests Flutter, APK compilada, QA física, HTTP/HTTPS E2E de dispositivo y publicación están `NOT_RUN_ENV`. No declarar `OTA_PRODUCT_PASS`, `ANDROID_PASS` ni `RELEASE_GO` hasta que se ejecuten realmente. La APK V5 existente NO contiene este nuevo código y tampoco tiene CDN configurado; hará falta **una nueva compilación** tras integrar y probar N5/03.

## Aplicación segura sin Codex

Aplicar el parche solo cuando el checkout tenga exactamente el árbol base N5/02 y el trabajo incompleto N4 esté preservado fuera de ese índice. Si N4 altera uno de estos siete archivos, comparar los hunks y resolver **solo ese solapamiento**, sin `git reset --hard`, sobrescritura ni merge automático. Con Flutter disponible ejecutar el test nuevo y su test de composición, análisis/format y la única suite global requerida tras este cambio Dart; compilar APK DEV con HTTPS/CDN de QA solo si existe un endpoint confiable. No subir el repositorio privado antiguo ni información sensible a GitHub público.

## Continúa

`NEXT_ACTOR=CHATGPT_DIRECTOR` mientras Codex no tenga tokens. `N4_R2=WIP_EXTERNALLY_UNVERIFIED`. Próximos cierres: prueba real de N5/03 con Flutter/HTTPS/Android, N4 cuentas/Super Admin, administración de aliados/publicidad y firma release; datos jurídicos nacionales se agregan por manifest con fuente oficial y `UNKNOWN/STALE` donde no se haya validado cobertura.