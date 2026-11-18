# CODEX LUNA — PICORADAR V6R4 — V6 CORREGIDO, EJECUCIÓN ÚNICA SIN PING-PONG

**TASK_ID:** `PICORADAR-V6R4-V6-FOCAL-G2-SCHEMA2-SECURITY-ANDROID-20261114`  
**Estado:** ORDEN EJECUTABLE **solo si el V6 original aún NO inició**. Sustituye el Markdown `CODEX_LUNA_PICORADAR_V6R4_V6_CIERRE_INTEGRACION_SEGURIDAD_ANDROID_20261114.md` en ese único supuesto. Si ya está ejecutándose, **NO iniciar otra sesión, no interrumpir, no ejecutar tareas en paralelo**: entregar el ZIP del proceso activo al director.  
**Dirección:** ChatGPT decide arquitectura, aceptación y riesgos; Codex ejecuta pasos cerrados y reporta pruebas. **Un solo ZIP de evidencia**.  
**PRODUCT_RELEASE=NO_GO** durante toda esta tarea. Sin merge, Hostinger, CDN real, DB real, Mi A3, publicación productiva, datos personales, CI paga ni APK release.

## 0. Mandato y decisiones ya tomadas — no abrir otra auditoría

**Meta de producto mantenida:** un **solo motor nacional schemaVersion 2** en Flutter/Drift, alimentado por datasets editoriales completos y aprobados de alcaldías, gobernaciones y tránsito para ciudad, municipio, departamento, pueblo/corredor solo con competencia y ámbito probado. Fuentes institucionales vigentes sirven **para los campos que expresan**, aunque no haya decreto PDF. Por cobertura faltante, exención, feriado, GPS o vigencia no probados: `UNKNOWN`/`STALE`; nunca `ALLOWED` por ausencia de fuente. Actualización ordinaria por manifiesto/versiones/hashes OTA sin nueva APK ni código por ciudad. **SHA-256 prueba integridad de bytes, no firma digital criptográfica.** Datos LAB con 14 autoridades, 33 DIVIPOLA, 21 coberturas parciales, 115 reglas NO equivalen a cobertura nacional completa.

**Baseline cerrado en SHA idéntico:** ZIP V5 `PICORADAR_V6R4_V5_EVIDENCIA_UNICA.zip`, SHA256 `d9252ca2b690daaec6867c3c904885da30c0b69d7221698a611b22c71b785fca`; Git `HEAD=15948a50332589ff3d1fb3157b6976809fe5a680`, `TREE=8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`, padre `09b4f0a35fa6eae2192c88c83d2afe10133aabfe`; bundle `GIT/full-final.bundle`, SHA256 `dad16fccb97493add593bbacbd13edfb1db60219f14b445fd5e22141356639a1`. Rama local `feat/picoradar-v6r4-lab-candidate`. PR #71 `recovery/20261019-modern` SHA `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, ancestro de **12 commits**. Candidato anterior: `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`.

**No repetir:** F0 custodia PASS, F1 Flutter/Drift/OTA/UI 3 casos PASS, F2 Laravel 33 pruebas/279 aserciones PASS, 14 Python PASS, tests de V5/V6R3, inventario de 50 medidas o 1.104 municipios, verificación ZIP V5 ya certificada. F3 Android bloqueado por recursos, F4 remoto bloqueado por falta de Gitleaks. Esas aprobaciones se heredan **únicamente para el árbol inalterado**. No modificar diseño, paquetes, schema2, migraciones ni motor para aumentar el número de tests.

**Hallazgo decisivo del director:** YA EXISTEN puentes de bytes Laravel→Flutter. NO crear nuevos servicios, tests E2E duplicados ni ensambladores:  
- Schema2 **prioritario:** `server/tests/Feature/RestrictionSchemaV2LabRoundTripTest.php::test_schema2_dataset_publishes_one_v2_city_without_changing_seven_r2_legacy_cities` escribe `PHP_G2_V3_REAL_LAB_RELEASE.json` y `PHP_G2_V3_REAL_LAB_MANIFEST.json`; `mobile/test/core/sync/restriction_g2_same_bytes_test.dart` prueba con el nombre exacto **`Laravel schema2 release SHA reaches loopback Flutter import and survives failures`**.  
- G1 legacy ya existe en `server/tests/Feature/RestrictionNationalLabPublicationTest.php` y `mobile/test/features/pico_placa/data/g1_laravel_flutter_same_bytes_test.dart`; **NO ejecutar G1 por hábito**. La integración G2 reutiliza la arquitectura aprobada.  
- El puente G2 ensaya bytes publicados desde Laravel con HTTP loopback del test Dart, Drift y último válido; **NO acredita endpoint Laravel/CDN desplegado**, ni publicación productiva de las 14 autoridades.

## 1. F0 reducido — identidad y concurrencia (solo una comprobación)

1. Verificar una vez que no existe otro agente/escritor PicoRadar activo. Si hay uno: detener este nuevo trabajo con `BLOCKED_CONCURRENT_WRITER`; no cambiar ningún checkout.
2. En clon aislado o candidato confirmado: `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git status --porcelain`, `git merge-base --is-ancestor 0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a HEAD` y `git rev-list --count 0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a..HEAD` (esperado **12** en baseline). Si HEAD/TREE o estado no coinciden, NO sobrescribir trabajo local: restaurar el bundle V5 en **otro clon** bajo `D:\codex\_isolated\` y usar ese. No `reset --hard`, `git clean`, `stash` ajeno ni `force-push`.
3. Reusar Flutter 3.47.9 y PHP/Laravel ya disponibles; no descargar SDK Flutter, reinstalar Composer ni repetir herramientas buscadas. No alterar `origin` si apunta a bundle local.

## 2. G2 PRIORITARIO — cerrar puente schema2 **con pruebas existentes, sin duplicarlas**

**Primero reutilizar evidencia, antes de abrir BD.** En la carpeta de trabajo V5, la relación de huellas está en `LOGS/qa-output-hashes.csv` del ZIP V5. Buscar **solo** en la salida QA de V5 `qa\G2-v3-evidence` y las rutas explícitas allí registradas (no búsqueda recursiva del disco). Se requieren exactamente:

| Archivo G2 generado por Laravel | Tamaño esperado | SHA-256 esperado |
|---|---:|---|
| `PHP_G2_V3_REAL_LAB_RELEASE.json` | 59.273 B | `ecfbbbe1895ca702473704f92974ac4174bd183b3fe4d78a00a4305dc93e4a53` |
| `PHP_G2_V3_REAL_LAB_MANIFEST.json` | 424 B | `d977424c9a59e9d8c28c83e7ed6393e64754ea3d3ccc637430097b88f1dde9ff` |

Comprobar además `FIXTURE_R2_SCHEMA1_RELEASE.json`, `PHP_G2_V3_RESULT.json` y `PHP_G2_V3_INPUT_SHA256.txt` que produce el mismo caso PHP. SHA de R2 original: `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`; provino del paquete R2 autorizado en V5. Nunca sustituirlo por V6R4 ni exponerlo como fuente productiva. Si los ficheros y huellas G2 son correctos, **NO repetir PHP F2 ni levantar MariaDB**.

**Solo si faltan esos bytes o los existentes no superan sus hashes**, repetir **un único método PHP** (`test_schema2_dataset_publishes_one_v2_city_without_changing_seven_r2_legacy_cities`) con el mismo patrón de base QA efímera del informe V5: MariaDB loopback 127.0.0.1, nuevo puerto/data dir y credenciales sintéticas, `APP_KEY` sintética, `explicit_defaults_for_timestamp=ON`, SQL estricto, `DB_URL` vacío, configuración Laravel **efectiva** igual a esa DB vacía demostrada por SQL antes de `RefreshDatabase`. Reutilizar configuración XML temporal segura; NO usar `server/phpunit.xml` SQLite predeterminado ni `phpunit.mariadb.xml` en puerto 3306 a ciegas. `PICORADAR_R2_EVIDENCE_DIR` y `PICORADAR_G2_V3_EVIDENCE_DIR` apuntan a directorios QA exactos existentes. Seleccionar el método con `--filter` y `--list-tests` antes de ejecutarlo **una vez**; exigir un solo test y exit 0. Si el test regenerado produce bytes distintos por metadatos temporales, **NO modificar fechas para igualar los hashes de V5**: comprobar SHA interno manifest→archivo y contratos reales, registrar las nuevas huellas y distinguir `REGENERATED_QA_NOT_BYTE_IDENTICAL_TO_V5` de una alteración no explicada. Apagar y comprobar cierre del puerto inmediatamente al terminar. Ante fallo ambiental, `G2=BLOCKED_QA_INPUT_OR_DB` y avanzar a G4/G3 independientes; NO repetir 33 tests.

**Prueba Dart — ejecutar solo un caso existente:** colocar `PICORADAR_G2_V3_EVIDENCE_DIR` en el entorno de proceso apuntando a los bytes verificados. Desde `mobile`, invocar Flutter 3.47.9 con `--no-pub` en `test/core/sync/restriction_g2_same_bytes_test.dart` y `--name 'Laravel schema2 release SHA reaches loopback Flutter import and survives failures'` (nombre exacto; no ejecutar las otras dos pruebas de ese archivo que dependen de evidencias V1/G34 distintas). Registrar comando, exit real, un test PASS/FAIL y SHA de ambos inputs. Verifica 7 jurisdicciones heredadas + 1 sintética schema2, 12+1 coberturas, SHA, última versión válida tras respuesta inválida y persistencia sintética. Las pruebas PASS de F1 no se repiten.

**No sobredimensionar el PASS:** `G2=PASS_SCHEMA2_LARAVEL_BYTES_TO_FLUTTER_QA` solo si este caso termina exit0 sobre los bytes PHP de huella verificada. No declarar `LIVE_STAGING_HTTP_PASS`, `FULL_NATIONAL_PUBLISH_PASS` ni release. La rollback administrativa ya está ensayada en `DatasetPublisherTest` F2; el test cliente prueba conservación del último válido, **no confundir ambos conceptos**. No exigir que un rollback admin mantenga una versión numérica creciente: en el contrato vigente `publicationRevision` crece al retornar a una versión publicada anterior. No cambiar semántica para fabricar PASS.

**Cambios de código:** normal esperado **cero**. Solo si la prueba revela defecto de producto reproducible, arreglar dueño causal mínimo y correr RED→GREEN focal y regresión vecina afectada; no crear segundo motor, backend, schema3 o nuevas capas. Preservar datos personales locales y no simular ruta/vía no probada.

## 3. G4 — escáner de secretos y respaldo **solo de rama LAB**

**Obtención gratuita, una tentativa primaria:** Gitleaks 8.30.0 Windows x64 oficial `https://github.com/gitleaks/gitleaks/releases/download/v8.30.0/gitleaks_8.30.0_windows_x64.zip`; SHA256 ZIP **`54fe94f644b832dd08e8c3a5915efb3bfa862386d59fb27ca0792cb687a83573`**, contrastado contra registro de empaquetado Chocolatey. Descargar únicamente en directorio aislado `D:\codex\_tools\gitleaks-8.30.0`, comprobar `Get-FileHash -Algorithm SHA256` **antes** de extraer y verificar `gitleaks version`. Si no se puede descargar en un intento, se admite **una sola alternativa de espejo íntegro que entregue bytes con exactamente el mismo SHA y licencia gratuita**; si tampoco es posible, `G4=HOLD_SCANNER_UNAVAILABLE`, **SIN push**, y seguir G2/G3. No instalar globalmente, elevar privilegios ni crear otro bloque para buscar scanner.

**Escanear alcance correcto y destino publicable:** en **clon aislado del HEAD candidato** ejecutar `git rev-list --count BASE..HEAD` (12 si sin delta) y `gitleaks git --log-opts="BASE..HEAD" <ruta-clon>` con BASE sustituida por el SHA PR71 arriba y HEAD por el SHA REAL final. Capturar exit, versión, número de hallazgos y referencia a revisión, con `--redact=100`; no incluir valores, cadenas, parches o reportes Gitleaks crudos en ZIP/ChatGPT. Además generar en una ruta **temporal creada por este bloque** `git archive HEAD` y descomprimir para un `gitleaks dir` sobre el **árbol exportado**, no sobre `.git` ni WIP privado. Comprobar cobertura del árbol exportado (no `export-ignore` ocultando archivos relevantes) y revisar rutas de riesgo detectadas: `.env`, `.pem`, `.key`, `.p12`, `.jks`, `.keystore`, DB/dump, ZIP/APK, archivos personales y binarios nuevos. El único binario esperado de los 12 commits previos fue Gradle wrapper; no atribuirle seguridad por nombre sin comprobar. No inventar allowlist, suppress ni cambiar reglas para poner verde. Cualquier hallazgo genuino => `HOLD_SECRET_FOUND`; falso positivo => `HOLD_REVIEW_REQUIRED` hasta decisión del director.

**NO escanear después de publicar:** si G2 requiere un nuevo commit, escanear ese delta y el **árbol final** ANTES del push. Guardar SHA HEAD final. Un PASS requiere ambos Gitleaks exit0, cero hallazgos, revisión de rutas sospechosas y prueba de que el árbol escaneado es el que se publicará. Escaneo heurístico V5 NO reemplaza Gitleaks. F4 ya tiene auditoría manual de los 12 commits; no repetirla como investigación general.

**Push condicional:** verificar `git ls-remote` del GitHub oficial **sin mostrar tokens**. Repo `sierraglobalcompany-rgb/PicoRadar`. No usar `origin` local de bundle como destino ni modificarlo permanentemente. Solo si scanner PASS y no existe rama remota divergente, **un único push sin `--force`** de `feat/picoradar-v6r4-lab-candidate` al repositorio oficial; verificar ref remoto con SHA EXACTO. Si 403/cuenta suspendida/auth/restricción, `G4=BLOCKED_REMOTE` sin reintentos. **NO crear PR, merge, tag, release ni disparar GitHub Actions manualmente**. En el checkout auditado, los workflows `mobile.yml` y `server.yml` hacen `push` únicamente a `main`; verificar ese dato antes de publicar y detener si cambió, para no generar consumo de CI inesperado. Si el usuario no ha autorizado publicación ni siquiera en rama LAB, dejar lista la rama local y el bundle; no forzar. El PR documental #79 ya existente no sustituye el push de código ni es un permiso de release.

## 4. G3 — Android: no repetir un gate imposible en el mismo entorno

**Estado probado:** pagefile libre **3,37 GiB** frente a umbral histórico seguro **6 GiB**, `mobile/android/gradle.properties` tiene `-Xmx8G -XX:MaxMetaspaceSize=4G`. F3 **BLOCKED_HOST_RESOURCE_STABLE**, sin APK. Si es el **mismo host y no hubo cambio real de pagefile/recursos**, conservar ese bloqueo **sin nueva medición ni intentar Gradle**. Si consta cambio real de configuración o se dispone ya de un host local gratuito y autorizado con recursos apropiados, medir **una vez**, exigir margen >=6 GiB y dependencias/firma/SDK válidos; solo entonces ejecutar **un** `flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev --no-pub`, capturar exit y validar APK/firma/paquete/SHA. No cambiar JVM/Gradle, memoria virtual, versionado ni firma por optimismo; no ADB ni Mi A3 ni producción sin nueva autorización. Si no hay host apto: `G3=BLOCKED_HOST_RESOURCE_STABLE` con condición material de desbloqueo, no abrir otra tarea para constatar lo mismo.

## 5. G5 — entrega **UNA SOLA VEZ**, sin informes dispersos

Crear `D:\codex\_REPORTES\PicoRadar\V6R4-V6-FOCAL-20261114\delivery\PICORADAR_V6R4_V6_FOCAL_EVIDENCIA_UNICA.zip`. Debe contener únicamente: `FINAL_REPORT.md` (una página o conciso), `GATES.csv` con cada PASS/HOLD, comando exacto, exit realmente capturado, SHA del HEAD y de los bytes del puente; logs focales saneados; resumen Gitleaks saneado (nunca findings con tokens), evidencia remota si hubo push, ZIP manifest de miembros con SHA/tamaño y CRC, y **un solo Git bundle del HEAD final restaurable** más `RESTORE.md`. Si APK debug autorizado y generado, incluirlo solamente si es seguro y conservar su SHA, firma y procedencia; no incluir APK release, base QA, `.env`, contraseñas, artefactos R2 privados, carpetas de Garaje, ZIP previos, ejecutable Gitleaks o evidencia de secretos. Los JSON QA sintéticos de G2 pueden ir solo si fueron comprobados sin datos privados; si no, incluir SHA/tamaño y ruta de generación, sin afirmar autosuficiencia de esa entrada.

Revalidar manifest/CRC/miembros y extracción del **ZIP nuevo** y `git bundle verify` + checkout en clon limpio. **No repetir** validación de ZIP antiguos. Respuesta de Codex: `TASK_ID | G2=... | G3=... | G4=... | G5=... | HEAD=... | TREE=... | RELEASE=NO_GO | NEXT=CHATGPT_DIRECTOR` + ruta local del único ZIP + SHA256. Codex nunca afirma que `D:\...` sea enlace descargable en ChatGPT; el usuario adjunta físicamente el ZIP.

## 6. Criterios de salida y proyecto hasta lanzamiento

- **Meta de este bloque:** certificar transporte real de bytes schema2 Laravel→Dart QA, desbloquear o clasificar de una sola vez seguridad GitHub y Android, conservar bundle. Si G2 pasa y G3/G4 siguen ambientales, entregar resultados sin otro diagnóstico inútil; el director definirá acceso a host apto/scanner o la siguiente integración productiva según evidencia.
- **Fuera de este bloque y sin replanificar ahora:** importación nacional **editorial** de autoridades/modos con pruebas de ámbitos/excepciones/festivos; snapshot **completo de todas las autoridades aprobadas**, versión/revisión, revisión humana, publicación controlada en staging real y rollback; Android APK físico/firma compatible; UX de estados, permisos, cámaras, privacidad; autorización humana del release. La app NO se declara terminada por 115 reglas LAB ni por test puente schema2.
- **L1–L6:** KISS/Ponytail (reusar), antirruido (cero tests clonados), antiparches (fallos reales), UX aprobada, evidencia independiente (PASS solo con exit/bytes) y antipingpong (un bloque sin relanzamientos).

## Anexo A — control de calidad del director: DIEZ pasadas VERDUGO y DIEZ JUEZ

**Este anexo documenta decisiones YA TOMADAS. Codex NO debe volver a ejecutarlo ni presentar otra auditoría general.** Se revisaron el prompt V6 anterior, el repositorio restaurado de V5, el ZIP y los contratos fuente; no se simularon nuevas ejecuciones de PHP/Flutter.

| Pase verdugo | Hallazgo concreto | Corrección obligatoria |
|---|---|---|
| V01 | V6 pedía un “nuevo puente” sin rastrear E2E existente | Reusar G2 existente y limitar a 1 método PHP + 1 caso Dart |
| V02 | G1 es schema1, insuficiente para objetivo schema2 | Prioridad al puente `restriction_g2_same_bytes_test.dart` |
| V03 | Repetir PHP 33/279 ocasiona ruido | Validar SHA de outputs G2 V5; PHP focal solo si faltan |
| V04 | Test Dart G2 tiene tres casos y dos fixtures adicionales | Usar filtro por nombre exacto del caso schema2 G2 |
| V05 | G4 `dir` en clon podría absorber `.git`/WIP | Exportar el HEAD en temp y escanear árboles exactos |
| V06 | Historial escaneado antes de un posible delta no basta | Escanear nuevo delta y HEAD final antes de push |
| V07 | “rollback” backend y last-good cliente se confundían | Distinguir publicación revisionada de conservación de cliente |
| V08 | G3 repetía mediciones aun con host estable | Bloqueo heredado hasta cambio real de recursos |
| V09 | Un `push` puede activar workflows y costes | Verificar triggers `push` de la rama antes de publicarla |
| V10 | PASS puente sintético podía confundirse con staging real | Etiqueta expresa PASS_QA_BYTES, no release/servidor desplegado |

| Pase juez | Contraprueba/decisión razonada | Criterio de aceptación |
|---|---|---|
| J01 | No hace falta desarrollar otro motor: schema2 existe | Sin nueva API/schema/clase por ciudad |
| J02 | El puente PHP real ya produce bytes verificables | SHA/bytes/versión de output idénticos |
| J03 | Drift+HTTP loopback prueban importador, no CDN real | PASS acotado y riesgo residual declarado |
| J04 | R2 real fue validado en F2; no inventar entrada | Conservar SHA original de R2 |
| J05 | El caso Dart por nombre reduce 2 dependencias ajenas | 1 caso seleccionado, exit0 real |
| J06 | Gitleaks original 8.30.0 y SHA comprobado públicamente | Checksum exacto antes de uso, 0 hallazgos |
| J07 | Historial PR71 tiene revisión previa; delta 12 commits | Escaneo BASE..HEAD + árbol HEAD, no 313 commits por ritual |
| J08 | Documental PR79 y rama LAB tienen destinos distintos | No decir que código está en GitHub sin ref remoto SHA |
| J09 | Sin capacidad de memoria, Gradle es un riesgo evitable | No build en host inalterado; host apto antes de APK |
| J10 | El cierre técnico debe avanzar sin falsos verdes legales | No release sin admin/staging real, QA física y fuentes aprobadas |

**NEXT_ACTOR AHORA = CODEX LUNA SOLO SI V6 ORIGINAL NO ESTÁ EN EJECUCIÓN. DESPUÉS DEL ÚNICO ZIP = CHATGPT DIRECTOR. PRODUCT_RELEASE=NO_GO.**
