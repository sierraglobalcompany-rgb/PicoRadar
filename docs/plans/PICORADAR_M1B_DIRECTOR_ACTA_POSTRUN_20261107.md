# PicoRadar — Acta director post M1B V2 (2026-11-07)

**Origen:** Codex `PICORADAR-M1B-V2-SOURCE-RESEARCH-20261107-DIRECTOR`, ZIP SHA-256 `a7efa9a40bb2a273b2bd474e8166c5cae87ad297d85f51617897726464ecf991`.
**Cierre:** M1B PARTIAL ACEPTADO EN SU ALCANCE; 8 jurisdicciones revisadas, 15 combinaciones `OFFICIAL_PARTIAL`, 4 URLs oficiales nuevas, 9 aperturas directas, 6 evidencias históricas reutilizadas, 1 403, 1.096 municipios sin investigar, 1.104 en cola. G0/manifest 11 de 11 PASS. Cero cambios de código, GitHub o producción. `RELEASE=NOT_APPROVED`.

## Corrección material del director: 0 FULL no equivale a 0 reglas publicadas

Se contrastaron independientemente mediante portales oficiales **8 reglas núcleo** para cinco ciudades:
- Medellín (car/moto): página oficial 2026-II contiene parejas lun 5/8, mar 1/4, mié 0/2, jue 3/6, vie 7/9; 05–20; desde 03-ago-2026. **M1B reportó dígitos UNKNOWN, error de extracción**. Ver https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre
- Bogotá (car): calendario noviembre, 06–21, regla ordinaria pares/impares; regional festivo separado. Ver https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-bogota-vehiculos-particulares-1-30-de-noviembre-de-2026
- Cartagena (car/moto): 05-oct-2026 a 22-ene-2027, pares 1/2,3/4,5/6,7/8,9/0; horarios distintos y festivos excluidos. Ver https://cartagena.gov.co/noticias/cambia-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena-0
- Dosquebradas (car/moto): desde 28-sep, pares 0/1,2/3,4/5,6/7,8/9, 06–20. Ver https://dosquebradas.gov.co/web/dosquebradas/ciudad/sala-de-prensa/noticias/303-vigencia-2026/10128-dosquebradas-retoma-desde-este-lunes-el-pico-y-placa-tradicional
- Villavicencio (car): 26-ene a 22-dic, lun 5/6, mar 7/8, mié 9/0, jue 1/2, vie 3/4, 06:30–09:30 y 17–20. Ver https://villavicencio.gov.co/con-jornadas-pedagogicas-inicio-el-pico-y-placa-2026-para-vehiculos-particulares-en-villavicencio/

**Ocho núcleos editoriales NO implican ocho reglas listas para producción.** Se mantienen tres ejes distintos: `core_rule_evidence`, `exceptions_and_geography`, `runtime_publication_approval`; todos los elementos conservan `activation=false`, `RELEASE=NOT_APPROVED`. Quedan por revisar excepciones, geometría, temporalidades y compatibilidad del motor; no exigir decreto íntegro cuando comunicado oficial basta para la regla principal.

## Antifalsos positivos y hallazgos preservados

- Siete candidatas reutilizaron evidencia sin `exact_url_consulted_this_run`, pero tienen `checked_at_colombia` igual a la hora de generación: NO usarlo como frescura de apertura de fuente. Separar `source_opened_at`, `source_reused_from`, `report_generated_at`.
- La página de Medellín mezcla sección II-2026 con FAQ histórico 2022: leer solo el periodo pertinente; `staleAfter=2026-11-10T05:00Z` es editorial y no debe extenderse a mano.
- El boletín taxi Cartagena noviembre dice “martes 02” aunque 02-nov-2026 fue lunes/festivo; no activar hasta conciliación.
- `candidate_status` histórico conserva valores `NOT_SEARCHED` para registros cuya columna `m1b_status` indica revisado. En vistas nuevas elegir **una sola columna vigente** y preservar la original como `upstream_status`, sin mutar el ZIP previo.
- SHA vacío del cuerpo fuente significa **sin bytes archivados**: no producir hash falso de la respuesta oficial.

## Próximo trabajo M1C — código focal SIN publicación

**Siguiente orden:** `CODEX_LUNA_PICORADAR_M1C_LOTE_FOCAL_20261107.md` dentro del paquete binario `PICORADAR_M1C_DIRECCION_Y_ENTRADA_UNICA_20261107.zip`, SHA-256 `f11c62efbac1913743ef17f66d1fa6cef0566cc914d94cdf2cce5f2548efd19a`. El archivo de prompt dentro tiene SHA-256 `60297f4841e044b4c0c7896ae58657adeabdc96d37b9d81c2cc4474e3aec0596`.

M1C no busca de nuevo todos los municipios: **compara 8 núcleos con el generador real y el runtime**, cierra los que ya coincidan y prepara ajustes mínimos solo donde haya discrepancia; no activar nuevas reglas por simple conteo, no modificar originales/WIP, no push/merge, no AOT/CI/JNI/QA física de nuevo. Entregar exactamente un ZIP de resultados.

Las otras siete candidatas necesitan únicamente investigación de vacíos puntuales. El universo nacional 1.104 y la semilla 73 siguen pendientes de investigación e integración por fases M1/M2; **no declarar cobertura nacional terminada**. La secuencia aprobada continúa M1 resto de fuentes → M2 motor/agente lector → M3 Laravel/Flutter/cámaras/usuarios opcionales → M4 CI/Android/firma/release.

**Continuidad:** PR #79 abierto Draft contra `recovery/20261019-modern`; PR #71 abierto Draft antiguo, sin cadena local R19/101 WIP; `AGENTS.md`, dos DOCX, seis leyes y `docs/CURRENT.md` tienen precedencia. Este documento es registro de dirección, no autoriza despliegue ni cambios automáticos de producto.
