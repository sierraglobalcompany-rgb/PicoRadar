# CODEX LUNA — PICORADAR · CIERRE OTA REAL Y QA RESIDUAL SIN REPETIR V5-R1

**TASK_ID:** `PICORADAR-V5R1-OTA-QA-RESIDUAL-UNICO-20261116`  
**ESTADO DE ESTA ORDEN:** preparada por ChatGPT Director; no ejecutada.  
**QUIÉN EJECUTA:** Codex Luna, únicamente cuando no haya otro escritor.  
**QUIÉN REVISA:** ChatGPT Director.  
**ÚNICO RESULTADO BUSCADO:** cerrar el bloqueo de pruebas ambientales y realizar, **si el entorno lo hace posible**, una publicación QA real **Laravel → manifest HTTP(S) de QA → descarga/verificación → Drift → selector/cálculo/rollback**, sin modificar el motor por ciudad, sin instalar APK en un teléfono y sin declarar producción lista. No es una nueva auditoría general.

## 0. BASE INMUTABLE Y HECHOS QUE NO SE VUELVEN A DEBATIR

- Entrega recibida `PICORADAR_V5R1_APK_OTA_NACIONAL_RETORNO_UNICO.zip` SHA-256 `481fa5608e7ca2cf6966d4d4b72c982fcdfdb0552b42a09a6d90f951dc33532d`: ZIP/CRC y **12/12** manifiesto PASS, verificación independiente ChatGPT.
- `HEAD` Windows reportado (local, **no** remoto): `182a8821bba688b28a6e223a1e956df748f7948b`; base `HEAD_TREE/REAL_INDEX_TREE=24408f305f7a977cf30e426ce3925cca19f981ad`.
- Árbol del candidato V5-R1 reportado y **reconstruido por ChatGPT en un clon aislado**: `10ab7af9d07ea6ea941ba54289c9c0455b6d1f70`. **Solo dos archivos de test**, sin cambio en lógica de producto ni en datos oficiales respecto a V4-R1.
- Recuperación de código: bundle privado `RC2_BASE_full-final.bundle` del ZIP de continuidad N1-R1 + `RECOVERY/RC2_TO_FINAL.patch` del ZIP V4-R1 reconstruyen `24408f3...` exacto. Luego `EVIDENCE/BASE_TO_FINAL.patch` del ZIP V5-R1 reconstruye `10ab7af...` exacto **si se normalizan los finales de línea CRLF del parche en una COPIA temporal** (`CRLF → LF`). Original SHA parche `6c0f66d38330312248f255d54360c04a6f9f2ef64901b12309982be688804e2b`; copia LF verificada SHA `8b7d6a3f1371292459db4a07382c7f464ccb76e177dc8db1057b365b66f3b0a2`. No alterar la copia original ni tocar otros worktrees.
- **NO REPETIR:** V3, V4, V4-R1; suite completa V4-R1 **3347 PASS / 11 SKIP / 0 FAIL** según logs, sobre lógica de producto sin cambios; las **175 pruebas focales PASS** de V5-R1; Flutter analyze PASS; 15 migraciones PASS; 16 Viaje visual PASS; pruebas PHP/Python acreditadas N1. Formato de dos Dart modificados PASS. `dart format .` falló intentando recorrer un directorio **generado e ignorado** bajo `mobile/build`; no reformatear ni borrar build por ello.
- APK DEV **YA EXISTE y se entregó en el ZIP anterior**: `co.picoradar.app.dev`, `1.0.1+2`, 244.933.378 bytes, SHA-256 `02d565db08f3779528e6f1c68de4cd75f1494b7c58ac6d46baf397f58f3c75d6`; debug, OTA **DISABLED_NO_CDN**. **No recompilarla ni volver a adjuntar 245 MB si los archivos de producto no cambian.** No instalar, desinstalar, limpiar datos, cambiar firma ni usar ADB.
- V5-R1 suite completa: **1897 PASS / 10 SKIP / 3 FAIL_INPUT al interrumpirse**, NO resultado completo. Los tres fallos están en `mobile/test/features/pico_placa/data/restriction_g2_same_bytes_test.dart` líneas aproximadas 48, 281 y 415 por faltantes `PICORADAR_G2_V3_EVIDENCE_DIR`, `PICORADAR_V1_METADATA_LAB_DIR`, `PICORADAR_G34_LAB_EVIDENCE_DIR`. Ya fueron recuperados y pasaron en V4-R1; **es regresión de preparación del entorno, no evidencia de defecto del motor**. La suite también emitió peticiones reales a `tile.openstreetmap.org`, motivo legítimo para interrumpirla.
- Motor nacional **ÚNICO `schemaVersion=2`**; reglas por fuente oficial con ámbito, modalidad, día, par/impar, dígitos, ventanas, festivos, vigencia, encendido/apagado y fuentes. Fuente institucional oficial es válida para los **campos expresos**, aun sin PDF del decreto; no inventar ámbito/exenciones, no inferir circulación libre de una ausencia. Snapshot nacional LAB tiene 14 autoridades / 33 DIVIPOLA / 22 coberturas **partial** / 120 reglas. Bogotá/Cartagena/Medellín no representan Colombia cubierta jurídicamente.
- `AGENTS.md`/Baseline superiores a este prompt. Producto funciona **sin cuenta**. Nada de ads/pagos/marketing/cloud personal por inercia. Placas, cédulas, fotos, matrículas, contratos, documentos y GPS exacto **local-only**; no incluirlos en reportes.

## 1. PRE-FLIGHT ÚNICO DE 5 MINUTOS LÓGICOS (SIN OTRO PROMPT)

1. Abrir el **mismo candidato V5-R1 ya usado**, protegido de WIP ajeno. Verificar **una sola vez** `git rev-parse HEAD`, `git write-tree` o árbol alterno de los archivos de trabajo, `git status --porcelain=v1`, y comprobar ausencia de otro escritor. No exigir `HEAD == FINAL_TREE`: V5-R1 dejó deliberadamente dos pruebas sin commit y el índice real intacto. Si existe trabajo nuevo ajeno, preservar y actuar solo en una copia aislada del **mismo** árbol.
2. Si hay que reconstruir: usar exactamente base RC2 + parche V4-R1 + copia temporal LF del parche V5-R1; confirmar árbol `10ab7af9d07ea6ea941ba54289c9c0455b6d1f70`. **No volver a ejecutar auditoría Git, N1 ni inventario nacional.** Si ya está el árbol V5 en el host, NO restaurar otra vez.
3. Leer rutas estrictamente pertinentes: `README.md` (sección Windows/PHP), `AGENTS.md`, `mobile/lib/core/sync/dataset_sync_service.dart`, `mobile/lib/core/config/app_config.dart`, `mobile/lib/app/app_providers.dart`, `server/app/Services/RestrictionPublicationService.php`, `server/app/Services/DatasetPublisher.php`, `server/tests/Feature/RestrictionPublicationServiceTest.php`, `server/tests/Feature/DatasetPublisherTest.php`, `mobile/test/core/sync/dataset_sync_service_test.dart`, `mobile/test/app/dataset_sync_composition_test.dart` y test con insumos históricos citado arriba. Nada de volver a leer cientos de documentos sin causa.
4. No aplicar nuevos hooks, `git clean`, `reset --hard`, `force-push`, `flutter clean`, cambio global de Gradle, descargas de SDK, subida de bundle privado, activación productiva de server, modificación de `.env` ajeno ni instalación en Mi A3.

## 2. RESOLVER LOS TRES `FAIL_INPUT` SIN REPETIR 3347 PRUEBAS

**Un solo reuso de evidencia antigua**. Buscar primero en la misma área local de reportes que ya utilizó V4-R1 (`logs/historical_inputs_sanitized.log` del ZIP V4-R1) y reutilizar/extractar únicamente los **14 miembros originales y verificados** de G2 V3, V1, G34, G1 y R2; nunca sintetizar esos originales. Verificaciones objetivo de ese log V4-R1:

- G2 V3 release SHA-256 `826e59877ee454102b01502cc2030ec0faae9d26196fab37f99a451f5d27d1f6`.
- V1 release SHA-256 `3b99adca0db33a1cd8bb179f3dd51c5737fa80ab0b6f360f2dd110c8809ed362`.
- G34 release SHA-256 `04e339bbcbcc7b9263f3b52a53d72726f45969b676fb9c05000dd2c62b63eadf`.
- G1 release SHA-256 `4c20e392033d9cd9e17b7a2e96a0241588a1d269301df29f30095f45d8816d8f`.
- R2 release SHA-256 `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`; R2 manifest `9b63da4b2e20e9b167e32fadde2aef7d62c34b91569d0c64a236a4aceddbb7f8`.

Si están ya extraídos, **solo apuntar las tres variables de entorno a directorios correctos**. Ejecutar UNA vez exclusivamente `mobile/test/features/pico_placa/data/restriction_g2_same_bytes_test.dart` con Flutter 3.47.9 y lockfile existente; guardar comando, exit y resultados. Si faltan archivos tras búsqueda limitada, marcar `HISTORICAL_3=FAIL_INPUT_UNRECOVERED`, no cambiar aserciones ni inventar datos, y continuar a §3 sin otra orden.

**Test de mapas:** identificar de manera focal el test/fixture que permite URLs `tile.openstreetmap.org` (candidatos: mapas CDA, Fotomultas, Viaje, Conducir). Para cualquier futura suite global, usar la capacidad **YA EXISTENTE** de provider HTTP de tiles fake/in-memory o un override de test, preservando URL real en producto. No solicitar recursos de tiles públicos en CI. Añadir **máximo un arreglo reutilizable de harness** solo si un test causal demuestra la emisión; no cambiar la app de producción ni desactivar tests para ocultarlo. Si no hay guardia segura, **no lanzar la global**; mantener `FULL_SUITE=REUSED_V4R1_PLUS_FOCAL_V5R1`, señalando que **esto NO certifica una nueva suite completa V5-R1**.

## 3. PUBLICACIÓN OTA EN QA GRATUITO Y AISLADO (EL ÚNICO BLOQUE FUNCIONAL NUEVO)

**Prioridad:** lograr una prueba de integración real, no otro `PASS_SCOPED` conceptual. Separar servidores y restricciones comerciales sin crear arquitectura paralela.

1. **Preflight BD una vez:** comprobar `php --version`, `php -m` y ruta de extensiones con el PHP autorizado del host. Si faltan `pdo_sqlite`/`sqlite3`, intentar **una sola vez** la receta existente en `README.md` con extensiones locales compatibles ya instaladas, sin alterar PHP global. Si no existen, inspeccionar una sola ruta conocida del MariaDB local de QA que ya figura en README, únicamente si se puede ejecutar en sandbox de datos fresco y sin tocar bases ajenas. No instalar infra comercial ni modificar producción. Si no existe BD gratuita y segura, marcar `QA_DB_UNAVAILABLE` y **continuar §4**; nunca declarar OTA E2E PASS.
2. Con BD QA efímera: crear `APP_ENV=testing`, `APP_KEY` sintética, conexión únicamente al SQLite/MariaDB recién creado, migraciones y cuentas sintéticas separadas **editor/revisor**, sin usuarios reales. Reutilizar `RestrictionPublicationService`, `DatasetPublisher`, `DatasetReleaseValidator` y rutas de `server/routes/web.php` / dataset público ya existentes. No fabricar otro publicador, API o esquema.
3. Ejecutar la secuencia: dos jurisdicciones A/B ficticias (Medellín/Abejorral son NOMBRES de prueba únicamente; no fingir decretos reales) → estado A habilitado v1 → deshabilitado v2 → habilitado con dígitos/días/horarios distintos v3; B permanece habilitada → aprobación editorial autorizada por otro usuario sintético → **snapshot ÍNTEGRO A+B**, nuevo versionado y SHA-256 → manifiesto/asset servidos sobre HTTP de QA aislado cuando el ambiente local lo admita. Comprobar lectura del recurso HTTP real y que publicar A **no borra** B. Una publicación/revisión legal ficticia no debe anunciarse como oficial.
4. Cliente: descargar el manifiesto de ese servicio QA real y el dataset en Drift mediante `DatasetSyncService`, no importación manual en test como sustituto de OTA. Comprobar ETag/304 cuando aplique, validación SHA y mismo origen, doble actualización, nueva jurisdicción, deshabilitación efectiva en Inicio/Pico/Viaje/recordatorios, cálculo de restricción, persistencia tras reinicio, conservación de Garaje y prueba negativa de hash corrupto con last-good/rollback. Donde el contrato indique `UNKNOWN/STALE`, **jamás `ALLOWED`** por ausencia de autoridad o cobertura parcial. Una prueba sintética puede demostrar mecánica, NO alcance legal nacional.
5. En pruebas locales pueden existir URLs HTTP **solo bajo ambiente QA aislado**. Para un build con OTA de usuario/dispositivo, exigir endpoint HTTPS accesible, certificado válido y origen autorizado; no confundir `AppConfig` aceptando URI `http` como permiso de seguridad para producción. **Sin HTTPS QA real: `OTA_PRODUCT_HTTPS=NOT_RUN_ENV`**, no crear túnel remoto, desactivar TLS ni inventar CDN.
6. No realizar 30 intentos de entorno. Si BD QA sigue bloqueada, ejecutar solo contratos offline que faltan y dejar `OTA_LARAVEL_HTTP=NOT_RUN_ENV`, `OTA_END_TO_END=NOT_RUN_ENV` con **una única causa y prerequisito preciso**. No repetir tests ya ejecutados en N1/V4 por inercia. No instalar servicios remotos ni publicar un dataset LAB en dominio real.

## 4. APK, CIERRE DE ÁRBOL Y CONTINUIDAD

- **Si NO cambia código de producto**: conservar APK V5-R1 anterior con su SHA, sin nuevo build, sin duplicación de 245 MB en ZIP. Tests nuevos pueden producir árbol distinto; generar parche solo del delta test y dar nuevo árbol. No simular que la APK anterior contiene datos descargados por OTA.
- **Si se modifica código de app**: completar todas las pruebas focales relacionadas y `flutter analyze`; solo entonces ejecutar una vez QA global **con una guardia que impida peticiones a tiles públicos**, y compilar APK DEV del árbol final con la receta Kotlin **documentada en README**. APK nueva dentro de un único ZIP si el build funciona. Si fuente Kotlin/Gradle sin cambios, no volver a arreglar lo ya resuelto. No entregar release ni instalar en Mi A3.
- **Si no existe HTTPS QA**: registrar exactamente `APK_OTA_CONFIG=DISABLED_NO_CDN` para la APK ya recibida. No editar configuración, empaquetar credenciales ni crear APK configurada con endpoints falsos.
- **GitHub:** el repositorio del código sigue bajo `HOLD_SECURITY`; no hacer push ni merge ni reescribir historial sin saneamiento/autorización. El Director conserva el estado documental en PR #79; Codex no debe crear un nuevo PR documental en este bloque. Mantener parche/git bundle recuperable **solo de cambios nuevos** (no duplicar 85 MB de bundle RC2). Guardar SHA de HEAD, base/final tree y cómo recuperar código. Si se detecta un bloqueo de seguridad real, describir el objeto preciso y la decisión requerida; no volver a investigar historial entero sin evidencia nueva.
- Requisitos de **registro opcional de usuarios**, consentimientos, filtros/exportación de datos permitidos, emails de administración, CDA/SOAT/aliados/publicidad siguen en el plan. **NO** introducirlos dentro de este lote OTA: requieren especificación de privacidad y aceptación propias. No afirmar `APP_COMPLETE` por tener APK y motor.

## 5. ÚNICA ENTREGA Y GATES EXPLÍCITOS

Devolver **UN SOLO ZIP** pequeño, sin datos reales/secretos ni la APK ya recibida si no cambia. Contenido: `FINAL_REPORT.md`, `GATES.csv`, logs focales **sanitizados** con comandos/exits/árbol, manifiesto de tamaño + SHA256 + CRC, y parche de cambios NUEVOS si existen. Si se compiló APK nueva, incluirla en ese mismo ZIP y su identidad SHA/versión/firma. Si no hubo cambio, referenciar SHA V5 existente en vez de replicar binarios. Verificar íntegramente el ZIP antes de informar ruta y SHA.

**Gates de salida independientes:**

```text
TASK_ID=PICORADAR-V5R1-OTA-QA-RESIDUAL-UNICO-20261116
BASE_TREE=10ab7af9d07ea6ea941ba54289c9c0455b6d1f70
FINAL_TREE=<git write-tree comprobado o NO_VERIFIED>
HISTORICAL_3=PASS|FAIL_INPUT_UNRECOVERED|NOT_RUN_ENV
TILE_TEST_NETWORK=BLOCKED_BY_TEST_GUARD|STILL_UNSAFE|NOT_RUN
MOBILE_GLOBAL=REUSED_V4R1_PLUS_FOCAL_V5R1|PASS_FINAL|FAIL|NOT_RUN_NET_GUARD
OTA_QA_DB=READY|QA_DB_UNAVAILABLE
OTA_SERVER_PUBLISH=PASS|FAIL|NOT_RUN_ENV
OTA_REAL_HTTP_CLIENT=PASS|FAIL|NOT_RUN_ENV
OTA_ROLLBACK_LAST_GOOD=PASS|FAIL|NOT_RUN_ENV
OTA_PRODUCT_HTTPS=PASS|NOT_RUN_ENV|FAIL
NATIONAL_DATA_ONLY=PASS_SCOPED|PARTIAL|FAIL
APK=REUSED_V5_OFFLINE|NEW_DEV_DELIVERED|NEW_DEV_FAILED
ANDROID=NOT_INSTALLED_SAFE
GITHUB_PRODUCT=HOLD_SECURITY
PRODUCT_RELEASE=NO_GO
NEXT_ACTOR=CHATGPT_DIRECTOR
```

**Ley 1 KISS:** reuse providers/publicador/Dio/Drift; **L2 antirruido:** no repetir 3347 PASS ni ZIP de 245 MB; **L3 antiparches:** arreglar causa de entorno/test, no motor por municipio; **L4 UX:** no rediseño; **L5:** PASS únicamente con logs/árbol/HTTP reales; **L6:** un bloque, un ZIP, un único relevo. **Prohibidos:** otra 10×10 de Codex, otra orden para solo preflight, cambiar datos legales para PASS, falsear E2E o declarar cobertura nacional por un catálogo de 1104 municipios.

**AL CERRAR:** escribir `SIGUE: CHATGPT DIRECTOR` y entregar el ZIP único sin pedir un siguiente prompt de verificación.