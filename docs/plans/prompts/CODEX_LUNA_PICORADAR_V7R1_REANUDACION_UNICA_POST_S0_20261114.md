# CODEX LUNA — PICORADAR V7-R1 — REANUDACIÓN ÚNICA DESPUÉS DEL GATE ANTIVIRUS

**TASK_ID:** `PICORADAR-V7R1-RESUME-AFTER-HOST-AV-GATE-20261114`  
**DIRECTOR:** ChatGPT. **EJECUTOR:** Codex Luna. **NEXT_ACTOR final:** ChatGPT Director.  
**No es V8, ni nueva auditoría, ni repetición de V7-R1.** Es una orden DELTA que solo sustituye la porción operativa pendiente de V7-R1. Ejecutar **únicamente cuando el usuario haya confirmado en la interfaz de Bitdefender** que la protección está activa, y no haya otra tarea PicoRadar activa. Si no hay confirmación positiva, NO iniciar. No interpretar `Get-MpComputerStatus` pasivo como fallo por sí solo, ni interpretar `AntiVirusProduct.productState=0x042000` como prueba de protección. **No desactivar antivirus ni permitir/restaurar para ejecución archivos en cuarentena.**

## 0. Estado congelado: NO repetir ni reabrir

- Candidato local: `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`. HEAD `15948a50332589ff3d1fb3157b6976809fe5a680`, TREE `8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`. No cambiar base por `main`; 12 commits desde el PR71 HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`.
- F0 custodio PASS; F1 Flutter/Drift/OTA/UI PASS; F2 PHP **33 pruebas/279 assertions PASS**; G2 puente schema2 mismo SHA hasta Flutter PASS; 14 Python PASS; V6 G5 ZIP/bundle PASS. CERO repetición de esas suites/ZIP/escaneos sin delta que afecte el contrato.
- V7-R1 devolvió `S0=BLOCKED_SECURITY_HOST`, `G4=HOLD_SECURITY_HOST+HOLD_LINK_IDENTITY`, `S3_ADMIN=BLOCKED_S0`, `S3_STAGING=NOT_READY`, `S4=BLOCKED_HOST_RESOURCE_STABLE`, `ZIP_SHA256=NOT_GENERATED`. No hubo cambios de código, commits, ZIP, push, MariaDB, APK ni teléfono. **No inventar un ZIP V7-R1.**
- La clasificación de Gitleaks ya está hecha en diez ubicaciones: **nueve BENIGN_CONFIRMED**, una URL Power BI preexistente en PR71 sigue **UNKNOWN** por coincidencia de identidad. Cinco eventos históricos se corresponden con cinco ubicaciones PHP del delta. No repetir Gitleaks ni exportar 1.839 archivos.
- El archivo `scripts/tests/test_hostinger_installer_browser.ps1` fue puesto en cuarentena; NO ejecutarlo, restaurarlo para ejecución, añadir exclusiones antivirus ni eludir bloqueos. Tres reportes Gitleaks `.private.json` siguen locales fuera de ZIP por restricción de política; no divulgar, subir, procesar en línea ni forzar borrado.

## 1. PRECONDICIÓN HUMANA DEL GATE S0 — no delegar inferencias

La persona usuaria debe abrir **Bitdefender** en Windows y verificar que el panel indique **«Estás protegido / You are safe»**, que **Protección → Antivirus → Avanzado → Bitdefender Shield** esté **ACTIVADO**, que no aparezcan alertas críticas y que Windows Security → Protección contra virus y amenazas → Administrar proveedores muestre el proveedor esperado. Si todo está correcto, puede informar exclusivamente `BITDEFENDER_ACTIVE_CONFIRMED=YES` (sin credenciales, capturas de cuentas ni registros privados).

`Get-MpComputerStatus` puede mostrar Defender pasivo cuando Bitdefender es antivirus principal. El `productState=0x042000` reportado por V7-R1 no certifica servicio activo; algunos decodificadores marcan su nibble de estado como **Snoozed**. La interfaz oficial del proveedor y el estado de Shield prevalecen para este gate. Si no puede constatarse, **STOP: NEXT_ACTOR=USUARIO_VERIFICA_BITDEFENDER**. No lanzar Codex otra vez para repetir el mismo diagnóstico automatizado ni escribir archivos de evidencia bajo el gate read-only.

Fuente de comprobación oficial: https://www.bitdefender.com/consumer/support/answer/29603/ y https://www.bitdefender.com/consumer/support/answer/9329/ .

## 2. Si y SOLO si Bitdefender está confirmado activo: ejecutar macro único

### A. Seguridad G4: cerrar solo la última referencia pendiente

1. Confirmar en lectura `HEAD/TREE`, worktree limpio y que no hay escritor ajeno. No restaurar/exportar/scannear de nuevo todo; reutilizar informe V7-R1 9/10 benignos.
2. La **página institucional oficial** `https://transformaciondigital.supertransporte.gov.co/index.php/transitotransporte/cda/` expone el enlace **«19082021 CDA OBSERVATORIO»** a `app.powerbi.com` (constatado por el Director el 14-nov-2026). Esto acredita la **existencia de un enlace público institucional**, NO que su href exacto sea idéntico al del archivo `codex/C24_CDA_GEODATA_AUDIT.md:261`.
3. Para determinar identidad, comparar en memoria las URL completas del ancla oficial (extraída de DOM/href de la página oficial; NO abrir el visor Power BI) y el enlace local histórico; decodificar solamente entidades HTML y espacios finales. Reportar SOLO `EXACT_MATCH=YES/NO/UNKNOWN`, sin copiar URL opaca, tokens, hash de su parámetro ni fragmentos. **Si YES**, clasificar esta única posición `PUBLIC_OFFICIAL_REFERENCE` con fuente institucional y cerrar hallazgo. **Si NO/UNKNOWN**, mantener `HOLD_LINK_IDENTITY`; no pedir otras 9 clasificaciones ni reanalizar Gitleaks.
4. Con `EXACT_MATCH=YES`, antivirus activo, 10/10 hallazgos explicados sin secretos, historia delta inspeccionada y revisión de workflows gratuita: verificar ancestro PR71 remoto y publicar UNA sola vez `feat/picoradar-v6r4-lab-candidate` con `git push` normal **solo si GitHub permite y no hay rama divergente**. Prohibidos `--force`, PR/merge automático, main, CI pagada, Hostinger y producción. Si cualquier gate NO pasa, **NO PUSH**, preservar bundle sin segunda tentativa. No hacer del `push` condición para las tres pruebas QA independientes.

### B. Publicador/editorial S3: exactamente tres casos focales pendientes

El V5 **no incluyó** los casos de las clases `RestrictionPublicationServiceTest` ni `RestrictionMaterialApprovalWorkflowTest`, aunque sí certificó 33 pruebas distintas. Si no existen logs previos del MISMO SHA para estos tres métodos, ejecutar una sola selección PHPUnit **con lista preflight exactamente 3**:

- `Tests\Feature\RestrictionPublicationServiceTest::test_selective_publication_and_city_rollback_preserve_other_cities`
- `Tests\Feature\RestrictionPublicationServiceTest::test_normal_publication_rejects_coverage_loss_before_writing_release`
- `Tests\Feature\RestrictionMaterialApprovalWorkflowTest::test_active_admin_approval_is_bound_to_exact_city_sha_sources_and_revision_then_published_separately`

Reutilizar entorno MariaDB QA efímero, solo loopback, destino confirmado tanto vía cliente como por configuración Laravel efectiva (`database.default`, HOST, PORT, DATABASE, DB_URL vacío), `APP_KEY` sintética, SQL estricto, `explicit_defaults_for_timestamp=ON`; comprobar base vacía y apagar DB al terminar. No tocar un host/base de producción ni repetir 33 PHP o bridge G2. Si 3 PASS, `S3_ADMIN=PASS_3_FOCAL`; si ambiente no seguro, `BLOCKED_ENV`; si defecto reproducible, máximo una corrección causal mínima con RED/GREEN focal, sin rediseñar motor y documentando nuevo HEAD/TREE.

Para staging real: marcar `READY_FOR_AUTHORIZED_STAGING` solamente si están preparados el snapshot completo **respecto de todas las coberturas aprobadas**, manifest/versión/SHA, rollback y un entorno aislado autorizado. Si no, reportar PRIMER requisito concreto faltante; no repetir loopback para simular CDN ni publicar nacional LAB parcial.

### C. Android S4: no repetir bloqueo de memoria

Host anterior: 3,37 GiB libres de pagefile vs gate interno mínimo 6 GiB; Gradle `-Xmx8G`. Si no hay cambio MATERIAL de recursos o host alternativo gratuito y autorizado, `S4=BLOCKED_HOST_RESOURCE_STABLE` y **NO ejecutar Gradle**. Solo compilar una APK debug si un preflight nuevo prueba recursos reales suficientes. No tocar Mi A3, firma, antivirus, pagefile, Actions pagas o producción sin autorización. Registrar requisito concreto del host para cierre físico.

### D. Evidencia de UNA entrega y fin

Entregar UN archivo ZIP: `D:\codex\_REPORTES\PicoRadar\V7R1-POST-S0-20261114\delivery\PICORADAR_V7R1_POST_S0_EVIDENCIA_UNICA.zip`. Dentro: informe FINAL_REPORT.md, tabla GATES.csv con estados y códigos de salida, solo informe Gitleaks **sanitizado** sin URL opaca, resultado exact-match YES/NO/UNKNOWN, logs mínimos de 3 PHP o BLOCKED, estado de recursos Android, bundle Git original verificable si HEAD sin cambios (o bundle nuevo si cambió), RESTORE.md y MANIFEST.csv de SHA256/bytes/CRC32. No reportes `.private.json`, tokens, claves, dumps de QA, PDF/PowerBI con parámetros, ZIP previos. Verificar CRC/hash/restore una vez. Si un impedimento de política bloquea escritura, NO evadir ni afirmar ZIP creado.

Línea final requerida: `TASK_ID | S0=... | G4=... | S3_ADMIN=... | S3_STAGING=... | S4=... | HEAD=... | TREE=... | ZIP_SHA256=... | RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`.

## 3. Decisiones congeladas / prevención pingpong

- Arquitectura: un solo motor schema2 con reglas habilitables por municipio, ciudad, pueblo, departamento y modalidad cuando la fuente oficial respalde ámbito/horario; OTA de datos. No desarrollar un motor por ciudad ni actualizar APK por calendario ordinario.
- Una comunicación oficial de alcaldía/gobernación sirve como fuente de los campos que publica; no exigir PDF de decreto siempre. Si faltan datos de cobertura, vacaciones, festivos, horario o excepciones, usar `UNKNOWN/STALE` y no declarar circulación libre.
- Las 14 autoridades/33 códigos/21 coberturas parciales/115 reglas son LAB, no cobertura jurídica nacional completa. No publicar snapshot parcial como producto nacional.
- No abrir V8, no más escaneos completos, no nuevas 10+10 pasadas a Codex; el director auditó el delta. Cuando los tres admin PASS y G4 se cierre, el siguiente gate real es APK/build y staging autorizado, no un inventario general.

**FIN — QUIÉN SIGUE: PERSONA USUARIA CONFIRMA BITDEFENDER; DESPUÉS CODEX LUNA SI ACTIVO; TRAS ZIP CHATGPT DIRECTOR.**