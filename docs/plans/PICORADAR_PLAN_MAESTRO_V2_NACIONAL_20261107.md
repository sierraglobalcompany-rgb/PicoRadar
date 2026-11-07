# PicoRadar — PLAN MAESTRO V2 · Cierre de producto y cobertura nacional

**Edición:** 2026-11-07. **Estado:** PROPUESTA DOCUMENTAL PARA REVISIÓN, NO RELEASE. **Director/autor de decisiones:** ChatGPT. **Ejecutor del código:** Codex Luna bajo orden posterior al cierre R21. **Propietario:** aprobación explícita de publicación y de operaciones riesgosas. **Objeto:** reemplazar la estrategia repetitiva de auditorías generales por una secuencia limitada de entregables verificables.

> **No ejecutar este documento como prompt de Codex.** Es planificación y definición de aceptación. No altera baselines ni leyes. R21 V2 ya concluyó PARTIAL el 2026-11-07; no tocar su checkout/candidato al arrancar M1. La propuesta se publicará, si se autoriza, únicamente en rama documental independiente, nunca como merge a `main` o a PR #71.

## A. Autoridad, objetivos e invariantes

1. **Autoridad documental:** `AGENTS.md` + políticas seguridad/privacidad/store > `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx` > `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx` > flujos aprobados > `docs/DESIGN_CONTRACT.md` > `docs/CURRENT.md`/SOP; verificar el archivo local `LEYES_IMPLEMENTACION_1_A_6.md` original y su SHA antes de cualquier cambio. Este plan no sustituye esos documentos.
2. **Resultado nacional exigido:** identificar jurisdicciones colombianas que realmente restringen circulación, y llevar a operación segura *todas las restricciones oficiales y actuales confirmadas* para sus clases efectivas. Un listado de municipios no equivale a operación. Localidades desconocidas siguen `UNKNOWN`; no convertir búsqueda fallida en “no hay pico y placa”. Un lanzamiento de alcance reducido requiere decisión expresa del propietario; no se rebaja el objetivo nacional en silencio.
3. **Arquitectura congelada:** Flutter feature-first + Riverpod/go_router/Drift, motor y cámaras en la ruta local; Laravel monolítico como admin, versionador y publicador; datasets descargables offline. No microservicios, no backend para cada posición GPS, no historial de GPS por defecto, no monetización antes de Free 1.0.
4. **Fuente oficial práctica:** calendario/comunicado en web de alcaldía o autoridad competente basta para proponer regla cuando trae *todos* los campos necesarios. No buscar decreto por rutina: una o varias páginas oficiales concordantes pueden documentar conjuntamente fechas, dígitos, horarios, festivos, exenciones y territorio; consultar acto integral solo si permanece una laguna/contradicción material después de ese cotejo. Guardar evidencia de qué dato se tomó de qué fuente.
5. **Consumo sin cuenta:** Garaje y Pico siguen sin registro. Distinguir cuentas de operadores administrativos de cuentas voluntarias de consumidores; no subir placas, documentos, recorridos, GPS o fotos por defecto. Alta voluntaria con políticas de privacidad y borrado exige contrato y QA específicos.
6. **No falsos verdes:** `UNKNOWN`, `STALE`, `CONFLICT` o revisión pendiente no equivalen a “puede circular”; el motor solo evalúa el tipo de restricción para el cual posee cobertura. Restricciones zonales, nocturnas, festivos, categorías y corredores no se infieren por analogía.
7. **No alterar datos aprobados:** los JSON generados se modifican desde generadores/inputs autorizados, con trazabilidad. Sin reescritura de historial, borrado de WIP/vehículos, `force push`, `merge`, Hostinger o Mi A3 sin autorización explícita adicional.

## B. Evidencia de partida (no extrapolar)

**Código GitHub cotejado:** `sierraglobalcompany-rgb/PicoRadar`, PR #71 `OPEN/DRAFT`, HEAD remoto `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` al 2026-11-07; `main` histórico no es base de desarrollo. R15/R19 aportaron localmente commits `0e9b0f2…`, `91c1a8f…`, `1b5badd…`. **R21 V2 CONCLUIDO PARTIAL/PR_NOT_READY sin commit: ZIP SHA-256 ffc3355569156f170e80ea7df4a886edef5afb351b097c179fada7fe3763e791; 101 WIP intactos; siguiente acción ChatGPT M1.** No mezclar con PR #72 ya integrado en rama moderna según `docs/CURRENT.md`.

**Límite y denominador de investigación:** CSV semilla R13/R21, 73 municipios DIVIPOLA, 219 filas (exactamente 73 `car-private`, 73 `car-taxi`, 73 `motorcycle-private`), 160 `pending`, 51 `conditional`, 6 `verified`, 1 `no_documented_restriction`, 1 `expired` (etiquetas históricas). 219 claves municipio×clase únicas, no 219 medidas activas. Una revisión verdadera de totalidad nacional exige cruzar con DIVIPOLA oficial vigente y competencias de autoridades, no presumir que 73 son suficientes.

**Calidad de fuentes semilla:** 179 entradas = 159 enlaces históricos **no revalidados** + 20 páginas oficiales consultadas **parcialmente** el 2026-11-07. Solo 174 pares municipio×URL son distintos (cinco pares aparecen dos veces con estados históricos y nuevos); existen 93 URL únicas. Los 20 registros consultados no aportan `content_sha256` del snapshot archivado. Varias URL se comparten entre numerosos municipios (Atlántico, fuentes metropolitanas): no supone competencia automática ni una misma regla. `OFFICIAL_PAGE_REVIEWED_PARTIAL` **no** significa que la regla esté completa y lista para runtime. `source_checks=20` no es 20 reglas certificadas. El registro SQLite/Excel es una semilla de investigación, NO la base productiva.

**Producto:** R18 AOT Gradle PASS, R19 verificó APK staging firmado debug de 108.767.389 bytes SHA-256 `D9F71FC77F2202B6F291B1317DFEF10F532F5D46B5D44BFC7E18B9953F3C8522`; JNI/GPS real no probados. H4 corrige foco backend en clon privado (catálogo `20261025` vs `20261024`) y RED/GREEN focal; Laravel completo/CI sobre SHA futuro siguen pendientes. `RELEASE=NOT_APPROVED`.

**Backend remoto observado:** modelos `Dataset`, `DatasetSource`, `DatasetRelease`, `RestrictionPublication`, `Camera`, `User` (operadores); rutas admin de restricciones/importación/revisión/publicación. Inventario de esas capacidades ≠ contrato de actualización móvil completo ni registro de consumidores. Reutilizar antes de diseñar nuevas tablas/servicios.

**Fuente de universo y competencia:** DIVIPOLA DANE, https://www.dane.gov.co/index.php/sistema-estadistico-nacional-sen/normas-y-estandares/nomenclaturas-y-clasificaciones/nomenclaturas/codificacion-de-la-division-politica-administrativa-de-colombia-divipola ; MinTransporte remite a autoridades de tránsito municipales para pico y placa https://mintransporte.gov.co/preguntas-frecuentes/113/transito-infracciones-a-las-normas-de-transito/ . Un código DIVIPOLA identifica unidad territorial, no prueba existencia ni ausencia de restricción.

## C. Modelo mínimo de cobertura y fuentes (contrato de datos antes de programar)

**Tres entidades lógicas, reutilizando tablas existentes:**

- `JurisdictionCoverage`: `divipola`, `authority_id`, `territory_id/type`, `vehicle_class`, `catalog_status`, `source_status`, `runtime_status`, `last_checked_at`, `next_check_at`, `reason`. La unidad de calidad es **jurisdicción efectiva × clase × régimen/ámbito**, no simplemente municipio. Estado independiente para ``medida inexistente comunicada oficialmente`` y ``búsqueda sin evidencia``; un booleano nunca basta.
- `AuthoritySource`: `authority`, `stable_portal_url`, `specific_notice_url`, `url_kind`, `scope_evidence`, `published_at`, `checked_at`, `legal_from/until`, `review_due_at`, `etag/last_modified`, `snapshot_sha256` solo si el snapshot fue capturado, `retrieval_status`, `content_status`, `decision`, `superseded_by`. Reutilizar `DatasetSource` y relaciones reales antes de migración. **Una URL única puede relacionarse con varias autoridades/territorios solo si la fuente acredita la competencia.** Conservar historial de estados en checks sin duplicar filas activas.
- `RestrictionRuleEvidence`: `rule_id`, `source_ids`, `jurisdiction/geometry`, `vehicle_class`, `plate_digit_side`, `digits_by_day`, `start/end_local`, `overnight`, `holidays`, `exceptions_scope`, `effective_from/until`, `review_ttl`, `generator_version`, `runtime_dataset_version`, `tests_evidence_id`. Horario legal, fecha de aviso y fecha técnica de frescura son campos diferentes.

Los nombres son **contratos conceptuales**, no órdenes de crear nuevas tablas. Codex hará un mapa de equivalencia a Eloquent/compilador existente y propondrá únicamente columnas o una tabla si demuestra faltantes y alternativas.

**Estados de descubrimiento:** `NOT_SEARCHED`, `OFFICIAL_MEASURE_FOUND`, `OFFICIAL_NO_MEASURE`, `TEMPORARILY_SUSPENDED`, `SCOPE_INCOMPLETE`, `OFFICIAL_CONFLICT`, `NO_CONCLUSIVE_EVIDENCE`, `EXPIRED`; sus equivalentes en UI/rules engine se decidirán conforme al baseline antes de cambiarlos. **No atribuir `OFFICIAL_NO_MEASURE` por ausencia de resultados.**

**Reglas de deduplicación:** URL canónica (sin fragmentos analíticos, manteniendo parámetros que cambien el documento), pareja autoridad/territorio + tipo documental; fuente única, múltiples comprobaciones versionadas. No borrar las cinco duplicaciones de la semilla sin preservar estado histórico y fecha. Documento de Atlántico multi-municipio: registrar competencia una vez y cada ámbito con evidencia por separado.

## D. Fases ejecutables y dependencias: una sola ruta a DONE

| Macro / fase | Objetivo y tareas concretas | Dependencia | Entregable/aceptación (Definition of Done) | Responsable / alcance Git |
|---|---|---|---|---|
| **M0.1 R21** | R21 V2 entregó ZIP, hashes y tres gates bloqueantes; conservar sin repetir. | CERRADO PARTIAL | Un ZIP R21 verificado, SHA/HEAD/pruebas reales; tres resultados `PR/LEGAL/BACKEND` GO o bloqueo causal. | Codex ejecuta, ChatGPT audita **solo deltas**. |
| **M0.2 Consolidación** | Comparar R21 con este plan, leyes, baselines, HEAD local/PR; resolver conflictos de alcance y dependencias. | M0.1 | Un `BASELINE_DECISIONS.md`: hechos probados, pendientes, **solo gates nuevos**; lista cerrada de archivos permitidos del próximo lote. | ChatGPT, ninguna escritura a runtime. |
| **M0.3 Gobernanza Git** | Plan documental en rama/PR Draft independiente; decidir después cómo incorporarlo a fuente moderna. Sin tocar PR #71/main o R21. | Documental, independiente | Documento versionado visible y PR Draft; aún NO MERGED. | ChatGPT acción documental autorizada, sin code push. |
| **M1.1 Universo** | Importar/listar DIVIPOLA oficial con versión y SHA; cruzar 73 municipios y autoridades, distritos, ámbitos metropolitanos, municipios no seleccionados; identificar si unidad es municipio o área no municipalizada. | M0.2 | Tabla de universo oficial con fecha, `divipola`, autoridad candidata, `discovery_status`; claves únicas, sin inventar número nacional ni reglas. | Codex en rama focal futura; ChatGPT valida contrato. |
| **M1.2 Normalizar fuentes** | Migrar 179 filas a bitácora: 93 URL únicas, cinco pares duplicados históricos, 159 no revalidados, 20 observados parciales. Resolver enlaces compartidos Atlántico/Medellín con `scope` explícito. | M1.1 | Un solo registro lógico por fuente activa; histórico de comprobaciones intacto; 0 pérdida de evidencia; pruebas de unicidad/relación. | Codex; NO cambiar directamente BD productiva. |
| **M1.3 Descubrimiento nacional** | Investigación agrupada por departamento/autoridad; buscar primero portal oficial y calendarios vigentes, luego boletines, actos si faltan campos. Clasificar `NO_CONCLUSIVE_EVIDENCE` sin fingir no-medida. | M1.1–M1.2 | Cada jurisdicción del universo tiene historial de búsqueda, autoridad competente y categoría/ámbito o estado investigable; informe de **descubrimiento** separado del de **reglas operativas**. | Agente investigador lector + revisión ChatGPT; Codex integra archivos. |
| **M1.4 Matriz operativa** | Por jurisdicción/ámbito: particular, taxi, moto y clases especiales indicadas por autoridades. Identificar dígito primero/último, calendario, nocturnos, festivos, corredores, zonas, vigencia. | M1.3 fuentes relevantes | Regla candidata completa por clase/ámbito con fuente oficial y fechas; faltantes listados sin `allowed`. Conteos con denominadores explícitos. | Codex normaliza; ChatGPT arbitra casos ambiguos. |
| **M1.5 Gate legal** | Revisión humana de ambiguos, conflictos, suspensiones, expirados y medidas de corta duración. No revisar otra vez fuentes sin cambio vigente de SHA/fecha. | M1.4 | Matriz `OFFICIAL_COMPLETE / PARTIAL / CONFLICT / NO_MEASURE / UNKNOWN` con fecha y evidencia; GO de compilación solo para entradas completas. | ChatGPT dirige; Codex ejecuta checks. |
| **M2.1 Contrato motor** | Comparar propuestas M1 con capacidades del motor actual (día, placa, zona, taxímetros, fines de semana, festivos, madrugada, excepciones); no extender engine por ciudad si ya representa el caso. | M1.5 | Matriz `SUPPORTED / DATA_ONLY / ENGINE_GAP`; **ningún motor nuevo**; defectos aislados con prueba RED. | ChatGPT arquitectura, Codex pruebas. |
| **M2.2 Compilación única** | Transformar fuentes aprobadas mediante pipeline/generadores existentes, jamás editar solo runtime JSON. Preservar claves estables, semántica de `staleAfter`, versionado y metadata de fuentes. | M2.1 | Input→generator→dataset→runtime reproducible con SHA y pruebas focales; fuentes pendientes fuera del conjunto habilitado. | Codex lote funcional; sin deploy. |
| **M2.3 Matriz de regresión** | Casos por tipo de restricción, no 219 tests copiados: dígitos, cambio semanal, zona, inicio/fin, festivos, madrugada, taxi, primer/último, `UNKNOWN/STALE` y ausencia oficial. | M2.2 | Parametrización reusable + un fixture por variación legal/material, pruebas en bordes. Fail-closed en incertidumbre. | Codex; ChatGPT valida falsos verdes. |
| **M2.4 Agente de lectura** | Proceso CLI/job independiente de solo lectura, quizá otra máquina pero sin otro backend. Planificador por fuente (7/15/30 días + eventos), ETag/Last-Modified, hash cuando hay archivo, deduplicación, alertas, propuestas y conflictos. | M1.2, M2.2 | Entradas verificables y propuestas, cero publicaciones automáticas, sin contraseñas, idempotente, logs sin PII; tests `NO_CHANGE`, `CONFLICT`, `EXPIRED`, `ERROR`, nueva rotación. | Codex; backend Laravel sigue autoridad de publicación. |
| **M2.5 Operación** | Definir responsable de revisión de propuestas, SLA según vencimiento, reversión y alerta. Sin renovación arbitraria si la fuente falla. | M2.4 | Playbook y cron probado sin ejecutar en producción, dashboard mínimo reutilizando admin. | ChatGPT controla política, Codex implementa. |
| **M3.1 Integración backend** | Mapear `DatasetSource/DatasetRelease/RestrictionPublication` y admin existente con datos M1/M2; solo migraciones mínimas si contrato insuficiente. | M2.2, M2.4 | Import/review/validate/publish/retire/rollback en ambiente efímero, tests SQLite/PHP y gates de permisos, sin Hostinger. | Codex; migración aprobada por ChatGPT. |
| **M3.2 Distribution API** | Definir manifest público ligero de versión de datasets de restricciones, cámaras y geografía; hash/firma/expiry/compat, cache y rollback. Usar mecanismo actual si ya existe. | M3.1 | Contrato versionado, pruebas de lectura cache, fallos y rollback; no servir datos personales. | Codex. |
| **M3.3 Flutter sync** | Consulta ocasional del manifest con red; descarga temporal, verificación, activación atómica, persistencia local y último bueno. Motor local no contacta server por posición. | M3.2 | Pruebas offline, caída de red, corrupto, downgraded, restart, versión incompatible; sin perder vehículos o docs. | Codex; QA móvil focal. |
| **M3.4 Fotomultas** | Reutilizar pipeline ANSV/`Camera`/`CameraSource`; publicar solo con autoridad, ubicación, clase, evidencia de operación y cobertura de velocidad cuando aplique. | M3.1 y datos ANSV existentes | Comparación fuente→registro→versión→APK, pruebas de retiro/actualización y `unknown` de velocidad/operación; nunca declarar activa una cámara solo por coordenada. | Codex; revisiones de fuente por ChatGPT. |
| **M3.5 Cuentas opcionales** | Separar operador `User` de consumidor, revisar contrato baseline, consentimiento, sesión, seguridad, borrado de cuenta y datos, sin cambiar Free anónimo. | M3.1; contrato de producto aprobado | Registro/login opt-in y revocación con pruebas de aislamiento, o decisión explícita de fase posterior **sin afirmar que el requisito fue entregado**. | ChatGPT decide alcance; Codex implementa. |
| **M4.1 GitHub** | Tras aceptación de M0–M3 integrar únicamente commits revisados en rama moderna; actualizar PR, mantener main intacto hasta autorización. | Aprobación ChatGPT/propietario, CI disponible | SHA único publicado, diff revisado, checklist y comprobación de no cambios ajenos. **Nunca subir el checkpoint sin evaluación funcional/PII.** | Codex solo por orden explícita, no automática. |
| **M4.2 CI y seguridad** | Ejecución de workflow real cuando se levante bloqueo de Actions; backend, Flutter, contratos, análisis y escaneo de secretos. No fingir green con jobs no ejecutados. | M4.1 | CI concluida en SHA exacto; defectos no aprobados resueltos, gates documentados. | Codex; propietario gestiona cuota. |
| **M4.3 Android físico** | Con aprobación expresa, validar arranque/JNI, persistencia, GPS real, cámaras, ciclo background, permisos, actualizaciones y datos de prueba sin tocar DEV/PROD reales. | Artefacto/entorno aislado y autorizado | Matriz física efectiva con log de crashes, hashes, dispositivo y datos originales preservados. AVD aislado no sustituye GPS físico cuando baseline lo exige. | Codex operativamente, propietario autoriza, ChatGPT audita. |
| **M4.4 Firma y release** | Firma comercial resguardada, AAB/APK final, backend con HTTPS, privacidad/store, matriz de ciudades actuales al instante de salida, rollback de datasets. | M4.2–M4.3 | **GO humano explícito**, artefacto final realmente firmado/probado y rollback ensayado. `RELEASE=NOT_APPROVED` hasta entonces. | Propietario autoriza, ChatGPT emite GO técnico, Codex ejecuta. |

> **Dependencias críticas**: M1.1–M1.3 pueden hacerse sin esperar JNI; agente puede avanzar con fuente/registry antes de un release; API/sync depende de versión publicada; cuentas voluntarias se aíslan del MVP anónimo, pero no se eliminarán del backlog. M4 físico y firma no bloquean la investigación nacional.

## E. Criterios de salida por macro (no porcentajes inventados)

- **M0 DONE:** ZIP R21 recibido y verificado; un único estado Git/HEAD, decisión de qué pruebas se pueden reutilizar, backlog ordenado por riesgos. Documentación Git en Draft separada y sin conflictos.
- **M1 DONE:** DIVIPOLA/autoridades/versiones inventariados y trazables; todas las jurisdicciones del universo con búsqueda documentada y estados explícitos; para **cada jurisdicción con medida confirmada** cobertura por vehículo/territorio o bloqueo real; cada fuente con fecha, autoridad, evidencia y revisión programada. No prometer total nacional por tener 73.
- **M2 DONE:** cada regla aprobada se genera y valida con test de bordes; propuesta→human review→dataset reproducible; agente lector 7/15/30 días + eventos con pruebas de idempotencia, sin publicación automática.
- **M3 DONE:** publicación/rollback real en ambiente no productivo, app consume versiones firmadas/con hashes verificados y conserva datos localmente; fotomultas con fuente/estado; registro voluntario según contrato sin hacer obligatoria la cuenta.
- **M4 DONE:** cambios Git integrados con aprobación, CI sobre SHA, soporte físico, firma de producción, seguridad y stores; GO final propietario. Si falta una regla nacional oficialmente confirmada, **V1 nacional integral NO-GO**; cualquier V1 limitada necesita aceptación específica y nombre de cobertura honesto.

## F. Política antipingpong: reutilizar pruebas y ahorrar tokens

**Identidad de gate reutilizable:** `(git_tree_or_artifact_sha, entradas/dataset_sha, lockfiles/toolchain_version, comando_de_prueba, configuración, entorno relevante, vigencia jurídica)`. Una prueba histórica **solo se reutiliza** si todas las dependencias materiales siguen iguales. Una actualización de reglas exige pruebas legales focales aunque el motor binario sea idéntico; un cambio de PHP no reabre automáticamente 3.000 pruebas Flutter.

**Selección mínima de validación:**

| Cambio | Pruebas focales nuevas | Pruebas NO repetidas si hashes y dependencias son iguales |
|---|---|---|
| Solo documentación/plan | enlace, integridad Markdown, coherencia con baselines | AOT, Flutter, PHPUnit, Android, crawler |
| Fuente oficial/fecha | lectura/frescura/dígitos, bordes de calendario, evidencia/competencia | Gradle, GPS, UI no afectada |
| Compilador de reglas/dataset | generador reproducible, parser/engine focal, schema, bordes afectados | tests físicos de AOT inmutable |
| Fuente / import Laravel | lint/PHPUnit focal + contrato publicación + DB efímera | Flutter suite si asset y API no cambiaron |
| Flutter UI/motor | analyze + test de feature afectada + integración relevante | backend/ANSV no impactado |
| Firma/package/manifest | firma, SHA, contrato, instalación segura | tests lógica de fuente sin cambios, salvo release legal vencido |
| Cambio de API/BD/seguridad | contrato, auth, migración/rollback y suite relacionada; full gate en cierre | no reclamar GREEN histórico para componente cambiado |

**Gates completos obligatorios:** tras la integración final y antes de publicar se ejecutan todas las suites requeridas por `AGENTS.md` y el baseline aplicable sobre el SHA release; no usar la política de ahorro como excusa para saltarse el gate final. **Reglas con caducidad:** un mismo SHA legal no prorroga automáticamente su validez; `staleAfter` es fecha técnica, no derogación.

**Formato una sola entrega Codex:** `PICORADAR_<LOTE>_EVIDENCIAS_UNICAS_<YYYYMMDD>.zip`, con `FINAL_REPORT.md`, `GATES.csv`, `FILES_CHANGED.csv`, `LEGAL_SOURCE_MATRIX.csv` si aplica, resultados/cmd/logs reducidos, `MANIFEST.json`, `MANIFEST.sha256`, auditoría de 10 controles *solo de lo nuevo*. Un ZIP comprobado por hashes, no APK enormes salvo que sean necesarios para auditar binario nuevo. Resumen externo con solo enlace + SHA + actor siguiente.

**Límite de loops:** una incidencia de entorno por lote recibe una investigación causal proporcionada y una alternativa segura acotada. Si no tiene arreglo en el alcance, se registra `BLOCKED_CAUSE` y se concluyen fases independientes, en vez de emitir un nuevo Rxx solo para preflight.

## G. Gobernanza GitHub y documentación

1. Plan maestro en **nueva rama exclusiva de documentación** iniciada en `recovery/20261019-modern` HEAD remoto comprobado. Crear únicamente `docs/plans/PICORADAR_PLAN_MAESTRO_V2_NACIONAL_20261107.md` (contenido íntegro de este documento). Abrir PR **Draft dirigido a `recovery/20261019-modern`**, no a `main`, sin merge y sin actualizar PR #71; nunca tocar el checkout que usa R21.
2. Esta versión en Draft es **propuesta**, no reemplazo automáticamente de `docs/CURRENT.md`, `docs/SOP.md` ni de baselines. Al terminar R21, incorporar allí solo las correcciones de estado justificadas por el ZIP (en nueva revisión documental). No fabricar éxitos de R21 por anticipado.
3. Registrar los futuros lotes funcionales en el formato de `codex/lots/Cxx_*.md` o handoff existente según `AGENTS.md`; un lote por rama, sin ruido documental. El PR del plan no permite implementación automática, push de código ni despliegue.
4. No añadir a GitHub la SQLite/Excel semilla sin revisión de licencias, procedencia y campos privados; es material **NO PRODUCTIVO**. Posteriormente versionar como artefacto derivado cuando pase la revisión y se decida su ubicación.

## H. Matriz de riesgos (stop conditions)

| Riesgo | Síntoma observable | Acción antes de avanzar |
|---|---|---|
| R21 modifica arquitectura/datos mientras plan se prepara | SHA/contrato divergente | Reconcilia diferencias por delta, actualiza tarea, sin perder evidencia |
| Jurisdicción metropolitana extrapolada | Una fuente aparece en 20 municipios sin alcance individual | REQUIRES_SCOPE_PROOF; no activar automáticamente |
| Fuente oficial incompleta | faltan festivos, zona, fecha o tipo | ampliar búsqueda, no norma automática |
| Política de TTL confundida | `staleAfter` alterado sin justificante | fail-closed, fuente oficial y test de borde |
| Registro de consumidor rompe anónimo | obliga login para Garaje/Pico | rechazar hasta restaurar requisito Free 1.0 |
| Escáner/publicador automático no autorizado | agente escribe en tabla activa | cortar privilegios, solo propuesta y aprobación |
| Falla Windows/CI/Android | gate ambiental bloquea otro frente | cerrar gate con causa, seguir trabajo independiente |
| Evidencia histórica usada para código cambiado | SHA no coincide | pruebas focales según impacto, full suite final |
| CI sin ejecutar/firma debug | aparece en informe como “ready” | NO-GO hasta job real, firma release, QA |

## I. Decisión operativa y siguientes actores

**Ahora post-R21:** ChatGPT verificó ZIP/HEAD y convierte M1.1–M1.3 en el único lote `M1A-FUENTES-NACIONALES` de datos/discovery. Los gates Laravel/Flutter/PR se conservan como pendientes M3/M4: no condicionan el inicio de M1. No publicar reglas ni marcar libre circulación por ausencia de fuente. PR #79 sigue documental Draft, sin merge.

**Release:** `NOT_APPROVED`. **PR #71:** `OPEN/DRAFT` HEAD histórico mientras no exista nueva evidencia. **No se promete fecha o porcentaje de terminación sin cobertura verificable.**

## J. Acta de reconciliación post-R21 V2 (2026-11-07)

**Resultado exacto recibido:** `R21_V2_RESULT=PARTIAL`, `PR_NOT_READY`, `RELEASE=NOT_APPROVED`; ZIP SHA-256 `ffc3355569156f170e80ea7df4a886edef5afb351b097c179fada7fe3763e791`. No hubo nuevo commit, corrección de código, publicación, ADB ni AOT. Clasificar 26 registros en la matriz de revisión **no equivale** a corregir código o reglas.

**101 rutas:** `FULL_DIFF_READ=4`, `STRUCTURAL_REVIEW=25`, `NOT_REVIEWED=71`, `HISTORICAL_EVIDENCE_ONLY=1`. Los 101 blobs WIP están conservados, pero solo 4 cuentan con lectura completa. La revisión semántica de alto riesgo queda en el carril de integración, no es prerrequisito para crear el registro nacional aislado.

**Backend:** cache Composer 108/108, autoload instalado y unit ANSV 3/21 PASS. La instalación no conserva exit code; `pdo_sqlite` falta, así que no hay PHPUnit/Laravel completo. **No repetir** por costumbre; habilitar extensión/entorno correcto y test solo cuando se retome M3/CI.

**Fuentes y motor:** Medellín tiene rotación oficialmente publicada con `staleAfter=2026-11-10T05:00Z` técnico/editorial; no prorrogar a mano. Cartagena: comunicado mensual de noviembre y oficial anual de enero aportan campos complementarios. Registrar errata del día y resolver con fecha oficial/calendario y pruebas de borde; no imponer búsqueda indefinida del decreto si todas las variables materiales están cubiertas. Moto zonal/nocturna sigue bloqueada.

**M1A autorizado como diseño y colección aislada, no como código de aplicación:** normalizar semilla conservando 179 eventos históricos → 93 fuentes URL → 174 relaciones territorio/fuente; traer DIVIPOLA oficial vigente; crear lista nacional con estados `NOT_SEARCHED` / `NO_CONCLUSIVE_EVIDENCE` cuando proceda y cola priorizada para investigación. No convertir URL compartida en competencia municipal, ni afirmar `OFFICIAL_NO_MEASURE` por búsquedas vacías.

**Cambios GitHub:** solo documentación en PR #79, `OPEN/DRAFT`; PR #71 no cambia, `main` y dispositivos intactos. Próximo gate ChatGPT: evaluar el ZIP único M1A y decidir lote de investigación o transformación sin auditorías globales repetitivas.