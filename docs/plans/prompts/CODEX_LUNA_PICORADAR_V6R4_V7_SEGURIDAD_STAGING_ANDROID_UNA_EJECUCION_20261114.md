# CODEX LUNA — PICORADAR V6R4 V7 — CIERRE FOCAL DE SEGURIDAD, STAGING LOCAL Y ANDROID (UNA EJECUCIÓN)

**TASK_ID:** PICORADAR-V6R4-V7-G4-SECURITY-STAGING-ANDROID-ONEPASS-20261114
**Responsables:** ChatGPT Director diseña/verifica; Codex Luna ejecuta en Windows. Al final NEXT_ACTOR=CHATGPT_DIRECTOR.
**Estado de partida:** G2=PASS_SCHEMA2_LARAVEL_BYTES_TO_FLUTTER_QA; F0/F1/F2 PASS y G5 PASS en entregas anteriores. G3=BLOCKED_HOST_RESOURCE_STABLE; G4=HOLD_REVIEW_REQUIRED; RELEASE=NO_GO.
**Orden:** solo si no existe otro ejecutor PicoRadar activo. NO reenvíes V1–V6 ni repitas suites aprobadas. UN ZIP de salida.

## A. Entradas exactas e invariantes

- Repositorio local candidato: D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113.
- HEAD exacto: 15948a50332589ff3d1fb3157b6976809fe5a680; TREE: 8e0b8cd1de0607e9baeeffcfac93c8f141afb67f; rama LAB: feat/picoradar-v6r4-lab-candidate; 12 commits después del PR71 0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a.
- ZIP V6 de entrada: PICORADAR_V6R4_V6_FOCAL_EVIDENCIA_UNICA.zip, SHA256 8e430ada1a882bc3fe4bc3e3283b835d8cba275a5c38ac2dc4eb7762d2bf717c. Bundle dentro: GIT/full-final.bundle, SHA256 dad16fccb97493add593bbacbd13edfb1db60219f14b445fd5e22141356639a1. Es recuperable; NO reempaquetar todos los paquetes anteriores.
- Las seis leyes L1–L6 y las instrucciones AGENTS.md aplican. Arquitectura congelada: UN motor nacional schema2, datos editoriales por autoridad, municipio/departamento/pueblo con ámbito demostrado, OTA sin nueva APK por calendario. No modificar motores, crear schemas, pipelines duplicados ni hardcodes por ciudad.
- Nunca usar datos, tokens o credenciales productivos; solo LAB/QA local. No main, PR71, PR79, Hostinger, CDN real, merge, force push, rebase, borrado WIP o Mi A3. Conservar UNKNOWN/STALE y la distinción LAB partial frente a snapshot completo aprobado.
- Si el checkout actual difiere, NO forzar cambios: usar clon NUEVO aislado desde el bundle verificado. Crear commit solo ante corrección causal necesaria, no por protocolo. Reportar nuevo HEAD/TREE y su diferencia exacta.

## B. S0 — Protección del host y custodia sin repetición

1. Preflight una vez: procesos/escritores PicoRadar, git rev-parse HEAD y HEAD^{tree}, git status --porcelain; no iniciar segundo escritor.
2. Verificar estado activo del antivirus (Windows Security / Get-MpComputerStatus cuando aplique). En V6 se desactivó temporalmente para rehacer un export tras cuarentena del archivo scripts/tests/test_hostinger_installer_browser.ps1. Si la protección sigue apagada, RESTABLECERLA mediante el control normal de Seguridad de Windows y comprobarlo antes de trabajar. Nunca deshabilitarla de nuevo, marcar la amenaza como permitida, instalar exclusiones ni ejecutar el .ps1 en cuarentena. Si Windows bloquea, HOLD_SECURITY_HOST y continuar únicamente tareas read-only seguras.
3. El archivo .ps1 es un elemento por revisar: inspección estática sin ejecución, estado/historial de protección; no declarar falso positivo sin evidencia. La integridad del Git bundle y el export 1839/1839 ya están PASS: no rehacer export para eludir protección.
4. Reportes crudos en D:\codex\_REPORTES\PicoRadar\V6R4-V6-FOCAL-20261114\qa\gitleaks-history.private.json, gitleaks-tree.private.json, gitleaks-tree-retry.private.json: permanecen LOCALES Y PRIVADOS. No mostrarlos en chat, GitHub, logs nuevos, ZIP ni servicios externos. Si alguna política impide borrado, NO evadirla; registrar retención protegida y responsable de disposición posterior. No tratar valores encontrados como claves de ejemplo sin examinarlos de forma controlada.

## C. S1 — Clasificación causal de Gitleaks (prioridad P0)

1. Reutilizar reportes Gitleaks 8.30.0 V6; no descargar de nuevo ni repetir el mismo escaneo sin cambio. Los reportes indican 5 hallazgos en BASE..HEAD y 10 en árbol HEAD; son eventos que pueden solaparse, NO sumar 15 secretos diferentes.
2. Revisar localmente cada hallazgo, sin copiar el valor sensible: regla, archivo/línea, si está en BASE PR71 o aparece en los 12 commits, tipo de dato, consumidor, clasificación BENIGN_CONFIRMED / POTENTIAL_SECRET / UNKNOWN y fundamento inspeccionable. Inventariar los 10 del árbol: data/releases/viaje_r2/toll_decision_ledger_v1.json:4; codex/C24_CDA_GEODATA_AUDIT.md:261; mobile/lib/features/garage/data/garage_favorites.dart:5; mobile/lib/features/pico_placa/data/pico_preferences.dart:3; scripts/compile_viaje_r2_data.py:1150; server/tests/Feature/RestrictionG34EditorialImportLabTest.php:183; server/tests/Feature/RestrictionSchemaV2LabRoundTripTest.php:68,300,362,411.
3. Auditoría de lectura previa del Director verificó que las primeras cinco coincidencias ya existían EN LA BASE PR71 en la misma línea; las últimas cinco están en dos archivos de pruebas PHP incorporados después. Contrastar contra el repo local, sin asumir que coinciden bytes de secreto por solo compartir línea. Las nueve coincidencias NO Power BI parecen IDs de almacenamiento, datos y fixtures: confirmarlas una por una con su uso, no dar PASS global por su apariencia.
4. La coincidencia codex/C24_CDA_GEODATA_AUDIT.md:261 es una URL app.powerbi.com/view con parámetro opaco r. NO abrirla ni transcribir su valor. Microsoft indica que las URLs de “publicar en web” pueden permitir acceso sin autenticación. Comprobar documentalmente si el dueño/fuente autorizó acceso público deliberado. Si no existe constatación inequívoca: POWERBI_PUBLIC_STATUS=UNKNOWN, G4=HOLD_OWNER_DECISION y NO PUSH. Si se descubre material confidencial real: detener publicación, documentar remediación/rotación fuera de informes públicos y pedir autorización antes de alterar historia. Que esté en el commit base ya público NO lo hace automáticamente seguro.
5. No añadir allowlist masiva, suprimir reglas completas, editar resultados del escáner ni declarar PASS por un reporte redactado. Para BENIGN_CONFIRMED basta acta puntual y control de diferencia; si la política exige supresión, solo huella exacta aprobada y sin alterar normas globales. Al finalizar crear SECURITY_FINDINGS_SANITIZED.csv: archivo/linea, tipo, base-o-delta, estado, razón corta, sin tokens, URL opaca, credenciales ni hallazgos crudos.

## D. S2 — GitHub LAB solo tras gate de seguridad real

1. Si y SOLO SI antivirus ACTIVO, los diez hallazgos están clasificadas BENIGN_CONFIRMED con evidencia (incluido estado público autorizado de Power BI), no hay hallazgos potenciales y no existe otro escritor: inspeccionar workflows push/PR y coste cero, remotos sin imprimir tokens; una consulta de lectura de remote SHA/branch.
2. Si la rama remota feat/picoradar-v6r4-lab-candidate NO existe y el remoto permite escritura, hacer UN push normal solo de dicha rama, nunca de main ni PR79/PR71. No force, no tags, no PR automático, no workflow de pago. Verificar SHA remoto idéntico. Si remotos 403, rama divergente, coste/permiso incierto o política impide la publicación, marcar G4=HOLD y conservar bundle, sin reintentos ciegos.
3. Nunca publicar reportes .private.json o findings con valores. Si se decide que uno de los diez es un secreto o acceso no aprobado, NO empujar la historia: documentar alcance y solución segura, sin reescribir commits ya compartidos sin autorización.
4. La sincronización documental PR79 ya existía hasta §BZ; no volver a copiar allí resultados antiguos. Toda publicación nueva necesita estado real y commit concreto; no confundir documentos con rama de código.

## E. S3 — Cerrar el tramo de publicación que falta, sin duplicar G2

1. NO repetir PHPUnit F2 33/279, Flutter F1, 14 Python ni G2 (un caso schema2 + SHA a través de HTTP loopback) sobre el mismo SHA/fixture. PASS anteriores siguen válidos en ese alcance, no equivalen a staging externo.
2. Comprobar en los servicios YA EXISTENTES RestrictionPublicationService / DatasetPublisher / DatasetReleaseValidator / DatasetSyncService si quedó realmente certificado el flujo administrativo completo: fuentes aprobadas -> snapshot completo relativo a la base aprobada -> revisión/manifest versionado -> consumidor -> rechazo de SHA/revisión mala -> last-good y rollback. Usar logs y tests anteriores como primera prueba; documentar EXACTAMENTE el primer eslabón no certificado.
3. Solo para ese eslabón, ejecutar UNA prueba focal en QA temporal y aislada (sin tocar producción). Reutilizar fixtures reales que ya existen, sin inventar estados legales, credenciales o acceso a CDN. No publicar snapshot LAB 14 autoridades como producto nacional completo ni borrar otras coberturas aprobadas. No reescribir panel administrativo ni crear segundo ensamblador.
4. Si la prueba está aprobada por evidencias previas, marcar REUSED_PASS con SHA/artefacto y no repetirla. Si requiere DB QA no disponible, S3=BLOCKED_ENV_QA sin intentar bases reales. Una falla reproducible real permite UNA corrección causal mínima, un test RED y un GREEN focal; si cambia HEAD, actualizar cadena de custodia y límites de pruebas relevantes.

## F. S4 — Android: un preflight, no otro Gradle inútil

1. El host V5 tenía 3,37 GiB de pagefile libre frente al mínimo de seguridad 6 GiB, gradle.properties -Xmx8G / MaxMetaspaceSize=4G. Si el host NO cambió materialmente, registrar BLOCKED_HOST_RESOURCE_STABLE sin build ni nuevo diagnóstico. Si hay nuevo equipo local gratuito adecuado o mayor memoria comprometida, medir una sola vez antes de intentar build.
2. No cambiar memoria virtual del sistema, desactivar antivirus, bajar indiscriminadamente memoria JVM, cambiar firma, desinstalar app, restaurar datos o usar Actions pagas por cuenta propia. Sin host apto, documentar exactamente el requisito de recurso/alternativa y continuar S1/S3.
3. Si preflight PASS y el build debug está autorizado, reutilizar comando de build dev existente y dependencias fijadas, hacer una compilación Android aislada, guardar exit/log/APK SHA. No afirmar QA física ni instalar Mi A3 sin autorización. Si falla, investigar causa concreta una sola vez y no encadenar múltiples reintentos a ciegas.

## G. S5 — UN ZIP FINAL y estado inequívoco

- Entregar SOLO: D:\codex\_REPORTES\PicoRadar\V6R4-V7-ONEPASS-20261114\delivery\PICORADAR_V6R4_V7_EVIDENCIA_UNICA.zip.
- Contenido mínimo: FINAL_REPORT.md, GATES.csv con exit y base SHA, SECURITY_FINDINGS_SANITIZED.csv, relación de fuentes/logs saneados, plan de remediación si HOLD, git bundle del HEAD resultante (comprobar restauración en clon limpio), archivo README de recuperación, MANIFEST.csv (bytes/SHA256/CRC) y APK debug SOLO SI se compiló y es seguro compartirlo.
- EXCLUIR los .private.json, cualquier token/URL opaca, fixtures con información no autorizada, claves QA, bruto del escáner y otros ZIP. Evitar valores secretos incluso en logs de error y nombres de archivos.
- Validar ZIP final una vez tras su cierre: CRC, SHA y tamaños de todos los miembros, extracción y bundle verify/clone/HEAD/TREE/status. Si una política impide borrar artefactos ajenos o temporales, no evadir; señalar su retención protegida. No incluir un ZIP preliminar paralelo.
- Una sola línea de cierre: TASK_ID | G4=... | S3=... | S4=... | HEAD=... | TREE=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR.
- No declarar liberación nacional: 14 autoridades/33 DIVIPOLA/21 coberturas parciales/115 reglas son LAB; cobertura nacional jurídica y teléfono físico siguen pendientes.

## H. Controles adversariales ya resueltos por el director (NO volver a ejecutar auditoría)

Verdurgo: V01 custodia íntegra; V02 suite G2 aprobada; V03 hallazgos 5/10 no son 15 secretos distintos; V04 cinco findings preexistentes; V05 cinco nuevos en PHP tests; V06 Power BI sin intención pública verificada; V07 antivirus deshabilitado en V6; V08 reportes privados fuera del ZIP; V09 Android bloqueado por recursos; V10 riesgo de confundir LAB con release.
Juez: J01 no retestar F0–G2; J02 clasificar antes de suprimir; J03 no abrir Power BI; J04 no forzar GitHub; J05 preservar bundle; J06 restablecer protección; J07 revisar .ps1 sin ejecutarlo; J08 solo QA focal faltante; J09 Android condicional sin tocar Mi A3; J10 terminar con UN ZIP, sin iniciar otro V8 por inercia.

**FIN: SIGUE CODEX LUNA solo para V7 si está libre; después CHATGPT DIRECTOR.**
