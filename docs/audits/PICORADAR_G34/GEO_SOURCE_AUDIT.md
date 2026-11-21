# G34 — auditoría de geografía DANE

**Verificación:** 2026-11-10 23:34:08 UTC  
**Resultado:** `PARTIAL`: la conciliación administrativa y los puntos de referencia son reproducibles; no describen cobertura vial ni autorizan circular.

## Fuente y método

- Servicio oficial DIVIPOLA/MGN 2025, versión ArcGIS 11.3: [FeatureServer DANE](https://portalgis.dane.gov.co/mparcgis/rest/services/Divipola/Serv_DIVIPOLA_MGN_2025/FeatureServer).
- Hosts oficiales consultados: `geoportal.dane.gov.co` y su espejo `portalgis.dane.gov.co`. El host primario devolvió HTTP 500 dos veces en el conteo de la capa 305; se continuó con el espejo oficial. La consulta y el error quedan registrados en `GEO_SOURCE_AUDIT.json`.
- Capas: 305 `Centros Poblados`, 317 `Municipio`, 319 `Departamento`.
- La capa 305 no anuncia paginación (`supportsPagination=false`); se pidieron IDs y se descargaron grupos ordenados de hasta 1.000 IDs.
- Para 305 se pidió `returnCentroid=true` y `outSR=4326`. No se descargaron ni empaquetaron polígonos.

SHA-256 de respuestas de metadatos conservadas en el audit JSON:

| Respuesta | SHA-256 |
|---|---|
| Servicio raíz | `481380c501aa7e2f7ff09ecddbb13b52308d543af63a7f37bbc7d99c3197d588` |
| Capa 305 | `2d1fdd1069a7a0df6220b41727bfa570ac57b5b77464bf8310bd91f0ba17cdd2` |
| Capa 317 | `eb83099740dc7727f9edebf9e7a5690fe99170b7a58528fadab858cdbd792d5b` |
| Capa 319 | `9093693c2b252aed6227e6c3a65078dc9131b14575dbb74978cca96669965419` |

## Reconciliación

El catálogo canónico local contiene 33 departamentos y 1.104 municipios. Los 33 códigos de departamento y los 1.104 códigos municipales coinciden con DANE; no hay municipios locales ausentes en DANE, códigos extra en el catálogo, padres distintos ni tipos administrativos contradictorios.

La capa DANE 317 tiene 1.122 entidades: 1.103 `MUNICIPIO`, 18 `ÁREA NO MUNICIPALIZADA` y una `ISLA`. Las 18 áreas y la isla no se contaron como municipios adicionales. La clase 1 de la capa 305 contiene 1.104 cabeceras; la clase 2, 7.316 centros poblados.

## Semántica y límites

El sidecar local contiene 8.420 puntos WGS84: todos llevan el rol `derived_centroid_reference_only`; no hay IDs duplicados, coordenadas nulas ni códigos padre vacíos. Un centroide sirve como referencia geográfica aproximada. No identifica la ubicación de una vía, corredor, excepción ni límite de restricción. La app no puede resolver `inside_scope_ref` con estos puntos.

Artefacto: `server/database/data/geography/dane_mgn_2025_reference_sidecar.json`  
Tamaño: 3.805.412 bytes  
SHA-256: `3a139c0d92619740e818cb2880e61bffc8d0e948f8422f9a9344ea9042b0825f`

La fuente primaria inaccesible y la falta de geometría vial mantienen el gate en `PARTIAL`; no se afirma cobertura geográfica completa.
