# CODEX LUNA — PICORADAR RC2-R1 — APK REAL Y CIERRE FOCAL DEL PRODUCTO, SIN PINGPONG

**TASK_ID:** `PICORADAR-RC2R1-APK-REAL-DATA-CLOSURE-ONEPASS-20261114`  
**QUIÉN EJECUTA:** Codex Luna; ChatGPT Director diseñó este único macrobloque y auditará solo el DELTA de retorno.  
**OBJETIVO COMPROBABLE:** producir una APK `dev-debug` instalable **si el host realmente dispone de SDK y recursos**, o dejar el requisito concreto de Windows sin repetir compilaciones inviables; entregar en el mismo bloque el estado verificable del sistema nacional por datos.  
**PRODUCT_RELEASE=NO_GO** hasta QA física, seguridad, publicación y autorización.  
**PROHIBIDO** relanzar RC2-R1 en paralelo: si Codex ya está ejecutando RC2 anterior, terminar esa ejecución y devolver su ZIP; no iniciar esta revisión.

## A. Punto de partida congelado y custodia mínima

1. **Entrada única:** ZIP `PICORADAR_RC1_AVANCE_FUNCIONAL_EVIDENCIA_UNICA.zip`, 85.172.104 bytes; SHA-256 `2ef40b1eb8428e040e72429c6780c04683c3f17ae164a8b896b16025b2da6a3e`. Su miembro `GIT/full-final.bundle` SHA-256 `2baae8686ba264adbebb132f16f2cec5743946f8c60ff7229b23658827d0c0bb`.
2. **Commit producto local** `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`, TREE `e312c7632fce4c43f9419cba60903e7420c46d85`, padre `15948a50332589ff3d1fb3157b6976809fe5a680`. Usar checkout aislado limpio existente que coincida; si no coincide, **una** recuperación desde bundle en clon nuevo. Nunca resetear/borrar checkout original, rebase ni modificar `main`, PR71 o PR79.
3. **PASS QUE NO SE REPITEN con ese HEAD:** protección de formulario schema2 (1 test/9 aserciones), importación JSON schema2 (1/20), aprobación/publicación/rollback (3/36); F2 general 33/279; Flutter OTA/Drift/UI (tres casos); puente Laravel-bytes→Flutter schema2 (un caso); 14 Python del LAB. Conservar sus logs de los ZIP anteriores como evidencias históricas, no ejecutarlos de nuevo ni meter sus paquetes enteros en el ZIP nuevo.
4. **NO desarrollar un segundo motor.** El único motor `schema2` consume reglas y coberturas habilitables por autoridad/ciudad/municipio/departamento/centro poblado con ámbito probado. Datos OTA + manifiesto, SHA, revisión, `UNKNOWN/STALE`, last-good y rechazo de snapshot incompleto; no hardcodes por ciudad. Comunicados de alcaldía/gobernación son fuentes válidas para los campos expresos sin exigir PDF de decreto; nunca inventar exenciones, horarios festivos o permiso de circulación.
5. Reglas L1–L6 (KISS/Ponytail, antirruido, antiparches, UX, evidencia, anti-pingpong). **Salida siempre un solo ZIP**. Trabajar desde `D:\codex\PicoRadar\RC2` o clon corto equivalente, preferiblemente en volumen NTFS comprobado. Si D: fuera exFAT, usar un volumen NTFS libre (C: o E: si confirmado) para el clon de build y sus caches, sin mover el original. Mantener `git status` limpio salvo corrección causal real.

## B. B0 — Herramientas verificadas sin bloquear frentes independientes

**Una sola detección (no recorrer todos los discos):** revisar Flutter 3.47.9 en PATH y `D:\codex\_toolchains`, `C:\src\flutter`, `%LOCALAPPDATA%` y `%USERPROFILE%\develop`. Validar versión exacta 3.47.9, Dart 3.13.7. NO usar Flutter 3.50 por el error SDK ya observado.

Si Flutter 3.47.9 falta, recuperar UNA VEZ el ZIP **oficial** Windows x64:

- URL: `https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.9-stable.zip`
- SHA256 de referencia: `d8e2b5977e09082c6440f89dc1aa887b94c8fbcc3b39222797046295a3f68a9e`.
- Contrastar ese SHA con `https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json` y el archivo descargado antes de extraer/ejecutar. Si no coincide o no está accesible, `TOOLCHAIN=BLOCKED_SHA_OR_DOWNLOAD` **sin reintentos ciegos**. No usar mirrors arbitrarios, scripts en cuarentena, instalaciones pagas ni `flutter upgrade`.
- Extraer en carpeta corta NTFS con espacio real, aislar `PATH` al proceso. Registrar ruta y resultado de `& '<ruta>\flutter\bin\flutter.bat' --version`, `dart --version`. Si la estructura contiene `flutter\flutter`, localizar exactamente el `bin\flutter.bat` generado; no asumir que ZIP y carpeta destino tienen una única capa.
- JDK real del proyecto: **17.0.19**; el PATH RC1 apuntaba a Java 21. Elegir `JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot` solo si está presente y validado con `& "$env:JAVA_HOME\bin\java.exe" -version`; modificar únicamente el entorno del proceso. Android SDK RC1 instalado con API 34–37 y Gradle wrapper 9.3.1, no actualizarlo por rutina.

**Preflight de build, una sola medición actual:** registrar RAM disponible, `Committed Bytes`, `Commit Limit`, resta disponible, espacio NTFS del clon/cachés y JDK/Android SDK. En RC1 había RAM 3.90 GiB, commit 30.67/32.45 GiB: **solo 1.77 GiB de margen**. Si el margen actual sigue **< 6 GiB**, establecer `ANDROID=BLOCKED_HOST_COMMIT` y NO ejecutar Gradle aunque Flutter esté instalado. No pedir repetición de ese mismo preflight en otra ronda si el host no cambió. No cambiar archivo de paginación, forzar reinicio ni cerrar procesos del usuario sin permiso. Acción única del propietario: configurar memoria virtual administrada por Windows en volumen NTFS con espacio, reiniciar si lo solicita, y entonces hacer otra medición.

**Preparación sin compilación cuando falta memoria:** se permite verificar SDK y registrar las rutas del proyecto; NO ejecutar Gradle. Continuar B2 y B3. La falta de memoria no impide el reporte ni la continuidad de Git.

## C. B1 — Una APK debug real, solo si B0 aprueba

1. En la copia NTFS aislada, confirmar `mobile/pubspec.lock` sin modificación, `.dart_tool/package_config.json` compatible y dependencias presentes. Si falta package_config o dependencias, ejecutar **un** `flutter pub get` fijado por lockfile (usar `--offline` solo si realmente están cacheadas, de lo contrario una recuperación ordinaria); **no** `pub upgrade`, build_runner ni limpieza indiscriminada. Verificar `mobile/android/local.properties` con `flutter.sdk` y `sdk.dir` reales del clon/SDK; permitir que Flutter lo regenere o corregir exclusivamente el archivo local ignorado por Git. No copiar rutas del equipo previo.
2. El repositorio define el comando Android validado en su `README.md`. Ejecutar desde `mobile`, usando la ruta absoluta de Flutter, los mismos parámetros de proyecto (son opciones Android de Flutter):

   ```powershell
   & '<FLUTTER_BIN_VERIFICADO>\flutter.bat' build apk --debug --flavor dev --dart-define=APP_ENV=dev --no-pub --no-android-gradle-daemon --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process
   $BUILD_EXIT = $LASTEXITCODE
   ```

   Antes de lanzarlo, si la memoria disponible no soporta los valores actuales de `mobile/android/gradle.properties` (`-Xmx8G`, Metaspace 4G), permitir **solo dentro del clon, temporalmente**, reducir gradle JVM a `-Xmx3g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=256m`, usar hasta 2 workers y `org.gradle.parallel=false`, con copia previa y restauración en `finally`. No cambiar configuraciones globales ni crear commit por este ajuste efímero. Si el resultado demuestra falta de memoria real, bloquear con el dato específico, no ampliar heaps de manera improvisada.
3. Capturar la **salida global** inmediatamente (no inferir PASS por un log parcial). Si el primer intento es `exit 0`, verificar `mobile/build/app/outputs/flutter-apk/app-dev-debug.apk`: existencia, tamaño, SHA256, integridad ZIP APK, package ID `co.picoradar.app.dev`, minSdk=24, targetSdk=36, versionCode/name y certificado de DEBUG mediante `aapt`/`apkanalyzer`/`apksigner` cuando las herramientas están disponibles. No declarar instalación/funcionamiento físico sin probarlo.
4. Solo si falla por un error de código/configuración **reproducible y localizado**, permitir UNA corrección mínima en clon, su validación focal y UNA recompilación. Si falla por red/SDK/espacio/memoria, `ANDROID=BLOCKED_ENV_<causa>` y detener reintentos. No ejecutar suite de pruebas Android larga porque se compiló una APK; si hay delta de código, únicamente su prueba afectada.
5. **No instalar ni desinstalar** PicoRadar del Xiaomi Mi A3, no cambiar firmas existentes, no publicar AAB, Play Store, producción ni Hostinger. APK `dev-debug` es solo artefacto de QA. Si hay APK, incluirla en el ZIP único y registrar su firma para planear posteriormente QA física sin destruir datos previos.

## D. B2 — Cierre exacto del sistema de datos, sin inventar nuevo staging

1. Usar **evidencia existente**: RC1 aprobó formulario seguro e importación/publicación; V5 aprobó 33 tests Laravel; V6 aprobó bytes Laravel→Flutter schema2, SHA, Drift y last-good en loopback; tres tests administrativos de aprobación/rollback pasaron RC1. Esos gates son **PASS_SCOPED_QA**, no staging desplegado ni publicación nacional.
2. Revisar **solo** estas uniones de código y evidencia (lectura): aprobado/editorial → snapshot completo (sin borrar coberturas previas) → manifest versión/revisión/SHA → OTA → Drift/last-good. Marcar por cada unión `REUSED_PASS` y archivo+SHA de evidencia o `NOT_CERTIFIED`. No reabrir 1.104 municipios, no levantar otro servidor ni generar nueva prueba si no hay un hueco **demostrable**. Si aparece UN hueco funcional reproducible, hacer solo una prueba focal RED→corrección mínima→GREEN bajo QA aislada y retornar el delta; de lo contrario continuar sin nuevas modificaciones.
3. Comprobar la **contratación del catálogo**: las reglas de cada jurisdicción se habilitan por datos y vehículo/modalidad/territorio y no por ramas codificadas en Flutter. El catálogo LAB de **14 autoridades / 33 códigos DIVIPOLA / 21 coberturas parciales / 115 reglas** no autoriza circulación ni es la totalidad nacional; ciudades sin información deben mantenerse `UNKNOWN` o deshabilitadas para consulta, no “sin pico y placa”. Diferenciar claramente **motor técnicamente generalizable** de **fuentes legales aún no recopiladas/certificadas**. No afirmar cobertura taxis, servicio público o carga para lugares sin fuentes.
4. Reportar los **bloqueos reales de salida a producto** en máximo seis líneas: APK/instalación física, staging/autenticación/admin, snapshot completo y firma/revisión/rollback, fuentes pendientes, seguridad push remoto y autorización final. No escribir otro plan maestro ni crear motor/tabla/frontend alternos.

## E. B3 — GitHub / seguridad: continuidad sin esconder deuda

- RC1 HEAD `7e2e1f3...` sigue **local**, no se encontró en GitHub. La rama PR79 documental tiene histórico y prompt; NO implica que la rama de producto esté sincronizada. Conserva la cadena de commits LAB y crea UN bundle nuevo desde el HEAD final; verificar el bundle desde un repositorio Git y clonar en entorno de comprobación.
- **No hacer push** de historial que tenga secretos o hallazgos no clasificados. Gitleaks anterior: nueve coincidencias benignas y una referencia Power BI cuya identidad exacta quedó pendiente. No repetir el escaneo de 1.839 ficheros ni escribir ese enlace en evidencias. Este bloque NO incluye `push`: mantener `CODE_REMOTE=HOLD_SECURITY`, bundle íntegro y nota breve para el Director. No forzar push, no crear PR, no alterar branch main.
- Usuario informó antivirus apagado: NO usarlo como excusa para repetir auditorías/impedir trabajo local con herramientas confiables ya verificadas; tampoco afirmar host seguro ni ejecutar scripts en cuarentena o abrir material sospechoso. Respetar políticas de seguridad y permisos.
- El siguiente Director puede sincronizar documentos de continuidad a GitHub; Codex no debe gastar el bloque rehaciendo PR79. Nunca incluir `.env`, tokens, claves, URL opacas ni reportes Gitleaks privados en ZIP/GitHub.

## F. B4 — Único ZIP de entrega y FIN sin pingpong

**Entregar solo:** `D:\codex\_REPORTES\PicoRadar\RC2R1-ONEPASS-20261114\delivery\PICORADAR_RC2R1_EVIDENCIA_UNICA.zip`.

Contiene `FINAL_REPORT.md` corto; `GATES.csv` (`B0/B1/B2/B3`, comando, exit real, SHA afectado); `LOGS/` **únicamente de esta ejecución**, saneados; `GIT/full-final.bundle` restaurable; `GIT/RESTORE.md` (comando y SHA del HEAD/TREE); `MANIFEST.csv` (SHA256, bytes y CRC32 de miembros); y **APK dev-debug dentro de este mismo ZIP si existe**, nunca un segundo enlace. En caso de bloqueo, igual entregar el ZIP y no enviar fragmentos separados. Evitar reempaquetar ZIPs anteriores dentro de este.

Verificar el ZIP después de cerrarlo: CRC, hashes/tamaños de miembros, extracción 100%, `git bundle verify`, clon aislado, `git rev-parse HEAD`, `HEAD^{tree}`, `git status --porcelain`. Registrar si hubo un cambio de código, con justificación, prueba y nuevo HEAD; no declarar limpio si quedan ajustes locales temporales. No publicar debug APK fuera del único ZIP.

**Respuesta de Codex (una línea + enlace al único ZIP):**  
`TASK_ID=PICORADAR-RC2R1-APK-REAL-DATA-CLOSURE-ONEPASS-20261114 | APK=<PASS_DEBUG|BLOCKED_HOST_COMMIT|BLOCKED_TOOLCHAIN|BUILD_FAIL_CAUSAL> | DATA_PIPELINE=<REUSED_PASS_SCOPED|FOCAL_PASS|OPEN_GAP> | REMOTE=NOT_SYNCED_SECURITY_HOLD | HEAD=<SHA> | TREE=<SHA> | APK_SHA256=<SHA|NO_APK> | ZIP_SHA256=<SHA> | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`

## G. Auditoría adversarial del DIRECTOR — ya resuelta, NO encargar a Codex

**10 pasadas VERDUGO:** V01: RC1 ZIP fuente inspeccionado; V02: bundle restaurado en clon y HEAD/TREE cotejados; V03: sintaxis de build cotejada con README (no inventar flags); V04: Flutter 3.47.9 existe, 3.50 incompatible con pruebas previas; V05: `--no-pub` sin package_config era fragilidad; V06: JAVA_HOME 17 vs Java 21 default; V07: 1.77 GiB de commit hace inviable prometer APK; V08: `-Xmx8G` merece reducción TEMPORAL SOLO en clon ante RAM apta; V09: no repetir PHP/Flutter aprobados; V10: GitHub docs no sustituye código remoto ni validación física.

**10 pasadas JUEZ:** J01: conservar SHA base y single writer; J02: evitar re-descargas si SDK verificado existe; J03: permitir preparar toolchain aunque memoria impida Gradle; J04: comprobar parámetros Gradle en local.properties y entornos correctos; J05: un intento de build y a lo sumo una reparación causal; J06: validar APK, no solo exit0; J07: reutilizar PASS por SHA y alcance; J08: preservar `UNKNOWN/STALE` y arquitectura nacional única; J09: no empujar historial con seguridad pendiente; J10: un solo ZIP verificable y NEXT_ACTOR explícito. **No repetir estas 20 pasadas en Codex.**

**NEXT_ACTOR = CODEX LUNA (solo si RC2 anterior todavía no comenzó); después = CHATGPT DIRECTOR.**