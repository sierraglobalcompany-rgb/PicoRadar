# CODEX LUNA — PICORADAR M1D V2 · ORDEN ÚNICA PARA CANDIDATO LOCAL BOGOTÁ CON LARAVEL · KISS + PONYTAIL

**TASK_ID:** `PICORADAR-M1D-LARAVEL-PUBLISHER-CANDIDATE-KISS-20261107-DIRECTOR` (MISMO identificador que M1D anterior; revisión documental V2, NO nuevo lote).

**REGLA DE NO INTERRUPCIÓN:** esta V2 sustituye la orden M1D inicial **solo si Codex aún no comenzó G0**. Si ya comenzó M1D con G0 PASS, NO interrumpir ni pedir que reinicie o aplique esta V2; recibir el ZIP de ese lote y auditar solamente diferencias. Si la ejecución M1D ya terminó, no abrir otra: adjuntar su ZIP único. El cambio V2 consiste en precisar controles críticos y la fuente de continuidad, no en alterar la arquitectura, el alcance, los ocho estados M1C ni los requisitos aprobados.
  
**ORDEN DIRECTA DEL DIRECTOR:** ChatGPT. **EJECUTOR EXCLUSIVO:** Codex Luna, manos ejecutoras.  
**Fecha de decisión:** 2026-11-07, Colombia. **Macroplan vigente:** M0–M4 Plan Maestro V2, PR #79 documental Draft.  
**Estado M1C:** CERRADO COMO DIAGNÓSTICO `PARTIAL`; NO reabrir ni repetir M1B/R21/M1C.  
**RELEASE:** `NOT_APPROVED`; **producción y GitHub código:** `PROHIBIDO`.  
**Único entregable al propietario:** `PICORADAR_M1D_LARAVEL_CANDIDATO_Y_EVIDENCIAS_UNICAS_20261107.zip` (un ZIP con TODO dentro, resumen/chat solo ruta real y SHA256).  
**Regla de interacción:** no solicitar nuevos prompts o 17 archivos sueltos; usar decisiones y bifurcaciones de esta orden. Bloquear únicamente acciones que excedan autorización, siempre con evidencia. No prometer ejecución en segundo plano.

## A. CONTEXTO CERTIFICADO Y FUENTES AUTORITATIVAS

### A1. Diagnóstico recibido / evidencia real

El director recibió físicamente y verificó integralmente el paquete de la ejecución M1C V2:

- Paquete `PICORADAR_M1C_RESULTADO_EVIDENCIAS_UNICAS_20261107.zip`, **SHA256 externo `f04521c240b4315fa036c797eb6c8abb70bd4ee79f60add88eb17eccaaa2e3dd`**, 10.968 bytes. CRC, manifiesto y hashes internos 7/7 PASS. **NO exigir este ZIP como entrada obligatoria** para M1D: usa su diagnóstico aquí y VERIFICA de nuevo contra H4 antes de tocar código.
- Git H4 local reportado y árbol: `HEAD=1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c`, `TREE=dc2f2fdc5521af4cb4ad16969d76248b1e021688`. El PR71 GitHub remoto `HEAD=0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` NO contiene necesariamente H4. El H4 de M1C estuvo en clon sparse limpio y sin remotes; original dirty /101 WIP protegido, **no hash verificado**. No afirmar WIP PASS.
- Runtime H4 `mobile/assets/datasets/restrictions/restrictions_v1.json`, SHA256 reportado `ce95abacc2968bc4267d3edaef6bf9320dba1d99d40daf56b6c7e7cc46e38341`, 211.555 bytes. Catálogo H4 `mobile/assets/catalogs/pico_jurisdiction_catalog_20261025.json`, SHA256 `e0d038e2ce46692a2bf27f5f0376d9e24d6dde0a3369b7a969ef66975fa3b91e`, 531.639 bytes.
- El compilador H4 `scripts/compile_pico_operational_catalog.py` (blob `553389dac1fc1b70b36a453f986ab7828964322f`, SHA256 `2b70cfee51d915b503e8e3ffafc957bc6b4cb15c2600b5684f131409dda53851`) lee Excel/municipios/runtime JSON y genera catálogo/auditorías. **NO escribe** el JSON runtime. Compilador remoto PR71 es una versión distinta: blob `1d2c23a5965d688930e5670549863a9d8d2f1aff`. No crear una controversia ni trabajo de reconciliación general: atribuír diferencias al SHA correspondiente.
- M1C comparó **8/8** núcleos: Medellín auto/moto y Cartagena moto `ALREADY_MATCHES` SOLO núcleo; Bogotá auto noviembre y Dosquebradas auto/moto `BLOCKED_RUNTIME_WRITER_NOT_FOUND` DEL JSON ESTÁTICO; Cartagena auto/Villavicencio auto `BLOCKED_SCOPE_OR_SOURCE`. `CHANGED=0`; **tests `NOT_RUN`**; `WIP_CONTENT=NOT_VERIFIED`.
- M1C `next_actor=CHATGPT` quedó atendido: el director comprobó legal y arquitectura, y **autoriza este M1D** sin reabrir M1C.

### A2. Decisión de arquitectura del director, PRIORITARIA

**ERROR A EVITAR:** `BLOCKED_RUNTIME_WRITER_NOT_FOUND` de M1C no significa que PicoRadar carezca de un publicador. En PR71/H4 verificar estos servicios Laravel EXISTENTES:

- `server/app/Services/RestrictionPublicationService.php` — método `publishVersions` fusiona un `RestrictionRuleVersion` validado con el dataset vigente. `publish`/`rollbackCity` requieren actor/validación y salvaguardas de concurrencia.
- `server/app/Services/RestrictionPayloadEncoder.php` — serialización/canonicalización JSON.
- `server/app/Services/DatasetPublisher.php` — guarda asset versionado en el disco configurado, valida SHA, revision y manifiesto/rollback. `server/config/datasets.php` tiene discos de draft/published.
- `server/app/Services/RestrictionContractValidator.php`, `DatasetReleaseValidator.php`; modelos `Dataset`, `DatasetRelease`, `DatasetSource`, `RestrictionRuleVersion` y rutas/admin existentes.
- **Contrato documental superior** `docs/agents/PICORADAR_SOURCE_AGENT_OPERATING_CONTRACT_V1.md`: **Laravel es la única autoridad de aprobación, generación, publicación y rollback**. El investigador/agente futuro solo lee y propone. No crear segundo motor/publicador Python/Flutter. No alterar este contrato.

**Decisión vinculante:** reutilizar el flujo Laravel B07. El gap por resolver es la **trazabilidad/entrega entre el asset de Laravel y el runtime estático/consumo Flutter**, no inventar otro writer. La presencia del publicador GitHub NO demuestra que H4 incluya exactamente la misma implementación, que exista endpoint de descarga, que el teléfono sincronice ni que un asset de prueba equivalga a un release. Registrar cada afirmación con ruta+método+SHA de H4 y test del flujo, o `NOT_VERIFIED`. El servicio `RestrictionPublicationService::publishVersions` del PR71 encadena de manera directa validación, borrador y publicación; **no invocar este método en entorno real para conseguir un simple candidato**. Primero usar harness de pruebas con SQLite/discos fake y los servicios/validadores existentes.
 Se permite un **único adaptador mínimo dentro del Laravel existente**, exclusivamente si es imprescindible y si no duplica validaciones/publicación. De existir ya forma segura de obtener el candidato por servicios/fixture, **NO escribir código de adapter por obligación**. No se autoriza cambiar schemas, crear tablas, introducir dependencias, microservicios, un segundo almacén legal o migrar el frontend.

### A3. Jerarquía y seis leyes

Leer del **checkout local real**, antes de editar:

1. `AGENTS.md`, `AGENTS.override.md` si existe, `docs/CURRENT.md`, `PicoRadar_RECOVERY_HANDOFF.md`, `docs/DESIGN_CONTRACT.md`, `docs/SOP.md`.
2. Baselines `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx` y `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx` si son accesibles (no fingir lectura de DOCX que no se puede abrir). Contratos de datos, flujo de restricciones/garaje y modelo de versión. Precedencia seguridad/privacidad > Cierre Global > Arquitectura > Flujos > Design/UX > Plan Maestro > CURRENT. NO alterar UX, navbar, login, banners, monetización ni garaje.
3. Originales PingPongLaw L1–L6 en workspace disponible; repositorio `sierraglobalcompany-rgb/PingPongLaw`, `docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md` como referencia verificable, sin inventar que está instalado localmente. L1 KISS+Ponytail, L2 antirruido, L3 antiparches, L4 humano, L5 independencia/falsos PASS, L6 antipingpong.
4. En GitHub, `docs/plans/PICORADAR_PLAN_MAESTRO_V2_NACIONAL_20261107.md` (apartado **Q**), `docs/agents/PICORADAR_AGENT_ERRORS_DECISIONS_LEDGER_20261107.md` (SRC-23/24) y `docs/agents/PICORADAR_SOURCE_AGENT_OPERATING_CONTRACT_V1.md`. PR79 HEAD documental esperado tras actualización `a25d829d6d5860e8c073cabf8f0e9b557ac8c49b`; **no hacer git pull sobre repos originales ni escribir en GitHub**.

## B. ALCANCE EXACTO: UN CAMBIO FUNCIONAL PEQUEÑO, NO UNA SEGUNDA PLATAFORMA

**Objetivo verificable:** demostrar en entorno temporal, con pruebas efectivas, la cadena existente

`fuente oficial revisada + propuesta Bogotá noviembre → versión/regla validada según contratos actuales → serialización Laravel existente → asset JSON de candidato con SHA → contrato de lectura del motor Flutter (sin activación)`.

No afirmar que el servicio actual ya implementa el puente móvil si no se demuestra. El resultado aceptable puede ser un candidato local validado sin código (`M1D_NO_CODE_NEEDED`), un patch mínimo de adaptador probado (`M1D_LOCAL_CANDIDATE_PASS`) o un bloqueo causal localizado (`M1D_BLOCKED_<causa>`), pero no un nuevo informe que solo diga "no writer" sin mirar Laravel.

### B1. Bogotá: hechos jurídicos aprobados solo para candidato de prueba

**Fuente oficial exacta:** `https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-bogota-vehiculos-particulares-1-30-de-noviembre-de-2026` (publicación 1-Nov-2026, contrastada por director 7-Nov-2026). Área: Bogotá particular ordinario, **NO** pico y placa regional. Zona horaria `America/Bogota` (UTC−05:00). Horario ordinario L–V `06:00–21:00`. Primer día de alcance 1-Nov-2026, fin calendario 30-Nov-2026 (parámetro de intervalo JSON según contrato real: si exclusivo, `2026-12-01T00:00:00-05:00`; no dar cobertura diciembre). Fecha impar: **pueden circular** 1,2,3,4,5 → **restringidos** 6,7,8,9,0. Fecha par: **pueden circular** 6,7,8,9,0 → **restringidos** 1,2,3,4,5. No intercambiar "permitidos" con "restringidos". Festivos 2 y 16-Nov: medida **regional de ingreso** en corredores, no fusionarla en regla ordinaria. Exenciones individuales, permisos solidarios y polígonos/regional NO se infieren, ni se genera estado `ALLOWED` de cobertura total sin evidencia y semántica representable. `source_checked_at` solo se marca si hay captura real por este lote; la verificación del director es externa al runtime y no se disfraza de nueva captura de Codex.

**Pruebas focales obligatorias en el código real** (ajustar nombres y fixtures al motor existente, sin repetir 3.000 pruebas):

1. Mar 03-Nov, 07:00 COT, último dígito 6/0: restringido en regla ordinaria; terminación 1/5: no restringido por ESA regla, pero no prometer permiso absoluto si excepciones/perímetro faltan.
2. Mié 04-Nov, 07:00, dígito 1/5: restringido; 6/0: no restringido por ESA regla. Comprobar inversión desde texto de **"pueden circular"**.
3. Lun 30-Nov, 08:00, día par: terminación 1–5 restringida; NO heredar octubre; `2026-12-01` sin regla aprobada → UNKNOWN, nunca verde.
4. 05:59 fuera ventana; exactamente 06:00 dentro; 20:59 dentro; exactamente 21:00 fuera: si el motor sin ámbito completo devuelve UNKNOWN, NO convertir ausencia de restricción en `ALLOWED` global.
5. **Festivos 02-Nov y 16-Nov (lunes):** la fuente oficial los marca como **pico y placa regional de ingreso**, no como jornada de restricción ordinaria urbana. Probar explícitamente: `URBANO_ORDINARIO=NOT_APPLICABLE` en esos festivos, y `REGIONAL=SEPARATE_RULE_OR_UNKNOWN` si la regla por corredor/hora no está aprobada o representada; NO aplicar a ciegas la paridad de un lunes no festivo ni afirmar `ALLOWED` en los nueve corredores. El sábado/domingo tampoco autoriza conclusiones sobre otras medidas. Debe existir test negativo contra **falso rojo** urbano Y test contra **falso verde** regional, ambos acotados al ámbito.

6. JSON candidato validador Laravel PASS solo si campos **obligatorios** (ámbito, fuentes, `verifiedAt`, `staleAfter`, `sourceCheckedAt`, IDs, unicidad, horario, fin temporal) tienen evidencia y formato real; si falta un campo legal sustancial, conservar candidato NO PUBLICABLE y pruebas negativas que demuestren fail-closed.

### B2. Ciudades NO editables en M1D

- **Medellín carro/moto:** H4 reportó `staleAfter=2026-11-10T05:00:00Z` = martes 10-Nov 00:00 COT. `now >= staleAfter` → stale/unknown; prueba corte exacto si se toca resolver; no extender `verifiedAt/staleAfter` por calendario ni página antigua. Rotación 2026-II actual corresponde lunes 5/8, martes 1/4, miércoles 0/2, jueves 3/6, viernes 7/9, 05–20, carro último y moto primero. No editar aquí.
- **Dosquebradas:** boletín oficial 26-Sep retorna el 28-Sep; dígitos L 0/1, Ma 2/3, Mi 4/5, J 6/7, V 8/9; carro último, moto primero; 06–20. `nextReviewAt` 01-Nov vencido en H4 y convertido a stale por parser. NO renovar TTL ni editar categorías en M1D: requerirá evidencia revisada, política y publicación Laravel aprobada.
- **Cartagena:** la Alcaldía publicó medida especial 24h para particulares del 11-Dic al 22-Ene (06→06 del día siguiente, excepto festivos) y la describe en todas las vías distritales; el H4 reporta IDs ligados a fuente/ámbito especial, cuya atribución debe reconciliarse antes de publicación. NO llamar a esa regla solamente «zonal» por el nombre del fixture. Comunicado de junio se refiere a otra temporada; moto centro amurallado y noche son medidas distintas. NO ajustar reglas en M1D ni activar por suposición. Fuente de referencia `https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026`.
- **Villavicencio:** Decreto 015/2026 mantiene polígono 2025 y regla 06:30–09:30/17–20, pero límites exactos/rutas sin validación. `stale` desde 23-Sep; no afirmar `ALLOWED` afuera del polígono ni editar.
- **Resto nacional:** 1.096 municipios M1B sin investigación y siete candidatas parciales; no declarar sin restricción, no modificar cola histórica en este lote.

## C. GATES OPERATIVOS (UNA SOLA PASADA POR ETAPA, NO PING-PONG)

### G0. Procedencia, entorno y privacidad (máximo una vez)

1. Trabajar **solo en D:**, aislado. Preferencia del propietario: `D:\codex\PicoRadar\` para área operativa y `D:\codex\_REPORTES\PicoRadar\` para informe. No dar por existente una ruta exacta: resolver una vez el source H4 verificado (`git cat-file -t <HEAD>`, `git rev-parse <HEAD>^{tree}`, `git status --porcelain=v1`); donde H4 exista, crear clon separado p. ej. `D:\codex\PicoRadar\_isolados\M1D_LARAVEL_20261107` si está libre. **Jamás** `git reset --hard`, `git clean`, `git restore`, `git stash`, `git checkout` sobre originales; nunca borrar/cambiar propietario de originales C:/D: ni iniciar red desde prod.
2. Leer las leyes/AGENTS/baselines una sola vez; registrar cuáles fueron realmente accesibles y hashes. Registrar `baseline_HEAD`, `tree`, rama y gitdir, diferencias, sparse path, remotes/alternates. No calcular 101 hashes WIP (fuera de alcance); preservación WIP por contenido=NOT_VERIFIED. Usar clon **sin remotes/alternates**; no usar links que dependan de C:.
3. Si H4 no está en disco, buscar solo en 1–2 rutas de reportes permitidas y Git objetos locales, sin repetir 15 G0; si ausente, `BLOCKED_BASE_H4_NOT_FOUND` y hacer comparación semántica Laravel remoto como informe, **ningún cambio de código**, entregar ZIP final (no inventar H4).
4. Ni la falta del ZIP M1C anterior ni la de los ZIP M1B/R21 detiene M1D. El ZIP anterior se usó como fuente histórica **ya auditada**, pero la evaluación actual exige volver a leer H4 en el clon, no "reutilizar" CODE PASS de reportes.

### G1. Mapeo de flujo real existente, con evidencia estática y archivo→método→efecto

1. Inspeccionar con nombres exactos el código H4 de `RestrictionPublicationService`, `DatasetPublisher`, `RestrictionPayloadEncoder`, `RestrictionContractValidator`, `DatasetReleaseValidator`, modelos `RestrictionRuleVersion`, `Dataset`, `DatasetRelease`, `DatasetSource`, y administradores/importers/commands relacionados. Si el sparse omite `scripts/`, usar `git ls-tree -r --name-only HEAD` + `git show HEAD:<ruta>` antes de NOT_FOUND, solo una exploración general.
2. Entregar matriz **INPUT → VALIDATE → ENCODE → DRAFT → PUBLISH(IN TEST ISOLATED ONLY) → MANIFEST → FLUTTER CONSUMER**, indicando método, ruta, hash blob y mecanismo real. Distinguir si API Laravel ya provee descarga y si el Flutter disponible en H4 solo lee JSON empaquetado; NO afirmar un puente que no esté en código.
3. Verificar si ruta local B07 ya permite construir un asset **candidato** de Bogotá sin publicar ni tocar el dataset estático. Si SÍ, ir G3; no programar por estética. Si NO, identificar **un único** borde faltante y seguir G2.

### G2. Adaptador mínimo dentro de Laravel, SOLO SI IMPRESCINDIBLE

**Autorización directiva condicionada (última alternativa):** primero intentar **solo test/harness** del Laravel existente sin añadir una ruta de producción. Únicamente si el flujo completo demuestra una carencia material que impide generar/exportar un candidato temporal con el contrato actual, se puede agregar UN comando/adapter de **solo candidatura/exportación de prueba** dentro del proyecto Laravel existente que reutilice validador+encoder+servicios actuales, produzca JSON canónico *fuera de rutas productivas*, con SHA-256 y metadatos de procedencia. Deberá fallar ante versiones no validadas/corruptas, no llamar métodos que publiquen en prod, no activar flags, no crear nuevo contrato maestro ni una segunda base de datos. Si la cadena existente ya genera candidato, **prohibido crear adapter redundante**. La solución puede incluir una prueba/harness de Laravel en vez de un comando si este es más simple.

- Máximo **un punto de integración** nuevo (más sus tests/fixtures focales); no introducir paquetes Composer, NPM, Python, tablas, migraciones, RabbitMQ/Redis workers, scrapers, endpoints públicos ni microservicios.
- Prohibido modificar directamente `mobile/assets/datasets/restrictions/restrictions_v1.json`; un candidato validado de `Storage::fake` o disco temporal NO es un release publicado ni una actualización de la app.
- Conserva el escritor Laravel como única fuente de aprobación/publicación; el adapter **solo exporta o prueba** el artifact existente en ámbito temporal, no duplica transacciones/manifiestos/versiones ni salta `validated`.
- No tocar cinco ciudades a la vez. **Una candidata Bogotá noviembre** sirve como prueba completa de la ruta, con el estado jurídico explícitamente `CANDIDATE_ONLY`; en la ausencia de fuente/perímetro requerido, producir un test que demuestre rechazo/UNKNOWN sin insistir en forzar el "verde".
- Si el contrato exige actor/admin o base de datos, usar SQLite local temporal/fixtures fakes. No emplear credenciales reales, producción ni Hostinger.

### G3. Pruebas RED/GREEN reales, solo el delta

1. Prueba RED reproducible por el puente ausente o por una divergencia real; de no haber defecto, no fabricar RED: registrar `NO_CODE_NEEDED` y correr regresiones focales comparativas reales si entorno lo permite.
2. Laravel PHP tests focales: dato válido → candidate serialization/hash, inválido → rechazo; selección por una jurisdicción sin sustituir otras; idempotencia en mismas entradas, `sourceCheckedAt/verifiedAt/staleAfter` semánticamente separados; ingreso de 02/16-Nov regional NO fusionado. SQLite temporal, `Storage::fake`, sin prod.
3. Flutter/motor: solo tests acotados de lectura del artifact candidato si ya hay harness existente, sin tocar otros módulos ni correr suite gigante; cotejar la paridad de Bogotá, límites horarios y cambio de mes. Si no se puede invocar Flutter sin reestructurar, marcar `NOT_RUN` con causa: no declarar PASS falso.
4. Ejecutar formato y `git diff --check` solo archivos modificados; static checks PHP/Flutter afectados; manifest/version SHA. **Registrar por separado** (a) `phpunit` Laravel efectivamente ejecutado, (b) tests de parser/motor Flutter efectivamente ejecutados, (c) contrato remoto de sincronización NO probado cuando falte, (d) cobertura jurídica por revisar. No llamarlos PASS en bloque por un `phpunit` verde. Incluir **comandos completos, exit codes, totales, stdout/stderr recortado con contexto y hash de fixtures**. Se prohíbe usar "PASS" de logs de otras ramas o de R21.
5. No abrir CI, Actions, dispositivo, Mi A3, ADB, JNI, Gradle, AOT, navegador Hostinger, ni llamadas al backend productivo. No publicar datasets en ninguna infraestructura.

### G4. Autoverificación y antirregresión

- Comparar `git diff --name-status`, `git diff --check`, `git status --porcelain`, SHA JSON bundle y catálogo **antes/después**. La variante permitida cambia **solo** Laravel código de integración y tests focales, con fixtures en `server/tests/` si existen convenciones; nunca `docs/` baseline, leyes, assets móviles ni datos de usuario.
- Garantizar que un candidato rechazado por faltantes no se publicará. Candidato válido local no equivale a `ALLOWED`; `unknown/stale` conserva jerarquía en app. No afirmar cobertura nacional, Android QA ni fuente legal exhaustiva.
- Si sin cambios, resultado `M1D_NO_CODE_NEEDED` requiere demostrar flujo funcional REAL y tests; informe solo estático es `M1D_PARTIAL`/`BLOCKED`, nunca PASS completo.
- Cero cambios remotos; PR79 permanece solo documental, PR71/main intactos. Puedes hacer **máximo 1 commit LOCAL** en rama aislada SOLO si existe diff funcional mínimo que pasó sus gates y el commit no afecta originales; no push, PR ni merge. Si no hay diff no commitear por formalidad.
- **Diez controles de auditoría** en `AUDIT_10_M1D.csv`: 1 procedencia, 2 normas, 3 publisher, 4 fuente Bogotá, 5 validador, 6 empaquetado SHA, 7 tests, 8 preservación, 9 fail-closed, 10 next actor. No ejecutar diez suites.

### G5. ENTREGABLE ÚNICO, NO 19 ARCHIVOS SUELTOS

Entregar **exactamente un ZIP** final descargable con los elementos siguientes dentro del ZIP:

1. `FINAL_REPORT.md` con hechos, SHA H4, git tree, actual SHA de código, `TASK_ID`, `RESULT`, comparación antes/después, limitaciones, siguiente actor `CHATGPT`, `RELEASE=NOT_APPROVED` y **la decisión sobre el puente**: `REUSE_EXISTING` o `MINIMAL_LARAVEL_ADAPTER` o `BLOCKED_CONTRACT`.
2. `PUBLISHER_SOURCE_TO_FLUTTER_MAP.csv` con fuente/etapa/path/método/asset/output/sha/gap demostrado, no conclusiones vagas.
3. `BOGOTA_NOV_2026_CANDIDATE_AND_GATES.csv` con fechas/dígitos permitidos vs restringidos/horas/ámbito/festivos/validUntil, naturaleza de fixture vs fuente oficial capturada; `PUBLISH_ALLOWED=NO` hasta revisión humana.
4. `FOCAL_TEST_RESULTS.csv` con comandos, status `PASS/FAIL/NOT_RUN`, counts y reason. Si no ejecutó, escribir `NOT_RUN`, NO PASS.
5. `AUDIT_10_M1D.csv` diez controles con evidencia real y límites.
6. `PATCH_CANDIDATE.diff` **solo si hay cambios**; en caso contrario `NO_DIFF_REASON.md` que explique de dónde sale el asset candidato.
7. `ARTIFACT_CANDIDATE/` opcional con **un** JSON candidato **no publicado** y SHA cuando legal y técnicamente válido; si falta ámbito o campos obligatorios, **no incluir pseudo-JSON publicado** y entregar `CANDIDATE_REJECTED_REASON.md`.
8. `TREE_AND_ASSET_SHA256.txt` con SHA original/clone HEAD/tree, runtime/catalog sha antes/después, lista de paths realmente tocados, WIP `NOT_VERIFIED`, no secretos, no datos privados.
9. `MANIFEST.json` con tamaño, SHA256 y CRC32 de cada archivo incluido; `MANIFEST.sha256`; hash externo ZIP calculado **después de crear** el ZIP, con `ZipFile.testzip` y comparación manifiesto. No incluir archivos `.env`, claves, PII ni bases reales.

Enviar en el chat de Codex **solo** estado resumido, ruta física válida, nombre exacto del ZIP, SHA-256 final y `NEXT_ACTOR=CHATGPT`; adjuntar el ZIP al usuario para que él lo comparta con ChatGPT. **Ningún archivo regado**, ni enlaces `D:/` sin binario.

### G6. Presupuesto estricto y control de alcance (obligatorio)

- **Una** inspección de procedencia H4; no repetir R21/M1C/M1B ni recapturar masivamente fuentes. Una matriz de métodos sobre **un** flujo de publicación y **un** candidato Bogotá.
- **Una** propuesta de causa raíz si la prueba focal no funciona; solo un punto de integración Laravel permitido, nunca adaptar Flutter+Laravel+scraper simultáneamente.
- Primer camino siempre **reutilizar** implementación y tests Laravel. Si la ruta actual no tiene consumo Flutter, reportarlo como `FLUTTER_SYNC_GAP` para M3; **no construir sync móvil en este lote**.
- Los `Storage::fake`, in-memory/SQLite y el manifiesto local de test pueden contener `published` como estado interno del fixture, pero eso **nunca es publicación real**: documentar carpeta temporal/actor fake, ausencia de endpoint productivo y prueba explícita de aislamiento.
- Fuente legal oficial consultada no autoriza inventar fechas de `sourceCheckedAt`, exenciones, perímetros, fechas de revisión o TTL. `UNKNOWN` cuando falten datos. No extender vigencia de Medellín en este lote.
- Si H4 inaccesible, entorno sin dependencias o contrato superior bloquea, **cerrar PARTIAL con causa/archivo/test NOT_RUN dentro del mismo ZIP**, no pedir otra orden de preflight.

## D. DECISIONES CERRADAS / ALTERNATIVAS SIN VUELTAS

| Si ocurre... | Entonces ejecuta... | NO hagas... |
|---|---|---|
| Flutter ya consume asset publicado de Laravel con manifest real y tests | `REUSE_EXISTING`, probar candidato Bogotá en entorno temporal y reportar `M1D_NO_CODE_NEEDED` si PASS | Crear puente nuevo por inercia. |
| Laravel produce asset pero Flutter solo consume bundle estático | Demostrar ambos contratos; solo si falta vía de candidato local introducir **mínimo adaptador Laravel** con pruebas; NO activar sync ni producción | Crear segundo publicador/editar JSON directo. |
| Un campo legal/territorial obligatorio no está corroborado | `BLOCKED_SCOPE`, conservar `UNKNOWN` y entregar test negativo local | Inventar polígono, excepciones o `ALLOWED`. |
| No existe HEAD H4 accesible/verificable | `BLOCKED_BASE_H4_NOT_FOUND`, archivo ZIP con prueba y decisión puntual; no escribir código | Reclonar `main` antiguo o tocar originales. |
| No hay infraestructura Laravel de tests instalable sin red/credenciales | Intentar máximo configuración efímera offline usando dependencias locales existentes; si falta algo, `BLOCKED_TEST_RUNTIME` exacto, diffs nunca se llaman PASS | Instalar global, desplegar o pedir otro preflight general. |
| Se descubre cambio a normas de producto/arquitectura superior | **STOP solo ese cambio**, adjuntar evidencia/alternativa KISS en ZIP para director | Cambiar baseline por cuenta propia. |
| No hay delta necesario | Entrega `M1D_NO_CODE_NEEDED` con pruebas del flujo existente, sin commit | Fabricar cambios para parecer productivo. |

## E. ORDEN DE CIERRE Y SIGUIENTE HITO

M1D es **prueba funcional y candidato local**, no release de Bogotá. Después ChatGPT auditará ZIP final y decidirá si procede M1 expansión municipal y M2 agente lector o el puente Flutter M3 cuando corresponda. Conserva M0–M4 existente, PR79 Draft, PR71/main sin cambios, 101 WIP protegidos, `RELEASE=NOT_APPROVED`.

**FIN DE PROMPT PARA CODEX LUNA.** `NEXT_ACTOR_AFTER_EXECUTION=CHATGPT`. La ejecución **no** autoriza GitHub, producción ni una fase M1E sin revisión del director.