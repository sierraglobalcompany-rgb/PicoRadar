# PICORADAR — RECOVERY HANDOFF AUTÓNOMO V6 — 2026-11-09

> **MODO=EXPORTAR · PROYECTO=PicoRadar · ESTADO=COMPLETO COMO RECUPERACIÓN DOCUMENTAL · RELEASE=NOT_APPROVED.**
>
> Este archivo es un **handoff de continuidad**, no autoriza editar código, publicar datasets, ejecutar migraciones, modificar el equipo de Codex ni hacer merge. En un chat nuevo, ejecutar Recovery V6 en modo **REANUDAR**, verificar solo cambios posteriores y pasar al NEXT. **Última entrega Codex M3-X01 está CERRADA, no en curso.**

## A. RESUMEN INMEDIATO / SEED PRIMERA PANTALLA

| Campo | Estado preciso |
|---|---|
| Fecha | 2026-11-09, Colombia (COT, UTC−5); hora exacta del documento no auditada |
| Proyecto | **PicoRadar**, aplicación **Flutter Android local-first + backend Laravel monolítico**, para consulta de restricciones de **pico y placa en Colombia**, por municipio/autoridad, tipo de vehículo, placa, vigencia y ámbito; cámaras son un módulo histórico separado y **NO** el objetivo de este relevo |
| Meta del usuario | **Pico y placa nacional verificable**, particular, moto, taxi y regímenes adicionales solo si están oficialmente acreditados; cero falsos «puede circular» |
| Último hito | **M3-X01 puente Laravel → manifiesto → Flutter/Drift PASÓ en QA focal sintética schema 1**: dos publicaciones revisiones 2→3, bytes idénticos verificables, negativa de v2 alterada preserva v1 según test Flutter documentado |
| Resultado | `M3_X01_BRIDGE_PASS_SCOPED`, **NO** `M3_DONE`, **NO** `RELEASE_READY`, **NO** normas reales probadas |
| Archivo de evidencia esencial | `evidence/PICORADAR_M3_X01_CONTRATO_LARAVEL_FLUTTER_EVIDENCIA_UNICA_20261109.zip`, original del usuario/Codex incluido en este pack; tamaño **41,321 bytes**; SHA-256 `87c30be0c7678162c2d57583d23b9b96c906bb33dcdb9427d6d5be09dd9a675c` |
| GitHub, fuente canónica | `sierraglobalcompany-rgb/PicoRadar` · PR documental **#79**, rama `docs/plan-maestro-nacional-v2-20261107`, último **checkpoint documental contrastado** `b57b2a93f9a397632088ef8d0d0c5bf23049f3ca` (podría avanzar por publicación de este Handoff: reconsultar) |
| Código remoto | PR código **#71** OPEN/DRAFT contra `main`, SHA `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, sin cambios observados por esta auditoría. **No está fusionado** |
| PC/checkout local | Codex reportó branch `recovery/20261019-modern`, HEAD `0d3a6a2...`, tree `04a01f15...`, status PRE/POST con borrado histórico protegido `scripts/tests/test_hostinger_installer_browser.ps1`; **independencia del WIP local NOT_VERIFIED** |
| WIP protegido | **101 rutas WIP NO enumeradas, ni leídas, ni hasheadas**. No inferir limpieza, ni restaurar el borrado histórico |
| Código nuevo | **No integrado**. Parche candidato M3-X01 toca **solo DOS tests** (PHP y Dart), `PATCH_CANDIDATE.diff`, SHA-256 `2e0ce26641f125afdf45b3c3cd4bf8714828a2fa98b0a3a717af9030235a8d3d`; presente en el ZIP de evidencia. No aplicar automáticamente |
| Bloqueo de producto | **Cobertura legal nacional incompleta**. Las cinco filas jurídicas focales siguen **0/5 READY**, no autorizar publicación. M3 sintético NO resuelve eso |
| Trabajo Codex activo | **NINGUNO CONFIRMADO**; M3-X01 terminó según ZIP; no lanzar otro prompt porque sí |
| **NEXT ÚNICO** | **CHATGPT DIRECTOR (nuevo chat)**: auditar el delta nacional M1 ya disponible en `docs/data/external-research/`, seleccionar una tanda acotada por **autoridad + clase + ámbito**, resolver primero contradicciones críticas con fuentes primarias y diseñar admisión de reglas al compilador existente, SIN publicar ni delegar hasta tener criterio completo |
| Cierre de NEXT | Tabla de candidatos por `(DIVIPOLA, autoridad, vehículo, régimen/ámbito, vigencia)` con fuente oficial, evidencia por campo, `SUPPORTED/DATA_ONLY/ENGINE_GAP`, conflictos y `READY_FOR_HUMAN_REVIEW` solo cuando proceda; una siguiente orden a Codex solo si queda trabajo local real coherente |
| PROHIBICIONES | No reejecutar M3-X01, G0R ni captura M1; no reabrir D01/C1; no modificar `main`, PR #71, JSON activos, WIP, app instalada, ADB, firma ni producción; no crear otro backend, DB, motor o agente de publicación |

**Frase de estado:** estamos construyendo consulta nacional fiable de pico y placa. **El transporte de bytes Laravel→Flutter se demostró en dos versiones sintéticas (schema 1); falta certificar restricciones oficiales, admitir el parche test-only bajo control, integrar C1/schema2 y completar QA físico/release. La siguiente decisión corresponde a ChatGPT, no a Codex.**

## B. IDENTIDAD, CANON Y FUENTES CONFIABLES

| Fuente | Identificador/URI real | Valor que demuestra | Estado de acceso y confianza |
|---|---|---|---|
| Repositorio GitHub | https://github.com/sierraglobalcompany-rgb/PicoRadar | Fuente remota de código/docs; **NO** el WIP del PC | VERIFICADO_DIRECTO en este chat, 2026-11-09 |
| PR #79 | https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/79 | Plan Maestro, registro de errores, documento externo en cuarentena;  **Draft docs-only** | VERIFICADO_DIRECTO; checkpoint `b57b2a...` |
| Plan Maestro V2 | `docs/plans/PICORADAR_PLAN_MAESTRO_V2_NACIONAL_20261107.md` en la rama documental | Línea M1→M4; §§AD (enfoque nacional), AE (documento externo), AF (M3-X01 cerrado) | VERIFICADO_DIRECTO, no fusionado a branch code |
| Contrato de agente | `docs/agents/PICORADAR_SOURCE_AGENT_OPERATING_CONTRACT_V1.md` | Codex ejecutor; Laravel publicador único; **puntero NEXT actualizado a ChatGPT** | VERIFICADO_DIRECTO, rama PR #79 |
| Ledger de fallos | `docs/agents/PICORADAR_AGENT_ERRORS_DECISIONS_LEDGER_20261107.md` | SRC-33…SRC-42; errores y antipingpong | VERIFICADO_DIRECTO, rama PR #79 |
| Código en revisión | https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/71 | Rama de producto/pruebas existentes contra main, **no integrar sin gates** | VERIFICADO_DIRECTO, SHA `0d3a6a2...` |
| Leyes L1–L6 | https://github.com/sierraglobalcompany-rgb/PingPongLaw/blob/84e961cadf482d234f4c0ee2ca60e8c7e9b388e8/docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md | KISS+Ponytail, antirruido, antiparches, diseño humano, evidencia independiente, antipingpong | CANON_READ=PASS, SHA blob `0f6e7b4e62d8660c846f135e18dded629d29e0da` |
| AGENTS del producto | `AGENTS.md`, branch `recovery/20261019-modern` | Precedencia de contratos y gates operativos | Inspeccionado en este chat, no sustituir por recovery |
| ZIP Codex M3-X01 | Incluido en `evidence/` de este paquete | Logs de pruebas, archivos Laravel exactos, diff de dos tests, manifests y proveniencia | Contenido inspeccionado; SHA/CRC validados directamente; logs de ejecución son **REPORTADOS** |
| Investigación externa | `docs/data/external-research/` en PR #79 | Archivo original 55.714 caracteres, CSV **65 filas**, CSV **31 medidas**, contrastes | VERIFICADO_DIRECTO como STAGING, **NO** normas aprobadas |
| Recovery V6 | `Recovery(4).md` adjunto por el usuario | Plantilla y diez controles; modo EXPORTAR usado aquí | Leído directamente, 359 líneas |

`RECOVERY_SEED`: este mismo chat y entrega de Codex de 2026-11-09. `RECOVERY_GAP`: se revisaron GitHub PR79, PR71 y ZIP posterior al checkpoint AE; **cerrado respecto de ese ZIP y cambios remotos visibles**, no garantiza estado de PC ni cambios privados posteriores. `CHATGPT_PROJECT`: acceso a conversaciones anteriores no garantizado; los hechos críticos están en este archivo y referencias.

## C. DECISIONES APROBADAS, LÍMITES Y ARQUITECTURA

**Roles:** ChatGPT = director técnico, arquitecto, investigador, responsable de definir criterios de datos y auditar. Codex Luna = ejecutor de último recurso con instrucciones completas y verificables; **una entrega ZIP única por tarea**, no decide arquitectura ni autoriza releases. Usuario da autorizaciones finales de merge/deploy y alteraciones sensibles. No confundir orden anterior de Codex con tarea activa actual.

**Leyes:** L1 KISS/Ponytail: no reconstruir motor, BD, API o stack; L2 antirruido: reutilizar fuentes y pruebas; L3 antiparches: resolver causas, no encadenar variantes; L4 conservar diseño/funciones ya aprobados; L5 probar cada afirmación sobre SHA/fuente; L6 evitar nuevas rondas para lo ya hecho. **No hooks nuevos ni instalaciones globales por recovery.**

**Arquitectura comprometida:** aplicación Flutter local-first (Drift, sincronización y evaluación local), backend Laravel monolítico como **único publicador** de catálogo versionado/restricciones. Agente externo de fuentes **solo lector/proponente**; revisión humana antes de publicar. JSON/manifest reales protegidos; `UNKNOWN`, `STALE`, `CONFLICT` **no** significan «puede circular». `staleAfter` es TTL técnico, **no** vigencia legal ni `nextReviewAt`.

**Alcance:** particular, motocicleta, taxi y otros regímenes debidamente acreditados; municipio, autoridad, ámbito territorial/corredores, dígito primero/último, días, horarios (también nocturnos), festivos, excepciones, rotaciones y vigencia. **No** confundir cámaras/fotomultas (capacidad histórica del producto) con el foco actual de pico y placa.

**Baseline legal/UI:** preservar `AGENTS.md`, SPEC, flujos y entidades aprobadas. Nadie está autorizado a eliminar funcionalidades existentes ni rediseñar para superar una prueba. **No inventar `NO_RESTRICTION` sin prueba afirmativa de la autoridad**. Si la norma abarca corredores y el motor no tiene localización/geom, clasificar `ENGINE_GAP` en vez de asignar la regla a toda la ciudad.

## D. VERDAD IMPLEMENTADA Y PRUEBAS POR FASE

### D1. M3-X01 — CERRADO COMO PASS FOCAL SINTÉTICO, NO INTEGRADO

- TASK_ID exacto: `PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR`; prompt V2.1 histórico en `docs/plans/CODEX_LUNA_PICORADAR_M3_CONTRATO_REAL_LARAVEL_FLUTTER_20261109.md` de PR79; **NO volver a enviarlo**.
- Se recuperaron herramientas en un sandbox `D:\codex\_toolchains\PicoRadar-M3X01` según Codex: PHP 8.5.8 con `pdo_sqlite`, Flutter 3.47.9/Dart 3.13.7 oficiales; no extrapolar que están ahora disponibles en PATH global o el nuevo chat.
- PHP focal: **1 PASS / 28 aserciones** en `RestrictionPublicationService` con SQLite `:memory:` y Storage::fake; regresiones **9 PASS / 38** `DatasetPublisherTest` y **2 PASS / 8** `DatasetPublicContractTest`. Primer intento de DatasetPublisherTest: **8 PASS + 1 FAIL `MissingAppKeyException`**, luego corregido mediante `APP_KEY` sintético por proceso, **no** cambio del producto. Resultado final 12 pruebas PHP PASS/74 aserciones **REPORTADO con log**.
- Flutter focal: **1 test PASS** sobre dos releases Laravel exactos servidos por loopback HTTP y cargados por importer/Drift. La evaluación pasó de restringido a permitido; desconocido `UNKNOWN`, vencido `STALE`; al servir v2 corrupta en **otra base con v1 instalada** se produjo `DatasetSyncException`, download_count=1 y no `skippedCurrent`, v1/ETag/vehículo/coverage preservados. `flutter analyze --no-pub`, formato Dart, Pint y `php -l` PASS **REPORTADOS en logs**.
- **Verificación propia del ChatGPT:** archivo ZIP 41.321 bytes, SHA `87c30be0c7678162c2d57583d23b9b96c906bb33dcdb9427d6d5be09dd9a675c`, 28 CRC; 26 miembros con SHA+size coincidentes y `MANIFEST.sha256` correcto; 4 archivos de publicación exactos dentro del ZIP, versions `r2-ea11d15276f7` y `r3-288b1b2edb9b`, revisiones **2→3**, `schemaVersion=1`; SHA payload v1 `f5b56ab7ce0e688c905eb7507131ea5014f49582d78a17a41ee7dec0be7a6d0c`, v2 `0700c56436483709b543e87b113f47d51db94f28acb9e9b459f025d490147632`. **Ejecuté** `verify_synthetic_bridge.py` extraído en carpeta temporal y finalizó EXIT=0. Esta verificación independiente **no** reejecutó PHP/Flutter.
- Parche de dos tests: `mobile/test/core/sync/dataset_sync_hardening_test.dart` y `server/tests/Feature/RestrictionPublicationServiceTest.php`, SHA `2e0ce26641f125afdf45b3c3cd4bf8714828a2fa98b0a3a717af9030235a8d3d` dentro del ZIP, **no aplicado**. `git apply --check` existe en log de Codex; no ejecutado de nuevo sobre checkout remoto/local por ChatGPT. Preservar para admisión posterior controlada. **No** merge ni push de código.
- **Fuera de alcance**: producción CDN/TLS, suites completas PHP/Flutter, schema2/C1, QA dispositivo, Android JNI, inventario de 101 WIP, release.

### D2. M1 — OBJETIVO NACIONAL, PENDIENTE

- M1.3 recopiló universo territorial histórico MGN **1.122** unidades en matriz y 3.366 combinaciones `territorio×vehículo`, con 3.356 `NOT_SEARCHED` originalmente; el lote de 17 ciudades abrió 36 clases nuevas, dejando **3.320 NOT_SEARCHED** según esa conciliación. **No es número de municipios con restricción, ni un inventario legal nacional validado hoy.**
- Investigación histórica de 73 municipios (septiembre): **6 `verified`, 36 `conditional`, 2 `expired`, 29 `pending`, cinco `engineEnabled` históricos**; remoto moderno `restrictions_v1.json`: 7 jurisdicciones/12 coberturas, **12/12 `staleAfter` expirados al 9-nov-2026**. TTL vencido ≠ decreto derogado.
- M1.4 cinco filas núcleo (Medellín auto/moto, Bogotá auto, Cartagena auto/moto): **0/5 READY**, 5 PARTIAL. 33 afirmaciones y 12 fuentes únicas en su ZIP; fuente capturas M1 posteriores: nueve HTTP200 con cuerpos, dos 403 respetados, uno fuera de allowlist, 13/13 tests offline de capturador; no más rondas de capturas.
- Informe de IA externa del propietario 2026 v3.0 **en cuarentena**: 65 filas catálogo (agrupaciones territoriales), 31 filas medidas, 22 esquemas YAML. Errores ya detectados: Bogotá pares/impares INVERTIDOS en informe; Cartagena temporada especial potencialmente omitida; Soledad «día sin moto» antiguo retirado reportado, revisar acto; Quibdó calendarios en conflicto; reglas absolutas de sábados/festivos falsas; corredores departamentales/urbanos no intercambiables. **Ninguna regla externa activada.** Ver `docs/data/external-research/EXTERNAL_PICO_CONTRASTES_20261109.csv`, fuente original preservada y Plan Maestro §AE.
- **Siguiente trabajo real:** reconciliar por autoridad y régimen utilizando el delta ya organizado, seleccionar fuentes primarias con actos completos, notas de vigencia, ámbito y exenciones; marcar cada fila `SUPPORTED`, `DATA_ONLY` o `ENGINE_GAP`, y producir candidatas para aprobación humana **sin cambiar código** ni convertir `UNKNOWN` en `ALLOWED`.

### D3. M2 — MOTOR, COMPILADOR Y AGENTE (NO DONE)

- Motor Flutter, compilación Python y publicación Laravel existen; hay pruebas históricas de recorrido Python→HTTP→Drift y publicador/regresión de sincronización. Reutilizar, no crear otro compilador/motor.
- `RestrictionContext/Rule` del motor moderno no tienen coordenada/polígono/corredor de forma nativa; las restricciones zonales/regionales/nocturnas deben clasificarse antes de emitir un dictamen individual de circulación. No refactorizar de forma automática.
- El agente de fuentes propone cambios, pero NO publica. M2 requiere sus gates particulares; prueba M3-X01 no los suplanta.

### D4. M4 — CIERRE, APK Y QA FÍSICO (NO DONE)

- Candidato PHP C1/D01 local (`D01_CANDIDATE_PHP_PASS_ENV_BLOCKED`) preservado en entrega anterior, `C1 schema2` **NO INTEGRADO** con Flutter/CI. No reabrir D01 C2 por inercia.
- QA Android físico Xiaomi Mi A3: obstáculos históricos JNI/registrant/firma y conservación de registros; no afirmar que están cerrados por puente schema1. Revisar versiones y evidencias actuales antes de APK/ADB.
- Los 101 WIP son `NOT_VERIFIED`; hay un archivo de script Hostinger históricamente eliminado y protegido. Tests generales PHP/Flutter, CI, Android físico, JWT/seguridad, privacidad, firma, aprobación legal y GO de release **no completados** para este resultado. `RELEASE=NOT_APPROVED`.

## E. TABLA ÚNICA DE TAREAS Y ANTIPING-PONG

| Tarea | Estado | Evidencia y acción posterior |
|---|---|---|
| M1A/M1B M1.3 y lote 17 ciudades | PARTIAL histórico | Reutilizar CSV/docs, NO repetir DANE/RUNT o 17 ciudades por rutina |
| M1.4 cinco reglas críticas | PARTIAL 0/5 READY | Solo cierre jurídico por fuentes primarias y ámbito, nunca activación por informe IA |
| M1 capturador 12 URLs | DONE_SCOPED | Nueve capturas/13 tests offline; sin nuevo ciclo de red ni integración del capturador por hábito |
| M3-X01 G0R + puente Laravel/Flutter | **DONE_SCOPED** | ZIP adjunto con PASS sintético y test-only patch. **No reejecutar** |
| M3-X01 parche QA en product repo | PENDING_SAFE_ADMISSION | Dos tests no aplicados; revisar delta sobre SHA destino y WIP antes de admitir en PR; no bloquear M1 por esto |
| Informe externo nacional v3.0 | STAGING_ONLY | Ya presente en GitHub con 65+31 CSV; corregir evidencia de autoridades sin importar YAML directo |
| C1/schema2 y M4 QA Android | NO INTEGRADO / PENDIENTE | Gates separados, sin producción ni APK hasta evidencia real |
| `main`, PR71, PR79 | FROZEN para producción | PR79 docs Draft, PR71 código Draft, sin merge; nuevo chat comprueba SHAs antes de tocar |

**Evitar nuevos prompts sobre** `M1C→M1D→M1E→M1F→D01→C1`, M1.3 horizontal, M1.4 búsqueda genérica, M1 captura original, M3-X01 G0R/bridge. Las causas, artefactos y resultados están conservados. Un incidente nuevo con SHA distinto sí requiere análisis focal, no reabrir todo.

## F. EVIDENCE LEDGER: AFIRMACIONES QUE DECIDEN SIGUIENTE ACCIÓN

| ID | Afirmación | Clasificación | Evidencia | Límite |
|---|---|---|---|---|
| F01 | ZIP M3-X01 íntegro, 28/26 | `VERIFICADO_DIRECTO` | ZIP adjunto SHA `87c30be0c7678162c2d57583d23b9b96c906bb33dcdb9427d6d5be09dd9a675c`, hashes y CRC | No implica PASS de código por sí solo |
| F02 | Dos manifiestos + payloads con SHA consistentes, publicación revisión 2→3 | `VERIFICADO_DIRECTO` | `synthetic/` y ejecución del verificador Python | Solo fixtures sintéticas schema1 |
| F03 | Tests PHP 12/74 y Flutter 1 focal PASS | `REPORTADO_CON_LOGS` | `TEST_COMMANDS_AND_RAW_OUTPUT.log`, `PHP_G3_RAW.log`, `GATES.csv` | ChatGPT no corrió PHP/Flutter en PC Codex |
| F04 | Caso v2 corrupta conserva v1 + vehículo/ETag | `REPORTADO_CON_LOGS` | `CONTRACT_NEGATIVE_CASES.csv` + test Dart en `PATCH_CANDIDATE.diff` | No acredita rollback del backend ni CDN productiva |
| F05 | Checkout original conservado, solo borrado Hostinger anterior | `REPORTADO` | `GIT_AND_WIP_STATUS.txt` | PC no accesible, 101 WIP NOT_VERIFIED |
| F06 | Patch candidato modifica solo dos tests | `VERIFICADO_DIRECTO` | Análisis de encabezados diff y SHA `2e0ce26641f125afdf45b3c3cd4bf8714828a2fa98b0a3a717af9030235a8d3d` | `git apply --check` en repo real no reejecutado aquí |
| F07 | PR79 docs-only Draft, PR71 Draft sin cambio remoto | `VERIFICADO_DIRECTO` | GitHub consultado al exportar, refs arriba | No prueba `git status` local o CI |
| F08 | Normas nacionales completas y listas | `NO_VERIFICADO/NO` | M1 0/5 y staging con contradicciones | No certificar municipalidades sin medidas |
| F09 | Informe externo aprobado y aplicado al motor | `NO`; `STAGING_ONLY` | `docs/data/external-research/` | 65 filas no = 65 autoridades/reglas certificadas |
| F10 | Herramientas PHP/Flutter continúan instaladas en PC | `REPORTADO` | `ENV_RECOVERY_REPORT.md`, `TOOLCHAIN_PROVENANCE.csv` | No inspeccionadas por ChatGPT; no nuevo lote por ello |

## G. CONTINUIDAD EJECUTABLE — INSTRUCCIONES AL NUEVO CHAT

1. **Leer A–G de este Handoff primero**, después consultar solo archivos canónicos que decidan la próxima tarea: Plan Maestro V2 §§AD/AE/AF, Ledger SRC-40/41/42, contrato del agente y CSV `docs/data/external-research`. Si no se puede leer Github, este handoff conserva mínimos.
2. **Consultar una sola vez GitHub PR79/PR71/HEADs**, por posible nuevo commit documental; no suponer que el SHA de este checkpoint es inmutable. Recuperar solo `RECOVERY_GAP` posterior a 2026-11-09.
3. **Aceptar M3-X01 como DONE_SCOPED sin reejecutarlo.** Si alguien cuestiona, abrir su ZIP adjunto, comparar manifiestos SHA y logs. No volver a recuperar PHP/Flutter, ni enviar el V2.1 a Codex.
4. **Empezar NEXT de M1 nacional directamente en ChatGPT**: sintetizar matriz de fuentes oficiales ya presentes, contrastar contradicciones Bogotá/Cartagena/Soledad/Quibdó y determinar mínimo trabajo residual por autoridad y clase. Donde falte prueba declarar `UNKNOWN/CONFLICT` y `PUBLISH_ALLOWED=NO`. Investigar cambios oficiales actuales solo si ello cambia una propuesta.
5. Antes de cualquier encargo local, **el director decide**: `LO_HECHO_CHATGPT`, `LIMITE_REAL`, `OBJETIVO_CODEX`, `REQUISITOS`, `BASE`, `NO_TOCAR`, `QA`, `CRITERIO_CIERRE`. **Un solo lote residual ZIP** si hay trabajo local genuino. Si no, ChatGPT continúa documentalmente; no fabricar otro prompt.
6. **No reescribir producto ni tests en automático** por test-only candidate; documentar su futura admisión CI/revisión WIP. Proteger primero rama/product HEAD/usuario y WIP de 101 rutas.
7. **Leyes L1–L6**, prioridad legal, arquitectura KISS, publicación Laravel solo humana, Flutter offline, y bloqueo de release gobiernan en todos los pasos.

**NEXT:** `CHATGPT_DIRECTOR_RECONCILIAR_M1_NACIONAL_FUENTES_Y_REGLAS_SEGURAS`.

**ENCARGADO_NEXT:** **CHATGPT (nuevo chat)**.

**Criterio de salida del NEXT:** matriz oficial de candidatos para revisión de M1 que sea aplicable por municipio y clase sin extrapolaciones ni falsos `ALLOWED`, más plan por autoridades acotado y único trabajo residual del ejecutor si de verdad necesita PC. **No** publicar/activar sin revisión y autorización.

## H. ADJUNTOS DEL PAQUETE Y RECUPERACIÓN

| Archivo dentro del ZIP de continuidad | Propósito | Control |
|---|---|---|
| `PICORADAR_RECOVERY_HANDOFF_20261109.md` | Este documento, fuente primera de relevo | SHA en `MANIFEST.json` del ZIP externo |
| `evidence/PICORADAR_M3_X01_CONTRATO_LARAVEL_FLUTTER_EVIDENCIA_UNICA_20261109.zip` | Evidencia irrepetible que no se publicó a GitHub | 41.321 bytes; SHA `87c30be0c7678162c2d57583d23b9b96c906bb33dcdb9427d6d5be09dd9a675c` |
| `MANIFEST.json` y `MANIFEST.sha256` | Inventario autocontenido y doble verificación | Hashes calculados, CRC del ZIP exterior |

**No se embeben archivos del informe externo, Plan Maestro ni leyes**, porque están en GitHub y ya están referenciados. No se incorporan binarios de toolchain, cachés, credenciales ni datos privados de usuarios. `ZIP=NECESARIO` aquí: los archivos de pruebas originales y el parche QA **no están versionados** en GitHub.

### Diez controles de calidad Recovery V6 (revisados sobre este documento)

| ID | Resultado | Qué se verificó / límite |
|---|---|---|
| P01 Identidad | PASS | PicoRadar y pico y placa nacional, no cámaras; objetivo inequívoco |
| P02 Historia y GAP | PARTIAL | ZIP final y PRs contrastados; estado PC privado no accesible |
| P03 Verdad y recencia | PASS | ZIP real, SHA y datos sintéticos vs logs de ejecución reportados distinguidos |
| P04 Git / WIP | PASS de honestidad | SHA remoto separado de worktree; 101 WIP NOT_VERIFIED y borrado protegido |
| P05 L1/L2 | PASS | Un Handoff y fuente GitHub; no duplicación de histórico ni capas |
| P06 L3 | PASS | G0R y puente no se reabren; patch QA no se introduce sin gates |
| P07 L4 | PASS de continuidad | Arquitectura/UI aprobada se preserva; no rediseño ni pérdida de funciones |
| P08 L5 | PASS acotado | CRC, SHA, synthetic verifier directos; PHP/Flutter por logs; sin GO falso |
| P09 L6 | PASS | Codex finalizó; NEXT ChatGPT. No concurrencia ni nuevo prompt en exportación |
| P10 Simulación handoff | PASS documental | Nuevo chat puede ejecutar NEXT con esta semilla y rutas; no simula una reanudación real |

## I. ESTADO FINAL DE EXPORTACIÓN

```text
MODO=EXPORTAR
ESTADO=COMPLETO_DOCUMENTAL
PROYECTO=PicoRadar — pico y placa Colombia
FUENTES=ZIP Codex verificado, GitHub PR79/PR71, Plan Maestro V2, PingPongLaw, Recovery V6
RECOVERY_GAP=CERRADO respecto de ZIP recibido y Github consultado; PC local NOT_VERIFIED
WIP=101 NOT_VERIFIED; borrado Hostinger histórico protegido
QA=M3_X01_BRIDGE_PASS_SCOPED (PHP/Flutter según logs; Python byte-audit ejecutada aquí)
M1_NATIONAL=PARTIAL; M1_5_RULES_READY=0/5; EXTERNAL_STAGING=ONLY
CODEX_ACTIVE=NO, M3_X01_FINALIZADO
PUBLISH_ALLOWED=NO
RELEASE=NOT_APPROVED
NEXT=CHATGPT_DIRECTOR_RECONCILIAR_M1_NACIONAL_FUENTES_Y_REGLAS_SEGURAS
ENCARGADO_NEXT=CHATGPT
```

**Regla final:** Recovery V6 es relevo y preservación, no autorización de implementación. Cualquier avance posterior debe partir del SHA y la evidencia más nuevos, sin reabrir un lote cerrado para llenar tiempo o mejorar métricas superficiales.