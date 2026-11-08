# PICORADAR — AUDITORÍA DIRECTIVA M1D ANTES DE EJECUCIÓN · 10 PASADAS Y PLAN DE CIERRE

**Corte del análisis:** 2026-11-07 (America/Bogota). **Autor:** ChatGPT, director técnico. **Objeto:** reauditar orden **M1D**, no reabrir M1C; conservar plan M0–M4, AGENTS, baselines, seis leyes y PR documental. **Estado:** `M1C=PARTIAL_DIAGNOSTIC_CLOSED`, `M1D=ORDER_READY_NOT_EXECUTION_VERIFIED`, `RELEASE=NOT_APPROVED`.

## 1. Evidencia reproducida y límites

- **ZIP M1C en este chat:** `PICORADAR_M1C_RESULTADO_EVIDENCIAS_UNICAS_20261107.zip`; 10,968 bytes, SHA-256 `f04521c240b4315fa036c797eb6c8abb70bd4ee79f60add88eb17eccaaa2e3dd`. Integridad CRC `PASS`, `MANIFEST.sha256` `PASS`. La matriz tiene **8 filas con claves municipio/categoría únicas**: 3 `ALREADY_MATCHES` solo núcleo, 3 `BLOCKED_RUNTIME_WRITER_NOT_FOUND`, 2 `BLOCKED_SCOPE_OR_SOURCE`. Tests en M1C `NOT_RUN` y el contenido Git H4 no viene dentro del ZIP.
- **GitHub verificado en la revisión:** PR79 `OPEN/DRAFT`, base `recovery/20261019-modern`, HEAD anterior a este checkpoint `a25d829d6d5860e8c073cabf8f0e9b557ac8c49b`, nueve archivos exclusivamente `docs/`; PR71 `OPEN/DRAFT`, HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`. `AGENTS.md` blob `39091e67ff6ecaf4da880ed8c2be0ac1f5273fbf`; Plan Maestro blob previo `5ad045bf03e0668ac82736fc7d0aeb107d5b8e57`; contrato agente blob `8e5e0eb631ce4d6585c1f261b49e15e75be72ed0`.
- **Publicador ya existente en GitHub (no prueba de H4):** `server/app/Services/RestrictionPublicationService.php` blob `1fb78bd792871345f2a1e813f5bcf0246888f859`; `RestrictionPayloadEncoder.php` `bc929abc471261b4758607712471c16f933672c2`; `DatasetPublisher.php` `3ba83febca01bab546b1e6260b720288ae4671f2`. El servicio fusiona versiones validadas, escribe un **draft Laravel** y pasa a un publicador de assets versionados/manifiesto. **No es escritor acreditado** del archivo empaquetado `mobile/assets/datasets/restrictions/restrictions_v1.json`. No inventar puente Flutter, sincronización o autoactualización.
- **Fuente jurídica oficial cotejada:** Bogotá 2026-11-01, `https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-bogota-vehiculos-particulares-1-30-de-noviembre-de-2026`: lunes-viernes 06–21, días impares *pueden circular* 1–5 (restringidos 6–0), pares *pueden circular* 6–0 (restringidos 1–5); 02/16-Nov se trata por regla regional de ingreso separada, **no** pico ordinario de una jornada urbana. Cartagena 24h fin de año en Distrito según `https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026`; no editar Cartagena en M1D. Medellín II-2026 según `https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre/`; calendario técnico H4 caduca 2026-11-10 00:00 COT **según ZIP M1C**, distinto de vigencia jurídica.

**Separación L5:** paquetes y contenido documental revisados por ChatGPT ≠ reproducción de ejecución local H4. `CI`, `QA físico`, `101 WIP por hashes`, `sourceCheckedAt` web de Codex y casos de integración Flutter siguen NO VERIFICADOS hasta nueva evidencia.

## 2. Diez pasadas obligatorias y resultado de cada una

| # | Control forense | Evidencia concreta | Dictamen y corrección |
|---|---|---|---|
| 1 | Entrada binaria | ZIP original real, CRC y SHA MANIFEST; 8 entradas únicas | **PASS integridad**. No exigir ZIP M1B/R21 de nuevo. |
| 2 | Estado de M1C | 3/3/2 y tests NOT_RUN en CSV; `WIP=NOT_VERIFIED` | **PASS documental / NO CODE PASS**. Cerrado `PARTIAL`, sin repetir. |
| 3 | Procedencia H4 | H4/tree/SHAs informados en M1C; no hay bytes fuente de H4 dentro del ZIP | **PARCIAL**. Codex comprobará una vez HEAD/tree contra clon; ni código ni WIP certificado por ChatGPT. |
| 4 | GitHub y autorización | PR79 Draft docs; PR71 Draft anterior; contrato/AGENTS | **PASS gobierno**. No push/merge/CI, PR71/main intactos. |
| 5 | Seis leyes y UX | PingPongLaw L1–L6; AGENTS, CURRENT, SOP y contrato; baseline DOCX local no leída por ChatGPT | **PASS de cumplimiento documental limitado**. Codex debe leer DOCX accesibles antes de alterar comportamiento; mantener KISS/Ponytail, no nueva arquitectura. |
| 6 | Causa raíz writer | Laravel publicador y encoder reales en PR71, no reproducidos en H4; JSON empaquetado sin writer probado | **CORREGIDO**. No second writer, no Python; primero prueba/harness Laravel existente. |
| 7 | Bogotá y festivos | Portal Bogotá define permitidos por paridad y 02/16-Nov solo regional de ingreso | **MEJORA MATERIAL**. Prompt V2 exige tests de falso rojo urbano + falso verde regional, y 01-Dic UNKNOWN. |
| 8 | Ámbitos, TTL y fuente | Medellín stale próximo; Dosquebradas nextReviewAt vencido; Cartagena especial distrital futura; Villavicencio polígono incompleto | **PARCIAL CONTROLADO**. Prohibida renovación TTL manual; no `ALLOWED` cuando dato no cubre ámbito. Cartagena no se toca en M1D. |
| 9 | Prompt M1D y pruebas | V1 autorizaba adaptador sujeto a condiciones, pero no exigía aislar tan explícitamente publishVersions + festivos | **MEJORADO V2**. Un único test/harness primero, adaptador solo última opción; SQLite/fakes, test exit+evidencia. Misma tarea M1D. |
| 10 | Antipingpong y recuperación | Contrato agente GitHub aún termina remitiendo a M1B como orden activa | **DEUDA DOCUMENTAL DETECTADA**. Actualizar solo puntero de continuidad; registrar M1D V2 canónico en PR79. Si Codex ya inició M1D G0, no reiniciar. Un ZIP resultado. |

## 3. Decisiones ya cerradas: no renegociar normas

1. Flutter local-first (Riverpod/go_router/Drift), Laravel backend y autoridad única de publicación, agente futuro **solo lectura/propuestas**, no account obligatoria ni tracking GPS continuo. No hay segundo repositorio runtime, microservicios, scraper o generador de JSON paralelo.
2. No cambiar `AGENTS.md`, baselines DOCX, seis leyes, DESIGN_CONTRACT, SOP, modelo jurídico, `main`, PR71, Android/Hostinger, claves ni datos del usuario. **PR79 solo documentación.**
3. M1D prueba **candidato** Bogotá noviembre en almacenamiento **efímero** con actor de prueba, SQLite/`Storage::fake` y SHA reproducible. Probar los límites 06:00/21:00, 03/04/30-Nov, 01-Dic unknown y 02/16-Nov festivos separados. El hecho de que un actor simulado publique dentro de una base fake no equivale a publicación real.
4. Si ya existe la ruta, **NO CODE NEEDED** con tests ejecutados. Si hay un borde demostrado, un único adaptador/harness en Laravel sin product deployment; cualquier supuesto consumo de Flutter no acreditado se reporta `FLUTTER_SYNC_GAP` para M3. Si no existe H4 o entorno de tests, entregar ZIP con bloqueo causal y NOT_RUN, sin nueva orden de preflight.
5. **Regla contra pingpong:** M1D sigue con idéntico TASK_ID. La versión V2 solo se usa **si M1D todavía no inició**. Si comenzó con G0 PASS, no interrumpir; auditar luego el ZIP V1. No abrir M1D V3 o M1E sin evidencia de resultado real.

## 4. Plan de finalización preciso, bajo el Plan Maestro existente

| Macro | Orden y dependencia | Salida verificable / aceptación | Bloqueos honestos |
|---|---|---|---|
| **M1D inmediato** | Codex lee orden M1D V2 y H4, prueba validación/asset Laravel con candidato Bogotá, sin prod | 1 ZIP: SHA+CRC+manifest, flujo por métodos/paths, pruebas efectivas o `NOT_RUN`, un patch local solo si imprescindible, y decisión de puente | Sin H4/SQLite/deps o jurídicamente incompleto → PARTIAL acotado, no otro preflight |
| **M1 fuentes nacionales** | Reusar 1104 DIVIPOLA/93 URL iniciales; investigar por autoridad/departamento, no 1104 consultas repetidas | Descubrimiento por municipio/autoridad **con denominador** y fuentes capturadas; entradas NO_SEARCHED ≠ NO_MEASURE; 7 casos parciales priorizados | Autoridades con fuentes no disponibles quedan UNKNOWN con cola de revisión, no falsas reglas |
| **M2 motor y agente** | Basado en M1 y Laravel existente; fuente → verificación oficial → propuesta → revisión | Casos para tipos legales, reglas territoriales/festivos/vigencia, deduplicación y lectura del agente **sin publicación automática** | No crear motor por ciudad ni nuevo backend; publicar solo candidate FULL apropiado |
| **M3 integración** | Laravel dataset versionado/manifest → Flutter verificación hash/rollback; cámaras ANSV; cuentas opt-in según baseline | En entorno temporal prueba de descarga/validación/activación atómica/offline/rollback sin pérdida de Garaje; pipeline cámaras con operación/velocidad no inventadas | Sin pruebas móvil/API, status no listo; alcance cuentas depende de baseline |
| **M4 cierre release** | Tras aceptación M1–M3: Git/CI real → QA Android JNI/firma/Mi A3 (autorizado) → seguridad/store/GO humano | CI concluida en SHA, 101 WIP auditadas con permiso, persistencia vehículos, QA físico, AAB/APK firma, release aprobado por propietario | CI fallida/logs ausentes, firma, datos o QA física faltantes impiden declarar FINAL |

**Prioridad de seguridad:** la caducidad H4 Medellín del **10-Nov-2026 00:00 COT** es una advertencia operativa próxima. Antes del corte, *no* renovar fechas en JSON manualmente; tras el corte, seguir `UNKNOWN/STALE` hasta revisión formal mediante writer aprobado. El plan no convierte silencio administrativo en permiso de circular.

## 5. Continuidad GitHub, versión y actor

- Base de la orden M1D: PR #79 documental Draft, `docs/plans/PICORADAR_PLAN_MAESTRO_V2_NACIONAL_20261107.md` sección Q, ledger `SRC-23/24`; PR71 código sin cambios. Esta revisión **no autoriza push/merge de código ni producción**.
- **Prompt canon propuesto:** `docs/plans/CODEX_LUNA_PICORADAR_M1D_V2_ORDEN_20261107.md` (mismo TASK_ID). Prompt descargable en ChatGPT: `CODEX_LUNA_PICORADAR_M1D_V2_ORDEN_UNICA_AUDITADA_20261107.md`.
- **Siguiente actor:** `CODEX LUNA` si no ha ejecutado M1D; si M1D ya empezó, **Codex continúa con la orden previa sin reiniciar**. Después, `CHATGPT` audita único ZIP.
- `RELEASE=NOT_APPROVED` hasta M4 y GO humano.

**Esta es revisión adversarial interna del director, con evidencia independiente de integridad, código remoto y portales oficiales; NO es certificación de tests ejecutados.**