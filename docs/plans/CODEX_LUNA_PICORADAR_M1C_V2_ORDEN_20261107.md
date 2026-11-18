# CODEX LUNA — PICORADAR · M1C V2 ALINEACIÓN FOCAL REPRODUCIBLE (SIN PUBLICACIÓN)

**Única orden operativa** `PICORADAR-M1C-CORE-RULES-FOCAL-20261107-DIRECTOR` · revisión V2. Esta V2 reemplaza la anterior SOLO si no comenzó; si M1C V1 ya tiene G0 PASS y avanza, NO interrumpir ni relanzar. **Versión** 2026-11-07; sustituye cualquier propuesta de reejecutar M1B. **Director técnico y aprobador:** ChatGPT. **Ejecutor:** Codex Luna, sin autonomía para cambiar criterios de producto, arquitectura, fechas, excepciones o permisos. **Entrega:** exactamente UN ZIP de evidencias. **Estado release:** NOT_APPROVED.

## 0. Propósito, fuentes y cierre real

La investigación M1B V2 terminó con 8 ciudades revisadas, 15 candidatas parciales, 0 declaradas FULL, 93 fuentes y 1.104 DIVIPOLA intactos. El director contrastó en portales oficiales **8 reglas núcleo** suficientemente publicadas para **comparación editorial focal** (no publicación automática ni ocho correcciones obligatorias). Lo publicado no demuestra que el sistema tenga representación correcta para todas las excepciones. No aceptar otro lote que solo mida ZIP, vuelva a auditar 101 WIP o reabra pruebas AOT.

Entrada binaria única: ZIP de esta orden. Contiene:
- `inputs/PICORADAR_M1B_V2_RESULTADO_EVIDENCIAS_20261107.zip`: evidencia real original, SHA-256 `a7efa9a40bb2a273b2bd474e8166c5cae87ad297d85f51617897726464ecf991`;
- `M1B_DIRECTOR_CANDIDATES_15_FOCAL_REVIEW.csv`: diagnóstico director por municipio×categoría, 8 `CORE_RULE_OFFICIAL_BULLETIN_VERIFIED` y 7 sin cerrar;
- `AUDITORIA_DIRECTOR_M1B_10_PASADAS_20261107.md`: fuentes oficiales, hallazgos y límites;
- este prompt; manifiesto y su SHA. **No exigir otros 19 archivos sueltos.**

**Regla de transferencia:** recibe el ZIP físicamente como adjunto o ruta real comunicada. El ZIP incluye también el R21 V2 original (solo referencia forense) y `FUENTES_PRIMARIAS_VERIFICADAS_M1C.md`; no volver a pedirle al director estos archivos. No suponer `Downloads`, disco, nombre de usuario ni archivos invisibles. Buscar acotadamente una sola vez entre adjuntos/ruta comunicada; validar SHA externo, CRC y manifest una vez, más los SHA individuales de los dos ZIP anidados. Validar el SHA externo contra el mensaje de entrega, no contra un campo `upstream_*` que identifica otro ZIP. Si G0 PASS, no repetirlo. Si falla, `INPUT_ATTACHMENT_REQUIRED` con ruta real, no falsos trabajos.

## 1. LEYES Y GATES ANTES DE ESCRIBIR

1. Leer `AGENTS.md` real de PicoRadar, luego `docs/CURRENT.md`, `docs/DESIGN_CONTRACT.md`, `docs/SOP.md`, `PicoRadar_RECOVERY_HANDOFF.md` y las dos DOCX de baseline (`docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`, `12_Arquitectura_Tecnica_Android_First_v1.docx`) cuando aplique.
2. Buscar y leer también `AGENTS.override.md` si existe y las seis leyes originales de implementación y ley antirruido en el workspace original (`D:\Codex\_work\PP-F3-20261024\PingPongLaw\docs\engineering\LEYES_IMPLEMENTACION_1_A_6.md` si existe). SHA-256 histórico de las seis leyes R21: `be3caa63d29685c07ba657764c82d8ba47414391b2ec095b31e608c19e4f2c8d`. Su ausencia se informa: NO reconstruirlas ni inventarlas ni declarar cumplimiento completo de leyes que no se hayan leído. Jerarquía: seguridad/privacidad > baseline > arquitectura > flujo funcional > design/UI > CURRENT > documentos de este paquete.
3. Invariantes: Flutter + Riverpod + go_router + Drift, Laravel único publicador, reglas locales versionadas, sin GPS continuo al servidor, sin cuenta obligatoria, sin Waze propio ni nuevas dependencias/microservicios. No activar ads/cloud premium, firma, producción ni usuarios. Mantener las 101 rutas WIP protegidas y su estado (82 modified/19 untracked); NO tocar teléfono Mi A3, Hostinger ni PR #71.
4. Mantener `main`, PR #71, PR #79, los originales C:/D:/, servicios y datos intactos. Prohibidos `push`, merge, deploy, force, restore, clean, reset, stash, instalación Android, cambios de reloj, updates de CI y habilitar monetización. Trabajar en clon nuevo **aislado** en `D:\codex\_CANDIDATOS\PicoRadar-M1C-Core-20261107` solo si NO existe; si existe, detener y reportar opciones. No usar worktree con .git enlazado al original. `git clone --sparse --no-hardlinks` desde una fuente local aprobada, retirar `origin` al crearlo. En el clon incluir solo carpetas necesarias `mobile`, `server`, `data`, `docs` mediante sparse-checkout; para scripts de generación fuera de sparse usar primero `git show HEAD:ruta` y `git ls-tree -r --name-only HEAD`, **no** concluir que no existen por `rg` sin resultados. Evitar materializar, ejecutar o editar `scripts/tests/test_hostinger_installer_browser.ps1`. Si para corregir hay que exponer scripts enteros y no es posible hacerlo de manera focal segura, bloquear solo el cambio afectado. No confiar en un checkout dirty de R15; no usar `git -c safe.directory=*`; confianza solo de proceso/ruta exacta si necesario. Sin remotos al finalizar.
5. Verificar `HEAD`, ascendencia y procedencia. PR #71 remoto Draft en `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`; candidato H4 local R19 `1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c` posterior a checkpoint WIP `0e9b0f2...` y corrección Cartagena `91c1a8f...`. No asumir que el SHA remoto incluye el trabajo local. Anclas R21: HEAD H4 `1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c`, árbol `dc2f2fdc5521af4cb4ad16969d76248b1e021688`, y ancestros exactos `0d3a6a2...` → `0e9b0f2...` → `91c1a8f...` → H4. Leer `GIT_PROVENANCE.json` del ZIP R21 y contrastar localmente antes de editar. No usar como fuente principal el PR #71, cuyo HEAD está antes del WIP de 101 rutas. Si no es posible demostrar que la fuente aprobada preserva 101 WIP e H4, **NO implementar ni intentar cherry-pick parcial**: producir plan exacto de rutas/generador y reporte, continuar la auditoría comparativa de datos, marcar código `BLOCKED_BASE`.
6. AOT R18 PASS solo para build; H4 R19 PASS focal; R20 R21 históricos; M1A G0/G2 reconciliados; M1B esta evidencia. NO ejecutar ni repetir Gradle, Flutter suite completa, emuladores, APK, JNI, SQLite full, Laravel full, scripts Hostinger, 10 auditorías previas o WIP profundos. Las validaciones nuevas deben responder al delta específico. No invertir tiempo de tokens en recontar 1.104 municipios tras G0, 93 fuentes, 101 WIP. Los hashes R21 son evidencia histórica de procedencia, NO autorización para publicar 101 archivos aún no revisados en profundidad.

## 2. Clasificación jurídica dirigida por el director

No cambiar el CSV M1B original ni sus 15 `OFFICIAL_PARTIAL`. Para cada una de las 8 filas `CORE_RULE_OFFICIAL_BULLETIN_VERIFIED` del nuevo CSV, producir tabla comparativa `M1C_CORE_ENGINE_COMPARISON.csv` con:
`divipola, vehicle_class, official_document_url, effective_from, effective_until_if_explicit, schedule_type, restricted_digits, position, local_hours, holidays, area_type, exceptions_status, existing_generator_path, existing_runtime_rule_id, diff_kind, risk, next_action, proof_ref, runtime_asset_sha256, generator_dependency_direction, comparison_asof_local, safe_user_message`. Si campo no existe marcar `UNKNOWN`/`N_A` explicando por qué; no inventar datos.

**Reglas ya verificadas por director para evitar repeticiones:**
- Medellín `05001`: particulares último dígito y motos primer dígito, lun `5/8`, mar `1/4`, mié `0/2`, jue `3/6`, vie `7/9`, 05–20, desde 2026-08-03, II semestre 2026. Fuente oficial https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre . Omitir FAQ 2022 (está dentro de la misma página). Excepciones de vías y corregimientos requieren tratamiento independiente. `staleAfter=2026-11-10T05:00Z` no es fin legal: NO extender arbitrariamente, ni eliminar la advertencia de datos vencidos.
- Bogotá `11001`: particular, último dígito; calendario noviembre 2026, 06–21, lunes-viernes, impar CIRCULAN `1/2/3/4/5` (restringidos `6/7/8/9/0`); par CIRCULAN `6/7/8/9/0` (restringidos `1/2/3/4/5`). Festivos 02 y 16: pico REGIONAL de ingreso distinto; no aplicar regla ordinaria. Fuente https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-bogota-vehiculos-particulares-1-30-de-noviembre-de-2026 . No inferir diciembre.
- Cartagena `13001`: particular/moto, ambos por último dígito; 2026-10-05..2027-01-22, lun `1/2`, mar `3/4`, mié `5/6`, jue `7/8`, vie `9/0`; car 07–09 y 18–20, moto 05–23; festivos/fin de semana no aplica, salvo medida especial futura a verificar. Fuente https://cartagena.gov.co/noticias/cambia-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena-0 . Taxistas **NO** usar estos dígitos; hay conflicto de día/fecha en el aviso de noviembre.
- Dosquebradas `66170`: car último dígito, moto primero; 2026-09-28 en adelante sin fin explícito; lun `0/1`, mar `2/3`, mié `4/5`, jue `6/7`, vie `8/9`, 06–20. Fuente https://dosquebradas.gov.co/web/dosquebradas/ciudad/sala-de-prensa/noticias/303-vigencia-2026/10128-dosquebradas-retoma-desde-este-lunes-el-pico-y-placa-tradicional . No extrapolar a Pereira o Santa Rosa.
- Villavicencio `50001`: particular último dígito; 2026-01-26..2026-12-22, lun `5/6`, mar `7/8`, mié `9/0`, jue `1/2`, vie `3/4`, 06:30–09:30 y 17–20. Fuente https://villavicencio.gov.co/con-jornadas-pedagogicas-inicio-el-pico-y-placa-2026-para-vehiculos-particulares-en-villavicencio/ . Perímetro referido al 2025 aún por validar.

**Campos ausentes no inventables:** exenciones individuales, corredores exactos, zona/polígono, fin legal no indicado, cambios posteriores y taxis no documentados. La fuente oficial puede ser comunicado claro, NO exigir decreto íntegro por defecto. Separa tres estados: `CORE_PUBLISHED_AND_EXTRACTED`, `EXCEPTION_OR_PERIMETER_UNVERIFIED`, `RUNTIME_READY_ONLY_AFTER_TESTS_AND_DIRECTOR_APPROVAL`. Nunca confundirlos ni activar por alcanzar el primero. No inventar SHA de bytes del HTTP si solo se leyó HTML renderizado. **Contrastar calendarios con reloj `America/Bogota` y semántica de extremos de franja** (inclusive/exclusive según contrato existente); Bogotá depende del *día impar/par de calendario*, NO del último dígito par/impar. Cartagena tiene medida separada de acceso de motocicletas al centro amurallado y no debe fusionarse con su rotación general. El área metropolitana de Medellín NO autoriza propagar automáticamente sus dígitos a los 73 municipios o a otros municipios vecinos.

## 3. Ejecución práctica (un solo lote, sin arquitectura nueva)

**G1 — Descubrimiento técnico acotado de motor/generador (READ-ONLY):**
- **Reutilizar el hallazgo R21 antes de buscar:** `scripts/compile_pico_operational_catalog.py` genera `mobile/assets/catalogs/pico_jurisdiction_catalog_20261025.json` consumiendo `data/sources/restrictions/PicoRadar_Pico_y_Placa_Colombia_CONSOLIDADO_2026-09-10.xlsx` y `mobile/assets/datasets/restrictions/restrictions_v1.json`; **NO ES escritor del runtime**. R21 **NO identificó un writer reproducible** de `restrictions_v1.json`. Tratar como `GENERATOR_DIRECTION_KNOWN`, `RUNTIME_WRITER_UNKNOWN`; si otra fuente aparece, demostrar ruta + SHA + comando y resultados deterministas. No reexplorar toda la arquitectura ni declarar writer por el nombre del script.
- Desde clon aprobado localizar fuente normativa y generadores usando rutas concretas conocidas. Usar `git ls-tree -r --name-only HEAD` y `git show HEAD:scripts/compile_pico_operational_catalog.py` para conocer scripts aunque no estén materializados por sparse; después `rg -n -F` sobre lo visible. No gastar consultas exploratorias masivas. Listar rutas SHA y dirección de dependencias; no asumir que un JSON generado es autoritativo.
- Comparar 8 filas contra reglas reales de motor y su fuente, separando `ALREADY_MATCHES`, `VERIFIED_MISMATCH`, `NOT_IMPLEMENTED`, `CANNOT_REPRESENT_WITHOUT_ARCHITECTURE_CHANGE`, `BLOCKED_BASE`.
- **No modificar** los 7 candidatos restantes (taxi Medellín/Cartagena, Pereira, Popayán, Bucaramanga) ni abrir auditoría jurídica completa. Comparar también si ya hay reglas implementadas que no necesitan reescritura.
- Si hay conflicto entre baselines, seis leyes, fuente primaria y datos del paquete, detener SOLO la fila afectada, citar la fuente y continuar las otras.

**G2 — Cambio mínimo SOLO si justificado:**
- Solo implementar cuando existan **ambas pruebas**: (A) una discrepancia real observada para una de las 8 filas, y (B) un **escritor reproducible, aprobado y preexistente del artefacto a modificar** con comando real y fuente autoritativa. Si (B) falta para `restrictions_v1.json`, **NO parchear JSON**, NO confundir el compilador del catálogo con su generador, NO construir un writer nuevo automáticamente. Registrar `BLOCKED_RUNTIME_WRITER_NOT_FOUND`, ruta afectada y decisión mínima propuesta al director; continuar con las otras comparaciones. Si ya coincide, `ALREADY_MATCHES` sin commit. Solo regenerar derivados con comando del proyecto verificado, nunca editar salidas generadas a mano. No añadir librerías, jobs, tablas, servicios, capas, endpoints, otro motor ni esquema nacional.
- Para categorías con campo vital no representable (por ejemplo geofencing/polígono o excepción que cambiaría decisión), dejarla como candidato editorial no publicable, con prueba `unknown/stale` estable. No forzar falso verde ni crear workaround.
- Jamás resolver `staleAfter` Medellín cambiando una fecha a mano. Producir `MEDELLIN_TTL_DECISION.md`: evidencia de II-2026, estado técnico actual y política de expiración **propuesta, no aplicada**, con casos antes/durante/después del 10-Nov 00:00 Colombia. Cuando la política existente exija `stale`, conservar ese estado; sin extender TTL. Todo cambio de TTL requiere una autorización adicional del director.
- `git diff` limitado a rutas explícitas del lote y lo exigido por el generador/test; evitar reformatear 100 archivos, scripts Hostinger, tests no relacionados. Recuento pre/post de evidencia; no tocar originales.

**G3 — Validación focal:**
- Ejecutar los tests ya existentes de restricción/versiones que cubran las **rutas modificadas** y agregar solo los casos faltantes de `car/moto`, posición primer/último, días, festivos, ventanas partidas, transición de mes, zonas excepcionales y `staleAfter`. Para Bogotá test explícito: 03-Nov (impar) vs 04-Nov (par), 02/16-Nov festivos con medida regional separada, cruce 30-Nov/01-Dic = `UNKNOWN` si no hay fuente posterior. Para Cartagena test de moto centro amurallado separado del pico general; para Villavicencio `UNKNOWN` fuera del polígono hasta resolver geometría. Pruebas de `NO FALSE CLEAR` en cualquier región/fecha que carezca de evidencia. Ejecutar formato/analizador **solo del delta** si disponible. Si falta Flutter/Composer, marcar `NOT_RUN_ENV`, sin simular PASS; no instalar paquetes globalmente ni resolver dependencia con microservicio.
- Verificar idempotencia del generador en los archivos afectados (mismos insumos mismos bytes) y que no se alteren municipio/vehículo fuera de las ocho filas autorizadas. Para una regla que ya coincide, reutilizar SHA y test histórico **solo** si coincide fuente, código, insumos, entorno relevante y alcance; si hubo delta funcional, ejecutar tests focales afectados. No repetir suites globales por rutina, pero antes de release los gates completos sobre el SHA final siguen pendientes.
- QA físico/JNI/CI/servidor y firma se programarán en M4, no aquí. Si hubo cambios de código, NO declarar `RELEASE_PASS` por pruebas focales.

**G4 — Entrega y responsabilidad:**
- Dejar clon aislado sin remoto; si generó código, preservar el diff/patch no aplicado al original, sin push ni merge. Mantener el branch del clon por lote `fix/M1C-core-rule-alignment` si necesita commit local único; de lo contrario no hacer commit ornamental.
- Producir exactamente un archivo `PICORADAR_M1C_RESULTADO_EVIDENCIAS_UNICAS_20261107.zip`, con como mínimo `FINAL_REPORT.md`, `M1C_CORE_ENGINE_COMPARISON.csv` (8 filas si G1 permitió comparar todas; si bloqueo especificar filas reales y las restantes `NOT_COMPARED` sin inventar PASS), `M1C_SCOPE_CHANGE.csv`, `M1C_TEST_RESULTS.csv`, `MEDELLIN_TTL_DECISION.md`, `M1C_NEXT_PRIORITY.csv`, `AUDIT_10_FOCAL.csv`, `MANIFEST.json`, `MANIFEST.sha256`; incluir `PATCH.diff` solo si existe diff real y no contiene datos sensibles. Hashes, tamaño, CRC verificados. Todos los artefactos fuera del repo. Datos sensibles redactados, sin tokens, GPS exacto de usuario o placas reales.
- Los diez controles **no son diez suites**. Deben informar por separado integridad, base/HEAD, normas, ocho filas core, no regressions, fechas/excepciones, generador, test focal, preservación y próximo paso. Distinguir `PASS`, `PARTIAL`, `NOT_RUN`, `BLOCKED` con evidencia y SHA. Ninguna afirmación de QA física o release.
- Entrega final en chat: `TASK_ID=...`, `RESULT=...`, `CORE_RULES_COMPARED=<número realmente comparado entre 0 y 8>`, `CHANGED=...`, `ALREADY_MATCHES=...`, `BLOCKED=...`, `GITHUB_WRITES=NO`, `PROTECTED_WIP_UNCHANGED=...`, `RELEASE=NOT_APPROVED`, `NEXT_ACTOR=CHATGPT`, link **a UN SOLO ZIP** y SHA-256 real. Nunca envíes 12 Markdown dispersos.

## 4. Política de parada inteligente (sin ping-pong)

- Paquete presente, Git base aprobada y motor localizable: **ejecutar de principio a fin**. No pedir permiso por detalles mecánicos contemplados.
- Fuente legal ambigua: bloquear solo esa fila, no todo el lote.
- No hay base Git comprobable: no tocar código, producir comparación editorial de ocho filas y paths de reparación concretos sin repetir G0 ni pedir auditoría nueva.
- El candidato está limpio y todo ya coincide: cerrar como `M1C_NO_CODE_NEEDED`; NO forzar un cambio para justificar lote.
- No se puede representar sin romper KISS/baseline: `DESIGN_DECISION_REQUIRED`, evidencia exacta, sin parche.

**FIN DE ORDEN — solo CODEX LUNA ejecuta; ChatGPT revisa, decide y autoriza después.**


## 5. Anexo de ejecución del director — evitar nuevo ping-pong

### A. Cuatro escenarios exhaustivos por regla (exactamente uno)

| Estado | Evidencia mínima | Acción permitida | Gate de cierre |
| --- | --- | --- | --- |
| `ALREADY_MATCHES` | Fuente oficial + runtime ID/ruta + SHA y campos equivalentes | Ningún cambio | Reporte del match y prueba histórica solo si es comparable |
| `VERIFIED_MISMATCH_WRITER_FOUND` | Campo divergente + writer existente de runtime + test focal RED | Cambio acotado en fuente de verdad permitida, regenerar y GREEN | `PATCH.diff` reversible, idempotencia, 0 deltas ajenos |
| `BLOCKED_RUNTIME_WRITER_NOT_FOUND` | Divergencia real + R21/inspección confirma ausencia de writer seguro | Ninguna edición del JSON runtime; decisión de diseño concreta para ChatGPT | Reporte de ruta, alcance, campo, alternativa KISS, sin falsa activación |
| `BLOCKED_SCOPE_OR_SOURCE` | Fuente desactualizada, ámbito no representable o norma/horario ambiguo | Ninguna activación, conservar `unknown/stale` | Reportar dato exacto y prueba de no-falso-libre |

También existe `BLOCKED_BASE`: si el clon no prueba procedencia/H4, no abrir G2; únicamente comparación editorial no atribuida al runtime real. **No generar arquitectura nueva para salir de un bloqueo de fuente.**

### B. Criterios de evidencia por ciudad, sin repetir búsquedas

- Medellín: usar rotación semestral 2026-II; separar corredor exento, aeropuerto/túnel y corregimientos de la regla base; `staleAfter` técnico no es fecha legal. No extrapolar por área metropolitana.
- Bogotá: conservar franjas 06:00–21:00 y semántica por fecha impar/par, con lista **de los que CIRCULAN** invertida correctamente para obtener restringidos; regional festivo de ingreso no es regla ordinaria. No inferir diciembre.
- Cartagena: carros y motos en horario diferente, último dígito, calendario 05-Oct–22-Jan; moto centro amurallado y taxis son medidas **separadas**. Probar 07–09 y 18–20 en carros sin transformar en 07–20 continuo.
- Dosquebradas: último dígito carro, primer dígito moto, desde 28-Sep, sin fin explícito publicado. No copiar a Pereira ni a Santa Rosa.
- Villavicencio: ventanas 06:30–09:30 y 17–20; polígono heredado 2025 NO confirmado; no producir "sin pico y placa" fuera de ese mapa sin validar ámbito.

### C. Presupuesto de trabajo y límites concretos

- **No más de una** validación completa del ZIP; si PASS, trabajar en diferencias.
- **No más de una** exploración del árbol/rutas script; reutilizar `R21 GIT_PROVENANCE` y SHA. En caso de writer ausente STOP SOLO filas afectadas, no seguir 20 llamadas buscando otro nombre.
- **Cero** instalaciones globales, CI/Android/ADB/emulador/build AOT/suite completa/Hostinger en este lote.
- **Máximo un** commit local en rama exclusiva de clon, únicamente si hay cambios de código legítimos; no push ni PR de código.
- **Diez pasadas de auditoría son diez controles con hallazgos**, no diez suites ni diez recorridos del repositorio. Evidencia `NOT_RUN` cuando no se ejecutó.
- La fuente del director **NO autoriza** edición del runtime por sí misma; demostrar writer y contrato existentes.

### D. Plan completo de salida, sin prometer un release

`M1C` = comparación técnica y propuestas/corrección local de las ocho reglas si es posible. El director incorpora resultado al Plan Maestro en PR #79; **no mezclar documentación de dirección con rama de runtime**. A continuación continúa `M1` con los otros 1.096 municipios aún no investigados por M1B, y las siete categorías parciales; `M2` agente consultor incremental y motor nacional; `M3` sincronización Laravel/Flutter, cámaras y usuarios opcionales; `M4` CI real, revisión de 101 WIP, QA Android físico/JNI/firma y aprobación de publicación. No declarar cierre nacional por completar estas ocho.

### E. Entrega obligatoria única

Un único ZIP con SHA-256 externo, CRC, manifest de bytes y hashes, reporte de `HEAD` y árbol, `8` filas de inventario con estados honestos, correspondencia a IDs reales, pruebas focales ejecutadas/no ejecutadas, `MEDELLIN_TTL_DECISION.md` y `AUDIT_10_FOCAL.csv`. **Nada de enlaces a rutas de D: sin adjuntar el ZIP real en el chat.** Si hay bloqueo, no devolver otro prompt: adjuntar resultado `PARTIAL` con propuesta de decisión cerrada, para que ChatGPT decida una sola vez.