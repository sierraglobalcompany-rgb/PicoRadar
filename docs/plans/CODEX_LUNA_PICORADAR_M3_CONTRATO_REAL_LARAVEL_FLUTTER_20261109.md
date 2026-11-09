# CODEX LUNA — PICORADAR M3-X01 | Prueba funcional mínima Laravel → manifiesto → Flutter | KISS + PONYTAIL

**TASK_ID ÚNICO:** `PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR`  
**ACTOR EJECUTOR:** Codex Luna. **DIRECTOR/ARQUITECTO/AUDITOR:** ChatGPT.  
**FECHA:** 2026-11-09 (Colombia). **REVISIÓN DE DIRECCIÓN:** V2 adversarial, **mismo TASK_ID**, sustituye íntegramente la V1 sin iniciar fase ni lote nuevos. **ESTADO:** ORDEN FOCAL AUTORIZADA PARA QA AISLADA, no release. **SHA y ruta canónica:** esta misma ruta Markdown en PR #79; verificar contra GitHub antes de iniciar. Si Codex ya comenzó V1, NO abandonar trabajo ni reiniciar: aplicar los requisitos nuevos al cierre y declarar las diferencias como `PARTIAL` cuando corresponda.  
**RESULTADO OBLIGATORIO:** UNA sola entrega ZIP auditable con informe, trazas, pruebas, artefactos mínimos, hashes y manifest; incluso si hay `BLOCKED_ENV` o `NO_DELTA_NEEDED`.  
**NO ES:** M1 legal completado, M2.4 agente desplegado, M3 completo, aprobación de política de movilidad, publicación real, migración a producción ni autorización de merge.

## 0. Por qué existe esta orden y por qué NO es otro ping-pong

El director recibió y verificó `PICORADAR_M1_CAPTURA_OFICIAL_EVIDENCIA_UNICA_20261109.zip`, ZIP SHA-256 `88bc276a2f9cbc63db104a7fc0380264831f268bedaace4a3afa7de4a5f1ea26`: 24 miembros/CRC PASS, 22 hashes de manifiesto PASS, nueve snapshots exactos y **13/13 tests Python reproducidos**. Resultado `SOURCE_CAPTURE_ACCEPTED_SCOPED`, `READY=0/5`. **Se cierra definitivamente esa ejecución.** No repetir capturas ni restablecer los tres hashes históricos, no eludir dos HTTP 403, no ampliar allowlist ArcGIS ni leer de nuevo las mismas URL. El `PATCH_CANDIDATE.diff` del capturador sigue fuera del repositorio y no forma parte de esta orden.

Hallazgo del director: el archivo HTML de Bogotá Jurídica del Decreto 652 (**2.433.776 bytes**, SHA `0c5864cceec8f0a5c54992a7a4460ba65046b02790b084ac7c326c43cbd8fa8c`) **sí contiene texto real** de los artículos 226–230, aunque también muestre «Cargando el Contenido del Documento». El HTML del 657 también contiene modificaciones. No pedir otra vez su texto por creer que el visor está vacío. Ninguna regla queda READY por esto; geometrías, excepciones y revisiones de actos siguen en el carril legal externo.

**Cambio deliberado de carril:** mientras M1 legal completa sus fuentes, probar un **corte vertical técnico reproducible** de los componentes que YA existen: bytes efectivos de un dataset sintético que Laravel publica → manifiesto estático real → validación SHA/versión en Flutter → persistencia y evaluación local. Esto aborda una interfaz de integración de producto; **no escribir una nueva implementación de sincronización** ni otra batería de pruebas duplicadas.

### Dependencias y precedencia

1. Obligatorio leer `AGENTS.md`, `docs/CURRENT.md`, `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`, `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx`, flujo y contrato específicos; vigilar seguridad/privacidad/store y precedencia. NO cambiar decisiones establecidas.
2. Leer las **Leyes L1–L6** del repositorio `sierraglobalcompany-rgb/PingPongLaw`, `docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md` (SHA Git de referencia `0f6e7b4e62d8660c846f135e18dded629d29e0da`): L1 KISS+Ponytail, L2 antirruido, L3 antiparches, L4 diseño UX sin intervención, L5 verificación independiente, L6 antiping-pong.
3. Plan maestro PicoRadar V2 PR **#79** (rama `docs/plan-maestro-nacional-v2-20261107`), §§D–F y Z y siguiente sección de checkpoint; **no asumir que documentos del PR79 están en checkout `recovery/20261019-modern`**. Se ha resuelto ya ese falso `GAP-CONTRACT`.
4. En remoto PR **#71** Draft HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` sobre `main`; PR **#79** solo documental. Trabajo local moderno referencia `recovery/20261019-modern`; no usar `main` histórico como fuente de producto, ni mezclar con C1/M1F/R21 ni con 101 WIP.
5. Arquitectura congelada: Flutter feature-first, Riverpod/go_router/Drift, motor local; Laravel monolito publica versiones inmutables/manifest; CDN estático; sin microservicios, sin backend para GPS por posición, sin paquetes nuevos. Garaje y Pico funcionan sin cuenta; no se filtran placas, nombres, GPS o documentos reales.

## 1. Problema funcional único que esta prueba debe demostrar

**Pregunta binaria:** ¿puede el cliente Flutter consumir y activar de forma segura una **pareja de releases v1 y v2 sintéticos publicados por Laravel, cuya transición v2 pasa obligatoriamente por `RestrictionPublicationService::publish()`**, reutilizando `DatasetReleaseValidator`, `DatasetPublisher` y `ManifestPublisher`, y conservar el último release instalado frente a bytes adulterados o versión inválida, sin conectarse a ningún servicio externo?

**Condición de fallo evitable:** un `DatasetPublisher::publish()` genérico aislado NO satisface el puente de restricciones. Su publicación como baseline dentro del test oficial es admisible, pero al menos la transición de versión que se evalúa en Flutter **DEBE** pasar por `RestrictionPublicationService::publish()` y producir bytes+manifest desde storage real del sandbox. El test `RestrictionPublicationServiceTest.php` ya tiene fixtures `co-alpha/co-beta` y servicio real; aprovecharlos antes de crear nuevas fixtures.

**Contrato que se prueba:** el repositorio remoto moderno `recovery/20261019-modern` usa `schemaVersion=1` para `restrictions` y manifest `schemaVersion=1`. El parche C1 local de schema2 sigue fuera del remoto: esta QA **NO prueba ni acepta C1 schema2**.

Es indispensable distinguir **tres cosas que YA existen por separado**:

- En Laravel, `server/app/Services/DatasetPublisher.php`, `server/app/Services/RestrictionPublicationService.php` y `server/app/Services/DatasetReleaseValidator.php`; tests existentes `server/tests/Feature/DatasetPublisherTest.php`, `server/tests/Feature/RestrictionPublicationServiceTest.php` y `server/tests/Feature/DatasetPublicContractTest.php` verifican publicación/rollback, manifest y rutas públicas. **Reutilizarlos; no rehacer sus casos.**
- En Flutter, `mobile/lib/core/sync/dataset_manifest.dart`, `mobile/lib/core/sync/dataset_sync_service.dart`, `mobile/lib/features/pico_placa/data/restriction_store.dart` y motor local. Tests existentes `mobile/test/core/sync/dataset_sync_service_test.dart`, `mobile/test/core/sync/dataset_sync_hardening_test.dart`, `mobile/test/app/dataset_sync_composition_test.dart`, `mobile/test/features/pico_placa/data/restriction_dataset_test.dart`. **Reutilizar y ejecutar solo los focales necesarios**.
- En particular, `mobile/test/core/sync/dataset_sync_hardening_test.dart` ya incluye el caso **`Python compiler bytes reach the engine through HTTP and Drift`**. **NO copiarlo como supuesta nueva funcionalidad**: aquí solo interesa la brecha de proveniencia Laravel publisher → Flutter consumidor.
- El `ManifestPublisher` real utiliza por defecto `DATASET_PUBLIC_BASE_URL=/storage` y emite `datasets.restrictions.url` como `/storage/datasets/restrictions/...`; `DatasetSyncService._resolveDatasetUri()` acepta URI relativa solo resolviéndola desde el `cdnBaseUri` y exige **mismo origen**. La prueba debe conservar literalmente el campo `url` del manifest emitido por Laravel. Es lícito usar `AppConfig(cdnBaseUrl: 'http://127.0.0.1:<puerto>')` únicamente dentro del test inyectado, como ya hacen tests existentes. **Nunca** cambiar `AppConfig`/validaciones de producción para permitir HTTP externo, ni reescribir el manifest por conveniencia.

La prueba debe usar **únicamente fixtures sintéticas** (identidades/placas sintéticas y sin evidencia oficial), `APP_ENV=testing`, almacenamiento temporal y SQLite efímera. Identificar **en los nombres de artefactos, registros y metadatos de test** `QA_NON_PRODUCTION_DO_NOT_PUBLISH` sin inyectar campos incompatibles en el payload validado por Laravel. Reusar `co-alpha/co-beta` o claves igualmente sintéticas. Exigir `schemaVersion=1`, `datasetKey=restrictions`, un `version` opaco `rN-...`, `generatedAt`, `coverages`, `verifiedAt` y `staleAfter` según los contratos reales. Fijar reloj del caso y `America/Bogota`, plate de prueba, horario y `isHoliday=false`; no depender del día en que Codex ejecute la prueba. Demostrar `restricted`, `unknown`, `stale` **solo si las fixtures representan realmente esas condiciones**, sin convertir UNKNOWN en ALLOWED. No usar JSON real ni cambiar `staleAfter` de Medellín/Bogotá/Cartagena. Jamás exponer esa fixture en CDN o Git productivo.

## 2. Límite de alcance y decisiones permitidas

**AUTORIZADO**

- Leer el código existente, construir una matriz concisa de las rutas reales de publicación y consumo, comparar formato (manifest, versionado, SHA-256, URL relativa/absoluta, schema, metadata de fuentes, tiempos y compatibilidad).
- Ejecutar tests focales PHP, tests focales Flutter si SDK ya está disponible en el entorno aprobado; usar únicamente servidor HTTP loopback de fixture (`127.0.0.1`) si se requiere, con puerto efímero y cierre automático.
- Crear en un **directorio temporal aislado fuera del checkout original** los bytes sintéticos usando `RestrictionPublicationService::publish` sobre una app/DB/Storage Laravel aislados. Los fakes de Storage pueden escribir carpetas *ignoradas* bajo `storage/framework/testing/`; ejecutar el test en copia/sandbox de QA cuando corresponda y preservar el checkout original incluso en archivos ignorados. Copiar **dos snapshots completos** del manifiesto y los datasets (baseline v1, transición v2) a artefactos inmutables de la entrega. **NO reconstruir ni editar a mano el JSON, el SHA o el manifest entre PHP y Dart.**
- Si la brecha entre aplicaciones NO está cubierta, añadir **como máximo dos cambios de test** en un candidato aislado: **preferir** `server/tests/Feature/RestrictionPublicationServiceTest.php` (publicación específica, no solo genérica) y `mobile/test/core/sync/dataset_sync_hardening_test.dart` (HTTP/Drift ya existentes). Opcionalmente un helper **solo de test** en `server/tests/Support/` si es indispensable; justificarlo. No pasar de tres rutas modificadas. Exportar desde PHP a un directorio del sandbox controlado por parámetro o variable **solo del test**; en Dart leer exclusivamente esos mismos archivos por ruta de prueba, **no referirse a rutas locales del equipo ajeno**. La entrega debe ser reproducible con un único paquete de entrada. No crear un transportador/productor duplicado para pasar de un lenguaje al otro.
- Conservar patch candidato fuera del checkout y un manifiesto de las rutas; no stage/commit/push por defecto. **No editar código de producción** durante esta ejecución. Si se encuentra un defecto productivo, aportar RED y propuesta de arreglo acotada; esperar decisión del director.

**PROHIBIDO**

- Cambios a `server/app/`, `mobile/lib/`, esquema/migraciones, scripts de producción o `mobile/assets/`; edición del catálogo legal, acto, TTL, manifiesto publicado real o `DATASET_SOURCE` real.
- `git checkout --`, `git clean`, `reset --hard`, `stash`, `force push`, borrar worktrees/C: o WIP, merge y publicación del PR #71/#79.
- Nuevos microservicios, nuevo SDK HTTP, BLoC/GetX/GetIt, arquitectura paralela, tablas adicionales o paquetes Flutter/Composer sin aprobación.
- Conexiones a Hostinger, MariaDB productiva, GitHub Actions por cuota, teléfono Xiaomi Mi A3, ADB, GPS, APK de release, datos personales ni tráfico externo. Si la prueba requiere acceso externo, **STOP** y producir ZIP de evidencia parcial.
- Declarar `M3 DONE`, `RELEASE GO`, `READY>0` o ``CI GREEN`` con pruebas locales sintéticas.

## 3. G0 — Preflight mínimo no destructivo (sin auditoría global repetida)

1. Identificar la ruta efectiva del checkout moderno y `git rev-parse --show-toplevel`, branch, HEAD, `git status --porcelain=v1`, `git rev-parse HEAD^{tree}`. `AGENTS.md` antiguo identifica `D:/Dev/PicoRadar`, pero la ruta real puede variar. **No asumir ruta ni crear worktree sin comprobar existentes**. Operar solo desde disco `D:` y en copia/área aislada protegida; `D:\codex\_REPORTES\PicoRadar\...` es para evidencias, no para destruir originales.
2. Esperado por último lote: branch `recovery/20261019-modern`, HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, árbol `04a01f15475dd25fbcd40597120e6e44722b0504`, `git status --short` con único borrado histórico **`D scripts/tests/test_hostinger_installer_browser.ps1`**. Si cualquier dato difiere, **STOP_SAFE**; no restaurar el borrado. No inventariar ni hashear los **101 WIP**, expresamente fuera de alcance. Solo comprobar identidad PRE/POST del checkout en la misma sesión.
3. Reconocer que el PR79 documental se consulta con referencia propia y NO se busca en checkout moderno para declarar que «falta el contrato». Antes de preparar fixtures, registrar **una sola vez** `php -v`, módulos PDO/SQLite, Composer/vendor local y `flutter --version` + presencia de dependencias del proyecto, sin instalar nada global ni pedir secretos. **Si falta Flutter o PHP esencial**, no crear una simulación en el otro lenguaje que pueda pasar por integración. Construir mapa G1 con evidencia estática y cerrar `M3_X01_BLOCKED_ENV` o `M3_X01_STOP_SAFE`, según la causa. No insistir con 13 variantes de búsqueda del SDK ni lanzar una nueva etapa de setup.
4. Asegurar ubicación de QA temporal aislada sin datos de usuario, permisos mínimos y limpieza solo de los artefactos propios si la política permite; nunca violar políticas de eliminación para «dejar limpio».

**G0 salida:** `BASELINE_MATCH/STOP_SAFE`, capacidades de entorno y diff protegido PRE. Nunca ejecutar la migración o fixture sobre una BD real.

## 4. G1 — Mapa de contrato real, sin reescribir arquitectura

Extraer de las implementaciones citadas **solo** un cuadro inspectable de:

- Clave de dataset de restricciones efectiva y nombre real de las rutas públicas.
- Propiedades requeridas en el manifiesto Laravel y aceptadas por el parser Flutter: `schemaVersion=1`, `generatedAt` (control futuro ≤5 minutos), `minAppVersion`, `datasets.restrictions.version`, `url`, `sha256`, `publicationRevision` positiva, `expiresAt` opcional, esquema y frescura de coberturas. Separar estrictamente `staleAfter` de `expiresAt`/`nextReviewAt`; usar valores sintéticos sin tocar TTL real. La versión de release `rN-...` es opaca: el cliente se guía por `publicationRevision` para determinar orden; **no tratarla como semver**.
- Formato de payload efectivo que genera el backend, campos requeridos del parser móvil y relación `source/verified_at/staleAfter`.
- Orden de validación: hashing **sobre bytes exactos publicados**, manifest emitido sin retoque, resolver `url` `/storage/...` contra `cdnBaseUri`, misma origin, descarga, verificación SHA, validación `datasetKey/version`, validación semántica, transacción Drift y preservación del último dato bueno ante fallo. Distinguir **rechazo del cliente** de **rollback de una publicación en Laravel**; son operaciones separadas y el rechazo de un payload malicioso no equivale a probar rollback del servidor. Registrar `publicationRevision` y hashes del baseline y de la actualización.
- Autorización de publicación backend y necesidad de `Validated` antes de `Published`; para este ensayo **solo publicar en instancia efímera**.

**Resultado G1:** `CONTRACT_MATRIX.csv` con `field`, `backend_path_or_method`, `mobile_path_or_method`, `expected`, `observed`, `PASS/MISMATCH/UNKNOWN`, `evidence`, `sha`. Un comentario de que «tests existentes pasan» NO sustituye este puente.

## 5. G2 — Prueba puente real de dos releases, sin duplicar arquitectura

**G2.0, condicionante:** ejecutar solo si tanto PHP/SQLite/Composer como Flutter con dependencias están disponibles, y G1 no encontró un contrato imposible. Los tests antiguos **no prueban automáticamente** este puente. Si alguno falta, no fabricar un GREEN usando solo un lenguaje.

**G2.1 — Fuente Laravel de verdad:** reutilizar el setup sintético que ya existe en `server/tests/Feature/RestrictionPublicationServiceTest.php` (`Storage::fake`, `co-alpha/co-beta`, `RestrictionRuleVersionService`, `RestrictionPublicationService`). Producir un baseline sintético **v1** en el publicador y luego una **transición v2 efectivamente publicada por `RestrictionPublicationService::publish()`**. Para cada estado, capturar manifest sin editar **tal como lo emite `ManifestPublisher`** (`manifest/v1/manifest.json`), el asset exacto bajo `datasets/restrictions/...` y evidencia `DatasetRelease`, `publicationRevision`, estado `Published` y SHA. Conservar el snapshot v1 ANTES de que v2 regenere el manifest. Un escenario `DatasetPublisher` genérico por sí solo no satisface el punto.

**G2.2 — Exportación reproductible:** ruta temporal `D:\codex\_REPORTES\PicoRadar\...\qa_synthetic\` u otra equivalente que el runner crea dentro de un aislamiento propio, nunca en producción; preservar las rutas relativas del manifest y del asset para que el test Dart sirva **los bytes sin modificación** en loopback. Archivos requeridos: `baseline/manifest.json`, `baseline/<asset_path_real>`, `next/manifest.json`, `next/<asset_path_real>`, `PROVENANCE.csv` (`stage`, `source_service`, `storage_disk`, `relative_path`, `bytes`, `sha256`, `manifest_release_version`, `publication_revision`, `php_test_command`). Si una validación interna requiere directorio de tests, no mover archivos ignorados del checkout original; emplear sandbox QA. Los nombres son etiquetas del ZIP, no rutas nuevas del producto. No construir un segundo exportador funcional.

**G2.3 — Verificación cruzada:** comprobar desde Python stdlib (o PHP independiente de las aserciones principales), sobre archivos ya exportados, `SHA256(asset)==manifest.datasets.restrictions.sha256` para **v1 y v2**. Revisar `schemaVersion=1`, `datasetKey`, `generatedAt`, `version`, `publicationRevision(v2)>publicationRevision(v1)>0`, `minAppVersion`, `url` literal del backend y ausencia de identificadores reales. No editar manifest ni payload para hacerlo aceptable; si `DATASET_PUBLIC_BASE_URL` por defecto produce `/storage/`, reportarlo como tal. Un `http://127.0.0.1` solo puede representar la URL base del **servidor de pruebas**, nunca convertirse en URL de producción dentro del manifest.

**G2.4 — Flutter consume los mismos bytes:** levantar servidor HTTP loopback local con puerto efímero **solo en test**, sirviendo `GET /v1/manifest.json` del snapshot v1 y la ruta exacta `/storage/datasets/restrictions/...` que resuelve el campo `url`; `AppConfig` de test con `cdnBaseUrl=http://127.0.0.1:<puerto>` y servicio real `DatasetSyncService` e importer real de restricciones. Evitar cambiar `AppConfig`/política HTTP del producto. Este uso del servicio inyectado en test **no valida la configuración de CDN de producción** ni TLS: esas pruebas siguen pendientes de M3/M4. Probar primer sync v1: SHA, version y `publicationRevision` instalados, lectura Drift, motor con placa y fecha sintética fija, `UNKNOWN/STALE` conforme a fixtures. Luego servir el manifest v2 y bytes de v2 tal como salieron de Laravel y comprobar cambio de revision y reglas. Guardar mediciones de SHA **del archivo servido**, **del campo manifest**, y de la base instalada. Si no se logra reproducir PHP→Dart desde los archivos reales, `M3_X01_BRIDGE_PASS_SCOPED` queda prohibido.

**G2.5 — NEGATIVO real de último bueno:** usar **una segunda base Drift efímera limpia** para instalar v1 y luego intentar v2 con el **manifest v2 real** y bytes v2 corrompidos solo en la respuesta del servidor de test. Así basta con dos releases PHP y no se confunde la descarga v2 fallida con la instalación v2 válida realizada en el primer escenario. Alternativamente, usar una tercera versión publicada por Laravel si ya existe sin fabricar una release. No falsear un caso reusando la versión instalada que `DatasetSyncService` salta como `skippedCurrent`. Comprobar `DatasetSyncException`, SHA/revisión y cobertura Drift previos intactos, reglas iguales, vehículo/preferencia de prueba preservados. No afirmar rollback de Laravel si solo se probó protección del cliente. El caso de corrupción usa **bytes mutados exclusivamente en el servidor de prueba**, mientras los bytes originales y hashes permanecen intactos dentro de la evidencia.

**G2.6 — Decisión temprana:** si hay incompatibilidad verdadera de schema, mismo origen, `publicationRevision`, `generatedAt` o payload, entregar `M3_X01_CONTRACT_GAP_CONFIRMED` con RED de ambos lados y comparación byte a byte. **No editar `server/app`, `mobile/lib` ni agregar un publicador alterno para hacerlo pasar**. Si solo falta acceso a la herramienta, marcar `M3_X01_BLOCKED_ENV` y conservar evidencia estática, sin nuevo lote de diagnóstico.

**Falsos positivos expresamente prohibidos:** (a) dos suites separadas con fixtures distintas; (b) una sola versión que Flutter salta como instalada; (c) `DatasetPublisher` genérico como sustituto del flujo real de restricciones; (d) manifest o hash reconstruidos a mano; (e) `pass` PHP sin Flutter; (f) tests Dart de esquema 1 como aprobación del candidato local C1 esquema 2; (g) rollback del cliente presentado como rollback del servidor; (h) reglas sintéticas presentadas como legales.

## 6. G3 — Pruebas focales y bloqueos de entorno

- PHP: ejecutar **al menos la prueba focal que exporta realmente v1/v2 desde `RestrictionPublicationService`**, y reutilizar las de `DatasetPublisherTest` y `DatasetPublicContractTest` solo cuando su contrato importe y el entorno lo permita. Indicar si se usa Storage fake dentro de sandbox QA (no real) y mostrar comando, PHP/extensión SQLite, counts/assertions, exit code y log. No dar por cubierto el lote con las 43 pruebas C1: son otro SHA y otro alcance.
- Flutter: ejecutar el **test focal de puente** desde `mobile/test/core/sync/dataset_sync_hardening_test.dart` con ruta de los artefactos v1/v2 exportados por PHP. No admitir que pase usando el fixture anterior Python→Flutter. Incluir `dart format --output=none --set-exit-if-changed` para archivos Dart cambiados y `flutter analyze` en el alcance autorizado; versión Flutter/Dart, lockfile, comando y exit code. Full `flutter test`, Android build y CI sobre SHA final son **NOT_RUN/PENDING** de M4 salvo que se ejecuten de verdad; el resultado local `BRIDGE_PASS_SCOPED` no los suplanta.
- Si Flutter SDK **no está disponible** tras un único chequeo del entorno autorizado, registrar `BLOCKED_ENV_FLUTTER` y continuar solo los gates PHP y verificación estática del contrato, **NO declarar `BRIDGE_PASS`**. No crear tareas de instalación ni gastar más rondas reparando un entorno no autorizado.
- Si no se puede construir la fixture PHP con SQLite efímero, registrar `BLOCKED_ENV_SERVER` o `BLOCKED_CONTRACT` según prueba causal, sin usar otra base ni cambiar servidor real.
- Los hashes de scripts, outputs y el ZIP serán calculados después de cerrar archivos. Test logs crudos del caso focal; no inventar cantidades ni transformar `NOT_RUN` en PASS.

## 7. G4 — Revisión forense y seguridad de preservación

- Comparar scope contra ley L1–L6, componentes existentes, contratos y precedencia del baseline. No introducir paquete nuevo, tratamiento de placa/GPS ni nuevas APIs reales.
- Comparar los SHA del manifest/payload y del test candidato con el contenido incluido. Todos los hashes de archivos se recalculan al empaquetar; incluir script de verificación con standard library o instrucciones exactas para reproducirlo.
- Caso de prueba debe contener solamente datos **sintéticos** con marcador inequívoco. Si se reutilizan claves DIVIPOLA existentes como escenario de sintaxis, marcar explícitamente ficticia su regla, no habilitarla en JSON runtime, DB de usuario o consola real.
- `git diff --check`, formato de los test files modificados y escaneo focal de secretos/PII. Si no se modifica test, `NO_DELTA_NEEDED` y por qué.
- Postflight de checkout original: branch, HEAD, árbol, status exactos; no afirmar que los 101 WIP fueron verificados. Si una limpieza de temporales propios es bloqueada por política, conservarlos, declararlos fuera del ZIP y no eludir el bloqueo.

## 8. G5 — Condiciones de salida excluyentes

Reportar uno solo de estos resultados:

- `M3_X01_BRIDGE_PASS_SCOPED`: **`RestrictionPublicationService` Laravel real**, dos versiones sucesivas publicadas en sandbox (`publicationRevision` estrictamente creciente), ambos manifests y payloads originales con SHA verificado por auditor independiente, **mismos bytes** consumidos por Flutter en test ejecutado, transacción Drift y caso negativo que realmente intenta descargar una versión nueva dañada y preserva el último bueno. El test debe reportar dos SHAs por versión, comprobados con el manifest, y evitar skip por versión actual. Solo QA aislada; no M3 DONE ni release.
- `M3_X01_NO_DELTA_NEEDED`: evidencia **ya existente, ejecutada y reproducida** de EXACTAMENTE este puente `RestrictionPublicationService → manifest V1/V2 → Flutter`, incluyendo transición v1→v2, negativa no skipped, hashes y fuentes de artefactos. La prueba Python→Flutter y el test PHP de publicación **por separado NO califican**.
- `M3_X01_BLOCKED_ENV`: herramienta indispensable ausente, causa documentada, chequeo único; entregar matriz de integración y pruebas realmente ejecutadas, sin verde sintético.
- `M3_X01_CONTRACT_GAP_CONFIRMED`: mismatch genuino entre salida Laravel y entrada Flutter, con prueba RED, no parche productivo autoautorizado.
- `M3_X01_STOP_SAFE`: cualquier cambio de baseline, riesgo legal/PII, manipulación WIP, dependencia externa, migración o necesidad de ampliar scope.

**RELEASE=NOT_APPROVED** en todos los casos; `PUBLISH_ALLOWED=NO`; ninguna regla real cambia de `UNKNOWN/STALE/PARTIAL` a `ALLOWED/READY`.

## 9. G6 — Una sola entrega ZIP y handoff

Crear UN SOLO ZIP con nombre aproximado `PICORADAR_M3_X01_CONTRATO_LARAVEL_FLUTTER_EVIDENCIA_UNICA_20261109.zip` dentro de `D:\codex\_REPORTES\PicoRadar\PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR\` (puede usar subcarpeta `delivery/` si existe y autorizada, pero especificar siempre ruta efectiva). No entregar 10 archivos sueltos; el ZIP debe contener:

1. `FINAL_REPORT.md`: TASK_ID, RESULT único, explicación técnica de la prueba, SHA HEAD, base, bloqueos, no falsos PASS, `NEXT_ACTOR=CHATGPT_DIRECTOR`.
2. `CONTRACT_MATRIX.csv`: tabla del puente Laravel ↔ Flutter por campo, con rutas de código y diferencias probadas.
3. `GATES.csv` y `AUDIT_10.csv`: comandos, versiones, condiciones y diez controles con PASS/PARTIAL/NOT_RUN/FAIL individuales.
4. `SYNTHETIC_BYTES_MANIFEST.json`, `PROVENANCE.csv` y artefactos `synthetic/baseline/`, `synthetic/next/` con **dos** manifests Laravel y **dos** payloads publicados, SHA y tamaños y rutas originales; marcados `QA_NON_PRODUCTION_DO_NOT_PUBLISH`. Si no se ejecutaron los lenguajes esenciales, poner `NOT_RUN` sin fabricar artefactos.
5. `TEST_COMMANDS_AND_RAW_OUTPUT.log`: pruebas focales PHP/Flutter (o bloqueos) con exit codes reales; `CONTRACT_NEGATIVE_CASES.csv` con estado v1, versión v2, causa de corrupción, si hubo download o `skippedCurrent`, excepción y SHA/versión de Drift antes/después. No reemplazar trazas por una transcripción redactada.
6. `PATCH_CANDIDATE.diff` **solo si hubo cambios**, un máximo de tres rutas permitidas y `git apply --check` en copia aislada. Si no hubo cambios: `NO_CODE_DELTA.md`.
7. `GIT_AND_WIP_STATUS.txt` con PRE/POST checkout original idénticos o desviación reportada; 101 WIP `NOT_VERIFIED` si no se inspeccionan.
8. `MANIFEST.json` + `MANIFEST.sha256` cubriendo cada miembro excepto el propio manifiesto/checksum; CRC, tamaños y SHA-256. SHA final del ZIP fuera del archivo para evitar autorreferencia.

Si un archivo no corresponde por bloqueo, registrar `NOT_RUN` y razón; no fabricar artefactos. **El informe debe auditar lo efectivamente ejecutado, no declarar éxito por código presente.** Ninguna orden para futuras tareas; limitarse a entregar el resultado para auditoría de ChatGPT.

## 10. Ruta de terminación preservada y responsabilidad

- **M1:** cobertura nacional legal oficial, autoridad/ámbito/clase, vigencia, anexos/geo, revisión humana; cinco filas permanecen NO READY y Medellín `staleAfter=2026-11-10T05:00:00Z` no se renueva sin fuente.
- **M2:** reutilizar motor+compilador y luego agente solo lector/proponente, siguiendo dependencias; no se declara completado mediante esta prueba.
- **M3:** evidencia focal **schema 1** de `RestrictionPublicationService`→manifest→Flutter, en entorno aislado, no integración de datos nacionales, no despliegue de API, no cuenta de usuario, no M3 DONE. Luego QA de publicación y sync sobre release versionado. No leer un PASS de este experimento como aprobación del parche C1 **schema 2**.
- **M4:** admisión del parche local C1 condicionado a Flutter/CI sobre SHA; QA WIP 101, Android físico/JNI/firma/seguridad/privacidad y GO humano. No tocar Mi A3 ahora.

**CUÁNDO CONTINUAR:** `NEXT_ACTOR_AFTER_ZIP=CHATGPT_DIRECTOR`. Codex es ejecutor; cualquier contradicción importante requiere STOP y evidencia, no autonomía de arquitectura. Prohibido crear M3-X01-C2 por un bloqueo ambiental: si está bloqueado, entregar el ZIP parcial y el director replanifica.

**FIN — CODEX LUNA, ORDEN COMPLETA.**