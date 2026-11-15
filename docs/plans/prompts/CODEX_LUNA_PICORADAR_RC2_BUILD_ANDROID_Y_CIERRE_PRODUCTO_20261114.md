# CODEX LUNA — PICORADAR RC2 — COMPILAR APK Y CERRAR LA INTEGRACIÓN DE PRODUCTO (UN MACROBLOQUE)

**TASK_ID:** `PICORADAR-RC2-APK-LOCAL-STAGING-ONEPASS-20261114`  
**Director:** ChatGPT decide alcance y acepta evidencia; **Codex Luna:** ejecuta sin replanificar.  
**NEXT_ACTOR cuando termine:** `CHATGPT_DIRECTOR`  
**RELEASE:** `NO_GO` hasta APK real, QA física y publicación autorizada.

> **OBJETIVO INMEDIATO, NO AUDITORÍA:** convertir el RC1 ya aprobado en una APK debug `dev` instalable y confirmar la ruta de publicación administrativa en QA local sin duplicar motores, pruebas ni infraestructura. Si un impedimento externo exige acción del propietario, NO generes otro RC3 con la misma causa: deja la acción exacta identificada y completa todos los pasos independientes del mismo bloque. Solo un escritor PicoRadar activo.

## 0. Punto de partida inmutable — NO REHACER

- Entrega: `PICORADAR_RC1_AVANCE_FUNCIONAL_EVIDENCIA_UNICA.zip`, **85.172.104 bytes**, SHA256 `2ef40b1eb8428e040e72429c6780c04683c3f17ae164a8b896b16025b2da6a3e`.
- Git bundle dentro de ese ZIP: `GIT/full-final.bundle`, SHA256 `2baae8686ba264adbebb132f16f2cec5743946f8c60ff7229b23658827d0c0bb`. Verificar UNA vez sus bytes y HEAD si se usa para recuperar el checkout.
- RC1 HEAD: `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`; TREE: `e312c7632fce4c43f9419cba60903e7420c46d85`; padre: `15948a50332589ff3d1fb3157b6976809fe5a680`.
- RC1 PASS respaldados por logs: formulario schema2 protegido (1 caso/9 aserciones); JSON schema2 importar→confirmar→validar/publicar (1 caso/20 aserciones, una repetición por directorio QA faltante); tres casos focales de publicación, rollback, rechazo de pérdida de cobertura y aprobación SHA (3/36); PHP lint y Pint focal PASS. F2 previo 33/279; Flutter OTA/Drift/UI 3 casos y G2 puente de bytes schema2 1 caso PASS. **NO repetir** esos tests con el mismo HEAD y los mismos fixtures.
- La restauración del bundle en clon independiente ya probó 1.839 archivos, checkout limpio, HEAD y TREE correctos. No reconstruir V6R4 ni modificar `C:\...` original, PR #71, PR #79, `main`, Hostinger ni teléfono.
- El parche RC1 de tres archivos está **confirmado como código en el commit local**, no aún remoto. No volver a aplicar el ZIP de parche anterior: se duplicaría. No crear motor distinto para cada ciudad, departamento, municipio o pueblo.

## 1. Preparación de una única copia de trabajo y recurso Android

Trabajar en `D:\codex\PicoRadar\RC2` o en un clon aislado equivalente con ruta corta sobre disco que soporte archivos del proyecto. Si `HEAD` y árbol difieren, no tocar la copia original; restaurar desde el bundle a una carpeta nueva. Capturar `git rev-parse HEAD`, `HEAD^{tree}` y `git status --porcelain` al inicio. Conservar la rama local RC1 y su historia sin rebase.

**Herramientas existentes**: JDK 17.0.19 y Android SDK android-34 a android-37, build-tools y caché Gradle 9.3.1 están presentes según RC1. El repositorio usa `mobile/android/app/build.gradle.kts`, AGP 9.1, Kotlin 2.4, `compileSdk=37`, `minSdk=24`, `targetSdk=36`, flavor `dev`, ID debug `co.picoradar.app.dev`. La firma de `release` sigue siendo debug: PROHIBIDO generar artefacto de producción.

**Flutter, sin actualizar SDK/Dart ni repetir instalaciones:**

1. Localizar **una sola vez** un Flutter 3.47.9 funcional en las carpetas de herramientas ya usadas por PicoRadar, el `PATH` del proceso y los directorios convencionales (`D:\codex\_toolchains`, `%LOCALAPPDATA%`, `C:\src\flutter`, `%USERPROFILE%\develop`). No recorrer íntegramente discos ni ejecutar SDK desconocidos.
2. Si no aparece, obtener **una vez** el ZIP oficial x64 (gratis) de la distribución Flutter, en carpeta de herramientas aislada sobre una unidad **NTFS** (si `D:` es exFAT, preferir un volumen NTFS disponible), **sin actualizar a 3.50**:  
   `https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.9-stable.zip`  
   **SHA256 EXACTO** `d8e2b5977e09082c6440f89dc1aa887b94c8fbcc3b39222797046295a3f68a9e` según `https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json`; framework `c197ca5199e9ee5661e865596c9c07294dfab51c`, Dart 3.13.7. Si el hash falla, NO ejecutar ni instalar; poner en HOLD_TOOLCHAIN y seguir con §3. No usar mirrors no verificables, desactivar antivirus ni permitir scripts en cuarentena.
3. Confirmar con ruta absoluta `flutter.bat --version` y `dart --version`. Aislar PATH a este proceso; NO modificar PATH global, Flutter del propietario, versiones del producto o `pubspec.lock`.

**Memoria real y una única decisión:** antes de Gradle, medir `RAM disponible`, `CommitLimit`, `CommittedBytes`/margen de memoria comprometida y espacio de disco (C:, unidad de trabajo y caché). RC1 dio RAM libre 3,90 GiB, comprometido 30,67/32,45 GiB, **margen 1,77 GiB**. En ese estado **NO intentar build**: el hecho de que Gradle tenga `-Xmx8G` y Metaspace de 4G no demuestra que el build necesite reservar todo, pero el margen es insuficiente para una compilación fiable. No ordenar cerrar procesos del usuario ni aumentar archivo de paginación/reiniciar automáticamente.

Si el usuario **ya** amplió memoria virtual o liberó memoria y existe **margen comprobado de al menos 6 GiB y RAM razonable**, hacer **una única compilación controlada**; no usar el dato antiguo ni bajar artificialmente el umbral. Una mejora de parámetros de Gradle puede hacerse SOLO dentro del clon aislado, con copia de respaldo, si es necesaria y justificable, sin commit ni cambio global: ejemplo `org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=256m`, `org.gradle.workers.max=2`, `org.gradle.parallel=false`. Restaurar al terminar. No introducir un parche permanente de Gradle sin prueba causal.

**Si sigue bloqueado el margen:** escribir `ANDROID_WAITING_FOR_OWNER_VM_RESOURCE` con cifras nuevas, y documentar acción del usuario: habilitar memoria virtual administrada por Windows en una unidad NTFS con espacio suficiente, cerrar aplicaciones voluntariamente y reiniciar si Windows lo solicita. No intentar Gradle con solo 1,77 GiB ni presentar esa limitación como defecto de Flutter/app. Ejecutar §3 independientemente.

## 2. APK debug real — una ejecución con corrección causal máxima de un fallo

Solo si Flutter 3.47.9 verificado, JDK 17/SDK listo y memoria PASS:

1. Desde `mobile`, preservar archivos locales del entorno y usar `flutter pub get` UNA VEZ solo si faltan dependencias/lock cache; no `upgrade`, `clean` global ni build_runner (no se modificaron entradas codegen). `flutter doctor -v` solo dirigido a Android si falta diagnóstico real.
2. Ejecutar exactamente el comando del README (desde `mobile`, con ruta absoluta a `flutter.bat` si no está en PATH):

   ```powershell
   flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev --no-pub --no-android-gradle-daemon --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process
   ```

   Capturar exit global, duración solo informativa, stderr/stdout saneados y archivos producidos. No ejecutar `:app:testDevDebugUnitTest` si ya hubo un build fallido que lo hace irrelevante; los tests previos conservan su propio PASS.
3. Si existe `mobile/build/app/outputs/flutter-apk/app-dev-debug.apk`, verificar tamaño, SHA256 y validez del APK con herramientas `aapt`/`apkanalyzer` disponibles; ID `co.picoradar.app.dev`, versión, target/minSdk, certificado **debug**. No inferir que instala ni que funciona en Mi A3 por el simple archivo. No instalar en dispositivo ni modificar datos persistidos.
4. Si falla compilación por un error causal **del código o configuración**, aplicar una sola corrección focal en clon aislado, un test/validación afectados y UNA recompilación adicional. Registrar delta y HEAD nuevo; no convertirlo en una ronda interminable. Si el fallo es red/espacio/SDK/memoria, registrar `BLOCKED_ENV_<CAUSA>` y no reintentar a ciegas.

## 3. Completar el producto por datos: ADMIN → PUBLICADOR → CLIENTE, sin tests repetidos

El formulario legado ahora rechaza downgrade de schema2; el importador JSON schema2 y sus pruebas focales ya pasaron. **No diseñar otra UI, otra tabla ni otro motor.** Confirmar mediante lectura de código/artefactos que existen todos los pasos de producto:

`jurisdicción y modalidad desde JSON aprobado → validación territorial/sourceUrls/verifiedAt/staleAfter/coverageCompleteness → aprobación SHA+fuentes+revisión → manifiesto versionado con bytes íntegros y SHA → fetch/OTA → persistencia Drift y last-good → rechazo/reversión de revisión errónea`.

F2/RC1/G2 ya cubren partes concretas; identificar **solamente el primer eslabón no certificado**, no buscar un problema nuevo en todo el proyecto. Hacer UN smoke de punta a punta en QA local con una ciudad sintética y base efímera **si** el hueco requiere prueba integrada y hay herramientas. El snapshot LAB 14 autoridades/33 códigos/21 coberturas/115 reglas **no** se debe publicar como snapshot nacional completo ni reemplazar autoridades ya aprobadas. Las ciudades sin restricción explícita o sin datos no deben convertirse automáticamente en “puede circular”: respetar `UNKNOWN/STALE` y `consultationEnabled` solo cuando corresponda.

**No abrir investigación nueva de 1.104 municipios.** Implementar/o documentar la carga editorial gradual mediante el schema2 ya soportado para ciudad/municipio/departamento/centro poblado con ámbito oficial probado. Un boletín vigente de alcaldía/departamento es fuente admisible para sus afirmaciones explícitas; no exigir PDF de decreto si no es necesario, pero tampoco inventar festivos, exenciones, perímetro, vigencia o permisos. Si la ruta de publicación ya está cubierta en los logs previos, marcar `REUSED_PASS` con SHA y evitar nuevo smoke.

## 4. GitHub y cadena de custodia — no bloquear el desarrollo local

El PR #79 documental está actualizado; eso **NO** significa que el commit RC1 exista remotamente. El código contiene historia LAB derivada de PR71; Gitleaks previo clasificó 9/10 coincidencias y quedó una referencia Power BI con identidad exacta por resolver. No publicar bruto de escáner, secretos, enlaces con token ni archivos privados. No hacer `push` de esa historia ni un PR nuevo mientras el gate de seguridad no cierre.

**Avanzar sin pingpong:** conservar un bundle Git completo del último HEAD, hash y diff breve saneado. Ejecutar `git bundle verify` desde un directorio que ya sea repositorio Git (o el clon de restauración), no desde una carpeta arbitraria. Si puede verificarse en lectura la igualdad del enlace de referencia con la fuente pública oficial, clasificar y adjuntar SOLO prueba de igualdad booleana, sin divulgar parámetro; si no, mantener `REMOTE_HOLD_SECURITY`, pero completar §2/§3. No volver a escanear 1.839 archivos sin nueva historia o nueva necesidad. No reabrir estado de Bitdefender como bloqueo de código: el usuario indicó que está apagado, por lo que no se declara el host seguro ni se ejecutan archivos en cuarentena.

## 5. Contrato de salida: UN SOLO ZIP Y NADA MÁS

Crear un único `D:\codex\_REPORTES\PicoRadar\RC2-APK-PRODUCT-20261114\delivery\PICORADAR_RC2_EVIDENCIA_UNICA.zip`, con:

- `FINAL_REPORT.md` corto, `GATES.csv` con PASS/BLOCKED y exits reales, `LOGS/` saneados **solo de operaciones nuevas**, `GIT/full-final.bundle` del HEAD final verificable en clon limpio, `MANIFEST.csv` con bytes/SHA256/CRC32 y **APK debug solo si se compiló**. Si el APK hace el ZIP demasiado grande, preservarlo junto a evidencia bajo el mismo ZIP (no entregar dos archivos). No incluir .private.json, credenciales, enlaces con tokens, `.env`, caches ni ZIP de rondas anteriores.
- Validar CRC, hashes y tamaños de todos los miembros, extraer a ruta temporal segura y verificar `git bundle verify`, HEAD/TREE exactos, estado limpio. No mezclar registros del fallo inicial con un PASS final sin explicarlo.
- En el mensaje de retorno entregar una línea exacta: `TASK_ID | RC1_REUSED=PASS | ANDROID_BUILD=<estado> | APP_ADMIN_STAGING=<estado> | REMOTE=<estado> | HEAD=<SHA> | TREE=<SHA> | APK_SHA256=<SHA_o_NO_APK> | ZIP_SHA256=<SHA> | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`.

**Criterio de éxito inmediato:** APK dev-debug verificable y evidencia de continuidad OTA/editorial, o bloqueo único e irreducible por **acción concreta del propietario** de memoria virtual/entorno; conservar logros sin otra auditoría repetida. No prometer producto release ni QA física sin evidencia.

**QUIÉN SIGUE:** CODEX LUNA PARA RC2 (SOLO SI NO ESTÁ ACTIVO OTRO TRABAJO); LUEGO CHATGPT DIRECTOR PARA DECISIÓN DE QA FÍSICA Y LANZAMIENTO.