# ANSV Camera Speed Field Audit

Date: 2026-08-31

Scope: D01-FIX3 audits how PicoRadar should present the ANSV field
`VELOCIDAD_INFRACCIONAR` in Conducir.

## Official Source

- Layer metadata:
  `https://srvansvargweb.ansv.gov.co/server/rest/services/Equipos_Fotodeteccion/Equipos_Geo/FeatureServer/0?f=json`
- Runtime data query:
  `https://srvansvargweb.ansv.gov.co/server/rest/services/Equipos_Fotodeteccion/Equipos_Geo/FeatureServer/0/query`
- Public page:
  `https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html`

## Field Metadata

The FeatureServer layer exposes:

| Field | Type | Alias | Domain | Nullable |
|---|---:|---|---|---|
| `VELOCIDAD` | `esriFieldTypeSmallInteger` | `VELOCIDAD` | `null` | `true` |
| `VELOCIDAD_INFRACCIONAR` | `esriFieldTypeInteger` | `VELOCIDAD_INFRACCIONAR` | `null` | `true` |
| `INFRACCIONES` | `esriFieldTypeString` | `INFRACCIONES` | `null` | `true` |

The layer metadata did not expose a coded domain, description, unit label, legal
definition, or alias more specific than the field name itself.

## Semantic Finding

`VELOCIDAD_INFRACCIONAR` is sufficiently clear to treat the numeric value as a
speed value reported by ANSV for a camera record, but the metadata alone is not
sufficient to call it the legal road speed limit.

Product copy must therefore avoid `limite legal` unless a later official source
explicitly defines the field that way.

Approved runtime wording for D01-FIX3:

- `Velocidad reportada`
- `Velocidad ANSV`
- `Velocidad de control reportada`
- `Valor reportado`

## Current Pack Coverage

The D01-FIX3 runtime pack remains APPROVED-only.

- `FINAL_APPROVED_CAMERA_COUNT`: 596
- `SPEED_VALUE_KNOWN_COUNT`: 50
- `SPEED_VALUE_UNKNOWN_COUNT`: 546
- `SPEED_VALUE_COVERAGE_PERCENT`: 8.39%

Known speed value distribution:

| km/h | Count |
|---:|---:|
| 10 | 5 |
| 30 | 16 |
| 40 | 7 |
| 50 | 6 |
| 60 | 8 |
| 70 | 3 |
| 80 | 5 |

## Runtime Rule

When a camera has `speedLimitKmh`, Conducir may compare current speed against
that ANSV reported value and must present it as a reported/control speed.

When a camera has `speedLimitKmh = null`, Conducir must still show the camera
distance and source, but must not invent a number or claim overspeed.

The D01-FIX3 visual hysteresis margin is only a UI/alert stability guard against
GPS speed jitter. It is not a legal tolerance, camera tolerance, or allowed
tolerance, and must not be described that way to users.
