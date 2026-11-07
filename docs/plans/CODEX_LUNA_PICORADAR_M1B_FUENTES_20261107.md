# CODEX LUNA — PicoRadar M1B · INVESTIGACIÓN OFICIAL NACIONAL / EVIDENCIA REUTILIZABLE / UN SOLO ZIP

**TASK_ID:** `PICORADAR-M1B-REAL-SOURCE-RESEARCH-20261107-DIRECTOR`  
**Orden creada:** 2026-11-07. **Director y responsable de arquitectura/criterios:** ChatGPT. **Ejecutor limitado:** Codex Luna.  
**Estado conocido:** `M1A_PARTIAL`, `M1A_G0_G2_RECOVERED_BY_DIRECTOR`, `RELEASE=NOT_APPROVED`.  
**Objetivo:** convertir la cola de 1.104 municipios y la semilla de 93 fuentes en una **primera investigación oficial nacional verificable**, comenzando por medidas realmente publicadas, NO reauditar M1A, regenerar DIVIPOLA, cambiar código o publicar restricciones. Un lote de investigación; entregar **un ZIP único** listo para adjuntar al director.

## 0. Contrato no negociable de entrega

1. Recibir y **extraer físicamente** el ZIP adjunto `PICORADAR_M1A_CIERRE_Y_M1B_INSUMOS_UNICOS_20261107.zip`. Un enlace en Markdown a una ruta `D:\...` NO entrega sus bytes; si faltan, marcar `G0=INPUT_NOT_AVAILABLE` y finalizar sin inventar datos. Ejecutar el archivo `CODEX_LUNA_PICORADAR_M1B_INVESTIGACION_OFICIAL_NACIONAL_20261107.md` de este ZIP, no órdenes antiguas M1A V1/V2. Evitar adivinar nombres de archivos.
2. Respuesta final **solo un enlace** al ZIP `PICORADAR_M1B_EVIDENCIAS_UNICAS_20261107.zip`, con SHA-256, valor `M1B_RESULT`, `RELEASE=NOT_APPROVED`, `NEXT_ACTOR=CHATGPT`. No pedirle al usuario que junte CSV/JSON sueltos; **todos los artefactos obligatorios van dentro del único ZIP**. `MANIFEST.json` con tamaño y SHA-256 de cada entrada; `MANIFEST.sha256` de bytes del manifiesto; `ZipFile.testzip()==None`, reabrir ZIP y verificar hashes antes de entregar.
3. No modificar ni publicar `main`, PR #71, PR #79, otros PR, GitHub Actions, Hostinger, EPM, datos de producción, APK, ADB o teléfono Mi A3. No hacer commits, push ni merge. Esta orden es investigación y creación de artefactos de salida aislados, no un desarrollo de runtime.
4. No editar, restaurar, copiar encima, normalizar, tocar ACL ni borrar archivos del WIP protegido; no intentar reparar `scripts/tests/test_hostinger_installer_browser.ps1`. Cero cambios de código, dependencias o esquemas. Las salidas deben estar **fuera** de los repositorios, en carpeta nueva para M1B.
5. Respetar `AGENTS.md`, las dos baselines `.docx`, `docs/CURRENT.md`, `docs/SOP.md`, `docs/DESIGN_CONTRACT.md` y `LEYES_IMPLEMENTACION_1_A_6.md` en su ubicación local existente (verificar ruta/sha de evidencia R21, no asumir). Leyes: dirección externa, KISS/Ponytail, cero ruido, sin parches, preservar decisiones previas, nunca convertir prueba sintética en aceptación física. Si hay conflicto explícito, STOP la operación afectada y registrar por qué.
6. Prohibido repetir Gradle, Flutter tests, AOT, JNI, AVD, Laravel completo, QA de R18–R21 o revalidar los 1.104 códigos DIVIPOLA ya aprobados focalmente; se permiten controles incrementales de salida M1B. `R18_AOT=PASS histórico limitado`, `R19_H4=PASS focal`, `G0/G2_RECOVERY=PASS offline` no cambian por investigación M1B.

## 1. Insumos y SHA fuente que debes reconocer (NO RECONSTRUIR)

**Fuente:** ZIP único de dirección que acompaña esta orden. Debe traer estos insumos (algunos vienen de los dos paquetes originales y otros del cruce del director):

- `M1_INTEGRATED_UNIVERSE_1104.csv`: DANE/MGN 2025 del repo, 1.104 únicos; campos adicionales `seed_73_member` con 73 YES y 1.031 NO; referencia `repository_mapping_member` y estado real de investigación M1A conservados.
- `M1_INTEGRATED_DISCOVERY_QUEUE_1104.csv`: 1.104 filas; `NOT_SEARCHED` no implica que no exista la medida; Medellín y Cartagena son los dos investigados M1A, **parcialmente**, no reglas aprobadas.
- `M1A_SOURCE_REGISTRY_93.csv`: 93 URLs / IDs de fuente, todas `allowed_for_runtime=NO` en la semilla. No sobrescribir el registro original ni cambiar su estado a verificado sin nueva evidencia.
- `M1A_TERRITORY_SOURCE_RELATIONS_174.csv`: 174 pares únicos; URLs con varios municipios no prueban competencia/alcance. Una autoridad puede publicar una medida supramunicipal, pero debes demostrar el territorio explícito antes de aplicarla a cada municipio.
- `M1A_SOURCE_HISTORY_179.csv`: 179 registros históricos; cinco pares con observaciones duplicadas, **preservarlos**.
- `M1_INPUT_COBERTURA_219_HISTORICA.csv`: 219 clases municipio–vehículo históricas, no 219 reglas operativas. Prioridad de corte R13: 17 P1, 48 P2, 154 P3.
- `M1_INPUT_MUNICIPIOS_73_SEMILLA.csv`: 73 localidades, 61 con alguna URL histórica y 12 sin URL histórica; conciliar por DIVIPOLA.
- `M1_DUPLICATE_HISTORY_PAIRS_5.csv`: detalle de duplicados que no debes eliminar.
- `M1A_DIRECTOR_RECONCILIATION.json`, `AUDITORIA_M1A_DIRECTOR_10_PASADAS.md` y `PLAN_CIERRE_V2_2_POST_M1A.md`: puertas y límites ya resueltos.
- `R21_WIP_101_EXPECTED_HASHES.csv` si se incluye: lista de 101 archivos de la evidencia R21 para cotejo READ-ONLY, NO lista de archivos a restaurar.

**Hash de referencia del ZIP original M1A V2:** `e8191f717df2288ed2ed1d5775081ee239839dbc9ebb011b5bf8d433b64d4173`; **ZIP ejecutado M1A:** `cb99385e8c365a923f9013aa2b793207a684fa5233a41baed1a206ecbd88109b`. Ninguno debe reconstruirse. El ZIP de esta orden se verificaría por su SHA-256 publicado en el mensaje de dirección, no por una ruta inventada.

## 2. G0 — Una validación de insumos que prevenga el mismo bloqueo

A. Extraer ZIP en carpeta de trabajo nueva. Verificar **una vez** CRC, `MANIFEST.json` y hashes de todos los miembros. Contar 1.104/1.104 fila-cola, 73/73, 219, 93, 174, 179, cinco duplicados. Revisar tipos y claves; rechazar CSV con fórmulas insertadas o filas que violen llave. No reescribir los datos históricos.
B. Si falta *una* tabla requerida, no inventarla, no reconstruirla buscando páginas, no etiquetar R21 como roto. Reportar faltante y terminar ese gate con `BLOCKED_INPUT`, pero continuar si existe otra tarea absolutamente independiente. Una segunda búsqueda de rutas es innecesaria.
C. Entregar tabla única `M1B_GATE_EVIDENCE.csv` con cada control, huella de archivo, resultado, evidencia y límite; los checks que venían PASS solo se citan por hash, no se ejecutan otra vez.
D. Escribir en informe `G0_SOURCE_TABLES_REUSABLE=YES` solo si todos los archivos están presentes y congruentes. Jamás `G3_COMPLETE` por el mero hecho de tener 1.104 municipios.

## 3. G1 — Prioridad jurídica P0: Medellín 10 de noviembre

Investigar **primero** fuente oficial vigente de Medellín para la rotación II-2026. `staleAfter=2026-11-10T05:00Z` representa vencimiento técnico editorial, **no** que la alcaldía haya terminado la medida ese día. Obtener a partir de páginas de Alcaldía / Secretaría de Movilidad qué clases, dígitos, horario, excepciones, perímetro, días hábiles, fecha de inicio y fin estén expresamente respaldados. Si la página no incluye todos, buscar fuente oficial secundaria. Guardar URL específica y fecha/hora de consulta, título, tipo (comunicado/calendario/decreto), estado HTTP, **hash del contenido recuperado cuando sea posible** y campos conocidos/desconocidos. No necesitas decreto si el calendario/comunicado de autoridad tiene los campos requeridos y no contradice otro acto conocido.

Entregar `M1B_MEDELLIN_P0_EVIDENCE.json` con `proposed_source_verified`, `data_validity` y `technical_refresh_decision` separados: `SUGGEST_KEEP_STALE`, `SUGGEST_REFRESH_AFTER_FOCAL_TEST` o `NEEDS_LEGAL_CLARIFICATION`, con justificación. Nunca editar `mobile` ni extender TTL automáticamente. Incluir casos propuestos antes/durante/después del 10 de noviembre para un futuro lote de código. **Si no se puede probar el fin/ámbito/exención:** `PARTIAL` y conservar fail-closed, sin inventar permiso.

## 4. G2 — Investigación nacional oficial sin sondeos interminables

### 4.1 Orden de búsqueda (determinista, registro completo)

1. Medellín P0 de G1 (no duplicarlo en este gate), Cartagena (dígitos/taxi 2026, festivos, franja 06:00–06:00 si la fuente exacta lo soporta).
2. Las **ocho ciudades P1 del CSV**: Bogotá, Bucaramanga, Cartagena, Dosquebradas, Medellín, Pereira, Popayán y Villavicencio. No busques de nuevo un P1 ya resuelto en este mismo lote.
3. Los **20 enlaces previamente clasificados `PARTIAL_OFFICIAL_PAGE_CHECK_ONLY`**, priorizando dominio gubernamental con publicación más reciente. Revisar específicamente qué campo de regla falta, no empezar la investigación desde cero.
4. La semilla de 73 municipios: primero los 61 con URL histórica, luego los 12 sin URL histórica; priorizar por 17 pares P1 y 48 P2. Buscar portales oficiales de alcaldías, secretarías o institutos de tránsito cuando la URL antigua esté vencida.
5. En el universo de 1.031 fuera de semilla, crear **prioridad documental para búsqueda posterior**: no afirmar ausencia de restricción. Puedes descubrir hasta 33 páginas de autoridad departamental cuando resulten útiles, sin equipararlas a reglas locales ni inventar municipios nuevos.

### 4.2 Presupuesto y criterios de avance

- Primera pasada: clasificar **las 93 URLs existentes** por dominio, titular aparente, última evidencia y probable estado (gov oficial / portal autoridad / red social / fuente secundaria / inaccesible). Esta clasificación local no requiere navegar las 93 si el dominio y la información histórica bastan, pero no equivale a verificar contenido vigente.
- Para verificaciones remotas: examinar hasta **100 páginas documentales distintas por ejecución** (no 100 búsquedas repetidas de una misma URL), y hasta **30 nuevas URLs oficiales** descubiertas para las 73 localidades si faltan fuentes. Si las conexiones fallan sistemáticamente, detener llamadas remotas tras **5 fallos independientes** y registrar `NETWORK_RESEARCH_BLOCKED`, preservando hallazgos previos. No bypass CAPTCHA/403, no fuentes privadas ni redes con acceso indebido.
- Si el presupuesto se agota antes de terminar 73 municipios, dejar una **cola única** clasificada con `REVIEW_BUDGET_PENDING`, fuente previa conocida, prioridad y `next_query`, sin recircular la misma revisión.
- Solo evidencias primarias: alcaldías, secretarías/direcciones de tránsito municipales, distrito, autoridad metropolitana legalmente competente o emisora de medida; ministerio nacional como contexto, no sustituto de medidas municipales. Notas de prensa secundaria se conservan como pistas, no como certificación. Página con fecha 2023 no prueba rotación 2026.

### 4.3 Extracción de campos obligatorios

Guardar **una fila por municipio y clase de vehículo / regla diferenciada**: código DIVIPOLA; autoridad y competencia; URL canónica y URL exacta consultada; fecha publicación, `checked_at` con zona `America/Bogota`; fecha inicio y fin o vigencia no especificada; días; horario local, incluidos cruces de medianoche; último/primer dígito y números; categoría particular/moto/taxi/público según acto; perímetro/corredores; excepciones festivos; evidencia textual breve sin reproducción extensa; conflicto o ambigüedad; estado `FULL_OFFICIAL_RULE_CANDIDATE`, `OFFICIAL_PARTIAL`, `OFFICIAL_NO_MEASURE` (solo si lo dice inequívocamente autoridad vigente), `LEGACY_CANDIDATE`, `UNREACHABLE`, `CONFLICT`, `NOT_SEARCHED`; hash de bytes de página cuando realmente se capturan; `activation=false`.

**Regla jurídica central del director:** comunicado o calendario oficial completo con fecha de publicación es suficiente para propuesta de actualización si cubre los campos materiales y no hay contradicción. No exigir siempre decreto. Si alguna excepción, vigencia o territorio sigue sin resolverse, escribir `UNKNOWN_FIELD` y evitar comportamiento permitir circular por defecto. Evitar extrapolar desde Medellín hacia Bello, desde Atlántico hacia 20 localidades, o desde Cartagena a municipios vecinos.

## 5. G3 — Calidad focal, no falsas aprobaciones

Generar tres matrices como mínimo:

- `M1B_SOURCE_REVIEW_93.csv`: exactamente 93 ID originales; estado local y remoto verificable, no sobrescribir el histórico. Una fuente puede aportar varias medidas, pero el link no certifica todas ellas. Si se descubren URLs nuevas, crear `M1B_NEW_OFFICIAL_SOURCES.csv` con ID estable derivado de URL canónica (p. ej. prefijo `newsrc_` + 16 caracteres hex SHA-256), autoridad, dominio, fuente de descubrimiento, fecha, estado y SHA de captura si existe. Nunca asignar un `source_id` nuevo sin agregar su fila en esta tabla; evitar colisiones de IDs.
- `M1B_JURISDICTION_VEHICLE_CANDIDATES.csv`: filas únicamente para hallazgos con base concreta; ninguna fila ficticia para completar 219/1.104. Todos incluyen `source_id` referencial a los 93 IDs originales o a `M1B_NEW_OFFICIAL_SOURCES.csv`, municipio, clase, vigencia/horario, estado, prueba y dudas.
- `M1B_NATIONAL_DISCOVERY_QUEUE_1104.csv`: 1.104 filas con último estado **de esta investigación**, prioridad siguiente y referencia; mantener estados M1A de Medellín/Cartagena salvo nuevo resultado real, diferenciar histórico con observación nueva.

Controles focales: (1) llaves 93 únicas y 1.104 únicas; (2) referencias fuente/territorio completas; (3) cero registros huérfanos; (4) nunca `OFFICIAL_NO_MEASURE` por HTTP 404/403/no resultado; (5) no afirmar `FULL` con vigencia/ámbito incompletos; (6) fechas horarios y zona Bogotá correctamente representados, incluidas madrugadas y festivos si aplica; (7) fuente multi-municipal no promovida sin cobertura literal; (8) datos válidos conservados al regenerar por segunda vez; (9) cero cambios a datasets productivos/servidor/Flutter; (10) cifrado/PII, claves y límites revisados. Las diez comprobaciones deben tener PASS/PARTIAL/BLOCKED, evidencia y localización exacta.

**No hay obligación de que esta primera oleada valide todas las 1.104 localidades.** Sí hay obligación de contar de forma honesta `NOT_SEARCHED` y de producir un plan de revisión sistemático que no repita páginas innecesariamente. No inventar porcentaje de cobertura nacional.

## 6. G4 — Preservación WIP (read-only, desacoplado de la investigación)

El resumen de `git status` del WIP protegido de M1A (`68598761...`) difiere del preflight que Codex anotó (`ad7bb66f...`). R21 adjuntó 101 SHA individuales del checkpoint en `WIP_101_REVIEW.csv`. El director suministra una tabla focal `R21_WIP_101_EXPECTED_HASHES.csv` en el paquete cuando disponible. Si el checkout protegido sigue accesible, **solo calcular SHA256 de contenido de cada una de las 101 rutas (sin seguir symlink fuera del repo)** y comparar con `r21_wip_checkpoint_blob_sha256` del CSV suministrado; para rutas presentes en disco pero ausentes del index, tratar bytes como untracked según el estado previo. Guardar `M1B_WIP_CONTENT_DELTA.csv`: `MATCH`, `MISMATCH`, `MISSING`, `UNREADABLE`; incluye solo nombre y hashes, no contenido sensible. Si no hay acceso, `NOT_RUN`, no inferir `PASS`. Prohibido `git restore`, `checkout`, crear/editar archivos protegidos, cambios ACL, permisos o antivirus. **Este gate nunca impide investigación documental aislada, solo cualquier propuesta posterior de integración del WIP.**

## 7. G5 — Entrega en un único ZIP, manifiesto y salida binaria

Crear SOLO en carpeta de reportes fuera de repositorios, dentro de un ZIP final:

1. `FINAL_REPORT.md`: hechos, fecha, conteos, resultados, bloqueos, fuentes oficiales, decisiones y siguiente etapa.
2. `GATES.csv`: G0..G5 y diez comprobaciones focales, evidencia y resultado sin relleno.
3. `M1B_SOURCE_REVIEW_93.csv` y `M1B_JURISDICTION_VEHICLE_CANDIDATES.csv`.
4. `M1B_NATIONAL_DISCOVERY_QUEUE_1104.csv`.
5. `M1B_MEDELLIN_P0_EVIDENCE.json`.
6. `M1B_SOURCE_CAPTURE_INDEX.csv` con URLs, fecha/hora, HTTP, hash si capturado, bytes y localización de evidencia, sin guardar credenciales/tokens/PII.
7. `M1B_WIP_CONTENT_DELTA.csv` o `M1B_WIP_NOT_RUN.md`; `SOURCE_POSTFLIGHT.json` de rutas protegidas y candidato sin mutación.
8. `MANIFEST.json` y `MANIFEST.sha256`; no incluir 1.104 HTML crudos innecesarios ni ZIPs anidados gigantes; si hay capturas legítimas, comprimir solo extractos saneados con su hash y procedencia.

**Éxito razonable del lote** = las bases e insumos presentes, una investigación real oficial de la mayor cantidad posible de fuentes prioritarias dentro del presupuesto, evidencias reusables, cero activación, cola íntegra y conteos honestos; no `GO` del release. Tras empaquetar, abrir el ZIP, validar CRC y cada SHA. Responder solo:

```
TASK_ID=PICORADAR-M1B-REAL-SOURCE-RESEARCH-20261107-DIRECTOR
M1B_RESULT=COMPLETE|PARTIAL|BLOCKED
G0_INPUT=PASS|BLOCKED
OFFICIAL_FULL_RULE_CANDIDATES=<número real>
MUNICIPALITIES_INVESTIGATED_THIS_RUN=<número real>
NATIONAL_QUEUE=1104
WIP_CONTENT_INTEGRITY=PASS|PARTIAL|NOT_RUN
GITHUB_WRITES=NO
RELEASE=NOT_APPROVED
NEXT_ACTOR=CHATGPT
ZIP=un único enlace real
ZIP_SHA256=<hash real>
```

## 8. Prohibiciones de falso positivo y bucle

- No declarar `FULL_RULE` si no se evidencia clase de vehículo, horario, dígitos, alcance y vigencia suficiente. No inventar fechas de fin; expresiones como “hasta nueva rotación” deben documentarse como tales.
- No copiar una regla departamental a municipios vecinos sin acreditar competencia y perímetro literal. No convertir el 20/73 del inventario previo en 20/73 ciudades listas.
- No confundir `staleAfter` editorial con validez jurídica, ni una URL HTTP 200 con confirmación de regla vigente, ni un link gubernamental con autoría del acto concreto.
- No repetir R18/R19/R20/R21 ni M1A G0/G2; esos gates están reconocidos por hashes. Si no hay Internet para fuentes, entregar la clasificación local y marca de bloqueo tras fallos acotados, no cientos de llamadas repetitivas.
- No actualizar GitHub automáticamente; el director actualizará PR documental #79 con el acta auditada tras recibir tu único ZIP. No pedir autorización para decisiones rutinarias ya especificadas; ante conflicto legal/material STOP la conclusión afectada y registra `UNKNOWN`.

**FIN DE ORDEN — SIGUIENTE ACTOR AHORA: CODEX LUNA. DESPUÉS DE TU ZIP: CHATGPT DIRECTOR.**

**Precisión de tipología territorial:** de los 1.104 códigos del snapshot, 1.103 tienen `territory_type=MUNICIPIO` y uno (`88001`, San Andrés) `ISLA`. Conservar el campo original y no forzar tipología MUNICIPIO sobre la isla.