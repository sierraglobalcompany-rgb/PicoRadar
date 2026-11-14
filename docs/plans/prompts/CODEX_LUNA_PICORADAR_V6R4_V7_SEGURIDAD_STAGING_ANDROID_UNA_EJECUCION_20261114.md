# CODEX LUNA — PICORADAR V6R4 V7 — SEGURIDAD, STAGING Y ANDROID EN UNA SOLA EJECUCIÓN

**TASK_ID:** `PICORADAR-V6R4-V7-G4-SECURITY-STAGING-ANDROID-ONEPASS-20261114`  
**Responsables:** ChatGPT Director define y audita; Codex Luna ejecuta lo estrictamente local. `NEXT_ACTOR=CHATGPT_DIRECTOR` al entregar.  
**Estado:** F0/F1/F2 PASS; G2=PASS_SCHEMA2_LARAVEL_BYTES_TO_FLUTTER_QA, G5 PASS. G3=BLOCKED_HOST_RESOURCE_STABLE y G4=HOLD_REVIEW_REQUIRED. `PRODUCT_RELEASE=NO_GO`.

**Esta orden sustituye el V6 ya terminado. Ejecutar una sola vez si no hay otro escritor PicoRadar activo.** No volver a ejecutar otras auditorías, pruebas aprobadas, recuentos nacionales, ni regenerar el proyecto.

## 0. Base exacta, reglas y alcance

- Candidato en `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`, rama `feat/picoradar-v6r4-lab-candidate`, HEAD `15948a50332589ff3d1fb3157b6976809fe5a680`, TREE `8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`. Ancestro PR71 `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, doce commits nuevos.
- Entrada preservada: `PICORADAR_V6R4_V6_FOCAL_EVIDENCIA_UNICA.zip`, SHA-256 `8e430ada1a882bc3fe4bc3e3283b835d8cba275a5c38ac2dc4eb7762d2bf717c`. Bundle `GIT/full-final.bundle`, SHA-256 `dad16fccb97493add593bbacbd13edfb1db60219f14b445fd5e22141356639a1`.
- Leer las instrucciones `AGENTS.md` aplicables y leyes L1–L6, sin reinstalar herramientas por rutina. Arquitectura nacional congelada: **UN motor schema2**, autoridad/ámbito/vehículo como datos, snapshots completos aprobados y OTA sin una APK por ciudad; fuente institucional basta para campos expresos. No declarar circulación libre sin fuente: `UNKNOWN/STALE`.
- No tocar `main`, PR71, PR79, producción, Hostinger, CDN, teléfonos, usuarios reales ni datos de Garaje. No `reset --hard`, `clean`, `force-push`, `rebase`, ni reescritura histórica. No consumir GitHub Actions pagas. No cambiar motores, schema ni crear servicios/test de integración duplicados.

## 1. S0 — seguridad del host y preservación

1. Una vez: detectar otro escritor, confirmar HEAD/TREE y `git status --porcelain` limpio. Si difieren, no operar sobre ese checkout; reconstruir en un clon **nuevo** usando el bundle verificado y registrar el desvío.
2. **Restablecer/verificar antivirus.** El ZIP V6 indica que se desactivó el antivirus para regenerar una exportación temporal después de una cuarentena de `scripts/tests/test_hostinger_installer_browser.ps1`. Comprobar Microsoft Defender/antivirus activo mediante Seguridad de Windows o `Get-MpComputerStatus`. Si está apagado, restaurar la protección por la vía normal antes de proseguir; si bloqueado, marcar `HOLD_SECURITY_HOST` y continuar solo lectura segura. **No volver a desactivarlo, no crear exclusiones, no restaurar como permitido ni ejecutar el PS1 puesto en cuarentena.** Registrar su estado y, en su caso, solo inspección estática y revisión de Historial de protección.
3. Los reportes `D:\codex\_REPORTES\PicoRadar\V6R4-V6-FOCAL-20261114\qa\gitleaks-history.private.json`, `gitleaks-tree.private.json`, `gitleaks-tree-retry.private.json` contienen coincidencias NO redactadas. Permanecen **exclusivamente locales y privados**: no volcarlos al chat, a GitHub, a otro proceso de red, a los logs de salida ni al ZIP. Si políticas impiden borrarlos, no eludirlas; conservarlos protegidos y dejar constancia de disposición pendiente.
4. No repetir el export Git ni escaneo completo que ya cubrió `1839/1839` rutas, salvo modificación real que altere el alcance. No repetir la restauración V6 por protocolo.

## 2. S1 — clasificación causal de Gitleaks, sin falsos PASS

Gitleaks 8.30.0 V6 identificó **5 eventos** en la historia `PR71..HEAD` y **10 coincidencias** en el árbol HEAD. No sumar como 15 secretos independientes. Los reportes crudos solo se consultan localmente, sin sacar valores.

Para cada coincidencia registrar `archivo:línea`, regla, presencia en PR71 BASE o en delta de 12 commits, naturaleza del campo, uso/consumidor, `BENIGN_CONFIRMED / POTENTIAL_SECRET / UNKNOWN`, razón verificable y decisión. Las diez líneas del árbol son:

- `data/releases/viaje_r2/toll_decision_ledger_v1.json:4`
- `codex/C24_CDA_GEODATA_AUDIT.md:261`
- `mobile/lib/features/garage/data/garage_favorites.dart:5`
- `mobile/lib/features/pico_placa/data/pico_preferences.dart:3`
- `scripts/compile_viaje_r2_data.py:1150`
- `server/tests/Feature/RestrictionG34EditorialImportLabTest.php:183`
- `server/tests/Feature/RestrictionSchemaV2LabRoundTripTest.php:68,300,362,411`

**Evidencia ya obtenida por el Director:** las cinco primeras líneas estaban idénticas en el commit BASE PR71; las otras cinco corresponden a dos archivos de pruebas PHP incorporados después. Nueve tienen apariencia de identificadores de almacenamiento, datos o fixtures: no aprobar por intuición; contrastar el uso exacto. Las cinco coincidencias históricas parecen corresponder al delta de fixtures pero verificar con reportes, no asumir equivalencia entre eventos.

**Power BI — hold crítico:** `codex/C24_CDA_GEODATA_AUDIT.md:261` contiene una URL `app.powerbi.com/view` con parámetro opaco `r`. **NO abrir la URL ni copiar su parámetro.** Microsoft advierte que “Publish to web” permite acceso público sin autenticación. Si no hay autorización explícita y comprobable de la fuente/dueño para exponer deliberadamente ese reporte, resultado `POWERBI_PUBLIC_STATUS=UNKNOWN`, `G4=HOLD_OWNER_DECISION`, **NO PUSH**. Que aparezca ya en la base pública no demuestra ausencia de riesgo. Si es secreto o expone datos privados, pedir autorización para remediación/rotación antes de alterar historial; no hacer esa operación unilateralmente.

Prohibido silenciar reglas globales, crear allowlists masivas, rebajar la criticidad para conseguir PASS o afirmar que un informe con `--redact` significa cero secretos. Los benignos confirmados se registran individualmente. Entregar `SECURITY_FINDINGS_SANITIZED.csv` solo con ruta, línea, tipo, base/delta, estado y breve razón, **sin valores, URL opaca, hashes derivados de secretos ni fragmentos crudos**.

## 3. S2 — rama LAB GitHub si seguridad real aprueba

1. Solo si el antivirus está activo, las diez coincidencias están clasificadas BENIGN_CONFIRMED con evidencia (incluida publicidad deliberada del informe Power BI) y ningún secreto dudoso: revisar los workflows y su coste, y efectuar una única consulta remota de lectura (`ls-remote`) sin mostrar tokens.
2. Si la rama remota LAB no existe y es seguro publicar, UN push ordinario a `refs/heads/feat/picoradar-v6r4-lab-candidate`. Verificar SHA remoto. **No PR automático, no push a main, no force, no tags, no CI paga.** Si la rama existe divergente, hay HTTP 403, CI/coste incierto, secreto o política pendiente: `G4=HOLD_...`, sin repetir ni forzar. Conservar el bundle restaurable.
3. Nunca subir findings privados, tokens, material de pruebas real ni registros de seguridad. El PR79 documental no equivale a tener el código de producto subido.

## 4. S3 — comprobar únicamente el eslabón de publicación que falta

- **No ejecutar** nuevamente F0, F1 (3 Flutter), F2 (33 PHPUnit/279 aserciones), 14 Python, G2 (schema2 Laravel→HTTP loopback→Drift/last-good) ni reconstrucción nacional sobre los mismos bytes y SHA.
- Revisar evidencia ya existente de `RestrictionPublicationService`, `DatasetPublisher`, `DatasetReleaseValidator` y `DatasetSyncService`: flujo editorial aprobado → snapshot **completo respecto a coberturas aprobadas** → manifest SHA/revision → cliente OTA → rechazo de SHA inválido o rollback → conservación de Garaje. Identificar el **primer eslabón que realmente no tenga QA**, sin inferir que loopback prueba CDN.
- Si todo lo requerido ya tiene QA suficiente, `S3=REUSED_PASS_SCOPED`, con ruta/SHA, sin otro test. Si falta una integración real, UNA prueba focal en QA local/efímero, usando servicios/fixtures existentes y sin crear nuevo servicio, motor ni snapshot parcial productivo. No usar ninguna DB, servidor ni CDN real. Si falta DB QA, `S3=BLOCKED_ENV_QA` y no ejecutar migraciones sobre otras bases.
- Falla funcional reproducible: solo corrección causal mínima, test RED y GREEN focal, registrar nuevo HEAD/TREE y delta. No refactors ornamentales ni aumento de alcance.

## 5. S4 — Android sin otro intento inútil

- V5 midió pagefile libre **3,37 GiB** frente al gate conservador **6 GiB**; `gradle.properties` usa `-Xmx8G` y `MaxMetaspaceSize=4G`. Si el equipo no cambió, `S4=BLOCKED_HOST_RESOURCE_STABLE` sin relanzar Gradle.
- Si ya hay una máquina local gratuita con recursos aptos o cambio real autorizado, medir preflight UNA vez; solo si PASS, compilar APK **debug/dev** con el comando documentado y dependencias fijadas, guardar exit, logs y SHA. No inferir QA física por compilar. Si falla, diagnosticar solo el error nuevo; evitar cascadas de reintentos.
- No cambiar memoria virtual del sistema, no desactivar antivirus, no forzar parámetros JVM inseguros, no cambiar firma, no reinstalar ni borrar datos del Mi A3, no GitHub Actions de pago sin consentimiento. Documentar requisito exacto para desbloquear al responsable.

## 6. S5 — único ZIP final de entrega

**Única salida:** `D:\codex\_REPORTES\PicoRadar\V6R4-V7-ONEPASS-20261114\delivery\PICORADAR_V6R4_V7_EVIDENCIA_UNICA.zip`.

Incluir `FINAL_REPORT.md`, `GATES.csv` con comandos/exits/HEAD/TREE y alcance, `SECURITY_FINDINGS_SANITIZED.csv`, logs mínimos depurados, mapa del eslabón S3, diagnóstico S4, manifest de tamaños/SHA256/CRC, RESTORE y **un bundle** del HEAD final verificable en clon nuevo. APK debug solo si existe y su compartición es segura. No incluir reportes `.private.json`, muestras de claves, URL Power BI, secretos QA, ZIP preliminar ni assets privados innecesarios.

Verificar una sola vez CRC, manifiesto, extracción, git bundle verify, checkout HEAD/TREE y estado limpio. Si una política impide borrar otros archivos, NO evadirla y no incluirlos. Línea final exacta de estados: `TASK_ID | G4=... | S3=... | S4=... | HEAD=... | TREE=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`.

## 7. Auditoría adversarial ya hecha por el director — NO repetir en Codex

**Verdugo V01–V10:** integridad ZIP; HEAD restaurable; G2 probado; doble conteo Gitleaks; cinco hallazgos en base; cinco en tests; link Power BI sin decisión; Defender desactivado para export; informes crudos privados fuera del ZIP; Android sin recursos. **Juez J01–J10:** aceptar F0–G2; clasificar antes de suprimir; no abrir token; no forzar GitHub; proteger bundle; restablecer antivirus; revisar PS1 sin ejecutarlo; hacer solo QA faltante; Android condicional; un ZIP y no V8 por inercia.

**FIN — SIGUE CODEX LUNA SOLO PARA ESTE BLOQUE SI NO ESTÁ OCUPADO; DESPUÉS CHATGPT DIRECTOR.**