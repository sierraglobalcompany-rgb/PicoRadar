# PICORADAR — Auditoría forense del lote M1 de 17 ciudades · 10 pasadas · decisión directiva

**Director:** ChatGPT · **Corte:** 2026-11-08, America/Bogota. **Resultado del lote:** `M1_PRIORITY_BATCH_DONE_WITH_GAPS` aceptado en su **alcance documental**, NO aceptado como cierre legal, dataset completo ni release. **Código:** no modificado según evidencia de lote; PHP/Dart C1 previo no integrado. **Autoridad:** AGENTS.md, las seis leyes L1-L6 y Plan Maestro V2 (M1-M4) no se alteran. **Próximo actor:** Codex ejecutor únicamente después de la decisión documental de ChatGPT.

## A. Evidencia física verificada por el director

- ZIP `PICORADAR_M1_LOTE_OPERATIVO_FUENTES_EVIDENCIAS_UNICAS_20261108.zip`: **47.606 bytes**, SHA-256 `bd294b01b1f06b9d7aad709d5196b3e98dc8430fcd6039acd581f8452a1aa8d8`. Coincide exactamente con el hash comunicado.
- ZIP `testzip()` = `None`/sin errores; 14 entradas, 12 archivos payload y dos manifiestos. Hash real de `MANIFEST.json` `d30be236d2eed235c74ade3bb9761c43af5f040c62f0959b92b89aad7450ab5b`, igual que el sidecar `MANIFEST.sha256`. **12/12** tamaños y SHA-256 internos iguales al manifiesto; CRC 14/14 PASS.
- `M1_3_COVERAGE_DISCOVERY.csv` 3.366 claves fuente históricas, con 3.356 `NOT_SEARCHED`, 6 `OFFICIAL_PARTIAL`, 2 `OFFICIAL_PARTIAL_TEXT_ONLY`, 1 `HISTORICAL_STALE_CONFLICT`, 1 `OFFICIAL_SOURCE_CONFLICT`. Hash exacto preservado `1172f0637b974c94198aa9f3def81cff39e00846327dc7df7b420a0c8d817293`.
- `M1_CITY_COVERAGE_DELTA.csv` tiene **41 claves únicas** `(DIVIPOLA, vehicle_class)`; 36 provienen de `NOT_SEARCHED`, 5 son revisitas con nuevo material. El control `prior_status` coincide con los valores del baseline en **41/41**. Cero nuevas filas indebidamente atribuidas a las cinco ciudades históricas.
- `M1_SOURCE_DECISIONS.csv` 52 filas de evidencia por clase, 17 ciudades distintas; 44 filas de reglas en `M1_OPERATIVE_RULE_MATRIX.csv` (12 ciudades nuevas x 3 = 36 y 8 núcleo), **44/44 `activation=false`**. Cero reglas `READY`.
- Reconciliación de las 36 filas nuevas: 12 `OFFICIAL_RULE_FOUND_PARTIAL`, dos `OFFICIAL_NO_MEASURE_WITH_EXPLICIT_PROOF` (solo bajo instrumento/periodo específico), 22 `SEARCHED_NO_CONCLUSION`. Los dos casos no-medida NO permiten generalizar `ALLOWED`: Barranquilla taxi por derogatoria Decreto 0450/2025 y Manizales moto bajo Decreto 0357 temporal. Debe comprobarse vigencia/modificatorios.
- `M1_BLOCKERS_AND_DECISIONS.csv` 16 incidentes agrupados por autoridad/riesgo; 10 controles propios en `AUDIT_10.csv`. Ningún P0 permite despliegue.

## B. Diez pasadas con dictamen independiente (NO un PASS genérico)

| N.º | Pasada | Dictamen | Evidencia, problema y decisión |
|---|---|---|---|
| 1 | Integridad ZIP | **PASS** | 47.606 bytes SHA, CRC 14/14 y sidecar coincide. |
| 2 | Manifiesto y contenido | **PASS** | 12/12 payload hash/tamaño válidos; se inspeccionaron CSV reales. |
| 3 | Identidad de la base | **PASS acotado** | 3.366 filas, baseline byte a byte preservado y 41/41 `prior_status` coherentes. No se reconsultó directamente DANE en esta auditoría. |
| 4 | Grano y duplicaciones | **PASS** | 41 claves `DIVIPOLA×clase` distintas; 36 nuevas y cinco revisitas, no sumar revisitas como municipios nuevos. |
| 5 | 12 ciudades nuevas | **PARTIAL** | 12 municipios tienen filas por 3 clases, pero 22/36 terminan sin conclusión, varios sin URL de resultado/consulta cruda; `12/12` representa registro de búsqueda, NO evidencia normativa completa. |
| 6 | Avance núcleo 5/8 | **PASS documental, NO cierre** | Cinco con nuevas afirmaciones, tres sin avance (Dosquebradas x2, Villavicencio x1); 0/8 totalmente listas. La matriz incluye incertidumbre territorial/festivos/excepciones. |
| 7 | No-medida / false ALLOWED | **PRECAUCIÓN P1** | Dos filas `OFFICIAL_NO_MEASURE_WITH_EXPLICIT_PROOF` están acotadas a instrumento/periodo. No certifican ausencia de medidas posteriores ni libertad de circular para toda la clase. Mantener `activation=false`. |
| 8 | URLs, hashes de páginas y tiempos | **PARTIAL / KPI NO REPRODUCIDO** | Fuente CSV: 19 URL distintas y 14 nuevas respecto del CSV M1.3. Notas: 26 URL distintas por extracción textual, 21 ausentes del CSV M1.3. Declaración 22 URLs nuevas no reproducida por estas vistas. 26 filas tienen hash de cuerpo informado, pero los cuerpos crudos no se adjuntan para verificar hashes; horas exactas de varias consultas faltan. |
| 9 | Contraste de normas oficiales | **PASS focal, 0 reglas autorizadas** | Confirmados vía fuentes oficiales: Medellín II-2026 y GIS de vías exentas, Bogotá Decreto 652/2025 y Cartagena calendario 2026 con ventana especial dic-ene. Persisten ámbito geométrico, excepciones, modificaciones y capas nocturnas. No se extrapola. |
| 10 | Preservación, leyes L1-L6 y ruta M1–M4 | **PASS documental / WIP NO_VERIFIED** | ZIP dice cero escritura Git/runtime/vehículos; no comprobó 101 hashes WIP en esta pasada. No microservicios, ni migraciones ni push. El siguiente trabajo debe transformar cinco candidatas avanzadas en expedientes legales comprobables, NO repetir búsqueda de 17 ciudades. |

## C. Hallazgos críticos y prioridad

**P0 — Terminar contrato legal antes de activar.** Cinco filas avanzadas: Medellín coche/moto, Bogotá coche, Cartagena coche/moto. La afirmación `NEW_RULES_READY_FOR_HUMAN_REVIEW=0` es correcta por contenido: dígitos y horario no bastan si faltan límite jurídico, festivo, excepciones o territorio. Una nota de vía exenta no demuestra polígono completo. Las fechas de revisión/editorial no suplen vigencia legal. `UNKNOWN`, `STALE`, `CONFLICT` jamás equivalen a circulación autorizada.

**P0 — Separar horario ordinario y temporada especial Cartagena.** Comunicado oficial de 16-ene-2026 anuncia fin de año **11-dic-2026–22-ene-2027** bajo una ventana especial 24h para particulares. El comunicado de octubre especifica el horario ordinario en su momento. Es un contraste real a conservar, no motivo para extender automáticamente `staleAfter` ni inventar límites a medianoche. Además, el permiso de circulación nocturna de motos es una modalidad distinta de una exención general.

**P0 — Bogotá Decreto 652/2025 accesible.** Artículos 226–230 compilados en Sistema Jurídico Distrital, vigencia desde 25-dic-2025 y posteriores modificaciones. Validar par/impar restringido, festivos, retorno regional como régimen separado, excepciones y perímetro urbano. Evitar usar el anuncio de 'dígitos que circulan' como lista de restringidos.

**P0 — Medellín decreto homónimo.** El Decreto **distrital** 1490 del 30-jul-2026 (Gaceta municipal 5885) refiere pico y placa; el Decreto **nacional** 1490 del 6-oct-2026 refiere inversiones de fondos de pensiones. Nunca mezclar un mismo número sin autoridad, fecha y materia. La página municipal II-2026 mantiene slug 2023 y requiere lectura de cuerpo. La ficha GIS identifica vías exentas, no necesariamente toda la geometría de aplicación. `staleAfter=2026-11-10T05:00Z` reportado para Medellín: **NO RENOVAR AUTOMÁTICAMENTE**.

**P1 — Evidencia de consultas y URLs.** Contar *URLs nuevas* exige criterio canónico (URL exacta vs normalizada) y un inventario asociado a source_id. No se acepta 22 como KPI auditado. El hallazgo es de reportabilidad, no orden de repetir búsquedas. Las 22 filas `NO_CONCLUSION` no son certificación de ausencia: varias no contienen URL, cuerpo, consulta literal o hora reproducible.

**P1 — Dos no-medida condicionadas.** Barranquilla taxi derogatoria 2025: no cubre automáticamente actos 2026. Manizales moto exenta bajo un decreto temporal: no equivale a ausencia universal de medida. Mantener solo `SCOPED_NO_MEASURE` con fuente, ámbito y período mientras se comprueban modificatorios.

**P1 — Protección WIP/CI.** Cinco cambios PHP+Dart del candidato C1 siguen sin integrar ni validar Flutter/CI. Los 101 WIP históricos no fueron comprobados nuevamente. Mantener carril independiente M4, no bloquear la investigación legal M1.

## D. Contraste externo focal realizado por el director

1. Alcaldía Medellín II-2026: `https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre`; comunicado de 24-jul: `https://www.medellin.gov.co/es/?p=549622`; ficha oficial GIS `https://www.medellin.gov.co/giscatalogacion/srv/api/records/2d9cb19a-e7c7-4e1d-8a38-fb055997b043` (vías exentas, Decreto 1490/2026).
2. Alcaldía Bogotá: `https://bogotajuridica.gov.co/sisjur/normas/Norma1.jsp?i=191872` y FAQ SDM `https://www.movilidadbogota.gov.co/preguntas-frecuentes/en-que-consiste-la-restriccion-establecida-para-vehiculos-particulares`; revisar modificatorios, no activar automáticamente.
3. Cartagena DATT: `https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026` y `https://www.cartagena.gov.co/noticias/datt-refuerza-controles-invita-cumplir-el-pico-placa-cartagena`; mecanismo de exenciones `https://www.cartagena.gov.co/tramites-y-servicios/permiso-pico-placa`.
4. Fuente oficial Barranquilla Decreto 0450/2025: `https://barranquilla.gov.co/documento/gaceta-no-1190/`. El decreto confirma derogatoria a fecha del acto; vigencia posterior requiere comprobación aparte.

**Nota de evidencia:** las consultas web del director confirman contenido focal accesible; no son captura byte-a-byte de las 26 páginas mencionadas por Codex ni revisión legal exhaustiva de todas las autoridades. Ni esta auditoría ni el lote acreditan uso real en teléfono.

## E. Cambio de rumbo aprobado: un solo próximo trabajo, nada de pingpong

**Lote siguiente** `PICORADAR-M1-LEGAL-CIERRE-5-FILAS-CRITICAS-20261108-DIRECTOR`: completar **solo** las 5 filas con evidencia avanzada y las capas legales que faltan, usando primero enlaces oficiales ya comprobados. No repetir DANE/RUNT, las 17 ciudades, M1C/D/E/F, auditorías PHP, 22 consultas inconclusas, ni buscar nuevas 100 URLs por inercia. Codex recopila evidencias, extrae 5 matrices legales y casos temporales; **ChatGPT decide** qué filas pasan a revisión M1.5.

**Ruta de salida M1–M4 sin cambio tecnológico:**

- **M1.4/1.5 próximo:** evidencia artículo por campo de 5 filas, riesgos espaciales/festivos/temporales, revisión humana; luego agrupaciones por autoridad para completar cobertura restante, sin certificar el universo nacional antes de investigarlo realmente.
- **M2:** reutilizar compilador/motor y agente de solo lectura que propone; pipeline con pruebas e idempotencia, sin auto-publicación.
- **M3:** Laravel revisión/publicación/rollback, sync Flutter versionado offline, cámaras/ANSV con evidencia de operación y funciones ya baselinadas; sin usar backend por GPS.
- **M4:** integración Git controlada y CI real, resolver cliente Flutter de C1, 101 WIP, crash JNI, QA Android físico, firma, privacidad y GO humano.

**Estado:** `M1_OPERATIVE_BATCH_ACCEPTED_SCOPED`, `M1_NATIONAL_PARTIAL`, `CODE_C1_NOT_INTEGRATED`, `PUBLISH_ALLOWED=NO`, `RELEASE=NOT_APPROVED`, `NEXT_ACTOR=CODEX_LUNA` solo para lote siguiente; tras su ZIP `NEXT_ACTOR=CHATGPT`.