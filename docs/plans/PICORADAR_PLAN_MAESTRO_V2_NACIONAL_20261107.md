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

## K. Rectificación forense de M1A V2 (2026-11-07)

**Estado:** M1A V1 preparado pero sin reporte de ejecución; V2 lo sustituye solo si no comenzó. No se autoriza ninguna escritura a runtime, WIP, CI, producción, teléfono ni PR #71.

**Hallazgo clave:** ya existe en GitHub el inventario DANE/MGN 2025 rastreado: `server/database/data/colombia_divipola_mgn_2025.json`, Git blob `e32d64d9bd08ad953c679041f22a2393cfc32831`, 1.104 municipios únicos/33 unidades de primer nivel (32 departamentos + Bogotá D.C.), 73/73 correspondencias `pico_jurisdiction_divipola_v1.json` presentes. M1A debe **reutilizar ese snapshot**, comprobar la actualidad del DANE mediante delta cuando sea viable, nunca reconstruir desde solo 73 por falta de Internet. 1.104 municipios inventariados NO equivalen a 1.104 municipios con medidas operativas.

**Fuentes y riesgos:** 93 URL únicas; 174 pares municipio–URL; 179 filas históricas, 5 pares duplicados; 20 comprobaciones parciales sin captura hash y 159 candidatas históricas; 7 URL de Facebook; 8 fuentes asociadas a varios municipios (89 relaciones), sin prueba automática del ámbito. Preservar historiales, reconocer alias sospechosos sin fusionar, separar autoridad, territorio, vehículo, vigencia y regla completa.

**Límites de ejecución:** generar la cola de investigación para el universo histórico completo, pero realizar una primera consulta acotada (máximo 33 portales de primer nivel + 25 jurisdicciones prioritarias); documentar `NOT_SEARCHED` sin interpretar como exención; conservar `source_checked_at` independiente de `snapshot_audited_at`. Ejecutar únicamente validaciones de datos del delta M1A, no repetir Gradle/Flutter/Laravel/JNI/CI R18–R21.

**Orden canónica:** `docs/plans/CODEX_LUNA_PICORADAR_M1A_V2_ORDEN_20261107.md` en este mismo PR #79. Entregar un solo ZIP con fuente normalizada, inventario, cola, manifiesto y diez comprobaciones focales; `RELEASE=NOT_APPROVED`. PR #79 permanece Draft sin merge. Si Codex ya ejecuta M1A V1, no interrumpir: auditar el resultado contra estas correcciones antes de decidir el siguiente paso.


## L. M1A postejecución: conciliación de fuentes sin repetir lote (2026-11-07)

- **Informe Codex M1A:** `PARTIAL`, `RELEASE=NOT_APPROVED`; universo DANE/MGN2025 1.104, dos jurisdicciones investigadas parcialmente, cero reglas nuevas completas. Los insumos del ZIP anterior no estuvieron disponibles en el entorno Codex.
- **Recuperación de dirección fuera de Codex:** ZIP M1A V2 histórico `e8191f71...d4173` presente e íntegro; reconciliados 73 semillas, 219 combinaciones históricas, 93 fuentes, 174 relaciones, 179 observaciones; 0 referencias huérfanas, 5 pares duplicados de historial preservados. No se activó ninguna regla. CSV enriquecidos y ZIP único están fuera de este PR documental, sin cambios de runtime.
- **Riesgo de integridad WIP:** 101 rutas protegidas conservan conteo, pero hash resumido difiere del preflight; no declarar integridad byte-a-byte sin la comparación focal read-only de 101 SHA del checkpoint R21.
- **Prioridad jurídica P0:** Medellín `staleAfter=2026-11-10T05:00Z`; tratar como TTL editorial, no fin legal; extraer norma oficial y prueba antes de ajustar código.
- **NEXT:** `docs/plans/CODEX_LUNA_PICORADAR_M1B_FUENTES_20261107.md` con paquete físico de tablas adjunto. No se vuelve a pedir M1A G0/G2 ni AOT/QA repetidas. Mantener PR #79 en Draft y PR #71 intacto.

Acta trazable: `docs/plans/PICORADAR_M1A_CIERRE_DIRECTOR_Y_M1B_20261107.md`. No hacer merge ni release sin autorización.

## M. Dirección M1B V2, contrato del agente y registro de decisiones (2026-11-07)

**Pre-ejecución:** La orden M1B V1 se sustituye por M1B V2 únicamente si Codex no comenzó M1B V1. No consta ejecución M1B; release NO APROBADO. La entrega de Codex será un único ZIP manifestado.

**Estado del agente:** solo existe su contrato, NO hay agente de vigilancia automática implementado ni desplegado. El investigador tiene acceso de solo lectura a fuentes públicas y produce propuestas; Laravel existente seguirá siendo el único publicador con control humano y rollback. Flutter permanece sin cuenta obligatoria y local-first.

**Correcciones principales:** (1) URL, HTTP 200/304 y fecha de consulta no equivalen a regla jurídica vigente; mantener fechas de publicación, revisión, inicio/fin y TTL editorial separadas. (2) No extrapolar reglas desde URLs asociadas a varios municipios. (3) 1.104 DIVIPOLA, 73 semilla, 219 categorías históricas, 93 fuentes y 174 relaciones son denominadores diferentes. (4) NOT_SEARCHED, 404 o URL rota no equivalen a sin medida. (5) SHA de captura solo con bytes archivados, no a partir de URL. (6) Cursor incremental y NO_CHANGE evitan reinvestigaciones. (7) Integridad de 101 WIP queda en gate previo a integración Git, no en el lote documental M1B. (8) No repetir AOT, H4 focal, AVD y suites R18–R21.

**Documentación de autoridad secundaria:** docs/agents/PICORADAR_SOURCE_AGENT_OPERATING_CONTRACT_V1.md y docs/agents/PICORADAR_AGENT_ERRORS_DECISIONS_LEDGER_20261107.md. **Orden única canónica:** docs/plans/CODEX_LUNA_PICORADAR_M1B_FUENTES_20261107.md (contenido V2). Root AGENTS.md, baselines y seis leyes locales tienen precedencia. PR #79 permanece Draft, sin merge ni activación.


## M. Auditoría final de transferencia M1B V2 (2026-11-07)

**No crea nueva fase. Estado:** M1B V2 sin ejecución de investigación tras el bloqueo de G0; R18/R19/R20/R21 y M1A quedan conservados según su evidencia. **Un único paquete operativo vigente:** `PICORADAR_M1B_V2_PAQUETE_FINAL_SIN_REPETICIONES_20261107.zip` SHA-256 externo `06e208a5d3131cfe7ca7156dddd1f586c001e5472fdd5456ed57889c23c37168`, prompt `CODEX_LUNA_PICORADAR_M1B_V2_ORDEN_FINAL_20261107.md` SHA `10c5560373e247a6010d3dfc1a8b71f3d617a56e10cdd2c3d8b6f605496538a3`. La ruta local de Sandbox no se presume disponible para Codex: **el ZIP debe adjuntarse en binario o situarse en ruta real comprobada**. Si Codex ya está investigando con otro paquete que pasó G0, no interrumpirlo.

Auditoría forense de 10 controles: (1) ZIP previo SHA PASS; (2) CRC/manifiesto 19 miembros PASS; (3) hash upstream confundible, corregido; (4) conteo real 11 datos = 9 CSV + 2 JSON, corregido; (5) 1.104 únicos, cola 1.104 y semilla 73 íntegros; (6) fuentes 93, relaciones 174, historial 179, duplicados históricos 5 y cero hashes de captura; (7) fuentes oficiales Medellín II-2026/Cartagena requieren investigación de contenido/fecha/perímetro, ninguna regla activada; (8) leyes, privacidad, KISS preservados; (9) presupuestos y numeración corregidos, no reabrir trabajo histórico; (10) PR #79 Draft, PR #71 intacto. Estos son controles del **plan y datos**, no pruebas nuevas del motor.

**Invariantes para el siguiente lote:** investigación de alcaldías oficial/municipio×vehículo/fecha/territorio, documentación incremental y un ZIP único. No repetir AOT, JNI, R18–R21 ni G0 M1A; no revisar WIP en M1B; no modificar `AGENTS.md`, `main`, PR #71, Hostinger, teléfono ni datasets productivos. `NO_MEASURE` solo con evidencia oficial de ausencia: `NOT_SEARCHED` no equivale a permiso de circulación. `RELEASE=NOT_APPROVED`.

**Tras la ejecución:** el director auditará SOLO los resultados reales M1B; actualizará este PR documental, contrato/ledger y el cursor. Después M1 continúa por ciudades/categorías; M2 motor/agente; M3 backend/Flutter; M4 integración CI/firma/QA físico. No hay necesidad de otro preflight general.


## N. M1B V2 entregado: acta del director y siguiente gate M1C (2026-11-07)

- M1B finalizó `PARTIAL`, `G0=PASS`: 8 jurisdicciones, 15 candidatas, 4 fuentes nuevas, 9 aperturas, 6 evidencias reutilizadas; 1096 sin investigación esta ejecución; 93 fuentes y 1104 DIVIPOLA preservados. ZIP SHA-256 `a7efa9a40bb2a273b2bd474e8166c5cae87ad297d85f51617897726464ecf991`. Ningún cambio runtime ni release.
- Director comprobó campos núcleo oficiales de **ocho combinaciones** (Medellín 2, Bogotá 1, Cartagena 2, Dosquebradas 2, Villavicencio 1), sin aprobar publicación. Faltan excepciones/áreas y pruebas/representación; los otros siete casos permanecen parciales. **0 FULL no es 0 medidas oficiales.**
- Error: la rotación II-2026 Medellín (lun 5/8 mar 1/4 mié 0/2 jue 3/6 vie 7/9) estaba publicada; M1B la dejó UNKNOWN. El FAQ inferior de la página incluye contenido histórico 2022. No extender `staleAfter=2026-11-10T05:00Z` sin decisión y pruebas focales.
- Registros de continuidad `SRC-17..19`: sobrecriterio FULL, timestamps de fuentes reutilizadas, doble estado de cola. Acta única `docs/plans/PICORADAR_M1B_DIRECTOR_ACTA_POSTRUN_20261107.md`.
- **Siguiente ejecución real:** M1C focal compara 8 núcleos con generador/motor en clon aislado, no reabre M1B, M1A ni AOT, no toca 101 WIP originales, no escribe GitHub, no publica. ZIP de entrada `PICORADAR_M1C_DIRECCION_Y_ENTRADA_UNICA_20261107.zip` SHA `f11c62efbac1913743ef17f66d1fa6cef0566cc914d94cdf2cce5f2548efd19a` contiene prompt Codex y ZIP M1B original con manifiesto. Tras M1C seguir cobertura nacional pendiente, agente, Laravel y QA/release según fases existentes. PR #79 documental Draft.


## O. Auditoría pre-ejecución M1C V2 y orden vigente (2026-11-07)

**Estado:** M1C V1 propuesta y NO acreditada como ejecutada; M1C V2 es corrección del **mismo TASK_ID** `PICORADAR-M1C-CORE-RULES-FOCAL-20261107-DIRECTOR`, sin abrir fase nueva. Si Codex ya ejecuta M1C V1 con G0 PASS, **no interrumpir ni duplicar**: auditar lo que entregue. Documento canónico de orden en esta rama: `docs/plans/CODEX_LUNA_PICORADAR_M1C_V2_ORDEN_20261107.md`; auditoría de 10 pasadas `docs/plans/PICORADAR_M1C_V2_AUDITORIA_10_PASADAS_20261107.md`.

**ZIP único de entrada disponible al propietario:** `PICORADAR_M1C_V2_ORDEN_AUDITADA_Y_EVIDENCIAS_UNICAS_20261107.zip`, SHA-256 `abe58119728c245068ee376fb992826c7f07b020e5cf53dce00833ae8741b409`, 7 miembros de contenido y 2 manifiestos, CRC/SHA verificados. Prompt interno SHA-256 `16563e2e5a96332c2b4e3f0f58af8b0be5142b0bd22f44f58e597b57ba8def45`. Contiene matriz 15 sin alterar, auditoría, fuentes oficiales, recovery, ZIP M1B V2 original SHA `a7efa9a40bb2a273b2bd474e8166c5cae87ad297d85f51617897726464ecf991` y ZIP R21 V2 original SHA `ffc3355569156f170e80ea7df4a886edef5afb351b097c179fada7fe3763e791`. El archivo debe adjuntarse **físicamente** a Codex; una ruta local `sandbox:` no se asume visible allí.

**Error estructural corregido:** R21 documentó `scripts/compile_pico_operational_catalog.py` como productor del catálogo desde **Excel fuente + `restrictions_v1.json` runtime**. No es productor de `restrictions_v1.json`; tampoco se conoce writer reproducible de este último. M1C V2 prohíbe edición manual del runtime y crear un escritor nuevo sin decisión previa. Si hay discrepancia, se registra `BLOCKED_RUNTIME_WRITER_NOT_FOUND` por fila; no parchear por el simple hecho de existir una regla editorial. Segundo riesgo: sparse checkout no muestra todo `scripts/` y `data/`; usar `git ls-tree`/`git show` antes de declarar archivos inexistentes, sin tocar script de Hostinger.

**Ocho filas del piloto:** Medellín auto/moto, Bogotá auto, Cartagena auto/moto, Dosquebradas auto/moto, Villavicencio auto. En el inventario director 15 candidatas, 8 núcleo y 7 incompletas, **todas con runtime_publish_allowed=NO**. La norma principal publicada no autoriza mensaje `puede circular` si faltan ámbito, festivos, excepciones o vigencia. G1 compara motor/IDs reales; G2 solo cambia con writer auténtico y test focal; G3 prueba solo delta; G4 devuelve un ZIP. No repetir R18–R21/M1B ni QA física/CI en este lote.

**Plan de finalización preservado:** M1C es piloto técnico de ocho filas, **no** cobertura nacional; 1.096 municipios permanecían sin investigar en M1B. Continuar M1 por fuentes y categorías restantes, M2 agente lector/motor, M3 Laravel–Flutter/cámaras/registro opcional, M4 CI+revisión de 101 WIP+JNI/QA física+firma+aprobación humana. Contratos AGENTS/baselines/leyes mantienen precedencia. PR #79 solo documentos, PR #71 y `main` intactos, `RELEASE=NOT_APPROVED`.

## P. Checkpoint forense post-recovery M1C V2 — contraste remoto, sin ejecución (2026-11-07)

**Este apartado es un DELTA de continuidad; NO modifica M0–M4 ni reemplaza la orden M1C V2 de O.** `TASK_ID=PICORADAR-M1C-CORE-RULES-FOCAL-20261107-DIRECTOR` sigue vigente. Aquí no se recibió ZIP de resultado M1C. Si Codex inició G0 PASS, no interrumpir; si terminó, ChatGPT audita su ZIP; si no ha iniciado, necesita el ZIP V2 original (SHA-256 reportado, no medido aquí: `abe58119728c245068ee376fb992826c7f07b020e5cf53dce00833ae8741b409`). NO relanzar M1B ni M1C V1/V3 ni sustituir R21/M1B binarios por Markdown.

**Evidencia GitHub anterior a este cambio documental:** PR79 HEAD `237224cd4d92f9b35376031b4938cab3076cc196` OPEN/DRAFT, PR71 HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` OPEN/DRAFT; nueve paths `docs/` en PR79. Compilador remoto PR71 `scripts/compile_pico_operational_catalog.py`, blob `1d2c23a5965d688930e5670549863a9d8d2f1aff`, NO contiene referencia a `restrictions_v1.json`; genera `pico_jurisdiction_catalog_v1.json` y auditorías. R21 reporta una relación distinta en clon local posterior. Primero comparar SHA/árbol local H4 y consumidores con `git ls-tree`/`git show`, no atribuir error ni fabricar writer por esta diferencia.

**Runtime remoto antiguo PR71:** `mobile/assets/datasets/restrictions/restrictions_v1.json`, blob `e6c73db1aba58ce6117a49789c12de8d03ceed85`, siete jurisdicciones; Medellín auto/moto y Villavicencio auto preservan dígitos/horarios principales pero tienen `staleAfter=2026-09-23T05:00:00Z`; Bogotá particular finaliza septiembre 2026; Cartagena y Dosquebradas no constan en ese JSON antiguo. No extrapolar esto a commits locales R14–R21: se deben comprobar sus propios SHA. El `staleAfter=2026-11-10T05:00:00Z` local es solo reportado en informes. No extender TTL a mano ni declarar 'puede circular' con ámbito incompleto.

**CI / WIP:** PR71 tenía cinco checks `failure` (Flutter, PHP 8.3/8.4/8.5 y MariaDB), 2026-10-21; logs no recuperables en esta consulta, causa no atribuible con certeza a billing ni a código. PR79 HEAD anterior sin checks asociados ≠ PASS. H4 SHA local reportado `1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c` no se resolvió en GitHub (422), lo cual NO demuestra ausencia local ni daño de 101 WIP.

**Legal y seguridad:** fuentes oficiales específicas Medellín II-2026 y atlas de vías exentas (Decreto 1490/2026), Bogotá noviembre 2026 y Cartagena octubre 2026–enero 2027 corroboran núcleos, no todos los ámbitos, exenciones ni autorización de publicación. Las DOCX baseline y leyes instaladas en Windows deben leerse realmente antes de editar comportamiento; AGENTS/leyes no se reemplazan.

**Salida única:** M1C V2 genera 8 filas de inventario, 0–8 comparadas realmente con SHA, `MEDELLIN_TTL_DECISION.md`, diez controles focales y **un ZIP resultado** con CRC/manifiesto/SHA, sin ADB, Hostinger, CI nueva, push, merge ni originales. Si falta ZIP de entrada: `INPUT_ATTACHMENT_REQUIRED` indica precondición de transferencia por el usuario, no permiso para otro preflight. ChatGPT decide luego el delta. M1 nacional → M2 pipeline/agente lector → M3 Laravel+Flutter/cámaras/cuentas opcionales → M4 CI/QA Android/firma/GO humano. `RELEASE=NOT_APPROVED`. Este cambio es solo documental, NO toca AGENTS, código, datasets, PR71 ni main.

## Q. Acta de auditoría M1C V2 y decisión M1D (2026-11-07 21:23 COT)

**Recepción independiente:** ZIP M1C `PICORADAR_M1C_RESULTADO_EVIDENCIAS_UNICAS_20261107.zip` de 10.968 bytes, SHA-256 `f04521c240b4315fa036c797eb6c8abb70bd4ee79f60add88eb17eccaaa2e3dd`; integridad ZIP CRC PASS, 7 payload SHA/bytes/CRC PASS, `MANIFEST.sha256` PASS. Su procedencia interna H4 y la ejecución de tests NO se certifican independientemente: JSON runtime de H4 (SHA reportado `ce95abacc2968bc4267d3edaef6bf9320dba1d99d40daf56b6c7e7cc46e38341`) no está anidado en el ZIP y H4 no es commit del PR71 remoto.

**Resultado aceptado como diagnóstico PARTIAL:** 8/8 filas comparadas sobre H4 según evidencias Codex: tres `ALREADY_MATCHES` *solo núcleo* (Medellín auto/moto, Cartagena moto), tres `BLOCKED_RUNTIME_WRITER_NOT_FOUND` (Bogotá auto noviembre, Dosquebradas auto/moto), dos `BLOCKED_SCOPE_OR_SOURCE` (Cartagena auto, Villavicencio auto). CHANGED=0, tests NOT_RUN, WIP 101 hashes NOT_VERIFIED; no afirmar pruebas PASS ni lista de ciudades lista para publicación. Original M1C cerrado, NO repetir M1B/M1C/R21.

**Corrección de diagnóstico / fuente de escritura:** `server/app/Services/RestrictionPublicationService.php` (PR71 blob `1fb78bd792871345f2a1e813f5bcf0246888f859`) fusiona versiones validadas; `RestrictionPayloadEncoder.php` (blob `bc929abc471261b4758607712471c16f933672c2`) codifica; `DatasetPublisher.php` (blob `3ba83febca01bab546b1e6260b720288ae4671f2`) publica asset versionado y manifiesto con SHA. El contrato `docs/agents/PICORADAR_SOURCE_AGENT_OPERATING_CONTRACT_V1.md` reserva expresamente a **Laravel** la aprobación/generación/publicación/rollback. Conclusión: **no hay writer comprobado del archivo estático H4**, pero **sí existe publicador de dataset Laravel**; prohibido concluir que no existe generación en todo el sistema. No crear writer Python independiente ni editar a mano `mobile/assets/datasets/restrictions/restrictions_v1.json`.

**Contraste externo jurídico focal, fuentes oficiales consultadas 2026-11-07:** Medellín II-2026 página de movilidad confirma rotación y vías exentas; Bogotá portal oficial 2026-11 confirma 06–21 y que dígitos que CIRCULAN en fechas impar/par deben invertirse para restricción, con regional festivo separado; Dosquebradas boletín 2026-09-26 confirma primer/último dígito y 06–20, sin fecha legal de fin, y no demuestra refresco de `nextReviewAt`; Cartagena anuncia 24h **a partir de 2026-12-11**, y su desmentido de junio se refería a la temporada de mitad de año (no valida la entrada futura ni la invalida automáticamente); Villavicencio Decreto 015/2026 dice mantener polígono 2025 pero sin coordenadas/segmentos auditados. Evitar `ALLOWED` ante perímetros/excepciones desconocidos.

**Siguiente lote único `PICORADAR-M1D-LARAVEL-PUBLISHER-CANDIDATE-KISS-20261107-DIRECTOR`:** Codex ejecuta en clon aislado H4 el flujo existente de Laravel (versiones validadas → payload canónico → asset versionado/manifest), identifica contrato de entrada a Flutter y prueba localmente un candidato **NO PUBLICADO** para Bogotá noviembre, basado en fuente oficial; cualquier adaptador imprescindible se incorpora dentro de Laravel, sin otra autoridad de publicación, sin nuevas dependencias ni schemas ni microservicios. Si local B07 ya cubre el flujo, `NO_CODE_NEEDED`; si falta solo puente de exportación, implementar **un único adaptador mínimo** bajo contrato existente, con pruebas RED/GREEN, `Storage::fake` y SQLite temporal. No tocar prod/Hostinger/cuenta real/móvil ni reescribir JSON estático manualmente. Mantener Dosquebradas y Medellín stale cuando caduquen; no extender TTL sin política y evidencia. Cartagena 24h y Villavicencio polígono quedan en investigación focal separada. **Un solo ZIP de salida** con manifiesto, pruebas efectivamente ejecutadas y patch si hubo delta; sin push, merge ni PR de código.

**Ruta al cierre intacta:** M1 continuar descubrimiento nacional por autoridad (1096 municipios no buscados M1B y siete filas sin núcleo); M2 aprovechar único pipeline Laravel/agente lector solo propone; M3 descarga/consumo Flutter y cámaras/cuenta opcional; M4 CI real, 101 WIP, QA físico Android/JNI/firma y GO humano. No crear V3 de M1C ni renovar el estado por calendario. PR79 documental Draft, PR71/main intactos, `RELEASE=NOT_APPROVED`.

## R. Gate director previo a M1D V2 — diez controles sin duplicar ejecución (2026-11-07)

**Orden canónica nueva, mismo TASK_ID anterior:** `docs/plans/CODEX_LUNA_PICORADAR_M1D_V2_ORDEN_20261107.md`; **auditoría de diez pasadas:** `docs/plans/PICORADAR_M1D_V2_AUDITORIA_DIRECTOR_10_PASADAS_20261107.md`. M1D V2 solo sustituye el Markdown M1D V1 **si Codex aún no inició G0**. Si M1D V1 comenzó o terminó, NO interrumpir/reiniciar: entregar su ZIP y auditar delta. Cierre M1C PARTIAL de Q se conserva; nada de M1B/M1C V3.

**Motivo de corrección real (no cambio de requisitos):** (1) el contrato del agente apuntaba a M1B como propuesta activa, puntero ahora corregido sin alterar semántica de autorización; (2) Bogotá 02/16-Nov son festivos con pico regional de ingreso **separado** y NO debe aplicarse por omisión una regla urbana ordinaria lunes de paridad; pruebas contra falso rojo urbano y falso verde regional exigidas; (3) `RestrictionPublicationService` Laravel existente puede pasar de validación a publicación real, así que M1D debe probar primero con `Storage::fake`/SQLite y **no invocarlo contra disco/base reales**; adapter dentro de Laravel solo última alternativa demostrada con prueba, no crear otro publicador ni sync Flutter M3 anticipada.

**Preservación y alcance:** PR71/main, 101 WIP, baselines/AGENTS/PingPongLaw, código, activos y producción sin cambios. Este lote no vuelve a probar M1C, no modifica `restrictions_v1.json`, no modifica TTL Medellín que según H4 reportado vence 2026-11-10 00:00 COT. El motor debe permanecer fail-closed en `UNKNOWN/STALE`; caducidad técnica ≠ fin legal. Cartagena 24h diciembre (todas las vías distritales según fuente oficial) y Villavicencio polígono quedan fuera de M1D y en cola focal de M1/M2. PR79 sigue Draft `RELEASE=NOT_APPROVED`.

**Criterios próximos de salida:** candidato Bogotá noviembre con ámbito jurídicamente limitado y asset Laravel **solo temporal**, pruebas reales con comandos y exit codes, ruta de consumo Flutter demostrada o `FLUTTER_SYNC_GAP`, un único ZIP con SHA256/CRC/manifiesto, sin publicación. Falta de H4/dependencias → resultado PARTIAL causal en el mismo ZIP, no nuevo pingpong. Continúa M1 nacional → M2 → M3 Laravel–Flutter/cámaras/cuenta opcional → M4 CI/QA físico/firma/GO humano; NO alterar fases M0–M4.

**Digest documental GitHub y copia descargable exacta:** prompt blob `116cce800cec10a73cd3b991088adb8f4c94a8c0`, SHA256 `a962bda8d1677f3020e50ed70625f9917b7308bea6480fb53a7d4e406570d03c`; auditoría blob `4c51571fca20dcefe525aacfb239069e7a05c55b`, SHA256 `d750c112bf6da84ca8bbec819e7ae9e4f23885e9ffd5d09c5d13f0e4e6c36291`. Solo Markdown de continuidad; siguiente actor Codex Luna condicional, luego ChatGPT.
