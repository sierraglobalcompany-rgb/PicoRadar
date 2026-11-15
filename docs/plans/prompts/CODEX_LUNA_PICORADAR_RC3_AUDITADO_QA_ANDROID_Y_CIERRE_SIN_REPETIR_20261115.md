# CODEX LUNA — PICORADAR RC3 AUDITADO R1 — QA ANDROID REAL, SIN REPETICIONES NI ZIP GIGANTE

**TASK_ID INALTERADO:** `PICORADAR-RC3-ANDROID-RUNTIME-QA-MINIMAL-EVIDENCE-20261115`  
**REVISIÓN DEL PROMPT:** R1 (sustituye exclusivamente el RC3 anterior si NO ha comenzado).  
**DIRECCIÓN:** ChatGPT decide arquitectura, alcance y gates; **Codex Luna ejecuta**.  
**RESULTADO EXIGIDO:** evidencia concreta de APK local y ejecución Android, o un **bloqueo único reproducible** con la acción externa precisa; **UN SOLO ZIP PEQUEÑO**.  
**NEXT_ACTOR:** `CHATGPT_DIRECTOR` al regresar el ZIP. No abrir RC4 ni nueva auditoría por iniciativa propia.

## 0. Identidad, hechos cerrados y límites

1. Candidato: `HEAD=7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`, `TREE=e312c7632fce4c43f9419cba60903e7420c46d85`, rama local RC2-R1 `feat/picoradar-rc2-r1-apk-real`. No reemplazar con `main` remoto; este SHA aún no existe en GitHub. Preservar checkout original.
2. El ZIP RC2-R1 que recibió ChatGPT mide **85.174.612 bytes**, SHA-256 **`c200a61bf64bb6524481904927c9cfdbf974b077f2b124c27861ccfe1abefe5c`**. Tiene **14 miembros en ZIP y 13 presentes coincidentes con manifiesto**. El manifiesto también declara `APK/app-dev-debug.apk`, **eliminado del ZIP por el usuario**, por lo que ese ZIP NO es íntegro frente a su manifiesto. Nunca reutilizar el SHA del ZIP antiguo `cceaf29b...` como si perteneciera al archivo adjunto.
3. Bundle RC2-R1 conservado en ese ZIP: `GIT/full-final.bundle`, SHA-256 **`aa85a9beae933457b432b6bbd1d1af47b3bee6102a5001482693c6d91d0df1a9`**. Su restauración a HEAD/TREE en clon limpio ya pasó. **No volver a incluir sus 85 MB** en el ZIP RC3 sin nuevo historial Git.
4. Compilación RC2-R1 **PASS_DEBUG acreditada por logs**, no por reinspección directa del binario adjunto: Flutter 3.47.9/Dart 3.13.7, JDK17, comando del README, `assembleDevDebug` exit0. Identidad reportada: paquete `co.picoradar.app.dev`, `versionName 1.0.1`, `versionCode 2`, minSdk24/targetSdk36, firma Android Debug v2 cert SHA-256 `5435a892a30b3e5387e9ef6272f3b1c073ff1a9fe19741f1d5060200f680b78e`.
5. **APK buscada EN WINDOWS** bajo el CLON de RC2-R1: `mobile\build\app\outputs\flutter-apk\app-dev-debug.apk`, tamaño exacto **210.966.556 bytes**, SHA-256 **`abc2ac3c6ec3536bc12e5bc45db199a67db161eab6a54eefa1a287030290d5a6`**. El APK pudo borrarse solo del ZIP o también del disco; comprobar, no adivinar. No mandar sus 211 MB a ChatGPT.
6. Pasadas/NO REPETIR en mismo código: Laravel 33 tests/279 assertions (V5); RC1 guard schema2, importador y 3 admin focales; Flutter/Drift/OTA/UI (V4), G2 bytes Laravel→Flutter (V6), build RC2-R1. Ninguna de ellas sustituye QA real Android.
7. Meta invariable: **UN motor nacional `schema2`** con reglas/datos habilitables por ciudad, municipio, departamento, centro poblado y modalidad; publicación OTA ordinaria sin nueva APK por ciudad, no parches/ramas de motor independientes. Fuente oficial municipal/departamental suficiente para **los campos que publica expresamente**, sin exigir PDF por defecto. Ante datos desconocidos, incompletos o vencidos, mantener `UNKNOWN/STALE`, jamás afirmar permiso de circulación. 14 autoridades / 33 DIVIPOLA / 21 coberturas parciales / 115 reglas = **LAB**, no cobertura nacional completa.
8. PR documental #79 no incorpora el código de producto. `HOLD_SECURITY` impide push del histórico local y `release=NO_GO`. No modificar main, PR71, PR79 por cuenta propia, remoto, firma de distribución, Hostinger, CDN real, BD productiva ni datos del Mi A3. No ejecutar `.ps1` en cuarentena ni descargar software por rutina. Bitdefender desactivado es dato conocido; **no abrir otra auditoría sobre antivirus**, pero tampoco declararlo seguro.

## 1. B0 — Custodia rápida y APK LOCAL, sin repetir build

- Desde el clon aislado **ya existente** de RC2-R1, verificar una vez `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git status --porcelain` y que no exista otro escritor PicoRadar. Si falta el clon, restaurar una copia en carpeta nueva desde el bundle conocido; registrar comando de restauración, NO reconstruir historia desde `main` remoto.
- Buscar el APK **solo** en `mobile\build\app\outputs\flutter-apk\app-dev-debug.apk` del clon que efectivamente hizo el build y luego la carpeta `delivery` de RC2-R1. No escanear todo `D:` ni copiarlo a varios directorios. Registrar ruta relativa o ruta local saneada, tamaño y `Get-FileHash -Algorithm SHA256`. Exigir ambos valores exactos; un APK de otra versión/firma NO es equivalente.
- Si existe y coincide: `APK_LOCAL=VERIFIED`. Con `aapt dump badging`/`apksigner verify --print-certs` si ya están disponibles, reconfirmar ID/firma (sin re-firmar). **No ejecutar Gradle, pub get, suites ni creación de ZIP con APK**.
- Si falta: `APK_LOCAL=MISSING`; se permite **una sola reconstrucción** EXCLUSIVAMENTE si Flutter 3.47.9, JDK17, SDK/cachés, checkout correcto y memoria comprometida libre actual ≥6 GiB están disponibles. Emplear el comando de build dev-debug que pasó en `LOGS/build_dev_debug.log`, sin upgrade ni cambios persistentes en `gradle.properties` o `pubspec.lock`. Revisar SHA/identidad del nuevo artefacto; si nuevo hash, dejar nuevo hash verificable y causa (no falsificar anterior). Si falta memoria o toolchain, `APK_LOCAL=BLOCKED_ENV`, y continuar al cierre sin inventar prueba de ejecución. No repetir la compilación a ciegas.
- **Corregir defecto del prompt anterior:** la ruta exacta del clon RC2-R1 no está demostrada en el ZIP; identificarla por HEAD y registro original, no asumir directorio inventado. La búsqueda puntual es suficiente.

## 2. B1 — Un QA Android sobre emulador DISPONIBLE, no prueba decorativa

**PRECONDICIÓN:** `APK_LOCAL=VERIFIED` y emulador de QA ya instalado y dedicado a datos **sintéticos**, sin registros reales. La app tiene pestañas reales `Inicio`, `Garaje`, `Apps`, `Viaje`, `Conducir` (`mobile/lib/app/shell/app_shell.dart`). No confundir `Viaje` con `Conducir` ni llamar prueba física a un widget test.

1. Preflight **una vez** con binarios ya instalados del Android SDK: listar AVDs (`emulator -list-avds`), procesos emulador y memoria comprometida/disco libres, sin instalar nuevos sistemas Android ni alterar pagefile. Si el único AVD contiene datos de usuario o no está identificado como QA, no usarlo. Si requiere más memoria que la disponible o almacenamiento insuficiente, `ANDROID_RUNTIME=BLOCKED_NO_SAFE_AVD`, seguir a B2/D; no abrir otro diagnóstico.
2. Si hay un AVD dedicado y recursos reales suficientes, iniciar SOLO ese emulador (o utilizarlo ya arrancado). Confirmar el serial `emulator-...` en `adb devices -l`; **todos los comandos ADB deben llevar `-s <serial_emulator_confirmado>`**. No dirigir comandos a dispositivos físicos aunque aparezcan conectados, no usar `-d` ni `adb -e` implícito. Nunca `-wipe-data`, `uninstall`, `pm clear`, `adb root` o `install -r` contra un emulador con datos no sintéticos.
3. Verificar que el paquete dev no esté instalado con datos ajenos. Instalar `app-dev-debug.apk` **solo** en el AVD QA, `adb -s <serial> install -t <ruta-apk>` para instalación nueva; si ya hay una versión QA anterior, primero medir firma/identidad y preservar sus datos, y solo usar `-r` cuando el AVD sea explícitamente desechable y la firma sea compatible. No borrar datos para obtener PASS.
4. Realizar un recorrido **observable**, con capturas y logcat focal, en una ejecución: arranque sin crash; `Inicio → Garaje → Viaje → Conducir` (visitar `Apps` si está accesible y sin datos externos), volver a Garaje; crear un vehículo **sintético**, cerrar y reabrir y comprobar persistencia; seleccionar una jurisdicción/servicio presentes en datos QA; cuando la información es vencida/parcial/ausente, verificar que la UI NO muestra «puede circular» como certeza. No simular movimiento real ni utilizar GPS del usuario. Evitar fechas adivinadas de pico y placa; usar estado de dataset visible o fixture local comprobado.
5. Si el AVD YA tiene un flujo OTA local aprobado y seguro, comprobar una actualización válida y rechazo de SHA inválido manteniendo last-good. **Si no está disponible, `OTA_ON_EMULATOR=NOT_TESTED_LOCAL_FIXTURE_MISSING`**, conservar el PASS G2 de bytes en QA sin afirmar OTA física probada. No desplegar infraestructura ni inventar fixtures para forzar una prueba.
6. Registrar PASS **por subcaso observado**, con fecha/hora, package ID, serial de EMULADOR (no físico), logs pequeños redactados y 1–3 capturas sintéticas. Si hay crash o pérdida de datos real, captura logcat y pasos mínimos; se permite **una sola reparación causal acotada** si la causa es inequívoca, con test focal RED/GREEN. No refactor del motor ni actualizar reglas por ciudad. Si la reparación cambia código, crear **un solo commit aislado o patch**, documentar HEAD/TREE nuevos, pruebas afectadas y SHA del artefacto reconstruido. Una APK antigua NO certifica un commit nuevo: si no se puede volver a compilar, dejar `RUNTIME_QA=FAIL_ON_OLD_APK` y `FIX_NOT_BUILT`.
7. Si NO hay AVD seguro, `ANDROID_RUNTIME=BLOCKED_NO_SAFE_AVD` y registrar **una sola decisión para el propietario**: autorizar QA física controlada en el Xiaomi Mi A3 **O** facilitar un AVD/equipo apto. **No intentar ADB ni instalar en el Mi A3** en este macrobloque sin autorización explícita; primero comparar firma de la instalación existente para no perder sus vehículos. Esto no significa que la app esté defectuosa.

## 3. B2 — Único cierre útil y no inventar trabajo nacional

- No volver a ejecutar pruebas F0/F1/F2/G2/RC1 sobre mismo HEAD. No crear reportes nuevos de «auditoría nacional» ni otro publicador. Los gates previos respaldan solamente QA aislada de schema2 y último bueno; **staging real/CDN, permisos de administrador remoto, snapshot íntegro de fuentes aprobadas y su rollback productivo siguen NO CERTIFICADOS**.
- Si `ANDROID_RUNTIME=PASS`, dejar matriz mínima de gates de lanzamiento como tabla de hechos (Android emulador PASS, QA Mi A3 pendiente, firma release pendiente, staging/OTA real pendiente, seguridad remoto HOLD, cobertura nacional aún parcial). Si `ANDROID_RUNTIME=BLOCKED`, no simular el PASS con más tests: registrar el único recurso/autorización necesaria y cerrar.
- **Hallazgo de código confirmado por el Director:** `mobile/android/app/build.gradle.kts` configura `buildTypes.release.signingConfig = signingConfigs.getByName("debug")`. Esto es apto SOLO para el flujo debug heredado; **NUNCA** declarar una variante release de distribución lista mientras firme con clave debug. No cambiar a clave inventada ni usar credenciales de producción; esto queda como gate específico de firma de release para el futuro.
- El producto final seguirá usando un motor `schema2` general; los datos habilitables provienen de publicaciones oficiales municipales/departamentales para los campos explícitos, sin crear hardcodes por ciudad ni prometer «nacional completo» desde el LAB parcial. `PRODUCT_RELEASE=NO_GO`.

## 4. B3 — ENTREGA: un solo ZIP pequeño, íntegro, con salida inequívoca

**Única ruta de salida:** `D:\codex\_REPORTES\PicoRadar\RC3-ANDROID-RUNTIME-20261115\delivery\PICORADAR_RC3_QA_ANDROID_EVIDENCIA_UNICA.zip`.

**Incluir:**
- `FINAL_REPORT.md`: resultados observados, límites QA vs release y `NEXT_ACTOR`.
- `GATES.csv`: prueba/estado/exit real/log o razón concreta de bloqueo.
- `APK_REFERENCE.txt`: hash/tamaño/paquete/firma verificados localmente o estado de ausencia, **sin los bytes del APK**.
- `ANDROID_RUNTIME_QA.md`: lista de subcasos y resultado, identidad del AVD QA o bloqueo específico; autorización Mi A3=NO.
- `LOGS/` mínimos saneados (máximo 1–2 MB total), `CAPTURES/` 1–3 capturas exclusivamente sintéticas si se ejecutó AVD.
- `PATCHES/` solo si hay modificación; parche Git respecto a base conocida y `git apply --check` probado en **clon desechable** con un resumen de HEAD/TREE, SHA del parche y si la nueva APK fue realmente compilada.
- `MANIFEST.csv`: un renglón por todos los miembros **excepto el propio manifiesto** (`path,bytes,sha256,crc32`); validar contra ZIP cerrado que no falte ningún miembro ni haya extras, y confirmar extracción, CRC y SHA del ZIP final.

**PROHIBIDO INCLUIR:** APK 211 MB, bundle Git 85 MB ya recibido, SDK Flutter 1,94 GB, reportes de Gitleaks `.private.json`, tokens, datos del Mi A3, ZIP anterior u otro ZIP preliminar. Si el commit nuevo requiere historia adicional, devolver parche delta autocontenido contra bundle RC2 conocido; no perder el punto de recuperación.

**Línea de cierre única:**
`TASK_ID=PICORADAR-RC3-ANDROID-RUNTIME-QA-MINIMAL-EVIDENCE-20261115 | APK_LOCAL=... | ANDROID_RUNTIME=... | OTA_ON_EMULATOR=... | HEAD=... | TREE=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`

**Detención:** no generar otro prompt RC4 ni abrir auditoría 10+10. Tras este ZIP el Director decide si el único paso faltante es autorización Mi A3, entorno Android, seguridad remoto, staging o firma de publicación.

---

## APÉNDICE — AUDITORÍA DEL DIRECTOR REALIZADA (NO TRABAJO PARA CODEX)

**10 pasadas VERDUGO — defectos localizados y corregidos:**

V01. APK excluida del ZIP → la integridad del original NO es PASS: congelar hashes reales y no volver a enviar binario.  
V02. Ruta del clon desconocida → localizar por HEAD/log RC2, no ruta inventada ni búsqueda de todo D:.  
V03. `adb install -r -t` indiscriminado → reemplazar por nueva instalación en AVD QA y `-r` solo con condiciones explícitas.  
V04. Serial ADB ambiguo → obligar `-s emulator-...` y excluir teléfono físico.  
V05. Navegación original omitió `Apps` y mezcló `Viaje/Conducir` → usar pestañas reales del shell.  
V06. Emulador existente no implica aislado → exigir AVD dedicado, datos sintéticos y preflight RAM/disco.  
V07. APK ausente puede forzar bucle build → una reconstrucción con recursos y toolchain ya verificados, no reinstalar SDK.  
V08. QA OTA no necesariamente accesible en emulador → diferenciar `NOT_TESTED` de `PASS`.  
V09. Arreglo de código con APK anterior rompe trazabilidad → ligar código, HEAD y nuevo build o marcar no probado.  
V10. Release Gradle firmado debug → dejar P0 firma de distribución fuera del PASS debug.

**10 pasadas JUEZ — decisión adversarial y criterio de salida:**

J01. Mantener RC3 como tarea única, solo versión R1; no crear RC4.  
J02. Conservar F0/F1/F2/G2/RC1 PASS solo al mismo SHA; no repetir suites.  
J03. Un APK real identificado por SHA aporta más que otro informe: primera acción exacta.  
J04. Un AVD existente pero con datos de terceros NO es autorización: prohibir limpieza.  
J05. Si no hay AVD, dar al propietario una alternativa precisa, no otra investigación.  
J06. No extrapolar QA del emulador a Mi A3 o firma release.  
J07. No llamar «circulación permitida» a faltantes, caducidad o cobertura parcial.  
J08. No publicar rama histórica con HOLD_SECURITY ni ocultar hallazgos privados.  
J09. Un ZIP pequeño con manifiesto completo reemplaza la repetición del bundle y APK.  
J10. Solo avances observables o bloqueos externos concretos; `NEXT_ACTOR` director y fin del bucle.

**QUIÉN CONTINÚA: CODEX LUNA SI NO HAY OTRO ESCRITOR PICORADAR ACTIVO. DESPUÉS DEL ÚNICO ZIP: CHATGPT DIRECTOR.**