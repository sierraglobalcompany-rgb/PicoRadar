# CODEX LUNA — PICORADAR G2 — MOTOR NACIONAL DECLARATIVO TIPADO, COMPATIBILIDAD Y REGLAS SUPERPUESTAS

**TASK_ID:** `PICORADAR-G2-MOTOR-NACIONAL-TIPADO-20261110`  
**ORDEN:** UNA ejecución integral en clon aislado de D:, UN commit local final y UN ZIP autosuficiente. NO publicar datos jurídicos ni hacer deploy.  
**DIRECTOR:** ChatGPT. **EJECUTOR:** Codex Luna. No tomar decisiones de producto, no inventar normas o territorios, no reabrir R1/R2/G1.  
**RESULTADO EXIGIDO:** Nuevas familias de condiciones operativas en UN SOLO motor Flutter y UN contrato Laravel, preparadas para reglas configurables por datos y sin falsos ALLOWED. El lote termina con prueba Laravel→Flutter de los mismos bytes. No basta con generar tablas o reportes.  
**BASE EXACTA:** `G1_COMMIT=9b5911dc2f734f89fb265877a568e426fc4b0651`, padre `R2=88fc5d1307a80a9781f7b7e23e1912c3316c7531`, anterior `R1=da9d8083bb21bd7c9863a319e07de51a5e692d09`, base moderna `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` de PR #71. **NO partir de `main` histórico.**  
**FUENTE G1 ZIP SHA256:** `aa3b450a539334806703f2cff4e898b8398fbb688da5ea7687c298f3a2fc3f1d`; R2 JSON base SHA256 `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`.  
**ESTADO ACTUAL:** G1 `PASS_SCOPED_CORROBORATED`, código local; NO CI, NO APK, NO Android físico, NO publicación de reglas, NO garantía de que las 101 rutas WIP históricas estén montadas. El PR #79 es documentación Draft; código PR #71 abierto en Draft.  
**LEY CANÓNICA:** L1 KISS/Ponytail, L2 antirruido, L3 antiparches, L4 diseño aprobado, L5 QA independiente, L6 antiping-pong. Respetar `AGENTS.md`, `docs/CURRENT.md`, `docs/SOP.md`, `docs/baseline/*`, y reglas anidadas vigentes. Si contradicen esta orden, documentar y resolver por jerarquía; parar SOLO la acción insegura.

## 0. PUNTO DE CONTROL PREVIO — OBLIGATORIO, SIN PING-PONG

1. Localizar el candidato G1 existente en `D:\codex\_isolated\PicoRadar-G1-National-Data-First`, **leer** `git status --porcelain=v1`, `git rev-parse HEAD`, parent, tree y worktrees. Verificar SHA G1 exacto y que sea descendiente de R2/R1/PR71. Si falta, restaurar únicamente desde fuentes y ZIPs respaldados, SIN modificar los checkouts protegidos ni fingir equivalencia de hashes.
2. Verificar antes/después `D:\codex\PicoRadar`, `D:\Dev\PicoRadar` y los worktrees detectados, WIP y archivos borrados/renombrados, sin asumir que 101 rutas existen hoy. No usar `git clean`, `git reset --hard`, `git stash`, `git gc`, borrar temporales ajenos, tocar C: o force push.
3. Crear **antes del primer cambio** un **bundle Git autónomo de la cadena local R1→R2→G1** en zona de evidencia D:. Incluir la historia necesaria desde el ancestro que permita restauración sin recursos externos: no usar sólo un bundle incremental con prerequisitos ocultos. Verificar `git bundle verify` **y restaurarlo a un repositorio temporal vacío**, comprobando `cat-file -e` de PR71, R1, R2 y G1 y árbol G1 idéntico; nunca usar como prueba única el checkout que creó el bundle. Incluirlo dentro del ZIP final. Si volumen impide bundle autónomo, empaquetar los 3 parches acumulativos G1/R2/R1 y el SHA de cada preimagen y posimagen; etiquetar `RECOVERY_BUNDLE_BLOCKED`, NO afirmar restauración independiente completa.
4. Leer `mobile/lib/core/database/app_database.dart` (Drift v9, tabla `restriction_coverages`), `vehicle_profile.dart`, `restriction_engine.dart`, `restriction_rule.dart`, `restriction_dataset.dart`, `restriction_store.dart`, `restriction_day_evaluation.dart`, `city_restriction_summary.dart`, `server/app/Services/RestrictionContractValidator.php`, `RestrictionPublicationService.php`, `RestrictionImportService.php`, `DatasetReleaseValidator.php`, `DatasetPublisher.php`, manifest/sync Flutter, tests existentes. Auditar consumidores dinámicos y serialización antes de cambiar. No reeditar R1/R2/G1 salvo por incompatibilidad concreta probada.
5. **No hacer push/crear PR** si no es posible verificar por medios autorizados cuenta, permisos, coste y disparadores de CI. El bundle local del punto 3 es obligatorio para preservar la cadena; PR remoto es OPCIONAL solamente cuando todos los gates sean inequívocos y la política del proyecto lo permita. Nunca merge ni deploy. No bloquear cambios de código local por la falta de push.

## 1. CRITERIO DE DISEÑO CERRADO — SIN MOTOR SEGUNDO NI `eval`

El dataset de restricciones ya contiene una lista de `jurisdictions`, cada una con `coverages`, y cada coverage con múltiples `rules`. **Reutilizar esa estructura**; NO crear un dataset diferente por ciudad, ni nuevo backend de consulta por placa, ni microservicio, DSL ejecutable, parser JSON genérico recursivo, motor de plugins o tabla extra para cada tipo de restricción.

**G2 sólo amplía la representación de condiciones; no rediseña el sistema.** El motor actual ya soporta días de semana, dígitos primero/último, paridad, franjas ordinarias/cruce medianoche, festivos, orígenes, efecto/prioridad, validFrom/Until y stale. NO reimplementar estos predicados. La ventana vacía `timeWindows: []` ya significa el día calendario completo aplicable; `06:00→06:00` es una semántica distinta y NO se habilita por equiparar inicio/fin.

**Separar dimensiones:** clase física del vehículo ≠ servicio legal ≠ uso (pasajeros/carga/mixto). Taxi es modalidad de servicio y no equivale a todo el transporte público. Carga puede ser privada o pública y no equivale a `taxi`. Un mismo vehículo puede estar sujeto simultáneamente a más de un régimen. No inferir peso/ejes/ocupantes/parrillero, permiso, ubicación o sexo desde la placa.

**Contrato explícito opt-in V2:** el esquema `restrictions.schemaVersion=1` y los datasets/instalaciones actuales no cambian de significado. Agregar V2 para condiciones nuevas, sin promoverlo a CDN/prod. NO insertar campos V2 silenciosamente en schema1: el parser antiguo los ignoraría y podría informar ALLOWED. V2 debe ser rechazado por cliente V1 con conservación de last-good; cliente nuevo puede leer V1 y V2 en laboratorio. Mantener manifest SHA/publicationRevision y verificar minAppVersion/rollback. No cambiar versiones prod. **Decisión cerrada de persistencia:** introducir UNA columna `coverageCompleteness` en `restriction_coverages` con los valores estrictos `legacy | complete | partial`, y UNA migración Drift v9→v10 (con pruebas desde v8 y v9) + generación reproducible. `legacy` se asigna exclusivamente al schema1 y preserva su conducta original sin certificación nueva; schema2 REQUIERE explícitamente `complete` o `partial`, nunca default implícito. `partial` obliga UNKNOWN cuando no hay restricción concluyente. No usar un campo escondido dentro de `rulesJson` para este estado del coverage, no crear nueva tabla ni migrar perfiles/documentos. Testear que la migración conserva las 12 coberturas y los datos privados. No reinterpretar cobertura V1 como universalmente certificada.

### 1.1 Tipos nuevos EXACTOS de condición (un catálogo pequeño, estático)

Agregar a reglas V2 un arreglo opcional **`conditions`** de objetos `{ "type": ..., "value": ... }` con los tipos cerrados siguientes; todos combinados por **AND**, y múltiples reglas representan **OR**, sin operadores arbitrarios. Los nombres exactos se mantienen para Flutter y Laravel:

- `pillion_present`: `value` boolean, verdadero si la motocicleta lleva acompañante. Sin dato explícito → `UNKNOWN`; nunca inferir sexo/género/apariencia o permiso.
- `occupants_at_least`: `value` entero **1–99**; número total de ocupantes incluido conductor, dato explícito. Ausencia → `UNKNOWN` cuando la regla puede afectar al vehículo.
- `gross_weight_kg_gt`: `value` entero en **0–100000**; comparar el **peso bruto vehicular declarado/homologado** del vehículo, NO carga transportada en este viaje; ausencia → `UNKNOWN`.
- `axles_at_least`: `value` entero en **1–20**; exige cantidad de ejes; ausencia → `UNKNOWN`.
- `inside_scope_ref`: `value` string no vacío (ID geográfico/área versionado), evaluar por un **hecho espacial verificado** proporcionado a `RestrictionContext` (`inside`, `outside`, `unknown`) para el MISMO ID. No afirmar `inside` a partir de un centroide de municipio; si falta polígono/corredor/ubicación comprobable → `UNKNOWN`. NO calcular point-in-polygon en G2: ese es G3.

**No agregar `sex` o `gender` del acompañante ni captura biométrica.** Una condición legal explícita futura de esa naturaleza necesitará una decisión privada y un campo opcional separado con consentimiento; no implementarla por especulación. NO implementar `vehicle_age_years` deduciendo año de modelo; el Decreto 652 distingue años de servicio y modelo/repotenciación según caso: registrar esa brecha para G3, no suponer equivalencia.

### 1.2 Contexto y clasificación

Mantener campos actuales de `RestrictionContext` y agregar **un único objeto de hechos tipados opcionales** para esas condiciones (pillion/occupants/grossVehicleWeightKg/axleCount/verifiedSpatialMembershipByScopeId). No crear cinco `Map<String,dynamic>` dispersos ni guardar GPS en backend. Los datos ausentes se representan con `null`/UNKNOWN, nunca `false`, 0 o `outside`. Las pruebas deben poder suministrarlos directamente sin UI nueva; G2 NO autoriza modificar Garaje o Viaje.

Para identificar vehículos, reutilizar `VehicleKind`/`VehicleServiceType` existentes y agregar únicamente valores concretos que permitan ensayar clases adicionales sin reinterpretar datos previos:
- `VehicleKind`: preservar `car`/`motorcycle`; agregar `truck`, `bus`, `motocarro`.
- `VehicleServiceType`: preservar `private`/`taxi`; agregar `public_passenger`, `special`, `public_cargo`.
- `vehicleUse` como hecho tipado opcional `passenger`/`cargo`/`mixed` cuando necesario; **no usar `serviceType=cargo` como sustituto de uso**, porque existe carga privada. Si la implementación de `vehicleUse` no es necesaria para las condiciones focales, mantenerlo como campo contextual documentado, sin crear lógica especulativa.

No habilitar selectores nuevos en Garaje sin flujo UX autorizado. En G2 la aceptación es **motor/parsers/contrato reales**, no una pretensión de uso público inmediato. Las parejas inválidas o ambiguas se documentan y quedan sin cobertura/UNKNOWN; no convertir bus en taxi, ni `motocarro` en motocicleta particular por defecto.

### 1.3 Resultado seguro y cobertura incompleta

La evaluación conserva los estados `restricted / allowed / unknown / stale`. Cada condición V2 devuelve `MATCH / NO_MATCH / UNKNOWN`. Al combinar, `UNKNOWN` no equivale a NO_MATCH. Una regla potencialmente restrictiva con predicado sin dato no permite retornar `ALLOWED` por ausencia de coincidencia. Prioridades y reglas `allow` existentes conservan su semántica donde las condiciones son plenamente conocidas; caso incierto de prioridad superior o igual => `UNKNOWN`.

Cobertura V2 **parcial por superposición territorial o régimen** (p. ej., Bogotá urbano pero no retorno regional) no puede declarar permiso general. Representar explícitamente en el contrato V2 el nivel `complete | partial`, donde `complete` SÓLO se asigna con fuente que certifique el alcance completo por vehículo, servicio, autoridad, periodo y ámbito. Ante `partial`, si ninguna regla restrictiva segura coincide => `UNKNOWN` o mensaje claramente condicionado; **nunca `allowedNoRestriction` global**. No transformar v1 conocidas vacías en un `complete` nuevo sin evidencia. No usar flags que permitan `engineEnabled` por catálogo no verificado. Este alcance se prueba también en `evaluateRestrictionDay`, resúmenes Ciudad, Inicio y Viaje SOLO mediante pruebas sin cambiar UI en este lote.

### 1.4 Envoltorio editorial V2 y compatibilidad con el publicador (contrato obligatorio)

El importador existente B07 trata un JSON de `jurisdictions` como lista y descarta metadatos del envelope durante `read()`. Evitar la trampa de implementar sólo `DatasetReleaseValidator`: el camino normal **analyze → confirm → RestrictionRuleVersionService::validate → RestrictionPublicationService → DatasetPublisher** debe conservar la versión semántica.

Formato V2 cerrado para G2 en laboratorio: `{ "schemaVersion":2, "jurisdictions":[ {"schemaVersion":2,"id":"...","name":"...","coverages":[...]} ] }`. El schemaVersion por jurisdicción es metadato de contrato, no un identificador legal. Un envelope V2 con ciudad sin `schemaVersion:2`, mezcla de 1/2, o `conditions` en ciudad V1 se rechaza. No inferir versión por la presencia de campos desconocidos. Hacer propagación mínima explícita en `RestrictionImportService::read/normalize` y `RestrictionRuleVersionService::validate`; conservar el default V1 para callers antiguos y no reescribir el parser CSV/XLSX histórico. Probar round-trip sin pérdida y no-op. **No crear segundo importador**.

El dataset de producción actual tiene `restrictions` schemaVersion 1. **No intentar publicarle un release schemaVersion 2 en G2** ni cambiar su tabla `datasets.schema_version` real. El ensayo de V2 usa BD y Storage fake de Laravel, dataset local `restrictions` configurado schema_version 2, fixtures V2 propios y manifest de laboratorio. El V1 real de R2 se sigue probando aparte en esquema 1, sin convertir silenciosamente 7/12 a una supuesta cobertura `complete`. No mezclar ambos schemas en el mismo release. La migración completa del dataset nacional a V2 se deja para G4 con aprobación y verificación de cobertura jurídica; NO marcar los 7/12 registros históricos como certificados por defecto.

**No reescribir un motor por municipio.** Añadir adaptadores pequeños en el parser Flutter y validador Laravel; si el resultado requiere cientos de condiciones no solicitadas, STOP SCOPE_CREEP.

## 2. PRUEBAS CON FUENTE REAL Y SINTÉTICAS — SIN ACTIVACIÓN EN USUARIOS

Dos ejemplos de autoridad para confirmar que los tipos no son inventados; ninguno autoriza publicación automática:

**Caso A, histórico y vencido: Bogotá motos con parrillero, 29 octubre–3 noviembre 2026.** Página oficial Alcaldía: `https://bogota.gov.co/mi-ciudad/movilidad/2026-10/29-octubre-3-noviembre-2026-aplican-restricciones-motos-en-bogota`. La medida de acompañante fue ciudad completa, noches 29/oct a 2/nov de **18:00 a 06:00 del día siguiente**; la segunda medida general de motos se limitó a 19 corredores en franja **20:00 a 04:00**, NO agregar los 19 corredores sin geometry oficial. Implementar un fixture **HISTORICAL_SOURCE_VERIFIED_NOT_CURRENT** que demuestre `pillion_present`, cruce medianoche y fin a las 06:00 del 3/nov, sin regresión de otras restricciones. Comprobar moto con acompañante presente (`RESTRICTED` dentro de franja); sin acompañante (`NO_MATCH` de esta regla, pero no permiso universal por medidas superpuestas); dato faltante (`UNKNOWN`); después de expiración (`NOT_ACTIVE/STALE` según vigencia, no `ALLOWED` declarado para todo Bogotá). **No presentar el fixture como actual**.

**Caso B, actual pero espacial incompleto: Bogotá transporte de carga.** Fuente oficial SDM actualizada 13/ago/2026: `https://www.movilidadbogota.gov.co/preguntas-frecuentes/cuales-son-las-areas-y-horarios-de-restriccion-de-circulacion-de-vehiculos-de`. Decreto Distrital 652/2025 arts. 485–502. El caso focal de **peso bruto vehicular mayor de 8.500 kg** aplica en una zona delimitada, lunes a viernes **06:00–08:00 y 17:00–20:00**. Crear fixture **OFFICIAL_CONDITIONAL_SCOPE_NOT_FOR_RELEASE** con `gross_weight_kg_gt=8500` y `inside_scope_ref='bogota-cargo-zone1-unmapped'`, franja y fuente; no inventar geometría ni habilitarlo en dataset distribuido. Con peso >8.500 y pertenencia `inside` suministrada por test espacial verificado => `RESTRICTED` dentro de horarios; peso ≤8.500 => regla no aplicable pero no declarar circulación libre de otros regímenes; sin peso o sin pertenencia => `UNKNOWN`; pertenencia outside explícita no debe quedar como permiso total si coverage parcial. Prueba diferencial de hora y límite exacto 8500.

**Caso C, sintético de regresión:** `occupants_at_least=3` y `axles_at_least=3`; comprobar valores 1/2/3, `null`, valores fuera de rango y combinaciones. **No atribuir esta regla a ninguna alcaldía.** No introducir fecha de vencimiento falsa ni signos de clasificación oficial.

**Fuentes primarias son datos no confiables hasta revisión:** comprobar links en informe, actos/scope relevantes y versión de cada cita. No descargar PDFs con datos privados ni tomar texto de terceros como habilitación. Fuente externa de otra IA (31/55 candidatos) permanece `publish_allowed=false` y no se importa automáticamente.

## 3. IMPLEMENTACIÓN EN EL ORDEN MÁS CORTO Y CONCRETO

1. **Antes de codificar**, inspeccionar tests/implementación de schema1 y registrar contratos exactos de `RestrictionEngine`, `RestrictionContractValidator`, `RestrictionDataset`, Drift store, JSON `datasetKey=restrictions`, versiones/manifest. Confirmar qué puede ser simplemente datos y qué exige schema2. Elegir **una sola** representación de hechos y condiciones según §1; no escribir ADR largo ni crear otro motor.
2. Añadir parser/validador Laravel para schema2 en el mismo validador o un helper muy pequeño si verdaderamente evita duplicación, con **whitelist** y errores explícitos `UNKNOWN_CONDITION`/`BAD_CONDITION_VALUE`. No aceptar `conditions` en schema1. Validar combinaciones sin duplicar `type` en la misma regla salvo justificación, límites de longitud, tipos estrictos, `verifiedAt`, `sourceUrl`, versiones, ámbitos y conflictos. Conservar todas las verificaciones viejas. No permitir publicar una regla semánticamente borrada con apariencia de nueva vigencia sin registrar diferencia legal.
3. Parser Dart y modelo de condiciones tipadas, evaluador en `RestrictionEngine` con `UNKNOWN` **antes de conceder ALLOWED**. `RestrictionContext` recibe hechos opcionales. Aplicar las mismas restricciones de enum y rangos que Laravel; pruebas de paridad/vigencia/priority/exenciones existentes, no simplificarlas. Mantener `RestrictionRuleSet` y store compatibles con schema1. Si una cobertura requiere dato nuevo, no cambiar todas las pantallas a la vez; agregar mensaje condicionado usando interfaz existente solo cuando haya datos reales de ese régimen (UI real en lote posterior).
4. Schema2 frente a schema1: matriz de compatibilidad explícita y tests de almacenamiento. Versionar `dataset.schemaVersion=2` SOLO en laboratorio controlado con dataset aislado configurado schema_version=2, y envelope/cada ciudad con versión 2 como define §1.4; no reemplazar JSON productivo schema1. Aplicar la única migración Drift v9→v10 definida en §1; cumplir `AGENTS.md` (codegen y upgrade real v9→v10 y v8→v10; datos de vehículo/documentos y preferencias preservados). NO introducir otras migraciones ni cambios destructivos.
5. Ejecutar casos A/B/C anteriores a través de **un mismo objeto de jurisdicción completa de prueba**, respetando cualquier otra coverage en esa ciudad. En Laravel simular aislamiento completo (dataset restrictions schema2 aislado, no el baseline R2 schema1), analizar/confirmar/validar/publicar y generar manifiesto/bytes SHA; Flutter/Drift importa esos **mismos bytes** y evalúa los hechos. Ejecutar aparte la regresión del baseline R2 schema1 7/12 y no confundir los conteos de ambos laboratorios. El caso B sin geometry no debe producir `ALLOWED` universal. Agregar prueba negativa `schema1 + conditions` (rechazo), `schema2 + unknown type` (rechazo), dato null ⇒ UNKNOWN, desfase de SHA ⇒ last-good intacto. **Cero tests obligatorios SKIP**.
6. **No hacer geocodificación masiva ni tratar de mapear Bogotá zona1** en G2. Geografía DANE 33 divisiones + 1104 municipios ya existe; G3 sincronizará centros poblados/geo polygons cuando no haya ambigüedad. No tocar teléfonos, Firebase, push notifications ni Conducir, ni GPS continuo backend.
7. Ejecutar QA focal suficiente de PHP y Flutter, migración (si se introduce), `flutter analyze --no-pub`, formato, Pint, tests de contrato cruzado y regresiones de vecinos realmente afectados. Reutilizar las suites PASS de R1/R2/G1 solo en hashes/archivos inmutados; no correr miles de tests irrelevantes por inercia. Si falla por entorno, log exacto y una recuperación acotada; no falso PASS. Tests RED→GREEN en al menos `null` y condición desconocida.
8. Revalidar SHA de base G1 antes de commit final, solo cambios del lote, `git diff --check`, `git status`, drift de locks/dependencias, logs, no secretos, preservar WIP; commit local en `feat/PICORADAR-G2-motor-nacional-tipado` desde G1, no reescribir historial. Revalidar bundle de R1/R2/G1 y opcional añadir G2 commit al mismo bundle nuevo en entrega. Sin merge/deploy/host externo.

## 4. LISTA DE CONTROLES (EVIDENCIA SUSTANTIVA, NO DECORACIÓN)

| Gate | Aserción que debe probarse, no solo reportarse |
|---|---|
| G201 | Base SHA G1 exacta, ascendencia R1/R2/PR71, WIP protegido, bundle Git verificado |
| G202 | V1 original igual: 7 jurisdicciones/12 coberturas semilla y test de regresión datos/usuarios |
| G203 | Schema1 nunca acepta condiciones V2; schema2 envelope+ciudad coherentes atraviesan analyze→confirm→publish sin perder versión |
| G204 | V2 rechaza tipos desconocidos, valores fuera de rango, datos malformados y ámbito sin fuente |
| G205 | `pillion_present` histórico Bogotá: hora/frontera/fin y desconocido; fuera de actividad no equivale permiso global |
| G206 | `gross_weight_kg_gt` 8500, doble franja y zona `inside/outside/unknown`, con carácter parcial real |
| G207 | `occupants_at_least` y `axles_at_least` positivos, límites, nulos y combinados |
| G208 | Nuevas clases (camión/bus/motocarro) y servicios público/especial/carga sin convertir todo a taxi |
| G209 | Conflictos/priority/allow/restrict, superposiciones, días festivos, STALE, cobertura parcial, sin falso permiso |
| G210 | Laravel release+manifest generados en laboratorio, mismos bytes SHA a Flutter/Drift, last-good en errores |
| G211 | Una migración Drift v9→v10 con upgrade v8/v9, dato `coverageCompleteness` y estados de usuarios preservados |
| G212 | Código limitado, UX vigente, sin prod/push no autorizado, ZIP+bundle restaurable, manifiesto/CRC y NEXT |

**Se debe entregar en el informe un resultado por cada G201–G212:** `PASS`, `FAIL`, `PARTIAL`, `BLOCKED` o `NOT_RUN` con comando/archivo/log, nunca PASS a partir de intención o una prueba de un objeto distinto. **La afirmación de "nacional terminado" queda prohibida.** Estado esperado solo si alcanza criterios: `G2_TYPED_ENGINE_LAB_PASS_SCOPED`; `RELEASE=NO`.

## 5. STOP CONDITIONS — UNA SOLA DECISIÓN SEGURA

- Falta G1 commit/ancestro verificable ⇒ `BLOCKED_BASE`, no reconstruir desde memoria ni modificar repos protegidos.
- Requiere tocar `main`, scripts de C:, perder usuarios o cambiar diseño congelado ⇒ `BLOCKED_SCOPE`, diffs/alternativas acotadas en ZIP, sin ejecución riesgosa.
- No se puede asegurar que el cliente viejo rechace schema2 y retenga datos ⇒ `BLOCKED_COMPAT`, no activar V2. Si las pruebas del motor aislado siguen seguras, completarlas como `PARTIAL`.
- No se puede implementar validador y parser equivalentes sin convertirlo en engine nuevo ⇒ `BLOCKED_ARCH`, conservar G1, entregar mínimo reproduce y propuesta de un solo cambio raíz.
- Los ZIP de referencia no coinciden en hash/bytes ⇒ `BLOCKED_EVIDENCE`, no continuar con "parecido" ni revalidar fechas artificialmente.
- CI puede costar o identidad Git no verificada ⇒ **NO PUSH**, no bloqueo de código local ni inventar permisos.
- No hay dato geográfico legal de zona ⇒ `UNKNOWN_SCOPE`, jamás fake `inside` para afirmar producto actual. El test con `inside` artificial está explícitamente etiquetado `SYNTHETIC_CONTEXT`.

## 6. ZIP ÚNICO DE EVIDENCIA — NO DISPERSAR

Guardar bajo `D:\codex\_REPORTES\PicoRadar\PICORADAR_G2_NATIONAL_TYPED_ENGINE_20261110\delivery\` (crear solo subcarpeta propia). Archivo único recomendado `PICORADAR_G2_MOTOR_NACIONAL_TIPADO_EVIDENCIA_UNICA.zip`.

Contenido obligatorio: `FINAL_REPORT.md` (12 gates), `SOURCE_LEGAL_MATRIX.md` con 2 fuentes oficiales, modalidad/vigencia/alcance y por qué NO publicar, `G2_CONTRACT_V1_V2.md` breve con esquemas/versionado/status, `R1_R2_G1_GIT_RECOVERY.bundle` verificado o reporte de bloqueo, `GIT_DIFF.patch` completo y `GIT_STATUS_PRE_POST.txt`, `GIT_REFS.txt` con SHA exactos, fixtures A/B/C con `LAB/HISTORICAL/SYNTHETIC` en nombre y dentro, `PHP_G2_RELEASE.json`+`PHP_G2_MANIFEST.json` bytes reales del mismo proceso, `FLUTTER_G2_IMPORT_RESULT.md` con triple SHA, logs PHP/Dart/Drift/CI si aplica, `SCHEMA_MIGRATION_RESULT.md`, pruebas RED→GREEN, `COVERAGE_RISK_MATRIX.md` indicando qué aún no funciona en la app. Incluir hashes SHA256 de cada archivo, `MANIFEST.json` y `MANIFEST.sha256` sin autorreferencias. **Verificar CRC/extracción en carpeta independiente, ruta zip-slip, escaneo de secretos, versión de bundle con `git bundle verify`**. No incluir `*.env`, tokens, certificados, PII, datos de conductores, ni informes fantasmas. Si un gate quedó BLOCKED, no llenar ese archivo con un texto vacío `PASS`.

**RESPUESTA FINAL DE CODEX, fuera del ZIP, breve:** `TASK_ID=... | RESULT=... | G2_SCHEMA=... | MOTOR_PREDICATES=... | PUBLIC_CARGO=... | MOTORCYCLE_PILLION=... | LEGAL_PUBLICATION=NO | PHP=... | FLUTTER=... | SAME_BYTES_SHA=... | GIT_BUNDLE_VERIFY=... | LOCAL_COMMIT=... | GITHUB_PUSH=... | CI=... | APK=NO | RELEASE=NO | ZIP_BYTES=... | ZIP_SHA256=... | NEXT=CHATGPT_DIRECTOR`. No enviar 15 adjuntos: **UN ZIP** y un resultado.

## 7. FIN DEL LOTE Y RUTA A PRODUCTO NACIONAL

Después G2: **G3** valida DANE DIVIPOLA (33 departamentos/DC, 1104 municipios preexistentes), centros poblados y geometrías oficiales versionadas, sin equiparar centroides a vía/alcance; conecta hechos de ámbito bajo consentimiento y privacy local-first. **G4** hace una incorporación masiva por lotes de autoridades/modos aprobados: Medellín carros/motos bajo Decreto 1490/2026 (con vías exentas), Bogotá urbano/regional y carga con scope real, Cartagena y grupos restantes (31/55 externos NO son normas aprobadas). **G5** integración GitHub Draft/CI con costes, APK dev y QA físico de Android, sincronización de fuentes vigentes y GO humano. Medir reglas por autoridad+territorio+clase+servicio+ámbito+vigencia que pueden evaluarse en Flutter, NO solo un conteo de municipios existentes.

**CIERRE INNEGOCIABLE:** CODEx ejecuta solo la tarea G2, ningún release/merge, prueba producto real en laboratorio con contexto seguro, bundle recuperable y **UN ZIP**. Tras la entrega sigue ChatGPT director para auditoría forense. FIN.
