# CODEX LUNA — PICORADAR R1 — BOGOTÁ NOVIEMBRE 2026, REGLA OFICIAL REAL DE PRINCIPIO A FIN

**TASK_ID INMUTABLE:** `PICORADAR-R1-BOGOTA-NOV2026-REAL-END2END-20261109`  
**ORDEN ÚNICA DEL DIRECTOR:** ChatGPT decide arquitectura, regla, seguridad y aceptación. Codex Luna implementa y comprueba, sin autonomía para cambiar el alcance.  
**PRIORIDAD:** producto funcionando, NO más matrices de 31/55, NO reejecutar M3-X01 sintético, NO reauditar todo el repositorio.  
**ESTADO:** `DEVELOPMENT_CANDIDATE`; `PRODUCTION_PUBLISH=NO`; `MERGE=NO`; `DEPLOY=NO`; `RELEASE=NO`.  
**ENTREGA:** un solo ZIP final con pruebas, código/parches e informe/manifest, no 15 archivos repartidos.

## 0. Por qué esta tarea y qué la hace diferente

El motor Flutter, los tipos `car/private`, Laravel B07 (importación/versiones/publicación/reversión), el parser Drift y el sincronizador con SHA y último estado bueno YA EXISTEN. El dataset incluido en la APK solo contiene para Bogotá particulares **septiembre de 2026**, vencido el `2026-09-23`; por tanto para noviembre no ofrece cobertura nueva válida. Una implementación de 31→55 filas de otra IA NO soluciona este problema. **En R1 vamos a materializar un calendario oficial REAL y vigente de Bogotá, hacer que Laravel lo genere en un release LOCAL AISLADO y comprobar que Flutter consume ESOS MISMOS BYTES**, además de una opción de primer arranque offline si cabe sin duplicar fuentes.

**Fuente jurídica oficial, no informe de IA:**
- `https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-bogota-vehiculos-particulares-1-30-de-noviembre-de-2026` publicada `2026-11-01`, calendario explícito para **NOVIEMBRE 2026**. Consultada por director `2026-11-09`.
- `https://www.movilidadbogota.gov.co/preguntas-frecuentes/en-que-consiste-la-restriccion-establecida-para-vehiculos-particulares` actualizada `2026-10-16`, restricción urbana por último dígito, 06:00–21:00, días hábiles, y diferenciación del retorno regional.
- `https://www.movilidadbogota.gov.co/pico-y-placa` actualizada `2026-11-03`, confirma fuente de calendario 2026 y otros regímenes separados.

**Hechos jurídicos que Codex NO debe reinterpretar:** Bogotá D.C. `DIVIPOLA=11001`, jurisdicción runtime **`co-dc-bogota`**, `vehicleKind=car`, `serviceType=private`, **perímetro urbano**, no return regional ni taxis ni transporte especial ni carga. **Días hábiles L–V de noviembre**, de **06:00 a 21:00**. **Fecha impar: restringidos `6,7,8,9,0`** (circulan `1..5`); **fecha par: restringidos `1,2,3,4,5`** (circulan `6..0`). Nov 2 y Nov 16 son **lunes festivos** con régimen de **retorno regional** por corredores, distinto del urbano. `validFrom=2026-11-01T00:00:00-05:00`; `validUntil=2026-11-30T23:59:59-05:00`; `timeWindows=[{startMinute:360,endMinute:1260}]`; `appliesOnHolidays=false`; `weekdays=[1,2,3,4,5]`; `digitPosition=lastNumeric`; `dateParity=odd|even`; efecto `restrict`. **Frescura estricta:** `verifiedAt` debe ser el instante UTC de acceso real documentado, no una fecha inventada; el límite máximo permitido para `staleAfter` en este lote es `2026-12-01T05:00:00Z` (inicio de diciembre en Colombia), y cualquier política vigente más estricta prevalece. Nunca extender la validez legal de la fuente más allá de noviembre. Si la fuente no puede cotejarse y no hay captura oficial verificable del director, dejar `BLOCKED_SOURCE` y no renovar TTL por suposición.

**Contexto obligatorio:** la regla ordinaria de Bogotá no resuelve exenciones individuales (art. 230), ni los 9 corredores del retorno regional, ni significa que un vehículo tiene licencia universal para circular. En particular, **NO decir «puede circular» como autorización de ingreso regional el 2/16 de noviembre**; el reporte debe etiquetar claramente el alcance «pico y placa URBANO GENERAL, no ingreso regional ni permisos individuales». Si el UI aprobado no puede comunicar esa salvedad sin añadir componente complejo, activar gate `SCOPE_UI_UNSAFE` y detener SOLO la activación del candidato, no inventar un segundo motor ni ocultarlo.

## 1. Estado base y prohibiciones verificables — G0

**GitHub canónico:** `sierraglobalcompany-rgb/PicoRadar`.
- PR #71 `OPEN/DRAFT` contra `main` histórico; su HEAD de código remoto esperado **`0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`**. Es la base moderna que se contrasta; **NO trabajar sobre el main histórico**.
- La rama de código moderna es `recovery/20261019-modern` (consultar `origin` real y verificar SHA antes de crear rama).
- PR #79 `OPEN/DRAFT` solo documentos; **no mergear docs para traer el prompt**. El Plan Maestro tiene §AN y el nuevo §AO. Se encuentra en `docs/plans/PICORADAR_PLAN_MAESTRO_V2_NACIONAL_20261107.md` de PR79.
- 101 rutas WIP históricas y `scripts/tests/test_hostinger_installer_browser.ps1` eliminado/protegido: **nunca limpiarlos ni restaurarlos de forma automática**. `D:/Dev/PicoRadar` es ruta histórica en `AGENTS.md`, NO garantía de checkout actual; en proyectos recientes se trabaja bajo `D:\codex\PicoRadar`. **Descubrir rutas y estado sin alterar nada**.
- Si Codex ya tiene **N1 V2** iniciado, NO iniciar R1 en paralelo ni tocar sus worktrees; dejar en ZIP `BLOCKED_ACTIVE_LOT`, capturar su estado read-only y entregar a ChatGPT. Si N1 V2 no inició, queda suspendido por §AN. No repetirlo.

Antes de editar, leer con jerarquía:
1. `AGENTS.md`, `docs/CURRENT.md`, `docs/SOP.md`, `docs/DESIGN_CONTRACT.md`, baselines 11/12 del repo y contratos/leyes de `sierraglobalcompany-rgb/PingPongLaw/docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md` (commit `84e961cadf482d234f4c0ee2ca60e8c7e9b388e8`). Leyes L1 KISS/Ponytail, L2 antirruido, L3 antiparches, L4 UX aprobada, L5 QA independiente, L6 antipingpong.
2. Código señalado abajo, en un clon/worktree nuevo bajo **D:** basado EXCLUSIVAMENTE en el HEAD moderno verificado. Para WIP previo: registrar `git status --porcelain=v1`, branch/HEAD, `git worktree list --porcelain`, stashes, hashes de rutas sensibles si accesibles; NO `git clean/reset --hard/stash pop`, no force push ni actualizaciones locales en el checkout original.
3. Si HEAD remoto, base o política cambió, detener acción de escritura e informar `BLOCKED_SHA_DRIFT` con diferencias concretas; no rebase ciego.

## 2. Archivos reales a inspeccionar; NO duplicar sus funciones

**Flutter/datos:**
- `mobile/assets/datasets/restrictions/restrictions_v1.json` — archivo incluido de semilla, schema1; **Bogotá car/private septiembre**, `staleAfter=2026-09-23`, no noviembre. Otras 11 coberturas preservadas, muchas vencidas.
- `mobile/lib/features/pico_placa/domain/restriction_engine.dart` — soporta `dateParity`, placas, festivos y `ALLOWED/RESTRICTED/UNKNOWN/STALE`, no cambiar globalmente `ALLOWED`.
- `mobile/lib/features/pico_placa/domain/restriction_rule.dart` — ventana 06:00–21:00 ya compatible.
- `mobile/lib/features/pico_placa/data/restriction_dataset.dart`, `restriction_store.dart`, `bundled_restrictions.dart` — importador, `coverageKnown` y actualización de semilla; **no modificar schema ni migraciones**.
- `mobile/lib/core/sync/dataset_sync_service.dart` y `mobile/lib/core/sync/dataset_manifest.dart` — manifiesto, SHA y last-good preexistentes.
- `mobile/lib/features/pico_placa/presentation/today_restriction_summary.dart`, `pico_detail_screen.dart` y consumidores de Inicio/Viaje — inspectar cómo se expresa «Puede circular»; asegurar el alcance Bogotá sin cambiar disposición gráfica aprobada.
- `mobile/test/features/pico_placa/data/restriction_dataset_test.dart`, tests reales del sincronizador y ciudad/UX. Preservar test `R4 empty known coverages stay known without inventing restrictions` y casos `unknown/stale`.

**Laravel:**
- `server/app/Services/RestrictionImportService.php` — `analyze()` **escribe** en disco privado, DB y auditoría: solo usar en base/discos fake de tests, nunca como preview read-only sobre datos reales; `normalize()` tiene valor predeterminado `publish=yes`.
- `server/app/Services/RestrictionRuleVersionService.php`, `RestrictionContractValidator.php`, `RestrictionPublicationService.php`, `DatasetPublisher.php`, `ManifestPublisher.php` — reutilizar, **no crear otro publicador**.
- `server/tests/Feature/RestrictionPublicationServiceTest.php`, `DatasetPublisherTest.php`, `RestrictionImportServiceTest.php` — casos existentes, ampliar tests focales, NO reejecutar M3-X01 synthetic bridge como tarea.

**CI:** `.github/workflows/mobile.yml`, `.github/workflows/server.yml`. Históricamente Actions bloqueado/cuota; evitar dispararlo sin gate de coste, no afirmar verde remoto.

## 3. Entregable de producto obligatorio: regla REAL, no «otro CSV»

**R1-A. Datos jurídicos como una sola fuente de la transformación.** Crear UNA definición versionada y auditable dentro de ruta de datos de desarrollo o fixtures legales en el stack existente (preferir fixture Laravel `server/tests/Fixtures/` o ruta ya existente; NO doble repositorio de verdad). Debe incluir autoridad, URL exacta oficial, check real si disponible, vigencia noviembre, alcance URBANO GENERAL, dos reglas de paridad, evidencia de excepción regional y estado de revisión. Sin buscar todas las ciudades ni crear estructura de agentes.

**R1-B. Publicación LOCAL en aislamiento, usando B07 REAL.** En test PHP/SQLite aislado, crear/preparar la versión de jurisdicción `co-dc-bogota`, validar origen oficial/ventanas, confirmar la versión y ejecutar **el `RestrictionPublicationService` y `DatasetPublisher` existentes** con `Storage::fake` o discos TEMPORALES, sin conexión a Hostinger/MariaDB real. Verificar resultante `restrictions` schema1, SHA-256, manifest, URL/version, revision y que SOLO la cobertura `car:private` de Bogotá cambió; `motorcycle:private` conocido-vacío y taxi Bogotá septiembre **NO reetiquetados como noviembre**, demás municipios idénticos byte-semánticamente. Si una publicación selectiva sustituye toda la jurisdicción, **conservar las otras coverages de Bogotá en la propuesta**, nunca enviarla solo con `car:private` y borrar moto/taxi.

**R1-C. Flutter consume los BYTES de la publicación local, no un fixture inventado:** tomar `restrictions` publicados y su manifest desde los discos de test (exportaciones reales reproducibles), verificar `sha256` y `version` `rN-hash` a través del `DatasetSyncService` en red fake/fixture HTTP si el harness existente lo permite, importador Drift y `RestrictionEngine`. Comparar los dos `rule.id`, dígitos, periodo y estados de destino. Acreditar idempotencia, reinstalación y last-good ante payload corrupto. **No copiar el JSON de un test sintético M3 y llamarlo producción.** 

**R1-D. Producto en APK/dev sin publicación remota:** el flujo de sincronización dev debe poder cargar ese manifest/release de prueba contra servidor LOCAL/AISLADO con mismo SHA. Si no hay acceso funcional al dispositivo Mi A3 por firma/JNI, preferir prueba de widget/dev emulador o test de sync real, registrar `QA_PHYSICAL_NOT_RUN`, no bloquees las pruebas host si son independientes. No inventar una URL pública ni entrar en Hostinger. **No cambiar el bundled asset por el release `rN-hash`**, porque `bundled_restrictions.dart` acepta actualización por versión con prefijo de fecha `AAAA.MM.DD` y solo en instalaciones sin release publicado. Si se quiere semilla offline actualizada, diseñar un artefacto de semilla **derivado de la misma definición legal**, con versión `AAAA.MM.DD-*`, bajo aprobación del director; fuera de R1 salvo que exista una conversión ya probada y el cambio esté literalmente contenido en el alcance. No convertir una prueba de sync en promesa de actualización offline a cualquier APK instalada.

**R1-E. Alcance y advertencia sin rediseño:** texto mínimo en puntos de consumo afectados de la regla Bogotá: «Pico y placa urbano general. No evalúa retorno regional, corredores de ingreso ni excepciones individuales». Respetar tipografía/jerarquía existente y tests/goldens. No añadir pantalla, geolocalización, permisos personales ni cambiar «Puede circular» para todas las ciudades sin orden. En 2/16 nov festivos: fuera de alcance retornar `UNKNOWN` o avisar inequívocamente que el resultado urbano NO aplica al retorno, según la ruta existente; no afirmar permiso regional general. Inspeccionar HOME, DETALLE y VIAJE; si cualquiera comunica permiso universal sin salvedad verificable, `SCOPE_UI_UNSAFE` y reportar localmente como bloqueado de aceptación (el data/QA independiente puede continuar). Proteger tests de comportamiento ya aprobado en otras ciudades.

**R1-F. Código mínimo:** priorizar dato versionado + 1 test Laravel y 1 test Flutter de integración + la nota de alcance solo donde falte. Cambiar `RestrictionEngine`, modelos de garaje, schema Drift, categorías o `staleAfter` de otras ciudades está PROHIBIDO. No modificar `scripts/compile_pico_operational_catalog.py`, worklist 31/55, app shell ni cámara. Si el pub local requiere refactor masivo, detener `BLOCKED_SCOPE` con punto y alternativa simple demostrada; no improvisar un framework de legalidad. No instalar dependencia.

## 4. Matriz exacta de resultados en la zona America/Bogota (tests obligatorios)

Usar al menos placas sintéticas (`ABC123`, `ABC126`, `ABC120`, `ABC121`; nunca placas de usuario), categoría `car/private` jurisdicción Bogotá y `isHoliday` según `ColombiaHolidayCalendar` existente. Se espera:

| Caso | Fecha/hora local 2026 | Placa | Resultado urbano general esperado |
|---|---|---|---|
| U01 | lunes **09-nov 08:00** (impar) | ABC126 (6) | RESTRICTED 06:00–21:00 |
| U02 | lunes **09-nov 08:00** | ABC123 (3) | ALLOWED *solo regla general urbana* |
| U03 | martes **10-nov 08:00** (par) | ABC123 (3) | RESTRICTED 06:00–21:00 |
| U04 | martes **10-nov 08:00** | ABC126 (6) | ALLOWED *solo urbano* |
| U05 | martes **10-nov 05:59** | ABC123 | sin restricción urbana por horario, sin permiso universal |
| U06 | martes **10-nov 21:00** | ABC123 | sin restricción urbana por horario, sin permiso universal |
| U07 | domingo **08-nov 08:00** | ABC126 | no hay pico ordinario urbano; sin inferir restricciones especiales |
| U08 | lunes festivo **16-nov 14:00** | ABC126 | ordinario NO aplica; **retorno regional NO EVALUADO**. Nunca permiso regional absoluto |
| U09 | lunes festivo **02-nov 17:00** | ABC123 | ordinario NO aplica; retorno regional distinto, no asignar ALLOWED global |
| U10 | lunes **30-nov 09:00** (par) | ABC121 (1) | RESTRICTED urbano |
| U11 | martes **01-dic 09:00** | ABC121 | STALE/UNKNOWN para reglas nov; nunca extender nov a diciembre |
| U12 | servicio `car/taxi` Bogotá en noviembre | placa sintética | NO importar horario ni dígitos de `car/private`; conservar dataset taxi independiente como STALE si vence |

Además P1-negativos: retorno regional sin contexto de ruta no certificado; `digits=null`/placa inválida UNKNOWN; versión corrupta no borra last-good; 1 cobertura conocida-vacía mantiene semántica previa; cambio de bundle NO sustituye release remoto válido; actualización de Bogotá NO reemplaza motos/taxis; ninguna copia de reglas externas no verificadas.

**Atención a la diferencia fuente: los días impares se restringe 6–0; NO invertir la paridad**. Fecha 9-nov es impar, 10-nov par. `Bogota.gov.co` en su cuadro indica quién **puede** circular, mientras el motor codifica quién está **restringido**. Es una de las fuentes históricas de errores de la otra IA.

## 5. Verificación 10 controles reales, no ritual de «diez pasadas»

1. `SOURCE`: URL oficial 2026-11, fechas, evidencia y versión real sin añadir 31 datos externos.
2. `BASELINE`: branch/HEAD/worktrees/WIP 101 protegidos; diff contra HEAD remoto sin mezclar PR79/docs.
3. `CONTRACT`: PHP validator/schema1 `vehicleKind=car`, `serviceType=private`, dos reglas y notas de alcance editorial externo.
4. `PUBLISH_SELECTIVE`: prueba Laravel publicación local conserva otras ciudades y coberturas `car/taxi` y `motorcycle/private` de Bogotá.
5. `MANIFEST`: versión y SHA reales, integridad bytes, rollback con disco de test.
6. `DRIFT_SYNC`: JSON real PHP → Dart parser/Drift → motor y último bueno tras corrupto, prueba integrada.
7. `DATES`: U01–U12 con cruce de festivo regional, 21:00, 30-nov, 01-dic y estados de incertidumbre correctamente etiquetados.
8. `UX`: Inicio/Detalle/Viaje no presentan autorización universal ni alteran UX aprobada; screenshots/goldens solo si realmente ejecutados.
9. `REGRESSION`: pruebas PHP focal, tests Flutter focal, `flutter analyze`/`dart format`, `pint --test` focal y vecinos; documentar SKIP si entorno no disponible, no renombrar a PASS.
10. `BOUNDARY`: nada en producción, sin CI remoto manual, sin secrets, sin WIP destruido, un ZIP íntegro con SHA independiente.

**No repetir:** M3-X01 synthetic bridge; QA física de firma fallida ya diagnosticada (solo reabrir con APK firmada candidata verificada); importador 73/219, inventario DANE/RUNT, auditoría extensa de 31/55, 20 revisiones del mismo prompt.

## 6. Git y límites operativos

- Ejecutar únicamente en una rama nueva de lote sobre fuente moderna verificada, preferible `feat/PICORADAR-R1-bogota-nov2026-real-e2e`, en clon/worktree aislado. NO tocar `main`, PR71, PR79, historical C:, WIP ni producción.
- **Push normal y PR Draft SOLO** si: branch confirmada; políticas lo permiten; costo/uso de Actions y límites habilitados/verificados para evitar factura; diffs, tests y datos sensibles revisados. Si costos CI o permisos no verificables, mantener commit local + patch completo + ZIP. Ningún merge, force, deploy, release activo ni cambios Hostinger.
- El cambio permitido es la definición legal de Bogotá noviembre (fuente comprobada) y tests/integración mínima. Si decides una actualización del bundled asset, documentar por qué es compatible con semilla por fecha y con `DatasetSyncService`; no borrar ni actualizar en bloque las 11 coberturas ajenas.
- Evitar pruebas que requieran internet externo, RUNT autenticado o cuentas; la captura de fuente oficial puede respaldarse en enlace/copia pública, registrar `SOURCE_NOT_REFETCHED` si no hay acceso en tu entorno, sin atribuir hash web no capturado.
- **Stop real:** `BLOCKED_SHA_DRIFT`, `BLOCKED_ACTIVE_LOT`, `BLOCKED_LEGAL_CONFLICT`, `SCOPE_UI_UNSAFE`, `BLOCKED_PRODUCTION_SIDE_EFFECT`, `BLOCKED_COST`, `BLOCKED_ENV`. Ante un bloqueo, entregar de todas formas resultado parcial útil y evidencia de lo ejecutado; no pedir un prompt nuevo por fallos triviales.

## 7. Un ZIP de evidencias, todo en un solo archivo

Crear bajo `D:\codex\_REPORTES\PicoRadar\` o bajo directorio temporal seguro en D: validado. **UN ZIP** denominado `PICORADAR_R1_BOGOTA_NOV2026_REAL_E2E_EVIDENCIA_UNICA.zip`, contenido sugerido:

- `FINAL_REPORT.md`: result `PASS_SCOPED_REAL_E2E | PARTIAL_CODE | BLOCKED_*`; alcance urbano, límites, errores, archivos, SHA/branch, cambios producto, hechos jurídicos.
- `REAL_SOURCE_CLAIMS.csv`: SOLO este acto/normativa y campos usados (no 31 medidas), URL, autoridad, artículo/comunicado, vigencia, observación.
- `ACTUAL_LARAVEL_RELEASE.json`: bytes reales de release aislado (sin datos personales), o explicar NO_RUN.
- `ACTUAL_MANIFEST.json`: bytes reales de manifiesto de Laravel de prueba, con SHA, o NO_RUN.
- `FLUTTER_IMPORT_RESULT.md` con resultado U01–U12, fuente de bytes y SHA.
- `QA_10_CONTROLS.csv`: por caso PASS/FAIL/NOT_RUN con comando, prueba e identidad del artefacto.
- `COMMANDS_AND_LOGS.txt`: comandos relevantes, stdout/stderr, exit codes.
- `GIT_DIFF.patch` + `GIT_STATUS.txt` + `CHANGED_FILES_SHA256.csv` y source/target SHAs.
- `MANIFEST.json` hash SHA256+tamaño para cada miembro (sin auto-referencia), `MANIFEST.sha256`, prueba CRC/ZIP y extracción independiente.

Excluir `.env`, credenciales, teléfonos, placas reales, WIP, backups únicos, APK gigantes sin autorización. **El informe externo de Codex debe traer SOLO este enlace ZIP y resumen de máximo 12 líneas**, `TASK_ID`, `RESULT`, `R1_BOGOTA_URBAN=PASS/FAIL/NOT_RUN`, `PHP_PUBLISH_LOCAL`, `FLUTTER_CONSUME_SAME_BYTES`, `DEV_UI`, `REGIONAL_UNSUPPORTED`, `CI`, `PRODUCT_RELEASE=NO`, `ZIP_SHA256` y **`NEXT=CHATGPT_DIRECTOR`**.

## 8. Condición de aceptación del director — NO negociar por un PASS fácil

R1 NO está terminado por 12 tests sintéticos, ni por un JSON escrito a mano, ni por una versión Laravel sin consumo Flutter. **R1_DONE solo si:** fuente oficial Bogotá Nov 2026 comprobada; release selectivo local real con otra cobertura preservada; mismo SHA de JSON/manifest consumido por importador y motor Drift; casos U01–U12 y estados protegidos; riesgo de retorno regional explicitado en todos los consumidores necesarios; pruebas focales PASS; sin pérdida WIP; ZIP único íntegro. Si falta QA física, distinguir `R1_HOST_E2E_PASS` y `R1_PHYSICAL_NOT_RUN`: NO aprobar release comercial.

**Después de R1:** ChatGPT audita el ZIP real y aprueba expansión R2 por bloques de autoridades/categorías, no otra ronda de auditoría del prompt. Priorizar después Bogotá taxis del mes actual, Medellín particular y moto del decreto 1490/2026, Cartagena particular/moto con especial 24h aún pendiente, y transporte especial/carga como carriles con contrato propio. Reutilizar los 35 contrastes y 31/55 sin repetir investigación.

**FIN DE ORDEN — EJECUTA SOLO R1. Un resultado funcional verificable o un bloqueo preciso, no un reporte de investigación.**
