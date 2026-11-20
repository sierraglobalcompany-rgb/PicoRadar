# CODEX LUNA — PICORADAR · N5-R5-R2 V2 C1-V2 · CIERRE PARALELO CAUSAL Y PRODUCTO NACIONAL

**ACTOR: CODEX LUNA — EJECUTAR, NO REAUDITAR.** Director: ChatGPT. Corte: 19/11/2026 (America/Bogota). Esta orden **sustituye al C1 anterior SOLO si aún no está ejecutándose**. Si C1 ya está activo, no iniciar otro escritor ni otro lote: incorporar únicamente las salvaguardas de concurrencia cuando sea seguro. No volver a R1, R2 V2 completo ni crear R3.

`TASK_ID=PICORADAR-N5R5R2-V2-C1-CAUSAL-20261119` (ID de lote estable, revisión documental V2). **Entrada física única: este Markdown íntegro. Salida única: UN ZIP de retorno**. Lo que está hecho se conserva; la meta es **cerrar gates nuevos y ejecutar producto**, no producir diagnósticos sin corrección.

## 0. Decisión y estado confirmado antes de iniciar

| Gate / área | Base acreditada por el ZIP de Codex R2 V2 | Nueva acción, si aplica |
|---|---|---|
| Árbol base N3 | `a883b64fffb53d3d9ec263739c169561ddf8b49d` | Solo recuperación excepcional |
| Árbol integrado N4+N5 | `986a24831aef2bcc6d261be771839f71c1129d40` | No reimplementar |
| **Árbol final R2 V2** | **`859bb8bbdff769ec3504af407f4df27593b2efea`** | Reusar como **única base de código**; verificar índice/worktree |
| Flutter focal / global | **65 PASS** / **3.365 PASS + 11 SKIP**, sin fallos reportados | **No repetir global ni focal por rutina**; solo tests tocados |
| Flutter analyze/formato | PASS en el árbol previo | Repetir analyze y formato solo si se modifica Dart |
| OTP malformado | Corregido: perfil validado antes de guardar token | No revertir ni reabrir lo ya verde |
| PHP causal | 4 PASS/75 assertions | No repetir si no cambia código afectado |
| PHP focal | 16 PASS/592 assertions, **37 warnings** | **Diagnóstico con salidas originales** y arreglo causal o clasificación sustentada |
| Publicación schema2 | Release sintético de **59.273 B**, SHA-256 `9a230f167af82452276bbd505c6e3a69ce8406996e60c7baaf143e157979741e`; manifest 424 B | Verificar **release + manifest de la misma corrida** |
| Puente Laravel → Flutter | **NOT_RUN**: hook objective_c `Invalid SDK hash` antes de aserciones | Resolver incoherencia local, correr una vez el test vertical de bytes actuales |
| APK DEV | NOT_RUN | **Una compilación segura** cuando condiciones mínimas lo permitan; no instalar Mi A3 |
| HTTPS / GitHub código / distribución | `NOT_RUN / HOLD_SECURITY / NO_GO` | No fingir release ni publicar código protegido |

**Principio de avance:** `PHP_WARNINGS` y `SDK_BRIDGE` son **dos carriles independientes**. Si falla uno, el otro y la preparación de APK DEV pueden avanzar si no violan seguridad. Un bloqueo parcial no justifica terminar el ZIP sin intentar el trabajo no dependiente.

### Contratos congelados (no tocar alcance ni arquitectura)

- Canon real L1 **KISS/Ponytail**, L2 antirruido, L3 antiparches, L4 UX humana, L5 verificación independiente, L6 antipingpong. Aplicar `AGENTS.md` y baselines reales del árbol; prevalece seguridad/privacidad, no este Markdown cuando haya conflicto verificable.
- **Una app Flutter/Riverpod/Drift y un Laravel monolítico; un solo motor `schemaVersion=2` para toda Colombia**. Actualizaciones ordinarias por datasets/manifest/OTA, no APK por municipio. Sin cobertura institucional: `UNKNOWN`, `STALE` o `CONFLICT`, jamás `ALLOWED` inferido. No deducir exenciones ni ausencia de pico y placa a partir de catálogos.
- **Barra aprobada** `Inicio · Garaje · Apps · Viaje · Conducir`, **Apps al centro**. Ajustes fuera de esa barra. Free 1.0 anónima; cuentas voluntarias y Super Admin separados; documentos/placas/VIN/GPS y recorridos **local-only**. No exponer datos privados en logs/ZIP/GitHub.
- Editor manual nacional y suspensión por autoridad/modalidad conservan otros datasets y vigencias; CDA/aseguradoras OTA con hashes, último snapshot válido y fallback. **Publicidad, campañas, correos reales, monetización y telemetría OFF** hasta aprobación separada. Se pueden probar sus caminos técnicos offline sin enviar correo ni mostrar ads reales.
- `GITHUB_PRODUCT=HOLD_SECURITY`, `RELEASE=NO_GO`. Prohibidos push/merge de código productivo, History rewrite, deploy, firma release, publicación, GitHub Actions de pago y manipulación del Xiaomi Mi A3. La rama de documentos GitHub no prueba código publicado.
- Checkout fuente protegido: último informe **HEAD `182a8821bba688b28a6e223a1e956df748f7948b`, índice `24408f305f7a977cf30e426ce3925cca19f981ad`, 43 WIP (18 modificados, 25 untracked)**; huella reportada `A132937B4483A8022D45C7F7D9E56B3981915A51DB6161E713F8E2EFBA792C0A`. Hoy ese estado del host no ha sido inspeccionado desde ChatGPT. **Solo lectura en fuente**; respetar eliminación previa `scripts/tests/test_hostinger_installer_browser.ps1`. Si cambia la huella, registrar diferencia y detener solo la acción que amenace WIP.

## 1. Reusar primero el candidato R2 V2, no buscar viejos ZIP

1. Codex identifica su candidato real **exclusivamente** bajo `D:\codex\_isolated\PICORADAR-N5R5R2-20261119*`, sin búsquedas amplias. Comparar **índice** (`git write-tree`) con `859bb8bbdff769ec3504af407f4df27593b2efea`, y **worktree** (`git diff --name-only` y archivos relevantes) contra el índice. Si PASS, **continuar de inmediato**. No deshacer staged, ni `git clean`, ni `reset`, ni `checkout` en fuente.
2. Si **no está** ese árbol, ejecutar **una vez** la recuperación autocontenida del bloque PowerShell incluido más adelante. N3 + parche base 61 rutas + delta R2 V2 9 rutas deben producir exactamente el árbol final. Verificar SHA de cada parche antes de aplicar. Nunca usar `main` viejo como reemplazo de N3.
3. El archivo `.git/objects/info/alternates` dentro del clon **aislado** da acceso persistente de solo lectura a objetos fuente; **no independiza el clon**. No ejecutar `git gc`, `repack` o `prune` en origen. Para entrega portar solo parches del cambio C1 y sus hashes (ver §6); el histórico base se conserva en este Markdown.

## 2. Ejecución PARALELA SEGURA: 2 subagentes como máximo, UN integrador

**Dueño de todo el lote: Codex Luna coordinador.** Puede iniciar **máximo dos subagentes** si Codex soporta paralelismo real y el host tiene recursos. No crear tres ramas de producto, varios prompts, varios ZIP ni dos agentes tocando el mismo archivo/caché/índice. **El coordinador es el único responsable de integrar los cambios y emitir `FINAL_TREE`.**

| Trabajo | Agente y acceso | Resultado útil exigido |
|---|---|---|
| **A — Laravel/PHP y catálogo nacional** | Worker A, **worktree aislado A**, dueño de `server/**` únicamente | Resolver/clasificar los 37 warnings; probar al menos la causa afectada. Verificar por contrato editor/autoridad/modalidad, datos `partial`, Super Admin/consentimiento y Ads OFF sin crear funcionalidades nuevas. Entregar **un diff causal** y logs acotados. |
| **B — Flutter/SDK/Android** | Worker B, **worktree aislado B**, dueño de `mobile/**` únicamente | Diagnosticar hash SDK de `objective_c`, probar recuperación de hook **solo local**, revisar test de puente y preparar un build DEV cuando el entorno sea seguro. Entregar **un diff causal** si cambia código, versiones SDK y logs. No tocar salida Laravel ni construir APK mientras corran tareas pesadas del A. |
| **I — Integrador único** | Coordinador, **candidato aislado original**, único dueño del índice final/ZIP | Aplicar ambos parches revisados; generar o reutilizar **un solo** release Laravel/manifest; ejecutar test Flutter con **esos bytes**, QA afectada y un build DEV posible; cerrar gates y empaquetar evidencias. |

**Materialización KISS de los subagentes (solo si hay paralelismo real):** desde el candidato aislado con `write-tree` final exacto, el coordinador crea un commit sintético **solo en el repositorio aislado** con `git commit-tree <FINAL_TREE>` (sin mover HEAD ni refs del checkout fuente). Luego crea `git worktree add --detach <A> <synthetic_commit>` y `<B>`, en rutas **nuevas** bajo `D:\codex\_isolated\_workers\`. Cada worker usa su **propio índice/worktree**, no `git add` sobre el candidato coordinador, no hace push ni toca el original. `git add -- server` solo en A, `git add -- mobile` solo en B, y cada uno exporta **solo sus cambios** con `git diff --cached <synthetic_commit> --binary` y `git diff --cached --check`; registrar también archivos nuevos, si existen. **No mezclar los `HEAD` sintéticos con HEAD productivo.** No borrar los worktrees hasta obtener la entrega.

**Integración:** coordinador revisa A/B por rutas e impactos; sobre **SU ÍNDICE aislado** aplica primero `git apply --cached --check` y luego el patch de A y el de B. Al materializar el resultado hacia SU worktree, verificar que no existan ediciones locales legítimas sin incorporar, ni se sobreescriban archivos de otra rama. Si se cruza una ruta entre A y B, detener solo esa integración y resolverla **una vez**, no doble escritura. El `FINAL_TREE` final solo se aprueba tras `git write-tree` y tests del delta afectado. No declarar PASS de los workers como PASS integrado.

**Si no hay subagentes, faltan objetos/recursos o la creación de worktrees genera riesgo:** usar **un único proceso secuencial** en el candidato aislado: A → B → I, sin perder ninguna obligación del lote. **No instalar herramientas ni ampliar arquitectura para habilitar subagentes.** Restringir compilaciones de Flutter/Gradle y PHP bajo presión de memoria a ejecución no simultánea; no compartir procesos de `pub get`, `composer install`, `.dart_tool`, `build/` o cachés globales entre dos writers. Si se necesita entorno de dependencias, lo organiza el coordinador sin reconfigurar otros proyectos.

## 3. Worker A — PHP_WARNINGS y producto Laravel nacional (sin reauditoría)

1. Inspeccionar versionado local PHP/PHPUnit y **solo los ocho tests focales** del lote. Los **37 warnings anteriores no tienen trazas brutas en el ZIP** y no se pueden atribuir a producción sin reproducción. Una ejecución diagnóstica focal con capturas stdout+stderr completas y `--display-warnings` si `vendor/bin/phpunit --help` demuestra soporte (no asumir que `artisan` y PHPUnit muestran lo mismo). Comprobar que el filtro realmente ejecutó los tests correctos; **no usar un conteo exacto heredado como reemplazo del éxito**. Fallback: única invocación Laravel de esas ocho rutas.
2. Agrupar las advertencias por **causa + archivo + mensaje**, preservar un ejemplo completo y cantidad real. Si hay `file_get_contents` por ruta/cwd, fixture, fecha o permisos, corregir **la causa** en un test/servicio mínimo; añadir test negativo cuando un defecto de producto lo exija. **Prohibido** `@`, `error_reporting(0)`, `skip`, mocks falsos, alterar `staleAfter` o modificar `.env` reales para pintar verde. Warnings de dependencias externas comprobados → `PARTIAL_EXTERNAL` con evidencia, no PASS; no bloquear Flutter.
3. Verificar un recorrido Laravel **sintético y autorizado** con el editor/servicio YA existente: `schemaVersion=2`, autoridad, modalidad habilitada/suspendida, conservación de demás jurisdicciones, publicidad pública OFF, acceso Super Admin sin bypass y catálogos CDA/aseguradoras con `manifest/SHA`. Ejecutar **solo tests existentes relevantes** y un negativo mínimo si se detecta defecto real. **No añadir un editor nuevo, CRM, plataforma de campañas ni datos nacionales inventados.**
4. Tras cambios, correr **solo tests causales afectados** y control PHP correspondiente (`php -l`, Pint si cambió PHP). Guardar patch/árbol/estado. Si no hay defecto, **no forzar cambios**. Debe regresar un resultado aunque Flutter esté bloqueado.

## 4. Worker B — SDK_COHERENCE y puente Flutter preparado

1. Registrar `where.exe flutter`, `where.exe dart`, `flutter --version`, `dart --version`, path de SDK efectivo y firma de `pubspec.lock` (esperado `E86ADA9D658800B3C47BCFB1F8743D3FF14CE75FAC1B81BC040B16CCFB03A41B`). Comparar Dart integrado con el externo, inspeccionar qué proceso invoca el hook `objective_c`. `Invalid SDK hash` puede ser caché de compilación pero **no lo demuestra**. No cambiar versión de Flutter/Dart ni lock, ni usar `flutter clean` o `dart pub cache repair`.
2. Ubicar el hook compilado real y sus metadatos con un **único rastreo focal** dentro del **worktree de B**. Si existe `mobile/.dart_tool/hooks_runner/objective_c` y es directorio ordinario interno, cuarentenarlo por **renombrado dentro del worktree B** con huella previa, nunca eliminar cachés globales/symlinks/junctions ni tocar la fuente. Usar la forma normal del propio paquete para regenerar con el SDK activo, no scripts inventados. Repetir el test de puente **una vez** con datos vigentes que entregue I; si todavía no hay release, diagnosticar el hook con un test local mínimo existente que lo active, y entregar el resultado al coordinador.
3. Si el error persiste, distinguir `SDK_CONFLICT / HOOK_CACHE / TOOLCHAIN / NOT_RUN_ENV` con logs y seguir en lo demás. Revisar solo escenarios Flutter pertinentes a motor nacional y privacidad: manifest+SHA rechazo de corrupción, `UNKNOWN/STALE`, aislamiento de modalidades, último dataset bueno, cuentas OTP y Ads OFF. No reejecutar global 3.365 ni focal 65 salvo archivos cambiados que lo exijan.
4. El coordinador (no B en paralelo con otros builds) decide APK DEV tras integrar. El trabajo B no puede habilitar publicación ni cambiar el `applicationId` o firma.

## 5. Integrador — VERTICAL_SAME_BYTES y APK DEV, gates no circulares

**VÍNCULO REAL entre herramientas:** tomar del Worker A **el publisher y test Laravel existentes**, no JSON manual. Localizar las rutas reales del test `server/tests/Feature/RestrictionSchemaV2LabRoundTripTest.php` y del test Flutter que consume `PICORADAR_G2_V3_EVIDENCE_DIR`. Reusar release+manifest auténticos de la misma corrida solo si hashes y origen coinciden; si faltan, producirlos **UNA vez** mediante la ruta Laravel real en el árbol integrado final. Guardar ambos archivos y el SHA de cada uno en `QA_LOGS` y en la misma carpeta de evidencia relativa. El hash `9a230f...` es referencia del lote anterior, **no condición para obligar a fabricar exactamente ese JSON nuevo**.

Con el directorio `PICORADAR_G2_V3_EVIDENCE_DIR` apuntando a ambos archivos, ejecutar **solo el test Flutter del puente con sus aserciones reales**. Si el test aborta antes de aserciones, `VERTICAL=PARTIAL_ENV`, nunca PASS. Verificar los casos que el código del test efectivamente comprueba; si faltan condiciones críticas (preservación de modalidades, `UNKNOWN/STALE`, hash, offline/rollback), añadir **solo los asertos ausentes necesarios y respaldados por contrato**. Un test verde que consume fixture viejo no acredita el release actual.

**Condiciones independientes de entrega:**
- `PHP_WARNINGS` puede ser `PASS` o `PARTIAL_EXTERNAL` argumentado; no declarar PASS sin nueva salida real.
- `SDK_COHERENCE` y `VERTICAL_SAME_BYTES` pueden seguir `PARTIAL_ENV`; aun así se exige trabajo independiente. Si se modificó código, correr solo sus pruebas causales en árbol **integrado**, más analyze/formato si Dart cambió. No repetir suite global como ritual.
- **APK DEV**: cuando el estado Flutter base siga PASS, no existan fallos de código críticos de producto y haya margen seguro de recursos, medir memoria disponible, espacio en volumen real de Gradle y riesgos de otros procesos. Umbral histórico orientativo **≥6 GiB libres de RAM** para intento Gradle; no confundir RAM con disco. Un **único build DEV** desde árbol integrado y toolchain coherente, **aunque el vertical esté bloqueado por infraestructura ajena**, etiquetándolo artefacto de desarrollo **no publicable**. Si el SDK continúa roto o faltan recursos, `APK_DEV=BLOCKED_ENV/RESOURCE`; no reintentar por fuerza ni limpiar cachés compartidas.
- Si hay APK nueva, reportar `applicationId` DEV, versionCode/name, SHA256, certificado público y si permitiría o no actualizar la firma DEV previa. **No instalar**, no tocar Mi A3, no generar release con firma nueva ni distribuir.

**Compromiso de cierre:** al menos un avance medible (warnings clasificados/corregidos, puente real con asertos o APK DEV), **sin fabricar éxito cuando el entorno bloquea todos**. En caso de bloqueo real en A o B, pedir al otro agente solución focal basada en logs/causa **solo en su ámbito**, sin saltarse guards. **No volver a entregar un ZIP que solo diga “falta el ZIP de entrada”**.

## 6. ENTREGA: un solo ZIP, inspeccionable y portable

`PICORADAR_N5R5R2V2_C1_RETORNO_UNICO.zip` **nuevo**, no sobrescribir R2 V2; preferir `D:\codex\_REPORTES\PicoRadar\N5R5R2-V2-C1\`. Un único integrador empaqueta, incluyendo:

- `FINAL_REPORT.md`: TASK_ID y estado real, **BASE_TREE / FINAL_TREE**, árbol original R2 V2 fijo `859bb8bbdff769ec3504af407f4df27593b2efea`, número de rutas cambiadas, causas y correcciones, acuerdos de los workers, PHP warnings y VERTICAL, SDK, APK si existe, inventario fuente antes/después, `GITHUB_PRODUCT=HOLD_SECURITY`, `RELEASE=NO_GO`, `NEXT_ACTOR=CHATGPT_DIRECTOR`.
- `GATES.csv`: IDs `SOURCE_WIP`, `INTEGRATED_TREE`, `PHP_WARNINGS`, `PHP_EDITOR_SUPERADMIN_ADS`, `SDK_COHERENCE`, `VERTICAL_SAME_BYTES`, `FLUTTER_AFFECTED`, `APK_DEV`, `OTA_HTTPS`, `GITHUB_SECURITY`, `RELEASE`; estados `PASS`, `PARTIAL_EXTERNAL`, `PARTIAL_ENV`, `FAIL_CODE`, `NOT_RUN_ENV`, `BLOCKED_RESOURCE`, con comando/evidencia. Referir los históricos 65/3365/4 sin repetirlos ni atribuirlos a nuevo árbol por defecto.
- `QA_LOGS/php_warnings.txt`: comando y traza sanitizada representativa completa por causa, warnings por grupo antes/después, pruebas exactas con exit codes; `QA_LOGS/vertical_same_bytes.txt`: publisher real, rutas relativas de release+manifest, tamaño/hash, fixture-versus-actual, test exacto y aserciones/resultado. **Si el snapshot es pequeño y sintético**, incluir los dos archivos reales bajo `QA_SNAPSHOT/` para que ChatGPT pueda revisarlo; si contiene datos privados, incluir solo hashes, campos/estadísticas redactados y razón de exclusión.
- `QA_LOGS/sdk_environment.txt`: rutas de toolchain normalizadas/redactadas, versiones, hook, memoria/disco, error real, acciones ambientales limitadas; `QA_LOGS/workers.txt`: por subagente, scope, archivos, patch SHA, logs y recursos; si fue secuencial registrarlo.
- `RECOVERY_C1.patch` **únicamente si hubo cambios de código** desde `859bb8bbdff769ec3504af407f4df27593b2efea`, generado del **índice final del integrador**: `git diff --cached <R2V2_FINAL_TREE> --binary`; `FINAL_TREE=git write-tree` y `git diff --cached --check <R2V2_FINAL_TREE>`. Incluir rutas nuevas en índice final. El ZIP y este Markdown permiten recuperar cambios desde N3 (dos parches embebidos + este delta). **Sin cambios, no crear patch artificial.**
- APK DEV nueva solo si se generó. `MANIFEST.csv` con tamaño, SHA256 y CRC32 de todos los demás miembros; validar ZIP CRC y SHA256 y entregar **solo ese ZIP** (más una síntesis corta por chat y su SHA). Ni ZIP de origen, ni cache, ni `.git`, ni datos de usuarios, ni documentos ni SDK. No repartir reportes fuera de ZIP.

**Persistencia / GitHub:** este lote **no hace push de código productivo** mientras continúe HOLD_SECURITY. En el reporte registrar exactamente qué tree y diff habría que portar luego a una rama segura, y qué autorización de seguridad falta. El prompt documental se conserva en rama separada. **La meta de producto no cambia** por fallos de infraestructura. El siguiente Director decidirá el cierre de: OTA HTTPS QA autorizado → firma compatible y pruebas físicas seguras → revisión del histórico GitHub + publicación aprobada → cobertura normativa editorial por archivos oficiales.

## 7. Porcentaje honesto y prioridad de negocio

**Referencia anterior (no métricas calculadas):** ≈58 % aplicación integral, ≈83 % núcleo técnico. **No incrementar sin gates de QA nuevos y denominador explícito.** Estimaciones previas por módulos: motor 90 %, Laravel 85 %, editor manual 75 %, selector 75 %, OTA 60 %, cuentas 65 %, Super Admin 60 %, publicidad/aliados 45 %, Android/release 35 %. Cobertura legal nacional = **SIN PORCENTAJE ACREDITADO**; 1.104 entradas geográficas ≠ restricciones oficiales verificadas. La meta de Free 1.0 es un producto técnicamente finalizable con cobertura editorial verificada y desconocidos seguros, no una falsa promesa de todas las ciudades.

**Gates con impacto alto inmediato:** (i) resolver causa de PHP warnings, (ii) puente real mismo release y modo `UNKNOWN/STALE`, (iii) APK DEV integrada; en segundo plano, reforzar solo contratos afectados de editor/Super Admin/Ads OFF. No abrir ocho tareas de refactor ni más ciudades de laboratorio para aparentar progreso.

## 8. Auto-auditoría del prompt: 10 ataques VERDUGO + 10 sentencias JUEZ (documental, no 20 suites)

| # | Verdugo: posible fallo de instrucción | Control aplicado |
|---|---|---|
| V01 | Repetir la suite 3365 por inercia | Prohibición explícita salvo cambio causal excepcional |
| V02 | Escribir dos agentes en el mismo índice | Worktrees A/B y único integrador; fallback secuencial |
| V03 | Bloquear PHP cuando falla Dart | Carriles independientes y resultados parciales verificables |
| V04 | Atribuir warnings truncados a código real sin evidencia | Captura completa causal y clasificación |
| V05 | Tratar Invalid SDK hash como bug del motor | Check toolchain/hook ambiental antes de tocar código |
| V06 | Reusar release sintético anterior como bytes actuales | SHA y manifest de la misma corrida actual |
| V07 | Clonar `main` viejo y perder 43 WIP | Reuse isolated; recuperación N3+dos parches, fuente read-only |
| V08 | Entregar patch sin untracked ni árbol | `git add` acotado, `write-tree`, `diff --cached --binary` |
| V09 | Publicar Ads o PII para probar | OFF/no comunicación real y ZIP sanitizado |
| V10 | Confundir APK DEV con release verificado | Dev no instalable automáticamente, firma/HTTPS/QA siguen pendientes |

| # | Juez: alternativa adversarial | Dictamen |
|---|---|---|
| J01 | ¿Otra auditoría general del repo? | NO; solo delta PHP/SDK/vertical |
| J02 | ¿R3 o ZIP viejo? | NO; C1 con 2 cargas verificadas |
| J03 | ¿Paralelo incondicional? | NO; máximo 2 workers, recursos/aislamiento primero |
| J04 | ¿Refactor nuevo editor/ads? | NO; pruebas de contratos existentes, bugs causales mínimos |
| J05 | ¿Borrar caché global SDK? | NO; solo cuarentena local demostrada |
| J06 | ¿Forzar APK si bridge bloqueado? | Solo DEV si SDK, code gates y RAM/disco seguros |
| J07 | ¿Inventar 100 % nacional por selector? | NO; separar motor técnico y fuentes legales |
| J08 | ¿Hacer push del código ya? | NO; `HOLD_SECURITY`, solo documentación autorizada |
| J09 | ¿Múltiples evidencias/ZIP? | NO; ZIP único por integrador y hashes |
| J10 | ¿Cerrar como PASS por un diagnóstico? | NO; separar PASS real, PARTIAL_ENV y FAIL_CODE |

**VEREDICTO DIRECTOR:** `C1_V2_APTO_PARA_CODEX_CON_PARALELISMO_CONDICIONAL`. Conservar `TASK_ID`, árboles SHA y guardas. Trabajo siguiente: Codex ejecuta **este mismo macrobloque**, devuelve ZIP, y ChatGPT Director revisa solo cambios nuevos.

# 🔴🔴🔴 SIGUE CODEX LUNA — EJECUTAR C1-V2, HASTA UN ZIP ÚNICO CON EVIDENCIA REAL 🔴🔴🔴

**AL REGRESAR EL ZIP SIGUE: CHATGPT DIRECTOR.** No mandar un segundo prompt en paralelo ni reiniciar agentes que ya escriben en el mismo candidato.

---

### ANEXO A. PowerShell de recuperación excepcional: NO ejecutar si el árbol FINAL idéntico existe

Sustituir SOLO `$mdPath` por la ruta física comprobada de este MD y `$sourceRepo` por el repositorio que efectivamente contiene objetos N3 según el preflight R2 anterior. No inventar `Downloads` ni `D:\` si los paths existentes son distintos.

```powershell
$ErrorActionPreference='Stop'
$mdPath='<RUTA_FISICA_REAL_DE_ESTE_MD>'
$sourceRepo='<REPO_ORIGEN_PROTEGIDO_CON_OBJETO_N3>'
$baseTarget='D:\codex\_isolated\PICORADAR-N5R5R2-V2-C1-RECOVERY'
$n3='a883b64fffb53d3d9ec263739c169561ddf8b49d'
$integratedExpected='986a24831aef2bcc6d261be771839f71c1129d40'
$finalExpected='859bb8bbdff769ec3504af407f4df27593b2efea'
if (!(Test-Path -LiteralPath $mdPath -PathType Leaf)) { throw 'MD_FILE_MISSING' }
if (!(Test-Path -LiteralPath $sourceRepo -PathType Container)) { throw 'SOURCE_REPO_UNAVAILABLE' }
$target=$baseTarget
for ($i=1; (Test-Path -LiteralPath $target); $i++) {
  if ($i -gt 3) { throw 'ISOLATED_RECOVERY_DESTINATIONS_EXIST_INSPECT_ONLY' }
  $target="$baseTarget-$('{0:D2}' -f $i)"
}
$parent=Split-Path -Parent $target
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$md=[System.IO.File]::ReadAllText($mdPath,[System.Text.Encoding]::UTF8)
function Extract-VerifiedPatch([string]$tag,[string]$expectedSha,[string]$outPath) {
  $startPattern='(?m)^@@BEGIN_'+[regex]::Escape($tag)+'@@\r?$'
  $endPattern='(?m)^@@END_'+[regex]::Escape($tag)+'@@\r?$'
  $a=[regex]::Match($md,$startPattern)
  $b=[regex]::Match($md,$endPattern)
  if (!$a.Success -or !$b.Success -or $b.Index -le $a.Index) { throw "PAYLOAD_MARKER_INVALID:$tag" }
  $part=$md.Substring($a.Index+$a.Length,$b.Index-$a.Index-$a.Length) -replace '\s+',''
  $raw=[Convert]::FromBase64String($part)
  $memory=[System.IO.MemoryStream]::new([byte[]]$raw)
  $stream=[System.IO.Compression.GZipStream]::new($memory,[System.IO.Compression.CompressionMode]::Decompress)
  $output=[System.IO.File]::Create($outPath)
  try { $stream.CopyTo($output) } finally { $output.Dispose();$stream.Dispose();$memory.Dispose() }
  $real=(Get-FileHash -LiteralPath $outPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($real -ne $expectedSha) { throw "PAYLOAD_SHA_MISMATCH:${tag}:$real" }
}
$basePatch=Join-Path $parent 'PICORADAR_N3_TO_INTEGRATED_C1.patch'
$deltaPatch=Join-Path $parent 'PICORADAR_INTEGRATED_TO_R2V2_FINAL_C1.patch'
Extract-VerifiedPatch 'R2V2_BASE' '04b23709133b1b6fb02e6bea7c9b735305d8670c223b8df319602a3862a1b19b' $basePatch
Extract-VerifiedPatch 'R2V2_FINAL_DELTA' '79d8426aef6e7ae25199e3f3c73ce762d3eabdf47ddc424304195d2988ac5ebf' $deltaPatch
$sourceObjs=(git -C $sourceRepo rev-parse --path-format=absolute --git-path objects).Trim()
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $sourceObjs -PathType Container)) { throw 'SOURCE_OBJECT_STORE_MISSING' }
New-Item -ItemType Directory -Path $target -Force | Out-Null
git -C $target init -q; if ($LASTEXITCODE -ne 0) { throw 'GIT_INIT_FAILED' }
git -C $target config core.autocrlf false; if ($LASTEXITCODE -ne 0) { throw 'GIT_CONFIG_FAILED' }
$altFile=Join-Path $target '.git\objects\info\alternates'
[System.IO.File]::WriteAllText($altFile,(($sourceObjs -replace '\\','/')+[Environment]::NewLine),[System.Text.UTF8Encoding]::new($false))
$kind=(git -C $target cat-file -t $n3).Trim()
if ($LASTEXITCODE -ne 0 -or $kind -ne 'tree') { throw 'N3_TREE_MISSING_SOURCE_REPO_INSPECT_ONCE' }
git -C $target read-tree $n3; if ($LASTEXITCODE -ne 0) { throw 'READ_TREE_FAIL' }
$syn=('Synthetic N3-R1 local base' | git -C $target -c user.name='PicoRadar QA' -c user.email='qa@invalid.example' commit-tree $n3).Trim()
if ($LASTEXITCODE -ne 0 -or !$syn) { throw 'COMMIT_TREE_FAILED' }
git -C $target symbolic-ref HEAD refs/heads/picoradar-c1-isolated
if ($LASTEXITCODE -ne 0) { throw 'SYMBOLIC_REF_FAILED' }
git -C $target update-ref refs/heads/picoradar-c1-isolated $syn
if ($LASTEXITCODE -ne 0) { throw 'UPDATE_REF_FAILED' }
git -C $target checkout-index -a -f; if ($LASTEXITCODE -ne 0) { throw 'CHECKOUT_N3_FAILED' }
git -C $target apply --cached --check $basePatch; if ($LASTEXITCODE -ne 0) { throw 'BASE_PATCH_CHECK_FAILED' }
git -C $target apply --cached $basePatch; if ($LASTEXITCODE -ne 0) { throw 'BASE_PATCH_APPLY_FAILED' }
$integrated=(git -C $target write-tree).Trim()
if ($LASTEXITCODE -ne 0 -or $integrated -ne $integratedExpected) { throw "INTEGRATED_TREE_MISMATCH:$integrated" }
git -C $target checkout-index -a -f; if ($LASTEXITCODE -ne 0) { throw 'MATERIALIZE_INTEGRATED_FAILED' }
git -C $target apply --cached --check $deltaPatch; if ($LASTEXITCODE -ne 0) { throw 'DELTA_PATCH_CHECK_FAILED' }
git -C $target apply --cached $deltaPatch; if ($LASTEXITCODE -ne 0) { throw 'DELTA_PATCH_APPLY_FAILED' }
$final=(git -C $target write-tree).Trim()
if ($LASTEXITCODE -ne 0 -or $final -ne $finalExpected) { throw "R2V2_FINAL_TREE_MISMATCH:$final" }
git -C $target checkout-index -a -f; if ($LASTEXITCODE -ne 0) { throw 'MATERIALIZE_FINAL_FAILED' }
$unstaged=@(git -C $target diff --name-only)
if ($unstaged.Count -gt 0) { throw "INDEX_WORKTREE_MISMATCH:$($unstaged.Count)" }
Write-Output "R2V2_FINAL_RECOVERED TARGET=$target TREE=$final"
```

**Advertencia:** `alternates` permite leer Git desde el origen; este clon todavía no es autónomo. Para un handoff portable devolver un delta nuevo desde `859bb8bb...` si hubo cambios, con hashes e identidad del árbol. No usar `git gc/repack/prune` en el origen.

<!-- CARGA DE SOLO RECUPERACIÓN: no usar si el aislado FINAL de R2 V2 ya está disponible. Validar hash SHA de ambas antes de aplicar. -->

@@BEGIN_R2V2_BASE@@
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
/gVYvWBoEZKAM6IzBIBrIzNkMKw8he7qKhiBd8IJVbguf1Fug4QWTvjdnT9WQK7Lc95KXXCKSAOnApQajNoDMjsW3BgQjV7MChGs6/9EWFLy
zcQYt4gZ5mHgEN9QS60dQljO461EojbBXUahOPD27FJZ0g6ssN4uB1edQsTGDPGEoRx6llqzIifreEtSrox0FdjfG6lkYJe+t9Jz8ekouHy6
2euNx2uX6/3Atmv46nEzhe8LnilP6Hpc+JvfvnpyevTz3vnh8Pjs9O1wb3//8OxsuPf+/PXx6dH/PDx4TiTvgV3q7Pj96f5hXam98/PTo5fv
z4+O3z3/Ad88Y8dzjCtLoyh/G8zJ2yiNLxdwJmU/oE7tH9iZ4fUn7NmsLZWFHVQjUaiyyN9qOobgfSkq7IDuv+hhg6T2wUVSrkDBTHgD8RS/
DFD1Kp51WcDG8PnayA07T+IZaVXQQBzMsDnpNIRprUQ3MvDxchFPQp5N/eRo//h072DvdHh2cvzu7Pj08GC4v/f2ZO/op3dnw8N3ey/fHB7A
8OS74cn7l2+O9qHM+d6b459kCQHVQrGXe2eHw/enb54jB/8PTDgAsHiGM8TkzWOkPBR4EwqYoDH7lgMcttJlhGrJOGM6WrUHi7d3ev7u8HR4
9O6f3x+dHh2eOePwFNg7eHv0Dp5fHv8PpzAi2lPiOfGe9U1CtEJ1Qpf9f+Fz8TX/5s3xH+H57HD//enh8M3x/t4bOZgH7O3e0Zsh/nV4+hyo
PS7PsdLCzudMRafQdWHKQYQDxPETpxUWWRegDO1vFLTIv4/CVUxQPdYLDBvm+P27cxdWxRL2ZCu+/3x4eoZbxlfmkOZc2tXbvdM/HJ4fvftp
eHb47qBJOdmZSpm9451c1ULQkM72Xx++PXxOgVD8zevjs/Pn/fUdvECk1xcvT45Pz5+vb61vlVNEWKwruuPRSxmdr4JCboy3dp5sAYXcfrK9
E4B8U0oh3fpFSumWIL9ropib4kZxi8i5W8T8pvfptySygOb7muwpHOWXW2bs+NUrut2JT0OSxJkmV/+8B1QMa2fRtyBB35ZsVBAJtS98qIM3
tCIDkEyiVYQO7Ods9TQiiu561/DPvfn1XC/9/eoL9NteD4J+1O/1NjbDy+3LTS/63bMHC0Hv2QYd+t0dOPO76ImpnYoqq6pkyuL5AXcrIsYm
59liH2VQi3vwP0fHW3FiD1Le7opwlZN5ApauyL6srIjjeAXdNgcw4jjLFvy+BXVFglBIoSUJUR6/qW2RwYE8ur5rCd8haxBhlI3SmI4MupqL
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
@@END_R2V2_BASE@@

@@BEGIN_R2V2_FINAL_DELTA@@
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
@@END_R2V2_FINAL_DELTA@@
