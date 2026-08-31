# ANSV Camera Pack Authorization Audit

Date: 2026-08-31

Scope: D01-FIX2 filters the local Driving camera runtime pack so it only ships
ANSV records whose authorization status is confidently `Aprobada`.

## Source

- Page: https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html
- FeatureServer:
  https://srvansvargweb.ansv.gov.co/server/rest/services/Equipos_Fotodeteccion/Equipos_Geo/FeatureServer/0/query

No raw ANSV dump is committed.

## Metrics

- ANSV_SOURCE_TOTAL_COUNT: 1224
- ANSV_STATUS_DISTRIBUTION:
  - Aprobada: 662
  - Con observaciones: 312
  - Pendiente: 71
  - Rechazada: 179
- ANSV_APPROVED_STATUS_COUNT: 662
- ANSV_APPROVED_WITHOUT_RUNTIME_COORDINATES_COUNT: 66
- ANSV_EXCLUDED_COUNT: 628
- FINAL_CAMERA_PACK_COUNT: 596
- FINAL_CAMERA_PACK_SHA256:
  `62fcc23f89ee0c8b089599bdb36dc8669a43e68d4a05b224ad57c33494cbe0b9`

## Duplicate Audit

- duplicateOfficialIds: 0
- exactDuplicateCoordinates: 16
- nearDuplicateCoordinatePairsWithin10m: 10

The duplicate coordinate records are not merged in D01-FIX2. Multiple equipment
IDs may represent multiple source records at one physical site, and grouping is
out of scope for this fix.

## Runtime Rule

The committed `camera_pack_v1.json` must contain only cameras with:

```text
status = Aprobada
```

Any `Pendiente`, `Rechazada`, `Con observaciones`, blank, or unknown status
fails closed before it can reach the matcher.
