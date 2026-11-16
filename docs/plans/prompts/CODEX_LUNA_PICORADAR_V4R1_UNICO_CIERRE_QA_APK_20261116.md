# CODEX LUNA — PICORADAR V4-R1 · UN SOLO MACROBLOQUE PARA CERRAR QA BLOQUEANTE Y ENTREGAR APK DEV

**TASK_ID:** `PICORADAR-N1-V4R1-QA-CAUSAL-APK-UNICO-20261116`  
**AUTORIDAD:** ChatGPT Director diseña y acepta; CODEX LUNA ejecuta en Windows; el propietario autoriza actos irreversibles.  
**SUSTITUYE ÍNTEGRAMENTE:** `CODEX_LUNA_PICORADAR_V4_DESBLOQUEO_30_FALLOS_Y_APK_DEV_20261115.md` y las órdenes V3/N1 anteriores. **Ejecutar SOLO V4-R1, UNA VEZ, si no existe otro escritor sobre el mismo candidato.** No reiniciar V3, no rehacer el inventario nacional ni auditar el prompt.  
**RESULTADO ÚTIL:** reparar por causa los fallos de QA atribuibles al árbol V3, conservar datos de usuarios, obtener un estado verdadero del motor/OTA y **construir y entregar una APK DEV interna** si los controles críticos del código actual y el entorno lo permiten. No significa release, merge, publicación o aprobación Android física.

## 0. HECHOS CONGELADOS — NO REPETIR

- **V3 final verificado por restauración independiente**: base RC2 `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289` + `RECOVERY/RC2_TO_FINAL.patch` del ZIP V3 ⇒ TREE **`829f202b27348c93d354acc4658e9fc0f7e939a8`**. ZIP V3 `PICORADAR_N1_V3_CIERRE_VERTICAL_EVIDENCIA_UNICA.zip` **96.141 bytes**, SHA-256 `6f7cd6de923c0e4fbbab751afc39b71ae1d34f03e987bbaebfd3144ae80324d0`, CRC PASS, manifiesto 13/13. Commit local `c38141fb5043ce87b0cf7974ec7c1855004d440e`: **REPORTADO**, no recuperado en GitHub. No exigir SHA del commit si el TREE reconstruido coincide.
- **QA V3**: `flutter analyze` PASS; formato de 405 Dart rastreados PASS; Viaje/ancla 3/3 PASS; migración Drift focal 3/3 PASS; presentación 68/68 PASS; motor N1 221 PASS + 1 entrada R2 ausente; OTA cliente 15 PASS + 3 entradas históricas ausentes; Laravel/Python N1 ya comprobados en su ámbito sin cambio PHP; **global `flutter test`: 3.315 PASS, 13 SKIP, 30 FAIL**. `OTA_E2E=NOT_RUN_ENV`, `APK_BUILT=NO`, `ANDROID=HOLD_SAFE`, `RELEASE=NO_GO`.
- **Cobertura editorial LAB V3**: 14 autoridades, 33 DIVIPOLA, 22 coberturas todas `partial`, 120 reglas. Cartagena carro tiene ajuste de `validUntil` hasta 2027-01-22 documentado; `staleAfter` sin prolongación artificial. Temporada 24 horas Cartagena sin reconfirmación sigue HOLD. No recopilar otra vez los 1.104 municipios ni alterar cifras legales para superar tests.
- **GitHub**: PR #79 es documentación `OPEN/DRAFT`; código V3 no está remoto por `HOLD_SECURITY`. No tratar un commit documental como integración del producto.

## 1. F0 — UNA SOLA COMPROBACIÓN DE ENTORNO, SIN DESTRUIR WIP

1. Candidato **reportado** `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`, rama **reportada** `feat/picoradar-n1-schema2-cartagena-lab`. Revisar una vez `git status --porcelain=v1`, `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git write-tree` **sin cambiar índice**, `git diff --check`, rutas Flutter conocidas y `flutter --version`. Diferenciar **TREE del HEAD, TREE del INDEX y archivos unstaged/untracked**: una restauración N1/V3 staged sobre RC2 puede ser válida aunque `HEAD^{tree}` sea RC2. Si algún archivo no está staged, comparar y proteger su contenido antes de concluir identidad. **Nunca usar `reset --hard`, `clean -fd`, force push, sobrescribir WIP ni tocar otros worktrees.** Si hay escritor simultáneo, detener la edición y entregar solo diagnóstico.
2. Si el árbol candidato equivale exactamente a V3 y no hay cambios ajenos, continuar allí; si no, **un clon aislado nuevo** desde el bundle RC2 del paquete de continuidad ya recibido y aplicar `RECOVERY/RC2_TO_FINAL.patch` de V3. Comparar `git write-tree` con `829f202b27348c93d354acc4658e9fc0f7e939a8` antes de editar. No extraer/duplicar en reportes el bundle RC2 de ~85 MB. Un árbol distinto con WIP ajeno ⇒ `TREE_CONFLICT` para ese checkout; las tareas seguras independientes pueden continuar en el clon aislado.
3. Leer `AGENTS.md` y contratos aplicables al cambio (no releer todo el repo). Respetar las seis leyes PingPongLaw: **L1 KISS/Ponytail, L2 Antirruido, L3 Antiparches, L4 UX aprobado, L5 pruebas reales, L6 una transferencia**. No instalar skills/hooks, bibliotecas, CI de pago ni scripts paralelos por costumbre. Flutter 3.47.9/Dart 3.13.7 **sí ejecutaron tests en V3**. `flutter pub get --offline` falló por symlinks Windows, pero `flutter test`/`analyze` funcionaron con caché existente: **usar `--no-pub` cuando corresponda** y no alterar Developer Mode/antivirus/SDK global/`pubspec.lock` sin autorización.

## 2. F1 — CUATRO CAUSAS DE LOS 30 FALLOS, NO 30 AUDITORÍAS

### A. SEIS MIGRACIONES — PRIORIDAD P0 POR PÉRDIDA DE DATOS

**Archivos existentes**: `mobile/test/core/database/alert_settings_migration_test.dart` (1), `app_database_test.dart` (2), `wallet_migration_test.dart` (1), `wallet_preparation_migration_test.dart` (2). Error V3: `no such table: restriction_coverages` o `duplicate column name: coverage_completeness` durante migración v9→v10. Código real: `mobile/lib/core/database/app_database.dart`, `AppDatabase.currentSchemaVersion=11`.

**Instrucciones causales obligatorias:**

- Inspeccionar una vez las migraciones sucesivas reales v1→v11 y los constructores SQLite históricos de **cada test**. Versiones marcadas artificialmente pero con estructura de otra versión deben corregirse en los **fixtures** conforme al esquema histórico, sin insertar columnas de más. En especial, una tabla `restriction_coverages` con `coverage_completeness` **antes de v10** es un fixture inválido; una supuesta v6–v8 **sin** tabla `restriction_coverages` requiere comprobar cuándo debió crearse (v2→v3).
- **Corregir también expectativas viejas:** `alert_settings_migration_test.dart` todavía espera `PRAGMA user_version=9` y estabilidad de un esquema idéntico al preupgrade, pese a que el migrador real ahora alcanza v11; convertir esa aserción en destino v11, preservación de **filas/valores preexistentes** y existencia de tablas/columnas nuevas. Actualizar títulos engañosos vX→v9/v6 solo en los tests afectados. No eliminar comprobaciones de restricciones, cifrado, FK, fechas, vehículos, obligaciones ni documentos.
- Si un fixture que reproduce fielmente una base histórica real continúa fallando, **es defecto del migrador**: reparar su causa mínima (no suprimir SQL, no ignorar columnas a ciegas, no retroceder versión ni ejecutar drop/recreate con pérdida). Comparar valor antes/después y `PRAGMA user_version=11`, `PRAGMA foreign_key_check`, tablas y blobs cifrados. La prioridad es que **los datos existentes sobrevivan a una actualización real**.
- Ejecutar primero **solo estos cuatro archivos**. No dar PASS por arreglar un fixture si una transición legítima sigue fallando.

### B. SEIS TESTS CON ENTRADAS HISTÓRICAS PRIVADAS — NO INVENTAR INPUTS

**Rutas**: `mobile/test/core/sync/restriction_g2_same_bytes_test.dart` (3), `mobile/test/features/pico_placa/data/g1_laravel_flutter_same_bytes_test.dart` (1), `restriction_g2_r2_schema1_regression_test.dart` (1), `restriction_g2_schema_test.dart` (1).

- Una sola búsqueda **limitada** en `D:\codex\_REPORTES\PicoRadar` y las carpetas históricas ya conocidas; extraer solo miembros necesarios de ZIP existentes; validar SHA/nombre de dataset que el test espera. Variables de entorno reales del test: `PICORADAR_G2_V3_EVIDENCE_DIR`, `PICORADAR_V1_METADATA_LAB_DIR`, `PICORADAR_G34_LAB_EVIDENCE_DIR`, `PICORADAR_G1_EVIDENCE_DIR`, `PICORADAR_R2_EVIDENCE_DIR`, `PICORADAR_G2_R2_RELEASE`. En estos tests el código consultado usa **`Platform.environment`**, por tanto inyectar variables **de proceso**; NO sustituir por `--dart-define` salvo que otra ruta inspeccionada lo exija.
- Si el archivo original existe y coincide, ejecutar **solo las pruebas afectadas**; si no existe, **`HISTORICAL_INPUT=INPUT_MISSING_VERIFIED`**, indicar cuál y dónde se buscó, **no** fabricar un R2 ni cambiar hash/assert, no `skip` ni test falso. No repetir el mismo preflight en otro prompt.
- La ausencia de un fixture histórico no demuestra defecto del motor ni debe bloquear **por sí sola** la **compilación de una APK DEV interna**. Sin embargo, **impide certificar esos tests y un PASS global**; no proclamar app lista para release.

### C. DIECISÉIS PRUEBAS VISUALES DE VIAJE — CORREGIR ORIGEN COMÚN

`mobile/test/features/trip/presentation/trip_visual_evidence_test.dart`: 16 fallos en V3, frecuentemente `pumpAndSettle timed out` en el harness `_pumpScreen`/`_reveal`/`_submitFixture`. Elegir **un caso representativo**, obtener traza limitada y establecer si los frames persistentes vienen de animación, provider/stream no finalizado, temporización de test o bug UI real. Reparar **la única causa compartida** en harness/consumidor responsable, sin subir timeouts a ciegas, eliminar pantallas, capturas, semántica, `expect`s o hacer `skip`. Volver a correr el **archivo completo una sola vez**; preservar accesibilidad, `360×800`, `390×844`, `412×915` y escalas si ya forman parte del test aprobado. Si no comparten causa, registrar la excepción concreta sin inventar un arreglo común.

### D. DOS ERRORES PEQUEÑOS E INDEPENDIENTES

- `mobile/test/features/pico_placa/data/four_city_consumption_audit_test.dart`: `Binding has not yet been initialized`. Inicializar `TestWidgetsFlutterBinding.ensureInitialized()` en el test **antes** de acceder a assets; no cambiar runtime por un fixture.
- `mobile/test/features/settings/presentation/settings_screen_test.dart`: espera literal `schemaVersion=9`; código actual es `AppDatabase.currentSchemaVersion=11`. Cambiar **solo** el oráculo incorrecto, mantener prueba de diagnóstico **sin placa, GPS, nombres, teléfono, documentos ni PII**.

**Estrategia:** arreglar A, C, D con causa + regresión. B es recuperación de inputs, no código nuevo. Detener únicamente las operaciones que arriesguen datos/conflicto; no crear cuatro macrobloques separados, no volver a correr los **3.315 PASS de V3 por protocolo**.

## 3. F2 — VALIDACIÓN REAL SIN REPETIR LA HISTORIA

1. Ejecutar **los tests focales de rutas modificadas** y los negativos relevantes (migración real, `UNKNOWN/STALE`, integridad OTA si se tocó). **Reusar** Viaje-ancla 3/3, Drift focal 3/3, presentación 68/68, PHP 13/37, Python 16 de V3/N1 **solo donde archivos/contratos no cambiaron**. Un resultado PASS del árbol V3 no certifica los archivos alterados en V4-R1.
2. Formato `dart format --output=none --set-exit-if-changed` sobre rutas Dart rastreadas; comando global literal exigido por `AGENTS.md` si es seguro. El V3 global chocó con una ruta ignorada rota bajo `mobile/build`: **no limpiar ni borrar artefactos ajenos**. Distinguir `FORMAT_TRACKED=PASS` de `FORMAT_GLOBAL=BLOCKED_ENV`; no llamar PASS a una ejecución global fallida. Ejecutar `flutter analyze` una vez sobre el árbol final.
3. Después de reparaciones focales, **una sola ejecución `flutter test` global final** (obligación de `AGENTS.md`) sobre el TREE final. Guardar el exit code y contar PASS/SKIP/FAIL, distinguir `FAIL_INPUT` de `FAIL_CODE`. Si quedan exactamente pruebas B por artefactos genuinamente ausentes, **GLOBAL=FAIL_INPUT**, NO `PASS`, y continuar con tareas independientes. Si aparecen **fallos nuevos**, hacer regresión causal limitada a rutas cambiadas y, si la reparación altera el resultado global, repetir la global **solo una vez más si es necesario para certificar el árbol modificado**. No hacer loop de diez ejecuciones.
4. **OTA:** reutilizar `RestrictionPublicationService`, manifest/publicador existentes y `DatasetSyncService`, **no crear otro motor, panel ni API**. Si existe servidor QA aislado con datos editoriales aprobados, un solo E2E: publicación de **snapshot completo** de jurisdicciones aprobadas → manifest versión/hash → cliente Drift → persistencia al reabrir → rechazo SHA incorrecto, rollback/last-good y `UNKNOWN` por cobertura desconocida. **Cambiar habilitada/deshabilitada y números/días por datos**, no por `if` de ciudad. Si falta servidor, ejecutar solo QA de contrato/cliente que ya funciona con HTTP local donde corresponda, registrar `OTA_E2E=NOT_RUN_ENV` y no recrear Docker, Hostinger o producción para simular un PASS.
5. **Verificación nacional sin inventar otro test gigante:** inspeccionar si el consumidor lee los cambios de manifest/dataset efectivamente para **dos jurisdicciones de prueba y dos modalidades**; probar habilitar/deshabilitar y cambio de dígitos o días **solo si ese contrato no está ya cubierto por pruebas vigentes**. `UNKNOWN/STALE` y ventana fullDay deben permanecer seguros. No declarar `NATIONAL_READY` si el selector todavía depende del catálogo empaquetado o el panel no puede publicar todos los predicados del motor; esos son **pendientes conocidos del producto**, no permiso para reescribir arquitectura en V4-R1.

## 4. F3 — COMPILAR APK DEV, SEPARADO DE LA APROBACIÓN DE RELEASE

**Intentar UNA compilación interna** desde `mobile` con el toolchain usado en V3, si: migraciones relevantes y conservación de datos PASS, pruebas críticas del motor/`NO_FALSE_ALLOWED` PASS atribuibles al código actual (permitiendo `INPUT_MISSING` exclusivamente para comparativas históricas), `flutter analyze` PASS y sin fallos nuevos conocidos de seguridad/privacidad. Los **seis inputs históricos ausentes**, por sí solos, no bloquean el build. Las 16 visuales se investigan y corrigen en este lote; si persisten fallos funcionales de UI crítica, **no presentar el build como validado**, aunque pueda compilarse para diagnóstico aislado.

Comando preferido **si la caché de paquetes es suficiente**: `flutter build apk --debug --no-pub`. Si falla, una reparación mecánica **local** sustentada por el log; no cambiar symlinks del sistema, Developer Mode, antivirus, firma, `applicationId`, credenciales, permisos, package ni versión de base de datos por reflejo. Anotar el comando/exit real. **Si compila**, inspeccionar existencia/bytes y SHA-256 de APK, package/versionCode/firma cuando herramientas locales disponibles, y **PONER EL APK REAL DENTRO DEL ÚNICO ZIP**; etiqueta `DEV_INTERNAL_NOT_RELEASED`. Si no compila, estado honesto `APK_BUILD=FAIL|NOT_RUN_ENV`, ZIP sin APK y error preciso; no generar un enlace inexistente.

**Prohibición física**: no instalar en Mi A3 en este bloque; no desinstalar la DEV antigua, no `pm clear`, no perder Garaje/Billetera/fotos. Firma/versionCode/migraciones/QA y autorización expresa siguen siendo gates para tocar el equipo. **Build DEV ≠ prueba OTA Android ≠ release**.

## 5. INVARIANTES DE PRODUCTO / CAMINO REAL HASTA TERMINAR

- **Un motor nacional `schemaVersion=2`, parametrizado por datos**, por autoridad/departamento/municipio/pueblo, modalidad, servicio, dígitos, pares/impares, días, festivos, horarios, vigencia, exenciones/ámbito sustentados. Publicación oficial de alcaldía/gobernación/secretaría es válida **para los campos que declara expresamente** aunque no haya PDF de decreto. Cualquier cambio habitual via **servidor → dataset versionado/habilitable → manifest SHA → OTA → caché Drift → cálculo offline**, sin APK nueva por ciudad. La ausencia o vencimiento de cobertura **nunca implica `ALLOWED`**; usar `UNKNOWN/STALE`. `partial` no se promueve artificialmente a `complete`.
- **Privacidad:** placas, cédulas, matrículas, fotos, contratos, documentos y ubicaciones identificables **solo en la app** según arquitectura local-first; no exportar PII en logs/ZIP/telemetría. Registro **opcional** y administración futura de usuarios/categorías, correos/exportación con consentimiento, CDA/SOAT, aliados y publicidad son **módulos adicionales pendientes**, no se deben fingir implementados ni introducir ahora como refactor. `AGENTS.md` prevalece donde Free 1.0 y Ads OFF entran en conflicto con monetización no autorizada.
- **Secuencia posterior a V4-R1 sin nuevos diagnósticos infinitos:** (a) publicar/consumir datos nacionales y selector geográfico 100 % basado en datasets, incluyendo habilitación/deshabilitación; (b) completar panel editorial y actualizaciones de contenidos autorizadas; (c) registro opcional y administración privada de usuarios con consentimiento explícito; (d) QA físico, seguridad de histórico y firma real; (e) merge/despliegue **solo con aprobación**. No equiparar APK DEV con producto nacional terminado.

## 6. GIT / SEGURIDAD / ENTREGA SIN PINGPONG

- **Código producto:** `HOLD_SECURITY` no queda resuelto por escanear solo el diff V4-R1. Hacer **una revisión acotada** del delta para no introducir secretos. Si se dispone de identificación exacta del enlace/hallazgo histórico, registrar qué objeto requiere saneamiento, sin reescribir Git history, hacer force push, abrir un PR nuevo ni subir un bundle privado. **No push/merge de producto hasta demostrar cierre del riesgo y confirmar autorización de la operación.** El Director conservará la continuidad documental en PR79; Codex no necesita hacer commits documentales concurrentes allí.
- **Persistencia local recuperable:** preferir un commit local claro en candidato aislado propio (solo rutas autorizadas) y un `RECOVERY/RC2_TO_FINAL.patch` aplicado sobre RC2 exacto; verificar `git apply --check`, `git apply`, `git add -A`, `git write-tree` esperado en clon separado. Devolver HEAD, TREE y SHA256; **no inventar que el commit local ya está en GitHub**. No incluir bundle RC2 gigantesco otra vez.
- **Un solo ZIP** en `D:\codex\_REPORTES\PicoRadar\<TASK_ID>\delivery\`: `FINAL_REPORT.md` breve con los 4 grupos y decisiones; `GATES.csv` con comandos/exits/árbol; logs focales con errores y resumen de la global final; `RECOVERY/RC2_TO_FINAL.patch` y manifiesto SHA256/CRC; **APK binaria si se compiló**, con SHA/paquete/firma y marca DEV. **Nada de credenciales, placas, usuarios reales, dumps SQL, fotos/documentos, ZIPs parciales, APK RC2 ni bundle repetido**. Comprobar ZIP CRC/manifiesto y devolver **una sola ruta Windows + SHA256**.

**Campos de salida obligatorios, no ampliar con estados ambiguos:**

```text
TASK_ID=PICORADAR-N1-V4R1-QA-CAUSAL-APK-UNICO-20261116
BASE_V3_TREE=829f202b27348c93d354acc4658e9fc0f7e939a8
FINAL_HEAD=<SHA_LOCAL_O_NOT_COMMITTED>
FINAL_TREE=<SHA_GIT_WRITE_TREE_REAL>
MIGRATIONS_6=PASS|FAIL|HOLD
HISTORICAL_INPUT_6=PASS|INPUT_MISSING_VERIFIED|FAIL
TRIP_VISUAL_16=PASS|FAIL|HOLD
BINDING_SETTINGS_2=PASS|FAIL
DART_CRITICAL=PASS_SCOPED|FAIL|NOT_RUN_ENV
FORMAT_TRACKED=PASS|FAIL
FORMAT_GLOBAL=PASS|BLOCKED_ENV|FAIL
FLUTTER_ANALYZE=PASS|FAIL|NOT_RUN_ENV
MOBILE_FULL_QA=PASS|FAIL_INPUT|FAIL_CODE|NOT_RUN_ENV
OTA_E2E=PASS_LAB|FAIL|NOT_RUN_ENV
NATIONAL_DATA_ONLY=PASS_SCOPED|PARTIAL|NOT_RUN_ENV
APK_BUILD=PASS|FAIL|NOT_RUN_ENV
APK_DELIVERED=YES|NO
ANDROID=NOT_INSTALLED_SAFE
GITHUB_PRODUCT=HOLD_SECURITY|VERIFIED_CLEAR_NOT_PUSHED
PRODUCT_RELEASE=NO_GO
NEXT_ACTOR=CHATGPT_DIRECTOR
```

**Criterio de parada:** si existe WIP concurrente o riesgo de pérdida de datos, detener **solo** ese paso y ejecutar lo independiente con aislamiento autorizado. Ante una precondición inalcanzable dejar evidencia **una vez**, no emitir otro prompt de diagnóstico, y avanzar hacia APK DEV siempre que sea seguro. **No repetir 3.315 PASS sin delta; no inventar 30 bugs independientes; no crear motor por municipio; no publicar antes de cerrar seguridad y QA.**