# CODEX LUNA — PICORADAR C5 · MACROBLOQUE DE CIERRE FUNCIONAL NACIONAL + APK DEV + RESPALDO GITHUB

**ORDEN DE EJECUCIÓN PARA CODEX LUNA. DIRECTOR: CHATGPT.** Fecha de corte: 20 de noviembre de 2026, Colombia. `TASK_ID=PICORADAR-C5-MUNICIPIOS-ANDROID-GITHUB-20261120`. **Este archivo sustituye instrucciones previas de C5 si las hubiera. Ejecutar un solo C5.** No abrir otro ciclo de auditorías, un preflight nuevo ni otro lote para arreglar un error trivial ya identificado.

## 1. Objetivo medible y reglas de operación

Entregar una evolución real del código C4: **(A)** administración completa y segura de jurisdicciones deshabilitadas/sin cobertura en el panel nacional; **(B)** consulta informativa de ciudades sin cobertura desde Flutter sin transformar `UNKNOWN` en `ALLOWED`; **(C)** APK DEV desde la raíz Flutter verdadera si el entorno lo permite; **(D)** respaldo de código reproducible y sincronización de GitHub solo cuando sea segura. Trabajar sobre los componentes existentes, no crear subsistemas nuevos.

**No prometer 100 % nacional/legal ni aumentar el 58 % histórico o 60,5/100 de evidencia por producir documentos.** La medida de avance es: runtime realmente modificado y demostrado, experiencia funcional, APK real y código respaldado. No reconstruir ni ejecutar de nuevo suites globales porque C4/anteriores ya quedaron acreditados.

Leyes inmutables: (1) KISS/monolito Flutter+Riverpod+Drift y Laravel; (2) cero ruido/clases/servicios especulativos; (3) no parches inconexos; (4) diseño humano accesible; (5) verificación independiente y sin falsos positivos; (6) antiping-pong, bloque grande, un ZIP y un integrador. Mandan `AGENTS.md`, los documentos de cierre/arquitectura, privacidad y contratos existentes. Mantener exactamente `Inicio · Garaje · Apps · Viaje · Conducir`, **Apps en el centro**, uso sin cuenta, anuncios/pagos/premium OFF en Free 1.0 y ningún GPS continuo hacia el servidor. No modificar reglas jurídicas sin fuente oficial ni simular validez territorial.

**Autoridad por fuente:** La evidencia C4 del ZIP y del árbol local vale para C4; los testimonios de tests sintéticos no equivalen a pruebas físicas. `main` de GitHub es histórico y NO sustituye al candidato moderno. Antes de cualquier push verificar rama, diff completo, secretos y relación de ascendencia; está prohibido mezclar por fuerza, cerrar/alterar PR #79 o publicar en producción.

## 2. Base exacta aceptada: NO reauditar

Fuente: `PICORADAR_C4_RETORNO_UNICO.zip` en `D:\codex\_REPORTES\PicoRadar\C4-20261120\` o la carpeta de trabajo C4 ya existente en `D:\codex\_isolated\PICORADAR-C4-20261120\`. Usar el candidato C4 existente **primero**; si no está, restaurar una sola vez desde el bundle `PICORADAR_C4_SOURCE.bundle` incluido en el ZIP C4. No exigir antiguos ZIPs N4/N5; no volver a reconstruir N3 salvo ausencia comprobada del candidato y del bundle.

- ZIP C4 SHA-256: `538a346a80d0be69b116de95155f02a718483b9d0116874a897d93426aeb65de`. Contiene 22 entradas, 21 con SHA/CRC del manifiesto.
- Commit C4 integrado `b63a2b743f855b7983c516c51bd4803b0078b192`, tree `afdee2ece960ef2c462393cbd3b2aaa3b0c974ca`. Padres históricos sintéticos; no suponer ancestro de GitHub `main`.
- Bundle SHA-256 `6a0254d3c316a940f594d1a0d1dea6e9ab1ef5b72c38834c421034d4a4ec6061`. Ya se comprobó clonación en carpeta vacía y árbol exacto; NO repetirla a menos que sea estrictamente necesaria para recuperar fuentes.
- C4: 3 runtime paths nuevos, 2 tests; Laravel 3 tests/42 assertions PASS; Flutter analyze focal y 3 widget tests PASS. C3 editor/roles, Drift v10→v11, offline componente, campañas OFF PASARON; C2 puente HTTP local PASÓ. No repetir para generar otro reporte.
- C4 WIP origen: HEAD protegido `182a8821bba688b28a6e223a1e956df748f7948b`, 43 entradas 18 modificadas/25 untracked, fingerprints preservados. C5 no puede borrar, limpiar, resetear ni escribir en ese checkout. Prohibido limpiar junction ignorada `server/vendor` o borrar paths del árbol operativo. Candidato de integración debe estar aislado.
- Android: C4 midió 9,28 GiB libres. El error **`No pubspec.yaml file found`** sucedió ANTES de Gradle por directorio equivocado. Es fallo de invocación y NO evidencia de falla Kotlin. No volver a investigar `objective_c`/`sqlite3` que ya pasaron.
- `GITHUB_PRODUCT=HOLD_NOT_PUSHED`, `RELEASE=NO_GO`; `PR #79` sigue draft y contiene otra base. C4 no incluyó fuentes jurídicas nuevas. Score de evidencia C4 `60,5/100`; producto y cobertura legal nacional no medibles.

**Comprobación mínima de base:** `git rev-parse HEAD HEAD^{tree}`, `git status --porcelain` y existencia de `mobile/pubspec.yaml` desde el root; comparar con C4. Si no coincide, NO inventar otra base ni seguir sobre el checkout protegido: recuperar mediante el bundle, una vez. Dejar huella de SHA de la entrada en `REPORT.md`.

## 3. Organización: implementación paralela sin competir por memoria

Codex Luna es **único integrador y dueño de branch/index/ZIP**. Puede repartir en **dos subagentes de escritura** en worktrees independientes: A solo `server/**`, B solo `mobile/**`. Máximo un tercero de **lectura** para comprobaciones de seguridad/GitHub. Nunca dar acceso de escritura concurrente al mismo worktree. El integrador aplica cambios y ejecuta las pruebas cruzadas después de integrar ambos frentes; sin subagentes, hacer A/B secuencialmente con el mismo alcance. **Durante el build Android, detener subagentes, PHP y test runners** para liberar RAM. Evitar ejecutores/paralelismo ficticios: registrar agentes disponibles y quién hizo cada cambio.

## 4. Frente A — nacional Laravel: ciudades y coberturas sin ocultarlas

**Brecha específica constatada en C4:** `server/app/Http/Controllers/Admin/RestrictionRuleController.php` contiene `Jurisdiction::query()->where('enabled', true)` en el listado de restricciones. La propia vista `server/resources/views/admin/restrictions/form.blade.php` explica que `Jurisdiction.enabled` controla gestión territorial, **no la publicación del dataset**. Eso puede ocultar del editor nacional municipios deshabilitados que deben quedar inventariados, distinguibles de `UNKNOWN`, `STALE`, `PARTIAL` y de una ausencia **oficialmente confirmada** de restricción.

**Implementar sobre controller/vista/servicios existentes:**

1. Agregar al listado administrativo una elección visible y limitada `gestión: activas / inactivas / todas` (default conservador actual: activas) para operadores autorizados. Una jurisdicción inactiva debe poder encontrarse sin habilitar la consulta ni crear o publicar una regla. Respetar búsqueda, departamento, categoría, paginación actual, roles y límites de consulta; no duplicar repositorio de datos, no introducir migraciones ni nuevos endpoints públicos si no hacen falta.
2. La tarjeta/fila debe diferenciar **INACTIVA PARA GESTIÓN**, **SIN COBERTURA VALIDADA**, `UNKNOWN`, `PARTIAL`, `STALE` y **confirmación editorial de ausencia de restricción** solo si tal contrato ya existe y la fuente lo sustenta. Jamás escribir `ALLOWED` por falta de reglas o por `enabled=false`. No confundir `coverageCompleteness` con vigencia o publicación.
3. Conservar acciones permitidas `@can` y errores de autorización; un lector no puede editar/aprobar/publicar. Enlaces a las acciones editoriales ya existentes, **sin endpoints duplicados ni mutaciones de publicación en GET**. Asegurar que el filtro paginado no salte resultados ni confunda el total al combinar `vehicle_kind` y `availability`.
4. Probar focalmente: (i) jurisdicción inactiva visible al seleccionar el filtro, (ii) ausencia de publicación y etiqueta de incertidumbre, (iii) rol sin permiso sin acciones, (iv) total/paginación de ambos filtros; comparar estado de manifest y release antes/después. Si alguna de estas capacidades ya está implementada en el C4 real, demostrarlo y **sustituir solo ese subobjetivo** por un defecto funcional reproducible del mismo flujo (no agregar más informes o pruebas sin runtime).

**No rehacer creación/edición/importación/validación/publicación/rollback**: en el árbol C4 ya existen en `RestrictionRuleController`, `RestrictionFormPayloadBuilder` y `RestrictionPublicationService`; C3 pasó la ruta HTTP y permisos. Pares schema2 `car/private`, `car/taxi`, `car/special`, `motorcycle/private`, `truck/private`, `truck/public_cargo`, `bus/public_passenger`, `bus/special`, `motocarro/private` ya figuran en form y validador; **NO crear otra taxonomía ni inflar cobertura jurídica**.

Resultado mínimo A: **diferencia de código PHP/Blade** y test causal HTTP PASS (nuevo o modificación de test pertinente), sin secretos ni datos sensibles, sin warnings de PHP persistentes y sin alterar estado publicado indebidamente.

## 5. Frente B — Flutter: ciudades sin consulta, con explicación real y sin permiso implícito

**Brecha específica constatada en C4:** `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart` contiene un selector que divide ciudades `available`/no disponibles; para las segundas usa «Próximamente» y `onTap: available ? ... : null`. La aplicación debe **mostrar municipios sin restricción o sin cobertura como estado explícito**, pero nunca afirmar que se puede circular sin fuente y fecha verificadas.

1. Sin modificar el motor nacional, permitir al usuario consultar una **ficha informativa de ciudad no disponible** desde el selector mediante acción accesible `Ver estado` o equivalente (sin convertirla en ciudad activa si la selección actual presupone dataset válido). La ficha explica en términos humanos si «consulta no disponible», `UNKNOWN` o «sin restricción confirmada», solamente si el contrato versionado realmente puede distinguirlo; de lo contrario decir «No hay información verificada para determinar si tiene restricción». Mostrar fuente/fecha SOLO cuando existan en datos válidos, sin fabricar URL, vigencia o normatividad.
2. Conservar la lista nacional, categorías/tipos (particulares/motos/taxis/carga/servicio público cuando existan) y el acceso sin cuenta. Al consultar la ficha **no iniciar HTTP ni GPS**, ni alterar vehículo, ciudad guardada, token, historial, Drift ni dataset last-good. No desactivar ciudades activas ni crear una ruta duplicada de Pico y Placa.
3. Reutilizar `pico_detail_screen.dart`, `city_pico_widgets.dart`, providers/contratos existentes. Añadir 2–4 widget tests estrictamente causales: ciudad deshabilitada accesible y anuncio correcto, sin mutación de selección; ciudad con datos válidos conserva navegación; `UNKNOWN` o `STALE` NO se anuncian `ALLOWED`. Test de render sin network. Si detecta que la función ya existe íntegramente, comprobar y escoger un defecto de **la misma ruta** de consulta nacional que impida el uso humano, con runtime y prueba; no rediseñar interfaz ni motor.
4. No tocar `pubspec.lock`, paquetes ni Drift salvo que un bug material comprobado lo exija y se agregue migración + prueba. Proteger barra inferior exacta y semántica accesible de C4. Campañas/aliados permanecen desactivados según Free 1.0: no introducir SDK de publicidad ni pantallas de compra. Comprobar smoke focal de flags OFF sin volver a ejecutar toda la suite comercial.

Resultado mínimo B: **código runtime Flutter funcional**, widget test PASS y evidencia de estado informado sin depender de cuenta/red. No repetir solo capturas sintéticas de C4 como si fueran funcionalidad nueva.

## 6. Frente C — Android: corregir causa real; ninguna repetición del error de carpeta

Ejecutar después de integrar A y B en candidato aislado (o antes de ellos si el único bloqueo es la máquina, pero NO dos builds concurrentes). El fallo C4 fue un error operativo, no de producto: Flutter se llamó fuera de `mobile/`.

**Preflight sin contar como intento de compilación:** obtener `$repoRoot = (git rev-parse --show-toplevel).Trim()` desde el candidato C5; `$mobileRoot = Join-Path $repoRoot 'mobile'`; comprobar `Test-Path (Join-Path $mobileRoot 'pubspec.yaml')`, `Test-Path (Join-Path $mobileRoot 'android\app\build.gradle.kts')`, flavor `dev` en ese Gradle y ubicación real de Flutter 3.47.1/Dart. Si falla una ruta, corregir `Set-Location`/SDK ANTES de ejecutar build; no quemar un intento por una invocación evidentemente incorrecta. Consultar RAM libre antes de compilar; mínimo **6 GiB libres**, y ningún PHP/Flutter test runner simultáneo.

Ejemplo obligatorio de contexto (ajustar `$flutterBat` al SDK local ya encontrado, sin descargar):

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$mobileRoot = Join-Path $repoRoot 'mobile'
if (-not (Test-Path (Join-Path $mobileRoot 'pubspec.yaml'))) { throw 'ROOT_FLUTTER_INVALID: falta mobile/pubspec.yaml' }
if (-not (Test-Path (Join-Path $mobileRoot 'android\app\build.gradle.kts'))) { throw 'ROOT_ANDROID_INVALID' }
Push-Location $mobileRoot
try {
  Write-Output ('BUILD_CWD=' + (Get-Location).Path)
  & $flutterBat build apk --flavor dev --debug --no-pub
  $buildExit = $LASTEXITCODE
} finally { Pop-Location }
```

**`$flutterBat` debe apuntar a un ejecutable verificado y es responsabilidad de Codex definirlo explícitamente antes.** `--no-pub` solo si las dependencias locales están resueltas/lock validado; no conectar a Internet para cambiar paquetes. Guardar stdout/stderr y código real. Un build real autorizado; **un segundo intento** solo si el primero llegó a Gradle, hay un diagnóstico inequívoco, cambio acotado y RAM suficiente. Si el fallo real es cierre de cachés incrementales Kotlin entre C: y D:, usar `kotlin.incremental=false` de manera temporal y **restaurar `gradle.properties` byte a byte**; no instalar SDKs, no limpiar caches globales, no cambiar versiones.

Si `exit 0`, verificar **existencia física** del APK `.dev` debug producido, tamaño, SHA-256, flavor/applicationId y firma; no declarar APK por un mensaje genérico. Si el sistema permite ADB, recolectar versión/estado de Mi A3 en modo lectura. **No desinstalar, no sobrescribir con certificado incompatible, no resetear datos**. QA física solo se marca PASS tras ejecutar realmente en dispositivo adecuado. Si build no se puede completar, avanzar A/B y GitHub; declarar `BUILD_BLOCKED_ENV` con causa y log, no un nuevo proyecto de diagnóstico.

## 7. Frente D — GitHub: preservar código real sin hacer un merge inseguro

C4 quedó completamente recuperable desde bundle; esto ya pasó y **no requiere clonar de nuevo para demostrar lo mismo**. El repositorio público GitHub `sierraglobalcompany-rgb/PicoRadar` tenía `main`=`e9ef37511df3110ffb0fc006ef06be781df432ac` al iniciar C5; corroborar en lectura una sola vez por si cambió. El PR #79 es **documental**, draft, con base `recovery/20261019-modern`; no tocarlo ni confundirlo con integración de C5.

**Prioridad**: terminar con el árbol C5 listo para restauración y, si la seguridad lo permite, una rama remota no productiva que contenga sus fuentes verdaderas. Proceso:

1. Crear commit(s) locales solo sobre el candidato C5, sin tocar checkout protegido. Obtener `FINAL_COMMIT`/`FINAL_TREE`; diffs de A y B y tests posteriores. No force-push.
2. Escanear el **árbol y todo historial que se proponga subir**, en particular `.env`, tokens, APKs, documentos privados, claves, BINARIOS y datos personales. Usar `gitleaks`/`detect-secrets` gratuitos si están presentes; sin herramientas, revisión heurística etiquetada `SCOPED_ONLY` **no es un PASS_SCANNER**. No imprimir secretos ni mandar valores al ZIP. Una ausencia de scanner es HOLD para publicar historial completo, **no para generar respaldo local**.
3. No subir el bundle histórico de 76 MB a GitHub público por comodidad. Si historial sintético presenta riesgos o no puede certificarse, usar un snapshot **source-only sin historia sintética** en una rama nueva de respaldo, con exclusiones explícitas y un escaneo igualmente conservador del árbol actual. No afirmar compatibilidad con `main` ni abrir PR si las historias son inconexas. No subir si existe una posible credencial activa sin revisar. Nunca subir `.git`, `.env` real, `vendor`, `build`, cachés, WIP privado o certificados de firma. Si el entorno niega GitHub auth, se mantiene `NOT_PUSHED` y se entrega respaldo C5 funcional en ZIP.
4. Para cualquier posible integración posterior con main, elaborar `MERGE_GAP.md` de una página (paths de diferencia crítica + reconciliación dirigida + seguridad, sin hacer otra auditoría general). No sustituir main histórico automáticamente, no merge forzado ni tags/releases.
5. El respaldo local final se debe **reclonar o extraer en otra carpeta vacía sin red** y comprobar que reconstruye exactamente `FINAL_TREE` y no depende de Git alternates, carpetas WIP ni objeto Git ajeno. Reutilizar la prueba ya hecha si los cambios nuevos se encuentran en el commit/archivo; una sola prueba de restauración C5 basta, no rehacer cada fase. Si solo existe snapshot sin `.git`, cotejar manifiesto SHA-256 de fuentes y reconstruir árbol Git de un commit limpio de origen.

**No confundir publicación del prompt con subida de código.** Reportar explícitamente `GITHUB_DOCS`, `GITHUB_CODE` y `PRODUCT_RELEASE` por separado.

## 8. QA y política de bloqueo: avance aunque falle un frente

- Laravel: PHP lint y Pint solo en archivos nuevos; **tests nuevos y sus regresiones directas**. No repetir 53 PHP C1 ni la suite completa por defecto. Si cambia una regla de permisos, ejecutar test directo del flujo de roles/seguridad afectado.
- Flutter: `dart format`/`flutter analyze --no-pub` focal y widgets modificados; no repetir 3.365 tests globales ni 11 C3 por inercia. Solo suite global si hay un cambio transversal de runtime y se justifica causa/recursos.
- Contrato: editor no produce `ALLOWED` a partir de inactividad/ausencia; Flutter no interpreta `UNKNOWN` como permiso; las pruebas usan fuentes sintéticas etiquetadas como tales. No publicar reglas oficiales nuevas sin fuente primaria con fecha y jurisdicción.
- Seguridad GitHub, HTTPS productivo, APK e instalación física son gates independientes: no permitir que uno bloquee el desarrollo funcional de otro. No inventar tiempos, permisos, herramientas, capturas o comandos exitosos.
- No hacer **más de dos** intentos del mismo build; no hacer **más de una** reconstrucción del bundle C4 si el candidato existía; no abrir C6 para 'reintentar el mismo paso' sin cambios causales. Un fracaso en A o B no cancela el trabajo independiente del otro; capturar fallo, subsanar causa y ejecutar test focal dentro del mismo C5.

## 9. Entrega obligatoria: UN SOLO ZIP, nada regado

Crear `PICORADAR_C5_RETORNO_UNICO.zip` bajo `D:\codex\_REPORTES\PicoRadar\C5-20261120\` (directorio de reporte, NO checkout protegido). Este ZIP es la **única entrega** para adjuntar a ChatGPT. Incluir como mínimo:

- `FINAL_REPORT.md`: qué código productivo se implementó, qué ya existía, qué quedó bloqueado; `NEXT=CHATGPT_DIRECTOR`, `PRODUCT_RELEASE=NO_GO` salvo autorización y QA completo posteriores. Estado independiente de A, B, C, D.
- `CHANGED_RUNTIME_FILES.csv`: path, antes/después, historia A/B, prueba causal y bytes/commit; separa runtime de tests/docs.
- `GATES.csv`: `PASS`, `PARTIAL`, `NOT_RUN`, `BLOCKED_ENV` y prueba exacta; no aceptar `PASS` con un log sintético.
- `QA/php_focal.log`, `QA/flutter_focal.log`, `QA/android_build.log` y otros nuevos solo si se ejecutaron. Adjuntar captura real del APK/UX solo si existe; etiquetar widgets sintéticos como `SYNTHETIC_WIDGET`.
- `FINAL_CODE_RECOVERY.bundle` **o** `FINAL_SOURCE_SNAPSHOT.tar.gz` sin secretos, + manifiesto de fuentes, procedimiento de recuperación y SHA-256; debe permitir recuperar exactamente los cambios C5 sin ZIP N3/N4/N5, y estar comprobado desde carpeta vacía. Si bundle incorpora historia con credenciales no seguras, NO meter credenciales en el ZIP: usar solo snapshot limpio y explicitar límite.
- `SECURITY_GATE.md` con método y límites sin valores secretos; `GITHUB_CODE_STATUS.md` con rama/commit remoto confirmado o causa de HOLD; `MERGE_GAP.md` breve si no hay integración.
- `FEATURES_BEFORE_AFTER.csv`: cuatro capacidades A/B/C/D, evidencia concreta, sin subir porcentaje por documentación, logs o tests repetidos. `SCORECARD_BEFORE_AFTER.csv` usando **la misma ponderación de 100 puntos que C4**; solo subir por gates nuevos efectivamente aprobados. Reportar `COBERTURA_LEGAL_NACIONAL=NO_MEDIBLE` hasta tener fuentes/denominador.
- `SOURCE_WIP_FINGERPRINTS_BEFORE_AFTER.csv` con 43 rutas y SHA byte por byte; si WIP inaccesible reportar `NOT_VERIFIED`, jamás `PASS` supuesto.
- `MANIFEST.csv` con todos los demás miembros: ruta relativa, tamaño, SHA-256, CRC32. ZIP CRC central validado, relectura de manifiesto 100 %, SHA del ZIP final. No anidar otro ZIP ni incluir vendor, gradle caches, secretos o archivos temporales grandes.

Respuesta de Codex al usuario: cuatro párrafos como máximo: resultado A/B/C/D, qué cambió y pruebas, ZIP único con ruta y SHA, bloqueos exactos, `NEXT=CHATGPT_DIRECTOR`. No enviar 12 enlaces ni documentos sueltos.

## 10. Controles adversariales ya resueltos por ChatGPT Director — NO repetir como tareas

### Verdugo (10 riesgos revisados)

V1. Android falló por carpeta, no por Kotlin: ruta real obligatoria. V2. Un intento fallido antes de Gradle no debe impedir un build auténtico: preflight separado. V3. A1/A2 de C4 existen: no reconstruir panel. V4. Deshabilitar jurisdicción no implica circulación permitida: etiquetas distintas. V5. Ciudades sin consulta no deben desaparecer ni crearse selectores paralelos. V6. La suite global repetida solo genera costo; pruebas focales. V7. Historia sintética no demuestra ascendencia remota: prohibir merge ingenuo. V8. Heurística de secretos no autoriza exponer historial público: scanning/conservadurismo. V9. Captura widget no prueba dispositivo real: gates segregados. V10. Un ZIP dependiente de otros objetos no conserva trabajo: recuperación autónoma comprobada.

### Juez (10 decisiones justificadas)

J1. A modifica el controlador/vista actual sin nuevo servicio. J2. `enabled=false` merece visibilidad **administrativa opcional** sin activar consulta. J3. B aporta una ficha informativa sin cambiar selector activo ni motor. J4. `UNKNOWN/STALE` siempre fuera de `ALLOWED`. J5. A/B aislados y un integrador impiden conflictos. J6. Un build desde `mobile/` prueba el bloqueo verdadero antes de cambiar Gradle. J7. Como mínimo un código backend y otro móvil con comportamiento distinto acreditan avance de producto, salvo bloqueo probado. J8. `GITHUB_CODE` separado de `GITHUB_DOCS` evita falsa sincronización. J9. Un snapshot source-only puede preservar código sin arriesgar historia, aun si el push público sigue retenido. J10. La misma métrica de C4 permite comparar evidencia, sin confundirla con el porcentaje global de terminación.

# 🔴🔴🔴 QUIÉN SIGUE: CODEX LUNA — EJECUTAR C5 COMPLETO, SIN PING-PONG 🔴🔴🔴

**DESPUÉS DEL ZIP ÚNICO C5 SIGUE CHATGPT DIRECTOR.**
