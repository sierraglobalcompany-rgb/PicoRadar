# G34 — conteos del sidecar geográfico

Audit ejecutado `2026-11-10T23:34:08Z`; los conteos se contrastan con `GEO_SOURCE_AUDIT.json` y el sidecar incluido.

| Métrica | Conteo |
|---|---:|
| Departamentos locales / DANE (capa 319) | 33 / 33 |
| Municipios canónicos locales | 1.104 |
| Códigos municipales conciliados | 1.104 de 1.104 |
| Códigos municipales locales sin pareja o con padre distinto | 0 / 0 |
| Entidades de la capa 317 | 1.122 |
| Capa 317: municipio / área no municipalizada / isla | 1.103 / 18 / 1 |
| Capa 305: total de centros | 8.420 |
| Clase 1: cabeceras municipales | 1.104 |
| Clase 2: centros poblados | 7.316 |
| Puntos con coordenadas WGS84 válidas | 8.420 |
| Puntos sin coordenadas / IDs duplicados / sin padre | 0 / 0 / 0 |
| Puntos etiquetados `derived_centroid_reference_only` | 8.420 |

No se interpretan los 18 códigos de áreas no municipalizadas ni la isla como municipios nuevos. Los centroides no demuestran cobertura vial ni producen `ALLOWED`.
