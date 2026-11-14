# CODEX LUNA — PicoRadar V6R4 V5 · CIERRE ÚNICO F2 + RESPALDO GITHUB LAB + GATE ANDROID

**TASK_ID:** `PICORADAR-V6R4-V5-F2-GITHUB-ANDROID-ONEPASS-20261114`  
**QUIÉN TRABAJA:** CODEX LUNA ejecuta exclusivamente este lote cuando ningún otro agente esté escribiendo PicoRadar. ChatGPT es el director y revisor final.  
**ESTADO:** `PRODUCT_RELEASE=NO_GO`. **Este V5 reemplaza al prompt residual POST-V4 del 14-nov SOLO SI NO SE HA INICIADO.** Si ya se inició, no interrumpir ni crear otro escritor: entregar su ZIP y volver a ChatGPT Director.  
**Repositorio:** `sierraglobalcompany-rgb/PicoRadar`; host Windows 11, rutas `D:\codex\`; herramientas gratuitas. GitHub PR #79 es documentación Draft y PR #71 es recuperación Draft. No confundirlos con `main` ni con la rama LAB.  
**Entrada:** el ZIP físico `PICORADAR_V6R4_V4_EVIDENCIA_UNICA.zip`, SHA-256 `6d24f095df4521210f28197e2452398056781d4e9db36b088d258664a89d37b2`, y el candidato local Git. Antes de escribir, verificar ruta real en el informe de V4; no asumir que una ruta D: existe únicamente porque está documentada.

## 0. Objetivo claro y límites — no repetir trabajo

**Entregar en UNA ejecución:** (a) Laravel QA real con **33/33 pruebas focales si aparece el fixture R2 genuino**, o **30/30 independientes con 3 dependientes BLOQUEADAS** si no aparece; (b) una evaluación binaria, reproducible y segura de `push` a **rama LAB no productiva** del commit V4 o de un único fix causal; (c) APK debug **solo** si cambió el host y los márgenes de memoria cumplen las reglas ya aprobadas; (d) **un ZIP único** restaurable, sin adjuntos dispersos. No buscar una cifra `PASS` a costa de alterar fixtures, evidencia legal, aserciones o reglas del producto.

**CONSERVAR y no ejecutar de nuevo:**

- F0 custodia `PASS`; último commit local **`15948a50332589ff3d1fb3157b6976809fe5a680`**; tree **`8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`**; padre **`09b4f0a35fa6eae2192c88c83d2afe10133aabfe`**. Bundle V4 extraído/restaurado en auditoría anterior. No reconstruir V6R4, no relanzar V2/V3/V4.
- F1 **PASS** con Flutter 3.47.9: OTA/Drift 2/2, widget real 1/1, análisis focal exit 0. No rerun, no `pub get` por ritual, no formateo de todo el proyecto.
- Datos LAB **14 autoridades, 33 códigos, 21 coberturas parciales, 115 reglas**; Python 14/14 y PHP schema2 ya reportados PASS. No reensamblar, buscar 50 fuentes IA2, investigar 1.104 municipios ni modificar motor/dataset.
- F2 MariaDB 10.4.32 QA ya había demostrado `--explicit-defaults-for-timestamp=ON` y resuelto `ends_at` SQLSTATE 1067. Sentinel anterior `RestrictionPublicationServiceTest`: **6 pruebas/25 assertions PASS**; no repetirlo sin un cambio que lo afecte.
- F3 en host V4: `pagefile_free=3.37 GiB`, RAM libre 9.51 GiB, commit libre 6.18 GiB frente a Gradle `-Xmx8G`, Metaspace 4G; sin APK. No cambiar parámetros de memoria/Gradle/firma para forzar build.
- F4: commit V4 NO publicado en GitHub (consulta remota dio 422); rama LAB no vista. Antepasado PR71 **`0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`**; `git rev-list BASE..HEAD` debe dar **12** commits con el HEAD sin nuevos fixes. La inspección heurística anterior NO fue auditoría integral de secretos.

**Meta permanente del producto:** un único motor nacional tipado `schemaVersion=2`, calendario y modalidades habilitables mediante datos por autoridad/ciudad/departamento/municipio/centro poblado **solo si su competencia y ámbito están acreditados**, y OTA con snapshot completo aprobado, versión/revisión/SHA/rollback, sin APK por ciudad. Un comunicado oficial de alcaldía, gobernación o autoridad de tránsito basta para **los campos que realmente demuestra**, aunque falte PDF de decreto. No inventar festivos, perímetros, exenciones ni circulación permitida; usar `UNKNOWN/STALE`. Los seis HOLD jurídicos históricos y festivos de Dosquebradas no se levantan aquí. **No publicar las 115 reglas LAB como cobertura nacional completa.**

## 1. Preflight único: protección de WIP y selección de la copia correcta

1. Si otro Codex/agente está activo en el mismo checkout, **no abrir segundo escritor**. Si el local contiene un HEAD posterior o cambios ajenos, **no hacer checkout ni aplicar bundle sobre él**: registrar `NEWER_WORK_DETECTED`, conservar y terminar esta orden sin sobrescribir.
2. En candidato ya existente, verificar `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git status --porcelain`, `git branch --show-current`. Exigir HEAD/tree citados, limpio y sin divergencia. Si falta candidato, comprobar SHA del ZIP V4, extraer **solo** `GIT/full-final.bundle` en staging y crear clon **nuevo y no colisionante** dentro de `D:\codex\_isolated\`. Seleccionar commit/branch explícitos, comprobar `git bundle verify`; un bundle no es un remoto para `push`. No `reset --hard`, `clean`, `stash`, `force`, ni borrados de WIP.
3. El cambio de este macrobloque **debe ser cero archivos de producto** si los errores son solo entorno/fixtures. Proteger `server/phpunit.xml`, `server/phpunit.mariadb.xml`, `.env*`, migraciones, `pubspec.lock`, `composer.lock`, `gradle.properties`, Garaje, motor, datos y snapshots aprobados. Crear un commit nuevo **únicamente** por fallo de producto genuino con RED y GREEN focal, sin alterar aserciones para obtener verde.

## 2. F2 · Laravel QA: reparar causa ambiental, máximo 33 casos en un único bloque

### 2.1 Qué pruebas hay en realidad (verificado leyendo seis clases PHP del commit V4)

| Fuente real en `server/tests/Feature/` | Casos | Sin R2 histórico |
|---|---:|---|
| `DatasetReleaseValidationTest.php` | 6 | Ejecutar 6 |
| `DatasetPublisherTest.php` | 9 | Ejecutar 9 |
| `RestrictionImportServiceTest.php` | 4 | Ejecutar 4 |
| `DatasetAuthorizationTest.php` | 6 | Ejecutar 6 |
| `RestrictionNationalLabPublicationTest.php` | 1 | **Bloquear 1** (R2 en `setUp`) |
| `RestrictionSchemaV2LabRoundTripTest.php` | 7 | **Ejecutar 5**, bloquear 2 con R2 |
| **TOTAL** | **33** | **30 ejecutables, 3 bloqueados** |

**Corrección crítica del prompt anterior:** decía ejecutar solo **un** método de `RestrictionSchemaV2LabRoundTripTest` sin R2; son **cinco** métodos realmente independientes. No dejar cuatro métodos pendientes por error del prompt. Para evitar falsos verdes por filtros que no coincidan, antes de ejecutar llamar `php vendor/bin/phpunit -c <XML_QA> --list-tests` con el **mismo filtro** y verificar el recuento **33** si R2 existe, o **25 + 5** si falta. `--list-tests` NO ejecuta los tests. Si descubre un número distinto, parar SOLO F2 y registrar diferencia exacta; no ampliar arbitrariamente el filtro.

**Los cinco métodos G2 independientes sin R2**, nombres literales:

- `test_schema2_import_confirm_validate_publish_emits_matching_release_and_manifest_bytes`
- `test_schema1_dataset_rejects_schema2_city_and_schema1_envelope_rejects_schema2_city`
- `test_material_rule_removal_requires_editorial_review_and_keeps_the_active_release`
- `test_complete_coverage_cannot_enter_a_release_without_editorial_evidence`
- `test_expanding_rule_validity_without_a_new_source_requires_review`

### 2.2 Configurar una vez, sin filtrar datos reales

1. **Una sola búsqueda delimitada de R2** en ubicaciones conocidas `D:\codex\_REPORTES\PicoRadar\` y ZIP/reportes R2/G2 ya registrados (primero índice/nombres, extracción selectiva). Nombre **`ACTUAL_R2_LARAVEL_RELEASE.json`** y SHA-256 **`c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`**; validar además `schemaVersion=1`, 7 jurisdicciones y 12 coberturas. Si no existe, `R2_FIXTURE=NOT_FOUND`, **no fabricar JSON ni detener las 30 pruebas independientes**.
2. Exportar en **proceso QA** `APP_KEY` sintética, aleatoria 32 bytes, codificada `base64:...`, sin imprimir su valor ni copiar `.env` de producción. Puede usarse `RandomNumberGenerator` de PowerShell/.NET en memoria; registrar solamente `APP_KEY_QA_PRESENT=TRUE` y `APP_KEY_ORIGIN=SYNTHETIC`. Nunca `php artisan key:generate` sobre `.env` real.
3. Proveer exactamente estas **cinco** variables (no tres): `PICORADAR_R2_EVIDENCE_DIR` (directorio **de entrada** R2 verificado), `PICORADAR_G1_EVIDENCE_DIR` (carpeta nueva vacía de salida QA), `PICORADAR_G2_EVIDENCE_DIR` (salida), `PICORADAR_G2_R2_RELEASE` (ruta al **archivo** R2 verificado), `PICORADAR_G2_V3_EVIDENCE_DIR` (salida). **Si R2 no existe:** NO establecer valores ficticios en las dos variables de R2; crear solo las tres carpetas de salida necesarias para tests independientes.
4. MariaDB QA **solo** con binario/receta que funcionó en V4: proceso **efímero**, datadir nuevo exclusivamente QA, `127.0.0.1`, puerto libre alto distinto si hace falta, esquema nuevo vacío con nombre inequívoco `picoradar_v6r4_qa_*`, usuario/contraseña sintéticos, `--explicit-defaults-for-timestamp=ON`, SQL estricto, sin servicios Windows ni bases reales. **Antes de cualquier `RefreshDatabase`:** verificar por TCP y con el MISMO usuario/host/puerto/db que verá PHPUnit: PID y socket de proceso QA, `SELECT DATABASE(), @@port, @@hostname, @@global.explicit_defaults_for_timestamp`, nombre/schema esperado, `information_schema.tables` = 0. Si no puede demostrarse identidad, `F2_BLOCKED_DB_SAFETY`; nunca migrar, nunca conectar a Hostinger ni DB productiva.
5. Crear `phpunit.v6r4.qa-temp.xml` **solo dentro del clon QA aislado en `server/`** a partir de `server/phpunit.mariadb.xml` (el XML original define `127.0.0.1:3306`, no el QA nuevo). Cambiar SOLO valores sintéticos de `DB_HOST/PORT/DATABASE/USERNAME/PASSWORD`, añadir `DB_URL` vacío, `APP_ENV=testing`, caché/sesión/correo/colas sin efectos externos; asegurar que el proceso PHPUnit hereda `APP_KEY` sin revelarla. NO tocar los XML rastreados, ni `.env`, ni config de producción. **Verificar además que Laravel realmente resuelve `database.default=mysql` y `config('database.connections.mysql.host/port/database')` contra el mismo QA**; comprobar que no haya `bootstrap/cache/config.php` apuntando a otra DB (si hay, desactivar SOLO en clon QA, con respaldo, nunca en árbol del usuario). Si hay divergencia, `F2_BLOCKED_CONFIG_SAFETY`.
6. Ejecutar en `server/` con `php vendor/bin/phpunit --configuration phpunit.v6r4.qa-temp.xml --no-coverage --colors=never`. Registrar literalmente comando, versión PHP/PHPUnit/MariaDB, hash de test, fixture y XML **sanitizado**, stdout/stderr **redactados**, código `$LASTEXITCODE` **inmediatamente** después de cada invocación, número real de pruebas y fallos. Un comando con `0 tests` **NUNCA** da PASS. No repetir el sentinel ni los tests F1/Python.

### 2.3 Ramas de ejecución cerradas, sin que Codex tenga que improvisar

**Si R2 existe y pasó el SHA:** usar `--testsuite Feature --filter '/DatasetReleaseValidationTest|DatasetPublisherTest|RestrictionImportServiceTest|DatasetAuthorizationTest|RestrictionNationalLabPublicationTest|RestrictionSchemaV2LabRoundTripTest/'` con el XML QA; comprobar `--list-tests` = **33** antes del **único** run de las 33. Estado `F2_FULL_PASS_SCOPED_QA` **solo** si exit 0 y 33 ejecutadas (y ningún error/skip material).

**Si R2 falta:** usar **dos** comandos de tests, con el mismo XML/DB QA:

- A. `--testsuite Feature --filter '/DatasetReleaseValidationTest|DatasetPublisherTest|RestrictionImportServiceTest|DatasetAuthorizationTest/'` ⇒ **25 tests**.
- B. Archivo **`tests/Feature/RestrictionSchemaV2LabRoundTripTest.php`** más `--filter '/test_schema2_import_confirm_validate_publish_emits_matching_release_and_manifest_bytes|test_schema1_dataset_rejects_schema2_city_and_schema1_envelope_rejects_schema2_city|test_material_rule_removal_requires_editorial_review_and_keeps_the_active_release|test_complete_coverage_cannot_enter_a_release_without_editorial_evidence|test_expanding_rule_validity_without_a_new_source_requires_review/'` ⇒ **5 tests**.

Verificar 25 y 5 por `--list-tests` antes; ejecutar cada selección **UNA sola vez**. Estado `F2_CORE_PASS_30_R2_DEPENDENT_3_BLOCKED` si exit 0 de ambos y 30 realmente ejecutados. Las 3 pruebas dependientes permanecen **BLOCKED_MISSING_AUTHENTIC_R2**, no `FAIL_PRODUCT` ni `PASS`. Si hay fallo genuino posterior a entorno confirmado: **un caso RED → corrección mínima causal → un caso GREEN**, sin repetir las clases sanas ni iniciar otra auditoría. No cambiar expectativas, fixtures, schema2 o fechas para conseguir PASS.

**Siempre:** detener únicamente el proceso MariaDB QA que se levantó, demostrar PID y puerto cerrados. Eliminar o aislar XML temporal y credenciales sintéticas dentro del clon efímero sin modificar WIP protegido. Nunca empaquetar bases, `APP_KEY`, contraseñas, dumps, `.env`, archivos privados ni JSON de usuarios. Conservar en staging QA resultados de fuentes **sintéticas** cuando sirvan para verificar publicación, registrando sus hashes; el ZIP contiene solo evidencias seguras y hashes.

## 3. F4 · Github: respaldo del CÓDIGO en rama LAB si la historia es segura

1. En candidato limpio validar con Git la referencia local de **PR71 HEAD** `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`; `git merge-base --is-ancestor BASE HEAD` exit 0 y `git rev-list --count BASE..HEAD` = 12 **si sigue mismo HEAD**. Si se creó un fix genuino, contar nuevo rango y documentar. Comparar SHA del PR71 en el remoto y confirmar `origin` = `https://github.com/sierraglobalcompany-rgb/PicoRadar` o URL SSH de ese mismo repositorio, **nunca un bundle**. Si base cambió, no asumir sincronización: detener solo F4.
2. Inspeccionar **los 12 commits completos, también commits intermedios**, no únicamente diff final: `git log --name-status BASE..HEAD`, `git diff --name-status BASE..HEAD`, `git log -p BASE..HEAD` y listado de archivos de cada árbol/commit. Rechazar `.env`, claves privadas, secretos, tokens, credenciales, archivos personales, dumps, databases, ZIP, evidencias privadas, PII o rutas de escape al repo. Una ausencia de resultados de `rg` no basta para aprobar seguridad.
3. Primera elección: `gitleaks` gratis si ya está instalado o disponible como binario confiable existente (PR71 documentó Gitleaks 8.30.1). Comando de referencia conforme a su CLI: `gitleaks git --log-opts="BASE..HEAD" .` desde clon aislado, versión, exit y hallazgos **redactados**; revisar además estado final/directorio ante secretos en paths que no aparezcan en parches. Si hay hallazgo, distinguir falso positivo **con fundamento y sin incluir secretos**. Si Gitleaks NO está disponible, ejecutar inspección estática local minuciosa de los 12 commits pero mantener `F4_HOLD_SECURITY_SCANNER_UNAVAILABLE` **sin push**; no instalar ni descargar binarios desconocidos para fabricar PASS.
4. Solo con scanner PASS + revisión de cambios/paths PASS + remoto autenticado y escritura permitida + ausencia de trabajo concurrente + HEAD exacto, hacer **un único** `git push origin HEAD:refs/heads/feat/picoradar-v6r4-lab-candidate` **SIN `--force`**. Si esa rama remota existe, no sobrescribir: comparar SHA y registrar estado; si GitHub 403/suspensión/autorización falla, **UN intento máximo**, marcar `F4_HOLD_REMOTE` y usar bundle. Verificar `git ls-remote --heads` y SHA publicado = HEAD antes de declarar `F4_LAB_SYNCED`.
5. NO crear PR listo, merge, force-push, deploy, CI paga, tag de release, manifest CDN ni actualización Hostinger. Rama LAB **es custodia de código sin certificación de producto**. F2 parcial por falta de R2 no prohíbe respaldar LAB si seguridad PASS; NO autoriza publicar dataset a consumidores.

## 4. F3 · Android: sin Gradle si el host sigue sin memoria

- Si el equipo sigue con el mismo perfil de V4, usar **el preflight de recursos V4 ya registrado**: `pagefile_free=3.37 GiB`, sin ejecutar Gradle de nuevo; estado `F3_BLOCKED_HOST_RESOURCE_STABLE`. No cambiar los umbrales anteriores, `gradle.properties`, pagefile, JVM, SDK, firma o Windows para simular éxito.
- Si hay **un host nuevo o incremento medible real de memoria/commit/pagefile**, comprobar una sola vez RAM disponible, commit libre, pagefile libre, límites JVM (`-Xmx8G`, metaspace 4G, codecache) y el gate histórico mínimo de **6 GiB libres** donde aplica, además de holgura real para esa JVM. Solo cuando todo es compatible, **una** compilación debug con tooling gratuito ya disponible en entorno aislado, sin tocar teléfono. Registrar comando/exit, APK bytes/hash y que **no es release aprobado**. Si falla por recurso nuevo, clasificarlo y no repetir variantes de Gradle.
- QA física y firma compatible del Xiaomi Mi A3, OTA real/staging, preservación de Garaje/retroceso y autorización de producto son posteriores; no fingir `ANDROID_PASS` por tener test Flutter en PC.

## 5. Entrega · UN ZIP obligatorio y plan de salida, sin próximo pingpong

**Ruta única** `D:\codex\_REPORTES\PicoRadar\V6R4-V5-20261114\delivery\PICORADAR_V6R4_V5_EVIDENCIA_UNICA.zip` (si existe, generar ruta alternativa sin borrar ni sobrescribir). **No adjuntar más archivos al usuario.**

Contenido mínimo y suficiente (evitar repetir los 82 MB de evidencias dentro del ZIP; **sí** incluir un bundle Git nuevo, autocontenido):

- `FINAL_REPORT.md`: tabla F0/F1 heredados, F2 (33 o 30+3 con causa exacta), F3, F4, F5; evidencia por gate, cierres reales, 1 siguiente bloqueo prioritario, versiones, fecha UTC/Colombia, HEAD/TREE/PARENT, release NO_GO y `NEXT_ACTOR=CHATGPT_DIRECTOR`.
- `GATES.csv`: cada selección `--list-tests` con recuento, cada ejecución con exit, nº de tests/assertions/failures, SHA de código y fixtures, fuente de evidencia R2 si se encontró. Un test omitido no pasa. Dos análisis `PASS` previos se heredan con enlace al ZIP V4 y SHA, no se regeneran.
- `LOGS/`: STDOUT/ERR QA **redactados** F2, verificación de conexión real, parada de MariaDB, scanner Git y remoto, preflight Android solo si hubo cambio de host. Nunca claves ni credenciales.
- `GIT/full-final.bundle` con HEAD **final**, `GIT/HEAD.txt`, `GIT/RESTORE.md` (bundle verificado y checkout restaurado en clon nuevo), lista de cambios PRODUCTO `0` si solo entorno; si hubo fix causal, ruta y test GREEN. Resumen SHA/branch LAB; ninguna `.git` suelta.
- `MANIFEST_SHA256.csv` con nombre, bytes, CRC32 y SHA-256 de **todos excepto el propio manifiesto**; validar CRC de ZIP, extracción completa y hashes. Registrar bytes y SHA del **ZIP final**. No mezclar ZIP históricos dentro.

**Criterios de finalización del lote:** F2 `FULL_PASS_33` **o** `CORE_PASS_30_R2_BLOCK_3`; F4 `LAB_SYNCED` **o** hold verificable de seguridad/remoto; F3 `APK_DEBUG_BUILT` solo si recursos o `BLOCKED_HOST_RESOURCE`; F5 `ZIP_VERIFY_PASS`. **No declarar PicoRadar terminado: producto sigue `NO_GO`.** Si F2 falla por entorno distinto a R2, informarlo exactamente sin microencargos posteriores. El director decidirá en un solo paso qué queda para staging completo y Android.

**Próxima ruta a lanzamiento ya fijada (NO ejecutar sin autorización/entorno):** validar y publicar en QA/staging **snapshot completo de todas las coberturas aprobadas** (no solo 14 LAB), control editorial, rollback/manifest/versionado; QA Android física preservando usuario/firma y última versión OTA; autorización de despliegue. La expansión nacional continua se hace con fuentes oficiales + JSON/manifiesto + aprobación, sin alterar motor ni APK por ciudad. No publicar falsos permisos `ALLOWED` por información incompleta.

**Respuesta FINAL de Codex (breve):** `TASK_ID | F2=<estado y n.º casos> | F3=<estado> | F4=<estado> | F5=<estado> | HEAD=<SHA> | TREE=<SHA> | ZIP_SHA256=<hash> | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR` y **UN enlace al ZIP único**.

## ANEXO · Auditoría del director: 10 VERDUGO + 10 JUEZ (solo delta de este prompt)

**Alcance real:** comparación del prompt POST-V4 original con los **seis archivos PHP del commit restaurado V4**, XML PHPUnit, logs y reporte del ZIP V4; GitHub PR79/PR71 por conector. Revisión adversarial **interna**, no ejecución de PHPUnit ni auditoría de seguridad certificada del director.

| Nº | Verdugo: comprobación adversarial | Error/riesgo evitado |
|---|---|---|
| V01 | Recontar seis clases, métodos por archivo | 33 total, NO solo 26 sin R2; 30 independientes |
| V02 | Leer G1 `setUp()` y G2 métodos | Tres casos R2 exactamente; no bloquear más |
| V03 | Ver CLI PHPUnit 12.5 y filtros | `--list-tests` antes del run evita 0 tests falsos PASS |
| V04 | Contrastar phpunit.xml y phpunit.mariadb.xml | SQLite/puerto 3306 no deben desviar QA |
| V05 | Revisar APP_KEY y cinco variables | No usar secretos reales ni inventar R2 |
| V06 | Verificar configuración Laravel efectiva | XML correcto no prueba DB real; bloquear migración equivocada |
| V07 | Auditar F0/F1 del ZIP V4 | Ninguna repetición de tests Flutter/Python/commit |
| V08 | Revisar PR79/PR71 y commit V4 remoto | GitHub docs ≠ rama de código; remoto V4 ausente |
| V09 | Considerar escaneo de commits intermedios | Revisar 12 commits, no solo snapshot final |
| V10 | Revisar memoria Gradle V4 | No quemar build inseguro en host idéntico |

| Nº | Juez: alternativa evaluada | Decisión sustentada |
|---|---|---|
| J01 | Rehacer F0 o restaurar encima de WIP | Rechazar; bundle válido, usar clon aislado solo si falta candidato |
| J02 | Ejecutar solo un test G2 sin R2 | Rechazar; cinco independientes disponibles |
| J03 | Declarar F2 FULL PASS con 30 tests | Rechazar; 3 dependientes R2 siguen BLOQUEADAS |
| J04 | Inventar fixture R2 desde snapshot V6R4 | Rechazar; exige bytes y SHA exactos |
| J05 | Cambiar migración `ends_at` | Rechazar; causa ya cerrada con MariaDB QA |
| J06 | Emplear APP_KEY o DB de producción | Rechazar; sintético/efímero y verificación de destino |
| J07 | Lanzar seis clases con rutas ambiguas | Sustituir por selección PHPUnit explícita con recuento |
| J08 | Publicar rama sin scanner ni historia revisada | Rechazar; hold y bundle si seguridad incierta |
| J09 | Reintentar Gradle con 3,37 GiB pagefile libre | Rechazar; no tocar umbral ni firma |
| J10 | Posponer indefinidamente V1 por 1.104 municipios | Rechazar; app release exige gates funcionales y cobertura honesta, expansión data-only continua |

**GOBIERNO:** Seis leyes L1 KISS/Ponytail, L2 antirruido, L3 antiparches, L4 UX fiel, L5 verificaciones trazables, L6 antipingpong. La ruta mínima completa ya está decidida. **QUIÉN SIGUE: CODEX LUNA si no hay otra ejecución activa; tras el ZIP único, CHATGPT DIRECTOR.**
