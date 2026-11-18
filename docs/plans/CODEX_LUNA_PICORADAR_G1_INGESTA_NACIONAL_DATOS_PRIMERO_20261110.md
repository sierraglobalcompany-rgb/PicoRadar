# CODEX LUNA — PICORADAR G1 — INGESTA NACIONAL CONFIGURABLE POR DATOS (NO OTRA CIUDAD/OTRO MES EN CÓDIGO)

**TASK_ID:** `PICORADAR-G1-NATIONAL-DATA-FIRST-RESTRICTIONS-20261110`  
**PROPÓSITO CONCRETO:** transformar la integración local R1/R2 ya probada en un mecanismo *reutilizable* de admisión de restricciones reales por ciudad, autoridad y vehículo, con actualización por archivos de datos revisados y conservando coberturas existentes. **NO** escribir otro calendario mensual en una prueba PHP, **NO** construir otro motor, **NO** activar producción y **NO** reiniciar R1/R2.

**ROLES:** ChatGPT decide arquitectura, fuentes, límites, alcance y GO. Codex Luna solo ejecuta exactamente este contrato y entrega evidencia. Si hay conflicto entre este prompt, `AGENTS.md`, normas canónicas/leyes o trabajo real aprobado, protege lo existente y documenta un único bloqueo concreto; no improvisa. Ejecutar una única vez, en **D:\codex** mediante clon/worktree independiente validado. Nunca modificar la raíz histórica de C: ni borrar WIP.

## 0. EVIDENCIAS Y VERSIONES QUE DEBES PRESERVAR

1. GitHub canónico: `sierraglobalcompany-rgb/PicoRadar`. PR **#71** base código Draft en `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, PR **#79** documentos Draft. No mergear ni rebasar automáticamente. Verificar nuevos HEAD remotos antes de actuar; si cambiaron, informar diferencia sin pisarlos.
2. Candidato local R1: `da9d8083bb21bd7c9863a319e07de51a5e692d09`; candidato local R2 **descendiente directo**: `88fc5d1307a80a9781f7b7e23e1912c3316c7531` en `feat/PICORADAR-R2-bogota-taxi-nov2026`. Verificar **git cat-file**, rama, padre, árbol limpio y que el R2 local no sea un SHA imaginado. Si no está disponible, localizar el ZIP y reconstruir en clon *aislado* sin aplicar sobre ningún WIP; no crear repositorio paralelo manual que duplique historia.
3. ZIP R2 aportado: `PICORADAR_R2_BOGOTA_TAXI_NOV2026_Y_R1_SCOPEFIX_EVIDENCIA_UNICA.zip`, SHA-256 **`213d65fcdecfc1fba12d613160e4168a8f77db5018156d2bad30f73b3d65019c`**. Contiene `ACTUAL_R2_LARAVEL_RELEASE.json`, `ACTUAL_R2_MANIFEST.json`, patch y logs. Release local `r3-f5584f294412`, SHA-256 de JSON **`c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`**. Solo usar rutas reales comprobadas; nunca asumir que una ruta D: de la respuesta de Codex equivale a archivo accesible.
4. **R2 fue auditable pero local:** 7 jurisdicciones, 12 coberturas; Bogotá carro particular noviembre y taxi (23 días) actuales dentro del laboratorio; el resto conserva su `staleAfter` antiguo. CI, APK, dispositivo, publicación real y push siguen **NO EJECUTADOS**. Mantener `RELEASE=NO`.
5. Catálogo nacional YA EXISTENTE: `server/database/data/colombia_divipola_mgn_2025.json` y `mobile/assets/catalogs/colombia_trip_municipalities_v1.json`, 33 divisiones departamentales/DC y **1104** entradas municipales; el catálogo de pico y placa `mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json` tiene **73** entradas, no 1104 reglas. No regenerar ni remplazar esos catálogos y no inventar GPS o polígonos.
6. Fuente jurídica vigente para caso real de control: `https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-para-taxis-en-bogota-del-1-al-30-de-noviembre-de-2026` (4-nov-2026) y `https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-bogota-vehiculos-particulares-1-30-de-noviembre-de-2026` (1-nov-2026). No cambiar el calendario acreditado por una interpretación nueva.
7. Leyes L1 KISS/Ponytail, L2 antirruido, L3 antiparches, L4 no alterar UX aprobada, L5 QA independiente, L6 antiping-pong. Consultar `AGENTS.md` local y las fuentes canónicas de leyes. No arrastrar todos los informes pasados a este lote.

## 1. DIAGNÓSTICO TÉCNICO Y DECISIÓN ARQUITECTÓNICA CERRADA

**No crear un servicio nuevo ni otro motor de reglas.** El código actual ya tiene:

- `server/app/Services/RestrictionImportService.php`: acepta JSON/CSV/XLSX; el JSON de una jurisdicción con `coverages` puede analizarse. **`analyze()` NO es read-only**: almacena archivo, crea import, filas y auditoría. Usarlo SOLO en DB temporal + `Storage::fake` en QA, o con autorización real en un entorno futuro.
- `server/app/Services/RestrictionRuleVersionService.php`: crea/valida borradores. `server/app/Services/RestrictionPublicationService.php` **sustituye el objeto de jurisdicción completo**, no hace merge entre coberturas. `DatasetPublisher`/manifest SHA son el único mecanismo de publicación.
- `mobile/lib/features/pico_placa/domain/restriction_engine.dart`: ya evalúa días, paridad, rotaciones expresadas por fecha, primer/último dígito, horarios y reglas trasmedianoche. `mobile/lib/features/pico_placa/data/restriction_dataset.dart` importa el contrato; `DatasetSyncService` verifica SHA y last-good.
- `mobile/lib/features/pico_placa/domain/restriction_day_evaluation.dart` considera `timeWindows: []` como regla **de todo el día calendario** en evaluación diaria al componer intervalo [0,1440]. **NO** inventar nueva semántica de 24 h sin comprobar esta capacidad. Una restricción 06:00→06:00 siguiente día NO se representa por `startMinute=endMinute` (rechazado): no resolver aquí una norma no aprobada.
- `VehicleKind={car,motorcycle}` y `VehicleServiceType={private,taxi}`; NO convertir carga, bus, transporte especial, motocarro o pasajeros acompañantes a esos pares por comodidad. Su extensión tipada y geografía de segmentos quedan para el siguiente lote de *capacidades* con condiciones reales oficiales ya delimitadas, no para G1 editorial.

**Problema que G1 debe resolver:** R1/R2 crearon calendarios reales dentro de tests PHP. Repetir esto para cada municipio/rotación obliga a cambiar código en cada actualización. Ya existe un importador de jurisdicciones completas, así que la mejora es **usar el contrato JSON existente como formato editorial revisable y seguro**, protegiendo automáticamente coberturas no modificadas, demostrando que añadir otra medida de un tipo YA SOPORTADO no exige añadir ramas por ciudad ni modificar pruebas hardcoded.

## 2. OBJETIVOS IMPLEMENTABLES, ORDENADOS Y BINARIOS

### G0 — Preflight y protección antes de escribir

- Verifica Git HEADs, remoto, worktrees, WIP, stash, eliminación histórica protegida `scripts/tests/test_hostinger_installer_browser.ps1`, estado local R2, y SHA de ZIP. **No asumir que 101 WIP antiguos están disponibles**; no hacer `git clean`, `reset --hard`, borrado, movidas, `push --force`, merge ni deploy. Crea candidato solo bajo D: y evita carpetas con archivos no rastreados de terceros.
- Lista explícitamente todos los archivos existentes que la solución podría afectar. La primera opción debe reutilizar clases existentes y modificar **el menor número de rutas posibles**. No tocar `mobile/assets/datasets/restrictions/restrictions_v1.json` ni los catálogos nacionales como forma de fingir publicación.
- Comprobar herramientas locales PHP/SQLite/Composer/Flutter. Si falta toolchain, no instalar paquetes o modificar lockfile: ejecutar lo viable, clasificar `PARTIAL_ENV`, entregar ZIP y parar sin falsas aprobaciones.

### G1 — Una entrada editorial JSON REAL, fuera de tests

- Crear una sola fuente de datos editorial versionada para la jurisdicción **`co-dc-bogota`**, por ejemplo `server/database/data/restrictions/official/co-dc-bogota-2026-11.json` (ruta exacta puede adaptarse si la solución aprobada ya tiene un directorio equivalente; **no duplicar**). **Punto de partida obligatorio:** extraer del JSON R2 validado el objeto completo de Bogotá (3 coberturas: `car/private` R1, `motorcycle/private` known-empty R1, `car/taxi` R2), sin editar a mano los 23 días; asociar las fuentes oficiales, fecha de revisión y estado editorial sin introducir campos extra al payload que el contrato Flutter pudiera interpretar mal. Si necesitas metadatos de revisión, dejar un fichero editorial mínimo adjunto, separado del payload canónico.
- Una actualización jurídica ordinaria de Bogotá debe requerir editar datos JSON y pasar revisión, **NO** cambiar `BogotaNovember2026PublicationTest.php`, escribir otro calendario PHP o publicar código de producción. Mover tablas hardcodeadas a lectura de este dato único, conservando un oráculo de pruebas pequeño, independiente de la misma fuente (no generar los `expected` automáticamente del input).
- Usar `RestrictionContractValidator` para validar JSON y los servicios reales de borrador y publicación **solo en laboratorio**. Si el importador JSON existente ya hace esto, reutilizarlo y probarlo; no crear un segundo importador. **`analyze()` escribe**: manejarlo explícitamente y probar que jamás llega a base/disk de producción.
- Mantener contrato schema1 intacto para R1/R2. La incorporación de condiciones nuevas (parrillero/ocupantes/carga/rutas) tendrá schema/contrato tipado revisado luego; este lote no debe romper lectores actuales.

### G2 — Protección anti-pérdida para TODAS las ciudades

- Comprobar que ninguna importación o draft de una cobertura aislada elimina al publicar las coberturas previamente conocidas de esa jurisdicción. **Primero buscar la ruta ya aprobada para componer una jurisdicción completa;** reutilizar duplicación/preview si existe. Si no existe, implementar el cambio mínimo en un servicio Laravel existente (no segundo publicador) que prepare el payload **COMPLETO** antes de crear/validar borrador: preservar identidades `(vehicleKind,serviceType)` no modificadas exactamente, incluidas coberturas stale y known-empty. Comparar JSON canónico por cobertura. No “refrescar” staleAfter ni inventar normas de las coberturas preservadas.
- **Fail closed y defensa en profundidad:** el publicador no debe aceptar silenciosamente una propuesta que elimina alguna cobertura previamente publicada en la misma jurisdicción, salvo flujo de revocación/remoción expresamente aprobado con evidencia. Para este G1, si detecta disminución de identidades, `REJECT_COVERAGE_LOSS` antes de escribir release; no implementar un bypass automático. **Esta regla se aplica a cualquier ciudad**, no solo Bogotá. No alterar los rollback aprobados: verificar el caso de rollback a una versión anterior; si hay incompatibilidad, limitar el guard a publicaciones normales y probar explícitamente.
- Crear una salida de **vista previa del diff** antes de publicar: ciudad, clases afectadas, reglas agregadas/reemplazadas, `staleAfter` de cada cobertura, fuente, partes inalteradas, posibles pérdidas, permisos requeridos. Reutilizar el admin/versionado actual cuando ya muestra esa información. Si agregar una vista requiere rehacer interfaz, preferir resultado estructurado generado por el servicio y tests: NO pantallas nuevas para G1.
- No promover datos externos de IA de las matrices 31/55 a estado verificable por presencia. Si no hay norma oficial completa o el motor no puede representar zona/exención, registrar `NOT_VERIFIED/CONDITIONAL` y **NO** publicar ese ámbito. Para localidades del catálogo geográfico sin medidas investigadas, `UNKNOWN` (no «puede circular»).

### G3 — Probar que el mecanismo no depende de Bogotá, con un lote de dos jurisdicciones

- En una base/disk **aislados**, partir del JSON semilla real de 7 jurisdicciones / 12 coberturas del commit PR71 y aplicar el JSON Bogotá extraído del R2. Debe quedar 7/12, conservar R1 car/private/moto and 6 ciudades (sus hashes canónicos coinciden), y generar release Laravel y manifest con SHAs reales.
- Para demostrar *reutilización nacional*, crear un caso **sintético marcado de prueba** para una SEGUNDA jurisdicción ya existente (por ejemplo, `co-cau-popayan`), modificando una regla desde un segundo JSON de test sin cambiar código JavaScript/PHP/Dart específico por municipio. Esta segunda medida NO es afirmación legal ni publicable: datos en `tests/Fixtures`, `sourceUrl` de prueba y test explícito `SYNTHETIC_NOT_FOR_RELEASE`. El objetivo es comprobar que una actualización multi-ciudad por data y control de identidades funciona sin ramificaciones especiales ni borrado de otros territorios. No usar datos jurídicos inventados como oficiales.
- Cambiar una pareja de dígitos solo en **un archivo de datos de laboratorio** y confirmar que el release y el resultado Flutter/Drift cambian conforme a ese dato *sin modificar código de evaluación*; verificar regresión de las otras coberturas, idempotencia, conflicto de revisión, rollback, SHA manifest y last-good.
- Verificar expresamente `timeWindows: []` = 24h **calendario** cuando la fecha es válida (sin crear otra clase), y que tiempo 06:00→06:00 con igualdad es rechazado en schema1; no afirmar que ambos son equivalentes.

### G4 — Cierre utilizable y pruebas, sin repetir todo PicoRadar

- Ejecutar suite focal real de `RestrictionImportServiceTest`, `RestrictionPublicationServiceTest`, `BogotaNovember2026PublicationTest`, validadores y tests de sincronización Flutter/Drift. Si cambias helpers de motor, correr tests engine y pantallas afectadas; no volver a correr pruebas históricas sintéticas M3-X01 si el mismo SHA/contrato no cambió.
- **Gate de no-falsos-positivos:** export Laravel real de laboratorio, manifest bytes, SHA, fecha, dos jurisdicciones, Flutter importa MISMO fichero. Ningún test de E2E requerido puede estar SKIPPED por ausencia de `PICORADAR_R2_EVIDENCE_DIR` u otra variable. Si la falta de entorno impide materializar export, reportar `E2E_BLOCKED`, no PASS.
- Actualizar solo docs de código realmente implementado y una matriz `ALREADY_SUPPORTED / NEEDS_NEW_TYPED_PREDICATE / NEEDS_GEOGRAPHY / OFFICIAL_UNVERIFIED` para categorías: particular, moto, taxi, carga, bus/colectivo, transporte especial, motocarro, parrillero, ocupantes, carga kg/ejes, 24h calendario, cruce 06→06, zona/sentido, excepciones/permiso. **Esta matriz es una comprobación de arquitectura de salida, no el resultado principal.** No descargar documentos masivamente ni buscar todas las normas; esas verificaciones y admisión jurídica corresponden al director.

## 3. PROHIBICIONES QUE EVITAN PARCHES Y FALSAS APROBACIONES

- NO instalar APK, no tocar Mi A3, no `main`, no migración/tabla nueva, no cambiar API externa, no nuevos paquetes, no nuevo engine ni segundo backend, no alterar UX aprobada, no poner `coverageKnown=true` a ciudades sin verificación.
- NO modificar `staleAfter` de coberturas antiguas para volverlas artificialmente vigentes. En release R2 solo Bogotá car/private y taxi tienen vigencia editorial hasta 01-dic; las otras diez siguen stale y ese estado debe preservarse.
- NO afirmar que G1 representa cobertura legal nacional; demuestra un **canal editorial multi-ciudad** seguro y reusable para familias ya soportadas. No convertir modalides públicas especiales/carga en taxi para superar tests.
- NO generar 1.104 registros municipales nuevos: YA existen. No inventar GPS/centroides. Mantener catálogo geográfico separado del de reglas y no duplicar B02. Geometrías/centros poblados vendrán por fuentes DANE georreferenciadas, versionadas.
- NO push sin comprobar que la cuenta, permisos, workflows y posible coste remoto estén autorizados; PR Draft nuevo solo si es seguro. Si no, dejar commit local más `GIT_DIFF.patch` íntegro y reportar bloqueo. No correr CI manual no autorizado.
- NO edición masiva de archivos que no estén relacionados con G1. Si la vía aprobada ya cumple G1 con cambios cero o mínimos, **demostrarlo** con caso 2 ciudades real de laboratorio en lugar de programar arquitectura redundante.

## 4. QA DE ACEPTACIÓN (DISTINGUIR EJECUCIÓN DE DOCUMENTACIÓN)

| ID | Prueba ejecutable | Gate |
|---|---|---|
| Q01 | Revalidar R2 local SHA y parent R1 y WIP intacto | PASS / BLOCKED, jamás supuesto |
| Q02 | Componer Bogotá 3 coberturas desde JSON editorial único, sin hardcoded mensual en PHP | PASS |
| Q03 | Revisión explícita de fuentes y datos, cero autopublicación por presencia | PASS |
| Q04 | Publicación normal rechaza perder cualquier identidad de cobertura ya publicada | PASS NEGATIVO |
| Q05 | Update solo taxi deja car/private y moto idénticos bit a bit al canonical object R2 | PASS |
| Q06 | Reemplazar Bogotá deja seis ciudades intactas | PASS |
| Q07 | Segundo municipio sintético desde archivo de datos sin cambio en motor/código calendario | PASS, NO JURÍDICO |
| Q08 | Laravel genera release+manifest; triple hash PHP/manifiesto/Dart | PASS E2E |
| Q09 | Flutter Drift importa 7/12 y preserva last-good tras corrupción | PASS |
| Q10 | 24h calendario `timeWindows=[]` correcto; 06→06 `start=end` rechazado | PASS o brecha precisa, sin inventar |
| Q11 | El estado de un municipio sin fuente confirmada se mantiene UNKNOWN | PASS |
| Q12 | Regresiones focales y PHP/Flutter analyze/format/Pint con 0 skipped E2E | PASS |

**Salidas mutuamente excluyentes:** `G1_DATA_FIRST_PASS_SCOPED` si las doce Q pasan; `G1_PARTIAL_WITH_EVIDENCE` si hay funciones terminadas pero bloqueos reales; `G1_BLOCKED_SAFE` si no hay baselines/herramientas. **NO** llamar release productivo ni cobertura legal nacional a ninguno. Si R2 ya forma parte del checkout remoto, no duplicar commits: trabajar en HEAD verificado y preservar autoría/historia.

## 5. PLAN NACIONAL POST-G1 (NO IMPLEMENTAR AQUÍ POR INERCIA)

**G2 — Predicados por familia con contrato Flutter/PHP unificado, sin DSL arbitraria:** implementar *solo basados en casos jurídicos concretos* y con tres valores match/no-match/unknown: parrillero/acompañante, ocupantes, clase de carga/peso/ejes, ruta/zona/sentido, exención con autorización, nuevas clases públicas. El concepto de condiciones debe ser **declarativo y tipado**, sin scripts JavaScript o expresiones remotas ejecutables. Cada atributo desconocido produce `UNKNOWN` en vez de permiso. Preservar schema1 con compatibilidad probada; versión nueva solo con migración y minAppVersion aceptadas.

**G3 — Geografía nacional y GPS:** reconciliar sin duplicar los 33/1104 registros DIVIPOLA-MGN ya presentes, añadir centros poblados, centroides/segmentos/polígonos verificados con identificador estable DANE, sin inventar (0,0). Un centroide no prueba ubicación en la vía. Diferenciar `no researched`, `no active measure confirmed`, `conditional`, `verified`, `stale` por clase y ámbito. Municipio sin regla no significa autorizado.

**G4 — Admisión oficial por LOTES multi-ciudad:** ChatGPT contrasta fuentes por autoridad/modalidad/ámbito sobre las matrices 31/55 y 73/219 existentes. Codex carga versiones de jurisdicción COMPLETAS en el mismo mecanismo G1, sin cambiar código por rotación; pruebas focales diferenciales. Exenciones y condiciones que el motor no conoce quedan fuera o `UNKNOWN`, no inventar.

**G5 — App distribuible:** QA CI/local del mismo SHA, APK con firma correcta, prueba física Mi A3, datos descargados por manifest SHA/last-good sin mezclar bundles por fecha, privacidad/GPS opcional, rollback. Release solo con GO del propietario.

## 6. ZIP ÚNICO DE EVIDENCIA Y RESPUESTA

Crear **un único** ZIP bajo `D:\codex\_REPORTES\PicoRadar\` con nombre real comprobado, no enlace supuesto. Contendrá: `FINAL_REPORT.md` con Q01–Q12 y resultado; `ARCHITECTURE_DIFF.md` (qué existe, qué cambió y qué no); `SOURCE_BOGOTA_NOV2026.json` (datos de normativa R2 revisados); `SAFE_COMPOSITION_DIFF.json`; archivos de fixture segundo municipio marcados `SYNTHETIC_NOT_FOR_RELEASE`; `REAL_LARAVEL_RELEASE.json`, `REAL_MANIFEST.json`, `FLUTTER_SAME_BYTES.md`; `TEST_COMMANDS_AND_LOGS.md` y logs focales PHP/Flutter; `GIT_DIFF.patch` íntegro con cualquier archivo nuevo, Git status/commit/refs, fuente legal, issues `BLOCKERS.md`; `CHANGED_FILES_SHA256.csv`, `MANIFEST.json` hash/tamaños de todo miembro, `MANIFEST.sha256`. Verificar CRC, zip-slip, extracción independiente, sha, ausencia de secretos; no incluir `.env`, tokens, contraseñas o PII.

**Respuesta fuera del ZIP (resumen corto):** `TASK_ID=...; RESULT=...; R2_BASE=...; DATA_FIRST_JSON=...; CITY_PRESERVATION=...; SECOND_CITY_TEST=...; FULLDAY=...; LARAVEL_SHA=...; FLUTTER_SHA=...; QA=...; CI=...; LOCAL_COMMIT=...; REMOTE_PUSH=...; RELEASE=NO; ZIP_PATH=...; ZIP_SHA256=...; NEXT=CHATGPT_DIRECTOR`.

**FIN DE ORDEN. ES EJECUCIÓN G1, NO REAUDITORÍA DE R2, NO OTRO CALENDARIO PHP, NO AUTOPUBLICACIÓN.**
