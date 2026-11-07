# PicoRadar — Registro acotado de errores, correcciones y decisiones del agente

**Corte:** 2026-11-07. **Ámbito:** Pico y placa nacional, inventario de fuentes, agente lector e integración documental. **Estado:** seguimiento del diseño; no implica que el agente automático exista o esté ejecutándose. **Regla:** una entrada solo cambia de estado con evidencia nueva; no reabrir decisiones PASS por costumbre. Baselines, `AGENTS.md` y seis leyes conservan precedencia.

| ID | Problema observado | Evidencia reutilizable | Corrección/decisión vigente | Estado y gatillo para reabrir |
|---|---|---|---|---|
| SRC-01 | M1A Codex no recibió físicamente el ZIP de insumos; G0/G2 parcial | M1A informe y ZIP original de dirección | Pasar **un solo ZIP autocontenido**, verificar manifest antes de navegar; G0/G2 conciliados por director | RESUELTO; reabrir solo si nuevos archivos faltan |
| SRC-02 | 73 municipios confundidos con cobertura nacional | DIVIPOLA MGN2025 repo 1.104 códigos, 73 mapeos | Reutilizar universo de 1.104; 73 = semilla, no total de medidas | RESUELTO documental; version DANE más nueva requiere delta |
| SRC-03 | 219 combinaciones históricas confundidas con reglas activas | R13 y `M1_INPUT_COBERTURA_219_HISTORICA.csv` | Separar inventario, candidatas FULL, publicación y runtime enabled | VIGENTE; sin aceptación 219/219 |
| SRC-04 | 179 vínculos de fuente confundidos con 179 URLs | 93 IDs, 174 pares fuente–territorio, 179 observaciones; 5 pares duplicados | Preservar historial, normalizar relaciones, no borrar observaciones duplicadas | RESUELTO en datos semilla; reabrir ante nuevo delta |
| SRC-05 | Fuentes en varios municipios se extrapolaban sin probar ámbito | 8 IDs multi-territorio, 89 relaciones históricas | Competencia+territorio+vehículo explícitos antes de `FULL`; fuente compartida ≠ restricción compartida | GUARDRAIL activo |
| SRC-06 | HTTP 200 o link de alcaldía podía interpretarse como norma vigente | Registro antiguo sin snapshots SHA; revisiones parciales | Distinguir respuesta, emisor, publicación, vigencia y evidencia capturada | GUARDRAIL activo |
| SRC-07 | Sin resultado, 404 o 403 puede derivar en «sin pico y placa» | Semilla `NOT_SEARCHED` y casos sin URLs | Solo negar medida con declaración oficial vigente para territorio/vehículo/periodo | GUARDRAIL activo |
| SRC-08 | Investigación enfocada en decretos detenía actualizaciones | Solicitud del propietario y contrato del agente | Aceptar comunicado o calendario oficial completo; escalar a decreto si contradicción/campo material falta | DECISIÓN de producto vigente |
| SRC-09 | Fecha de corte `staleAfter` confundida con fin de norma Medellín | R13/R18: `2026-11-10T05:00Z` | Separar TTL técnico de vigencia; no renovar sin prueba focal | ABIERTO P0: fuente oficial y prueba, sin activación automática |
| SRC-10 | Manizales/Cali/Barranquilla muestran medidas temporales, territoriales y suspensiones | Investigación de dirección previa, revisión pendiente para activación | Modelar período, polígono, suspensión, categoría; no extrapolar; validar publicación vigente | ABIERTO jurídico por ciudad |
| SRC-11 | Cambios de consulta disparaban trabajos y commits repetidos | Antipingpong requerido; `checked_at` cambia sin contenido | Checkpoint incremental; hashes del contenido capturado; distinguir NO_CHANGE de SOURCE_CHANGED | DISEÑO; probar en futura implementación |
| SRC-12 | Estado de los 101 WIP protegido con hash global divergente | R21/M1A; 82M+19 nuevos preservados | Gate de integridad individual **antes de integración**. No investigarlo de nuevo en M1B documental | ABIERTO de integración, fuera de M1B |
| SRC-13 | AOT PASS confundido con JNI, H4 focal con motor Android | R18 AOT, R19 H4, R20/R21 reportes | Conservar evidencia exacta de cada alcance; JNI físico y suite final aparte | ABIERTO runtime, sin pruebas repetidas durante investigación |
| SRC-14 | GitHub docs pueden confundirse con backend o agente desplegado | PR #79 Draft, PR #71 Draft, `AGENTS.md` canónico | Documentar contrato y ledger en PR #79; NO tocar root AGENTS, NO publicar código ni datos | DOCUMENTACIÓN ACTUALIZADA, agente NO desplegado |

## Regla para el siguiente lote

Antes de pedir otra tarea: comprobar `task_id`, `source_input_sha`, `prior_gate`, `code_head_sha`, fecha y dependencia. Reutilizar PASS si mismo insumo y mismo alcance; no reutilizar PASS de AOT como PASS de JNI, ni de documento como integración. Cuando un hallazgo se replique por la **misma** causa, corregir el contrato/flujo una vez, no abrir otra auditoría global. Cada nuevo registro tendrá ID, evidencia, gravedad, corrección, responsable y trigger.

El agente **lee y propone**. Laravel **valida y publica** solo con autorización. **PR #79 permanece Draft; release NOT_APPROVED.**