# CODEX LUNA — PICORADAR R2 — BOGOTÁ TAXIS NOVIEMBRE 2026 + CORRECCIÓN P1 DE VIAJE (UNA SOLA EJECUCIÓN)

**TASK_ID ÚNICO:** `PICORADAR-R2-BOGOTA-TAXI-NOV2026-AND-R1-SCOPEFIX-20261109`.

**ORDEN DEL DIRECTOR:** ChatGPT define arquitectura, legislación, prioridades y aceptación. Tú, Codex Luna, solo implementas lo especificado, ejecutas pruebas y devuelves **un único ZIP autosuficiente** con evidencias. La instrucción vigente **no es repetir R1**, N1 ni M3-X01. **R1 Bogotá carro noviembre se preserva y R2 añade un segundo régimen real: taxi de Bogotá noviembre**, corrigiendo el defecto P1 detectado por auditoría independiente en el aviso de Viaje para motos. No improvisar un nuevo motor, arquitectura, API, base de datos, agente, plataforma editorial ni reescritura.

**ESTADO Y LÍMITES:** `PRODUCTION_RELEASE=NO`, `MERGE=NO`, `DEPLOY=NO`, `PUBLISH_TO_HOSTINGER=NO`, `DATASETS_ACTIVE_PROD=UNCHANGED`, `NEXT_AFTER_ZIP=CHATGPT_DIRECTOR`. Solo publicar a una rama remota **nueva** si la seguridad de permisos, costes y workflows se valida expresamente en el preflight descrito; de lo contrario entregar commit local y diff dentro del ZIP. Está prohibido modificar `main`, PR #71, PR #79 o worktrees WIP ajenos. No ejecutar tareas concurrentes con otro Codex.

## 1. Evidencias y SHA de arranque: leer, no repetir

Repositorio privado: `sierraglobalcompany-rgb/PicoRadar`.

- PR #71 código moderno (`recovery/20261019-modern`) **HEAD esperado** `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`.
- PR #79 plan/docs Draft: consultar HEAD actual desde remoto, leer §AN/§AO/§AP y cualquier sección posterior del Plan Maestro antes de modificar. No asumir que es idéntico al valor visto por ChatGPT; parar si cambió sustantivamente.
- R1 código completado en **commit local** `da9d8083bb21bd7c9863a319e07de51a5e692d09` de rama `feat/PICORADAR-R1-bogota-nov2026-real-e2e`; **NO estaba en GitHub** al auditar. Verificar ese commit local con `git cat-file -t` y `git rev-parse` y su padre exacto antes de usarlo. Si no existe o su diff ya fue modificado, `BLOCKED_PRECONDITION`, no reconstruir R1 desde conjeturas. Consultar respuesta ZIP antes de recrear.
- ZIP R1 único esperado físicamente en equipo Windows: `D:\codex\_REPORTES\PicoRadar\PICORADAR_R1_BOGOTA_NOV2026_REAL_E2E_EVIDENCIA_UNICA.zip`; SHA-256 **`52b8e0b8a9b5affba66da1e7cfb6f08343f7ab899a8afe44c1ce11feece8b02d`**, 36.259 bytes. Si esa ruta no existe, buscar **solo** en carpeta de informes autorizada; si tampoco, la prueba PHP de R1 genera los mismos bytes con un entorno aislado. No inventar otra entrega ni copiar archivos desde Descargas supuestas.
- Release R1 exacto en ZIP: `ACTUAL_LARAVEL_RELEASE.json`, version `r2-d0ac10fe5cba`, SHA-256 `315f6d81bf5a90b24e77d2d639f9774b67c996add29fa11101d1450c846c272a`. Manifest R1 `ACTUAL_MANIFEST.json` SHA-256 `5515155a2e83d6d2cb5dd7ed8a530b55cd122f578c785f7f935016c29fdad4c8`. Baseline del paquete de código `restrictions_v1.json` cuenta **7 jurisdicciones y 12 coberturas**.
- **Dictamen director R1:** integridad del ZIP PASS, PHP Laravel → release SHA real → HTTP loopback → Flutter/Drift PASS según logs; taxi/moto y seis ciudades comparados con el GitHub original PASS; **NO APK, CI, QA física ni actualización de usuarios**. Defecto P1 confirmado: `restriction_scope_notice.dart` no recibe `VehicleKind` y Trip puede mostrar texto para carro cuando el vehículo es moto privada.
- Las seis leyes vigentes `sierraglobalcompany-rgb/PingPongLaw` (KISS/Ponytail, antirruido, antiparches, UX aprobada, QA independiente, antipingpong), `AGENTS.md`, baselines y compatibilidad tienen prioridad. **No hace falta repetir inventario 31/55 ni el test sintético M3-X01**.

## 2. Preflight estricto — protección de WIP y ubicación

1. Reconocer ubicaciones `D:\codex\PicoRadar` (raíz preferida) y el checkout local R1 real referido en ZIP. **Solo inspección de lectura sobre C:** historial R1 se ejecutó en `C:\Users\felip\.codex\worktrees\picoradar-r1-bogota-nov2026\PicoRadar`. No escribir sobre ese checkout ni sobre carpeta de proyecto ajena; trabajar en clon/worktree **aislado bajo D:** con nombre R2 único. Si el clon D no existe, preparar clon local de commits (o un bundle local controlado) preservando el commit R1; no trasladar `.git` a ciegas ni destruir cualquier WIP.
2. Registrar `git status --porcelain=v1`, `git rev-parse HEAD`, branch, tree, remotos, worktrees, refs, stashes y 101 rutas históricas si están accesibles. Las 101 no estaban materializadas en el checkout R1, de modo que **no declarar 101/101 preservadas por no encontrarlas**. El checkout original tenía la **eliminación preexistente** `scripts/tests/test_hostinger_installer_browser.ps1`; protegerla, NO recrear ni borrar.
3. Confirmar que el commit local R1 es descendiente directo de `0d3a6a2...`, que su diff contiene solamente las diez rutas R1 declaradas, y no hay cambios sin seguimiento. Si hay conflictos sustantivos o repo distinto, **STOP_SAFE**; no reset, clean, stash, prune, cherry-pick silencioso, force push ni rebase automático. Ante discrepancia leve, explicar en ZIP y detener modificaciones irreversibles.
4. Fijar el **unico directorio de laboratorio** R2 en D para outputs, dataset falso, logs y ZIP. Nunca usar carpetas de producción ni Hostinger. Crear entorno SQLite en memoria o BD exclusivamente temporal y `Storage::fake`; salidas JSON del publicador SOLO de ese entorno.
5. Inspeccionar `.github/workflows/mobile.yml` y `server.yml` antes de cualquier push/PR. PR abre Actions automáticamente y consume minutos. **Prohibido crear PR o disparar workflow remoto si costes, permisos y hard-stop no están comprobados**. Una rama remota nueva puede recibir un único push normal solo si las políticas/permisos y workflows confirman que el push no dispara cargos no aprobados; documentar decisión. Si duda, `PUSH=NO` y el código queda íntegro en el ZIP.

## 3. Fuente jurídica OFICIAL R2 y tabla que debes codificar, sin delegar razonamiento legal

**Única fuente de calendario taxi noviembre 2026**: artículo de la Alcaldía Mayor de Bogotá, 4-nov-2026:
`https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-para-taxis-en-bogota-del-1-al-30-de-noviembre-de-2026`

La Alcaldía establece **taxis**, último dígito, **lunes a sábado 05:30–21:00** (minutos `330` a `1260`), **domingo y festivos sin restricción de taxi**. Los días **2 y 16 de noviembre** son lunes festivos. **No importar** regla de particular carro (06–21, paridad de fecha) ni usar el calendario de servicio especial como taxi, aunque los dígitos coincidan. Regla taxi válida **solo del 1 al 30 de noviembre de 2026**; no trasladar patrones a diciembre 2026, no inventar acto ni días de diciembre. `sourceUrl` HTTPS anterior, `verifiedAt` será la fecha real de revisión en este lote, nunca un timestamp ficticio.

**Tabla definitiva de DÍGITOS RESTRINGIDOS por fecha, contrastada por el director con los 8 permitidos publicados:**

| Día 2026-11 | Últimos dígitos RESTRINGIDOS |
|:--:|:--:|
| 03 | 1,2 |
| 04 | 3,4 |
| 05 | 5,6 |
| 06 | 7,8 |
| 07 | 9,0 |
| 09 | 1,2 |
| 10 | 3,4 |
| 11 | 5,6 |
| 12 | 7,8 |
| 13 | 9,0 |
| 14 | 1,2 |
| 17 | 5,6 |
| 18 | 7,8 |
| 19 | 9,0 |
| 20 | 1,2 |
| 21 | 3,4 |
| 23 | 5,6 |
| 24 | 7,8 |
| 25 | 9,0 |
| 26 | 1,2 |
| 27 | 3,4 |
| 28 | 5,6 |
| 30 | 7,8 |

**Conteos obligatorios:** exactamente **23 fechas** y **23 reglas de taxi** con dígitos explícitos; no domingos ni 2/16. **No usar aritmética de paridad ni asumir rotación únicamente en días efectivamente restringidos**, porque el artículo enumera cada día y el festivo 16 interrumpe la secuencia de manera no trivial. Todas las reglas taxi `vehicleKind=car`, `serviceType=taxi`, `digitPosition=lastNumeric`, `effect=restrict`, `timeWindows=[{startMinute:330,endMinute:1260}]`, `appliesOnHolidays=false`, `priority` conservar patrón aprobado (1000 si coincide con contrato), `validFrom=YYYY-MM-DDT00:00:00-05:00`, `validUntil=YYYY-MM-DDT23:59:59-05:00`. **No copiar `staleAfter` de septiembre**; fijar nueva política editorial compatible con validador y limitada al período publicado (no después de 01-dic 05:00Z sin justificación). Mantener `sourceUrls` evidencia oficial, `verifiedAt` coherente. 

**Tratamiento de excepciones:** no inferir permisos por placa. Medida taxi sin domingos ni festivos sí está explícitamente publicada. No convertir taxi en transporte especial, carga, bus, colectivo ni todo servicio público. Los casos especiales futuros requerirán sus contratos propios. La aplicación no garantiza autorización regional o de otras autoridades.

## 4. Dos entregables REALES en un mismo commit — cambios productivos mínimos

### R2-A. Reparación P1 del aviso de Viaje (sin rediseño)

1. Archivo existente: `mobile/lib/features/pico_placa/presentation/restriction_scope_notice.dart`: añadir argumento **`VehicleKind vehicleKind`** a `bogotaUrbanRestrictionScopeNotice`, y no devolver aviso si `vehicleKind != VehicleKind.car`. Mantener check `serviceType == VehicleServiceType.private`, `co-dc-bogota`, noviembre 2026, texto aprobado de R1. No producir avisos para `motorcycle/private`, `car/taxi`, otras ciudades y meses.
2. En `mobile/lib/features/pico_placa/presentation/today_restriction_summary.dart`, pasar el `vehicleKind` existente al helper; no alterar lógica de `RestrictionStatus`, `RestrictionDayStatus`, `allowedNoRestriction` o `known-empty`.
3. En `mobile/lib/features/trip/presentation/trip_plan_result.dart`, incorporar `VehicleKind? vehicleKind` al contrato de `TripInstantEndpoint`; cuando `vehicleKind==null`, no inventar tipo ni aviso; en `mobile/lib/features/trip/presentation/trip_screen.dart`, propagar **el tipo real del vehículo** en las cuatro llamadas, con nulabilidad segura cuando no hay vehículo. No cambiar el ruteo, cálculos de ETA, diseño, semántica aprobada ni mensajes fuera de Bogotá car/private.
4. Cambiar exclusivamente tests focales existentes `mobile/test/features/pico_placa/presentation/bogota_scope_notice_test.dart` para demostrar **negativos motos y taxis** en helper, Today, y Viaje, y positivos carro de noviembre tanto día hábil como festivo. Un test positivo con `motorcycle/private` en Trip **debe FALLAR antes de la corrección** y **PASAR después**; capturar RED→GREEN, pero sin reset de otras cosas.
5. No crear otro widget/servicio/estado/motor ni añadir dependencia. Reutilizar el helper que ya existe (KISS). Si el objetivo requiere tocar demasiados componentes, parar con `BLOCKED_SCOPE` y explicar exactamente.

### R2-B. Bogotá taxi noviembre realmente a través del publicador existente

1. Reutilizar `server/tests/Feature/BogotaNovember2026PublicationTest.php` y el flujo `RestrictionRuleVersionService` → `RestrictionPublicationService` → `DatasetPublisher` → `ManifestPublisher`; conservar el fixture R1 `server/tests/Fixtures/bogota_nov_2026_car_private.json` sin mutarlo. Crear **un** fixture oficial taxi específico Nov, o un pequeño array explícito y auditable en el test existente, **no** compilador nuevo, no framework y no copiar el código del publicador.
2. En SQLite in-memory + `Storage::fake` generar/recuperar baseline original (7 jurisdicciones/12 coberturas), conservar versión R1 car/private `r2` (desde el flujo oficial previo, idealmente reutilizando bytes exactos ZIP; si insumo no está disponible, reproducir R1 desde test existente y verificar que emita el mismo SHA cuando corresponda, no afirmar reproducibilidad byte a byte si `generatedAt` varió). **Añadir solamente** nueva cobertura `car/taxi` de noviembre al **objeto Bogotá COMPLETO**: mantener `car/private` de R1 noviembre y `motorcycle/private` known-empty sin alterar, así como las otras seis ciudades. No publicar un objeto Bogotá solo-taxi, ni cambiar `engineEnabled` del catálogo ni activar cobertura de otro municipio.
3. Comprobar conservación de **7 jurisdicciones/12 coberturas** y todos los `sourceUrls`, rule data, `verifiedAt`/`staleAfter` previos de particulares y moto; cobertura taxi se sustituye solo por el calendario oficial de 23 fechas. Comparar **directamente** el objeto `car/private` R1 antes/después y el objeto moto R1 antes/después, no confiar en conteo 7/12 solamente. Guardar diff estructurado de únicas diferencias: taxi, nueva envoltura version/fecha/manifiesto.
4. Publicar exclusivamente en el laboratorio local con las APIs existentes y una revisión de publicación correcta; capturar **bytes exactos de release real R2 y manifest real R2** y sus SHA256, `DatasetRelease` (estado, `publicationRevision`) y JSON auditado. Exigir consistencia `sha256(bytes)==manifest.datasets.restrictions.sha256==sha256` de entrada Flutter. No comparar versiones por prefijo fecha; Laravel usa `rN-...` y semilla bundled reconoce `YYYY.MM.DD` bajo otro flujo.
5. Flutter `DatasetSyncService` debe consumir esos bytes del manifiesto/release R2 mediante el harness loopback **ya existente** (extender test en `mobile/test/features/pico_placa/data/bogota_november_2026_release_e2e_test.dart`). Importar Drift con **12** coberturas, demostrar 23 fechas de taxi, minutos 329/330/1259/1260, nov 2/16 festivos, domingos, sábados, fin de noviembre, y **regresión de car/private R1**. Confirmar reimportación idempotente y `last-good` ante SHA corrupto/JSON corrupto. Sin simulaciones que sustituyan la evidencia R2 para esa prueba.
6. UI: verificar que taxi Bogotá consulta su propia cobertura y **no** hereda aviso “Solo pico y placa urbano general” de particular (incluidas Inicio, Mi Pico, Viaje); test de vista real o widget en `mobile/test/features/pico_placa/presentation/` según coste. No rediseñar pantallas ni cambiar semántica de permiso de otros servicios.
7. Si hay impedimento real de producción/fixture, documentar `BLOCKED_SCOPED` y conservar cambios útiles. El ZIP de R2 no debe reclamar `R2_E2E_PASS` sin **un release R2 real** generado por Laravel y leído por Flutter con SHA idéntico. Nunca modificar el JSON activo `mobile/assets/datasets/restrictions/restrictions_v1.json` solo para “pasar” pruebas o alargar su caducidad artificialmente.

## 5. QA y criterios exactos contra falsos positivos

Ejecutar únicamente suites relacionadas con los cambios y vecinos que puedan romperse: PHPUnit de R1/R2 publicación y validador; Flutter de import/sync, motores, resumen, Trip, Home y selector; `flutter analyze --no-pub` si el entorno no permite pub get, formato con diff check y Pint del PHP modificado. No repetir 3.309 pruebas antiguas ni QA JNI/firmas salvo que se genere realmente APK candidata.

**Controles obligatorios observables:**

1. `G0_PREFLIGHT=PASS` con commits/base/raíces, WIP propio y trabajo en D aislado, o `BLOCKED_SAFE`.
2. `SOURCE_TAXI=OFFICIAL` URL y fecha verificada, tabla de **23/23** fechas idéntica a este prompt; sin inferir el patrón.
3. `R1_TRIP_MOTORCYCLE_NEGATIVE=RED→GREEN`: moto privada no recibe aviso para carro; taxi tampoco; car/private recibe el aprobado.
4. `R1_CAR_PRESERVED=PASS` mediante comparación íntegra del objeto de cobertura R1.
5. `BOGOTA_MOTO_KNOWN_EMPTY_PRESERVED=PASS` con mismo TTL y rules[].
6. `SIX_OTHER_CITIES_PRESERVED=PASS` y `JURISDICTIONS=7 / COVERAGES=12` (comprobación de contenido y conteo).
7. `PHP_R2_RELEASE=PASS`: paso por **Laravel real** en Storage fake, estado versionado, manifest, SHA, y rollback comprobados; no impresión de JSON manual como sustituto.
8. `FLUTTER_R2_REAL_BYTES=PASS`: **mismo** release PHP → HTTP loopback → sync → Drift → evaluación 23 reglas con límites y festivos. El test E2E **no puede quedar skipped** cuando se reporte PASS: preparar `PICORADAR_R1_EVIDENCE_DIR`/variable R2 correspondiente antes de lanzar QA; contar skip explícitamente. Si en CI por falta de variable se omite, `CI_E2E_NOT_VERIFIED` y nunca `CI_PASS` de integración.
9. `UI_SCOPE_AND_NEGATIVE=PASS`: car privado Bogotá noviembre contextualizado; taxi y moto NO reciben aviso de carro; fuente y avisos accesibles. No hacer claim de app real cuando solo pasó widget.
10. `REGRESSION_SECRETS_ZIP=PASS`: PHP/Flutter focal, formato/análisis, `git diff --check`, scan de secretos, integridad ZIP + extracción independiente y hash. Cualquier fallo se registra; no maquillar `PASS` a partir de tests omitidos.

**Estados separados sin inventos:** `R2_PHP_LOCAL`, `R2_FLUTTER_SAME_BYTES`, `R2_UI_WIDGET`, `R2_DEV_APP_RUNTIME`, `QA_PHYSICAL`, `CI`, `RELEASE`; estos últimos solo PASS si se hicieron. La validación del host **no** implica que usuarios reales tengan noviembre activo. `R1_SCOPEFIX_PASS` también requiere test moto/taxi en Trip, no solo helper.

## 6. Git, políticas de costo y archivos autorizados

- Código producto permitido SOLO donde pasa el `VehicleKind` en aviso (helper, summary, Trip) y tests vecinos. El servicio Laravel y el motor permanecen intactos. Nuevos fixtures/test taxi pueden añadirse junto a tests existentes. No tocar bundling productivo, ERP, cámara, manifest de producción, Hosted, Play Store, dispositivos externos, ni copias no materializadas de los 101 WIP históricos.
- Crear **un solo commit local final** de R2 si gates pasan, basado en R1 `da9d...` exacto; no reescribir commit R1 (no amend), no squash ajeno. `git diff --name-status` y cambio de archivo máximo 8–12 rutas justificadas. Todo otro archivo no previsto es error o requiere detener y justificar, nunca asumir autonomía.
- Si un `git push` normal a rama R2 de nombre exacto es seguro **según políticas ya aprobadas y lectura completa de workflow/costos**, puede hacerse UNA vez y verificar SHA remoto. **No abrir PR** si Actions/coste o permiso no acreditado; no usar `force`, no merge, no deploy. En caso de duda, no hacer escritura remota: entregar patch y commit SHA en ZIP. El director integrará después.
- `flutter pub get --offline` puede fallar por symlink/Developer Mode. No alterar Windows global ni instalar herramientas no autorizadas para evadir política. `--no-pub` solo si lockfile no cambió y dependencias resueltas. Anotar bloqueo de APK/QA físico si corresponde.
- Borrar temporales no es condición de aceptación; si política Windows bloquea limpieza, excluir residuos del ZIP e informar. Jamás `git clean/reset` o borrar carpetas C históricas.

## 7. ENTREGA ÚNICA OBLIGATORIA — un ZIP ZIP, no archivos sueltos

Ruta de salida sugerida **bajo D validado**: `D:\codex\_REPORTES\PicoRadar\PICORADAR_R2_BOGOTA_TAXI_NOV2026_Y_R1_SCOPEFIX_EVIDENCIA_UNICA.zip`; ruta real comprobada en la respuesta, no enlace inventado.

Contenido mínimo del ZIP autosuficiente: `FINAL_REPORT.md` con tabla de 10 controles y estados; `SOURCE_TAXI_NOV2026.csv` con 23 fechas y URL/fecha de consulta; `ACTUAL_R2_LARAVEL_RELEASE.json` y `ACTUAL_R2_MANIFEST.json` **bytes exactos**, `R2_PUBLISH_RESULT.json` con SHA/versión/revisión; `R1_R2_PRESERVATION_DIFF.json`; `FLUTTER_IMPORT_RESULT.md` con comparación triple SHA, 23 fechas y lastgood; logs PHP/Flutter (incluyendo skip counts), lint/format; `GIT_DIFF.patch` que contenga todo lo modificado, `GIT_STATUS.txt`, `CHANGED_FILES_SHA256.csv`, `COMMANDS_AND_LOGS.txt`, evidencias RED→GREEN, `BLOCKERS.md` si algo no se pudo ejecutar, `MANIFEST.json` de todos los demás miembros (tamaños+SHA) y `MANIFEST.sha256`, hash SHA-256 del ZIP final. Validar CRC y extracción en carpeta temporal independiente, proteger rutas zip-slip, escanear secretos. No empaquetar contraseñas, tokens, `.env`, PII ni rutas privadas que no sean necesarias para reproducir.

Respuesta de Codex muy breve fuera del ZIP:
`TASK_ID=...; RESULT=...; R2_TAXI_RULES=23/23; R1_SCOPEFIX=...; PHP_RELEASE=...; FLUTTER_SAME_BYTES=...; SOURCE=...; PRESERVED_7_12=...; LOCAL_COMMIT=...; GITHUB_PUSH=...; CI=...; QA_PHYSICAL=...; RELEASE=NO; ZIP_PATH=...; ZIP_SHA256=...; NEXT=CHATGPT_DIRECTOR`.

## 8. Límites y finalización posterior sin desviarse

Tras este ZIP y una única auditoría forense del código real, ChatGPT director prosigue con el siguiente lote **multiciudad real** ya fundamentado: Medellín carro/moto con Decreto 1490/2026 y ámbito exento, Cartagena carro/moto con regímenes especiales, y luego otras autoridades verificadas. Modalidades servicio público especial/bus/carga requieren contrato **diferenciado**; no convertirlas en taxi ni privado por conveniencia. La matriz 31/55 y catálogo 73/219 ya existen: **no volver a ordenarlos**. **El indicador de progreso nacional es cantidad de restricciones oficiales realmente comprobables en Flutter/Drift por clase/municipio/fecha y actualización versionada**, no número de scripts, hojas o prompts.

**FIN DE ORDEN — SOLO CODEX LUNA EJECUTA ESTA TAREA R2. UNA EJECUCIÓN, UN COMMIT, UN ZIP. NO PUBLICAR. DESPUÉS CONTINÚA CHATGPT DIRECTOR.**
