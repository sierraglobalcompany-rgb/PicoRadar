# CODEX LUNA — PICORADAR R1 V2 — BOGOTÁ NOVIEMBRE 2026, INTEGRACIÓN OFICIAL REAL SIN PÉRDIDA DE COBERTURAS

**TASK_ID INMUTABLE:** `PICORADAR-R1-BOGOTA-NOV2026-REAL-END2END-20261109`  
**VERSION REVISADA:** `R1_V2_CORREGIDA_20261109`. SUSTITUYE solo la orden R1 V1 de nombre `CODEX_LUNA_PICORADAR_R1_BOGOTA_NOV2026_E2E_REAL_20261109.md`; NO cambia `TASK_ID`, no reabre R1, N1, M3-X01 ni crea otra ejecución. Si R1 V1 ya está EN CURSO, inspeccionar primero lo ejecutado, conservar el trabajo válido y aplicar SOLO las correcciones siguientes sin reejecutar lo cerrado. Si la V1 ya está terminada, entregar evidencia para auditoría ChatGPT antes de nuevo trabajo.
**RAZÓN DE V2:** la publicación Laravel sustituye la **jurisdicción entera**, no una cobertura individual (`RestrictionPublicationService::publishVersions` usa `selected[$key]->payload` en vez de fusionar coverages); además, `RestrictionEngine._matchRule` considera `digits=null` o vacíos como regla que aplica **a todas las placas**, no `UNKNOWN`. La V1 fijaba un caso negativo incorrecto. Esta V2 establece composición completa y test de no regresión.

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
- PR #79 `OPEN/DRAFT` solo documentos; **no mergear docs para traer el prompt**. El Plan Maestro tiene §AN, §AO histórico y §AP (R1 V2 vigente). Se encuentra en `docs/plans/PICORADAR_PLAN_MAESTRO_V2_NACIONAL_20261107.md` de PR79.
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

**R1-B. Publicación LOCAL con preservación de jurisdicción completa — PROCEDIMIENTO OBLIGATORIO.** Emplear SQLite de pruebas y `Storage::fake`/discos temporales; ningún archivo/DB/manifest en producción, Hostinger ni instalaciones de usuario. **No asumir que el publicador fusiona coberturas:** `RestrictionPublicationService::publishVersions` sustituye **la entrada completa** de `jurisdictions[]` de Bogotá con `RestrictionRuleVersion.payload`; un draft únicamente `car/private` ELIMINARÍA `car/taxi` y `motorcycle/private` de Bogotá.

**Secuencia técnica cerrada que Codex debe implementar y probar:**
1. **Preparar baseline local real de prueba:** utilizar los bytes del asset existente `mobile/assets/datasets/restrictions/restrictions_v1.json` **sin editarlo**; persistirlo como release inicial en SQLite/discos fake reutilizando validación y publicador ya existentes. Confirmar `7` jurisdicciones y `12` coberturas en el baseline, incluido Bogotá `car/private`, `car/taxi` y `motorcycle/private` conocida-vacía. Si el entorno ya tiene un baseline seguro de test que conserva exactamente esos contenidos, REUTILIZARLO; no añadir un importador nuevo.
2. **Construir versión íntegra de Bogotá:** copiar el objeto `co-dc-bogota` del baseline, reemplazar SOLAMENTE su cobertura `car/private` por la nueva de noviembre (`two parity rules`), conservar textualmente/canónicamente sin cambiar absolutamente ningún campo de las coberturas `car/taxi` y `motorcycle/private` (incluidos `verifiedAt`, `staleAfter`, `sourceUrls`, `rules=[]`, y orden si el encoder lo conserva). Sin alterar nombre o ID de jurisdicción. Comprobar que las otras seis jurisdicciones son equivalentes al baseline **campo por campo** y que el total sigue en `7`/`12`.
3. **Validar/publicar en entorno aislado:** `RestrictionRuleVersionService::createDraft($jurisdiction, $fullBogotaPayload, $actor)` → `validate()` → `RestrictionPublicationService::publish([$versionId], $expectedPublicationRevision, $actor)`, reutilizando `DatasetReleaseValidator`, `DatasetPublisher`, `ManifestPublisher` y la fuente oficial activa de test. No llamar B07 con un CSV parcial que transforme una sola cobertura en **toda** la ciudad. El `currentPayload` del publicador requiere baseline para probar preservación; si no existe, falla el gate y NO fabricar evidencia. Los datos anteriores vencidos de otras categorías siguen vencidos; está PROHIBIDO cambiar sus TTL para pasar validaciones.
4. **Comprobación adversarial explícita:** generar en una prueba negativa un draft de Bogotá solo con `car/private`, demostrar que su publicación eliminaría las otras dos coberturas, pero ejecutar la demostración en transacción/fake separado con rollback **sin alterar el artefacto de salida**; confirmar que la propuesta final íntegra preserva las 12 coberturas. Si no se necesita ejecutar la publicación destructiva para demostrar la causa, basta una aserción estructural sobre el algoritmo existente más un test que rechace el payload incompleto; no escribir de más.
5. **Evidencia real:** exportar **exactos bytes** de release que el Laravel aislado dejó en `datasets/restrictions/...`, y manifiesto escrito en `manifest/v1/manifest.json`, al ZIP, con SHA-256 y `version` reales. La versión resultante `rN-hash` no debe hacerse pasar por versión de semilla `AAAA.MM.DD-*`. Aislar todo con `Storage::fake` configurado; el reporte debe declarar si se utilizó fixture, backend de prueba o webserver local, no decir 'producción'.

**Gate B1:** los metadatos de resumen de versión pueden conservar como mínimo el `staleAfter` antiguo de taxi/moto; NO convertir toda Bogotá en cobertura fresca por actualizar `car/private` ni alterar frescura ajena. `BOG_NOV_CAR=2 rules; BOG_TAXI=UNCHANGED; BOG_MOTO_KNOWN_EMPTY=UNCHANGED; OTHER_6_JURISDICTIONS=UNCHANGED; TOTAL=7 jurisdictions/12 coverages; 0 leaked writes`. Si cualquiera falla, `R1_PUBLISH_LOCAL=FAIL`, no certificar E2E.


**R1-C. Flutter consume los MISMOS BYTES de la publicación Laravel local, nunca un JSON reconstruido a mano:** después de B1, exportar al directorio de evidencias aislado los archivos de publicación generados. El test Dart debe abrir **ese archivo exacto**, verificar su SHA con el `manifest`, usar el `DatasetSyncService` existente con respuesta HTTP fake o adaptador ya probado, importar a Drift y evaluar `RestrictionEngine` y UI/estado. Registrar `SHA_PHP_RELEASE == SHA_DART_INPUT == SHA_MANIFEST_ENTRY`; si el test Dart usa un payload parecido escrito manualmente, `R1_HOST_E2E=NOT_PROVEN`. Si las pruebas se ejecutan separadas, indicar rutas deterministas de input/output y comandos para conectarlas, sin crear librería/servicio. Acreditar idempotencia, rollback y last-good al fallar SHA/JSON corrupto, además de la permanencia de las **12 coberturas**. No reejecutar M3-X01.

**Gate C1:** `REAL_PHP_BYTES_TRANSFERRED=YES` + `SAME_SHA_3_WAYS=YES` + `DRIFT_IMPORT=PASS` + `ENGINE_CHECK=PASS` + `NO_LOSS_OF_BOGOTÁ_TAXI_MOTO=PASS`. Si la herramienta no puede exportar bytes desde el test de PHP hacia el harness Flutter, entregar `PARTIAL_BLOCKED_CROSS_LANGUAGE` y el ZIP con bytes y comandos; jamás sustituir el requisito por pruebas sintéticas inconexas. 

**R1-D. Producto en APK/dev sin publicación remota:** el flujo de sincronización dev debe poder cargar ese manifest/release de prueba contra servidor LOCAL/AISLADO con mismo SHA. Si no hay acceso funcional al dispositivo Mi A3 por firma/JNI, preferir prueba de widget/dev emulador o test de sync real, registrar `QA_PHYSICAL_NOT_RUN`, no bloquees las pruebas host si son independientes. No inventar una URL pública ni entrar en Hostinger. **No cambiar el bundled asset por el release `rN-hash`**, porque `bundled_restrictions.dart` acepta actualización por versión con prefijo de fecha `AAAA.MM.DD` y solo en instalaciones sin release publicado. Si se quiere semilla offline actualizada, diseñar un artefacto de semilla **derivado de la misma definición legal**, con versión `AAAA.MM.DD-*`, bajo aprobación del director; fuera de R1 salvo que exista una conversión ya probada y el cambio esté literalmente contenido en el alcance. No convertir una prueba de sync en promesa de actualización offline a cualquier APK instalada.

**R1-E. Alcance y advertencia sin rediseño (contrato determinado, NO cambiar semántica del motor global):** el motor devuelve `ALLOWED` cuando `coverageKnown=true` y ninguna regla urbana aplica, incluido festivo o placa no restringida. Ese estado **significa exclusivamente que NO coincide con la regla urbana general consultada**, NO autorización para circular por la región ni exención legal. Conservar el enum y las pruebas existentes de `known-empty`; no convertir `ALLOWED` global a `UNKNOWN`. Para Bogotá particular en NOV-2026, añadir o reutilizar un único texto de alcance contextual, visible y accesible junto al resultado en Inicio, Detalle y Viaje **en cada consumidor que pueda mostrar 'Puede circular'**: «Solo pico y placa urbano general. No evalúa retorno regional por corredores ni excepciones individuales». Si ya hay aviso equivalente demostrado, no duplicarlo. Para festivos 02 y 16 nov, debe comunicar sin ambigüedad «Restricción ordinaria urbana no aplica; retorno regional no evaluado», aun si internamente el motor produce `allowedNoRestriction`. No cambiar `ALLOWED` a UNKNOWN a ciegas; si un consumidor no permite acotar el mensaje sin romper el diseño aprobado, `SCOPE_UI_UNSAFE` y **no aceptar R1 para disponibilidad al usuario**. Respetar tipografía, accesibilidad y jerarquía existente; sin geolocalización ni pantalla nueva. Comprobar Inicio/Detalle/Viaje y regresión otras ciudades.

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

Además P1-negativos (cuidado con la semántica APROBADA): retorno regional sin contexto de ruta NO se certifica; **`digits=null` o `digits=[]` significan regla SIN FILTRO DE PLACA y se aplican a todas las placas** según el motor existente, por tanto una regla `restrict` activa con `digits=null` produce `RESTRICTED` y NUNCA `UNKNOWN` por esa sola causa; **placa inválida sin dígito en una regla que SÍ requiere `digits` no vacíos produce `UNKNOWN`**. Cobertura conocida-vacía fresca conserva `ALLOWED` por diseño; cobertura inexistente o vencida `UNKNOWN/STALE` según caso; versión corrupta no borra last-good; release publicado no se sustituye por semilla; actualización Bogotá NO reemplaza taxi/moto; ningún dato de otra IA habilita motor/publicación.

**Atención a la diferencia fuente: los días impares se restringe 6–0; NO invertir la paridad**. Fecha 9-nov es impar, 10-nov par. `Bogota.gov.co` en su cuadro indica quién **puede** circular, mientras el motor codifica quién está **restringido**. Es una de las fuentes históricas de errores de la otra IA.

## 5. Verificación 10 controles reales, no ritual de «diez pasadas»

1. `SOURCE`: URL oficial 2026-11, fechas, evidencia y versión real sin añadir 31 datos externos.
2. `BASELINE`: branch/HEAD/worktrees/WIP 101 protegidos; diff contra HEAD remoto sin mezclar PR79/docs.
3. `CONTRACT`: PHP validator/schema1 `vehicleKind=car`, `serviceType=private`, dos reglas y notas de alcance editorial externo.
4. `PUBLISH_SELECTIVE`: prueba Laravel debe demostrar que publicar solo una cobertura BORRARÍA Bogotá taxi/moto según código; propuesta FINAL incluye las tres coberturas y preserva las otras 6 ciudades: **7 jurisdicciones, 12 coverages**, sin retocar TTL ajenos.
5. `MANIFEST`: versión y SHA reales, integridad bytes, rollback con disco de test.
6. `DRIFT_SYNC`: JSON/manifest exactos escritos por PHP → mismo SHA triple en Dart → parser/Drift → motor/UI y último bueno tras corrupto; jamás fixtures Dart reescritas a mano.
7. `DATES`: U01–U12 con festivos de retorno regional, corte 21:00 y 01-dic; negativos `digits=null` (RESTRICTED si aplica la regla general) vs placa inválida con `digits` no vacío (UNKNOWN), known-empty ALLOWED y stale conservados.
8. `UX`: Inicio/Detalle/Viaje no presentan autorización universal ni alteran UX aprobada; screenshots/goldens solo si realmente ejecutados.
9. `REGRESSION`: pruebas PHP focal, tests Flutter focal, `flutter analyze`/`dart format`, `pint --test` focal y vecinos; documentar SKIP si entorno no disponible, no renombrar a PASS.
10. `BOUNDARY`: nada en producción, sin CI remoto manual, sin secrets, sin WIP destruido, un ZIP íntegro con SHA independiente.

**No repetir:** M3-X01 synthetic bridge; QA física de firma fallida ya diagnosticada (solo reabrir con APK firmada candidata verificada); importador 73/219, inventario DANE/RUNT, auditoría extensa de 31/55, 20 revisiones del mismo prompt.

## 6. Git y límites operativos

- Ejecutar únicamente en una rama nueva de lote sobre fuente moderna verificada, preferible `feat/PICORADAR-R1-bogota-nov2026-real-e2e`, en clon/worktree aislado. NO tocar `main`, PR71, PR79, historical C:, WIP ni producción.
- **Push normal y PR Draft SOLO** si: branch confirmada; políticas lo permiten; costo/uso de Actions y límites habilitados/verificados para evitar factura; diffs, tests y datos sensibles revisados. Si costos CI o permisos no verificables, mantener commit local + patch completo + ZIP. Ningún merge, force, deploy, release activo ni cambios Hostinger.
- El cambio permitido es la definición legal de Bogotá noviembre (fuente comprobada) y tests/integración mínima. Si decides una actualización del bundled asset, documentar por qué es compatible con semilla por fecha y con `DatasetSyncService`; no borrar ni actualizar en bloque las 11 coberturas ajenas.
- Evitar pruebas que requieran internet externo, RUNT autenticado o cuentas; la captura de fuente oficial puede respaldarse en enlace/copia pública, registrar `SOURCE_NOT_REFETCHED` si no hay acceso en tu entorno, sin atribuir hash web no capturado.
- **Stop real:** `BLOCKED_SHA_DRIFT`, `BLOCKED_ACTIVE_LOT`, `BLOCKED_LEGAL_CONFLICT`, `BLOCKED_DATA_LOSS`, `SCOPE_UI_UNSAFE`, `BLOCKED_PRODUCTION_SIDE_EFFECT`, `BLOCKED_COST`, `BLOCKED_ENV`. Ante un bloqueo, entregar de todas formas resultado parcial útil y evidencia de lo ejecutado; no pedir un prompt nuevo por fallos triviales.

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

R1 NO está terminado por 12 tests sintéticos, por un JSON escrito a mano ni por publicar Bogotá parcialmente borrando taxi/moto. **`R1_HOST_E2E_PASS` solo si:** fuente Bogotá Nov 2026 confirmada; baseline real 7/12 sembrado en ENTORNO DE PRUEBAS; `RestrictionPublicationService` publicó una propuesta **de jurisdicción íntegra** (Bogotá car privado nuevo, taxi y moto preservados); resto 6 ciudades intactas; bytes de release Laravel y manifiesto con SHA exacto consumidos por Sync/Drift/Engine Flutter; U01–U12 y negativos de `digits=null` vs placa inválida correctos; mensajes urbanos/regionales inequívocos en los consumidores que existan; regresiones focales PASS; sin pérdida WIP; ZIP único validado. Distinguimos `R1_HOST_E2E_PASS` de `R1_DEV_APP_USABLE` (UI ejecutada sobre release de test) y de `R1_PHYSICAL_NOT_RUN`; **ninguno equivale a release comercial ni cobertura nacional**. Si fuente, manifiesto, datos o QA no están realmente disponibles, registrar `PARTIAL/NOT_RUN` con punto preciso, nunca falsear PASS.

**Después de R1:** ChatGPT audita el ZIP real y aprueba expansión R2 por bloques de autoridades/categorías, no otra ronda de auditoría del prompt. Priorizar después Bogotá taxis del mes actual, Medellín particular y moto del decreto 1490/2026, Cartagena particular/moto con especial 24h aún pendiente, y transporte especial/carga como carriles con contrato propio. Reutilizar los 35 contrastes y 31/55 sin repetir investigación.

**FIN DE ORDEN — EJECUTA SOLO R1 V2 CORREGIDA. No ejecutar V1 en paralelo. Un resultado funcional verificable, sin pérdida de taxi/moto, o un bloqueo concreto con ZIP único.**
