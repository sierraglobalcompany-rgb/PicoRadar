# CODEX LUNA — PICORADAR V6R4 V7-R1 — CIERRE RESIDUAL REAL, SIN PINGPONG

**TASK_ID:** `PICORADAR-V6R4-V7R1-SECURITY-GITHUB-STAGING-ANDROID-ONCE-20261114`  
**ORIGEN:** revisión crítica del V7 anterior por ChatGPT Director, **no** otro ciclo de auditorías ni una nueva fase V8.  
**EJECUTAR SOLO si el V7 original no comenzó**; si comenzó, no competir ni abortarlo: terminar aquel y entregar su ZIP.  
**RESPONSABLE:** Codex Luna ejecuta; ChatGPT Director recibe UN ZIP, audita solo el delta y decide la siguiente aprobación.  
**PRODUCT_RELEASE=NO_GO** aunque este lote pase sus gates: faltan Android físico, snapshot editorial nacional aprobado, publicación en entorno autorizado y decisión de lanzamiento.

## 0. Estado congelado y evidencia que NO debes repetir

- Proyecto `sierraglobalcompany-rgb/PicoRadar`. Candidato local reportado: `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`; rama `feat/picoradar-v6r4-lab-candidate`.
- `HEAD=15948a50332589ff3d1fb3157b6976809fe5a680`, `TREE=8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`. Antecesor remoto PR71 `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`: **12 commits** locales adicionales.
- Evidencia V6: `PICORADAR_V6R4_V6_FOCAL_EVIDENCIA_UNICA.zip`, SHA-256 `8e430ada1a882bc3fe4bc3e3283b835d8cba275a5c38ac2dc4eb7762d2bf717c`; bundle interno `GIT/full-final.bundle`, SHA-256 `dad16fccb97493add593bbacbd13edfb1db60219f14b445fd5e22141356639a1`. V6 verificó ZIP, restauración y clon íntegro; **no repetir en preflight**.
- CERRADOS sobre este mismo HEAD: F0 custodia PASS, F1 tres pruebas Flutter/OTA/Drift/UI PASS, F2 **33 PHP/279 aserciones PASS**, G2 puente real Laravel schema2→manifest/SHA→HTTP loopback→Flutter/Drift PASS (un test), 14 Python PASS. **No ejecutar otra vez esas suites, ni V5/V6, ni compilar datos nacionales sin motivo.**
- G3 Android **BLOCKED_HOST_RESOURCE_STABLE**: pagefile libre medido 3,37 GiB, umbral documentado 6 GiB, Gradle `-Xmx8G` / `MaxMetaspaceSize=4G`; sin APK. G4 seguridad **HOLD_REVIEW_REQUIRED**: Gitleaks 8.30.0 detectó 5 eventos históricos en `PR71..HEAD` y 10 posiciones en el árbol HEAD (no sumar como 15 secretos).
- Producto congelado: UN motor nacional schema2 (Flutter/Drift + Laravel), reglas por autoridad, ámbito, municipio/departamento/localidad y modalidad **habilitables por datos**; OTA versionada sin APK por cambio normativo; `UNKNOWN/STALE` ante ambigüedad. Portales oficiales de alcaldías/gobernaciones bastan para **lo que expresamente publican**; no exigir PDF de decreto por rutina. Nunca publicar el snapshot LAB 14 autoridades/33 códigos/21 coberturas parciales/115 reglas como si fuese nacional y completo.
- Lee `AGENTS.md`/leyes L1–L6 y las instrucciones pertinentes de ese repositorio **solo para lo que vayas a tocar**. Respeta WIP ajeno. Cero cambios a main, PR71/79, Hostinger, CDN real, datos de usuarios, firmas, Xiaomi Mi A3, merge, force-push, rebase o CI de pago.

## S0 — Preflight mínimo / protección del host (una vez)

1. Detecta escritor PicoRadar activo. Verifica `git status --porcelain`, `git rev-parse HEAD`, `git rev-parse HEAD^{tree}` en candidato existente. Si limpio e idéntico, úsalo. Si no, no lo manipules: clon aislado NUEVO desde el bundle V6 verificado, sin sobrescribir carpetas ni borrar WIP. No rehagas la custodia histórica.
2. Confirma **antivirus efectivamente activo** en Windows: `Get-MpComputerStatus` y/o estado del antivirus registrado en Centro de Seguridad de Windows si Defender está subordinado a otro proveedor. No confundir Defender pasivo con equipo desprotegido. Si el producto activo está deshabilitado, reactivarlo por la vía oficial y comprobarlo; si no puedes verificar protección, `G4=HOLD_SECURITY_HOST`, solo operaciones de lectura segura. **Jamás desactivar antivirus, añadir exclusiones, recuperar para ejecución ni ejecutar** `scripts/tests/test_hostinger_installer_browser.ps1` que fue puesto en cuarentena. Revisión estática solo si necesaria, sin ejecutar PowerShell de ese archivo.
3. Reportes privados Gitleaks del V6 en `D:\codex\_REPORTES\PicoRadar\V6R4-V6-FOCAL-20261114\qa\gitleaks-{history,tree,tree-retry}.private.json`: utilizar localmente, no copiar valores a terminal guardada, CSV público, GitHub, chat, ZIP o una consulta externa. Si no pueden borrarse por política, NO forzar: documentar localización, permisos y retención; no inventar que fueron eliminados.
4. Reusar el escaneo V6 que cubrió 1.839/1.839 archivos y 12 commits. **No descargar de nuevo Gitleaks ni reexportar el árbol para eludir antivirus; no repetir escaneo salvo código nuevo real.**

## S1 — Clasificar los hallazgos concretos sin bloqueo artificial ni filtraciones

1. Inventaría las **10 ubicaciones del árbol** y mapea separadamente los **5 eventos históricos** sin sumar duplicados, utilizando SOLO reportes privados en lectura local. Clasifica cada referencia por `BASE_PR71` / `DELTA_12_COMMITS`, regla, consumidor y fundamento en estados `BENIGN_CONFIRMED`, `POTENTIAL_SECRET`, `UNKNOWN`. No transcribir valores, enlaces con parámetros, huellas derivadas de tokens ni snippets de findings. Rutas verificadas:
   - `data/releases/viaje_r2/toll_decision_ledger_v1.json:4`
   - `codex/C24_CDA_GEODATA_AUDIT.md:261`
   - `mobile/lib/features/garage/data/garage_favorites.dart:5`
   - `mobile/lib/features/pico_placa/data/pico_preferences.dart:3`
   - `scripts/compile_viaje_r2_data.py:1150`
   - `server/tests/Feature/RestrictionG34EditorialImportLabTest.php:183`
   - `server/tests/Feature/RestrictionSchemaV2LabRoundTripTest.php:68,300,362,411`
2. El Director ya comprobó que las **cinco primeras posiciones existían en PR71** con el mismo contenido y que las otras cinco están en tests PHP del delta. Esto NO prueba que toda coincidencia sea inocua; verificar contexto una sola vez, no todo Git.
3. **Corrección decisiva frente al V7 original — Power BI:** la fuente del archivo `codex/C24_CDA_GEODATA_AUDIT.md` es la página oficial de la Superintendencia de Transporte `https://transformaciondigital.supertransporte.gov.co/index.php/transitotransporte/cda/`, que enlaza públicamente un tablero Power BI de CDA, fuente RUNT. Una publicación oficial **sí acredita que se enlazó deliberadamente un tablero público**, sin requerir por sistema una carta adicional del dueño. Para confirmar que la URL del repositorio es la misma:
   - Hacer como máximo **UN GET** de la página oficial de la Superintendencia por HTTPS y leer sus enlaces `href` a `app.powerbi.com`; **NO navegar a Power BI**, no hacer peticiones a ese host, no loguear ni enviar parámetros del enlace a terceros.
   - Comparar **localmente en memoria** el `href` oficial decodificado con la URL del archivo repositorio, normalizando solo entidades HTML y espacios finales; no modificar ni truncar parámetros al comparar. Emitir únicamente `OFFICIAL_LINK_EXACT_MATCH=YES/NO/UNKNOWN`, URL de la página institucional (sin parámetros) y fecha de consulta.
   - Si `YES`, clasificar como **PUBLIC_OFFICIAL_REFERENCE** (finding `grafana-api-key` compatible con falso positivo para una URL oficial), siempre que el archivo no contenga otro material privado. No inferir que el dashboard licencia exportar datos sensibles o que sirve de fuente pico y placa.
   - Si `NO`, no hay red, el HTML no expone el enlace o el documento difiere: `POWERBI_REFERENCE=UNKNOWN`, revisión humana focal **solo de esa referencia**, `G4=HOLD_LINK_IDENTITY`. No abrir el token, no forzar GitHub, pero **continuar S3/S4 independientes**. No afirmar que una URL antigua es secreta solo por tener parámetro opaco, ni que es segura sin igualdad verificable.
4. Los 9 restantes: confirmar si son **IDs de dominio/almacenamiento o fixtures sintéticos**, no credenciales de acceso. Si aparece secreto real o credencial de terceros: `G4=HOLD_REAL_SECRET`; no publicar, no rotar o reescribir historia sin aprobación. Prohibidas allowlists masivas y supresión de reglas completas.
5. Entrega solo `SECURITY_FINDINGS_SANITIZED.csv` con **10 filas** + `HISTORY_EVENTS_SUMMARY` por número de eventos mapeados, columnas ubicación/regla/base-delta/clase/estado/justificación breve, nunca valores sensibles. Si G4 continúa HOLD, **NO DEVOLVER OTRO LOTE SOLO PARA VOLVER A ESCANEAR**: reportar cuestión precisa que requiere intervención del director/propietario.

## S2 — Publicar rama LAB una sola vez ÚNICAMENTE si G4=PASS

1. Condiciones acumulativas: antivirus activo, 10 ubicaciones clasificadas (`BENIGN_CONFIRMED` o `PUBLIC_OFFICIAL_REFERENCE` acreditada), 5 eventos históricos mapeados, sin secretos/UNKNOWN, worktree limpio, sin otros escritores y sin valores privados en artefactos. **No equiparar hallazgos en historia y árbol a 15 tokens**.
2. Confirmar mediante UNA consulta de solo lectura que el SHA `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` del ancestro PR71 coincide con el remoto esperado y que los 12 commits son los únicos nuevos; esto delimita la historia que va a exponerse. Si el ancestro no coincide, HOLD (no hacer reseteos). Inspeccionar workflows para no abrir PR ni disparar CI paga; `push` de los workflows actuales está dirigido a main, pero corroborar antes.
3. Comprobar si existe `refs/heads/feat/picoradar-v6r4-lab-candidate` remota. Solo si **no existe**, ejecutar UN `git push` ordinario de esa rama a ese ref y comprobar que el SHA remoto coincide con el HEAD local. No push de main, PR71, PR79, tags, PR automático, `--force`, `--mirror`, scripts de publicación ni hooks ajenos. Si 403, rama divergente, coste incierto o desvío de identidad: `G4=HOLD_REMOTE`, conservar bundle sin reintentos.
4. Si NO puede aprobarse G4, **no hacer `push`**. Guardar la causa concreta; no trasladar inseguridad a una rama nueva por presión de continuidad. Documentación PR79 no es evidencia de código remoto.

## S3 — Publicador/editorial: solo TRES casos NO certificados en V5, no suite nueva

1. **Delimitar evidencia real antes de declarar PASS.** Inspección directa del `LOGS/phpunit-list-tests.stdout.log` del ZIP V5: las 33 pruebas aprobadas pertenecen a `DatasetPublisherTest` (9), `RestrictionSchemaV2LabRoundTripTest` (7), `DatasetAuthorizationTest` (6), `DatasetReleaseValidationTest` (6), `RestrictionImportServiceTest` (4) y `RestrictionNationalLabPublicationTest` (1). **NO INCLUYERON** `RestrictionPublicationServiceTest` ni `RestrictionMaterialApprovalWorkflowTest`. No atribuirles el PASS V5.
2. Ya están certificados para este HEAD los contratos de dataset/manifest/rollback de `DatasetPublisherTest`, fuente/release schema2 de `RestrictionSchemaV2LabRoundTripTest` y G2 Flutter 1/1. NO repetirlos. Para cerrar la brecha ADMIN de selección por ciudad y aprobación editorial, buscar primero en evidencias históricas **un log ejecutado con SHA idéntico y los siguientes nombres exactos**; si existe, registrar `REUSED_PASS` con ruta/hash/exit sin retest:
   - `Tests\Feature\RestrictionPublicationServiceTest::test_selective_publication_and_city_rollback_preserve_other_cities`
   - `Tests\Feature\RestrictionPublicationServiceTest::test_normal_publication_rejects_coverage_loss_before_writing_release`
   - `Tests\Feature\RestrictionMaterialApprovalWorkflowTest::test_active_admin_approval_is_bound_to_exact_city_sha_sources_and_revision_then_published_separately`
3. Si no hay ese PASS verificable: ejecutar **UNA sola selección focal de estos TRES casos**, no las 12 pruebas de ambas clases ni 33 anteriores. Reutilizar únicamente procedimiento QA MariaDB de V5, con DATADIR nuevo efímero, `127.0.0.1` puerto libre, SQL estricto, `explicit_defaults_for_timestamp=ON`, `APP_KEY` aleatoria exclusiva de QA y XML PHPUnit temporal. Antes de `RefreshDatabase`, demostrar con cliente y Laravel efectivo `database.default=mysql`, HOST/PORT/DATABASE/USER, DB_URL vacío, datadir/instancia local del proceso recién lanzado y ausencia de tablas ajenas. **Nunca** apuntar producción, Hostinger ni una base compartida. Crear `--list-tests` con filtro de esos tres nombres exactos; si no enumera **exactamente 3**, NO ejecutarlos. Ejecutar una vez, registrar exit/3 resultados y detener MariaDB dejando puerto cerrado. Un error real permite UNA corrección causal mínima y prueba focal RED→GREEN; no refactor de motor ni otro lote.
4. Si QA MariaDB temporal NO está disponible o falta cualquier identidad verificada, `S3_ADMIN=BLOCKED_ENV_QA`; NO llamarlo PASS ni pedir las 33 pruebas otra vez. Si salen los tres PASS, `S3_ADMIN=PASS_3_FOCAL`. Si ya había evidencia exactamente equivalente, `S3_ADMIN=REUSED_PASS_3`.
5. **Separar staging real de QA:** una aprobación administrativa local no certifica CDN, actualización externa en teléfono ni fuentes nacionales completas. Si solo falta autorización/infraestructura para staging, `S3_STAGING=READY_FOR_AUTHORIZED_STAGING` y enumerar insumos concretos: instancia aislada, snapshot COMPLETO respecto a coberturas previamente aprobadas, manifest/versionado/rollback, prueba de consumidor con bytes de dicha instancia y permiso de publicación. NO inventar otro test de loopback ni usar el LAB nacional parcial como catálogo de producto.

## S4 — Android: bloqueo de recursos con salida operativa, no Gradle repetido

1. Verificar si el host cambió materialmente desde V5: pagefile libre antes 3,37 GiB, umbral previo 6 GiB, `-Xmx8G`. Si sigue igual, `S4=BLOCKED_HOST_RESOURCE_STABLE`, **sin invocar Gradle** ni repetir búsquedas de SDK.
2. Si hay host local gratuito distinto o memoria libre/comprometida ampliada de forma autorizada: realizar **un único** preflight de recursos reales (RAM física libre, commit/virtual memory disponible, espacio disco y Java/Android SDK), no inferir capacidad por pagefile aisladamente. Solo si resulta apto, `flutter build apk --debug --flavor dev` con SDK y dependencias fijadas, compilar UNA vez, guardar código de salida, ubicación y SHA del APK si éxito.
3. Prohibido: desactivar antivirus, ajustar pagefile sin autorización, cambiar firma, bajar memoria JVM arbitrariamente, activar Actions de pago, desinstalar o tocar el Mi A3 y alterar producto para que compile. Si está bloqueado, reportar **requisito técnico preciso para otro host o autorización de ajuste de memoria**, sin crear otro ciclo de diagnóstico. Build debug no sustituye QA física.

## S5 — Entrega UN ZIP y decisión sin más pingpong

**ÚNICO artefacto final:** `D:\codex\_REPORTES\PicoRadar\V6R4-V7R1-ONEPASS-20261114\delivery\PICORADAR_V6R4_V7R1_EVIDENCIA_UNICA.zip`.

Incluir: `FINAL_REPORT.md`, `GATES.csv` (S0/S1/G4/S3/S4, comando/salida/exit real), `SECURITY_FINDINGS_SANITIZED.csv`, acta `OFFICIAL_LINK_EXACT_MATCH` sin parámetros, tabla de contratos S3 con evidencia preexistente y salida focal 3/3 o bloqueo concreto, evaluación Android S4, logs mínimos saneados, `RESTORE.md`, un único Git bundle del HEAD **solo si cambió** o **el bundle V6 único reutilizado sin repetir export** y `MANIFEST.csv` (bytes/SHA256/CRC32 de miembros, excluyéndose a sí mismo). Verificar una sola vez ZIP CRC, extracción, 100% miembros, commit SHA/TREE y bundle restaurable. **No incluir archivos privados Gitleaks, PowerBI opaco, credenciales sintéticas, ZIP preliminares, JSON editorial no autorizado ni archivos ajenos.**

Si HEAD no cambia, referenciar el bundle original V6 y usarlo dentro de UN ZIP final para entrega autocontenida; no recomprimir otros ZIP completos. Si algún acceso está bloqueado por policy, no evadir: documentar HOLD. Línea final:

`TASK_ID | S0=... | G4=... | S3=... | S4=... | HEAD=... | TREE=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`

**No crear V8 por inercia:** el siguiente actor decidirá si falta una autorización externa concreta, el dispositivo Android o un defecto funcional genuino; no otra auditoría de lo mismo.

## Anexo — 10 pasadas VERDUGO + 10 JUEZ ya realizadas por CHATGPT (NO tarea de Codex)

| Pasada | Control adversarial aplicado al V7 anterior | Corrección V7-R1 |
|---|---|---|
| V01 | Exigía autorización nueva incluso para enlace oficialmente divulgado | Comparación exacta de enlace desde entidad oficial; escalamiento solo si no coincide |
| V02 | Podía declarar secreto real sin distinguir token de URL pública | Clasificaciones separadas y prueba de coincidencia, sin transcribir valor |
| V03 | Cinco eventos historia + diez árbol podían duplicarse | Mapeo explícito, sin sumarlos como 15 credenciales |
| V04 | Escaneo de árbol ya PASS de cobertura, se podía repetir por rutina | Prohibida nueva exportación salvo cambio efectivo |
| V05 | Podía reactivar malware al rescatar PS1 de cuarentena | Inspección estática y Defender activo; nunca ejecutar ni permitir PS1 |
| V06 | La base PR71 pública no justificaba un push sin verificar identidad remota | Igualdad SHA ancestro remoto + acotación de 12 commits |
| V07 | S3 atribuía PASS V5 a clases administrativas que V5 no ejecutó | Selección nueva de 3 casos focales, solo si falta evidencia previa |
| V08 | Confundía QA aislado con staging real | READY_FOR_AUTHORIZED_STAGING, sin test equivalente inventado |
| V09 | Bloqueo Android podía producir otra compilación fallida con mismo host | Preflight una vez solo ante cambio real y recomendación operacional |
| V10 | Alto riesgo de repetir ZIP/escaneos/historia | Un único ZIP/autocontenido y bundle reutilizado |
| J01 | ¿Coincidencia exacta equivale a aprobación legal de todos los datos? No | Solo clasifica una referencia web pública, no autoriza datos sensibles |
| J02 | ¿Encontrar cinco fixtures equivale a cinco PASS? No | Evidencia por regla, consumidor y uso, sin allowlist masiva |
| J03 | ¿Puede avanzar staging si seguridad está en hold? Sí, solo QA local seguro | S2 bloqueado, S3 independiente y limitado |
| J04 | ¿Puede ignorarse antivirus por usar un clon? No | S0 obligatorio y solo operaciones read-only si host inseguro |
| J05 | ¿Cabe subir historia previa sin verificar? No | Confirmar ancestro remoto y commits añadidos |
| J06 | ¿Puede dispararse CI gratuito sin verificar coste? No | Revisar triggers; no PR ni flujo pago |
| J07 | ¿Pueden darse por PASSED dos clases no incluidas en las 33? No | Mantener 33 PASS y exigir 3 focales administrativos o BLOCKED_ENV |
| J08 | ¿Debe Codex decidir una nueva arquitectura schema2? No | Motor y publicador actuales congelados |
| J09 | ¿Permite 3,37 GiB pagefile inferir fallo eterno? No | Bloqueo del host previo, reevaluación solo si condiciones cambian |
| J10 | ¿Un PASS focal permite release? No | PRODUCT_RELEASE=NO_GO hasta staging, Android físico y datos aprobados |

**FIN — QUIÉN SIGUE: CODEX LUNA (SOLO SI V7 NO COMENZÓ); LUEGO CHATGPT DIRECTOR.**