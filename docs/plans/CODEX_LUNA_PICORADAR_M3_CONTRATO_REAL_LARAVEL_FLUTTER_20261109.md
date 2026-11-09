# CODEX LUNA — PICORADAR M3-X01 | Prueba funcional mínima Laravel → manifiesto → Flutter | KISS + PONYTAIL

**TASK_ID ÚNICO:** `PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR`  
**ACTOR EJECUTOR:** Codex Luna. **DIRECTOR/ARQUITECTO/AUDITOR:** ChatGPT.  
**FECHA:** 2026-11-09 (Colombia). **ESTADO:** ORDEN FOCAL AUTORIZADA PARA QA AISLADA, no release.  
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

**Pregunta binaria:** ¿puede el cliente Flutter consumir y activar de forma segura un dataset de restricciones **con bytes realmente producidos por el publicador Laravel**, y conservar el último dato sano ante un error de integridad/versión, sin conectarse a ningún servicio real?

Es indispensable distinguir **tres cosas que YA existen por separado**:

- En Laravel, `server/app/Services/DatasetPublisher.php`, `server/app/Services/RestrictionPublicationService.php` y `server/app/Services/DatasetReleaseValidator.php`; tests existentes `server/tests/Feature/DatasetPublisherTest.php`, `server/tests/Feature/RestrictionPublicationServiceTest.php` y `server/tests/Feature/DatasetPublicContractTest.php` verifican publicación/rollback, manifest y rutas públicas. **Reutilizarlos; no rehacer sus casos.**
- En Flutter, `mobile/lib/core/sync/dataset_manifest.dart`, `mobile/lib/core/sync/dataset_sync_service.dart`, `mobile/lib/features/pico_placa/data/restriction_store.dart` y motor local. Tests existentes `mobile/test/core/sync/dataset_sync_service_test.dart`, `mobile/test/core/sync/dataset_sync_hardening_test.dart`, `mobile/test/app/dataset_sync_composition_test.dart`, `mobile/test/features/pico_placa/data/restriction_dataset_test.dart`. **Reutilizar y ejecutar solo los focales necesarios**.
- En particular, `mobile/test/core/sync/dataset_sync_hardening_test.dart` ya incluye el caso **`Python compiler bytes reach the engine through HTTP and Drift`**. **NO copiarlo como supuesta nueva funcionalidad**: aquí solo interesa la brecha de proveniencia Laravel publisher → Flutter consumidor.

La prueba debe usar **únicamente fixtures sintéticas** (identidades/placas sintéticas y sin evidencia oficial), `APP_ENV=testing`, almacenamiento temporal y SQLite efímera. El dataset sintético debe ser inequívocamente `QA_NON_PRODUCTION_DO_NOT_PUBLISH`, mantener reglas de validez de schema y permitir diferenciar `restricted`, `unknown`, `stale` (según contrato existente), sin convertir UNKNOWN en ALLOWED. No usar JSON real ni cambiar `staleAfter` de Medellín/Bogotá/Cartagena. Jamás exponer esa fixture en CDN o Git productivo.

## 2. Límite de alcance y decisiones permitidas

**AUTORIZADO**

- Leer el código existente, construir una matriz concisa de las rutas reales de publicación y consumo, comparar formato (manifest, versionado, SHA-256, URL relativa/absoluta, schema, metadata de fuentes, tiempos y compatibilidad).
- Ejecutar tests focales PHP, tests focales Flutter si SDK ya está disponible en el entorno aprobado; usar únicamente servidor HTTP loopback de fixture (`127.0.0.1`) si se requiere, con puerto efímero y cierre automático.
- Crear en un **directorio temporal aislado fuera de checkout** los bytes del dataset sintético mediante el publicador Laravel real y su manifiesto; copiar los artefactos resultantes al ZIP de evidencias con hashes. Un JSON inventado a mano NO satisface el origen Laravel.
- Si la brecha entre aplicaciones NO está cubierta, añadir **como máximo dos cambios de test** en un candidato aislado: uno en `server/tests/Feature/DatasetPublisherTest.php` o `server/tests/Feature/RestrictionPublicationServiceTest.php`, y otro en `mobile/test/core/sync/dataset_sync_hardening_test.dart` o `mobile/test/app/dataset_sync_composition_test.dart`. Opcionalmente un helper **solo de test** en `server/tests/Support/` si es absolutamente necesario; explicar por qué no se pudo reutilizar soporte existente. Prohibido producir más de tres rutas de código/test modificadas sin STOP al director.
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
3. Reconocer que el PR79 documental se consulta con referencia propia y NO se busca en checkout moderno para declarar que «falta el contrato». Confirmar si el local tiene PHP/Composer/PDO SQLite y SDK Flutter existentes, sin instalar global ni pedir secretos. **Un diagnóstico acotado por herramienta; no loops de reinstalación**.
4. Asegurar ubicación de QA temporal aislada sin datos de usuario, permisos mínimos y limpieza solo de los artefactos propios si la política permite; nunca violar políticas de eliminación para «dejar limpio».

**G0 salida:** `BASELINE_MATCH/STOP_SAFE`, capacidades de entorno y diff protegido PRE. Nunca ejecutar la migración o fixture sobre una BD real.

## 4. G1 — Mapa de contrato real, sin reescribir arquitectura

Extraer de las implementaciones citadas **solo** un cuadro inspectable de:

- Clave de dataset de restricciones efectiva y nombre real de las rutas públicas.
- Propiedades requeridas en el manifiesto Laravel y aceptadas por el parser Flutter: versión, SHA-256, URI/URL, `minAppVersion`, esquema y freshness (revisar código, no suponer).
- Formato de payload efectivo que genera el backend, campos requeridos del parser móvil y relación `source/verified_at/staleAfter`.
- Orden de validación: hashing sobre bytes publicados, descarga, verificación de SHA, validación semántica, activación atómica en Drift, rollback y conservación del último dato bueno.
- Autorización de publicación backend y necesidad de `Validated` antes de `Published`; para este ensayo **solo publicar en instancia efímera**.

**Resultado G1:** `CONTRACT_MATRIX.csv` con `field`, `backend_path_or_method`, `mobile_path_or_method`, `expected`, `observed`, `PASS/MISMATCH/UNKNOWN`, `evidence`, `sha`. Un comentario de que «tests existentes pasan» NO sustituye este puente.

## 5. G2 — Prueba de extremo a extremo que no sea duplicada

1. En un sandbox PHP/SQLite efímero, producir por métodos existentes de Laravel una versión sintética validada y un manifiesto estático real; no modificar archivos de la app ni registrar datos reales. Capturar bytes completos `manifest.json` y `restrictions-qa.json` o los nombres que realmente produzca la implementación, preservando rutas relativas para su lectura desde test. Si el publicador no puede emitir la fixture sin cambios de producción, documentar `BLOCKED_CONTRACT` con call stack/test mínimo; no crear un publicador alterno.
2. Verificar independientemente con un programa estándar (Python stdlib/PHP permitido solo para inspección) que `SHA256(payload generado)` coincide exactamente con el que aparece en manifest; comprobar claves/versión/URI y que el JSON sintético es explícitamente no productivo. Registrar log y archivos en subcarpeta `synthetic/` del ZIP, no publicarlos remotamente.
3. Alimentar **esos mismos bytes Laravel**, no un JSON escrito a mano en el test Flutter, a una prueba Dart/Flutter mediante fixture local/HTTP loopback del test existente. Exigir: parser acepta schema y hash, Drift importa atómicamente, regla sintética se evalúa localmente, `UNKNOWN/STALE` no se presentan como ALLOWED y las preferencias/vehículos locales no se pierden. Pueden reutilizarse tests ya existentes si demuestran el mismo origen de bytes; si no, añadir **una aserción focal de puente**, no una suite completa duplicada.
4. Simular daño de bytes/hash o versión incompatible, comprobar rechazo y preservación del dataset previo. **No** repetir todas las variantes de reintento, gzip, tamaño, redirect ya cubiertas en `dataset_sync_hardening_test.dart`; solo ejecutar el caso necesario para la unión Laravel→Flutter.
5. Si se descubre que un payload generado por Laravel contradice el parser Flutter, entregar RED con diferencia de contrato byte-a-byte, impacto, alternativas KISS y STOP. No corregir ambos frameworks a ciegas.

**Condiciones de falso positivo a evitar:** no bastan por separado un PHPUnit PASS y un Flutter test PASS si **no consumieron exactamente los mismos bytes**; tampoco cuenta una fixture codificada manualmente como si procediera del publicador Laravel. La ruta manifiesto→datos→Flutter debe ser inspeccionable en el ZIP.

## 6. G3 — Pruebas focales y bloqueos de entorno

- PHP: seleccionar y ejecutar **solo tests relevantes ya existentes**, por ejemplo `server/tests/Feature/DatasetPublisherTest.php`, `server/tests/Feature/RestrictionPublicationServiceTest.php` y `server/tests/Feature/DatasetPublicContractTest.php`, más la prueba nueva si procede. Registrar comando literal, extensión/versión PHP, base SQLite temporal, counts/tests/assertions, exit code y log. No asumir que 43 pruebas C1 cubren este lote: cambio de artefacto y entorno.
- Flutter, si SDK disponible: ejecutar **test focal** (`mobile/test/core/sync/dataset_sync_hardening_test.dart` / `mobile/test/app/dataset_sync_composition_test.dart`) y `flutter analyze` si se modificó test Dart. Registrar versión exacta Flutter/Dart, dependencias lockfile, salida y exit code. Tests amplios `flutter test`/build Android solo cuando requisito de `AGENTS.md` los haga necesarios en cierre de código; no fingir una suite completa o un APK.
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

- `M3_X01_BRIDGE_PASS_SCOPED`: **bytes publicados por Laravel real** → manifest SHA comprobado → **mismos bytes** importados y evaluados por Flutter en prueba ejecutada → corrupción/rollback focal PASS; solo en QA aislada, no `M3_DONE` ni release.
- `M3_X01_NO_DELTA_NEEDED`: hallada evidencia **ya existente y reproducida** de EXACTAMENTE ese puente real con mismas entradas/hashes; sin crear tests redundantes. Debe citar rutas, comandos y bytes; las pruebas separadas de Python→Flutter y PHP→manifest NO califican.
- `M3_X01_BLOCKED_ENV`: herramienta indispensable ausente, causa documentada, chequeo único; entregar matriz de integración y pruebas realmente ejecutadas, sin verde sintético.
- `M3_X01_CONTRACT_GAP_CONFIRMED`: mismatch genuino entre salida Laravel y entrada Flutter, con prueba RED, no parche productivo autoautorizado.
- `M3_X01_STOP_SAFE`: cualquier cambio de baseline, riesgo legal/PII, manipulación WIP, dependencia externa, migración o necesidad de ampliar scope.

**RELEASE=NOT_APPROVED** en todos los casos; `PUBLISH_ALLOWED=NO`; ninguna regla real cambia de `UNKNOWN/STALE/PARTIAL` a `ALLOWED/READY`.

## 9. G6 — Una sola entrega ZIP y handoff

Crear UN SOLO ZIP con nombre aproximado `PICORADAR_M3_X01_CONTRATO_LARAVEL_FLUTTER_EVIDENCIA_UNICA_20261109.zip` dentro de `D:\codex\_REPORTES\PicoRadar\PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR\` (puede usar subcarpeta `delivery/` si existe y autorizada, pero especificar siempre ruta efectiva). No entregar 10 archivos sueltos; el ZIP debe contener:

1. `FINAL_REPORT.md`: TASK_ID, RESULT único, explicación técnica de la prueba, SHA HEAD, base, bloqueos, no falsos PASS, `NEXT_ACTOR=CHATGPT_DIRECTOR`.
2. `CONTRACT_MATRIX.csv`: tabla del puente Laravel ↔ Flutter por campo, con rutas de código y diferencias probadas.
3. `GATES.csv` y `AUDIT_10.csv`: comandos, versiones, condiciones y diez controles con PASS/PARTIAL/NOT_RUN/FAIL individuales.
4. `SYNTHETIC_BYTES_MANIFEST.json` + artefactos `synthetic/` solo de datos de prueba, con sha y tamaños; rutas no privadas.
5. `TEST_COMMANDS_AND_RAW_OUTPUT.log`: pruebas focales PHP/Flutter (o bloqueos de entorno) con exit codes reales; no reemplazar por una transcripción redactada sin trazabilidad.
6. `PATCH_CANDIDATE.diff` **solo si hubo cambios**, un máximo de tres rutas permitidas y `git apply --check` en copia aislada. Si no hubo cambios: `NO_CODE_DELTA.md`.
7. `GIT_AND_WIP_STATUS.txt` con PRE/POST checkout original idénticos o desviación reportada; 101 WIP `NOT_VERIFIED` si no se inspeccionan.
8. `MANIFEST.json` + `MANIFEST.sha256` cubriendo cada miembro excepto el propio manifiesto/checksum; CRC, tamaños y SHA-256. SHA final del ZIP fuera del archivo para evitar autorreferencia.

Si un archivo no corresponde por bloqueo, registrar `NOT_RUN` y razón; no fabricar artefactos. **El informe debe auditar lo efectivamente ejecutado, no declarar éxito por código presente.** Ninguna orden para futuras tareas; limitarse a entregar el resultado para auditoría de ChatGPT.

## 10. Ruta de terminación preservada y responsabilidad

- **M1:** cobertura nacional legal oficial, autoridad/ámbito/clase, vigencia, anexos/geo, revisión humana; cinco filas permanecen NO READY y Medellín `staleAfter=2026-11-10T05:00:00Z` no se renueva sin fuente.
- **M2:** reutilizar motor+compilador y luego agente solo lector/proponente, siguiendo dependencias; no se declara completado mediante esta prueba.
- **M3:** evidencia real de interfaz publicador→sync offline, luego API/manifiesto y módulos existentes; este lote es solo **ensayo de contrato sintético** de un borde, no macro terminada.
- **M4:** admisión del parche local C1 condicionado a Flutter/CI sobre SHA; QA WIP 101, Android físico/JNI/firma/seguridad/privacidad y GO humano. No tocar Mi A3 ahora.

**CUÁNDO CONTINUAR:** `NEXT_ACTOR_AFTER_ZIP=CHATGPT_DIRECTOR`. Codex es ejecutor; cualquier contradicción importante requiere STOP y evidencia, no autonomía de arquitectura. Prohibido crear M3-X01-C2 por un bloqueo ambiental: si está bloqueado, entregar el ZIP parcial y el director replanifica.

**FIN — CODEX LUNA, ORDEN COMPLETA.**