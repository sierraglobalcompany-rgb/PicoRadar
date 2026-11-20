# CODEX LUNA — PICORADAR C4 · DESARROLLO RUNTIME REAL + APK ANDROID + RESPALDO INTEGRAL DE CÓDIGO

**EJECUTOR: CODEX LUNA. DIRECTOR: CHATGPT.** Fecha de decisión: 20-11-2026 (America/Bogota).  
**TASK_ID:** `PICORADAR-C4-RUNTIME-ADMIN-APK-RECOVERY-20261120`  
**ENTRADA:** ESTE Markdown y los archivos locales C3 que ya tienes. **NO pedir nuevos adjuntos, NO repetir N4/N5/R2/C1/C2/C3, NO crear otro preflight autónomo.**  
**RESULTADO OBLIGATORIO:** progreso de producto comprobable, o bloqueo causal honesto; un **único archivo ZIP** con evidencia y recuperación de código sin dependencias ocultas. El paquete final NO debe ser una mera nueva auditoría.

## 0. Dictamen cerrado del director — NO rediscutir

Del ZIP `PICORADAR_C3_RETORNO_UNICO.zip`:

- SHA-256: `78a90ae4671d53f67555758b365276677a7ef24a7622b59ed45c783584de97d7`. Se comprobaron los 16 miembros (CRC) y las 15 entradas del manifiesto (bytes/SHA-256/CRC32).
- C3 partió del índice/tree `859bb8bbdff769ec3504af407f4df27593b2efea` y terminó en `4bd048974d5edb46b93257a77338eeef7903dd64`, mediante 3 rutas modificadas **todas de pruebas**. No hubo cambio runtime.
- C3 HTTP editor/revisión/publicación/rollback `PASS_LOCAL`: 1 test, 55 assertions; C3 Flutter focal `PASS`: 11 pruebas, formato/análisis; Drift v10→v11 con conservación de placa, vehículo, preferencias y versión del dataset: `PASS_LOCAL`; catálogo offline con transporte simulado: `PASS_OFFLINE_COMPONENT`; Free 1.0 anuncios OFF `PASS_LOCAL`. Son evidencias locales, no usuarios/dispositivos en producción.
- C2 puente Laravel→Flutter con mismos bytes + last-good: `PASS_LOCAL`; C1 PHP focal: 53/53, 592 aserciones y cero warnings. No volver a ejecutarlos sin cambio pertinente.
- C3 APK `BLOCKED_ENV`: compilación `:android_file_picker:compileDebugKotlin`, caché incremental que cruza `C:\...\Pub\Cache` y `D:\codex\...`; memoria antes del build 6,36 GiB. No es prueba de error del motor. C3 no generó APK.
- C3 código remoto `NOT_PUSHED` y `HOLD_SECURITY`: HEAD de recuperación `37ca71e1a1ebfbb14d908f3ab128c109ff401bc2`, **commit raíz sintético**, tree `a883b64fffb53d3d9ec263739c169561ddf8b49d`, sin `parent` ni `remote`. PR #79 está draft, rama de documentos, NO code PR.
- La restauración anterior exigía objeto local `a883...`: **ZIP C3 NO es autónomo por sí solo**. No confundir tres parches con copia integral recuperable.
- Fuente protegida Windows: 43 WIP (18 modificados + 25 untracked), comparados byte a byte en C3; no volver a tocar dicha fuente. La eliminación preexistente de `scripts/tests/test_hostinger_installer_browser.ps1` debe preservarse.
- Scorecard C3 `37→59/100`: **puntaje de verificación local**, NO porcentaje de aplicación terminada. El 58 % histórico de producto era una estimación, no una métrica nueva. Legal nacional `NO_MEDIBLE`, 17 filas LAB (3 PARTIAL, 14 UNKNOWN), cero nuevas fuentes verificadas. Nunca convertir UNKNOWN/STALE en ALLOWED.
- Las seis leyes `docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md`: L1 KISS/ponytail; L2 antirruido; L3 antiparches; L4 diseño humano; L5 verificación independiente; L6 antipíng-pong. Cumplir `AGENTS.md`: **Inicio · Garaje · Apps · Viaje · Conducir**, Apps al centro, funciona sin cuenta, Free 1.0 antes de monetizar, ADS/pagos OFF, privacidad GPS, y prelación de documentos base.

### Requisito de avance

**C4 no puede declarar cierre funcional por agregar únicamente tests, matrices, prompts o documentación.** Entregar al menos **una funcionalidad o mejora runtime visible, integrada y verificada**, preferentemente dos frentes, salvo bloqueo material demostrable. Las pruebas deben acompañar implementación, no sustituirla. No prometer nueva cobertura jurídica sin decreto oficial y vigencia verificables.

## 1. Recuperación segura en candidato aislado — una vez, sin repeticiones

1. Localiza primero el candidato C3 en los aislados locales ya conocidos (`D:\codex\_isolated\...`). Identifica por `git rev-parse HEAD` y `git write-tree`: HEAD `37ca71e...` y árbol indexado C3 `4bd048974d5edb46b93257a77338eeef7903dd64`. **No asumir** que el HEAD refleja los cambios staged: C3 no hizo commit.
2. Si el árbol está, prepara una copia de trabajo **independiente** mediante clone/alternates de los objetos del candidato, registra el tree y restáuralo en índice y working tree de la copia. `git write-tree` debe devolver `4bd0489...` **antes de C4**. No cambiar índice, HEAD, archivos ni 43 WIP del checkout operativo. La copia `--shared` es temporal; la entrega deberá ser autónoma y NO depender de sus alternates.
3. Si no existe el objeto base, usa las rutas indicadas por `RECONSTRUCTION.md` de C3 **una sola vez**. Si también falta el objeto Git `a883...`, **no declares restauración posible con los parches solamente**: `BLOCKED_MISSING_BASE`, preserva todo, entrega evidencias y cualquier trabajo independiente realizable. Nunca inventar árbol.
4. Lee únicamente los archivos relacionados de `AGENTS.md`, el contrato de producto prioritario, `server/app/Http/Controllers/Admin`, `server/resources/views/admin/restrictions`, `server/app/Services/RestrictionFormPayloadBuilder.php`, `server/app/Services/DatasetPublisher.php`, `mobile/lib/features/pico_placa`, `mobile/lib/core/sync` y la UI afectada. No realizar una nueva auditoría arquitectónica global.
5. En las copias, compara `SOURCE_WIP_FINGERPRINTS.csv` histórico con una fotografía de solo lectura actual de las 43 rutas. **No tocar las 43**; si no se puede verificar un byte, declarar `WIP_BYTES_NOT_RECHECKED`, no PASS falso. Evitar limpieza recursiva de aislamientos ajenos.

## 2. Dos frentes de producto, arquitectura KISS; hasta dos subagentes SOLO si conviene

**Integrador C4 único** posee commit/índice/ZIP/GitHub y decide las uniones. Cada subagente, si existe capacidad real, usa directorio/worktree y caché privados; sin ediciones simultáneas de `pubspec`, `composer`, `.env`, schema ni rutas compartidas. Dado el riesgo de RAM, **no compilar Android en paralelo con Flutter** ni ejecutar dos Gradle.

### Frente A — Laravel: producto real del editor nacional / Super Admin (prioridad 1)

Objetivo visible: agregar al panel administrativo una **vista/indicador de cobertura y vigencia por jurisdicción × tipo/servicio de vehículo**, reutilizando catálogo y modelo de publicación. Debe distinguir `VERIFIED`, `PARTIAL`, `UNKNOWN` y `STALE/EXPIRED` de acuerdo con los **estados ya definidos** por dominio; NO reinventar vocabulario persistente, NO convertir falta de regla en permiso de circular.

- Inspección causal única: localizar si ya existe vista equivalente **con rutas, filtro y evidencia real** en el candidato C3. Si existe y funciona, NO duplicarla: identifica la **acción de editor nacional que falte** (p. ej. acceso desde dashboard a revisar estado vigente por jurisdicción/categoría, fuente legal, versión o publicación) y completa esa acción en la UI existente. No crear controlador/modelo paralelo.
- Implementar, en código de producción, una pantalla Blade o panel existente con filtros útiles (jurisdicción, categoría/modalidad, estado), total de estados desconocidos, fecha de vigencia y enlace al editor/preview cuando exista. Los filtros deben ser server-side / paginados o limitados; evitar cargar catálogos enteros en memoria. Permisos: solo roles habilitados, nunca exponer datos de operador a visitantes. Si el modelo no registra alguna evidencia, mostrar **«sin fuente verificada»** en lugar de inventarla.
- Si se detecta falta de separación efectiva entre quien edita y quien aprueba, corregir el controlador/policy existente de forma mínima y demostrar que rechazo/denegación no muta el manifest. Si ya está demostrado en C3, **no reimplementarlo ni repetir su test**.
- Demostración focal: ruta/controller + vista + permisos + conteos basados en 3 fixtures sintéticos (válido, vencido, desconocido). Verifica que ausencia de fuente no se anuncie como restricción publicada y que editor no pueda elevarse a Super Admin. Captura de HTML real o prueba HTTP renderizada; no solo prueba unitaria aislada. Si faltan extensiones del entorno, usa el mecanismo local acreditado en C3 una vez; reporta causa si falla.
- Entregable A: **al menos una ruta PHP/Blade runtime modificada**, más test causal y muestra de UI/HTML. NO nuevas tablas si modelos existentes permiten lograrlo; no cambiar normativa.

### Frente B — Flutter: información y UX de restricciones nacionales en modo offline (prioridad 2)

Objetivo visible: en la pantalla apropiada de pico y placa / estado del vehículo existente, mostrar de manera comprensible **jurisdicción, modalidad, fecha, estado de restricción y calidad/vigencia de los datos** (`UNKNOWN`, `STALE`, `PARTIAL`, válido), obtenido del motor/store **local**. Debe seguir funcionando sin cuenta y sin consultar al servidor por ubicación continua.

- Leer primero la implementación real existente en el candidato. Si la pantalla ya comunica fielmente estos estados, NO crear pantalla duplicada ni cambiar navegación; realizar una mejora runtime delimitada que falte: **fuente/fecha de última actualización visible, o aviso contextual de datos desconocidos/caducados**, si están disponibles en el catálogo. **No mostrar enlace a fuente oficial si no existe en el dataset**.
- Reutilizar `restrictionStoreProvider`/motor tipado/Drift v11; jamás implementar motor paralelo, ninguna regla hardcodeada por ciudad, ningún booleano `UNKNOWN=ALLOWED`. No alterar semántica de evaluaciones aprobadas.
- Un test widget o integración de componente prueba el estado visible para cobertura conocida, desconocida y vencida y la ausencia de llamadas HTTP durante render; un test de datos si cambió persistencia. No repetir 3.365 test globales, C2 puente ni los 11 de C3, salvo dependencia cambiada específicamente. Si no hay SDK funcional, implementar y validar estáticamente si posible, pero estado `NOT_RUN`, no PASS.
- Entregable B: **al menos una ruta Dart runtime modificada**, test focal y captura/render prueba del estado. Sin cambios de `pubspec`, Drift schema o build config salvo necesidad causal reproducida.

**Orden operativo:** A y B pueden correr en paralelo SOLO con recursos suficientes; si no, secuencial A→B. Si un frente encuentra bloqueo reproducible, no detener el otro. No iniciar subagentes de auditoría ni repetir los mismos tests. Integrar ambos cambios UNA sola vez, con archivo de conflictos y QA mínimo de sus rutas. Preferir avance real de A+B antes de gastar tiempo en compilación.

## 3. APK DEV — reparar la causa de raíz C:/D:, NO otra exploración general

**Diagnóstico previo acreditado:** Android `:android_file_picker:compileDebugKotlin` falla al cerrar caché incremental con paths de `C:\Users\...\Pub\Cache` frente a base `D:\codex\...\mobile\android`. La documentación oficial Kotlin `https://kotlinlang.org/docs/gradle-compilation-and-caches.html` autoriza `kotlin.incremental=false` en `gradle.properties` o `-Pkotlin.incremental=false` en Gradle. Este workaround afecta rendimiento de compilación, no la lógica de la app.

1. Esperar integración de A+B y QA focales. Comprobar RAM libre >=6 GiB **antes** de un único intento controlado; si inferior, `APK_BLOCKED_RESOURCE` y continuar recuperación sin esperar. Registrar herramientas (`flutter --version`, SDK, Java, `gradlew --version` si procede) con salida saneada.
2. En la **copia aislada** (no proyectos ajenos), registrar hash y contenido relevante de `mobile/android/gradle.properties`; aplicar temporalmente `kotlin.incremental=false` solo allí. Si no hay archivo, crearlo **solo en copia**. Limitar a un worker Gradle y concurrencia; sin limpiar caches globales, sin cambiar plugins/versiones, sin tocar `C:\Users\...\Pub\Cache` ni reiniciar herramientas ajenas. Puedes pasar la propiedad por Gradle directamente si compruebas que el comando realmente compila el flavor `dev`; **no asumir** que `flutter build ... -- -P...` propaga argumentos Gradle.
3. Ejecutar **una sola compilación** del flavor DEV Debug ya identificado; usar `--no-pub` si las dependencias están resueltas y registradas. Si falla, capturar tarea, stacktrace causal y el nuevo primer error; no hacer bucle de retries ni versiones aleatorias. Restaurar el `gradle.properties` original después, preservando el APK construido si existe.
4. Si se genera APK: verificar ruta, tamaño, SHA-256, `applicationId`, versión y **firma/certificado**; anexar APK al ZIP final. No aprobar instalación ni actualizar producción por este solo build. En Xiaomi Mi A3, una firma diferente puede impedir actualización; no desinstalar ni borrar datos. ADB instalación **NO autorizada** por esta orden, sin consentimiento explícito del propietario.

## 4. Recuperabilidad y GitHub: no más documentación sin código

A. **Respaldo portátil obligatorio:** la entrega C4 debe poder recuperar EXACTAMENTE el tree C4 aun si se pierde `D:\codex\_isolated` y el objeto `a883...`. No basta repetir los parches C3. Crear en copia aislada un commit local con el tree C4 y un **Git bundle autocontenido** que incluya sus antecesores Git realmente necesarios (sin referencias a alternates). Verificar en **nuevo repositorio vacío independiente** que `git clone`/`git bundle verify` permite obtener idéntico `git rev-parse HEAD^{tree}`. El bundle puede ser un archivo `.bundle` dentro del **único ZIP externo**; no adjuntar otro ZIP. Si el bundle excede límite o falla, sustituirlo por un directorio `SOURCE_SNAPSHOT/` con archivos de código completos y hashes, excluyendo `.git`, `vendor`, `node_modules`, `.dart_tool`, secretos, caches, APKs y material no fuente. Verifica que snapshot pueda reconstruir manifest/hash de C4. **No etiquetar recuperable sin prueba de reconstrucción desde cero.**

B. **GitHub productivo del proyecto, nueva rama de código y ascendencia honesta:** el repositorio remoto real es `sierraglobalcompany-rgb/PicoRadar`; `main` no se toca y PR #79 es solo documental/draft. Intentar GitHub únicamente si se cumplen TODOS:
   - acceso remoto auténtico/permiso confirmado; obtener SHA remoto actual, no asumir el C3;
   - rama NUEVA **desde** `origin/main` o base de código oficial verificada, sin force push ni historia sintética presentada como ancestro;
   - llevar al nuevo worktree los cambios runtime verificados desde C3→C4, y la integración N4/N5 SOLO si las rutas base coinciden o se resuelven incompatibilidades con tests concretos; jamás reemplazar el árbol remoto completo sin revisión de diff y de archivos que desaparecerían;
   - `git diff --check`, comparación de tree/listado y escaneo de secretos en **diff + archivos nuevos + snapshot** (sin imprimir valores). Para checkout público, una coincidencia real o revisión no concluyente mantiene `HOLD_SECURITY`. Usa herramientas gratuitas si ya disponibles; ausencia de gitleaks/trufflehog se declara y se complementa con revisión diferencial, sin falsos PASS.
   - las rutas no afectadas del remote deben seguir idénticas, salvo cambios justificados; cero archivos personales/secrets, cero pérdida de archivos del main remoto.
   - realizar commit y push SOLO a rama `director/picoradar-c4-integration-20261120` **si toda la integración pasa**. Registrar SHA remoto, tree y URL PR sólo si efectivamente existe. No merge, no despliegue, no release y no forzar push. Si GitHub 403 o la ascendencia/integración no es segura, **NO_PUSH**, conservar bundle portátil y anotar bloqueo concreto **una sola vez**; no usar otro falso "código actualizado en GitHub" por subir solo un Markdown.

C. Documento de continuidad corto `docs/plans/PICORADAR_C4_ESTADO_VERIFICABLE_20261120.md` en **rama documental existente** si el push es posible: trees exactos, QA nueva, código realmente remoto vs solo local, bloqueos, prioridades C5. No hacerlo reemplazo de código ni alargar la ejecución. No modificar `main`/PR79.

## 5. Gate de medición: progreso real, no porcentajes inventados

Crear `SCORECARD_C4_BEFORE_AFTER.csv` con los **mismos 12 criterios y pesos de C3** para comparabilidad: Motor 14, Cobertura oficial 12, Editor 12, Autorización 9, Publicación 11, OTA/offline 10, Drift 7, UX incertidumbre 6, campañas 5, GitHub código 4, HTTPS real 5, APK/QA dispositivo 5. Valor base para reproducir **37→59 puntos**: puntaje 59 local C3. El nuevo score solo aumenta si aparece **evidencia nueva y de alcance compatible**; no dar puntos por repetir pruebas viejas, prompts ni duplicar test. Escribir por separado:

- `SCORE_EVIDENCIA_LOCAL_C4=X/100` (no llamar "% de app");
- `PRODUCTO_GLOBAL_PCT=NO_MEDIBLE` si no existe inventario de funcionalidades aprobadas con denominador/ponderación y trazabilidad. Si se reporta un % estimado, marcarlo `ESTIMACION`, explicar método y nunca restar/sumar desde el 58 % histórico a la matriz de 59;
- `COBERTURA_JURIDICA_NACIONAL=NO_MEDIBLE` hasta fuente y denominador válidos, y reportar `n_verified/n_eligible` solo cuando ambos sean jurídicamente sustentables;
- `RUNTIME_FILES_CHANGED`, `PHP_C4_TESTS_PASS`, `FLUTTER_C4_TESTS_PASS`, `APK_BUILD`, `CODE_BRANCH_PUSHED`, `PORTABLE_RECOVERY`, `WIP_43_SHA_MATCH`, `RELEASE=NO_GO` salvo todos gates físicos/legales/seguridad satisfechos.

Un PASO local no equivale a navegador real, HTTPS, modo avión, ni QA física. Un build DEV no es app publicada.

## 6. Salida final única y estructura (debe ser real)

Un solo ZIP `PICORADAR_C4_RETORNO_UNICO.zip`, ubicado bajo `D:\codex\_REPORTES\PicoRadar\C4-20261120\`. Sin ZIP anidado ni adjuntos dispersos. Contenido mínimo:

- `FINAL_REPORT.md`: tareas concretas implementadas, archivos runtime cambiados, antes/después, hashes tree C3/C4, bloqueos, qué no se probó y `NEXT=CHATGPT_DIRECTOR`;
- `GATES.csv`, `SCORECARD_C4_BEFORE_AFTER.csv`, `CHANGED_RUNTIME_FILES.csv`, `RECONSTRUCTION_C4.md`;
- `QA/` logs focales **completos saneados** y HTML/capturas de las rutas y widgets; si algo no corrió, marca `NOT_RUN`, sin inventar logs;
- `C4_DELTA.patch` que contenga código runtime **y** tests, para inspección y recuperación; `R2V2_BASE.patch`, `R2V2_FINAL_DELTA.patch`, `C3_DELTA.patch` con sus SHA del reporte C3 cuando aún existan (si falta alguno, declarar faltante sin regenerarlo falsamente);
- `PICORADAR_C4_SOURCE.bundle` **o** `SOURCE_SNAPSHOT/` autónomo verificado; `GITHUB_CODE_STATUS.md` y `SECURITY_GATE.md` con secretos omitidos;
- `SOURCE_WIP_FINGERPRINTS_BEFORE_AFTER.csv` de las 43 rutas solo lectura; APK **únicamente** si build verdadero y firma/hashes verificables;
- `MANIFEST.csv`: rutas, bytes, sha256 y crc32 por miembro excluyendo el propio manifiesto; ZIP CRC íntegro y resumen SHA-256 del ZIP.

**NO incluir** secretos, datos personales reales, tokens, claves, certificados privados, cachés completas ni logs con credenciales. Si el tamaño del bundle exige simplificar, no sacrifiques el código recuperable: omite logs repetidos, no la fuente.

### Criterio de cierre C4

`PASS_SCOPED_PRODUCT` requiere: al menos **un código runtime nuevo** y su prueba causal; preservación exacta del WIP; snapshot/bundle autónomo probado; estado honesto APK/GitHub. `PASS_CODE_BRANCH` solo si branch code remoto comprobado. `PASS_APK_DEV` solo si existe APK con hash/firma y build exit 0. `RELEASE=NO_GO` mientras falten HTTPS real, legal oficial completa por cobertura pretendida, QA dispositivo y aprobación de publicación. Si se completan A+B y el build falla, reporta progreso de producto real, no `BLOCKED_ENV` global.

## 7. Auditoría adversarial DEL DIRECTOR al prompt — ya hecha, NO volver a ejecutar

### 10 controles VERDUGO (fallo buscado → prevención)

1. Tests C3 sin runtime → exigir archivos PHP/Blade y Dart ejecutables nuevos.
2. `59/100` mal rotulado como avance app → separar score local y producto medible.
3. Parche sin objeto base a883 → bundle con restauración en repo vacío.
4. Commit sintético presentado como descendiente de main → branch oficial con verdadera base.
5. Push público sin análisis → control de secretos y árbol previo, HOLD real si falla.
6. Kotlin raíz C/D se reintenta a ciegas → `kotlin.incremental=false` una vez, copia aislada.
7. APK DEP bloquea el resto → build al final, independentemente de desarrollo.
8. Dos agentes comparten recursos → máximo dos worktrees privados y un integrador.
9. Se revalidan miles de tests → focal por diff; anteriores son evidencia histórica.
10. Cobertura nacional inventada → UNKNOWN/STALE y fuente/fecha legal auditable, cero aprobaciones ficticias.

### 10 controles JUEZ (decisión y condición de aceptación)

1. Reusar editor/publicador existente: no repetir controladores ni tablas.
2. Agregar cobertura/vigencia visible: respuesta útil para editor nacional.
3. Mantener frontera Super Admin/editor: denegaciones sin mutación.
4. Reusar motor Flutter local: no crear segundo motor de decisiones.
5. Mejorar incertidumbre en UX: siempre explicitar UNKNOWN/STALE.
6. Conservar Free 1.0 sin cuenta ni monetización forzosa.
7. Usar prueba causal UI/HTTP de cambios nuevos, no sólo nueva unit test.
8. Medir 12 criterios de C3 con alcance consistente, sin fake progress.
9. Recuperabilidad offline con commit/bundle completo: no depender de Windows.
10. Release NO_GO hasta gates reales, pero continuar implementando sin ping-pong.

## 8. Contrato de ejecución compacto de Codex Luna

**Secuencia:** localizar C3 → crear copia aislada → verificar tree → Frente A runtime + QA → Frente B runtime + QA → integrar → un build APK corregido si RAM → portable bundle → rama de código real solo si segura → ZIP único validado. No reabrir auditorías completas. Un solo preflight focal. Cada bloqueo: **una observación + una acción correctiva autorizada**; si falla, registra `PARTIAL` y avanza en lo independiente. No crear C4-V2, C4-R1, múltiples prompts ni consultas al director durante la ejecución si hay una alternativa segura y ya indicada.

**CIERRE:** informar en la respuesta solo `TASK_ID`, estado por frente, `RUNTIME_FILES_CHANGED`, árbol final, pruebas nuevas, disponibilidad de bundle, APK, GitHub y `SHA256 ZIP`; adjuntar **un solo ZIP**.

# 🔴🔴🔴 QUIÉN SIGUE: CODEX LUNA — EJECUTAR C4 Y ENTREGAR ZIP ÚNICO 🔴🔴🔴

**DESPUÉS DEL ZIP C4 CONTINÚA: CHATGPT DIRECTOR.**
