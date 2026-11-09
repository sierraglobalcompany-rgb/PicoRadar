# PicoRadar — Auditoría forense M1.4 y decisión de continuidad sin ping-pong

**Fecha:** 2026-11-09 (America/Bogota). **Director:** ChatGPT. **Estado de entrada:** `LEGAL_FIVE_PARTIAL_EVIDENCE`, `RELEASE=NOT_APPROVED`, `PUBLISH_ALLOWED=NO`. **ZIP examinado:** `PICORADAR_M1_4_CIERRE_LEGAL_5_FILAS_EVIDENCIAS_UNICAS_20261108.zip`.

## 0. Identidad verificable

- ZIP real: **18.131 bytes**, SHA-256 **`54e1e12d71384e77d1365cefee110b95c300caa8e36ff20acce9c629f5b10cd7`**, 12 entradas, `ZipFile.testzip() = None`.
- `MANIFEST.json`: 10 miembros de contenido, todos comprobados por tamaños y SHA-256. `MANIFEST.sha256`: 11 entradas; hashes cotejados, incluyendo el propio manifiesto JSON. No se inventa hash del ZIP dentro del ZIP.
- Cinco claves únicas: `05001/car-private`, `05001/motorcycle-private`, `11001/car-private`, `13001/car-private`, `13001/motorcycle-private`.
- `SOURCE_CLAIM_MATRIX.csv`: **33 afirmaciones únicas** (`claim_id` sin duplicados), **28 filas con URL, 12 URL exactas distintas**; **22 filas con campo de SHA de cuerpo y 9 SHA distintos**. **Los cuerpos brutos no están en este ZIP**, por lo que no se validó el contenido de esos 9 SHA con capturas originales. Este límite es material y NO se llama PASS de fuentes.
- `TEMPORAL_EDGE_CASES.csv`: 12 escenarios **documentales**, no pruebas del motor Flutter; 1 escenario de corte técnico de alta certeza, 11 escenarios parciales/índice/UNKNOWN. 13 brechas: **7 P0, 6 P1**.
- `GIT_AND_WIP_STATUS.txt`: reporte de Codex sobre checkout protegido HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, borrado histórico `scripts/tests/test_hostinger_installer_browser.ps1`, WIP 101 **NOT_VERIFIED**. No se certificó localmente el filesystem del equipo de Codex.

## 1. Diez pasadas y resultado individual

| # | Comprobación | Resultado | Dictamen independiente |
|---|---|---|---|
| 01 | Integridad ZIP | **PASS** | 18.131 bytes, SHA exacto, 12 CRC correctos. |
| 02 | Manifiestos | **PASS** | Diez hashes/tamaños internos correctos, 11 líneas checksum correctas. |
| 03 | Claves y alcance | **PASS** | Exactamente cinco parejas únicas DIVIPOLA/clase; no se incluye Bogotá moto ni taxi Cartagena como regla lista. |
| 04 | Reglas activas/READY | **PASS de bloqueo** | `ready_for_director_review=false`, `activation=false` para las cinco. Cero aptas para publicar. |
| 05 | Afirmaciones y capturas | **PARTIAL** | 33 `claim_id` distintos, 12 URL, 9 hashes de cuerpo únicos; no se adjuntaron los bytes de capturas para validación externa. |
| 06 | Pruebas temporales | **PARTIAL** | 12 filas de casos/expectativas, no 12 tests de motor ejecutados. Incluye incertidumbre explícita de extremos. |
| 07 | Brechas P0/P1 | **PASS diagnóstico / BLOCKED legal** | 7 P0 + 6 P1. Faltan decretos/anexos, alcance territorial y elegibilidad específica. Prohibido inferir ALLOWED. |
| 08 | Contrato de gobernanza | **CORREGIDO DIRECTOR** | `GAP-CONTRACT` no representa un documento inexistente: Plan Maestro y contrato del agente están en PR #79, rama `docs/plan-maestro-nacional-v2-20261107`, aunque no integrados a checkout original. No reiterar un 404 en una rama equivocada. |
| 09 | Fuentes públicas actuales | **AVANCE REVISIÓN / NO CERTIFICACIÓN FINAL** | Portal oficial Medellín para exenciones y cartografía; Cartagena para reglas/permiso, Bogotá SDM y decreto. Gaceta 5885 identificada por índice externo, copia de Decreto 0015 disponible en tercero: ambos requieren autenticidad de fuente oficial antes de elevarlos a gate legal. |
| 10 | L1–L6, WIP y ruta | **PASS de decisión, QA pendiente** | Sin cambios a Flutter/Laravel/JSON, sin publicación; evitar otro lote de lectura idéntica. Cambiar método de adquisición de evidencia, no endurecer reglas arbitrariamente. |

## 2. Contradicciones y decisiones del director

1. **Estado real:** `M1_4_PARTIAL_ACCEPTED_EVIDENCE`, **0/5 READY**. La integridad del ZIP no certifica legalidad ni vigencia.
2. **`GAP-CONTRACT`:** resolver mediante enlaces y SHAs GitHub de PR #79, sin modificar checkout original ni insistir en que los documentos faltan globalmente.
3. **Medellín:** Gaceta 5885, páginas 3 y siguientes, Decreto distrital 1490 (30-jul-2026), indicado por índice vLex de documento externo; referencia oficial GeoMedellín sobre vías exentas II-2026 y trámite de exención con autorización. La ficha de 34 vías **no define** automáticamente todo polígono de restricción. No confundir Decreto 1490 distrital con decreto nacional homónimo.
4. **Cartagena:** canal oficial de noticia 16-ene-2026 sobre Decreto 0015, comunicado 06-oct y trámite oficial DATT; una reproducción de 12 páginas en un tercero sirve como pista de artículos, no como firma/copia oficial verificada. La franja extraordinaria 11-dic-2026 a 22-ene-2027 requiere comparación con actos modificatorios; comunicado de junio sobre ausencia de 24h a mitad de año no implica automáticamente derogar la medida anunciada para diciembre.
5. **Bogotá:** SDM separa régimen urbano y retorno regional; excepciones por registro no equivalen a permiso individual. No inventar geometría.
6. **Riesgo de diseño:** no confundir `regla legal candidata con campos parcialmente comprobados` con `respuesta geolocalizada autorizante`. Se puede documentar rotación/horario y bloquear ALLOWED por mapa/exception incompleta, sin cambiar motor o UI desde esta investigación. Cualquier cambio de contrato requiere verificar el baseline superior.
7. **Frescura:** fecha técnica de Medellín `2026-11-10T05:00:00Z` llega en menos de un día desde este corte; NO prorrogar, no inferir fin legal ni liberar circular.
8. **No repetir:** termina M1.4 documental; obtener actos originales mediante canal oficial (histórico de Gacetas Medellín, Alcaldía/DATT Cartagena, SDM/geoservicios Bogotá), con petición formal cuando no sea posible acceder. Es una dependencia externa, no una excusa para generar una secuencia infinita de auditorías.

## 3. Corrección causal y próxima tarea de desarrollo

**No lanzar M1.4-C2.** Los paquetes M1.3, M1 operativo y M1.4 declaran hashes de capturas sin adjuntar los cuerpos brutos, lo que impide certificación independiente y duplica búsquedas. Conservar la ruta M1 nacional y adelantar un **utilitario mínimo de pruebas de procedencia M1**, reutilizando herramientas existentes; NO crear otro microservicio, un sistema de publicación, ni un nuevo agente M2.4 prematuro.

**Tarea operativa única propuesta:** `PICORADAR-M1-EVIDENCIA-OFICIAL-REPRODUCIBLE-20261109-DIRECTOR`, archivo `docs/plans/CODEX_LUNA_PICORADAR_M1_EVIDENCIA_REPRODUCIBLE_20261109.md`. Comenzar con inventario de funciones existentes (30 minutos de alcance lógico, no cronómetro), preferir reutilización; si no hay equivalente, un script CLI offline-first Python stdlib con test offline. Recibir las 12 URL exactas de la matriz M1.4, capturar por fuente HTTP permitida y cuerpo bruto dentro de un único ZIP de evidencias reproducible; registrar 403, timeout y no encontrado honestamente. **No confirmar nuevas reglas ni cambiar datasheets/runtime.** Proteger checkout/101 WIP. Después ChatGPT coteja nuevos hashes y arbitra fuentes, sin convertir una respuesta HTTP 200 en regla READY.

**Dependencia M2:** este utilitario sirve a M1.3/M1.4 como infraestructura mínima de evidencias; **NO se declara M2.4 implementado** ni se alteran sus dependencias M1.2/M2.2 del Plan Maestro.

## 4. Plan para terminar la aplicación

| Fase | Resultado exigido | Paralelismo legítimo |
|---|---|---|
| M1 adquisición | Capturas oficiales reproducibles, evidencia de actos/anexos/territorio, universo por autoridad y clase; revisión humana de completas | Automatizar captura en lote pequeño; solicitudes de información oficial en paralelo |
| M1.5 | Solo filas con texto/competencia/fecha/scope probados pasan a revisión; `UNKNOWN`/`STALE` bloqueados | No bloquear recolección de fuentes de otras ciudades |
| M2 | Motor/compilador existentes, agente lector solo proponente, revisión y pruebas de borde | No crear motor ni backend nuevos; este utilitario NO es M2.4 DONE |
| M3 | Laravel publica únicamente tras revisión, Flutter sincroniza versión/hash offline, cámaras con fuentes; QA staging | Funcionalidad sin cuenta y privacidad congeladas |
| M4 | Admitir C1 local tras QA Flutter/CI sobre SHA concreto; revisar WIP; QA Android/JNI/firmas y seguridad | Todo release sigue `NOT_APPROVED` hasta GO humano |

**PR documental:** #79; **PR funcional:** #71 Draft, sin merge. **No autorizar publicación ni cambio de TTL con este informe.**

## 5. Evidencias web complementarias independientes (no incluidas en ZIP)

- Medellín GeoMedellín vías exentas II-2026: https://www.medellin.gov.co/giscatalogacion/srv/api/records/2d9cb19a-e7c7-4e1d-8a38-fb055997b043
- Medellín trámite de exención: https://www.medellin.gov.co/es/tramites-y-servicios/exencion-de-pico-y-placa
- Histórico de Gacetas: https://www.medellin.gov.co/statements/innovaciondigital/gacetas/consulta-publica?page=1 (para 5885 anterior al 28-ago usar enlace histórico)
- Referencia secundaria de Gaceta 5885: https://vlex.com.co/vid/resolucion-n-202650063152-gaceta-1131189742
- Bogotá SDM: https://www.movilidadbogota.gov.co/preguntas-frecuentes/en-que-consiste-la-restriccion-establecida-para-vehiculos-particulares
- Cartagena comunicado oficial: https://cartagena.gov.co/noticias/cambia-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena-0
- Cartagena 16-ene 2026: https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026
- Cartagena permiso DATT: https://cartagena.gov.co/tramites-y-servicios/permiso-pico-placa
- Copia secundaria Decreto 0015: https://es.scribd.com/document/993729606/DECRETO-0015-DE-2026

**Responsabilidad:** ChatGPT = decisiones, interpretación, auditoría. Codex Luna = una ejecución técnica delimitada. Salida final Codex = **un ZIP único**. `RELEASE=NOT_APPROVED`.