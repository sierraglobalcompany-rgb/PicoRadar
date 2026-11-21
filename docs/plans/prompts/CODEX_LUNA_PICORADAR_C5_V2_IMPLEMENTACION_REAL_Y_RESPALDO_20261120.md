# CODEX LUNA — PICORADAR C5 V2 · IMPLEMENTACIÓN REAL EN PARALELO, APK Y RESPALDO DE CÓDIGO

**EJECUTOR:** CODEX LUNA. **DIRECTOR:** ChatGPT. **TASK_ID ÚNICO:** `PICORADAR-C5-MUNICIPIOS-ANDROID-GITHUB-20261120` (MISMO ID de C5; V2 sustituye al Markdown C5 original **solo si C5 todavía no ha empezado**). **Corte:** 20/11/2026, `America/Bogota`.

**ORDEN:** Ejecutar, implementar, probar lo afectado, integrar y devolver **UN SOLO ZIP**. Este archivo es autónomo como orden; no requiere leer el C5 anterior, pero usa el candidato C4 ya existente en el computador. **NO abrir C6, NO emitir otra auditoría general, NO pedir que ChatGPT resuelva fallos triviales, NO repetir suites históricas para generar porcentajes.** Codex puede razonar y corregir errores propios dentro de este mismo lote con evidencia verificable.

## 0. Decisión del director y fuente de verdad

El avance bajo C1–C4 fue real pero lento: C3 creó 3 pruebas sin cambiar runtime; C4 finalmente modificó 3 archivos de runtime y 2 de tests, añadió bandeja nacional y UI accesible. **C5 debe producir código funcional nuevo, no solo pruebas, un plan o reportes.** Los dos cambios mínimos obligatorios, salvo bloqueo causal probado, son A (administración de inactivas) y B (ficha informativa móvil de ciudades sin consulta). C (Android) y D (respaldo GitHub) son independientes; si fallan, **A+B continúan**.

Las 6 leyes vigentes: **L1 KISS/cola de caballo** (usar Flutter/Riverpod/Drift y Laravel existentes); **L2 antirruido** (sin servicios, capas ni SDK nuevos por conveniencia); **L3 antiparches** (causa→corrección definitiva→test); **L4 diseño humano y accesible**; **L5 evidencia independiente y sin PASS supuesto**; **L6 antiping-pong** (un macrobloque, cerrar fallos del propio bloque, un ZIP de retorno). Aplican las instrucciones superiores de `AGENTS.md`, los documentos de cierre/arquitectura/privacidad, flujos y contratos vigentes. Barra exacta `Inicio · Garaje · Apps · Viaje · Conducir`, Apps centro, la app funciona sin cuenta, nunca subir GPS continuo al servidor, anuncios/pagos/premium OFF en Free 1.0. **UNKNOWN/STALE/PARTIAL no son ALLOWED**; inactividad administrativa no prueba ausencia legal de restricción.

**Base verificada por Director a partir del ZIP C4:**
- `PICORADAR_C4_RETORNO_UNICO.zip`: SHA-256 `538a346a80d0be69b116de95155f02a718483b9d0116874a897d93426aeb65de`, 22 miembros, 21 manifiesto, CRC correcto.
- C4 commit `b63a2b743f855b7983c516c51bd4803b0078b192`; tree `afdee2ece960ef2c462393cbd3b2aaa3b0c974ca`.
- Bundle C4 `PICORADAR_C4_SOURCE.bundle` SHA-256 `6a0254d3c316a940f594d1a0d1dea6e9ab1ef5b72c38834c421034d4a4ec6061` (clonado anteriormente sin alternates, tree idéntico).
- Fuente Windows prevista: `D:\codex\_REPORTES\PicoRadar\C4-20261120\PICORADAR_C4_RETORNO_UNICO.zip`. Trabajar bajo `D:\codex\_isolated\`, nunca sobre el checkout operativo protegido.
- Checkout operativo protegido: HEAD `182a8821bba688b28a6e223a1e956df748f7948b`; 43 WIP (18 M, 25 ??). No hacer `reset`, `clean`, checkout, borrar junction `server/vendor` ni copiar una build sobre él. Tomar hashes WIP antes/después en modo solo lectura y comparar 43/43 cuando sea accesible.
- C4 PHP 3 tests/42 aserciones PASS, widget Flutter 3 PASS; C3 editor HTTP/roles, Drift 10→11 y offline de componente PASS; C2 puente HTTP local PASS; anteriores 3.365 Flutter PASS (+11 skipped), PHP focal C1 53 PASS/592 aserciones. **No reejecutarlos por inercia**.
- `QA_SCORE_C4=60.5/100`, según rúbrica C4, **no porcentaje de producto terminado**; `DEVELOPMENT_PCT=NO_MEDIBLE`, estimación heredada 58 % NO validada; `LEGAL_COVERAGE_NATIONAL=NO_MEDIBLE`.
- Estado: `RELEASE=NO_GO`, `GITHUB_CODE=HOLD_NOT_PUSHED`, PR #79 documental `OPEN/DRAFT` base `recovery/20261019-modern`. No usar `main` remoto como sustituto del candidato C4 ni usar `--allow-unrelated-histories` para unirlo.

## 1. Inicio operativo mínimo: 5 comprobaciones, no otro preflight

1. Localizar candidato C4 aislado y leer `git rev-parse HEAD`, `git rev-parse 'HEAD^{tree}'`, `git status --porcelain=v1` y comprobar `mobile/pubspec.yaml`. Si coincide con commit/tree arriba, usarlo. Si no existe, restaurar **una sola vez** desde el bundle C4 del ZIP de SHA conocido hacia nueva carpeta `D:\codex\_isolated\PICORADAR-C5-V2\`. No reconstruir N3/N4/N5 ni buscar ZIPs históricos.
2. Definir ruta explícita de `server/` y `mobile/` desde `git rev-parse --show-toplevel`; comprobar archivo Gradle `mobile/android/app/build.gradle.kts`, sin suponer nombres de worktree o flavor. Capturar SHA de entrada.
3. Verificar que el candidato aislado está limpio frente al commit C4. Si hay cambios ajenos, preservarlos, inventariar y crear otro worktree aislado: **nunca descartarlos**.
4. Una lectura de `AGENTS.md`/contratos **de los archivos afectados**, sin repetir auditorías extensas. GitHub se consulta **una vez para HEAD/PR #79**; si otra sesión hizo cambios, integrar explícitamente esa diferencia, no sobreescribir.
5. Los agentes tienen tareas precisas. No crear otra matriz de fallos genérica ni revisar el proyecto completo antes de editar.

## 2. Paralelismo seguro con progreso verificable

**Codex Luna** mantiene el índice final, commits, integraciones, gates y el único ZIP. Cuando haya disponibilidad, abrir **dos subagentes de escritura en worktrees distintos**, ambos desde **C4 commit exacto**: A cambia solo `server/**`; B cambia solo `mobile/**`. Una ayuda opcional **solo lectura** puede clasificar seguridad, comparar GitHub y preparar instrucciones Android. Nunca dos escritores en el mismo worktree ni compilar simultáneamente; integrar A y B mediante commits/diffs causales, revisando rutas y sin sobrescribir. Si no hay subagentes, ejecutar A y B secuencialmente **sin reducir entregables**. Durante Android detener runners/agentes pesados para liberar memoria. Registrar qué agente hizo cada cambio, pruebas y commit.

**Orden práctico:** iniciar A/B; en paralelo el integrador prepara D solo lectura. Integrar A/B, ejecutar tests afectados, completar D, y finalmente C (Android) desde la raíz correcta con RAM suficiente. Si C queda bloqueado por entorno, **no volver a paralizar producto**.

## 3. A — Laravel / Super Admin / editor nacional: inactivas visibles sin publicación accidental

**Defecto real inspeccionado por Director en el árbol C4:**
- `server/app/Http/Controllers/Admin/RestrictionRuleController.php`, método `index()`, aprox. línea 43: `Jurisdiction::query()->where('enabled', true)`; la bandeja excluye toda jurisdicción inactiva aun para administradores.
- `server/resources/views/admin/restrictions/index.blade.php` tiene cuatro filtros (`q`, `department`, `vehicle_kind`, `availability`) y paginación posterior a filtros sobre las coberturas.
- El formulario `server/resources/views/admin/restrictions/form.blade.php` explica correctamente que `Jurisdiction.enabled` controla administración territorial y **no cambia el dataset publicado**. Los métodos `create`/`store` imponen otros controles `enabled=true`: **NO retirar esas restricciones en bloque, NO abrir escritura/publicación de inactivas automáticamente**.

**Implementación requerida, sin servicio nuevo:**
1. Introducir filtro de gestión `active | inactive | all` (aceptar solo esos 3 valores; default **active** por retrocompatibilidad) en `index()` y selector accesible en `index.blade.php`; conservar búsqueda, departamento, vehículo, cobertura, página, total de resultados y querystring. `inactive` significa inventario administrativo **solo lectura** en este bloque, no activar consulta ni permitir publicar. Reutilizar autorizaciones existentes; no crear endpoints públicos.
2. Mostrar etiqueta claramente separada para inactividad de gestión y estado de cobertura. Una jurisdicción puede estar inactiva y tener versión histórica: no cambiar publicación en base de datos. Si falta versión/fecha/fuente, mostrar `UNKNOWN` o «Sin cobertura verificada», **nunca «sin pico y placa» ni ALLOWED**. No confundir `enabled` con el contrato `consultation_enabled` del release.
3. No mostrar para inactivas acciones que abran borradores, edición, validación o publicación **si el contrato actual lo prohíbe**. Lectura autorizada, consulta de historia y fuentes existentes sí; roles `@can` deben seguir siendo efectivos. Si un método GET muta registros, es un bug causal a corregir aquí; si no, no reescribir rutas.
4. **Pruebas causales HTTP** (mínimo): con fixtures sintéticos, filtro default active intacto; inactive/all localizan la inactiva; combinación con búsqueda, tipo y estado produce total/paginación consistentes; usuario de lectura no ejecuta mutaciones; diff de publicación/manifest/release antes/después nulo en solo lectura. Ejecutar PHP lint, Pint y pruebas *tocadas*, no la suite completa.

**Resultado A:** 1–2 archivos runtime PHP/Blade modificados de manera razonable, test HTTP ejecutado y salida `PASS_A` solo si el render, filtrado, roles y no-mutación se comprobaron. Si ya estuviera implementado integralmente por otra sesión, registrar SHA y resolver un fallo igualmente real y acotado de *ese mismo flujo*, sin sustituirlo por documentación o repetir QA.

## 4. B — Flutter nacional: ficha informativa de municipios sin datos consultables

**Defecto real inspeccionado por Director en el árbol C4:** `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart`, `_CitySelectorList` (aprox. líneas 743–784) separa `available` / `upcoming`; `_PicoCatalogCityTile` (aprox. 848 y 878) marca `Próximamente`, `enabled: available`, `onTap: available ? ... : null`. El catálogo nacional incluye ciudades no consultables **pero el usuario no puede abrir una explicación accesible sobre ellas**.

**Implementación requerida (reutilizar pantalla, no crear motor/endpoint):**
1. Una ciudad sin dataset habilitado debe ofrecer una acción accesible («Ver estado» / pulsar fila informativa) para consultar **solo información verificable**: ciudad/departamento, consulta no disponible y qué significa. Mostrar exactamente «No hay información verificada para determinar si tiene restricción» o texto equivalente cuando el contrato no distinga ausencia legal confirmada. Solo decir «sin restricción confirmada» cuando haya fuente oficial primaria, jurisdicción, categoría, fecha/vigencia y contrato explícito; de lo contrario mantener `UNKNOWN`. Nunca tratar `upcoming`, `engineEnabled=false`, `STALE` o catálogo vacío como `ALLOWED`.
2. La ficha informativa **no debe cerrar el selector devolviendo ID de ciudad activa**, cambiar la jurisdicción guardada, vehículos, preferencias, token, Drift ni last-good, ni iniciar HTTP/GPS. Mantener selección/navegación existentes de ciudades disponibles. Reutilizar widgets, componentes, `Semantics`, tema y providers actuales; si se abre modal, cerrar solo ese modal y preservar selector.
3. No crear un `PicoDetailScreen` alternativo, duplicar proveedor, agregar SDK o editar reglas del motor. Mantener municipios, categorías y acceso sin cuenta. Texto humano legible a pantalla pequeña y lectores de pantalla.
4. **2–4 widget tests nuevos causales:** tocar municipio no consultable abre explicación y no devuelve selección; una ciudad disponible conserva selección; `UNKNOWN` y `STALE` no se anuncian permitidos; render no hace HTTP. Usar datos sintéticos marcados y ejecutar `dart format`, `flutter analyze --no-pub` focal y tests afectados. No correr 3.365 tests ni rehacer Drift v10→v11.

**Resultado B:** código de producción Dart modificado, UI verificable y tests ejecutados; pantallas offline simuladas siguen marcadas **COMPONENT**, no DEVICE.

## 5. C — Android DEV: build real desde la carpeta correcta (no un bucle de cachés)

C4 tuvo **9,28 GiB libres**, pero el intento falló ANTES de Gradle (`No pubspec.yaml file found`): fue una **invocación fuera de `mobile/`**. La falla Kotlin incremental C3 era distinta y no quedó reproducida en C4. `objective_c`/`sqlite3` ya se resolvieron en los gates locales previos. No cambiar dependencias, firmados ni gradle por especulación.

**Preflight operativo sin contar como build:** ejecutar desde el **candidato aislado C5 integrado**, no checkout fuente; localizar con `git rev-parse --show-toplevel`; `Test-Path` de `mobile/pubspec.yaml` y `mobile/android/app/build.gradle.kts`; resolver `$flutterBat` a un ejecutable **real** (`flutter.bat` en PATH o ubicación validada; `Get-Command flutter.bat`, `Test-Path`); comprobar `flutter --version` y `--flavor dev` de `build.gradle.kts`, lock/dependencias locales y RAM libre **>=6 GiB**. Si faltan, registrar `BLOCKED_ENV` sin empezar Gradle ni gastar un intento; no instalar descargas.

**Invocación recomendada en PowerShell** (el integrador debe establecer `$flutterBat` después de verificarlo):

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$mobileRoot = Join-Path $repoRoot 'mobile'
if (-not (Test-Path -LiteralPath (Join-Path $mobileRoot 'pubspec.yaml'))) { throw 'ROOT_FLUTTER_INVALID' }
if (-not (Test-Path -LiteralPath (Join-Path $mobileRoot 'android\app\build.gradle.kts'))) { throw 'ROOT_ANDROID_INVALID' }
if ([string]::IsNullOrWhiteSpace($flutterBat) -or -not (Test-Path -LiteralPath $flutterBat)) { throw 'FLUTTER_EXECUTABLE_NOT_VERIFIED' }
Push-Location $mobileRoot
try {
    Write-Output ('BUILD_CWD=' + (Get-Location).Path)
    & $flutterBat build apk --flavor dev --debug --no-pub
    $code = $LASTEXITCODE
} finally { Pop-Location }
if ($code -ne 0) { throw ('ANDROID_BUILD_FAILED_EXIT_' + $code) }
```

**Una compilación auténtica.** Segundo intento solo si primero llegó efectivamente a Gradle, existe causa verificable solucionable, memoria suficiente y se hace **un cambio acotado**. Si `:android_file_picker:compileDebugKotlin` confirma error de cachés incrementales C:/D:, usar `kotlin.incremental=false` temporalmente en configuración correcta, respaldando/restaurando `gradle.properties` con SHA byte a byte; no borrar caches globales ni subir propiedades efímeras al commit. No construir simultáneamente con tests o subagentes pesados.

`PASS_APK` requiere `exit 0`, archivo APK físicamente presente en outputs, hash SHA-256, tamaño y appId/flavor/firma comprobados; **no inventar ruta o firma**. Mi A3: como mínimo ADB lectura si está autorizado; **sin instalación** si certificado distinto, sin desinstalación ni pérdida de datos. `QA_FISICA=NOT_RUN` hasta probar en dispositivo; HTTPS/OTA real siguen independientes.

## 6. D — respaldar fuentes de C5 y acercar GitHub a la realidad sin exponer historia

**Problema aún abierto:** el proyecto recuperado es un árbol Git **de ascendencia sintética**, no un commit descendiente de `main`. Subir solo prompts no actualiza el código. Repo `sierraglobalcompany-rgb/PicoRadar`, `main` visto por Director con HEAD histórico `e9ef37511df3110ffb0fc006ef06be781df432ac`, **dato de corte sujeto a nueva lectura**, PR #79 documental DRAFT con base distinta. **Jamás** force-push, fusionar historias no relacionadas, sustituir `main` ni alterar PR #79.

D debe actuar de forma práctica, no producir un informe de 20 páginas:
1. Integrar commits A+B en **candidato C5** y fijar `FINAL_COMMIT`, `FINAL_TREE`, `git diff C4..C5 --stat` y hashes de runtime. Confirmar que los archivos del bundle C4 usados son la fuente real y que cada cambio nuevo está incluido; no usar objetos ajenos ni alternates.
2. Construir **un solo respaldo autónomo del C5 completo**, preferentemente snapshot `SOURCE_ONLY` de archivos necesarios para reconstruir app/servidor/tests/scripts, con manifiesto SHA256 individual, exclusiones de `.git`, WIP privado, `.env` real, certificados, llaves, paquetes `vendor`, caches, binarios de build e información privada. `git archive` o una selección basada en `git ls-files` es aceptable **solo tras verificar que sus archivos rastreados son seguros**; si excluye archivos necesarios, registrarlos y reparar respaldo, no afirmar full restore. No depender de C4 bundle para recuperar C5. Un Git bundle histórico **solo** si escaneo de secretos de todo historial accesible resulta realmente completo/seguro; si no, entregar snapshot source-only sin historia sintética.
3. Rehacer **una sola prueba de restauración C5** en carpeta vacía y sin red. Comparar SHA de todos los archivos incluidos, listado de rutas fuente, `mobile/pubspec.yaml`, servidor Laravel y los cambios A/B. Si se conserva Git tree exacto, acreditarlo; si es snapshot filtrado, reportar paridad exacta de fuentes **en vez de inventar el mismo Git tree**. ZIP final incluye respaldo y manifiesto sin ZIP anidado.
4. **GitHub código real:** consultar estado de origen una sola vez. Usar `gitleaks`/`detect-secrets` gratuito si hay uno instalado, más revisión específica de las rutas de credenciales/privacidad; no imprimir valores. Una heurística sin scanner es `SCOPED_HEURISTIC_ONLY`, **no aprobación para subir historial**. Solo si árbol fuente actual está libre de secretos y no hay un riesgo pendiente: intentar UNA publicación a una **rama nueva no productiva** con snapshot *source-only de historia limpia*; registrar commit/branch remoto confirmado. El historial sintético no se sube como comodidad. No convertirlo en PR hacia main sin puente de reconciliación comprobado. Si el remoto niega acceso 403/auth, o la seguridad permanece indeterminada, `GITHUB_CODE=HOLD_NOT_PUSHED` y respaldo en ZIP; no repetir push indefinidamente. Jamás publicar tokens/APKs, ni contenido privado por accidente.
5. `MERGE_GAP.md` breve: rutas que difieren con main, base ajena, estrategia **sin merge automático** para integrar después de seguridad, y siguiente paso concreto. Separar `GITHUB_DOCS`, `GITHUB_CODE`, `RELEASE`. **No permitir que falta de push bloquee el cierre A+B.**

## 7. QA proporcional y salida real

**Solo pruebas directas del código modificado.** Backend: control de filtro, paginación y rol + no mutación en GET; frontend: estados y selección, no red. Ejecutar `php -l`, Pint focal, Flutter format/analyze y tests focales. Si falla A/B, Codex diagnostica y corrige dentro de C5; máximo dos correcciones causales por fallo, explicar límite si no pasa. No pasar resultados históricos como nuevas pruebas. No ampliar editor/ads/Super Admin con nuevos subsistemas si la función ya existe. Publicidad Free 1.0 y aliados **OFF/fail-closed**: conservar y comprobar flags por lectura; un cambio runtime de campaña solo si hay bug reproducible y A/B ya cerraron.

**Interpretación del progreso:**
- `SCORECARD_C4=60.5/100` (rúbrica de verificación; NO confundir con % desarrollado). Calcular C5 con **exactamente las mismas ponderaciones**, con números por criterio, test/evidencia y delta justificado. **No regalar puntos A si editor ya estaba 12/12, ni subir cobertura legal sin fuente oficial, ni asignar 5/5 de Android solo por compilar sin teléfono**.
- `PRODUCT_DEV_PERCENT=NO_MEDIBLE` hasta validar denominador de funciones globales; 58% solo estimación histórica sin actualización certificada. `LEGAL_COVERAGE_PERCENT=NO_MEDIBLE` hasta tener denominador y registros oficiales. Proporcionar indicador adicional **Flujos C5 A+B: 0/2, 1/2 o 2/2** demostrados, independiente del score.
- Para acercarse a 100% real tras C5: primero asegurar rama código/restore y APK DEV, después HTTPS/OTA real+Drift offline en dispositivo, QA Mi A3 con firma/datos intactos, cobertura nacional editorial validada municipio/categoría/fuente, seguridad y release Free 1.0. Publicidad/premium se planifican sin activarse antes de Free 1.0. No proclamar terminación ni publicación por un mock.

## 8. Retorno exigido: UN SOLO ZIP adjuntable

`D:\codex\_REPORTES\PicoRadar\C5-20261120\PICORADAR_C5_RETORNO_UNICO.zip`, **único entregable**. Debe incluir:

- `FINAL_REPORT.md`: alcance A/B/C/D, EXACTOS archivos runtime, resultados, bloqueos y `NEXT=CHATGPT_DIRECTOR`; no adjuntar la respuesta como 12 enlaces dispersos.
- `GATES.csv`: cada gate y su evidencia trazable; `FEATURES_BEFORE_AFTER.csv` con A+B antes/después y nuevos commits; `SCORECARD_BEFORE_AFTER.csv` con pesos C4, sin manipular 58% ni 60.5 inicial.
- `QA/php_focal.log`, `QA/flutter_focal.log`, `QA/android_build.log` **solo los realmente ejecutados** y stderr/códigos de salida. Test negativo necesario donde haya incertidumbre de permisos/UNKNOWN; una captura sintética es `PASS_WIDGET` y no `PASS_DEVICE`.
- **`C5_SOURCE_RECOVERY.tar.gz` o `.bundle`**, completo y sanitizado, `SOURCE_MANIFEST.csv`, `RECONSTRUCTION_C5.md`; verificación desde carpeta vacía con hashes, sin dependencia externa. Evitar bundle histórico no escaneado; no incluir `.env` privados ni secretos.
- `GITHUB_CODE_STATUS.md` con SHA remoto real y rama **solo si existe**, o HOLD y causa; `SECURITY_GATE.md` sin valores sensibles; `MERGE_GAP.md` conciso; `WIP_BEFORE_AFTER.csv` con SHA/bytes de las 43 rutas protegidas o `NOT_VERIFIED` si inaccesibles.
- `MANIFEST.csv` enumerando **cada otro miembro** con ruta relativa, tamaño, SHA-256 y CRC32, y validación de CRC central de todos. SHA-256 del ZIP externo, una sola carpeta bajo reportes, sin otros ZIPs anidados.

**Reporte de Codex al usuario:** cuatro párrafos máximo: A/B runtime y tests, C APK/bloqueo, D respaldo/GitHub/seguridad, ruta+SHA del ZIP, `NEXT=CHATGPT_DIRECTOR`. Si no se pudo implementar, decir exactamente qué archivo/call/test falló, qué sí quedó terminado y no inventar porcentaje.

## 9. Auditoría diferencial del Director — NO son tareas para Codex

**10 pasadas como VERDUGO:**
1. El filtro `enabled=true` oculta municipios: A corrige exclusivamente lectura administrativa.
2. Retirar `enabled` de todos los flujos abriría publicación: A preserva restricciones create/store/publish.
3. Confundir municipio inactivo con sin pico y placa engaña al usuario: contrato UNKNOWN obligatorio.
4. Un filtro de ciudad sin paginación coherente falsea resultados: prueba conteo combinado.
5. Un `ListTile(enabled:false)` impide información al lector: B añade interacción accesible sin selección.
6. Reutilizar `Navigator.pop(id)` para una ciudad sin dato la activa implícitamente: B lo prohíbe.
7. Repetir 3.365 tests y 53 PHP oculta avance de runtime: tests focales solamente.
8. Ejecutar Flutter fuera de `mobile/` quemó un build sin Gradle: preflight verifica raíz y ejecutable.
9. Publicar historia sintética en GitHub público puede filtrar datos: D prefiere fuentes limpias y HOLD seguro.
10. Score 60.5 no equivale a % terminado, y editor ya está al techo: métrica separada sin puntos regalados.

**10 pasadas como JUEZ:**
1. Conservar `active` por defecto protege la UI previa.
2. `inactive/all` como filtros GET sin mutación atienden al Super Admin con cambio mínimo.
3. Separar «gestión» de «cobertura» mantiene lógica legal consistente.
4. Reusar `RestrictionRuleController` y Blade evita duplicados.
5. Reusar selector y componentes Flutter evita otra navegación nacional.
6. Mostrar incertidumbre informativa sin red ni cuenta conserva privacidad y last-good.
7. Dos worktrees y un integrador permiten paralelismo sin colisiones.
8. Build solo con preflight y >=6 GiB separa entornos de defectos de código.
9. Respaldar fuentes C5 enteras sin historia riesgosa protege continuidad del chat.
10. GitHub solo rama no productiva con seguridad verificada y score constante evita falsos PASS.

**Resultado aprobado del Director:** ejecutar C5 V2 completo, cerrar A+B con cambios runtime, intento C real y respaldo D. **No abrir otra ronda de auditoría para ordenar el trabajo que ya está definido.**

# 🔴🔴🔴 QUIÉN SIGUE: CODEX LUNA — EJECUTAR C5 V2 Y ENTREGAR UN ZIP ÚNICO 🔴🔴🔴

**DESPUÉS DEL ZIP C5 SIGUE: CHATGPT DIRECTOR.**
