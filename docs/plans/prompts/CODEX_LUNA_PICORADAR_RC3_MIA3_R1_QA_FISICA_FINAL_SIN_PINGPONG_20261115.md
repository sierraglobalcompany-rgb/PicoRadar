# CODEX LUNA — PICO RADAR RC3 Mi A3 R1 | UNA QA FÍSICA SEGURA Y CIERRE FOCAL

**TASK_ID:** `PICORADAR-RC3-MIA3-R1-PHYSICAL-ONEPASS-20261115`  
**DIRECTOR:** ChatGPT. **EJECUTOR:** Codex Luna. **SIGUIENTE:** ChatGPT Director después de un solo ZIP pequeño.  
**ESTA ORDEN SUSTITUYE** a `CODEX_LUNA_PICORADAR_RC3_MIA3_QA_FISICA_SEGURA_20261115.md` **solo si no se ha iniciado**. Prohibido abrir otro escritor o volver a ejecutar RC3 original.  
**MISIÓN:** medir funcionamiento real en Xiaomi Mi A3 con prioridad ABSOLUTA de conservar vehículos/documentos/datos. Distinguir sin ambigüedad «APK RC2 ejecutada», «versión anterior observada» y «bloqueo de instalación». No iniciar otra auditoría ni una reconstrucción del proyecto.

## 0. Estado inmutable y evidencia reutilizada

- Candidato base RC1/RC2: `HEAD=7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`; `TREE=e312c7632fce4c43f9419cba60903e7420c46d85`. Bundle autocontenido ya entregado dentro de `PICORADAR_RC2R1_EVIDENCIA_UNICA.zip`; SHA256 del bundle `aa85a9beae933457b432b6bbd1d1af47b3bee6102a5001482693c6d91d0df1a9`. No copiarlo nuevamente ni modificar código. Si no se localiza el clon de RC2, usar el bundle SOLO como custodia en clon aislado; no reconstruir ni reabrir trabajo de producto.
- **APK LOCAL esperada:** `mobile\build\app\outputs\flutter-apk\app-dev-debug.apk` del clon RC2; **210.966.556 bytes**; SHA256 `abc2ac3c6ec3536bc12e5bc45db199a67db161eab6a54eefa1a287030290d5a6`; package `co.picoradar.app.dev`; versionName `1.0.1`, versionCode `2`; signer SHA256 `5435a892a30b3e5387e9ef6272f3b1c073ff1a9fe19741f1d5060200f680b78e`. Build debug y verificación local RC2/RC3 documentados, **pero no hay runtime del APK RC2 probado**. NO ejecutar Flutter, Gradle, suites Laravel/Drift/OTA, tests 33/279, tests RC1 ni otro build.
- Histórico Mi A3: hubo una instalación PicoRadar con vehículos persistidos; no asumir que sigue instalada, el mismo package, la misma firma o el mismo número actual. **El usuario dijo «ya desbloqueé el celular»**: permite preparar el QA físico y que el usuario acepte el permiso de depuración USB, **no** equivale a permiso para desinstalar, borrar, reducir versión, refirmar, liberar bootloader ni actualizar una app con datos sin una salvaguarda explícita.
- La aplicación tiene en `mobile/android/app/src/main/AndroidManifest.xml` **`android:allowBackup="false"`**. En consecuencia, NO exigir ni presentar `adb backup`/backup automático de Android como respaldo viable. El código de `AppShell` contiene cinco accesos: **Inicio, Garaje, Apps (overlay), Viaje, Conducir**. Nunca ejecutar Conducir en carretera real ni iniciar un seguimiento de viaje/GPS como condición del test.
- Las leyes del proyecto se conservan: motor **único schema2**, restricciones y servicios por datos oficiales de municipio/ciudad/departamento/pueblo, OTA con versiones habilitables, no hardcodes por ciudad, incertidumbre `UNKNOWN/STALE`; portal municipal/departamental oficial basta para campos expresos sin PDF de decreto. 14 autoridades/33 DIVIPOLA/21 coberturas parciales/115 reglas son LAB, NO certificación nacional. `PRODUCT_RELEASE=NO_GO`.

## 1. B0 — Una conexión ADB controlada, sin diagnósticos en bucle

1. Continuar en el **clon RC2 existente** si está disponible; confirmar HEAD/TREE y `git status --porcelain` una sola vez. No hacer búsquedas recursivas de todo `D:`. Si aparece WIP no tocarlo. Verificar SHA256/tamaño del APK local **una sola vez**. Si SHA, package o signer difieren, no instalar: resultado `APK_MISMATCH` y ZIP de bloqueo pequeño. Si está ausente, `APK_NOT_FOUND`; no recompilar ni borrar otros paquetes.
2. El usuario conecta **su Mi A3 por cable USB y desbloquea pantalla**. Pedirle, si hace falta, habilitar «Opciones del desarrollador → Depuración USB» y **aceptar personalmente** la solicitud RSA en la pantalla. NO pulsar ni aceptar en nombre del usuario; no cambiar opciones de seguridad ni usar fastboot/root/OEM unlock.
3. Comprobar herramientas ADB del Android SDK ya instalado; `adb devices -l` para listar. Si `unauthorized`, **permitir un único ciclo legítimo de interacción humana**: indicar «acepta la ventana RSA en tu teléfono», y repetir `adb devices -l` **una sola vez**. Si sigue `unauthorized/offline` o sin conexión: `BLOCKED_ADB_PERMISSION_OR_CONNECTION`, generar ZIP pequeño con pasos del usuario. No usar `adb kill-server`, reinicios forzosos, reinstalación de drivers ni diagnóstico infinito.
4. Si hay varios dispositivos, determinar inequívocamente el Mi A3 por `adb -s SERIAL shell getprop ro.product.model` y `ro.product.device` (esperado Mi A3 / `laurel_sprout`). Guardar `SERIAL` **solo en variable local**, redactarlo en ZIP/logs. Si identidad no concluyente: STOP. Desde aquí **TODOS los comandos ADB sobre el teléfono usan `-s SERIAL`**; nunca `-d` ambiguo ni comandos sobre otros dispositivos.
5. Lecturas puntuales sin PII: `ro.build.version.sdk`, batería suficiente, espacio disponible, `pm path co.picoradar.app.dev`, `pm path co.picoradar.app` (por si prod está instalada como app separada), versión e identificador de paquete en `dumpsys package` filtrado. **No extraer Drift, datos privados, matrículas, fotos, contactos ni ubicaciones**. Verificar capacidad libre antes de instalar APK de 211 MB y margen razonable para extracción/instalación. No declarar que un teléfono está vacío a partir de `pm path` de un package distinto.

## 2. B1 — Matriz de instalación; nunca destruir registros

**RUTA A — `co.picoradar.app.dev` NO está instalado:** si la identidad APK y el Mi A3 coinciden, la memoria del teléfono es suficiente y el usuario mantiene disponible el dispositivo para QA, permitir **UNA nueva instalación** de `co.picoradar.app.dev` mediante `adb -s SERIAL install <RUTA_APK_VERIFICADA>` (añadir `-t` únicamente si Android informa `testOnly`). Esto crea app dev separada de `co.picoradar.app` si aquella está instalada; no tocar la app prod. Confirmar después por package/version y signer cuando sea posible. Si falla, STOP sin borrar nada.

**RUTA B — `co.picoradar.app.dev` YA está instalado:** la app previa puede contener vehículos y pertenecer a otra firma.

1. Registrar solo **conteo observable** y versión existente; no leer/registrar matrículas. Para conocer la firma instalada, usar una interfaz de lectura fiable o `adb -s SERIAL shell pm path co.picoradar.app.dev` + extracción SOLO del `base.apk` **si es estrictamente necesario y existe espacio en disco**. Si se extrae, situarlo en carpeta temporal PRIVADA de QA en `D:` y ejecutar `apksigner verify --print-certs` LOCAL; nunca copiar el APK extraído al ZIP o a GitHub. No extraer datos de la aplicación. La huella del certificado NO es el SHA256 del archivo APK: comparar certificado con certificado.
2. Si **firma no coincide, es desconocida, versión implica downgrade, package varía, falta espacio o falla una comprobación**, `APK_RC2_INSTALL=BLOCKED_SIGNATURE_OR_IDENTITY`. **No hacer `adb uninstall`, `pm clear`, `install -r`, `install -d`, root, eliminación de datos ni alteración de firmas.** Continuar directamente B2 (QA observacional de la versión instalada) con etiqueta estricta `INSTALLED_OLD_VERSION_ONLY`; NO certificar APK RC2.
3. Si **firma coincide** y versión RC2 >= instalada, **NO se da automáticamente por segura la actualización**. Dado `allowBackup=false`, no inventar backup. Solo instalar con `adb -s SERIAL install -r <RUTA_APK_VERIFICADA>` si existen **ambas** condiciones: a) respaldo/restauración de datos previamente verificado por un mecanismo legítimo concreto **o** confirmación expresa adicional del propietario, informado de que el `-r` normalmente preserva datos pero una migración puede fallar; b) compatibilidad concreta de migración del esquema/versión conocida, sin depender únicamente de que firme igual. Si falta una, NO instalar; pasar a B2 observacional y reportar `INPLACE_UPDATE=REQUIRES_OWNER_DECISION` en el ZIP. Una sola solicitud de decisión, sin interrumpir el resto del trabajo útil.
4. Ante cualquier error `INSTALL_FAILED_*`, STOP, preservar estado; no “arreglar” con desinstalación, firmas nuevas o borrado. Si hubo instalación, registrar package + versión y distinguir **nueva instalación**, **actualización autorizada** o **sin instalación**.

**Dato de seguridad:** no realizar acciones de modificación de datos en una instalación previa no respaldada (ni siquiera crear/eliminar un vehículo sintético) durante este bloque. Queda prohibida la opción de borrar y reinstalar por conveniencia. La observación puede continuar aunque B1 quede HOLD.

## 3. B2 — Una única sesión física, aprovechando lo que sea seguro

- Si la **APK RC2 fue instalada/actualizada y su identidad comprobada**, `RUNTIME_SCOPE=RC2_APK`; si solamente se ejecuta la app que ya estaba instalada, `RUNTIME_SCOPE=PREEXISTING_APP_ONLY`; si no hay app accesible, `RUNTIME_SCOPE=NOT_TESTED`. Estos tres estados **no se pueden fusionar**.
- Lanzar por icono o actividad de launch confirmada, por ejemplo `adb -s SERIAL shell am start -n co.picoradar.app.dev/co.picoradar.app.MainActivity` **solo si el package dev está instalado**. Alternativamente abrir manualmente la app en el teléfono. No generar 1.000 eventos aleatorios con monkey. Solo una sesión; confirmar visualmente si abre y si hay crash; logcat focal únicamente si hay anomalía, con saneamiento de serial, rutas personales, notificaciones, matrículas y coordenadas.
- Recorrido observado: **Inicio → Garaje → Apps (comprobar que abre/cierra el overlay, no asumir pantalla navegable) → Viaje → Conducir (solo abrir/cerrar sin activar seguimiento GPS) → Garaje**. Registrar PASS/FAIL/NOT_TESTED por pestaña, nunca PASS por el solo arranque. Si la versión previa difiere, registrar las pestañas reales que existan. No habilitar servicios externos ni conceder permisos sensibles sin necesidad.
- **Preservación:** anotar únicamente conteo agregado de vehículos al comenzar y al terminar, sin placas. Reabrir app normalmente (sin `force-stop` de otros paquetes) y comprobar que registros previos siguen visibles. Un conteo idéntico es **evidencia parcial**, no garantiza integridad de todos los documentos ni de Drift. Si se instaló de cero la app dev y está vacía, permitir **como máximo un vehículo obviamente sintético** cuando sea claramente distinguible y su retirada posterior segura; no introducir datos reales. No mutar la app preexistente.
- **Motor de restricciones:** observar UNA consulta existente de pico y placa y su jurisdicción si está disponible; nunca inventar rotaciones ni cambiar reloj/GPS. Comprobar que datos `UNKNOWN/STALE` no se convierten en promesa de circulación; si no hay un caso observable, marcar `NOT_TESTED` en vez de simular legalidad. **OTA física solo si ya existe endpoint QA seguro y preparado**, sin usar CDN productivo ni sobrescribir el dataset bueno; de lo contrario `OTA_PHYSICAL=NOT_TESTED_ENDPOINT`, conservar solo G2 LAB PASS.
- Si un fallo real se reproduce en el **APK RC2** y se puede aislar, `APP_DEFECT=OBSERVED` con mínima secuencia y log saneado; STOP sin nuevas builds ni tareas de reparación automáticas. Si falla una versión anterior no atribuir el defecto al APK RC2.

## 4. B3 — Un ZIP pequeño y decisión honesta

**Única entrega:** `D:\codex\_REPORTES\PicoRadar\RC3-MIA3-R1-20261115\delivery\PICORADAR_RC3_MIA3_R1_EVIDENCIA_UNICA.zip`.

Contenido exacto y suficiente: `FINAL_REPORT.md`, `GATES.csv`, `ANDROID_OBSERVATIONS.md`, `APK_IDENTITY_REFERENCE.txt`, `LOGS/adb_preflight_sanitized.txt` y `LOGS/runtime_focal_sanitized.txt` (vacío o `NOT_RUN` si no procede), `MANIFEST.csv` con ruta/tamaño/SHA256/CRC32 de los demás miembros. Ningún otro ZIP en `delivery`, máximo **dos** capturas redactadas SIN placas, imágenes personales ni datos; preferible sin capturas si ello aumenta riesgo. **Excluir** APK de 211MB, bundle Git de 85MB ya custodiado, archivos Gitleaks `.private.json`, `base.apk` extraído, cachés, IDs ADB/serial, coordenadas, placas, documentos e información privada; no pegar secretos ni hashes de placas.

Registrar explícitamente: `ADB`, `DEVICE_IDENTITY`, `APK_LOCAL_SHA`, `INSTALLED_PACKAGE`, `OLD_SIGNER_MATCH`, `INSTALL_ACTION`, `RUNTIME_SCOPE`, `STARTUP`, cada una de las cinco pestañas, `VEHICLES_COUNT_BEFORE_AFTER` (solo números), `DATA_PRESERVED_SCOPE`, `UNKNOWN_STALE`, `OTA_PHYSICAL`, `APP_DEFECT`, razón de HOLD y **acción humana única** si hace falta. Señalar `CHECKOUT_UNCHANGED=YES` solo cuando realmente se compruebe. **No repetir tests históricos** ni descargar SDK; una ejecución focal, un ZIP compacto. Validar el ZIP resultante por CRC, tamaños, SHA256 y extracción del manifiesto (que no enumere binarios excluidos); calcular SHA256 final del ZIP. Entregar ruta ZIP, hash y resumen en una línea.

**GATES OBLIGATORIOS:** `RELEASE=NO_GO`, `GITHUB_PRODUCT=HOLD_SECURITY` (sin push), `RELEASE_SIGNING=NOT_READY_DEBUG_KEY` (no generar clave ni APK release), `NATIONAL_COVERAGE=LAB_PARTIAL`, `NEXT_ACTOR=CHATGPT_DIRECTOR`.

**Línea final:** `TASK_ID=PICORADAR-RC3-MIA3-R1-PHYSICAL-ONEPASS-20261115 | ADB=... | INSTALL_ACTION=... | RUNTIME_SCOPE=... | APP_DEFECT=... | DATA_PRESERVED_SCOPE=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`.

## 5. Auditoría adversarial del DIRECTOR cerrada: 10 VERDUGO + 10 JUEZ (NO DELEGAR)

**10 pasadas como VERDUGO — defecto concreto encontrado en el prompt anterior:**

| V | Defecto y efecto que se eliminó |
|---|---|
| V01 | Interpretar «desbloqueé» como autorización para borrar o actualizar una app con vehículos: ahora solo habilita inspección y permiso RSA en pantalla. |
| V02 | `adb devices` terminaba en `unauthorized` sin dar ocasión a aceptar RSA: ahora hay una sola repetición humana controlada. |
| V03 | Comandos sobre dispositivo ambiguo podían modificar otro Android: ahora hay validación de Mi A3 y `-s SERIAL` en todos. |
| V04 | Mezclar SHA del archivo APK con huella de certificado: la firma se compara únicamente con firma verificada de ambos APK. |
| V05 | Exigir respaldo automático imposible con `android:allowBackup=false`: ahora se prohíbe inventarlo. |
| V06 | Firma distinta llevaba a un bloqueo sin utilidad: ahora se permite QA read-only de versión instalada, diferenciada de APK RC2. |
| V07 | Confundir una observación de versión vieja con PASS de RC2: `RUNTIME_SCOPE` y `INSTALL_ACTION` evitan el falso positivo. |
| V08 | Tratar Apps como pantalla normal: el `AppShell` usa un overlay y se inspecciona como tal. |
| V09 | Crear vehículo sintético sobre datos reales y contaminar el Garaje: solo se permite en dev nuevo y vacío, si es reversible. |
| V10 | Empaquetar otra vez APK/bundle provocaba ZIP enorme/manifiesto roto: ahora ZIP pequeño con miembros reales y hashes. |

**10 pasadas como JUEZ — decisión de ingeniería y condición de aceptación:**

| J | Decisión aprobada y por qué es suficiente |
|---|---|
| J01 | Mantener HEAD/TREE, APK SHA y PASS previos por referencia: elimina repetición de suites sin perder custodia. |
| J02 | Solo una autorización ADB, sin root/bootloader/fastboot: mínimo acceso necesario. |
| J03 | Instalar dev nuevo únicamente si no existe ese package y la identidad es inequívoca: no afecta una app prod separada. |
| J04 | Una actualización `-r` exige compatibilidad y salvaguarda/consentimiento adicional informado: la firma idéntica no garantiza migración segura. |
| J05 | En app preexistente, observación sin mutación y conteo agregado: útil sin exponer documentos ni matrículas. |
| J06 | Una sola sesión Inicio/Garaje/Apps/Viaje/Conducir y retorno: evidencia runtime, no prueba de navegación simulada. |
| J07 | Contar registros antes/después aporta evidencia parcial, sin afirmar integridad total de Drift: conclusión proporcional. |
| J08 | UNKNOWN/STALE y OTA se certifican físicamente solo cuando pueden observarse con fuente/endpoint QA seguro: no inventar PASS. |
| J09 | Separar APK debug de firma release y mantener GitHub HOLD: QA físico no autoriza despliegue ni publicación. |
| J10 | Un ZIP sanitizado con PASS/HOLD por caso y NEXT_ACTOR director: cierre operacional, sin RC4 ni auditoría adicional. |

**PROHIBIDO** iniciar «RC4», proponer una segunda auditoría o generar más prompts en esta sesión. Codex hace el trabajo físico permitido, entrega **un único ZIP** y cede la dirección a ChatGPT. **NEXT_ACTOR=CODEX LUNA solo para esta orden; después CHATGPT DIRECTOR**.