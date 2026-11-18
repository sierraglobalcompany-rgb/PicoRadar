# CODEX LUNA — PICO RADAR V6R4 — CIERRE RESIDUAL F2 + SEGURIDAD GITHUB + GATE ANDROID (UN SOLO MACROBLOQUE)

**TASK_ID:** `PICORADAR-V6R4-POST-V4-F2-GITHUB-ANDROID-ONEPASS-20261114`  
**Prioridad:** ejecutar de una sola vez lo que quedó PENDIENTE de V4; NO reabrir F0/F1 ni V5/V6R3.  
**Director técnico:** ChatGPT. **Codex:** ejecutor de pasos definidos.  
**Estado entrada:** `PRODUCT_RELEASE=NO_GO`, `NEXT_ACTOR=CODEX_LUNA_IF_IDLE`.  
**Repositorio:** `sierraglobalcompany-rgb/PicoRadar`. **Plataforma:** Windows 11; rutas reales bajo `D:\codex\`. **Solo herramientas gratuitas, sin CI pagada.**

## A. RESULTADO ESPERADO, UNA SOLA ENTREGA

1. **Certificar el máximo posible de Laravel F2** con los cinco env vars reales y `APP_KEY` sintética, en MariaDB QA efímera, sin tocar producción. Si falta el R2 histórico exacto, ejecutar y certificar todos los casos independientes; el resto queda `BLOCKED_MISSING_R2_FIXTURE` (no `FAIL_PRODUCT`).
2. **Revisar únicamente los 12 commits locales aún no publicados**, verificar cadena remota y seguridad, y hacer **un solo push** a una rama LAB no productiva si TODOS los controles se satisfacen. Si no, HOLD justificado y bundle restaurable; no tocar `main` ni PR #71 ni PR #79.
3. **Intentar build Android debug SOLO si se satisfacen los umbrales de recursos existentes**. Si sigue bloqueado, NO ejecutar Gradle ni modificar umbrales, pagefile, configuración de memoria o firma. Avanzar F2/F4 independientemente.
4. Emitir **UN ÚNICO ZIP** de informe y evidencias de los cambios NUEVOS, con bundle completo de Git, logs útiles, checksum por miembro, CRC/extracción y estado final. No archivos dispersos para entregar al usuario.

### Contrato de entrada INMUTABLE (no volver a auditar)

- ZIP de entrada: `D:\codex\_REPORTES\PicoRadar\V6R4-V4-ONEPASS-20261113\delivery\PICORADAR_V6R4_V4_EVIDENCIA_UNICA.zip`; SHA-256 exacto `6d24f095df4521210f28197e2452398056781d4e9db36b088d258664a89d37b2`. Si el checkout local ya está correcto, basta verificar el ZIP y la huella; NO extraerlo sobre un árbol con WIP.
- HEAD válido `15948a50332589ff3d1fb3157b6976809fe5a680`, TREE `8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`, PARENT `09b4f0a35fa6eae2192c88c83d2afe10133aabfe`. Rama local `feat/picoradar-v6r4-lab-candidate`. Bundle del ZIP `dad16fccb97493add593bbacbd13edfb1db60219f14b445fd5e22141356639a1` restaura HEAD/tree en clon limpio. El clon de bundle NO tiene remote GitHub por defecto: si `origin` apunta al bundle, no intentar push allí.
- **F0 CERRADO**: 8 rutas V6R4 comprometidas en V2 y commit focal V4, no repetir custodia. **F1 CERRADO**: Flutter 3.47.9, test OTA/Drift **2/2 PASS**, widget **1/1 PASS**, ambos analizadores PASS, SHA/last-good y Garaje; **NO repetir ni formatear 642 líneas preexistentes**. Python 14/14 PASS y snapshots LAB 14 autoridades/33 DIVIPOLA/21 pares parciales/115 reglas, no reensamblar ni editar motor/dataset salvo fallo PRODUCTO NUEVO plenamente demostrado.
- **F2 V4:** MariaDB 10.4.32 `127.0.0.1:57206` con `--explicit-defaults-for-timestamp=ON` y SQL estricto eliminó el anterior SQL 1067. Sentinel `RestrictionPublicationServiceTest` 6 tests/25 assertions PASS (exit 0). Seis clases: 33 tests/113 assertions, exit 2, 7 `MissingAppKeyException` y 4 fallos de entorno por R2/G2 ausentes. **No volver a probar un sentinel ya PASS con configuración idéntica.** Base QA anterior apagada y puerto cerrado.
- **F3 V4:** pagefile libre 3,37 GiB, commit libre 6,18 GiB, RAM 9,51 GiB; `mobile/android/gradle.properties` configura `-Xmx8G`, MaxMetaspaceSize 4G. Sin Gradle/APK/Mi A3. **No cambiar umbral de 6 GiB de pagefile/commit adoptado antes ni forzar JVM.**
- **F4 GitHub:** PR #79 Draft (docs) y PR #71 Draft (recuperación), código HEAD V4 NO en remoto. Ancestro remoto de V4: PR71 HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`; exactamente **12 commits** en `0d3a6a2..15948a5` y **126 rutas** distintas. El control heurístico del director sobre líneas agregadas no encontró patrones de secretos típicos, PERO NO constituye scanner completo; por eso F4 sigue HOLD hasta controles adecuados. **No reescanear 313 commits innecesariamente**; la historia previa a PR71 es pública en PR71.

## B. GATE 0 — UN ESCRITOR / PROTECCIÓN

1. Confirmar que ningún Codex esté trabajando en este PicoRadar. Si existe otra ejecución, **NO iniciar segundo escritor**; entregar al director el conflicto y nada más. No reiniciar Codex por rutina.
2. Identificar el candidato local ya existente leyendo estado bajo `D:\codex\_isolated\` y rutas del último informe. Comprobar `git rev-parse HEAD`, `git show -s --format=%T HEAD`, `git status --porcelain`. Usar candidato existente solo si HEAD y tree exactos y checkout limpio. Si falta, restaurar el **bundle verificado** del ZIP en **NUEVO clon** `D:\codex\_isolated\PicoRadar-V6R4-POSTV4-F2-20261114` (nombre no puede colisionar con carpeta existente) y seleccionar explícitamente `feat/picoradar-v6r4-lab-candidate`. **Nunca** `reset --hard`, `clean`, `stash`, overwrite de WIP ni checkout forzado.
3. Si aparece un HEAD posterior a V4, no sobrescribir ni ejecutar esta orden ciegamente; registrar `NEWER_WORK_DETECTED` y conservarlo. Si todo coincide, no crear commit nuevo salvo que un fallo PRODUCTO reproducible exija una corrección mínima (improbable).
4. Los archivos `server/phpunit.xml`, `server/phpunit.mariadb.xml`, `server/.env*`, `mobile/android/gradle.properties`, `pubspec.lock`, `composer.lock`, motor Flutter, datasets y Garaje quedan **protegidos**. No refactor, schema3, nuevo motor, APK por ciudad ni dependencias de pago.

## C. F2 — CIERRE CAUSAL Y MÁXIMO QA ADMIN REAL

### C1. Preparar APP_KEY SINTÉTICA y cinco variables CORRECTAS

La causa del fallo V4 NO es el motor. Las dos pruebas más importantes ahora son autorización (7 errores APP_KEY) y publicación/round-trip (4 casos con referencias de evidencia). Leer solo la fuente de esas clases y **no lanzar tests hasta verificar la configuración**:

| Variable | Papel concreto | Fuente permitida |
|---|---|---|
| `APP_KEY` | cifrado/HTTP Laravel durante tests | generar en memoria una clave **aleatoria de 32 bytes** tipo `base64:...`, exclusiva de esta ejecución, **nunca copiar de `.env` real**, nunca registrar ni empaquetar |
| `PICORADAR_R2_EVIDENCE_DIR` | directorio con `ACTUAL_R2_LARAVEL_RELEASE.json` | evidencia R2 **real**, SHA `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5` |
| `PICORADAR_G1_EVIDENCE_DIR` | salida QA del caso nacional LAB | nuevo directorio vacío en staging privado de este run |
| `PICORADAR_G2_EVIDENCE_DIR` | salida QA schema2 G2 | nuevo directorio vacío en staging privado |
| `PICORADAR_G2_R2_RELEASE` | **ruta de archivo**, no directorio | ruta exacta al mismo JSON R2 con SHA anterior |
| `PICORADAR_G2_V3_EVIDENCE_DIR` | salida QA de round-trip mixto | nuevo directorio vacío en staging privado |

**MUY IMPORTANTE:** hay **cinco `PICORADAR_…`** además de `APP_KEY`; no solo los tres que informó Codex. Confirmado en `server/tests/Feature/RestrictionNationalLabPublicationTest.php` y `RestrictionSchemaV2LabRoundTripTest.php` (líneas 57, 76, 131, 181, 189 y 249). Los tres directorios de salida (`G1`, `G2`, `G2_V3`) son artefactos NUEVOS de QA y no dependen de localizar originales. **El R2 es entrada auténtica insustituible**; se usa también en verificaciones de 7 jurisdicciones/12 coberturas.

Para APP_KEY, una receta PowerShell 5+ segura en **proceso actual**, sin imprimir bytes ni escribir secreto a disco:

```powershell
$keyBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($keyBytes)
$env:APP_KEY = 'base64:' + [Convert]::ToBase64String($keyBytes)
$rng.Dispose()
# Registrar solo APP_KEY_SYNTHETIC_PRESENT=TRUE; nunca su valor.
```

**R2 — búsqueda acotada UNA VEZ:** consultar índices/informes históricos R2/G2 disponibles bajo `D:\codex\_REPORTES\PicoRadar\` y ubicaciones PicoRadar conocidas del usuario; si hay ZIP histórico R2, inspeccionar nombres de entradas antes de extraer selectivamente. Limitar la búsqueda a rutas ya conocidas y a los archivos `ACTUAL_R2_LARAVEL_RELEASE.json`/ZIP R2 reales, sin escanear indiscriminadamente todo D:. Verificar SHA-256 y estructura (7 jurisdicciones/12 coberturas) **antes de exportar variables**. No usar snapshot V5/V6R3/V6R4, JSON similar ni reconstrucción manual para simular el SHA R2. Si no aparece en este recorrido, estado `BLOCKED_MISSING_R2_FIXTURE`; **no parar C2/C3 independientes** ni pedir al usuario de nuevo históricos en esta ejecución.

### C2. Base MariaDB QA efímera, identidad antes de migraciones

1. Reutilizar binario/versiones y receta ya validada en F2 V4 (no instalar nada). **Crear nuevo datadir QA exclusivo** bajo staging de este run, process loopback `127.0.0.1`, puerto alto libre elegido y documentado (no asumir 57206 libre), `--explicit-defaults-for-timestamp=ON`, SQL estricto; nunca servicio Windows ni DB existente. Registrar PID, versión, IP/puerto, nombre de base aleatoria con prefijo `picoradar_v6r4_qa_`, usuario sintético, `@@explicit_defaults_for_timestamp=1` y cero tablas iniciales. Si no se puede demostrar esa identidad mediante consulta al mismo endpoint TCP que usará PHPUnit, STOP **solo F2 = BLOCKED_DB_SAFETY**.
2. Crear XML PHPUnit **temporal no rastreado** a partir de `server/phpunit.mariadb.xml`, apuntando EXCLUSIVAMENTE a DB/puerto/usuario nuevos. Asegurar `DB_CONNECTION=mysql`, `DB_HOST=127.0.0.1`, `DB_PORT=<QA_PORT>`, `DB_DATABASE=<QA_DB>`, `DB_URL=` vacío; `APP_ENV=testing`, `CACHE_STORE=array`, `SESSION_DRIVER=array`, sin correo ni cola externos. `APP_KEY` debe estar disponible al proceso hijo de PHPUnit. No editar los XML rastreados y no filtrar secretos al ZIP. Exigir verificación previa del DESTINO de DB desde el cliente SQL con usuario sintético. **NO** correr `migrate:fresh` en ninguna DB que no sea demostrablemente efímera; las clases usan `RefreshDatabase`.
3. Si R2 legítimo disponible: preparar **las cinco variables**, tres dirs de salida privados, y ejecutar exactamente **una vez** el conjunto de seis clases por sus rutas, usando `php vendor/bin/phpunit --configuration <xml_QA> --no-coverage --colors=never` desde `server` con estos archivos:
   - `tests/Feature/DatasetReleaseValidationTest.php`
   - `tests/Feature/DatasetPublisherTest.php`
   - `tests/Feature/RestrictionImportServiceTest.php`
   - `tests/Feature/RestrictionNationalLabPublicationTest.php`
   - `tests/Feature/DatasetAuthorizationTest.php`
   - `tests/Feature/RestrictionSchemaV2LabRoundTripTest.php`
   Capturar stdout, stderr, exit global y por caso que falle, SHA de test/fixtures y versión de MariaDB, con secretos redactados. Si PASS (exit0), `F2_FULL_PASS_SCOPED_QA`.
4. Si **NO** hay R2 exacto: ejecutar **una sola vez** las cuatro clases independientes (`DatasetReleaseValidationTest`, `DatasetPublisherTest`, `RestrictionImportServiceTest`, `DatasetAuthorizationTest`) con APP_KEY sintética y DB QA validada; y **una vez** el caso `RestrictionSchemaV2LabRoundTripTest::test_schema2_import_confirm_validate_publish_emits_matching_release_and_manifest_bytes` filtrado por nombre exacto, con `PICORADAR_G2_EVIDENCE_DIR` preparado. **No ejecutar** `RestrictionNationalLabPublicationTest` (su `setUp` requiere R2) ni los dos casos schema2 que leen `PICORADAR_G2_R2_RELEASE` ni fingir 33/33. Estado `F2_CORE_PASS_R2_DEPENDENT_BLOCKED` si todos los independientes pasan; `F2_FAIL_REAL` solo ante error reproducible distinto de entorno/fixture.
5. Si surge un fallo realmente nuevo luego de cumplir entorno/fixtures, aplicar **UN RED** del caso, localizar causa en responsable correcto, una corrección mínima y **UN GREEN focal** con entorno igual; no modificar aserciones, mover error de capa ni instalar herramientas por rutina. Si una dependencia de evidencia resulta ausente, registrar hold y continuar F4. No repetir sentinel F2 de V4 ni 14 Python ni F1.
6. **SIEMPRE**: apagar MariaDB QA, comprobar PID terminado y puerto cerrado. Conservar los outputs G1/G2 en staging (sin datos privados) solo si ayudan a QA, y en ZIP incluir únicamente métricas/hashes y evidencia segura/sintética de validación, no credenciales ni base. El XML temporal, contraseña, APP_KEY, data dir de MariaDB y sesiones quedan FUERA del ZIP y Git. Si el entorno impide eliminar un archivo por política, dejarlo confinado y señalar ruta sin publicar secreto.

### C3. Criterio de publicación por datos (NO publicar todavía)

Reutilizar exclusivamente pruebas existentes que afirmen que `RestrictionImportService` → revisión/validación editorial → `DatasetPublisher` emite **snapshot completo** (preserva las jurisdicciones antes aprobadas), manifest con SHA/version/revision, rechaza manifest corrupto y no da `ALLOWED` ante falta de cobertura. No construir admin nuevo. Una publicación eventual requiere aprobación humana, pruebas end-to-end reales con consumidor Flutter y fuente legal acreditada. **Un LAB de 14 autoridades no es dataset nacional completo.** Mantener seis HOLD previos y festivos Dosquebradas desconocidos.

## D. F4 — SINCRONIZACIÓN DE CÓDIGO A GITHUB SIN EXPONER HISTORIA PRIVADA

1. Confirmar remotos: la rama local del candidato NO puede apuntar a un bundle como destino de push. El remoto GitHub exacto esperado es `sierraglobalcompany-rgb/PicoRadar`. No revelar credenciales, usar solo conexión GitHub configurada del usuario. Leer rama `recovery/20261019-modern` y SHA remoto esperado `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`; si remoto cambió, no asumir, validar ancestro/concurrencia; nunca force-push. `git merge-base --is-ancestor <SHA_PR71> HEAD` debe dar exit0; `git rev-list --count <SHA_PR71>..HEAD` = **12** antes de cualquier commit nuevo.
2. Auditar solamente esos 12 commits, `git diff --name-status <SHA_PR71>..HEAD`, archivos nuevos y valores sospechosos (tokens/API keys/llaves privadas/.env reales, contraseñas, datos de usuarios, PII, datos productivos, ZIP o dumps). Usar herramienta gratuita y disponible de detección de secretos para el rango **si está instalada**, registrar versión/alcance/exit; no instalar dependencias globales ni depender de GitHub Actions. El escaneo heurístico del director dio cero hits conocidos en líneas añadidas, pero no cuenta por sí solo como seguridad certificada. Registrar conclusiones `SAFE_TO_PUBLISH` **solo si inspección del diff y scanner/régimen de seguridad realmente suficientes**, y verificar ausencia de archivos sensibles incluso en commits intermedios. Ante duda: `HOLD_SECURITY`, sin push.
3. Si scanner/control de seguridad PASS, URL real y autorización de escritura están verificados, el remoto responde, la rama `feat/picoradar-v6r4-lab-candidate` sigue ausente y el HEAD sigue EXACTO, ejecutar **UN SOLO push no forzado** a esa rama LAB. Confirmar `git ls-remote --heads` después: SHA remoto = HEAD; incluir URL. Si existe rama remota, comparar primero el SHA, nunca sobrescribir/rebasar/forzar. Si 403, suspensión, límites o auth bloquean, **NO reintentar indefinidamente**: una vez, hold y bundle.
4. Este push **no** constituye PR listo, merge, release, CI aprobado, Hostinger, CDN ni aplicación instalada. **No** empujar código LAB a `main`, ni tocar PR #71 o #79. Todo producto permanece `NO_GO` hasta backend, Android y decisión del propietario.
5. Si F2 no exige cambios productivos, NO crear commit solo para narrar pruebas. Si hay nuevo commit focal, anotar HEAD/TREE/PARENT y actualizar rango de seguridad antes del push. Un branch remoto puede estar publicado como **LAB** aunque F2 siga con hold de evidencia R2, siempre que seguridad y F1 PASS se mantengan: dejar su estado claramente no publicable.

## E. F3 — ANDROID: CONDICIONAL REAL, SIN QUEMAR OTRO INTENTO

- El V4 tuvo `pagefile_free=3.37 GiB` y `-Xmx8G` + metaspace 4G. **No convertir esto en «error de Flutter»**; no usar `flutter build`/Gradle si el host/recursos siguen iguales. No modificar `gradle.properties`, JVM, pagefile, Windows ni políticas para obtener verde artificial.
- Recalcular RAM/commit/pagefile **solo si hay evidencia de que cambió el host o hubo ampliación real de recursos**, no como ritual. Exigir el gate de margen seguro anterior (mínimo pagefile y commit libre 6 GiB, y memoria adecuada a valores efectivos JVM). Si no pasa, `F3_BLOCKED_HOST_RESOURCE_STABLE` y continuar F2/F4.
- Solo si ya existe un equipo compatible gratuito, ambiente Android/SDK/Gradle conocido y margen medido, realizar **UNA** compilación debug acotada en clon aislado; `--no-pub` cuando corresponda; no teléfono, no desinstalación ni cambio de firma. Verificar APK bytes/SHA solo si se generó; no decir "APK listo" sin instalar/probar luego. Si surge error nuevo, capturar causa, no reintentar tres versiones de Gradle ni usar CI pago.

## F. EVIDENCIAS Y CONTRATO DE SALIDA — UN SOLO ZIP

**Directorio de entrega:** `D:\codex\_REPORTES\PicoRadar\V6R4-POSTV4-F2-GITHUB-ANDROID-20261114\delivery\` (crear sin borrar otros reportes). **Archivo único:** `PICORADAR_V6R4_POSTV4_F2_GITHUB_ANDROID_EVIDENCIA_UNICA.zip`.

El ZIP deberá contener **solo lo nuevo y lo necesario para recuperar**, sin duplicar ZIP anteriores:

- `FINAL_REPORT.md`: tabla F0 heredado PASS, F1 heredado PASS, F2 subcasos, F3, F4, F5; comandos reales con exit, versiones, tiempos, origen de fixtures/hashes; siguiente bloqueo real y `NEXT_ACTOR=CHATGPT_DIRECTOR`. Separar hechos de hipótesis, logs de pruebas y decisiones.
- `GATES.csv`: cada caso ejecutado con exit exacto, SHA código/test/fixture, duración si existe. No marcar PASS tests omitidos. Variables config redactadas, solo boolean/identidad no sensibles.
- `LOGS/`: stdout/stderr acotados (con credenciales y claves redactadas antes de empaquetar), detalle real de DB preflight/postflight; resultados F2; resultado seguridad remoto; preflight Android **solo si cambió hardware**.
- `GIT/full-final.bundle`: desde HEAD final, incluso si no hubo cambios (para **una entrega recuperable independiente**). Más `GIT/HEAD.txt` con HEAD/TREE/PARENT, `GIT/RESTORE.md` probado en clon aislado, `GIT/CHANGED_PATHS.txt` exclusivamente nuevos cambios, comparativa PR71→HEAD y resultado remoto. **No** incluir `.git`, database ni archivos personales sueltos.
- `MANIFEST_SHA256.csv` con ruta/bytes/CRC32/SHA256 de todos los miembros **excepto el propio manifiesto**; CRC ZIP global, extracción/verificación, SHA256 ZIP final informados al usuario. Usar un único ZIP sin otros adjuntos en la entrega.

**F0/F1 previos no necesitan nuevos logs**, solo referencia exacta al ZIP V4 con SHA256. Si hay fallo ambiental definitivo, seguir creando ZIP, no abrir otra micro-orden. **Nunca subir el ZIP completo al repo ni publicar contenido privado.**

## G. GATE FINAL / PROHIBICIONES / QUIÉN SIGUE

**Se considera éxito de este lote:** `F2_FULL_PASS_SCOPED_QA`, o `F2_CORE_PASS_R2_DEPENDENT_BLOCKED` con causa documental exacta; `F4_BRANCH_SYNCED_LAB` o `F4_HOLD_SECURITY` con razones verificadas; `F3_APK_DEBUG_BUILT` solo si gate de recursos, en otro caso `F3_BLOCKED_HOST_RESOURCE_STABLE`; `F5_ZIP_VERIFY_PASS`. No declarar app completa todavía.

**Leyes L1–L6:** KISS/Ponytail (1 motor schema2, sin reescritura); antirruido (no repetir PASS); antiparches (APP_KEY/fixtures, no cambiar tests para esconderlos); UX intacta; QA con evidencia independiente y alcance cierto; antipingpong (UNA ejecución residual, no tres nuevas auditorías). Política editorial: fuente oficial de alcaldía/gobernación/tránsito basta para campos que expresa sin exigir PDF, pero no inventar festivos, alcances ni exenciones. Sin GPS/placas reales, sin `migrate:fresh` fuera de QA, sin datos productivos, sin pago, sin acciones destructivas. Sin release ni APK al Mi A3 sin autorización aparte.

**RESPUESTA FINAL DE CODEX EN EL CHAT:** `TASK_ID | F2 | F3 | F4 | F5 | FINAL_HEAD | FINAL_TREE | ZIP_SHA256 | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`, más **UN SOLO enlace al ZIP de evidencia**. No adjuntar reportes sueltos, prompts ni tests adicionales fuera de ese ZIP.

**QUIÉN SIGUE DESPUÉS DE ESTE BLOQUE: CHATGPT DIRECTOR PARA AUDITAR SOLAMENTE EL DELTA Y DECIDIR INTEGRACIÓN/RELEASE.**
