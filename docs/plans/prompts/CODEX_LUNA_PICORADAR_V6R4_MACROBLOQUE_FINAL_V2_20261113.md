# CODEX LUNA — PICO RADAR V6R4 — MACROBLOQUE ÚNICO V2 PARA CERRAR CUSTODIA, QA DE EJECUCIÓN, PUBLICADOR Y BUILD LOCAL

**TASK_ID:** `PICORADAR-V6R4-CLOSE-RUNTIME-PUBLISHER-ANDROID-QA-ONCE-20261113-V2`  
**Orden válida:** sustituye SOLO el prompt residual `PICORADAR-V6R4-RESIDUAL-ONCE-CUSTODY-RUNTIME-20261113`, **si aún no se empezó**. No volver a ejecutar el macro original V6R4 (`PICORADAR-V1-V6R4-NATIONAL-REGISTRY-DOSQUEBRADAS-QA-ONCE-20261113`). Si ya está ejecutándose cualquier otro lote, no abrir segundo escritor: terminar con `BLOCKED_CONCURRENT_WRITER` sin tocar su checkout. Si el residual V1 empezó o terminó, preservar su resultado y ejecutar únicamente gates aún no satisfechos, sin duplicar commits, logs ni pruebas.

**Responsabilidades:** CHATGPT DIRECTOR define el alcance y decide aceptación; CODEX LUNA ejecuta sin rediseñar la arquitectura. **Meta:** dejar recuperable V6R4, certificar datos→Laravel/OTA→Drift/UI→APK QA local siempre que las herramientas lo permitan, sin crear un motor por municipio. **Una sola salida final:** UN ZIP real para adjuntar a ChatGPT; el texto de respuesta de Codex es solo una línea de estado + ruta y SHA del ZIP.

**Fuente obligatoria:** ZIP físico `PICORADAR_CONTINUITY_PACK_V6R4_20261113.zip` (puede venir con sufijo `(1)`): tamaño **85.294.656 B**, SHA-256 `474a18a916fc0b8bc0f0cec4f34fcee674d0679a08bba36c9561caa70b75b7fe`; contiene `EVIDENCIA/PICORADAR_V6R4_NATIONAL_REGISTRY_QA_EVIDENCIA_UNICA.zip` (85.251.541 B; SHA-256 `6d43ff1882925748c66f5a65f53947f63f76dd49a98c921c75a2ace9d4d9f1fd`). Obtener ubicación real del archivo, no adivinar Descargas ni asumir que aparece en D:. Si el paquete es accesible por otra ruta íntegra, úsala. **No solicitar archivos históricos V5/V6R3.**

## A. Contrato inviolable de producto y reglas de ejecución

1. Un único motor nacional `schemaVersion=2` reutilizable, Flutter + Drift + `DatasetSyncService` + Laravel `RestrictionImportService`/`DatasetReleaseValidator`/`DatasetPublisher`. Los datos por autoridad y modalidad son habilitables; una actualización normal de calendario debe distribuirse por manifest/version/SHA/OTA **sin APK nueva**. Municipio sin cobertura o `enabled=false` = **UNKNOWN**, jamás circulación libre. Nueve pares tipados soportados no equivalen a nueve coberturas en cada municipio.
2. La meta es cobertura nacional progresiva de **municipios, departamentos, ciudades y pueblos/centros poblados** con ámbito comprobado; no pedir un decreto PDF cuando **una página oficial vigente** de alcaldía, gobernación o autoridad de tránsito acredita expresamente el hecho. No inventar festivos, exenciones, geocercas, zonas, matrícula de origen, límites horarios ni vigencia; mantener `partial` + `UNKNOWN/STALE` según evidencia. El inventario DANE (1.104 municipios) **NO** equivale a 1.104 normas activas.
3. Cumplir seis leyes existentes L1 KISS/Ponytail, L2 antirruido, L3 antiparches, L4 UX aprobado, L5 comprobación independiente, L6 antipingpong, y `AGENTS.md`/contratos específicos. No instalar skills, modificar normas, reinventar arquitectura, crear un segundo ensamblador o reabrir la auditoría nacional. Mantener Inicio, Garaje, Apps, Viaje, Conducir y cámaras.
4. **Prohibido:** tocar producción/Hostinger/CDN público, DB con datos reales, vehículos/placas de usuarios, Mi A3/ADB, publicar dataset o APK, `main`, hacer merge, rebase/force-push, limpiar/resetear/stashear WIP de terceros, instalar software de pago, lanzar CI de pago, imprimir secretos. Este macrobloque autoriza **commits solo locales en un clon aislado** y una compilación APK **debug QA local si pasa el preflight de recursos**, nunca instalación física ni release firmado.
5. No usar `--skip`, no silenciar errores, no modificar `staleAfter`, fechas normativas, `appliesOnHolidays` ni aserciones para conseguir verde. Una prueba de laboratorio no demuestra verdad jurídica ni publicación real. Cualquier falla real admite **una corrección causal focal y una repetición focal**, registrando RED y GREEN; no suite masiva ni ciclos infinitos.

## B. Estado exacto ya acreditado — NO VOLVER A INVESTIGARLO

- V6R3 base del bundle: commit `8d4ece555f563b77aa76e88cd48329609c5e50cb`, tree `6371302314d57c8e6a0ac62955984a4414f85f85`; ese SHA no se recuperó por consulta GitHub (422). **NO usar `main` remoto como base sustituta.** V6R4 no trae commit; el ZIP preserva bundle V6R3 + patch con **cuatro modificados y cuatro nuevos**.
- LAB V6R4: **14 jurisdicciones / 33 DIVIPOLA únicos / 21 coberturas parciales / 115 reglas**, frente a 13/32/19/105 de V6R3; 13/13 jurisdicciones previas idénticas. Atlántico tiene 20 códigos bajo una autoridad; no interpretar 33 códigos como 33 autoridades. Snapshot `server/database/data/restrictions/lab/national_bulk_v6r4_2026-11-13.json` SHA-256 `4b6a9ae5d41fabaff743655dfb376493e289ba4e8c6b71ddd0c88aad132159c8`.
- **YA PASS POR LOGS:** Python focal 14/14, generador determinista y PHP esquema 2 con cinco negativos. No repetirlos si blobs/inputs no cambian. **FALTAN:** dos tests Flutter/Drift/OTA V6R4 `NOT_RUN_ENV` por SDK ausente, Laravel DB QA `BLOCKED_ENV_DB`, compilación Android y pruebas físicas. No marcar como falla de código algo que jamás corrió.
- **Incertidumbre concreta Dosquebradas:** boletín oficial 26-sep-2026 acredita retorno 28-sep, L–V, parejas de dígitos, 06:00–20:00 y dos modalidades; **NO** acredita festivos, ámbito vial exacto ni exenciones. `appliesOnHolidays=true` está en **10 reglas LAB como hipótesis editorial**, no ley probada. `staleAfter=2026-11-19T23:59:59-05:00` y el contrato de consulta diaria requieren estar vigente hasta el inicio del día siguiente: **18-nov aún cubierto, 19-nov `STALE`**. No extender la fecha para hacer pasar tests.

## C. F0 — CUSTODIA Y COMMIT LOCAL, ANTES DE DEPENDER DEL SDK

1. Una sola inspección read-only del checkout reportado `D:\codex\_isolated\PicoRadar-V6R4-National-Registry-QA-20261113` si existe: `git rev-parse HEAD`, `git status --porcelain=v1`, `git diff --name-only`, `git ls-files --others --exclude-standard`, SHA del snapshot y estado de otros agentes. Si el candidato local contiene cambios posteriores, WIP ajeno, HEAD distinto o algo no reconciliable, **NO lo modifiques**; construir un clon NUEVO desde el bundle+patch del ZIP, sin limpiar el original. Si el candidato coincide exactamente, también puedes usar **nuevo clon** para eliminar riesgo de interferencia. No hacer búsquedas recursivas de discos.
2. **Ocho rutas exactas** a custodiar con `git add --` explícito y sin otras rutas:

```text
mobile/test/features/pico_placa/data/national_bulk_v6r3_ota_test.dart
scripts/qa/assemble_national_bulk_v6r3.py
scripts/tests/test_assemble_national_bulk_v6r3.py
server/tests/contracts/validate_national_lab_v6r3.php
server/database/data/restrictions/lab/2026-11-13-dosquebradas-traditional-partial.json
server/database/data/restrictions/lab/national_sources_manifest_v1.json
server/database/data/restrictions/lab/national_bulk_v6r4_2026-11-13.json
server/database/data/restrictions/lab/national_bulk_v6r4_2026-11-13.sha256
```

3. Si necesitas restaurar: descomprimir los dos ZIP a una carpeta temporal aislada; `git clone --no-checkout <full.bundle> <DIR_NUEVO>`; configurar allí `core.autocrlf=false`; `git checkout -b feat/picoradar-v6r4-lab-candidate 8d4ece555f563b77aa76e88cd48329609c5e50cb`; `git apply --check <patch>` y `git apply <patch>`. Ejecuta los comandos desde la ruta correcta, con rutas absolutas para bundle/patch. Verifica exactamente 4 `M` + 4 `??` y `git diff --check` (no usar `git diff` aislado como evidencia de los 4 nuevos).
4. Crear **un único commit LAB local de custodia** con las ocho rutas tras `git diff --cached --check` y revisión de `git diff --cached --name-only`; anota en mensaje `V6R4 LAB_ONLY / Flutter not certified` si sigue sin ejecutarse. No condicionar el commit a Flutter ni etiquetarlo `RELEASE`. Si ya hay commit idéntico, reutilizar SHA, no crear otro. Si cambias algo después por causa confirmada, **un segundo commit focal** con archivo(s) exactos y ambos SHA documentados; no `--amend` de historia ajena.
5. Crear bundle **solo desde la rama aislada que contiene el commit** (incluir ancestros necesarios; evitar `--all` que exporte refs/WIP de terceros). Verificar `git bundle verify` y **checkout del HEAD del candidato en clon nuevo**. Guardar HEAD/TREE/parent y `git status` final. La prioridad es no perder los ocho archivos aunque no exista Flutter.

## D. F1 — DESBLOQUEO REAL Y ACOTADO DE FLUTTER/DART (SIN PROTOCOLOS VACÍOS)

1. UNA búsqueda limitada a `Get-Command flutter,dart`, `where.exe`, variables de entorno y **rutas conocidas de V5** o inventario del host; verificar versión compatible con `mobile/pubspec.yaml`, `pubspec.lock`, `.dart_tool/package_config.json`. No reintentar el diagnóstico en cinco prompts.
2. **Cambio respecto de la orden anterior:** si el SDK no existe, el objetivo NO es conformarse de inmediato con `NOT_RUN_ENV`. Si tienes internet, espacio, memoria y permisos normales, puedes preparar **una instalación gratuita, oficial, portable y aislada en `D:\codex\_tools\flutter`**, sin tocar SDK de otros proyectos, PATH global, registro ni Developer Mode. Una sola instalación acotada con procedencia y versión verificadas de la distribución oficial Flutter; usa caché de dependencias existente primero y `flutter pub get --offline` cuando corresponda. No fijar una versión a ciegas ni modificar `pubspec.lock`, `pubspec.yaml` o dependencias para acomodar un SDK incorrecto. Si descarga/instalación no es viable con recursos gratuitos y seguros, `NOT_RUN_ENV` con causa concreta **y sigue con F0/F3 independientes**.
3. Si herramientas y dependencias están disponibles, desde `mobile` ejecutar:

```text
flutter test --no-pub test/features/pico_placa/data/national_bulk_v6r3_ota_test.dart
flutter analyze test/features/pico_placa/data/national_bulk_v6r3_ota_test.dart
dart format --output=none --set-exit-if-changed test/features/pico_placa/data/national_bulk_v6r3_ota_test.dart
```

Si la versión instalada requiere sintaxis equivalente, registra el comando real. Si `package_config` no existe y hay caché local, un `flutter pub get --offline` seguro; si requiere red, solo fuentes oficiales/gratuitas y sin actualizar lock; **un intento acotado**. Guardar ruta SDK, versión, hash de `pubspec.lock`, stdout/stderr, exit code y número real de tests ejecutados. No falsear PASS con `flutter analyze` sin `flutter test`.
4. **Oráculo de los DOS tests existentes:** (i) importación Drift/HTTP loopback V5→V6R3→V6R4, 2→13→14 jurisdicciones, 3→19→21 coberturas, 15→105→115 reglas; manifiesto revision/SHA; hash malo rechazado; último bueno, Garaje y preferencias preservados, cierre/reapertura; (ii) Trip/catalog y widget desde Drift real: 66170 Dosquebradas ≠ 66001 Pereira, 05360 Itagüí propio, Atlántico 20 códigos/1 autoridad; viernes Dosquebradas dígitos 8/9, horario 06–20, resultado individual UNKNOWN; Manizales 01-dic STALE, Itagüí 30-nov informativo y 01-dic STALE.
5. **Único añadido permitido al Dart si falta:** aserciones de borde **18-nov/19-nov** para Dosquebradas según el contrato diario. Diagnóstico preciso del test, no trucos de zona horaria ni cambio de TTL. Para festivos, **no** introducir como hecho legal `appliesOnHolidays=true`; evaluar si el UI/estado personal actual evita conclusiones falsas. Si la ficha informativa atribuye prohibición festiva sin fuente, documentar `PUBLICATION_HOLD_DOSQUEBRADAS_HOLIDAY`; no diseñar un motor municipal ni extender schema. Si falla por código, una corrección causal mínima + una repetición del test afectado; si SDK ausente, `NOT_RUN_ENV`.

## E. F2 — LARAVEL Y PUBLICACIÓN DE SNAPSHOT COMPLETO **SOLO EN QA LOCAL**

1. En una sola pasada, detectar PHPUnit/Composer, PDO disponibles y **DB efímera aislada realmente disponible**. `pdo_sqlite` ausente **no implica** que Laravel sea imposible: si existe MariaDB/MySQL de pruebas gratuita y separada, usarla con `.env.testing` temporal, usuarios/tablas sintéticas y aislamiento verificable. Si no existe, puedes arrancar **una instancia QA portable/temporal gratuita** solo si es sencillo, permitido, sin servicio global y hay recursos; no improvisar contenedores persistentes ni tocar bases ajenas. Un intento razonable; si no se puede, `BLOCKED_ENV_DB` y avanzar a F3/F4 si son independientes.
2. Si DB QA está certificadamente aislada, **reutilizar** servicios/admin existentes: importar schema2→draft→validar→revisar/aprobar→preview de **SNAPSHOT COMPLETO de todas las autoridades ya aprobadas en ese entorno**→revision/SHA/manifest QA→publicación local loopback→rollback/rechazo. Asegurar negativo para hash incorrecto, pérdida de cobertura previamente aprobada al publicar un snapshot parcial, `complete+[]`, autorización/roles. No crear portal nuevo; 4 combos del formulario frente a 9 pares validados es un pendiente **focal**, verificar primero el importador JSON.
3. **No confundir** `national_sources_manifest_v1.json` del LAB (14 fuentes, habilitables para QA) con manifest o cobertura editorial aprobados para producción. Como el importador Drift **reemplaza** el conjunto de restricciones, **NO publicar** el snapshot V6R4 si no representa la unión completa de fuentes productivas aprobadas. Probar la política de *no pérdida* en QA local; si el publicador existente no la comprueba, registrar bloqueo concreto y aplicar **solo la validación genérica mínima** si hay entorno/test causal para demostrarlo; no declarar GO de publicación por un conteo fijo de 14. `enabled=false` jamás equivale a `ALLOWED`.
4. **Todo el material previo utilizable se conserva:** fuentes válidas ya incluidas, QA de otras fases, candidatos IA2 catalogados, Bogotá taxis R2 y otros tipos **no deben darse por publicados ni descartarse**. No cargar 50 borradores sin normalizar ni inventar diez ciudades adicionales. Reportar en una tabla muy corta `aprobado_integrable / LAB_partial / HOLD / no_verificado`; si algo ya aprobado falta del snapshot completo, bloquear la publicación QA hasta integrarlo por el mecanismo existente, sin reescribir el motor.

## F. F3 — BUILD ANDROID DEBUG **LOCAL Y CONDICIONAL**, SIN TÉLEFONO

1. Solo si `F1` tiene PASS real y la instalación Android/Gradle local **ya es compatible**, comprobar una vez memoria RAM/commit disponible, espacio y firma/debug keystore sin leer ni publicar secretos. No reintentar builds que ya fallaron por memoria sin condición nueva; no instalar AGP/SDK globalmente ni borrar build de otros proyectos.
2. Si recursos suficientes y sin perjuicio a la PC, intentar **una compilación `flutter build apk --debug`** para V6R4; registrar versión de Flutter/Android, SHA del código, stdout/stderr, exit, tamaño/SHA del APK. APK construido **no es QA física, ni release, ni permiso para instalar sobre Mi A3**. Si el preflight es adverso, `ANDROID_BUILD=BLOCKED_RESOURCES/NOT_RUN_ENV`, y cerrar los demás gates sin retry. Conservar el APK QA resultante dentro del mismo ZIP final solo si cabe y no contiene activos privados; no generar otro ZIP.
3. QA física futura exige consentimiento para intervenir el dispositivo y **firma compatible sin desinstalar Garaje**; no simular ADB ni declarar instalación exitosa sin logs del teléfono. La publicación OTA externa sigue fuera de este lote; el test loopback solo prueba contrato de sincronización local.

## G. F4 — GitHub y continuidad SIN EXPONER HISTORIA NI CONFUNDIR DOCS CON CÓDIGO

- El **director** actualiza por separado el estado documental del PR #79 de forma segura. Este encargo **NO autoriza push de código o bundles** desde la PC: `main` y PR #71 permanecen intactos; ni PR #79 documental es un PR de código V6R4. Si el árbol local carece de remoto utilizable o el acceso da 403/suspensión, no reintentar por rutina.
- Dejar SHA del commit LAB y contenido recuperable en el **ZIP único**; confirmar qué código está realmente en GitHub y qué sólo existe en bundle. No subir historia completa de 85 MB a un repositorio público sin revisión de secretos y procedencia; la integración GitHub de código requiere posteriormente un gate explícito de seguridad y de rama.
- No repetir auditorías V5, V6R3, IA2/50 medidas, DANE/1.104 o las 14 pruebas Python si los mismos hashes ya están acreditados. Si un archivo fuente cambia, repetir **únicamente validadores afectados** para ese SHA, nunca usar PASS de hashes anteriores como certificado del nuevo.

## H. F5 — UN ZIP FINAL, GATES Y RESPONSABLE FINAL

**Destino:** `D:\codex\_REPORTES\PicoRadar\V6R4-CLOSE-ONCE-20261113\delivery\PICORADAR_V6R4_CLOSE_RUNTIME_PUBLISHER_ANDROID_QA_EVIDENCIA_UNICA.zip` (crear directorio nuevo, nunca sobrescribir una entrega existente). **UN ZIP, no una carpeta de adjuntos ni dos entregas.**

Contenido mínimo **dentro** del ZIP:

```text
FINAL_REPORT.md                 decisión por F0–F5, HEAD/TREE, trabajo real y NEXT
GATES.csv                       F0 custodia, F1 Flutter, F2 Admin QA, F3 APK debug, F4 continuidad, F5 paquete
GIT/V6R4-CANDIDATE.bundle       bundle verificable desde HEAD con ocho rutas versionadas
GIT/RESTORE.md                  instrucciones precisas de clon/checkout y SHA HEAD
GIT/CHANGED_PATHS.txt           ocho rutas previstas y cualquier delta causal adicional justificado
LOGS/                           logs crudos ejecutados (sin credenciales) y un preflight por entorno
QA/                             solo fixtures/deltas nuevos necesarios, no ZIP históricos duplicados
OPEN_HOLDS.md                   festivos/ámbito/TTL y seis HOLD existentes, sin declararlos resueltos
MANIFEST_SHA256.csv             path, bytes, SHA256 de cada miembro distinto del propio manifiesto
ANDROID/                        APK debug y su SHA, solo si se compiló y es seguro adjuntarlo
```

Verificar el ZIP (CRC y 100% tamaños/hash del manifiesto), el bundle en **clon limpio** y los 8 archivos. SHA-256 del ZIP final solo **fuera** del ZIP para evitar auto-referencia. Si scripts/SDK fallaron, registrar exit y causa, no generar reporte de PASS ficticio. No incluir DB, Garaje real, secretos, backup privado, logs con tokens ni un segundo ZIP de pruebas.

**Matriz de salida sin reintentos:**

| Gate | Si resulta PASS | Si no puede ejecutarse de forma segura |
|---|---|---|
| F0 commit y bundle | HEAD candidato recuperable | preservar ZIP/parche original, `BLOCKED_CUSTODY` con razón concreta |
| F1 Flutter/Drift/OTA | dos tests reales y bordes de fecha | `NOT_RUN_ENV` o `FAIL_CAUSE_CONFIRMED`, nunca PASS de V5 |
| F2 Laravel con QA DB | import/review/publicación QA local/rollback | `BLOCKED_ENV_DB` sin tocar producción |
| F3 APK debug | APK local con SHA, no instalado | `BLOCKED_RESOURCES`/`NOT_RUN_ENV`; no retry destructivo |
| F4 GitHub/docs | estado documental reflejado por director, hashes de código separados | nunca inventar push de producto; `CODE_REMOTE_NOT_SYNCED` |
| F5 Entrega | **un ZIP íntegro** | informar falla de empaquetado sin falsificar evidencia |

**Respuesta final de Codex (única y compacta):**  
`TASK_ID=... | F0=... | FLUTTER=... | ADMIN_QA=... | ANDROID_BUILD=... | CODE_GITHUB=NOT_PUSHED | HEAD=... | TREE=... | ZIP=RUTA_REAL | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`.

**IMPORTANTE:** si Flutter/DB no se desbloquean en esta ejecución, **NO** abrir automáticamente otra ronda de diagnósticos; entrega el candidato preservado, causa exacta y la alternativa concreta para ejecutar QA en entorno apto. La cobertura nacional futura se amplía **mediante datos oficiales aprobados**, con los 6 HOLD abordados como **predicados genéricos** cuando haya fuente/oráculo, jamás un motor por ciudad. El director decide el siguiente gate basándose solo en lo realmente nuevo del ZIP.
