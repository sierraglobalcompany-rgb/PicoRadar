# PICO RADAR — AUDITORÍA DIRECTIVA DEL ZIP M1.3 · DIEZ PASADAS Y REENFOQUE

**Fecha de corte:** 2026-11-08, Colombia. **Director:** ChatGPT. **Estado anterior:** `M1_3_STATUS=PARTIAL_DISCOVERY`. **Conclusión:** aceptar el lote como **inventario trazable y descubrimiento parcial**, NO como investigación nacional terminada ni aptitud de publicación. **Release:** `NOT_APPROVED`.

## Evidencias primarias y alcance de la revisión

ZIP realmente adjunto: `PICORADAR_M1_3_DESCUBRIMIENTO_NACIONAL_EVIDENCIAS_UNICAS_20261108.zip`, 54.484 bytes, SHA-256 `97d2987ee96624a25be60db1dfa8f7c3123ec70256d958a681e3ff5dd5a8c7a8`. Con `zipfile.testzip` se verificaron 14 entradas, CRC correcto, manifiesto con 12 payloads, 12/12 tamaños y SHA-256 coincidentes. Manifiesto SHA256 `08fcf49201d159331a5cb77ea8099ee904b1a7b8d15ee74b8b12218ee5fd84fd` comprobado contra `MANIFEST.sha256`.

Datos auditados realmente en ZIP, no inferidos por reportes: `M1_3_COVERAGE_DISCOVERY.csv` 3.366 filas únicas `(divipola,vehicle_class)` con código de cinco dígitos, tres categorías por unidad; 1.122 códigos territoriales distintos. Estados: 3.356 `NOT_SEARCHED`, seis `OFFICIAL_PARTIAL`, dos `OFFICIAL_PARTIAL_TEXT_ONLY`, una `HISTORICAL_STALE_CONFLICT` y una `OFFICIAL_SOURCE_CONFLICT`. Ocho candidatas con `activation=false`, cero listas; 52 registros `SOURCE_CHECKS` pero SOLO 18 URLs no vacías distintas (una fila sin URL) (se reusa el mismo índice DANE y RUNT por departamento), 47 registros con SHA no vacío, **14 SHA únicos**. 33 índices administrativos ≠ 33 portales de movilidad demostrados. Matriz legal por municipio ≠ lista de restricciones vigentes.

**Error de denominadores hallado:** las ocho filas núcleo pertenecen a **cinco** ciudades (`05001 Medellín` dos, `11001 Bogotá` una, `13001 Cartagena` dos, `66170 Dosquebradas` dos, `50001 Villavicencio` una). El reporte dice 8/1.104 municipios investigados y 1.114/1.122 sin investigación, pero confunde filas clase con entidades territoriales. El conteo correcto de municipios con revisión vertical en este ZIP es **5/1.122 unidades**; quedan 1.117 unidades sin barrida vertical específica. Para el universo completo de clase: 3.356/3.366 `NOT_SEARCHED` y otras 10 filas con tratamiento de fuente parcial/conflicto, no diez reglas completas. El resultado histórico M1B `8/1.104` es una métrica de *filas núcleo* y no debe etiquetarse unidades.

**Limitación de independencia:** el ZIP no incorpora los 253.918 bytes DANE MGN2025 ni todos los cuerpos de 5 páginas oficiales; se confirman sus hashes y conteos **declarados en el informe**, no se reconstruye independientemente la extracción de DANE/RUNT a partir de las respuestas HTTP originales. Las capturas M1A/B fueron declaradas íntegras por Codex pero no se incluyen ambos ZIP completos para recomprobarlas aquí. WIP 101 `NOT_VERIFIED`; checkout original no inspeccionado por Codex; sin Git ni QA física.

## Diez pasadas, con resultado separado

| # | Control | Estado | Observación verificable | Corrección/acción |
|---|---|---|---|---|
| 1 | Integridad del paquete | **PASS** | SHA externo 54.484 bytes, 14 CRC, 12 SHA/tamaños | Conservar ZIP como evidencia de M1.3. |
| 2 | Unicidad de matriz | **PASS local** | 1.122 códigos únicos, 3.366 claves territorio×clase, cero duplicados | No confundir filas con investigación real. |
| 3 | Conteos municipales | **FAIL documental corregido** | Ocho filas núcleo en cinco ciudades; `1.114` pendientes del informe confunde unidad con fila | Usar 5/1.122 de revisión vertical, 1.117 sin revisión vertical. |
| 4 | Cobertura nacional | **PARTIAL** | 3.356 NOT_SEARCHED, cero candidatas activables; 33 índices no son autoridades | Siguiente lote se mide por nuevas investigaciones específicas, no índices. |
| 5 | Calidad de fuente/linaje | **PARTIAL** | 52 filas fuente, 18 URLs no vacías distintas, 14 SHA únicos; hashes de cuerpos no contenidos | Distinguir evidencia capturada de referencias/índices. |
| 6 | Competencia legal | **PARTIAL** | RUNT OT en 31/33 índices es candidato, no competencia ni medida | Fuente de autoridad por municipio/régimen. |
| 7 | Reglas núcleo | **PARTIAL** | 8/8 revisitadas, 0/8 completas/activadas; 2 incidencias fuera del núcleo | Resolver lagunas por ciudad, no recrear ocho fichas. |
| 8 | Verificación externa focal | **AVANCE MATERIAL** | Fuente oficial Cartagena 19-oct facilita horarios/festivos; Bogotá SDM cita decreto/perímetro; Medellín tiene GIS de vías exentas | Incorporar específicamente en delta M1.4, no activar por ello. |
| 9 | Protección WIP / no release | **PASS por alcance; WIP NOT_VERIFIED** | Sin code/JSON/DB/Git/ADB; temporales no eliminados por política | No eludir protección ni inferir hash de WIP. |
| 10 | Seis leyes y continuidad | **ACCION DIRECTIVA** | Antirruido/antiparches piden no repetir barridas; plan M1.3–M1.5 puede avanzar por bloques con n/N | Lote único sobre 5 ciudades previas + 12 nuevas y propuesta M1.4/1.5 sin publicación. |

## Contraste externo adicional del director — **no** es evidencia archivada en ZIP

1. DATT Cartagena, comunicado del **19 de octubre de 2026**, https://cartagena.gov.co/noticias/datt-refuerza-controles-invita-cumplir-el-pico-y-placa-cartagena : particulares/motos desde 05-oct-2026 hasta 22-ene-2027, rotación lun 1/2 mar 3/4 mié 5/6 jue 7/8 vie 9/0, particulares 07–09 y 18–20, motos 05–23, sin festivos y con disposiciones especiales. Esta fuente accesible mejora el informe que solo disponía de página OCT vía 403; no demuestra por sí sola polígonos completos o todas excepciones.
2. DATT taxi Cartagena, https://cartagena.gov.co/noticias/esta-nueva-rotacion-pico-placa-para-taxis-cartagena-1 : el comunicado de 04-nov contiene literalmente «martes 02 de noviembre de 2026», discrepancia con calendario real, 2-nov fue lunes. El boletín 04-ene `https://cartagena.gov.co/noticias/cartagena-adopta-nueva-rotacion-pico-placa-para-taxis-partir-este-lunes-5-enero` aporta contexto legal de festivos, madrugada y excepciones, sujeto a modificaciones posteriores. No corregir automáticamente la fecha ni activar taxi.
3. SDM Bogotá `https://www.movilidadbogota.gov.co/preguntas-frecuentes/en-que-consiste-la-restriccion-establecida-para-vehiculos-particulares` (actualización 16-oct-2026): restricción por fecha par 1–5 e impar 6–0, urbano, 06–21, Decreto 652/2025 arts. 227–230; regional de ingreso tiene reglas distintas. Es evidencia mejor que inferir restringidos por complemento de habilitados.
4. Medellín `https://www.medellin.gov.co/giscatalogacion/srv/api/records/2d9cb19a-e7c7-4e1d-8a38-fb055997b043` identifica vías exentas II-2026 y Decreto 1490/2026; el dato GIS abierto CC BY-SA no equivale a haber ingerido geometría validada.

No se ejecutó actualización de datos productivos, ni se obtuvo autorización de GO. Revisar licencias/atribución antes de redistribuir bases o capturas, y no copiar textos largos de terceros.

## Decisión única y plan de finalización

**M1.3 queda `PARTIAL_DISCOVERY`**; no más rondas de índices DANE/RUNT. **M1.4/M1.5 focales pueden empezar con evidencia oficial suficientemente completa**, aun mientras otras unidades permanezcan `NOT_SEARCHED`. Ruta: (1) un lote de cinco ciudades existentes y doce capitales nuevas por código DIVIPOLA, informando cada cambio sobre baseline y faltantes; (2) decisión humana por regla completa y compilación Laravel única desde fuente aprobada; (3) M2 agente lector/proponente y motor reutilizado; (4) M3 sincronización Flutter y cámaras; (5) M4 CI SHA final, WIP, Android físico/JNI, firma y GO humano. Ni datos `STALE` ni `UNKNOWN` autorizan a circular.

**TASK_ID propuesto:** `PICORADAR-M1-FUENTES-OPERATIVAS-17-CIUDADES-20261108-DIRECTOR`. El encargo no exige 17 reglamentos terminados ni inventa cobertura. **Control de éxito:** 12/12 ciudades nuevas con investigación específica y prueba de consulta o bloqueo, ocho candidatas núcleo con matriz de doce campos; `activation=false` siempre. Un único ZIP, SHA/CRC/manifiesto, sin code push, merge, producción o herramientas físicas. **Siguiente actor al terminar: ChatGPT.**