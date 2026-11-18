# CODEX LUNA — PICORADAR · V3 · ÚNICO MACROBLOQUE DE CIERRE FUNCIONAL N1 → OTA QA → APK DEV

**TASK_ID:** `PICORADAR-N1-V3-CIERRE-VERTICAL-SIN-PINGPONG-20261115`  
**QUIÉN EJECUTA:** Codex Luna, en Windows autorizado y SIN escritor concurrente.  
**QUIÉN DIRIGE/ACEPTA:** ChatGPT Director; el propietario decide publicación y operaciones irreversibles.  
**SUSTITUYE TOTALMENTE:** `CODEX_LUNA_PICORADAR_MACROBLOQUE_CIERRE_N1_V2_AUDITADO_20261115.md` y todo prompt previo de este cierre. **EJECUTAR SOLO V3 UNA VEZ.**  
**PROPÓSITO:** avanzar de código N1 recuperado a **motor Flutter integrado y verificado, OTA QA realmente validada, migraciones comprobadas y APK DEV N1 nueva entregable**. La expansión de datos oficiales comprobados es acotada y **NO** bloquea el cierre técnico. No confundir APK de laboratorio con release autorizado.

## A. CONTRATO DE PRODUCTO Y REGLAS (no decidir de nuevo)

- **Un solo motor nacional de restricciones `schemaVersion=2`** en Flutter/Laravel: autoridad/departamento/municipio/ciudad/pueblo, modalidad (carro, moto, taxi, etc.), servicio, placa, días, horarios (incluido `fullDay`), vigencia, festivos, ámbito, condiciones y exenciones **solo expresas en fuente**. No motor, APK ni lógica hardcodeada por municipio. Ampliaciones ordinarias por **dataset versionado/habilitable/deshabilitable + OTA**, sin cambiar APK.
- **Toda ausencia, ambigüedad de cobertura espacial/exenciones, fuente sin soporte, dato caduco o modalidad no investigada = `UNKNOWN/STALE`**, NUNCA permiso `ALLOWED`. Estado de «sin restricción» solo ante prueba institucional positiva y ámbito certificado. Coberturas LAB existentes son `partial` (no convertir a `complete`). `staleAfter` es revisión editorial, no fin legal.
- **Autoridad:** seguridad/privacidad/autorizaciones > `AGENTS.md` y baselines vigentes (leer los dos DOCX y los flujos pertinentes según AGENTS, sin auditoría total) > contratos concretos > seis leyes [PingPongLaw](https://github.com/sierraglobalcompany-rgb/PingPongLaw/blob/84e961cadf482d234f4c0ee2ca60e8c7e9b388e8/docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md): L1 KISS/Ponytail, L2 antirruido, L3 causa raíz, L4 UI fiel, L5 pruebas del árbol real, L6 antipingpong. No reinstalar skills/hooks ni rehacer las 10+10 auditorías ya realizadas.
- **Prohibido:** tocar WIP ajeno, `reset --hard`/`clean`, force-push, merge, rebase de rama compartida, producción/Hostinger/CDN/DB reales, actualizar firma release, cambiar permisos o credenciales, publicar datos LAB como oficiales, desinstalar/borrar datos del Mi A3, enviar placas/GPS/documentos/secretos/bundle privado a ZIP o GitHub, cambiar arquitectura/`schema3`, actualizar dependencias sin causa.
- **GitHub sí es objetivo de continuidad, pero hay `HOLD_SECURITY` histórico.** NO subir historial/producto hasta resolver evidencia del hallazgo y verificar que no se expongan secretos o enlaces privados; **sin bypass ni declarar seguridad resuelta por suposición**. Si no se puede cerrar ese gate en este lote, entregar patch+ZIP íntegro y `GITHUB_PRODUCT=HOLD_SECURITY`. No sustituir seguridad por comodidad. **No tocar el PR documental #79; ChatGPT Director lleva la documentación.** Un push de producto solo si el hold está efectivamente resuelto y el repositorio/AGENTS y autorización vigente lo permiten; entonces **rama nueva de trabajo + PR Draft, NUNCA merge ni release**, con SHA y URL. Un rechazo 403 se reporta una vez, sin reintentos circulares.

### Evidencia congelada que NO debes repetir

```text
REPO=sierraglobalcompany-rgb/PicoRadar
RC2_HEAD=7e2e1f3f311b18e29f63d3a5e05e9439a11c4289
RC2_TREE=e312c7632fce4c43f9419cba60903e7420c46d85
N1R1_TREE=3980778395ade9957e9ddf5097916ac814f2a1e5
N1R1_HEAD_LOCAL_REPORTADO=0e596a659e14f98bf98c6c0f74e23288a4bf3fe8
N1R1_PATCH_SHA256=5fa7e7a6cf199f60138d5b58a9e1c0bc3823e47f27b785aedcea551e83be577f
N1R1_ZIP_SHA256=857bb28d85c3108b83e0b5b5ca03b81b1aee021ffe88278c0e71cd5d3465b744
N1_DATA_LAB=14_AUTORIDADES/33_CODIGOS/22_COBERTURAS_PARTIAL/120_REGLAS
N1_PHP=13_TESTS_37_ASSERTIONS_PASS_REPORTED
N1_PYTHON=16_TESTS_PASS_REPORTED
N1_DART=NOT_RUN_ENV
N1_APK=NO_EXISTE
PRODUCT_RELEASE=NO_GO
```

Estas pruebas PHP/Python y árbol ya se verificaron **en su ámbito**. No repetirlas sin modificación de contratos/bytes relevante. No reiniciar V6R4/RC1/RC2/RC3/N1-R1, ni repetir inventario de 1.104 municipios, ni probar una APK vieja como si incluyera N1. El ZIP de continuidad con bundle RC2 + parche N1 está en custodia del usuario; **no presumas acceso a adjuntos de ChatGPT desde `D:\`**.

## B. F0 — PREPARACIÓN ÚNICA: FUENTE REAL Y FLUTTER (sin preflight infinito)

**F0.1** En el directorio real del repositorio (`D:\codex\<proyecto>` si existe; descubrir ruta una sola vez) registrar `git status --porcelain=v1`, `git rev-parse HEAD`, `HEAD^{tree}`, `git write-tree`, `git diff --name-only` y `git diff --cached --name-only`. Detectar trabajo concurrente. Hay **tres entradas válidas**:

1. **A:** `HEAD^{tree}=N1R1_TREE`, commit local N1 presente.
2. **B:** `HEAD=RC2_HEAD` y `git write-tree=N1R1_TREE` (23 rutas staged), sin edición sin stage ajena. **Este estado staged ya se reconstruyó independientemente: NO lo confundas con falta de N1.**
3. **C:** si A/B no coinciden o hay WIP ajeno, usar únicamente **clon aislado nuevo** sobre `RC2_BASE_full-final.bundle` disponible localmente + `RECOVERY/BASE_TO_HEAD.patch` extraído del ZIP N1; `git apply --check`, `git apply`, `git add -A` y `git write-tree` = `N1R1_TREE` exacto. Jamás regenerar/parchear encima de `main` remoto ni usar `git add -A` en el trabajo ajeno.

Si no hay árbol N1 ni paquete local, `BLOCKED_INPUT` verdadero, no falsear restauración. Si otro escritor está trabajando, proteger checkout ajeno; se permite aislado **solo si no colisiona sobre los mismos recursos de publicación/emulador/repositorio remoto**. Usa un solo árbol de implementación estable, no crees cinco copias de trabajo.

**F0.2** Buscar Flutter **3.47.9 / Dart 3.13.7** una vez: `PATH`, SDK usado por build RC2, rutas conocidas y `D:\codex\_tools`; validar versión y dependencias existentes con `flutter pub get --offline` en `mobile/` si procede. Si falta SDK, solo **una alternativa gratuita, aislada y oficial** si el host dispone de espacio/red y no altera herramientas globales. No bajar SDK varias veces ni cambiar `pubspec.lock`, plugins, Gradle, Android SDK global o antivirus para resolver un problema de entorno. Registrar comando y error `NOT_RUN_ENV` si no se dispone: **seguir F2 servidor y datos independientes**, no devolver solo un informe de preflight.

**F0.3** Antes de tocar rutas, leer instrucciones `AGENTS.md`, los dos baselines exigidos y los contratos específicos de motor, Drift, OTA y Android. El flujo existente domina; **no inventar nuevos endpoints, panel, motor o DAO**. Una sola lectura focal, no auditoría histórica.

## C. F1 — CORREGIR Y CERRAR EL CONSUMIDOR REAL DEL MOTOR (P0)

**F1.1** Con Flutter, ejecutar UNA selección focal, desde `mobile/`, de los cinco tests N1 ya escritos + el test de Viaje existente:

```text
test/features/pico_placa/data/restriction_g2_schema_test.dart
test/features/pico_placa/domain/restriction_g2_typed_engine_test.dart
test/features/pico_placa/domain/restriction_day_evaluation_test.dart
test/features/pico_placa/domain/city_restriction_summary_test.dart
test/features/pico_placa/presentation/pico_detail_screen_test.dart
test/features/trip/application/trip_restriction_evaluation_test.dart
```

Usa `flutter test <ruta>` o selección conjunta soportada; registra exit code, versión y TREE. **No crear un test duplicado de countdown:** `pico_detail_screen_test.dart` YA tiene el caso `full-day countdown ends at the next 06:00 anchor`. Reusar; añadir borde 05:59/06:00 solo si ese contrato permanece sin comprobar.

**F1.2 Riesgo causal A — fecha de festivo ancla:** `mobile/lib/features/trip/application/trip_restriction_evaluation.dart` crea `ColombiaHolidayCalendar`, pero el `RestrictionContext` de `at()` **no** pasa `isHolidayOnDate: holidays.isHoliday` al motor. En el test EXISTENTE de Viaje añadir **dos aserciones causales, no suite nueva**:

- Regla sintética schema2 `fullDay:true`, `startMinute=endMinute=360`, `weekdays={viernes}`, `appliesOnHolidays=false`, anclada viernes **2026-11-13 06:00**, consulta sábado **2026-11-14 02:00 America/Bogota** (`2026-11-14T07:00:00Z`). Placa que coincida; `coverageKnown=true`, `partial`, `dataIsStale=false`, `staleAfter` posterior al 15-nov y que cubra el día consultado, `nowUtc` válido. Con hechos suficientes, debe dar `instantStatus=RESTRICTED` y `engineReason` coherente; si devuelve UNKNOWN solo por calendario del día anterior, test RED reproduce omisión.
- Caso **ancla FESTIVA**, usar lunes **2026-11-16** (ColombiaHolidayCalendar lo marca festivo) con consulta martes 17 02:00, `weekdays={lunes}`, `appliesOnHolidays=false`. No se debe emitir `RESTRICTED` por asumir que la ancla es no festiva. Si la cobertura sigue parcial/ambigua, `UNKNOWN` es correcto y nunca convertirlo artificialmente en `ALLOWED`.

Si falla por la omisión concreta, pasar `isHolidayOnDate: holidays.isHoliday` en **ese consumidor**, sin crear nuevo calendario. Si ya pasa, conservar código. Los fixtures nunca deben expirar antes de la fecha de consulta ni exigir hechos desconocidos que invaliden el oráculo.

**F1.3 Riesgo causal B — vigencia de ventana anclada:** mismo viernes 13 06:00→sábado 14 06:00, `validFrom=DateTime(2026,11,13,6)` y `validUntil=DateTime(2026,11,13,23,59,59)` **hora civil Bogotá**; instant sábado 14 02:00. El motor usa `anchorStart` y puede concluir restringido; el `validAtInstant` de Viaje compara **el instante** con `validUntil` y puede degradarlo a `STALE/UNKNOWN`. Probar `instantStatus`, `status`, `reason`, `engineReason` sobre el MISMO árbol y corregir solo si RED. Preferir **no sobrescribir una evaluación concluyente del motor** mediante un heurístico horario sin tener en cuenta las ventanas fullDay candidatas. Preservar `UNKNOWN` cuando realmente falten ámbito/registro/condiciones; no cambiar contrato general de ventanas normales. Al sábado 06:00 la ventana viernes terminó y no se inventa permiso para un día sin cobertura.

**F1.4** Asegurar cero falsos `ALLOWED` con entradas negativas ya existentes: cobertura ausente/`partial` sin datos de ámbito, fecha futura no cubierta, `staleAfter` vencido, placa/servicio/registro desconocido, feriado de ancla incierto. Evitar regresiones de Inicio, Garaje, Viaje, Conducir, vista de ciudad y contador. **No cambiar datasets legales/PHP para forzar un test verde.**

**F1.5** Una sola secuencia `RED → arreglo causal pequeño → GREEN` si hay fallo real; luego una corrida final de la selección afectada sobre TREE final. Si Flutter no existe: `DART=NOT_RUN_ENV`; no dar PASS y avanzar al servidor sin bucle. Si falla una función realmente P0, `DART=FAIL`, corregir dentro del lote si el cambio es acotado; nunca generar APK etiquetada como validada.

## D. F2 — MIGRACIONES Y OTA QUE PRODUCEN VALOR REAL

### F2.A Drift: corregir únicamente la expectativa vieja si se reproduce

Con Flutter ejecutar:

```text
test/core/database/restriction_coverage_migration_test.dart
test/core/database/restriction_availability_migration_test.dart
```

**Código verificado:** `AppDatabase.currentSchemaVersion=11`; `restriction_coverage_migration_test.dart` todavía afirma `PRAGMA user_version==10` en los casos v8/v9. Si el test falla **solo** por esa expectativa, actualizar su descripción/aserción a destino v11 y comprobar **las mismas filas/campos de cobertura, tabla availability y datos del usuario**. **No rebajar versión 11, saltarse migración ni convertir el test en skip.** El segundo test ya cubre v10→v11. Si hay pérdida real: `MIGRATION_DATA_HOLD`, no instalar en Mi A3; corregir raíz solo dentro del ámbito de Drift autorizado.

### F2.B OTA QA: servidor por su cuenta, cliente cuando Flutter esté disponible

Reutiliza componentes existentes; NO construir otro publicador ni nuevas API:

```text
server/app/Services/RestrictionPublicationService.php
server/app/Services/DatasetReleaseValidator.php
server/tests/Feature/RestrictionPublicationServiceTest.php
server/tests/Feature/DatasetReleaseValidationTest.php
server/tests/Feature/RestrictionNationalLabPublicationTest.php
mobile/lib/core/sync/dataset_sync_service.dart
mobile/test/core/sync/restriction_g2_same_bytes_test.dart
mobile/test/core/sync/dataset_sync_hardening_test.dart
mobile/test/integration/admin_content_publication_bridge_test.dart
```

1. **Sin depender de F1**, ejecutar tests Laravel NUEVOS pertinentes y autónomos; reutilizar las pruebas PHP N1 acreditadas sobre bytes idénticos. Usar solo sqlite/DB QA efímera si realmente disponible, sin cambiar configuración productiva. **Atención:** `RestrictionNationalLabPublicationTest.php` exige variables `PICORADAR_R2_EVIDENCE_DIR` y `PICORADAR_G1_EVIDENCE_DIR` con baseline R2 concreto y SHA; si faltan, marcar `NOT_RUN_INPUT` y **NO fabricar fixtures con nombres parecidos, copiar R4 como R2 ni afirmar PASS**. Un servidor ausente no bloquea test unitario que no lo necesita.
2. Publicación de **snapshot integral aprobado** (otras autoridades preservadas), `publicationRevision`, manifest/asset SHA256; probar datos de dos autoridades/modalidades, rechazo de hash/bytes alterados y conservación de last-good sin vaciar Drift o Garaje. No usar JSON N1 LAB como dataset nacional productivo. Si solo hay pruebas parciales, `OTA_SERVER=PASS_SCOPED` pero `OTA_E2E=NOT_RUN_ENV`.
3. Con Flutter+servidor QA disponible, ejecutar los tests sync existentes y el puente con `PICORADAR_B07_BASE_URL` apuntando a servidor QA **efectivamente levantado**. Si el test se omite (`skip`) por URL o infraestructura, consignar `SKIPPED`; nunca `OTA_E2E_PASS`. Si no hay DB o API, avanzar con tests focales de parser/sync offline, registrar qué componente impide el E2E completo; no descargar imagen Docker ni abrir la red pública por rutina.
4. Confirmar arranque/reapertura de DB y persistencia del dataset realmente integrado cuando el entorno lo permite, sin borrado de vehículos. **Distinguir** `OTA_SERVER_SCOPED`, `OTA_CLIENT_SCOPED`, `OTA_E2E_LAB`, `OTA_ANDROID`: son gates distintos.

### F2.C Datos oficiales YA PUBLICADOS: solo delta seguro y documentado (no una nueva investigación nacional)

**Meta del usuario:** cubrir territorio nacional por datos habilitables, sin una APK por municipio. **Un comunicado verificable de alcaldía, secretaría, tránsito o gobernación vale como fuente oficial para las condiciones que expresa**; el PDF del decreto no es requisito universal. No inferir exenciones, perímetros, horario, servicio o vigencia de campos no publicados. La investigación de los 1.104 códigos y la certificación jurídica 100% son **carril editorial posterior**, no gate para compilar la APK.

Fuentes oficiales identificadas por el Director (contrastar contra LAB existente una sola vez; pueden cambiar; NO transcribir a ciegas):

- **Cartagena, carro/moto 2026-10-05→2027-01-22:** https://cartagena.gov.co/noticias/cambia-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena-0 — lunes 1/2, martes 3/4, miércoles 5/6, jueves 7/8, viernes 9/0; carro 07–09 y 18–20; moto 05–23; exceptúa festivos. Ya hay 5 reglas moto Cartagena en N1: **comparar y REUTILIZAR, no duplicar**. `staleAfter` carro 19-nov-2026 y moto 22-nov-2026 requieren revisión editorial; NO ampliar caducidad automáticamente sin cotejo.
- **Cartagena taxi, noviembre 2026:** https://www.cartagena.gov.co/noticias/esta-nueva-rotacion-pico-placa-para-taxis-cartagena-1 — lunes 5/6, martes 7/8, miércoles 9/0, jueves 1/2, viernes 3/4, periodo declarado 02–27 noviembre. **La noticia llama «martes 02-nov» cuando el 02-nov-2026 fue lunes**; validar el calendario real y el horario con fuente oficial adicional antes de crear reglas. Fuente matriz anual (horario 06→06 y festivos exceptuados): https://www.cartagena.gov.co/noticias/cartagena-adopta-nueva-rotacion-pico-placa-para-taxis-partir-este-lunes-5-enero . Si falta coherencia de vigencia/horario, guardar `HOLD_EDITORIAL`; no bloquear QA técnica.
- **Medellín segundo semestre 2026:** https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre/ — desde 03-ago-2026, lunes 5/8, martes 1/4, miércoles 0/2, jueves 3/6, viernes 7/9, 05–20 para carro particular (último dígito) y moto (primer dígito). Taxi se anuncia quincenal, pero **no da por sí sola el calendario completo**: mantener taxi `HOLD` hasta tabla precisa, no inventar rotaciones.
- **Cartagena `fullDay` 11-dic-2026→22-ene-2027:** noticia de enero https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026 anunció temporada, pero 18-jun-2026 https://www.cartagena.gov.co/noticias/pico-placa-no-sera-24-horas-datt-reitera-que-mantiene-medida-vigente-establecida-horario-fraccionado negó la temporada intermedia 24h. **No se deriva automáticamente decisión de diciembre:** mantener `HOLD_OFFICIAL_RECONFIRMATION`, cero reglas fullDay estacionales activas hasta comunicación inequívoca.

**Operación acotada:** comparar cuatro fuentes con entradas N1; si un caso está completo y el contrato existente lo admite, introducir **un solo delta editorial por modalidad y fuente** en LAB con `partial`/fuente/fechas exactas y pruebas de compilador **solo del delta cambiado**. No convertir esto en nueva ingestión nacional ni en puerta de salida para APK. Si no hay acceso a web desde Codex, usar solo JSON/evidencias suministrados, mantener HOLD sin alucinar nueva verificación. **Contador editorial** separado: autoridades, DIVIPOLA, pares cobertura, reglas, `complete` acreditadas y `HOLD`.

## E. F3 — APK DEV N1 NUEVA Y QA FÍSICA SEGURA

**Precondiciones APK:** Flutter+Android SDK funcionan; F1 `PASS/FIXED_PASS`, `NO_FALSE_ALLOWED=PASS`, Drift sin pérdida de datos ni `DATA_HOLD`, pruebas del árbol final pertinentes sin P0. **El E2E OTA real puede quedar pendiente sin impedir generar APK DEV EXPERIMENTAL**, pero impide declarar release nacional listo.

1. **QA final obligatorio según `AGENTS.md`, UNA VEZ sobre el código final:** desde `mobile/` ejecutar `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` (suite global), y `flutter build apk --debug` **con número/versión de build seguros**. No correr globales después de cada microcambio: primero focales, luego una pasada final. Si una suite global falla, indicar nombre, si es fallo nuevo/heredado e impacto; arreglar solo fallos causales del lote. Si `NOT_RUN_ENV`, **NO** decir lote móvil PASS. Respetar también gates Laravel aplicables si se cambió servidor.
2. APK **del árbol FINAL**, nunca la RC2 pre-N1. Inspeccionar package/applicationId, firma, versión instalada Mi A3 y build code; generar **versionCode superior** compatible via `--build-number` de Flutter (sin editar archivos por estética). Registrar SHA-256, tamaño, `versionName`, `versionCode`, fingerprints de firma, comandos/exit y `FINAL_TREE`. Firma DEBUG es solo DEV; para distribución falta firma release y seguridad.
3. **Mi A3 — preservar datos:** solo instalar si autorización condicional previa sigue válida, packageId+certificado coinciden, versión es superior, migraciones reales pasaron y comparación segura es posible. Si cualquiera falta, `ANDROID=HOLD_SAFE`, **no** `uninstall`, `pm clear`, `adb shell pm reset-permissions`, reset de datos, downgrade o firma distinta. Con autorización efectiva: capturar conteos de Garaje **en momentos comparables** y resultado de arranque/reapertura, consulta local de carro/moto, `UNKNOWN/STALE`, OTA y rollback si endpoint QA existe. Nunca incluir placa ni datos sensibles en ZIP.
4. **Entrega real de APK:** si compilada, poner **ESA APK** en `APK/` dentro del **ZIP ÚNICO**, si el medio soporta tamaño; validar extracción y SHA. **No reportar «entregada» ofreciendo solo una ruta D:\**. Si la transferencia impide incluirla, `APK_BUILT=PASS`, `APK_DELIVERED=NO`, límite exacto documentado; director decide el transporte. Jamás incluir RC2 vieja o duplicar bundles pesados.

## F. F4 — PERSISTENCIA GIT, EVIDENCIAS Y CIERRE EN UNA SOLA ENTREGA

**F4.1 Git local y respaldo íntegro.** Al completar cambios y tests, crear **un commit LOCAL** en el árbol aislado/autorizado, nunca sobre cambios ajenos, incluyendo N1 + delta nuevo; registrar `FINAL_HEAD`, `FINAL_TREE`, `git status`. Exportar `RECOVERY/RC2_TO_FINAL.patch` **autocontenido desde el commit RC2 exacto**, incluyendo los 23 archivos N1 originales + nuevos (archivos binarios si los hubiera en `git diff --binary`); verificar en CLON AISLADO nuevo `RC2 + patch => FINAL_TREE` con `git apply --check`, `git apply`, `git add` limitado a archivos del parche, `git write-tree`. **NO** volver a insertar el bundle RC2 de 85 MB en el ZIP; está en custodia del usuario. Si no hubo cambios, conservar índice SHA N1 y referencia al parche N1 original; no inventar commit.

**F4.2 GitHub.** Registrar `GITHUB_DOCS=PR79_DRAFT` (el Director gestiona su actualización, no Codex). Para producto, comprobar el estado real de `HOLD_SECURITY` sin repetir un escaneo histórico amplio si ya hay evidencia vigente. Si permanece abierto, **NO PUSH** y dejar `GITHUB_PRODUCT=HOLD_SECURITY` + causa, SHA y medida precisa para desbloquear; el ZIP protege código. Si está realmente solucionado y es seguro/legal/autorizado, subir únicamente una rama de trabajo y PR Draft con SHA y URL, nunca merge/force-push ni ZIP privado; si 403, reportar una vez. No confundir guardado remoto documental con publicación de código. `PRODUCT_RELEASE=NO_GO` hasta controles finales, firma release y aprobación explícita.

**F4.3 ÚNICO ARCHIVO ZIP** `PICORADAR_N1_V3_CIERRE_VERTICAL_EVIDENCIA_UNICA.zip`, en `D:\codex\_REPORTES\PicoRadar\<TASK_ID>\delivery` si ruta disponible, con SOLO:

- `FINAL_REPORT.md`: **primera línea** resultado de producto y avances comprobados (no 20 páginas de excusas), fallos reparados, dudas y responsabilidades; tabla `YA_HECHO/NO_HECHO` por motor, Viaje, Drift, OTA Server, OTA Flutter, OTA E2E, APK, Mi A3, seguridad y GitHub.
- `GATES.csv`: ID de gate, árbol/commit, comando exacto, exit, `PASS|FAIL|PASS_SCOPED|SKIPPED|NOT_RUN_ENV|NOT_RUN_INPUT|HOLD`, evidencia/cobertura y si se reutilizó prueba anterior. Prohibido confundir `SKIPPED` con PASS y test de archivo antiguo con HEAD final.
- `LOGS/` focales y gates globales nuevos **saneados**, salida suficiente para reproducir, sin credenciales/datos privados. No empaquetar salidas redundantes.
- `RECOVERY/RC2_TO_FINAL.patch` SOLO cuando haya cambios respecto de RC2; SHA reproducible y comprobación de `FINAL_TREE`; si no, referenciar parche N1 original por SHA.
- `DATA_EDITORIAL_DELTA.csv` solo si fuentes realmente contrastadas introducen cambio; incluir `fuente`, `modalidad`, `fechas`, `partial/hold`, `staleAfter`, sin tablas especulativas.
- `APK/` con APK nueva compilada, **solo si existe y fue comprobada**.
- `MANIFEST_SHA256.csv` tamaño+SHA256+CRC32 de cada miembro distinto del propio manifest (evitar autorreferencia), comprobación completa del ZIP CRC y del binario APK extraído si lo hay.

**NO** incluir bundle RC2 otra vez, repositorio entero, DB reales, informes duplicados ni prometer archivos separados. `NEXT_ACTOR=CHATGPT_DIRECTOR` al cierre, aun cuando una parte esté `HOLD`.

### Respuesta exterior Codex: UNA sola línea, no otro plan ni preguntas repetidas

```text
TASK_ID | FINAL_TREE | DART_N1 | TRIP_ANCHOR | DRIFT | OTA_SERVER | OTA_CLIENT | OTA_E2E | MOBILE_FULL_QA | APK_BUILT | APK_DELIVERED | ANDROID | GITHUB_PRODUCT | RELEASE=NO_GO | ZIP_PATH | ZIP_SHA256 | NEXT_ACTOR=CHATGPT_DIRECTOR
```

**Contador de progreso fijo y honesto (no % de código):** `G1` Dart + seguridad del motor, `G2` OTA QA integral, `G3` Drift + APK DEV + QA física, `G4` seguridad GitHub + firma de distribución, `G5` release autorizado. Solo marcar `Gx=1` si **todos** sus criterios están verificados, `PASS_SCOPED` no basta; informar `GATES_CERRADOS=0..5/5` y qué falta por gate. La cobertura editorial nacional tiene su **contador independiente**, no se suma como un gate de APK. No crear R4/N2 automáticamente. Las pruebas y las modificaciones de este lote deben dejar un producto o desbloqueo real, no otra auditoría de auditorías.

# 🔴 AL ENTREGAR EL ZIP: SIGUE CHATGPT DIRECTOR PARA VERIFICAR DELTA Y DECIDIR RELEASE, NO CODEX OTRA VEZ POR INERCIA