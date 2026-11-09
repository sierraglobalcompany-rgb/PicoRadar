# CODEX LUNA — PICORADAR · M1.3→M1.4 · LOTE ÚNICO DE FUENTES Y REGLAS OPERATIVAS · KISS + PONYTAIL

**TASK_ID:** `PICORADAR-M1-FUENTES-OPERATIVAS-17-CIUDADES-20261108-DIRECTOR`  
**DIRECTOR TÉCNICO:** ChatGPT. **EJECUTOR LIMITADO:** Codex Luna.  
**ESTADO AL INICIAR:** M1.3 `PARTIAL_DISCOVERY`, 1.122 unidades territoriales inventariadas, 3.366 filas de tres clases, 3.356 `NOT_SEARCHED`, ocho reglas núcleo incompletas en cinco ciudades, dos incidencias adicionales; **cero reglas autorizadas en este lote**.  
**SALIDA:** un solo ZIP de evidencias con manifiesto, SHA-256 y CRC. `NEXT_ACTOR=CHATGPT`.  
**RELEASE=NOT_APPROVED; PUBLISH_ALLOWED=NO; CODE_PUSH=NO; MERGE=NO; DEPLOY=NO`.  
**REGLA ANTIPING-PONG:** si este TASK_ID ya empezó, NO reiniciar ni duplicar consultas: concluir la ejecución vigente y devolver el ZIP. No abrir M1G, Rxx, C2 ni sublotes por municipio.

## 0. Objetivo inequívoco y límite de autoridad

Este lote NO vuelve a inventariar DANE/RUNT ni reaudita el validador PHP. Transformará los hallazgos del M1.3 previo en **matrices de evidencias de fuente y candidatas de reglas por vehículo/ámbito**, mientras abre investigación *real* en doce ciudades adicionales. El éxito significa aumentar unidades/filas con investigación específica demostrada, reducir lagunas de las ocho candidatas y preparar decisiones humanas M1.4/M1.5; NO significa liberar la aplicación ni completar toda Colombia.

**Preservar las leyes L1–L6 y jerarquía:** `AGENTS.md` → seguridad/privacidad/store → `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx` → `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx` → flujos → diseño → Plan Maestro V2 (§§D, W/W.1). No se aprueba cambio de esas fuentes por este prompt. Flutter + Riverpod/Drift y Laravel monolítico/publicador único quedan congelados; agente lector solo propone. No cambiar algoritmos, JSON, BD, WIP, releases, cámaras, GPS ni teléfono.

**Terminología estricta:** `NOT_SEARCHED` ≠ `SEARCHED_NO_CONCLUSION` ≠ `OFFICIAL_NO_MEASURE` ≠ `OFFICIAL_RULE_PARTIAL` ≠ `OFFICIAL_RULE_COMPLETE_REVIEW_PENDING`; `OFFICIAL_RULE_COMPLETE` requiere todas las variables materiales, validación de competencia, revisión humana posterior, todavía `activation=false`. `staleAfter` técnico NO es `nextReviewAt` de inspección y ninguno es fin legal. Nunca inferir `ALLOWED` por no encontrar fuente. Si una web falla HTTP 403, mantener `INDEX_ONLY/ACCESS_BLOCKED`; las páginas oficiales accesibles por otros canales pueden documentar evidencia nueva, conservando URL, fecha y límites de captura.

## G0. Preflight mínimo (una vez, sin bloqueos repetitivos)

1. Leer `AGENTS.md`, `docs/CURRENT.md`, Plan Maestro y la última orden M1.3; comprobar `TASK_ID`, fecha, HEAD solo lectura, ramas y rutas protegidas. No tocar `D:\\codex\\PicoRadar` ni clones C1. Trabajar en carpeta aislada de reportes bajo `D:\\codex\\_REPORTES\\PicoRadar\\<TASK_ID>`, salvo ruta canónica distinta validada en `AGENTS.md`.
2. Localizar y verificar por bytes **el ZIP adjuntado al director para M1.3**, nombre `PICORADAR_M1_3_DESCUBRIMIENTO_NACIONAL_EVIDENCIAS_UNICAS_20261108.zip`, SHA-256 `97d2987ee96624a25be60db1dfa8f7c3123ec70256d958a681e3ff5dd5a8c7a8`. Verificar 14 entradas, `testzip`, 12 miembros de manifiesto; extraer solo a carpeta temporal segura, sin borrar originales. Si no está: usar el mismo contenido previamente verificado en copia local identificada por hash; si falta, documentar `BLOCKED_INPUT` en ZIP con todos los adelantos independientes posibles. **No pedir otro preflight o input por separado.**
3. Inventario que NO se repite: MGN2025 `1.122` unidades únicas reportadas: 1.103 municipios, 1 isla, 18 ANM. 33 índices de departamentos/DC. 3.366 filas (3 clases cada una); 3.356 `NOT_SEARCHED`, ocho parciales, dos incidencias. Cinco **ciudades**, no ocho. Las ocho son **filas de vehículo**: Medellín dos, Bogotá particular una, Cartagena dos, Dosquebradas dos, Villavicencio una.
4. Comprobar que la matriz `M1_3_COVERAGE_DISCOVERY.csv` conserva claves `divipola×vehicle_class` únicas. No recrear M1A/M1B, no volver a consultar los 33 índices salvo error verificable en hash/denominador. No instalar dependencias globales ni usar credenciales privadas.

## G1. Primera prioridad: cerrar lagunas específicas en cinco ciudades ya investigadas

Revisar únicamente **el delta documental de fuente**, sin recontar como nueva búsqueda lo que ya estaba verificado. Cada hallazgo debe indicar código, clase, territorio y autoridad con competencia, fecha/hora, autoridad oficial, URLs oficiales concretas, texto breve de soporte propio/parafraseado, resultado de acceso, hash de bytes **si el cuerpo se obtuvo**, vigencia legal, días, dígito de placa, horario, festivos, exenciones, perímetro, condiciones especiales y elementos todavía desconocidos. Priorizar y trabajar en este orden:

| Prioridad | Territorio y códigos | Acción causal y fuente oficial inicial | Decisión permitida |
|---|---|---|---|
| P0 | **Medellín 05001** particular/moto | Contrastar reglas II-2026, **Decreto 1490/2026** y ficha cartográfica oficial de **vías exentas** `https://www.medellin.gov.co/giscatalogacion/srv/api/records/2d9cb19a-e7c7-4e1d-8a38-fb055997b043` con `https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre`; identificar si se puede derivar perímetro permitido/no permitido del geodato sin inventar geometría. | Registrar evidencia/zonas/lagunas. **No ampliar `staleAfter` local de 2026-11-10T05Z**: requiere política y aprobación posteriores. |
| P0 | **Cartagena 13001** particular/moto + incidencia taxi separada | Aportar fuente oficial publicada el **19-oct-2026** `https://cartagena.gov.co/noticias/datt-refuerza-controles-invita-cumplir-el-pico-y-placa-cartagena`, fuente 06-oct `https://cartagena.gov.co/noticias/cambia-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena-0` y el aviso taxi 04-nov `https://cartagena.gov.co/noticias/esta-nueva-rotacion-pico-placa-para-taxis-cartagena-1`. Para taxi, consultar la norma 0004/2026 `https://cartagena.gov.co/noticias/cartagena-adopta-nueva-rotacion-pico-placa-para-taxis-partir-este-lunes-5-enero` antes de decidir festivo, horario nocturno y error **martes 02-nov** (es lunes). | Precisar rotación, horas, festivos, 22-ene-2027 para particulares/moto y texto por ámbito. Taxi es **incidencia extra**, no una de las ocho. Mantener excepción temporal/estacional y zona como revisión; no publicar. |
| P0 | **Bogotá 11001** particular + alerta moto adicional | Fuente SDM actualizada `https://www.movilidadbogota.gov.co/preguntas-frecuentes/en-que-consiste-la-restriccion-establecida-para-vehiculos-particulares` y `https://www.movilidadbogota.gov.co/pico-y-placa`; leer **Decreto 652/2025, arts. 227–230**, perímetro, excepciones, regional festivo separado. El portal SDM **no publica medida equivalente para moto particular solo por existir regla de carros**: verificar categoría exacta antes de decir ausencia o aplicar una regla. | Bogotá particular: los dígitos **restringidos** por paridad del día, no confundir con los habilitados. Bogotá moto `staleAfter < sourceCheckedAt` es conflicto de dataset histórico, no permiso ni cambio de fecha. |
| P1 | **Dosquebradas 66170** particular/moto | Noticia oficial `https://dosquebradas.gov.co/web/dosquebradas/ciudad/sala-de-prensa/noticias/303-vigencia-2026/10128-dosquebradas-retoma-desde-este-lunes-el-pico-y-placa-tradicional`; buscar acto/sitio de Secretaría de Tránsito para **fin legal, perímetro, festivos**. Descartar la URL 10140 previamente comprobada como redirección a otra noticia. | Completar solo campos demostrados, conservar fin abierto si norma realmente no fija uno; no inferir feriados. |
| P1 | **Villavicencio 50001** particular | Comunicado `https://villavicencio.gov.co/con-jornadas-pedagogicas-inicio-el-pico-y-placa-2026-para-vehiculos-particulares-en-villavicencio/` y el **Decreto 015/2026 íntegro**/mapa del polígono 2025 al que remite. | Validar geometría verificable y modificaciones; no activar zona sin polígono/corredores. |

**Prueba de completitud por cada una de las ocho filas:** ① autoridad+territorio real ② tipo vehículo/servicio ③ posición de dígito ④ dígitos×días ⑤ horario/madrugada ⑥ festivos ⑦ excepciones ⑧ ámbito espacial verificable ⑨ inicio/fin legal o fin abierto justificado ⑩ fuentes con fecha/evidencia ⑪ consistencia de rotaciones futuras ⑫ política técnica de revisión/TTL separada. Un campo material `UNKNOWN` ⇒ `OFFICIAL_RULE_PARTIAL`, `activation=false`. No inventar detalles y no confundir ámbito distrital con polígono efectivo de vías.

## G2. Segunda prioridad: doce ciudades NUEVAS, códigos exactos, sin otra barrida de índices

Abrir desde `NOT_SEARCHED` una investigación documental específica sobre estas **doce ciudades ancladas a códigos existentes en la matriz**; no elegir otras ni confundir autoridad RUNT candidata con competencia probada. Cada ciudad inicia con las tres clases (`car-private`, `car-taxi`, `motorcycle-private`). Se considera investigada una fila **solo si hubo búsqueda documental específica por clase o evidencia oficial que abarque varias clases**, con resultado y marca de tiempo. Buscar fuente local oficial por Secretaría/Alcaldía/organismo y municipio competente, usar búsqueda abierta para encontrar documento específico y buscar un segundo texto solo si falta campo material. No más de cuatro búsquedas focales por ciudad salvo contradictorio legal justificado. No copiar regulación de capitales a toda su área metropolitana.

| Orden | DIVIPOLA | Ciudad | Departamento |
|---:|---|---|---|
| 1 | `76001` | Santiago de Cali | Valle del Cauca |
| 2 | `08001` | Barranquilla | Atlántico |
| 3 | `68001` | Bucaramanga | Santander |
| 4 | `66001` | Pereira | Risaralda |
| 5 | `17001` | Manizales | Caldas |
| 6 | `63001` | Armenia | Quindío |
| 7 | `73001` | Ibagué | Tolima |
| 8 | `54001` | San José de Cúcuta | Norte de Santander |
| 9 | `52001` | Pasto | Nariño |
| 10 | `15001` | Tunja | Boyacá |
| 11 | `23001` | Montería | Córdoba |
| 12 | `41001` | Neiva | Huila |

**Criterio de salida de G2:** 12/12 ciudades **intentadas y clasificadas** con evidencia de consulta específica o error motivado (no necesariamente 36 reglas completas). Registrar por cada clase `OFFICIAL_RULE_FOUND_PARTIAL`, `COMPLETE_REVIEW_PENDING`, `OFFICIAL_NO_MEASURE_WITH_EXPLICIT_PROOF`, `SEARCHED_NO_CONCLUSION`, `ACCESS_BLOCKED` o `NOT_SEARCHED` si no se llegó a investigar. Si la autoridad oficial publica cero medidas, NO adjudicar `OFFICIAL_NO_MEASURE` sin pronunciamiento expreso sobre territorio y categoría/periodo. Es mejor 12 intentadas con prueba que 1.122 filas generadas mecánicamente. No ampliar automáticamente a municipios vecinos.

**Selección cerrada por el director:** la lista no declara que las doce tengan pico y placa: son consultas prioritarias para producir nueva evidencia útil. Si alguna fuente está 403 o exige CAPTCHAs, registrar bloqueo, usar índices/boletines oficiales accesibles y no eludir controles. Sin inferencia desde medios secundarios hacia reglas publicables.

## G3. Matriz única versionada: no cambiar datos ni perder historial

A partir de los mismos CSV M1.3 (no crear nueva BD ni hacer migraciones), entregar un **delta** separado con estas columnas mínimas y claves estables:

- `M1_SOURCE_DECISIONS.csv`: `divipola,department,municipality,authority,authority_competence_evidence,vehicle_class,regime_scope,source_url,source_published_at,source_checked_at,retrieval_result,snapshot_sha256_if_bytes_captured,specific_claim_supported,field_value,legal_from,legal_until,exception_scope,spatial_scope,next_review_at,technical_stale_after_proposal,confidence_class,unresolved,decision`.
- `M1_OPERATIVE_RULE_MATRIX.csv`: `divipola,territory,vehicle_class,service_type,plate_digit_side,weekdays,digits_by_day,time_windows,overnight,holidays,exceptions,geometry_or_corridor,legal_from,legal_until_or_open,source_refs,source_checked_at,next_review_at,technical_stale_after_proposal,completeness_12_fields,blocking_unknowns,activation`.
- `M1_CITY_COVERAGE_DELTA.csv`: `divipola,source_prior_status,source_new_status,vehicle_class,old_evidence,new_source_ids,verified_fields,remaining_unknowns,review_due,reason`.
- `M1_BLOCKERS_AND_DECISIONS.csv`: `issue_id,priority,divipola,vehicle_class,field,conflicting_values,sources_compared,actionable_next,owner,freeze_reason`.
- `M1_COUNTS_AND_GATE.csv`: `metric,numerator,denominator,unit,cutoff,identity_of_units,method,evidence`, incluyendo municipios únicos investigados vs filas clase, 5 ciudades históricas vs 12 nuevas, 8 filas núcleo vs 2 incidentes, 1.122 unidades MGN2025, 3.366 filas y 3.356 no investigadas **antes del lote**, 12 ciudades nuevas objetivo, unidades aún `NOT_SEARCHED`, y cobertura real sin falsos verdes.

Conservar `M1_3_COVERAGE_DISCOVERY.csv` intacta como baseline. El CSV delta no debe duplicar 3.366 registros largos; conservar solamente las filas que **cambiaron por evidencia nueva**, e indicar denominador completo aparte. Los nombres de fuentes M1A/B permanecen sin reescritura de historial, sin inflar `n` con visitas repetidas al mismo documento. No guardar credenciales/PII/snapshots masivos con licencias inciertas en GitHub.

**Prueba de exactitud:** conteos de estados reconciliados; `new_n = old_n + delta_n` sin dobles conteos; distinción explícita de `(municipio,clase)` y `(municipio)`; cada regla derivada tiene fuente, alcance y fecha, no mezcla entre primero/último dígito. Candidatas nunca activadas (`activation=false`), no crear runtime JSON ni actualizar `staleAfter` Medellín, Bogotá moto u otra jurisdicción.

## G4. Verificación y política de cierre

Ejecutar diez controles distintos (NO diez búsquedas globales):

1. ZIP M1.3 real SHA/CRC/manifiesto; si falta, señalar exactamente lo que no se pudo verificar.
2. 1.122 códigos y 3.366 filas únicas del baseline, sin cambio de universo.
3. Las **cinco ciudades históricas / ocho filas** están bien diferenciadas.
4. Doce códigos nuevos válidos y resultados individualizados, sin repetir `NOT_SEARCHED` como investigado.
5. Fuentes oficiales primarias, fechas y captura SHA solo si se obtuvo cuerpo real.
6. Atribución a autoridad y ámbito, sin RUNT como autorización por sí solo.
7. Verificación de placa primer/último; horario nocturno/festivos y paridad habilitado/restringido.
8. Excepciones/zonas y fuente legal, `UNKNOWN/CONFLICT` sin falso `ALLOWED`.
9. Denominadores municipio vs clase, historial preservado y 0 cambios de código/datos/WIP.
10. Un solo ZIP íntegro; resultado `M1_PRIORITY_BATCH_DONE_WITH_GAPS` o `PARTIAL_ACCESS_BLOCKED` con porcentajes SOLO de este lote y sin declarar M1 nacional DONE.

**No reabrir** H4, M1E, M1F, C1, PHP, SQLite, Flutter, APK, JNI, CI ni migraciones. Su verificación solo corresponde al carril de integración M4. Si un portal bloquea, cambiar a fuente oficial alternativa claramente identificada o registrar `ACCESS_BLOCKED`. Si faltan insumos documentales, completar las filas investigables y cerrar un único ZIP sin ping-pong.

## G5. Entrega ÚNICA y handoff

Empaquetar exactamente **un ZIP** llamado `PICORADAR_M1_LOTE_OPERATIVO_FUENTES_EVIDENCIAS_UNICAS_20261108.zip` con: `FINAL_REPORT.md` (resultado, cobertura, P0/P1/P2, n/N exacto y actor), los cinco CSV de G3, `OFFICIAL_SOURCE_NOTES.md` (enlaces y evidencia por afirmación), `AUDIT_10.csv`, `COMMANDS_AND_RESULTS.log` (intentos reales, tiempo y salida), `GIT_AND_WIP_STATUS.txt`, `NEXT_FOCUS.md` (lista cerrada de lagunas agrupadas por autoridad, jamás 1.100 tareas separadas), `MANIFEST.json` con SHA256/tamaño por payload y `MANIFEST.sha256`. Debe pasar `zipfile.testzip`, SHA256 y CRC32. El ZIP contiene **todas las evidencias útiles**; no enviar CSV/MD separados al director ni directorios temporales. No eliminar temporales mediante comandos peligrosos si política lo impide; registrar ruta y no eludir.

Al terminar, responder únicamente `TASK_ID`, `RESULT`, `NEW_MUNICIPALITIES_WITH_SPECIFIC_RESEARCH=n/12`, `CORE_ROWS_ADVANCED=n/8`, `NEW_RULES_READY_FOR_HUMAN_REVIEW=n` (nunca publicar), `ZIP_SHA256`, un enlace al ZIP, `NEXT_ACTOR=CHATGPT`, `RELEASE=NOT_APPROVED`. No afirmar `M1.3 DONE`, que exige todo el universo investigado de forma trazable. El director decidirá el siguiente bloque de fuentes o M1.4/M1.5 **en un solo plan**.

## G6. Ruta de proyecto NO ALTERADA

- **M1 nacional:** identificación por autoridad/municipio, evidencia legal, propuestas revisadas; este lote incrementa el denominador investigado sin cambiar su naturaleza.
- **M2:** motor existente, compilador y agente de solo lectura/propuestas, sin duplicar publicador.
- **M3:** Laravel único editor/validador/publicador con manifest/rollback; Flutter local-first, offline, cámaras y cuentas opcionales según baseline.
- **M4:** admisión controlada del candidato C1, CI real Flutter/PHP/SQLite, WIP, QA física Android/JNI/firma y autorización humana. No anticipar release.

**FIN ORDEN CODEX LUNA. NEXT_ACTOR_AFTER_ZIP=CHATGPT.**