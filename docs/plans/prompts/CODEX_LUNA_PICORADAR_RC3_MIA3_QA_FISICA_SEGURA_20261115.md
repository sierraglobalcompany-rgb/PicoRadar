# CODEX LUNA — PICORADAR RC3 · QA FÍSICA CONTROLADA EN XIAOMI MI A3

**TASK_ID:** `PICORADAR-RC3-MIA3-PHYSICAL-RUNTIME-QA-ONEPASS-20261115`  
**Director:** ChatGPT. **Ejecutor:** Codex Luna. **NEXT_ACTOR:** `CHATGPT_DIRECTOR` tras el ZIP.  
**Objetivo:** demostrar el arranque, navegación y persistencia de PicoRadar en el teléfono **sin destruir la instalación ni los datos existentes**. Una sola sesión, sin auditorías generales.

## 0. Hechos cerrados: NO REPETIR

- El usuario comunicó «ya desbloqueé el celular» después de que se propusiera QA en el Xiaomi Mi A3. Trátalo como **disponibilidad del dispositivo para inspección no destructiva**, no como permiso para borrar datos, modificar bootloader ni reemplazar una instalación de firma diferente.
- HEAD del código y de la APK: `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`; TREE `e312c7632fce4c43f9419cba60903e7420c46d85`. No actualizar producto ni volver a ejecutar F0/F1/F2/G2/RC1/RC2/RC3.
- APK debug local esperada: `mobile\build\app\outputs\flutter-apk\app-dev-debug.apk`; **210966556 bytes**, SHA-256 `abc2ac3c6ec3536bc12e5bc45db199a67db161eab6a54eefa1a287030290d5a6`, package `co.picoradar.app.dev`, versión `1.0.1 (2)`, certificado de firma debug SHA-256 `5435a892a30b3e5387e9ef6272f3b1c073ff1a9fe19741f1d5060200f680b78e`. Reutilizar APK; NO compilar nuevamente ni incluirla en ZIP.
- RC3 cerró `BLOCKED_NO_SAFE_AVD`; **no intentar el emulador**. APK existente y hash verificados por Codex en RC3. El teléfono NO fue intervenido anteriormente en RC3.
- No bootloader, fastboot, root, modo recuperación, factory reset, `adb uninstall`, `adb shell pm clear`, `adb install -d`, `-g` indiscriminado ni `-r` sin comprobaciones. No desactivar antivirus, no publicar GitHub/Hostinger/CDN, no usar credenciales productivas. El usuario no ha autorizado borrar vehículos ni reinstalar desde cero.

## 1. Preparación mínima de Windows y Android — no desviarse

1. Localiza la APK desde el clon **exacto** identificado en RC3 (no hacer búsqueda completa de `D:`), verifica una vez `Get-FileHash -Algorithm SHA256`, tamaño y firma con `apksigner verify --print-certs` si está disponible. Si no coincide, **detener instalación** e informar `APK_IDENTITY_MISMATCH`. No ejecutar Gradle.
2. Conectar **por USB** el Xiaomi Mi A3 encendido y desbloqueado. Si Windows no tiene acceso ADB, indicar al usuario que habilite **Opciones de desarrollador → Depuración por USB** y acepte **en el teléfono** el diálogo de autorización RSA. No pulsar ni eludir el permiso por él. Desbloquear pantalla ≠ habilitar ADB. No hace falta desbloquear el bootloader.
3. `adb devices -l` una vez. Si el estado es `unauthorized` / `offline` / sin dispositivo, terminar con `BLOCKED_ADB_AUTH` y pasos exactos para el usuario; **no bucle de drivers/comandos ni intervención adicional**. Si hay más de un dispositivo, identificar primero el Mi A3 por `adb -s <serial> shell getprop ro.product.model` y `ro.product.device` (Mi A3 / `laurel_sprout`), y elegir un solo serial. Todos los comandos posteriores deben incluir `-s <serial_MiA3>`. **Redactar el serial en informes**.
4. Lecturas del teléfono: SDK, batería suficiente, espacio libre aproximado, package `co.picoradar.app.dev` con `adb -s <serial> shell pm path co.picoradar.app.dev`; registrar instalación sí/no y versión actual con `dumpsys package` focal redactado. **No extraer archivos privados, bases Drift, contactos, coordenadas, identificadores ni imágenes personales**.

## 2. Decisión binaria de instalación sin pérdida de datos

- **CASO A — No existe `co.picoradar.app.dev` en el teléfono:** se permite **una nueva instalación** con `adb -s <serial> install <apk_verificada>` (si testOnly lo exige, añadir solo `-t`). Nunca `uninstall` ni `clear`. Si hay fallos de almacenamiento, permiso, políticas o firma, STOP con causa; no forzar.
- **CASO B — La app ya existe:** por la QA física histórica hay posibilidad de datos de vehículos y firma anterior diferente. Antes de tocarla, obtener **la huella del certificado realmente instalado** mediante medios read-only, preferentemente `adb shell pm path` y `adb pull` del `base.apk` a carpeta temporal aislada **solo si hay espacio**, seguido de `apksigner verify --print-certs` local (evitar imprimir tokens o serial); alternativamente una herramienta fiable que devuelva esa huella. Comparar con SHA256 del certificado del APK RC2.
  - **Firma distinta, no verificable, package cambiado, downgrade, espacio insuficiente, app con datos sin respaldo verificable o compatibilidad de migración desconocida:** **NO instalar, NO desinstalar, NO borrar, NO sobrescribir**. `BLOCKED_EXISTING_APP_PRESERVATION`, devolver evidencia saneada y una decisión única para el propietario. Se puede observar la app ya instalada, pero ese resultado **NO certifica el APK RC2**.
  - **Firma coincidente y datos protegidos:** realizar primero un resumen no sensible de los registros visibles y confirmar que **existe un respaldo/restauración aprobado para esos datos o que la instalación actual no contiene datos importantes**. **Si no hay esa confirmación, no hacer `install -r`**. Solo cuando la preservación esté acreditada, ejecutar **una vez** `adb -s <serial> install -r <apk_verificada>` (usar `-t` solo si el APK lo requiere; nunca `-d`). No cambiar datos de usuario ni configuración. Si surge aviso de incompatibilidad, parar sin manipular firma ni desinstalar.
- Nunca convertir el simple desbloqueo del teléfono en autorización para borrar/reemplazar datos. Documentar claramente qué rama A/B se tomó. Si queda bloqueado en B, no inventar otra campaña de pruebas: ese es un requisito de autorización o respaldo, no un defecto de app.

## 3. UNA sesión de QA observable, únicamente si la APK RC2 realmente quedó instalada

Conservando los datos anteriores:

1. Iniciar el paquete `co.picoradar.app.dev` mediante launcher normal o `adb -s <serial> shell monkey -p co.picoradar.app.dev -c android.intent.category.LAUNCHER 1` (solo con paquete verificado). Capturar arranque y un `logcat` **focal saneado**, sin PII. No declarar PASS si hay crash de arranque.
2. Recorrido real de pestañas: **Inicio → Garaje → Apps → Viaje → Conducir → Garaje**, solo si cada pestaña es accesible en la versión ejecutada. Distinguir `Viaje` de `Conducir`. No navegar a servicios externos con credenciales reales.
3. Contar los vehículos existentes sin registrar placa, ubicación ni datos personales. **Agregar un vehículo claramente sintético SOLO si hay garantía de poder eliminar exactamente ese registro sin afectar otros**; de lo contrario, omitir esa subprueba. Cerrar y reabrir la app y verificar que los vehículos previos permanecen y que el dato sintético se conserva, si fue creado. No usar placas reales para pruebas.
4. Comprobar una consulta en jurisdicción ya incluida en los datos del APK con resultado observable. Para información incompleta o caducada, verificar que la UI **no garantice “puede circular”**; registrar `UNKNOWN/STALE` cuando corresponda. No inventar restricciones ni fechas, no alterar reloj/GPS del teléfono.
5. OTA real en este Mi A3 **solo si existe endpoint/fixture QA local explícitamente seguro y preconfigurado**. Si no, `OTA_PHYSICAL=NOT_TESTED_NO_SAFE_QA_ENDPOINT`; conservar solo el PASS de G2 con bytes en laboratorio, sin confundirlo con OTA en dispositivo.
6. Si ocurre crash real o pérdida de datos, detenerse, guardar solo las líneas esenciales de crash redactadas y la reproducción mínima; **no reparar en el teléfono ni lanzar múltiples builds**. `APP_DEFECT=OBSERVED` únicamente cuando exista evidencia específica. No solicitar nueva auditoría general.

## 4. Salida: UN ZIP PEQUEÑO, sin APK ni datos sensibles

**Único ZIP:** `D:\codex\_REPORTES\PicoRadar\RC3-MIA3-PHYSICAL-QA-20261115\delivery\PICORADAR_RC3_MIA3_QA_EVIDENCIA_UNICA.zip`.

Incluir `FINAL_REPORT.md`, `GATES.csv`, `APK_REFERENCE.txt`, `ANDROID_PHYSICAL_QA.md`, logs **mínimos y redactados**, opcional hasta 2 capturas **sin PII ni placas**, `MANIFEST.csv` (ruta/bytes/SHA256/CRC32 de todos los demás miembros). `FINAL_REPORT` debe indicar el CASO A/B, firma verificada sí/no, si existía aplicación, si hubo instalación, resumen antes/después sin PII, pruebas observadas, código HEAD, gates faltantes y único próximo actor. Excluir APK 211MB, bundle 85MB ya recibido, archivos Gitleaks privados, datos del dispositivo y logs crudos de ADB. Si no hubo instalación, el ZIP debe demostrar preflight y bloqueo sin inventar PASS. Validar CRC, tamaños, hash, extracción y SHA del ZIP final; entregar **solo ese archivo**.

Línea de cierre: `TASK_ID=PICORADAR-RC3-MIA3-PHYSICAL-RUNTIME-QA-ONEPASS-20261115 | ADB=... | INSTALLED_APP=... | SIGNATURE_MATCH=... | APK_RC2_INSTALLED=... | RUNTIME=... | DATA_PRESERVED=... | OTA_PHYSICAL=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`.

**Leyes del proyecto:** KISS/Ponytail; nada de hardcodes por ciudad, parches en cadena, auditorías o tests redundantes, ni prometer cobertura nacional antes de fuentes y datos completos aprobados. Motor **único schema2**, datos oficiales habilitables por ciudad/municipio/departamento/pueblo, actualización OTA por datos. Las 14 autoridades/33 DIVIPOLA/21 pares de cobertura/115 reglas actuales son LAB parcial. Firma `release` todavía apunta a debug; seguridad GitHub y staging/OTA real siguen HOLD. El desarrollo de Android ahora necesita ejecución física verificable, no otro reporte de arquitectura.

**AL FINAL: SIGUE CHATGPT DIRECTOR. NO INICIAR OTRA TAREA CODEx POR INERCIA.**