# CODEX LUNA — PICORADAR C7 · VALIDACIÓN REAL, COBERTURA OFICIAL Y CONTINUIDAD GITHUB SIN ARCHIVOS PESADOS

**TASK_ID:** `PICORADAR-C7-QA-HTTPS-NACIONAL-20261121`  
**EJECUTOR:** Codex Luna. **DIRECTOR:** ChatGPT. **Fecha de corte:** 21/11/2026, America/Bogota.  
**ORDEN:** ejecutar **un solo macrobloque**, con progreso funcional, integración única y **UN SOLO ZIP LIGERO DE RETORNO**. NO reauditar C1–C6. NO generar un C7.1 para preflight. El respaldo C6 ya funciona: el objetivo no es volver a construirlo.

## 0. Decisión innegociable del propietario: NO adjuntar APK

**La APK fue retirada intencionalmente del ZIP que se entrega a ChatGPT por su tamaño. NO pedirla nuevamente, NO incluirla en ningún ZIP futuro, NO copiarla al directorio de evidencias ni codificarla en Base64.** No incluir un TAR, bundle, snapshot o ZIP con el árbol completo: el código ya tiene respaldo remoto verificado. Para continuar, reutilizar la APK existente **solo en la máquina local**, buscando de manera acotada en el directorio de compilación de C6, y referenciar exclusivamente identidad, tamaño, SHA-256 y logs sanitizados. Si el artefacto local ya no existe, declarar `APK_LOCAL_MISSING` y seguir los demás frentes; no reconstruirla por rutina. Para una modificación que *realmente* requiera nueva compilación, un máximo de un build controlado si RAM ≥6 GiB, guardando la APK solo localmente.

## 1. Hechos aceptados: no repetir sus auditorías

1. C6 `PARTIAL`, PHP export focal **3 tests/41 assertions** y regresiones **8 tests/80 assertions**, Pint y `php -l` PASS. Nuevo CSV editorial y matriz municipal real **A1/A2 implementados**. No repetirlos sin modificación directa.
2. Catálogo geográfico **33 departamentos / 1.104 municipios**, **NO** significa 1.104 restricciones jurídicas verificadas; legal nacional `NO_MEDIBLE`; ausencia de norma = `UNKNOWN`, no `ALLOWED`.
3. APK DEV **ya compilada**: paquete `co.picoradar.app.dev`, `versionName=1.0.1`, `versionCode=2`, firma **debug v2**; SHA-256 `245e285d86fa2057dd53870fc38141746b61342821012abd1f761857395fb639`. Evidencia C6 de `flutter build apk --debug --flavor dev --no-pub` exit 0 tras ajuste temporal `kotlin.incremental=false`; lockfile y `gradle.properties` restaurados. **Esto acredita BUILD, NO instalación ni QA física ni release firmada.** No repetir compilación si APK local coincide.
4. Respaldo de fuentes C6 confirmado EN GITHUB, no solo documento: repositorio `sierraglobalcompany-rgb/PicoRadar`, rama `backup/picoradar-c6-source-20261120`, commit **`bc1422c7198607850a49f4a294ed67316fed0805`**, tree **`2c0fd2e7a4ef8eed5b342101afb7320982d3c07c`**, **1.882** blobs. Es commit raíz source-only sin ascendente en `main`, y **NO es merge-ready**.
5. ZIP C6 recibido por ChatGPT, modificado por el propietario para omitir APK: conserva **29** evidencias con hashes válidos y 1 entrada de APK ausente deliberadamente. NO declarar corrupto por esa omisión; el SHA del ZIP original cambia después de editarlo. El TAR restante verificó **1.882/1.882** hashes. No generar otro TAR.
6. WIP original en host Windows: **43 rutas (18 M + 25 ??)**, HEAD `182a8821bba688b28a6e223a1e956df748f7948b`. No abrir/escribir/borrar el checkout protegido; no eliminar junctions ignoradas ni `server/vendor`, ni revertir la eliminación preexistente de `scripts/tests/test_hostinger_installer_browser.ps1`.
7. PR #79: OPEN/DRAFT en `docs/plan-maestro-nacional-v2-20261107`, contra `recovery/20261019-modern`. **No tocarlo ni mezclarlo con C7**. `main` divergente (~838 rutas documentadas, sin ancestro común). `HOLD_COMPATIBILITY`, `RELEASE=NO_GO` y publicidad/pagos/premium OFF.
8. La puntuación heredada **61/100** mide evidencia funcional local, no porcentaje de producto ni cumplimiento legal. Conservar 61 hasta que un gate de la matriz original pase según su definición. Nunca sumar puntos por nuevos documentos ni por el build Android que ya pasó si la rúbrica exige dispositivo.

## 2. Leyes de operación (mandatorias)

- L1 KISS/Ponytail: una implementación, componentes existentes, sin arquitectura paralela.
- L2 antirruido: no carpetas masivas de informes, no escaneos repetidos, no preguntas innecesarias.
- L3 antiparches: corregir causas, no monkeypatch, no cambiar dependencias/Gradle sin falla reproducible.
- L4 diseño humano: estados claros, UI conservada `Inicio · Garaje · Apps · Viaje · Conducir`, Apps siempre centro, flujo sin cuenta, incertidumbre jurídica visible.
- L5 verificación independiente: cada `PASS` exige comando real, salida, exit y/o comparación reproducible. `NOT_RUN` y `BLOCKED` nunca se etiquetan PASS.
- L6 antiping-pong: un macrobloque con reintento **causal** acotado; no repetir prueba que ya pasó sin cambio relevante.
- Seguridad/privacidad: jamás incluir placas reales, contraseñas, token, documentos, llaves privadas, datos GPS personales, `.env`, SQLite local ni informes sensibles en repo/ZIP. Nunca afirmar ausencia absoluta de secretos por heurística.

## 3. Arranque de una sola vez: base remota real

1. En `D:\codex\_isolated\`, preparar un clon/worktree NUEVO basado en `backup/picoradar-c6-source-20261120` (no desde `main`; no requiere el TAR ni ZIP anterior). Comprobar commit y tree exactos **una vez**, limpieza del checkout, `git status --porcelain`, y solo registrar SHA. No correr baterías de auditorías previas.
2. Crear una rama nueva `develop/picoradar-c7-20261121` **descendiente de** `bc1422c...`; una única persona/agent integrador controla su índice Git, su commit y su push. No sobrescribir la rama C6 de respaldo. No `--force`, no refactor masivo, no GitHub Actions.
3. Máximo **dos subagentes** en worktrees independientes si el entorno los permite: agente `SERVER` para tarea A y agente `MOBILE` para tarea B. Apoyo `LEGAL` solo lectura/investigación para tarea C. El integrador aplica parches, coordina QA y publicará una sola vez. Si hay menos de 6 GiB libres o los worktrees no son posibles: secuencial; no detener trabajo.
4. Leer únicamente contratos pertinentes del árbol C6 y `AGENTS.md` del repo original cuando corresponda. No redescubrir 1.882 rutas ni volver a hacer 10+10 auditorías previas. C7 no depende de ejecutar C6, C5 o R2 de nuevo.

## 4. Frente A — servidor nacional real y HTTPS de extremo a extremo

**Meta:** demostrar un flujo operativo nacional desde el Super Admin hasta la respuesta que recibirá el cliente, reutilizando los servicios que YA EXISTEN (`RestrictionRuleController`, `RestrictionImportService`, `RestrictionPublicationService`, validadores, datasets y manifest publisher). **NO reconstruir editor, CSV, importación, roles ni publicación.**

A1. Identificar una única secuencia reproducible y permitida: **draft sintético -> validar -> autorización de segundo rol ante cambio material -> publicar -> leer manifest/dataset -> rollback -> comprobar último válido y auditoría**. No mutar datos de producción, no incorporar datos jurídicos ficticios a fuentes oficiales. Usar DB temporal y storage temporal local si no existe staging autorizado. Evitar repetir los 3 tests de exportación C6: nueva prueba enfocada solo en brecha operativa que no estuviera cubierta ya por C2–C6; si ya existe demostración igual y sin cambios, marcar `REUSED_PASS` citando archivo/log en vez de repetir.

A2. **HTTPS real** únicamente si existen servidor, dominio/endpoint y autorización ya configurados. Comprobar TLS válido, cadena, respuesta manifest, hash de archivo y consumo del cliente sin exponer secretos; no habilitar redirecciones inseguras ni usar `verify=false`. Si no hay staging disponible, `HTTPS_REAL=BLOCKED_EXTERNAL`, registrar campo exacto faltante (dominio, credenciales autorizadas o despliegue), y pasar a A3: preparación de configuración y pruebas de contrato en entorno aislado sin declarar HTTPS PASS.

A3. Si el recorrido encuentra un **defecto real** de publicación, validación o controles de rol, implementar su corrección mínima con 1–3 tests causales; si no lo encuentra, no forzar cambios sin necesidad. No modificar banderas `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false` o ads/pagos/premium. Un 100 % de editor manual no implica 100 % de cobertura jurídica.

## 5. Frente B — Android y experiencia real sin enviar APK a ChatGPT

**Meta:** cerrar el mayor gate físico sin poner en riesgo datos del usuario. El artefacto C6 se queda en el host Windows de Codex. Registrar ruta local y hash, **nunca empaquetarlo**.

B1. Si hay dispositivo de pruebas conectado y el propietario ha autorizado la interacción, hacer **preflight read-only**: `adb devices -l`, `adb shell getprop ro.build.version.sdk`, paquetes instalados y firma/código de versión disponible. No registrar placas, cuentas ni rutas GPS; sanitizar logs. Si no hay dispositivo o autorización, `DEVICE=BLOCKED_EXTERNAL` y continuar A/C/D: no iniciar ping-pong ni pedir APK.

B2. **NO desinstalar, borrar datos, `pm clear`, resetear teléfono ni sobrescribir app con firma incompatible.** En particular, el Mi A3 tiene antecedente de fallo de instalación por diferencia de firma entre builds. Antes de cualquier instalación obtener confirmación específica del propietario para el paso mutador y verificar compatibilidad de firma. Si no coincide, declarar `SIGNATURE_MISMATCH_HOLD` con propuesta no destructiva; no usar `adb install -r` contra firma incompatible.

B3. **Solo si hay autorización y compatibilidad**, instalar localmente el APK ya compilado y ejecutar smoke físico acotado: abre app sin cuenta, ver `Inicio · Garaje · Apps · Viaje · Conducir`, ciudad con norma conocida vs `UNKNOWN`, persistencia tras reinicio, resultado offline si la conectividad puede cambiarse sin afectar a terceros, manejo de datos no válidos, sin crash. El usuario controla cualquier cambio de ajustes del dispositivo. Guardar únicamente resultados y capturas sintéticas o redactadas (no capturas con placas o documentos reales). `DEVICE_PASS` solo cuando se ejecute realmente en dispositivo.

B4. Si no hay dispositivo, hacer **una** comprobación local enfocada de funcionalidad NO cubierta (p. ej. cold-start/estado UNKNOWN) cuando aporte evidencia; evitar reejecutar 3.365 tests globales. No recompilar APK ya verificada ni volver a hacer análisis/format global sin cambios.

## 6. Frente C — cobertura jurídica nacional honesta y útil

**Meta:** acercar la plataforma a un editor nacional operativo sin inventar restricciones. La geografía DIVIPOLA se conserva; no tratar 1.104 municipios como normas certificadas. Sin scraping evasivo, sin CAPTCHA, sin atribuir fuentes no verificadas.

C1. Revisar **máximo tres jurisdicciones piloto previamente registradas** cuya documentación oficial esté accesible por Internet en el entorno; fuente de alcaldía/autoridad/decreto/resolución, URL oficial, autoridad emisora, fecha, vigencia, modalidades de vehículo y municipio. Se prohíben fuentes de agregadores como evidencia jurídica primaria y se prohíbe escribir condiciones inferidas. Si fuente oficial no está disponible, estado `UNKNOWN` o `STALE`, y registrar el motivo en la matriz (sin falsas reglas).

C2. Para un caso con evidencia suficiente, preparar **un borrador editorial** verificable en el admin (no publicar en producción automáticamente), con los campos typed del motor y un test causal de interpretación que no duplique pruebas pasadas. Si la fuente no acredita excepción, horario o modalidad, no inventar esos campos. Si los tres casos carecen de fuente suficiente, entregar solo matriz de bloqueo con citas reales y continuar otros frentes.

C3. No activar ni desactivar normas reales sin aprobación del propietario. No prometer cobertura legal nacional completa. Mantener términos `UNKNOWN`, `PARTIAL`, `STALE`, `VERIFIED` acorde a datos verificados y vencimientos.

## 7. Frente D — GitHub que sirva para desarrollar, sin tocar main

D1. Después del desarrollo A/B/C, integrar únicamente cambios revisados y probados a `develop/picoradar-c7-20261121`; `git diff --check`, revisión de secretos focal y `git status` limpio. **No hay obligación de inventar modificaciones** si no se reproduce defecto o fuente jurídica real; el lote habrá progresado con gate físico/HTTPS si éstos pasaron.

D2. Push **sin force** a esa rama de desarrollo, confirmar commit/tree remoto y diff contra `backup/picoradar-c6-source-20261120`. Si existe delta de código pertinente, abrir **PR DRAFT** de C7 **contra la rama backup C6**, nunca contra `main`, sin Actions y sin merge. Ese PR es revisión de avances, **NO release**. Si el push está bloqueado por credenciales/permiso o seguridad, un solo intento de diagnóstico; seguir con entregables y `GITHUB_C7=HOLD` sin probar múltiples auth flows.

D3. No hacer merge hacia `main` ni reescribir sus 838 diferencias por fuerza. PR #79 no es fuente de código C7: no tocarlo. La integración eventual requiere un bloque posterior de compatibilidad con plan explícito; el backup remoto actual ya evita perder C6.

D4. Mantener continuidad de un solo punto de verdad: README de breve estado C7 en **rama de desarrollo** (sin duplicar decenas de recovery.md), con SHA, blockers y próxima acción concreta. Nada de `git bundle` ni TAR ni snapshot nuevo enviado a ChatGPT.

## 8. Gates de aceptación y regla de avance

- `C7_A_SERVER`: `PASS_REAL_VERTICAL`, `PASS_SCOPED_LOCAL`, `REUSED_PASS`, `BLOCKED_EXTERNAL` o `FAIL`; declarar exacto alcance. `HTTPS_REAL=PASS` solo con URL HTTPS autorizada y TLS real validado.
- `C7_B_ANDROID`: `PASS_DEVICE`, `BLOCKED_EXTERNAL`, `SIGNATURE_MISMATCH_HOLD` o `FAIL`; compilar ya no es el gate principal, pues el build de C6 existe.
- `C7_C_LEGAL`: indicar ciudades piloto y fuentes, o `NO_OFFICIAL_SOURCE`, con fecha/URL/estado. **No aumentar el denominador legal por ciudad sin norma verificada.**
- `C7_D_GITHUB`: estado branch y Draft PR si corresponde, commit/tree remoto idénticos. Backup C6 `PASS` se reutiliza, sin puntuar como nuevo avance.
- `ADS_PAYMENTS_PREMIUM=OFF`, `APP_WITHOUT_ACCOUNT=TRUE`, `GPS_PRIVACY=PASS_REUSED` si no se cambió.
- `WIP_PROTECTED`: fingerprint pre/post del checkout protegido solo si se interactuó con él (normalmente cero interacción); no ejecutar revisión completa innecesaria en checkout intacto.
- `RELEASE=NO_GO` hasta HTTPS real, firma/producto, QA dispositivo y cobertura legal necesarias para las jurisdicciones publicadas. No aprobar tiendas ni publicar servidor automáticamente.

**No inflar porcentajes:** base `EVIDENCE_SCORE=61/100`, `PRODUCT_COMPLETION=UNMEASURED`, `NATIONAL_LEGAL_COVERAGE=UNMEASURED`; cambiar solo cuando se cierre un criterio original con prueba nueva. Informar también avances binarios en el bloque sin inventar porcentaje global.

## 9. Reintentos e interrupciones

- Un preflight global corto; máximo **dos intentos** por fallo (inicial + 1 corrección causal), sin reejecutar toda la suite. Si una tarea encuentra un bloqueo externo no modificable, pasar inmediatamente a otra tarea. No pedir al director otro prompt por cada fallo.
- Los agentes no comparten índice ni `.dart_tool` en paralelo, no ejecutan Gradle pesado concurrente; cada uno escribe en su worktree, integrador único revisa y aplica.
- No borrar caches globales, junctions, vendor ni WIP protegido. No exigir ≥6 GiB de RAM para ejecutar PHP, Git o investigar normas: ese umbral aplica solo a compilación Android pesada.
- Reportar `FAIL` si falla un test, no convertirlo en `PASS_SCOPED` por omitirlo. El mecanismo de defensa ante falsos positivos es el log con comando/exit, y una prueba que reproduzca defecto antes de afirmar su corrección.

## 10. Entrega: exactamente un ZIP muy ligero, sin APK ni código completo

En `D:\codex\_REPORTES\PicoRadar\C7-20261121\` crear **`PICORADAR_C7_RETORNO_UNICO_LIGERO.zip`**. Objetivo **≤2 MiB** (máximo **5 MiB**, salvo autorización del propietario); excluir archivos binarios grandes, `APK`, `AAB`, `tar.gz`, `.bundle`, ZIP anidado, source tree, `vendor`, caches, PDFs extensos y pruebas globales antiguas. El repositorio GitHub es el respaldo del código; el ZIP solo permite al director inspeccionar el delta. Incluir únicamente:

1. `FINAL_REPORT.md`: tareas hechas/pendientes, resultados reales, commits/refs, tipo de evidencia, estado de release y exactamente quién sigue.
2. `GATES.csv`: A/B/C/D, estado, evidencia comprobable y siguientes acciones sin repetir QA.
3. `CODE_DIFF.csv` y, si hubo cambios, `C7_DELTA.patch` **texto liviano** (en GitHub queda fuente definitiva); nunca adjuntar archivos de código completos masivos.
4. `QA/` logs cortos sanitizados de pruebas/ADB/HTTPS y enlaces de fuentes normativas; no datos personales ni secretos.
5. `MANIFEST.csv` con ruta, tamaño, SHA-256, CRC32 de cada miembro excluyendo el propio manifiesto; comprobar ZIP CRC y hashes. Imprimir ruta local final + SHA256 ZIP.
6. Si existen verificaciones de APK, **solo** `QA/APK_IDENTITY.txt` con hash C6, firma, package/version y estado instalación; **PROHIBIDO incluir la APK**.

No entregar rutas `D:\` como enlaces descargables desde ChatGPT: entregar el ZIP físico en la conversación cuando sea posible, o su ruta exacta para adjuntarlo manualmente. No responder con informes diseminados. No pedir al usuario recuperar el ZIP C6 ni volver a subir APK/TAR.

### Cierre exigido

`TASK_ID | RESULT | SERVER_GATE | HTTPS_REAL | DEVICE_GATE | LEGAL_PILOTS | GITHUB_C7_COMMIT | PR_C7 | RELEASE | ZIP_PATH | ZIP_SHA256 | NEXT=CHATGPT_DIRECTOR`.

**NO REHACER C1–C6. NO EMPAQUETAR APK. NO EMPAQUETAR EL TAR DE 77 MB. NO HACER MERGE EN MAIN. EJECUTAR TRABAJO QUE ACERQUE EL PRODUCTO AL LANZAMIENTO.**

# 🔴🔴🔴 SIGUE: CODEX LUNA — EJECUTAR C7, DEVOLVER SOLO ZIP LIGERO 🔴🔴🔴

**DESPUÉS DEL ZIP SIGUE: CHATGPT DIRECTOR.**
