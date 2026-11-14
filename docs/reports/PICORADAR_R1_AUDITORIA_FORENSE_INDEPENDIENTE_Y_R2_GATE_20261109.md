# PICORADAR — AUDITORÍA FORENSE INDEPENDIENTE R1, DECISIÓN Y REENFOQUE R2

**Fecha de corte:** 2026-11-09, Colombia. **Auditor:** ChatGPT director técnico. **No se ejecutó PHP/Flutter en este entorno**; la evidencia de ejecución procede de logs de Codex. La inspección de bytes ZIP, hashes, contenido JSON y diff, así como la comparación de datos conservados contra el repo remoto y fuentes oficiales, fueron independientes. **Ninguna auditoría documental equivale a QA Android ni permiso de publicar.**

## Identidad exacta de la entrega

- ZIP recibido: `PICORADAR_R1_BOGOTA_NOV2026_REAL_E2E_EVIDENCIA_UNICA.zip`, **36.259 bytes**, SHA-256 `52b8e0b8a9b5affba66da1e7cfb6f08343f7ab899a8afe44c1ce11feece8b02d`.
- `TASK_ID=PICORADAR-R1-BOGOTA-NOV2026-REAL-END2END-20261109`; `RESULT_CODEX=PASS_SCOPED_REAL_E2E` (dictamen de Codex, no propio de producto).
- 20 miembros ZIP, CRC PASS; `MANIFEST.json` 18/18 miembros, hashes y tamaños PASS, `MANIFEST.sha256` correcto. Sin rutas traversal detectadas.
- Commit **local** declarado `da9d8083bb21bd7c9863a319e07de51a5e692d09`, rama `feat/PICORADAR-R1-bogota-nov2026-real-e2e`, sobre `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`. **No hay prueba de push ni que ese commit esté en GitHub**. PR #71 sigue Draft HEAD `0d3a6a2…`, PR #79 sigue Draft documental. No inferir WIP local completamente preservado; los 101 paths históricos no estaban materializados.
- `GIT_DIFF.patch` 10 archivos: **seis Dart de presentación + 2 Dart tests + PHP test + JSON fixture**. No se modifica motor Flutter, importador Laravel, dataset bundled, configuración de red ni versión en uso. Nuevos archivos reconstruidos del patch tienen SHA256 idéntico al `CHANGED_FILES_SHA256.csv` (5/5), pero cambios de archivos preexistentes no fueron ejecutados ni aplicados independientemente aquí.

## Diez pasadas forenses (trabajo ejecutado y resultado)

| ID | Trabajo de auditoría | Resultado / límite |
|---|---|---|
| F01 | Verifiqué ruta física del ZIP, tamaño, SHA256, índice y CRC. | **PASS**, 36.259 bytes, 20 miembros. |
| F02 | Recalculé todos los tamaños y SHA256 contra `MANIFEST.json` y luego el hash de ese manifiesto contra `MANIFEST.sha256`. | **PASS** 18/18 y 1/1. |
| F03 | Abrí el release y manifest Laravel; contrasté SHA de bytes release, entrada manifest, versión y esquema. | **PASS** `r2-d0ac10fe5cba`; SHA release `315f6d81bf5a90b24e77d2d639f9774b67c996add29fa11101d1450c846c272a`; esquema 1. |
| F04 | Verifiqué directamente la fuente Bogotá oficial y la FAQ SDM (paridad, 06–21, festivos 2/16). Comparé `BOGOTA_NOV2026_DATA_DEFINITION.json` con la cobertura publicada. | **PASS jurídico focal**. Fuente de particular urbano, NO retorno regional/permiso personal. Definición y cobertura coinciden exactamente. |
| F05 | Comparé 8 unidades inmutables del release (6 otras ciudades + Bogotá taxi + moto known-empty) contra la fuente `restrictions_v1.json` del SHA PR71 usando serialización recursiva canónica y FNV-1a 64 bits calculado separadamente en dos entornos. | **PASS de contenido** 8/8; FNV es fingerprint auxiliar, no sustituye SHA de la entrega. Las dos reglas de carro particular son la única modificación de cobertura. |
| F06 | Revisé el patch y los hashes de 10 archivos; reconstruí 5 nuevos byte a byte desde diff y comprobé sus SHA256; el diff no escribe release en datos activos. | **PASS de integridad 5/5 nuevos**. **LÍMITE MATERIAL:** usuario real / APK siguen con bundle obsoleto hasta que exista distribución del release. |
| F07 | Contrasté `PHP_FINAL_FOCAL.log`, tests PHP y procedimiento `Storage::fake`, SQLite memoria; comprobé que el test genera release y manifest antes de exportar. | **PASS_LOG_REPORTED**: 11 pruebas/53 aserciones, sin ejecución propia. Baseline de laboratorio, no BD real. |
| F08 | Contrasté logs Flutter, test HTTP localhost exact bytes y pruebas UI; comprobé la posibilidad de skip condicionado al entorno. | **PASS_LOG_REPORTED**: 497 casos focales y 5 R1 tras refactor, sin pruebas propias. **CI gate insuficiente** si `PICORADAR_R1_EVIDENCE_DIR` no está definido: tests E2E se omiten. |
| F09 | Leí cambios de Trip `TripInstantEndpoint` y helper `bogotaUrbanRestrictionScopeNotice`. El helper filtra jurisdicción/servicio/fecha, **NO VehicleKind**; Trip no le entrega especie. | **DEFECTO P1 ESTÁTICO**: una moto privada en Bogotá puede recibir aviso de pico urbano diseñado para carro. Home/Detalle sí filtran carro. Agregar tipo carro a helper y Trip, test negativo moto privada. |
| F10 | Reconcilí estado GitHub, logs de herramientas, no ejecución Android/CI, y medí valor de producto vs. test. | **R1_LAB_E2E_ACCEPT_SCOPED**; **R1_PRODUCT_INTEGRATION=NOT_ACCEPTED** (sin runtime distribuido, sin QA físico); `NEXT=CODEX` para un solo lote R2 con reparación y taxi Bogotá oficial. |

## Evidencia comprobada, límites y decisiones del director

### Qué SÍ se acepta
- El enlace técnico real en laboratorio **PHP Laravel → release & manifest → bytes SHA idénticos → HTTP loopback → DatasetSyncService → Drift → motor y widgets** se ejecutó según logs, y el artefacto exacto comprobado está en ZIP. Esto **supera** un puente solamente sintético, aunque no sustituye un dispositivo.
- El publicador reemplaza la jurisdicción completa, pero el nuevo test conserva las 3 coberturas de Bogotá y las otras seis ciudades. Los 8 subconjuntos preservados se compararon con GitHub independientemente.
- Laravel `11/53`, Flutter `497` y re-test R1 `5` constan en logs; `flutter analyze`, formato, Pint constan como PASS reportados. No existen nuevos errores de sintaxis evidentes en el diff inspeccionado.
- Fuente oficial particular: https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-bogota-vehiculos-particulares-1-30-de-noviembre-de-2026 ; autoridad SDM: https://www.movilidadbogota.gov.co/preguntas-frecuentes/en-que-consiste-la-restriccion-establecida-para-vehiculos-particulares .

### Qué NO se acepta como completado
- **No hay actualización del dataset activo de Flutter**, ni publicación remota Laravel, ni APK nuevo, ni push del commit, ni evidencia de instalación/distribución. La cobertura nueva existe en **fixture de prueba y release local**. Un usuario de PicoRadar no ha obtenido esta actualización por este lote.
- **Defecto P1 Trip/motos**: con `jurisdictionId=co-dc-bogota`, `serviceType=private` y noviembre 2026, el helper devuelve aviso aunque el vehículo sea moto. Faltan `vehicleKind` en contrato y test negativo para Trip. No reescribir motor ni hacer una advertencia global genérica.
- **CI verde no probará necesariamente E2E cross-stack**, pues el test tiene skip condicional para `PICORADAR_R1_EVIDENCE_DIR`. Hay que forzar a los scripts de QA del lote que produzcan y pasen el release exacto, verificar que no haya skips en la prueba obligatoria y no declarar CI validada sin CI real.
- **Original root WIP 101**, CI Actions, QA física Mi A3, APK, firma JNI, privacidad y publicación siguen **NOT_VERIFIED / NOT_RUN**. `flutter pub get --offline` falló por Developer Mode/symlink; tests posteriores usaron caché `--no-pub`.
- Noviembre 2026 es una ventana legal finita; **no** extender diciembre inventando rotación. `staleAfter` del particular R1 01-dic-2026 05:00Z es una política editorial técnica, no prueba nueva de norma 2027.

## Siguiente bloque nacional que realmente añade cobertura: R2 Bogotá taxis + corrección P1

**Fuente oficial nueva del director**, publicada 04-nov-2026: https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-para-taxis-en-bogota-del-1-al-30-de-noviembre-de-2026 . Taxi `car/taxi`: lunes a sábado **05:30–21:00**, último dígito, no domingos/festivos. La fuente especifica **23 fechas** de noviembre con un par restringido por fecha; NO usar paridad diaria del particular ni asumir que la rotación salta solo días hábiles. Los festivos son 2 y 16 de noviembre. Vehículos de transporte especial NO se convertirán a taxi por coincidencia temporal.

**Un solo lote para Codex con nuevo TASK_ID:** `PICORADAR-R2-BOGOTA-TAXI-NOV2026-AND-R1-SCOPEFIX-20261109`. Debe:
1. Partir del commit local de R1 si y solo si verifica su SHA, sin tocar WIP ni reejecutar M3-X01.
2. Corregir el defecto del aviso de moto en Trip, con test negativo obligatorio.
3. Implementar **segunda cobertura oficial real** (`car/taxi` nov 2026) en el publicador Laravel aislado, SIN perder car/private R1 ni moto known-empty ni seis otras ciudades, SHA real/manifest/Flutter/Drift/UX.
4. Demostrar R2 entrega funcional en entorno de prueba, dejar explícito que no hay app/Hostinger publicada; crear commit y push normal a rama de código nueva SOLO si los gates remotos/permisos/coste se verifican sin riesgo. Jamás merge, deploy o publicación automática.
5. Entregar **UN ZIP único** con tests, SHA, fuente, JSON exacto, manifest, diff, QA físico si realmente se realizó y reporte de bloqueos; `NEXT=CHATGPT_DIRECTOR`.

**Puertas nacionales sucesivas:** R2 taxis Bogotá; luego lote Medellín carro+moto (norma 1490/2026 autenticada y ámbitos exentos), Cartagena (moto nocturno/24h pendiente), y servicio especial/carga en contratos separados. Conservar M1 legal y el catálogo 73/219 como base; no convertir `UNKNOWN` en `ALLOWED`. El objetivo sigue siendo cobertura nacional, no 31/55 documentos.

**DICTAMEN:** `R1_EVIDENCE_INTEGRITY=PASS`, `R1_LAB_E2E=PASS_SCOPED_REPORTED_AND_STRUCTURALLY_CORROBORATED`, `R1_UI_TRIP=P1_FIX_REQUIRED`, `R1_PRODUCT_RELEASE=NO`, `NEXT_ACTOR=CODEX_LUNA_FOR_R2_WITH_FIX`.
