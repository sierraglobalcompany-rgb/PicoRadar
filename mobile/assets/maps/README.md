# Colombia departments - local display geometry

Source: Departamento Administrativo Nacional de Estadistica - DANE:
https://www.dane.gov.co . Territorial framework 2025, department layer 1:
https://geoportal.dane.gov.co/mparcgis/rest/services/Territoriales_DANE/Serv_Territoriales_DANE_2025/MapServer/1

Retrieved 2026-09-12. Source fields: `dpto_ccdgo`, `dpto_cnmbr`.
License/attribution: CC BY 4.0, subject to the published DANE conditions:
https://geoportal.dane.gov.co/acerca-del-geoportal/licencia-y-condiciones-de-uso/

This is a **simplified derivative for manual exploration**, not an authoritative
boundary for camera enforcement. The camera inventory is separate and unchanged.
Bogota is independent of Cundinamarca. Island coordinates are unchanged. The
dedicated island inset was removed at the owner's request; the territory remains
available in search. The national map does not request tiles or GPS.

## Reproduction

Run from repository root. Download the layer query with `where=1=1`,
`outFields=dpto_ccdgo,dpto_cnmbr`, `returnGeometry=true`, `outSR=4326`, `f=geojson`
to `temp/FOTOMULTAS_OWNER_MAP/geometry/dane-source.geojson`.

```text
npx --yes --package mapshaper@0.7.61 mapshaper temp/FOTOMULTAS_OWNER_MAP/geometry/dane-source.geojson -explode -simplify dp interval=100 keep-shapes stats -o format=geojson temp/FOTOMULTAS_OWNER_MAP/geometry/dane-simplified.geojson
node mobile/tool/prepare_department_geometry.mjs temp/FOTOMULTAS_OWNER_MAP/geometry/dane-source.geojson temp/FOTOMULTAS_OWNER_MAP/geometry/dane-simplified.geojson mobile/assets/maps/colombia_departments_dane2025.geojson
```

Mapshaper 0.7.61 is a development-only MPL-2.0 tool, not a mobile dependency.
All departments are simplified together to share topology. Exploding components
before `keep-shapes` protects small islands; the script restores MultiPolygons.

## Recorded validation

- Original: 41,981,158 bytes. Output: 2,090,116 bytes.
- Raw SHA256: `3eea0dbf533b6f87631feafdad3786f7b515ca0b6c18e932701fdf0eb2d83876`.
- 33 unique two-digit codes, 90 polygon components before and after.
- 72 shared-boundary adjacency pairs before and after; none lost.
- 6 archipelago components and 51 Bolivar components preserved.
- Simplification interval 100 metres, reported maximum displacement 99.9948 m.
- Mapshaper repaired 34 intersections; reported collapsed rings: zero.
- The transformation rejects missing codes, components, holes or adjacency.
- Flutter tests additionally check interior label anchors, Bogota separation,
  small-territory selection and the unchanged inventory counts.

Source and intermediate files stay in local `temp`, not in the APK. The final
asset embeds provenance and transformation metadata. Do not substitute the
owner's raster mockup or rectangles for these geographical boundaries.
