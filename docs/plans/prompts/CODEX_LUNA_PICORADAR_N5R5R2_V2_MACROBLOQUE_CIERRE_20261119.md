# CODEX LUNA — PICORADAR N5-R5-R2 V2 · MACROBLOQUE FINAL INTEGRACIÓN + QA CAUSAL + AVANCE VERTICAL NACIONAL

**ORDEN DIRECTA PARA CODEX LUNA.** Director: ChatGPT. Fecha de corte: 19/11/2026, `America/Bogota`.
**TASK_ID INALTERADO:** `PICORADAR-N5R5R2-AUTOCONTENIDO-20261119` (V2 mejora la ejecución de ese MISMO lote; **NO** es N5-R5-R3 ni una auditoría independiente adicional).
**ENTRADA ÚNICA:** este Markdown físico íntegro con la carga comprimida al final, sin ZIP de entrada, sin depender de GitHub Actions y sin reconstruir N3/N4/N5. **Si R2 V1 ya se está ejecutando o terminó con evidencia nueva, NO relanzar V2 en paralelo: conservar su trabajo y devolver su resultado**. No intervenir checkout ajeno.
**SALIDA:** exactamente un ZIP con resultados verificables, no un nuevo informe de preflight; sin otros adjuntos independientes.

## 0. Decisión y estado CONGELADOS — leer una sola vez

- Proyecto exclusivo: PicoRadar (`sierraglobalcompany-rgb/PicoRadar`). Aplicación Flutter/Drift y servidor Laravel: motor nacional único `schemaVersion=2`; datos por autoridad, municipio, modalidad, servicio, categoría, días, horarios, periodos, excepciones explícitas y activación; editor manual de jurisdicciones; exportación manifest/JSON/SHA-256; OTA con integridad, fallback y consulta offline. No motores/APK por municipio.
- Source base N3-R1 **tree** `a883b64fffb53d3d9ec263739c169561ddf8b49d`. Parche gzip/Base64 INCLUIDO abajo; descomprime a **217.228 bytes** SHA-256 `04b23709133b1b6fb02e6bea7c9b735305d8670c223b8df319602a3862a1b19b`, **61 rutas, incluidas 15 rutas de test**. Aplicado sobre N3 produce `INTEGRATED_TREE=986a24831aef2bcc6d261be771839f71c1129d40`. Ya verificado estáticamente por Director; Codex solo confirma en Windows y PASA A IMPLEMENTAR/TESTEAR.
- Último Codex ejecutado conocido: R1 `BLOCKED_INPUT_ZIP`; R2 V1 preparado pero sin evidencia de ejecución posterior. **NO buscar el ZIP faltante, ni RC2, ni repetir V4/N4, ni repetir 20 pasadas.** Si la realidad local demuestra que R2 ya fue aplicado/testeado, comprobar la identidad del árbol y continuar con los gates faltantes en ese mismo aislado, sin crear otra reconstrucción.
- Original de Windows: 43 entradas WIP reportadas en R1, **estado actual no verificado**. `sourceRepo` se consulta solo para objetos Git y huellas sin cambios; jamás `git checkout/reset/clean/stash/add/commit/branch` en el origen. Ni borrar caches ni firmar/instalar en Mi A3; no publicar ni tocar servidor real.
- Remoto: GitHub `main` NO equivale al árbol integrado. PR #79 Draft, head `docs/plan-maestro-nacional-v2-20261107`, base `recovery/20261019-modern`; rama de documentación separada `director/n5-modality-safe-20261118`; `GITHUB_PRODUCT=HOLD_SECURITY`; NO push, merge, force-push, deploy, credenciales ni GitHub Actions para este lote. Documentación remota existente no es certificación.
- Reglas obligatorias: **L1 KISS+Ponytail; L2 Antirruido; L3 Antiparches; L4 UX humana; L5 Verificación independiente; L6 Antipingpong.** `AGENTS.md` exige **Inicio · Garaje · Apps · Viaje · Conducir**, Apps al centro. Ajustes sigue accesible sin alterar esa barra. Free 1.0 sin registro obligatorio, ads/marketing/correo real OFF. Placa/VIN/documentos/GPS exacto/rutas permanecen locales; sin reglas oficiales suficientes responder `UNKNOWN/STALE`, nunca `ALLOWED` por ausencia de cobertura.
- Avance documental heredado **NO medido por gates actuales:** aplicación integral ≈58%, núcleo técnico nacional ≈83%; motor 90%, servidor 85%, editor 75%, OTA 60%, Super Admin 60%, cuentas 65%, publicidad/aliados 45%, Android/release 35%. **No aumentar ninguna cifra por reconstruir un árbol o correr un preflight.** Cobertura normativa nacional sin porcentaje verificable; catálogo de 1.104 entradas ≠ 1.104 normas.

## 1. Recuperación determinista en Windows, protección de WIP y portabilidad entre sesiones

**Paso previo único:** identifica la ruta física de ESTE `.md` adjunto y la ruta verdadera del repo fuente N4/N3. Si no se sabe la ruta, utiliza solo la ubicación reportada en el último lote N4 y una búsqueda local acotada allí; NO rastrear todo el disco, NO consultar al usuario por el ZIP. No adivinar `Downloads`. Revisa `git -C <origen> status --porcelain=v1` **solo lectura** y, si cabe, hash de HEAD/índice. Si se requiere editar código, hacerlo exclusivamente en el aislado.

**PowerShell — completar SOLO dos rutas físicas de entrada** (`$mdPath` y `$sourceRepo`). El script elige un directorio aislado libre, jamás borra uno existente, persiste *alternates* para procesos nuevos, y valida el árbol exacto. No ejecutar por partes sobre el checkout fuente:

```powershell
$ErrorActionPreference = 'Stop'
$mdPath = '<RUTA_REAL_DEL_MARKDOWN_FISICO_V2>'
$sourceRepo = '<RUTA_REAL_REPO_N4_O_N3_PROTEGIDO>'
$baseTarget = 'D:\codex\_isolated\PICORADAR-N5R5R2-20261119'
$patchPath = 'D:\codex\_isolated\PICORADAR-N5R5R2-BASE.patch'
$n3 = 'a883b64fffb53d3d9ec263739c169561ddf8b49d'
$expectedPatch = '04b23709133b1b6fb02e6bea7c9b735305d8670c223b8df319602a3862a1b19b'
$expectedTree = '986a24831aef2bcc6d261be771839f71c1129d40'
if (!(Test-Path -LiteralPath $mdPath -PathType Leaf)) { throw 'MD_PHYSICAL_FILE_MISSING' }
if (!(Test-Path -LiteralPath $sourceRepo -PathType Container)) { throw 'SOURCE_REPO_MISSING' }
$target = $baseTarget
for ($i = 1; (Test-Path -LiteralPath $target); $i++) {
  if ($i -gt 3) { throw 'ALL_ISOLATED_DESTINATIONS_EXIST_INSPECT_PRIOR_RESULT' }
  $target = "$baseTarget-$('{0:D2}' -f $i)"
}
$txt = [System.IO.File]::ReadAllText($mdPath, [System.Text.Encoding]::UTF8)
$startMatch = [regex]::Match($txt, '(?m)^@@BEGIN_N5R5R2_GZIP@@\r?$')
$endMatch = [regex]::Match($txt, '(?m)^@@END_N5R5R2_GZIP@@\r?$')
if (!$startMatch.Success -or !$endMatch.Success -or $endMatch.Index -le $startMatch.Index) { throw 'PAYLOAD_MARKERS_INVALID' }
$payload = ($txt.Substring($startMatch.Index + $startMatch.Length, $endMatch.Index - $startMatch.Index - $startMatch.Length) -replace '\s+', '')
[byte[]]$gzBytes = [Convert]::FromBase64String($payload)
New-Item -ItemType Directory -Path (Split-Path -Parent $patchPath) -Force | Out-Null
$mem = [System.IO.MemoryStream]::new([byte[]]$gzBytes)
$gz = [System.IO.Compression.GZipStream]::new($mem, [System.IO.Compression.CompressionMode]::Decompress)
$out = [System.IO.File]::Create($patchPath)
try { $gz.CopyTo($out) } finally { $out.Dispose(); $gz.Dispose(); $mem.Dispose() }
$realPatch = (Get-FileHash -LiteralPath $patchPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($realPatch -ne $expectedPatch) { throw "PAYLOAD_SHA_MISMATCH:$realPatch" }
$sourceObjs = (git -C $sourceRepo rev-parse --path-format=absolute --git-path objects).Trim()
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $sourceObjs)) { throw 'SOURCE_OBJECTS_UNAVAILABLE' }
New-Item -ItemType Directory -Path $target -Force | Out-Null
git -C $target init -q; if ($LASTEXITCODE -ne 0) { throw 'ISOLATED_INIT_FAILED' }
git -C $target config core.autocrlf false; if ($LASTEXITCODE -ne 0) { throw 'GIT_CONFIG_FAILED' }
# CRÍTICO: no depender de la variable de entorno de esta ventana de PowerShell.
$altFile = Join-Path $target '.git\objects\info\alternates'
$altText = ($sourceObjs -replace '\\', '/') + [Environment]::NewLine
[System.IO.File]::WriteAllText($altFile, $altText, [System.Text.UTF8Encoding]::new($false))
$kind = (git -C $target cat-file -t $n3).Trim()
if ($LASTEXITCODE -ne 0 -or $kind -ne 'tree') { throw 'N3_TREE_NOT_READABLE_FROM_PERSISTED_ALTERNATES' }
git -C $target read-tree $n3; if ($LASTEXITCODE -ne 0) { throw 'READ_TREE_FAILED' }
$synthetic = ('Synthetic N3-R1 isolated base' | git -C $target -c user.name='PicoRadar QA Local' -c user.email='qa@invalid.example' commit-tree $n3).Trim()
if ($LASTEXITCODE -ne 0 -or !$synthetic) { throw 'SYNTHETIC_COMMIT_FAILED' }
git -C $target symbolic-ref HEAD refs/heads/picoradar-isolated
if ($LASTEXITCODE -ne 0) { throw 'SYMBOLIC_REF_FAILED' }
git -C $target update-ref refs/heads/picoradar-isolated $synthetic
if ($LASTEXITCODE -ne 0) { throw 'UPDATE_REF_FAILED' }
git -C $target checkout-index -a -f; if ($LASTEXITCODE -ne 0) { throw 'BASE_CHECKOUT_INDEX_FAILED' }
git -C $target apply --cached --check $patchPath; if ($LASTEXITCODE -ne 0) { throw 'PATCH_CHECK_FAILED' }
git -C $target apply --cached $patchPath; if ($LASTEXITCODE -ne 0) { throw 'PATCH_APPLY_FAILED' }
git -C $target diff --cached --check $n3; if ($LASTEXITCODE -ne 0) { throw 'PATCH_WHITESPACE_FAILED' }
$integratedTree = (git -C $target write-tree).Trim()
if ($LASTEXITCODE -ne 0 -or $integratedTree -ne $expectedTree) { throw "TREE_MISMATCH:$integratedTree" }
$paths = @(git -C $target diff --cached --name-only $n3)
if ($paths.Count -ne 61) { throw "EXPECTED_61_PATHS_GOT_$($paths.Count)" }
git -C $target checkout-index -a -f; if ($LASTEXITCODE -ne 0) { throw 'INTEGRATED_CHECKOUT_INDEX_FAILED' }
$diff = @(git -C $target diff --name-only)
if ($diff.Count -ne 0) { throw "INDEX_WORKTREE_MISMATCH:$($diff.Count)" }
Write-Output "N5R5R2_INTEGRATION_PASS TARGET=$target TREE=$integratedTree ROUTES=61 SOURCE_RO_ONLY=true"
```

**Nota de seguridad Git:** *alternates* persistentes evitan perder acceso al árbol al abrir otra consola, **pero NO convierten el repositorio en autónomo**; depende de los objetos fuente. El único ZIP final debe contener suficientes identificadores/hashes y el parche incremental reproducible; para traslado posterior usar base N3 + payload íntegro R2 + delta final. No copiar todo `.git` al ZIP. No forzar `git gc`, `repack`, `prune` ni limpieza en el origen. Si el árbol N3 no existe en el almacén identificado, una única corrección de ruta y retry en OTRO destino aislado; después marcar `BLOCKED_BASE_N3`, seguir con lo independiente y no inventar nueva base.

## 2. Bloque de IMPLEMENTACIÓN/VALIDACIÓN — entregar progreso real, NO otra auditoría

Ejecutar desde el árbol integrado **$target**, nunca desde el origen. Asegurar que `server` y `mobile` existen, referenciar el árbol SHA antes y después, registrar runtime y comandos/resultados. Solo una pasada focal inicial; después de corregir un defecto reproducido, ejecutar el test causal afectado y una pasada focal final; NO repetir toda la historia.

### A. Laravel: cuentas opcionales, Super Admin, editor nacional y publicaciones

Preparar un entorno de test aislado: `APP_ENV=testing`, BD SQLite temporal/memoria o base de test desechable exclusivamente autorizada; nunca `.env`/base de datos de producción. Validar que configuración de pruebas no apunte a servicio externo antes de migrar/correr tests. Si faltan `vendor`, intentar restaurar desde `composer.lock` en el aislado **una vez**, sin cambios de versión ni dependencia comercial. Ejecutar desde `$target\server`:

```text
php artisan test tests/Feature/AppAccountApiTest.php tests/Feature/AdminAppUsersTest.php tests/Feature/MobileCatalogPublicationTest.php tests/Feature/RestrictionSchemaV2LabRoundTripTest.php tests/Feature/CampaignCatalogPublisherTest.php tests/Feature/CampaignAdminControllerTest.php tests/Unit/MobileCatalogPayloadValidatorTest.php tests/Unit/RestrictionFormPayloadBuilderTest.php
```

Criterios **medibles**: (1) editor manual versiona una jurisdicción y cambia **solo** modalidad elegida, mantiene otras autoridades; (2) publicar manifest/datasets con SHA, deshacer publicación sin borrar snapshots anteriores, no declarar `complete` una cobertura parcial; (3) cuentas Free 1.0 anónimas, OTP/supresión/exportación con autorización y mínimos datos voluntarios, sin garaje/placas/GPS en backend; (4) Super Admin no exporta ni envía datos sin permisos; (5) campañas técnicas/panel preparadas pero catálogo público y correos reales OFF por defecto, HTTPS obligatorio cuando corresponda. Si un test revela un defecto concreto, arreglar **causa raíz**, no añadir flags falsos, mocks irreales ni saltos de tests. No enviar correos de prueba reales.

### B. Flutter: consumo real y fallos negativos de cuentas

Desde `$target\mobile`, verificar SDK y dependencias lock; restaurarlas una vez si hace falta. Ejecutar **exactamente** la tanda focal de 7 archivos existentes:

```text
flutter test --no-pub test/features/account/data/app_account_client_test.dart test/features/account/data/app_account_config_test.dart test/features/settings/presentation/settings_screen_test.dart test/app/mobile_catalog_ota_test.dart test/app/dataset_sync_composition_test.dart test/features/home/application/home_partner_catalog_provider_test.dart test/features/home/data/home_partner_catalog_test.dart
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test
```

**DOS defectos plausibles observados en el parche y aún sin prueba causal:**

1. `mobile/lib/features/account/data/app_account_client.dart`: en `_send`, el manejador `on DioException` vuelve a llamar `_decode(error.response?.data)`; si HTTP 503/otro error trae cuerpo malformado, un `FormatException` puede escaparse fuera del manejador. **Antes de modificar**, ver si los tests existentes cubren `HTTP 503 + invalid JSON`; si no, agregar solo ese caso. Resultado esperado: un `AppAccountFailure` tipado y UI sin crash, sin token de sesión nuevo. Corregir focalmente si falla.
2. `verifyOtp` escribe `app_account_access_token_v1` **antes** de comprobar que `profile` es válida; una respuesta `200` con token pero `profile` ausente/malformado podría dejar sesión residual. Añadir caso causal si no está cubierto: resultado `invalid_response` y almacenamiento sin token nuevo. Validar perfil **antes** de persistir; si falla escritura, no presentar sesión iniciada. No borrar una sesión anterior válida por una respuesta malformada sin test/contrato.

No interpretar estos hallazgos estáticos como tests ya ejecutados. No cambiar UI aprobada. Garantizar `UNKNOWN/STALE` frente a cobertura normativa faltante; OTA rechaza hash/manifest corrupto, conserva datos locales y usa fallback **realmente implementado** (no declarar rollback a snapshot histórico si solo regresa a assets). Si requiere `dart format`, aplicar solo a archivos editados en `lib`/`test` y comprobar el delta; evitar formato masivo del repo.

### C. Avance VERTICAL local cruzado — el gran valor de este lote

Además de los focales, **cerrar una comprobación útil de extremo a extremo LOCAL** dentro de lo que ya existe: editor Laravel guarda/edita regla de modalidad por ciudad → publicador crea manifest/dataset verificables con hash → cliente Flutter lee/valida bytes de ese mismo contrato y muestra/consulta `UNKNOWN` o restricción según cobertura; conservar otra ciudad/modalidad y documentos locales. Reutilizar `RestrictionSchemaV2LabRoundTripTest`, `MobileCatalogPublicationTest`, `mobile_catalog_ota_test` y `dataset_sync_composition_test`: **si la evidencia actual ya cubre un tramo, enlazar sus outputs; no crear sistema de test nuevo**. Si falta una unión contractual imprescindible, implementar UN test de contrato focal con fixture derivado de la salida real del laboratorio y verificar SHA + parse tipado, sin activar norma legal no confirmada. No introducir ciudad hardcodeada ni crear otro backend/motor. Esta es una prueba **local**, no atribuirle TLS/CDN real.

**Casos de aceptación núcleo:** un municipio con cobertura parcial retorna `UNKNOWN` cuando falta regla; suspensión de taxi no desactiva carro particular ni otra autoridad; vigencia/fecha/zona horaria explícitas; publicación parcial no borra otras jurisdicciones; fichero alterado no se instala; Free no solicita login ni sirve publicidad; catálogos de CDA/aseguradoras muestran asset válido si OTA falla. Corregir fallos reales derivados de integración, sin reabrir G1/G2/G34 salvo si el contrato *actual* demuestra causalidad.

### D. Gates de coste y entorno: ejecutar una sola vez cuando tienen entrada real

- **Fixtures históricos (6 FAIL conocidos):** comprobar una sola vez las rutas/hashes de G1/G2/G34/R2. Si no existen originales auténticos, `FLUTTER_GLOBAL=PARTIAL_EXTERNAL_FIXTURES`, sin correr suite global ni generar fixtures falsos. Si sí existen y focales verdes, `flutter test --no-pub` **una vez** y contar PASS/FAIL/SKIP reales.
- **APK DEV:** medir memoria/disco del host justo antes. Umbral operativo mínimo reportado: **6 GiB de margen**; N4 observó solo 4,45 GiB. Si condiciones y gates de código son satisfactorios, hacer **un** build Android DEV desde `FINAL_TREE`, con ID, versión, firma, SHA256 y logs; de lo contrario `BLOCKED_RESOURCE_GATE`. No reiniciar procesos ajenos, no limpiar caches compartidas, no desinstalar ni instalar en Mi A3 sin aprobación y compatibilidad de firma. APK DEBUG/DEV ≠ release.
- **HTTPS externo, Android físico, revisión de historial GitHub, producción, fuentes legales para toda Colombia:** no fingir pruebas. Solo ejecutar HTTPS si existe **un endpoint QA existente, seguro y expresamente autorizado** y no involucra producción real; de lo contrario `OTA_HTTPS=NOT_RUN_ENV`. No usar HTTP local como evidencia de HTTPS. Mantener `RELEASE=NO_GO` y `GITHUB_PRODUCT=HOLD_SECURITY` hasta autorización distinta.

## 3. Correcciones permitidas, alcance congelado y condición de STOP

**Permitido:** correcciones causales PHP/Dart/plantillas de los módulos del lote; agregar pruebas negativas/contrato mínimas y migración segura solo si se reproduce defecto; documentación de evidencia dentro del ZIP. **No permitido:** inventar restricciones, decretos o exenciones; subir código/PII/historial a GitHub público, alterar un `staleAfter` para silenciar fallo, activar `complete` sin fuente, SaaS pago, email real, publicidad real, estadísticas/tracking GPS, CI Actions, cambio mayor UX/arquitectura, deploy/merge, modificación al checkout WIP original. En conflictos materiales, bloquear solo la acción afectada y continuar lo independiente.

No declarar `PASS` sin comando/resultado y árbol final. Si el resultado es `NO_FIX_REQUIRED`, eso cuenta como avance **solo si** hay QA integrada real, y debe conducir al próximo gate (no a otra auditoría). La instalación/local/deploy de servidor real, la revisión del historial y publicación final se reservan para la fase de release autorizada; no se deben omitir del plan del 100%.

## 4. Evidencia única y reproduccción exacta — obligatorio

Entregar **UN ÚNICO ZIP** bajo `D:\codex\_REPORTES\PicoRadar\N5R5R2-V2-20261119\PICORADAR_N5R5R2_RETORNO_UNICO.zip` (si ya existe una entrega R2, no reemplazarla: nuevo sufijo y reportar ruta/huella). Dentro, solo:

- `FINAL_REPORT.md`: `TASK_ID`, fecha/hora, `SOURCE_N3_TREE`, `INTEGRATED_BASE_TREE`, `FINAL_TREE`, `FINAL_CODE_STATUS`, decisiones/fixes, datos reales sobre rutas/QA, estado WIP original antes/después **solo lectura**, limitaciones, `NEXT_ACTOR=CHATGPT_DIRECTOR`, prioridades siguientes, GitHub producto `HOLD_SECURITY`, release `NO_GO`.
- `GATES.csv`: cada gate `SOURCE_TREE`, `INTEGRATED_TREE`, `PHP_FOCAL`, `FLUTTER_FOCAL`, `CLIENT_NEGATIVE_CASES`, `NATIONAL_VERTICAL_LOCAL`, `FORMAT`, `ANALYZE`, `GLOBAL`, `APK_DEV`, `OTA_HTTPS`, `GITHUB_SECURITY`, `RELEASE`; `PASS` / `FAIL_CODE` / `PARTIAL` / `NOT_RUN_ENV` y motivo trazable, sin convertir suites antiguas en verdes nuevos.
- `MANIFEST.csv`: archivo, tamaño en bytes, SHA256 y CRC32 de cada miembro salvo el propio manifiesto; ZIP CRC verificado y SHA256 del ZIP informado en el texto de respuesta de Codex.
- `QA_LOGS/` con salida sanitizada mínima de comandos realmente ejecutados (sin tokens, OTP, placas, VIN, rutas/GPS, secretos, certificados privados ni URL privadas). Hasta un log por familia de tests; no decenas de adjuntos fuera del ZIP.
- `RECOVERY.patch` **solo si hay código corregido**, patch binario generado desde `INTEGRATED_BASE_TREE=986a24831aef2bcc6d261be771839f71c1129d40` hasta `FINAL_TREE`, NO desde HEAD sintético N3. Para obtenerlo en el repo aislado, agregar **solo los archivos efectivamente modificados/autorizados** y usar `git diff --cached 986a24831aef2bcc6d261be771839f71c1129d40 --binary`. Comprobar que al aplicar N3+payload original+delta se reproduce `FINAL_TREE` en una copia independiente si resulta factible sin nuevos artefactos grandes; jamás añadir secretos o fixtures externos no autorizados.
- `APP_DEV.apk` solo si es **nueva**, generada en este lote. No incluir APK anterior, repos completos, ZIP R1, PDF histórico, payload base64, `.env` reales, `vendor`, `build`, caches ni `.git`.

**Regla de evidencia:** comprobar que `FINAL_TREE` se calculó luego de terminar fixes/tests; ligar todos los logs a ese árbol (si hubo fixes después de tests, retestar solo lo afectado y actualizar el árbol final). Nada de placeholders `$variable` como resultado. El ZIP contiene todo lo necesario para **auditar sin pedirte 10 archivos**; sin bundles históricos gigantes. Si hay FAIL_CODE reproducible, corregir en este lote antes de devolver; no quedarse en diagnóstico formal.

## 5. Definición objetiva de acercamiento al 100% y turno siguiente

**Ahora se cierra el tramo de código integrado**: N4+N5/01–04, servidor/publicador/editor/schema2, cuentas anónimas opcionales, Super Admin, catálogos CDA/aseguradoras, publicidad preparada OFF, cliente Android Flutter y QA causal. Criterio de progreso: 61 rutas recuperadas + focales PASS en árbol final + recorrido vertical local PASS + bugs reales corregidos, sin duplicar arquitectura. Si no hay recursos externos, no confundir `PARTIAL` con defecto de código.

**Después de este ZIP, ChatGPT Director** valida solo el delta y programa el último recorrido seguro: backend Laravel en QA HTTPS autorizado → manifest/OTA versionado → Drift/offline/rollback → APK firmada/QA física sin pérdida de Garaje → seguridad GitHub/historial → publicación y monitoreo autorizado. La ampliación editorial nacional por fuentes oficiales continúa **por lotes de datos OTA** sin versiones móviles por ciudad. No declarar 100% nacional mientras existan jurisdicciones/modalidades sin cobertura acreditada; `UNKNOWN/STALE` permanece.

**No pedir otro prompt ni una segunda auditoría del mismo material. No crear N5-R5-R3. Si ya está corriendo R2 V1, preservarlo y usar sus pruebas como única ejecución.**

## 6. Respaldo excepcional de payload (no es requisito)

Si y solo si falta el archivo físico `.md` en Codex, existe el parche idéntico en GitHub commit fijo `9e853cfb63ebb2038ace8f923ed5a87c746f78bd`, ruta `docs/implementation-candidates/n5-integration/N3R1_TO_N4R2_N504_INTEGRATED.patch`. Un único intento de descarga y SHA256 obligatorio antes de aplicarlo; **no buscar ZIP anterior ni suponer acceso a GitHub**. Si el servidor privado exige autenticación, reportar `PATCH_SOURCE_UNAVAILABLE`, no degradar garantías.

**🔴 NEXT_ACTOR=CODEX_LUNA — SOLO SI AÚN NO ESTÁ CORRIENDO R2.**
**🔴 AL REGRESAR EL ZIP ÚNICO: NEXT_ACTOR=CHATGPT_DIRECTOR.**
**RELEASE=NO_GO; GITHUB_PRODUCT=HOLD_SECURITY.**

<!-- PAYLOAD INMUTABLE DE R2: la marca y Base64 han sido trasladados literalmente, sin modificar bytes del parche. No editar, reformatear ni copiar al chat. -->

@@BEGIN_N5R5R2_GZIP@@
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
@@END_N5R5R2_GZIP@@