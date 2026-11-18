# CODEX LUNA — PICORADAR RC3 — QA ANDROID REAL SIN DUPLICAR APK NI REPETIR AUDITORÍAS

**TASK_ID:** `PICORADAR-RC3-ANDROID-RUNTIME-QA-MINIMAL-EVIDENCE-20261115`  
**DIRECTOR:** ChatGPT. **EJECUTOR:** Codex Luna. **NEXT_ACTOR:** `CHATGPT_DIRECTOR` al entregar el único ZIP.  
**OBJETIVO OPERATIVO:** pasar de «APK debug compilada» a «APK debug ejecutada y comprobada», sin reconstruir un motor nacional, sin repetir las suites verdes y sin volver a subir 210,97 MB de APK a ChatGPT. Priorizar resultado verificable, no informes sobre informes.

## 0. Fuente de verdad e identidad congelada

- Código RC1/RC2-R1: **HEAD** `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`, **TREE** `e312c7632fce4c43f9419cba60903e7420c46d85`, rama local `feat/picoradar-rc2-r1-apk-real`. El checkout original se conserva sin modificación. Si ese HEAD no está, recuperar clon aislado desde el bundle del ZIP RC2-R1, **sin clonar main GitHub como sustituto**.
- Bundle ya auditado en el ZIP aportado: `GIT/full-final.bundle`, SHA-256 `aa85a9beae933457b432b6bbd1d1af47b3bee6102a5001482693c6d91d0df1a9`, con clon/HEAD/TREE PASS. No volver a empaquetarlo si el código no cambia.
- ZIP RC2-R1 recibido por el Director: **85.174.612 bytes**; SHA-256 actual `c200a61bf64bb6524481904927c9cfdbf974b077f2b124c27861ccfe1abefe5c`. Tiene 14 entradas, CRC PASS. Sus **13 miembros presentes declarados** corresponden a tamaño/SHA/CRC del manifiesto, pero el miembro APK fue retirado después de generar el manifiesto. El SHA del ZIP originalmente anunciado `cceaf29b...` **no** corresponde a esta copia modificada. No declarar `MANIFEST_FULL_PASS` ni «APK incluida».
- Build registrado en `LOGS/build_dev_debug.log`: `flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev --no-pub --no-android-gradle-daemon --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process`, exit 0, Flutter 3.47.9, Dart 3.13.7, JDK17. En `LOGS/apk_audit.log` consta identidad/firmante debug; esto es evidencia **reportada**, no reinspección del APK físico por el Director.
- **APK esperada solo en Windows:** `mobile/build/app/outputs/flutter-apk/app-dev-debug.apk` bajo el clon aislado de la compilación RC2-R1. Tamaño **210.966.556 bytes**; SHA-256 `abc2ac3c6ec3536bc12e5bc45db199a67db161eab6a54eefa1a287030290d5a6`; applicationId `co.picoradar.app.dev`; versionName `1.0.1`, versionCode `2`; certificado debug SHA-256 `5435a892a30b3e5387e9ef6272f3b1c073ff1a9fe19741f1d5060200f680b78e`. **No confundir con APK de la instalación anterior del Mi A3.**
- Aprobaciones ya certificadas, **NO REPETIR SI EL CÓDIGO NO CAMBIA**: F0 custodia; F1 Flutter/Drift/OTA/UI; F2 Laravel 33/279; tres pruebas RC1 admin 3/36; protección schema2; G2 Laravel bytes→Flutter/Drift; build RC2-R1. Meta: motor único nacional `schema2`, municipios/ciudades/departamentos/pueblos por reglas y fuentes aprobadas, OTA de datos, no APK distinta por ciudad. `UNKNOWN/STALE` donde falte cobertura o vigencia; datos LAB 14 autoridades/33 DIVIPOLA/21 coberturas parciales/115 reglas **NO son cobertura nacional certificada**.

## 1. A — Localizar y preservar el APK existente (acción inicial, sin Gradle)

1. Comprobar una sola vez en la ruta conocida del build RC2-R1 y, si fue movido, consultar únicamente la carpeta `delivery` de esa tarea. Registrar ruta, tamaño y `Get-FileHash -Algorithm SHA256`. No hacer búsqueda recursiva por todo el disco ni copiar APK a varios ZIP.
2. Si existe y hash/tamaño coinciden: **`APK_LOCAL_VERIFIED`**. Inspeccionar con `aapt dump badging` y `apksigner verify --print-certs` únicamente si las herramientas ya están instaladas. Conservar el archivo original, no modificar ni re-firmar. **No volver a compilar**.
3. Si fue borrado solo del ZIP adjunto pero sigue en Windows: continuar directamente a la fase B. NO pedir al usuario que vuelva a adjuntar 211 MB.
4. Si también falta en Windows: `APK_LOCAL_MISSING`. Solo se autoriza UNA reconstrucción si el clon, Flutter 3.47.9/JDK17/cachés y el margen real de memoria comprometida (≥6 GiB) están disponibles, usando el comando ya probado arriba sin alterar lockfile, código, firma ni gradle.properties final. Si recursos insuficientes: registrar `BLOCKED_LOCAL_APK_MISSING` y continuar el trabajo documental útil; no fingir APK probada.

## 2. B — Ejecutar QA Android con un entorno **seguro y autorizado**

1. Prioridad: **emulador Android existente** y aislado, con datos sintéticos (consultar `emulator -list-avds` y RAM/commit una vez). NO instalar nuevo AVD de varios GiB ni reconfigurar Windows si faltan recursos; `EMULATOR_NOT_AVAILABLE` es resultado válido, no incidente a auditar.
2. Si hay emulador compatible y recursos: instalar únicamente `co.picoradar.app.dev` en ese emulador (`adb -s <ID_EMULADOR> install -r -t <RUTA_APK>`), validar package/debug certificate si herramientas disponibles y realizar este recorrido funcional **una vez**:
   - arranque sin crash y navegación **Inicio → Garaje → Conducir**;
   - alta de **vehículo sintético** en Garaje, cierre y reapertura, comprobar persistencia;
   - elegir jurisdicción y modalidad realmente cargada; comprobar que `UNKNOWN/STALE` **no** se presenta como autorización de circulación;
   - si el emulador de QA ya tiene fixture de OTA local aprobado, aplicar una revisión válida y comprobar actualización/último bueno; probar un SHA inválido solo si el flujo de QA existente lo permite sin tocar infraestructura real;
   - capturar una evidencia visual relevante y un segmento pequeño de logcat saneado. No subir placa, datos personales ni contenido de usuarios reales.
3. **Mi A3 físico:** NO ejecutar `adb`, instalar, desinstalar, borrar datos ni conectar al teléfono hasta autorización expresa del propietario para esta prueba. La firma dev actual podría no coincidir con la instalación anterior. Tras autorización futura, comparar paquete/firmante antes de intentar `adb install -r`; si difiere, marcar `HOLD_SIGNING_DATA_PRESERVATION`, **jamás** usar `adb uninstall`, `pm clear`, sustituir firma o borrar registros para forzar PASS. Este gate no impide QA en emulador.
4. Si el emulador no está disponible, registrar exactamente `RUNTIME_QA_BLOCKED_NO_AUTHORIZED_DEVICE` y conservar la APK existente. **No repetir los tests de widget/Drift como sustituto engañoso de QA real.**
5. Si existe fallo funcional comprobado en emulador, capturar la causa con un único log reproducible. Hacer **una reparación focal** solo si es claramente segura, dentro del motor/pantalla actual, con una prueba RED/GREEN ligada al fallo. Si el arreglo crea nuevo commit, proporcionar `git format-patch` pequeño basado en el HEAD RC2-R1 + SHA de archivos y ruta de aplicación/rollback; no modificar el checkout original. No ampliar alcance a refactor ni municipio nuevo.

## 3. C — Habilitación nacional y publicación: cierre de la brecha real, no otra auditoría

- Usar las pruebas y mapas de código existentes para una **única comprobación de estado**: cobertura editorial aprobada → snapshot que no pierde ciudades → manifest con SHA/revisión → cliente OTA/último bueno. RC1 y V6 ya certificaron contratos en QA; no volver a ejecutar 33 PHP/3 Flutter/G2 sin código modificado.
- Informar brecha remanente específica: **publicación en staging/CDN autorizado y prueba física** siguen sin certificarse. No desplegar a Hostinger ni publicar los 14 datos LAB como cobertura nacional total. Un anuncio oficial municipal/departamental es fuente suficiente para sus afirmaciones explícitas aunque no haya PDF de decreto; excepciones/horarios no documentados quedan `UNKNOWN` y jurisdicciones no habilitadas no se equiparan a circulación libre.
- GitHub: PR #79 contiene la documentación, NO el código RC1/RC2. El `HEAD 7e2e1f3...` no estaba publicado y existe `HOLD_SECURITY` por una referencia Power BI pendiente. **No realizar push, merge ni crear release mientras persista el hold**. No reabrir escaneo de 1.839 ficheros ni dar PASS ficticio. El avance del APK/QA puede continuar localmente sin publicar el histórico inseguro.

## 4. D — Entregar UN ZIP PEQUEÑO, sin duplicar el APK ni 85 MB de Git

Salida: `D:\codex\_REPORTES\PicoRadar\RC3-ANDROID-RUNTIME-20261115\delivery\PICORADAR_RC3_QA_ANDROID_EVIDENCIA_UNICA.zip`.

**Incluir únicamente:** `FINAL_REPORT.md` (resultado comprobado, bloqueo si existe, relación con RC2), `GATES.csv` (comandos y exits observados), `APK_REFERENCE.txt` (ruta local, SHA, tamaño, certificado, si existe; nunca los bytes APK), `ANDROID_RUNTIME_QA.md` (casos y resultados, emulador/estado autorización Mi A3), logs sanitizados pequeños, capturas si ayudan y `MANIFEST.csv` con SHA/tamaño/CRC de los miembros realmente incluidos. Si hubo corrección, incluir `PATCHES/*.patch` y sus SHA más la base Git a la que aplican; **no duplicar el bundle de 85 MB** mientras la historia no cambie. Documentar que para recuperar código completo se requiere el bundle ya entregado de RC2 con hash conocido y el patch delta nuevo, si existe.

**No incluir:** APK de 210,97 MB, ZIP RC2 completo, bundle V6/RC2 repetido, descargas Flutter de ~1,94 GB, reportes secretos Gitleaks, claves QA ni documentos privados. **No alterar un ZIP ya cerrado quitándole miembros sin regenerar manifiesto y SHA**, como ocurrió con RC2.

Validar el ZIP final contra sus archivos presentes (CRC, SHA-256, tamaño), informar SHA-256 real del ZIP y tamaño real; una sola entrega, sin ZIP preliminares. El informe debe separar **`BUILD_LOG_PASS`**, **`APK_LOCAL_VERIFIED`**, **`RUNTIME_QA_PASS/FAIL/BLOCKED`** y **`RELEASE_NO_GO`**.

Línea de cierre requerida:
`TASK_ID=PICORADAR-RC3-ANDROID-RUNTIME-QA-MINIMAL-EVIDENCE-20261115 | APK_LOCAL=... | ANDROID_RUNTIME=... | HEAD=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`

## 5. Límites obligatorios, sin pingpong

**NO** rediseñar el motor nacional, crear un motor por ciudad, reescribir el importador schema2, solicitar otro inventario de 1.104 municipios, volver a las 33 pruebas PHP, relanzar Flutter/Gradle cuando el APK existe, reabrir auditorías 10+10 antiguas, pedir nuevo ZIP de 300 MB, instalar en Mi A3 sin autorización, habilitar antivirus por la fuerza, ejecutar `.ps1` en cuarentena, usar CI de pago ni publicar producción. Si algo ajeno al objetivo falla, aislarlo y seguir con el próximo paso permitido del mismo macrobloque.

**QUIÉN SIGUE:** CODEX LUNA solo si no hay otro escritor activo. Después de su único ZIP, CHATGPT DIRECTOR. No crear RC4 automáticamente.