# CODEX LUNA — PICORADAR · M1.3 CONTINUIDAD DE DESCUBRIMIENTO NACIONAL · LOTE ÚNICO · KISS + PONYTAIL

**TASK_ID:** `PICORADAR-M1-3-CONTINUIDAD-FUENTES-NACIONALES-20261108-DIRECTOR`  
**ACTOR QUE ORDENA:** ChatGPT, director técnico y auditor. **ACTOR QUE EJECUTA:** Codex Luna, exclusivamente operaciones descritas.  
**ESTADO DE ENTREGA DE PARTIDA:** C1 = `D01_CANDIDATE_PHP_PASS_ENV_BLOCKED`; NO es código integrado, NO es release, NO es permiso de circulación.  
**RELEASE=NOT_APPROVED · PUBLISH_ALLOWED=NO · CODE_PUSH_ALLOWED=NO · MERGE_ALLOWED=NO · NEXT_AFTER_ZIP=CHATGPT.**

## 0. POR QUÉ CAMBIA EL FOCO (NO ES OTRO PARCHE)

El Plan Maestro V2 ya aprobado como **hoja de ruta documental Draft** tiene una secuencia M0→M1→M2→M3→M4. Su tabla D establece que **M1.1–M1.3 pueden avanzar sin esperar Flutter/JNI o M4**. Hemos agotado demasiadas rondas M1C→M1D→M1E→M1F→D01→C1 en el validador de Bogotá. **SE TERMINA EL PING-PONG DE CALENDARIO.** No generar C2, D02, M1G ni volver a investigar la misma causa.

- C1 ZIP real SHA-256 `ae33efd1515214e9848806eb94d86ca133adc42e30eb2dee61972f8e38a1903e`, 13 miembros CRC PASS, once evidencias; PHP 36 pruebas/75 aserciones + 7 feature/32 aserciones PASS reportado y reproducido focalmente por director con `calendar_repro.php` (antes RED, después GREEN). `PATCH_CUMULATIVE.diff` SHA-256 `d7317989e1ba756d563ea4a0d685f9127218f2f5b7b9141a2c3d1fac9d2cc244`. Cambios locales no commiteados en cinco rutas, **NO** en GitHub. Flutter/Dart NOT_RUN. Integración de código y Flutter CI quedan en M4, no contaminan este lote M1.3.
- Dataset H4 contiene 10 jurisdicciones y 19 coberturas; **9/10 contratos validan y Bogotá moto falla por `staleAfter` anterior a `sourceCheckedAt`**. Eso no autoriza reparar JSON a mano ni extender TTL por próximo `nextReviewAt`. Medellín `staleAfter=2026-11-10T05:00Z` editorial: no prorrogar sin revisión de autoridad.
- Base nacional semilla histórica: 73 municipios/219 municipio×categoría; 179 filas fuentes, 93 URL únicas, 174 pares municipio×URL, cinco pares duplicados con historia; 159 fuentes sin revalidación, 20 inspeccionadas parcialmente. Estas cifras son referencias históricas **no métrica de vigencia 2026**. El objetivo es un inventario nacional verificable, no inferir que otros municipios están sin restricción.

## 1. AUTORIDAD OBLIGATORIA Y ORDEN DE PRECEDENCIA

1. `AGENTS.md` en el checkout de PicoRadar; no usar el `main` histórico como base autorizada si contradice la rama moderna.
2. `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx` y `12_Arquitectura_Tecnica_Android_First_v1.docx`; `docs/CURRENT.md`, `docs/DESIGN_CONTRACT.md` y `docs/SOP.md` si se consulta su alcance.
3. `sierraglobalcompany-rgb/PingPongLaw/docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md` (L1 KISS+Ponytail; L2 antirruido; L3 antiparches; L4 UX; L5 verificación independiente; L6 antiping-pong).
4. Plan Maestro `docs/plans/PICORADAR_PLAN_MAESTRO_V2_NACIONAL_20261107.md`, especialmente §§A–F e I/J y el nuevo checkpoint post-C1. Tiene **estado documental Draft**, no sustituye baselines.
5. Contrato del agente lector: `docs/agents/PICORADAR_SOURCE_AGENT_OPERATING_CONTRACT_V1.md`; ledger de decisiones. **Laravel es el único aprobador y publicador; el investigador solo propone.**
6. Fuentes legales **oficiales primarias**: Alcaldía/Secretaría de Movilidad/autoridad de tránsito; DANE DIVIPOLA para universo territorial. Distinguir fecha de comunicado, consulta, vigencia legal, próxima revisión y TTL editorial. Nunca inventar norma, enlace, estado abierto o permiso.

## 2. PREPARACIÓN SEGURA G0 — SOLO LEER, SIN AFECTAR OTRO LOTE

- Trabajo únicamente bajo `D:\codex\<subcarpeta aislada del proyecto PicoRadar>` o espacio de trabajo aislado autorizado. No usar C: como origen operativo; no enumerar, editar o limpiar los 101 WIP históricos. Ningún `reset --hard`, `clean -fdx`, force push, cherry-pick, merge, stash ni eliminación.
- **No abrir ni modificar** candidato de código `D:\codex\_CANDIDATOS\PicoRadar-M1E-Calendar-Overlap-20261108`; contiene cinco rutas C1 sin commit. Preservar todos sus bytes y diffs. No tocar clone H4, `D:\codex\PicoRadar` original ni dispositivos.
- Lectura de referencias canónicas locales de M1A y M1B (fuentes/CSV/SQLite/ZIP de evidencias) **si realmente existen**, copias de solo lectura con SHA. No exigir rescatar indefinidamente ZIP histórico ausente; si falta el artefacto, buscar semilla equivalente en el repo/paquetes existentes y marcar `MISSING_ORIGINAL_INPUT` con una sola búsqueda acotada. No fabricar el archivo ni reconstruir sus filas de memoria.
- GitHub PR #79 documental Draft conserva plan, auditorías y ledger; PR #71 y `main` no son destinos de escritura. Registrar SHA observados antes de empezar; no usar SHA previo como prueba de actualidad.
- Emitir `G0=PASS|PARTIAL_SOURCE_INPUT` más inventario de rutas y hashes encontrados. Si la semilla falta parcialmente, continuar con los registros verificables y registrar denominadores **reales**; no detener todo por una referencia histórica inexistente.

## 3. TRABAJO AUTORIZADO: M1.3, DESCUBRIMIENTO POR AUTORIDAD Y TERRITORIO

### G1 — Delimitar universo sin reabrir M1A/M1B

- Reutilizar **la tabla territorial ya producida** (código DIVIPOLA, departamento, nombre, tipo de entidad, autoridad identificada) y las 179 fuentes históricas cuando disponibles; no borrar duplicados históricos ni hacer otra migración general.
- Contrastar la versión DIVIPOLA oficial vigente con la semilla disponible por **deltas**, no volver a producir otra base si la anterior tiene hash y fuente. Cada nueva unidad territorial entra con `DISCOVERY_STATUS=NOT_SEARCHED`, nunca `OFFICIAL_NO_MEASURE` sin pronunciamiento expreso de autoridad competente.
- Definir denominador real por `department × municipality_or_district × authority × vehicle_class × scope`. La fila territorial es **indicio de investigación**, no regla activa. Mantener `scope` (municipal, metropolitano, corredor, área) y competencia de autoridad.
- Reutilizar `M1A/M1B` PASS **solo** si la fuente, fecha, contenido, SHA y ámbito coinciden. Los 20 registros parciales son `PARTIAL`, nunca 20 medidas certificadas.

### G2 — Investigación nacional focal y en bloque, no ciudad por ciudad en chats

**Gate de alcance — mejora directiva puntual, mismo TASK_ID, NO reiniciar a Codex si ya empezó G0:** esta barrida es una **etapa verificable de descubrimiento M1.3**, no un cierre nacional. Los 32 departamentos + Bogotá D. C. son 33 índices administrativos, NO 33 reglas operativas; el máximo de tres URL nuevas por unidad es presupuesto de esta pasada y NO demuestra cobertura municipal completa. Reportar `M1_3_STATUS=PARTIAL_DISCOVERY` mientras quede cualquier municipio/autoridad del universo `NOT_SEARCHED`, `DENOMINATOR_UNKNOWN` o con falta de evidencia; solo `DISCOVERY_COMPLETE_EVIDENCED` cuando todas las unidades del universo oficial tengan búsqueda/resultado trazable por autoridad y ámbito, con `n/N` real y casos bloqueados explícitos. **Nunca declarar `M1.3 DONE` por terminar las dos barridas**. Las filas individualmente completas podrán proponerse para M1.4/1.5 focal, pero la investigación restante continúa en M1.3 sin inventar otro lote por municipio.

**Límite de ejecución verificable:** hacer **una barrida horizontal** por los 32 departamentos y Bogotá D.C. como índice administrativo (no 33 reglas de pico y placa): para cada uno registrar autoridad competente candidata, portal oficial y estado de la fuente, consultando como máximo **tres URL oficiales nuevas por unidad** en esta barrida. Después hacer una **barrida vertical de las ocho filas núcleo** y de las fuentes oficiales parciales existentes que presenten cambio, contradicción o vencimiento: buscar únicamente las variables faltantes, no repetir páginas cuyo snapshot y SHA estén vigentes. No hay un requisito de llenar 1.096 municipios con fuentes ficticias ni una cuota de reglas aprobadas. Para el resto, producir cola priorizada por autoridad/municipio y estado `NOT_SEARCHED`. Finalizar este lote cuando esas dos barridas estén completas o cuando las fuentes accesibles se hayan agotado con causa registrada; no abrir automáticamente otro prompt por cada ciudad.

- Investigar **por departamento y autoridad competente**, agrupando localidades bajo una misma autoridad donde una fuente oficial demuestra competencia; no extender la misma regla a 20 municipios porque comparten un URL.
- **Denominador de núcleo:** son ocho filas históricas (Medellín particular/moto 2, Bogotá particular 1, Cartagena particular/moto 2, Dosquebradas particular/moto 2, Villavicencio particular 1). **Bogotá moto es un hallazgo adicional de frescura, no una novena coincidencia de las ocho**; reportar `8_core + 1_extra` por separado, sin inflar métricas.
- Priorizar primero los **pendientes de vigencia/riesgo dentro de las ocho filas núcleo históricas** sin volver a copiar información ya confirmada: Bogotá moto (`staleAfter` anterior a `sourceCheckedAt`), Medellín carro/moto (revisión editorial al 10-nov, sin renovación automática), Dosquebradas carro/moto (revisión histórica vencida), Cartagena y Villavicencio (ámbito/zonas/futuras fechas), con criterio de necesidad y evidencias locales. Después, fuentes no revalidadas en el orden del registro de riesgo real.
- Un único lote debe avanzar **todo lo posible en fuentes oficiales accesibles** de autoridades agrupadas, sin emitir un prompt por cada autoridad; si la red o navegador no permiten verificar, registrar `SOURCE_NOT_ACCESSIBLE`, URL concreta, hora y una alternativa oficial concreta, sin especulación.
- Procedimiento por fuente: 1) URL oficial y autoridad; 2) fecha de acceso y fecha de publicación; 3) territorio/categoría afectada; 4) texto o extracto acotado que soporte cada dato; 5) regla, primera/última cifra y dígitos por día; 6) horarios, vacaciones/festivos y excepciones; 7) fechas de vigencia legal y próxima revisión; 8) URL de norma solo si el boletín no basta para un campo material; 9) rotación y riesgo de noticia vieja; 10) evidencia y nivel de confianza. No editar datos productivos.
- **PROHIBIDO:** declarar `no hay pico y placa` por ausencia de búsqueda, extender una vigencia por novedad de revisión, trasplantar perímetros de otra ciudad, confundir placas **que circulan** con placas **restringidas**, crear polígonos o coordenadas de memoria, o asumir 24h sin fecha precisa.

### G3 — Normalizar a un contrato existente, sin modificar runtime

Producir archivos tabulares **de investigación**, no datasets operativos:

1. `M1_3_SOURCE_CHECKS.csv`: `source_id`, `source_url`, `authority`, `divipola`, `territory_scope`, `vehicle_class`, `checked_at_iso`, `source_published_at`, `effective_from`, `effective_until`, `last_rotation_at`, `next_review_at`, `retrieval_result`, `authority_scope_evidence`, `snapshot_sha256_if_captured`, `source_status`, `notes`.
2. `M1_3_COVERAGE_DISCOVERY.csv`: `divipola`, `department`, `territory`, `authority_id`, `vehicle_class`, `regime_scope`, `catalog_status`, `source_status`, `runtime_status`, `last_checked_at`, `next_check_at`, `reason`, `source_ids`, `source_evidence`, `operator_review_required`.
3. `M1_3_OPERATIONAL_CANDIDATES.csv`: solo filas **confirmadas** con `source_id`, `vehicle_kind`, `service_type`, `digitPosition`, `digits_by_weekday`, `time_windows`, `holiday_rule`, `exceptions`, `geometry_or_corridor`, `legal_from`, `legal_until`, `editorial_stale_after`, `blocking_unknowns`, `activation=false`.
4. `M1_3_BLOCKERS.csv`: brecha de fuente, dato, territorio, clase, no competencia, fecha o excepción; severidad; acción concreta; dueño; sin duplicar el mismo problema por URL o ciudad.
5. `M1_3_DELTA_VS_M1A_M1B.csv`: solo novedades comparadas por `source_id` y SHA, con recuentos y procedencia; **no reescribir 179 filas sin necesidad**.

Los CSV pueden tener menos filas si la evidencia faltó; separar `NOT_SEARCHED` de `SEARCHED_NO_CONCLUSION`. `editorial_stale_after` es una **propuesta técnica sin activar**, NO se calcula a partir de `next_review_at` ni se inventa cuando falta política aprobada; campo vacío con `blocking_unknowns` explícito. Prohibido autoaprobar, mover fuente a producción o afirmar cobertura nacional operativa.

### G4 — Control de calidad independiente de los datos

- Verificar unicidad por clave natural de fuente, territorio/autoridad y clase; mantener histórico de revisiones. Informar un denominador para: jurisdicciones universo, investigadas, pendientes, con autoridad, con fuente oficial, con regla completa, con ámbito claro, con conflicto, con licencia/evidencia de snapshot. No presentar porcentajes sin `n/N` y fecha de corte.
- Validar que la evidencia respalde literalmente cada dígito, sentido del dígito, fecha y horario, o marcar `INCOMPLETE` sin inventar. Una misma fuente puede soportar varios territorios solo si hay prueba de competencia.
- Ejecutar verificadores CSV/UTF-8/JSON del lote con código efímero en directorio de reportes, no tocar el runtime. No crear tablas ni migraciones si los datos pueden vivir en CSV normalizados temporales. No agregar dependencias al proyecto.
- Diez controles forenses distintos, cada uno con `evidence`, `result`, `limitation`, `action`, para verificar **esta entrega**; no hacer diez ejecuciones iguales ni un dashboard de fantasía.

### G5 — Salida única y estado verificable

**Entregar exactamente un ZIP** nombrado `PICORADAR_M1_3_DESCUBRIMIENTO_NACIONAL_EVIDENCIAS_UNICAS_20261108.zip`, con:
`FINAL_REPORT.md`, los 5 CSV G3, `SOURCE_PROVENANCE.md` (fecha, enlaces oficiales, SHA reales y extractos breves, sin textos largos con copyright), `COUNTS_AND_DENOMINATORS.csv`, `AUDIT_10.csv`, `COMMANDS_AND_RESULTS.log` (comandos reales, códigos de salida), `STATUS_GIT_AND_WIP.txt`, `NEXT_FOCUS.md`, `MANIFEST.json`, `MANIFEST.sha256` y anexos estrictamente necesarios. ZIP no requiere código móvil, APK ni copia de miles de páginas. Validar **ZIP SHA-256, ZipFile.testzip/CRC, tamaños y hashes de todas las entradas** después de cerrarlo.

`FINAL_REPORT.md` debe informar `M1_3_STATUS=PARTIAL_DISCOVERY|DISCOVERY_COMPLETE_EVIDENCED`, cobertura `N` del universo DIVIPOLA comprobado, cantidad realmente investigada `n`, `NOT_SEARCHED` y bloqueos por ámbito/categoría, evitando declarar M1.3 completo por el índice departamental. `NEXT_FOCUS.md` debe indicar las próximas fuentes **exactas** y sus motivos, no pedir otro preflight global. Un bloqueo ambiental termina el lote con estado `PARTIAL_SOURCES` y el trabajo válido conseguido; no generar otra ronda para repetir las mismas URL.

## 4. DECISIONES Y STOP CONDITIONS — SIN AUTONOMÍA DE ARQUITECTURA

| Condición | Acción autorizada | Prohibido |
|---|---|---|
| Fuente parcial/ambigua | `INCOMPLETE` con campo concreto + URL, continuar otras fuentes | Inventar horario, dígitos, jurisdicción o vigencia |
| Documento oficial no trae decreto integral | Usar boletín si cubre todos los datos, pedir decreto solo por laguna material | Búsqueda interminable del decreto por rutina |
| Bogotá moto `staleAfter < sourceCheckedAt` | Guardar como conflicto y buscar fuente de fecha; nunca editar JSON | Elegir `nextReviewAt` posterior para convertirlo en fresco |
| Medellín TTL llega al 10 nov | Avisar caducidad técnica; proponer revisión fuente/autoridad y timestamp comprobable | Extender TTL automáticamente o declarar permitido |
| Autoridad metropolitana cubre varios municipios | Reutilizar fuente, exigir cobertura probada por cada territorio | Duplicar medida municipal sin prueba de competencia |
| WIP o historia local dudosa | Preservar, registrar hash/ausencia, trabajar en copia aislada | `git reset`, `clean`, borrar, forzar o restaurar sobre originales |
| Falla Flutter/SQLite/JNI/ADB | NO es gate de M1.3; continuar investigación | Reabrir M1F-D01 ni reinstalar SDK en este lote |
| Usuario no dio autorización de publicación | Solo propuesta de fuente/candidato, release NO | Push de código, deploy, activar reglas |
| Fecha legal y `nextReviewAt` difieren | Conservar campos distintos y señal de revisión | Concluir modificación legal por revisión editorial |

## 5. FIN DEL LOTE Y RUTA A PRODUCTO TERMINADO

- **Ahora:** completar M1.3 descubrimiento nacional por autoridad y fuente a partir de M1A/M1B, sin repetir lo hecho.
- **Después:** ChatGPT audita el ZIP; cierra filas completas y toma las decisiones de ámbito; M1.4/1.5 normalizan reglas oficiales completas y revisión humana focal.
- **M2:** motor existente + agente lector proponente, Laravel único aprobador/publicador, pruebas de límites y datos completos.
- **M3:** integración de distribución Laravel→Flutter con manifest, hashes, offline/rollback; cámaras, cuenta opcional si baseline. No backend por cada coordenada.
- **M4:** admisión de las cinco rutas D01-C1 a una rama de código compatible con H4 solo tras verificación Flutter/CI; proteger 101 WIP; CI real, pruebas físicas Android/JNI/firma y GO humano. No confundir el PHP PASS C1 con Flutter PASS.

**ESTADO DE ESTE PROMPT:** listo para ejecutar SOLO cuando no haya un lote M1.3 en curso; si existe, no interrumpir ni duplicar. `NEXT_ACTOR_AFTER_ZIP=CHATGPT`. **FIN PROMPT CODEX LUNA.**