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

Historical wording for D01-FIX3 (superseded by the owner decision below):

- `Velocidad reportada`
- `Velocidad ANSV`
- `Velocidad de control reportada`
- `Valor reportado`

## Historical D01-FIX3 Pack Coverage

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

Owner decision, 2026-09-09: the ANSV value is informational and appears only
in camera details as `Velocidad reportada por ANSV`, together with its source
and snapshot date. Missing values read `No informada`. The runtime pack now
contains 360 cameras; the counts above describe the historical audit only.

The field must not drive a speed-limit sign, numeric excess, gauge color or
pulse, overspeed vibration, or a spoken instruction to reduce speed. This
applies even when the measured vehicle speed exceeds the reported value.

Details must explain: `Este dato no confirma el limite vigente de esta via.
Respeta la senalizacion` (localized with Spanish accents in the application).
The proximity message is `Camara a [distancia] metros. Respeta la senalizacion
de la via`. No new verified-limit mechanism is introduced. Existing dataset
fields remain compatible and unchanged; camera approval is not verification
of the current speed limit, road, carriageway or direction of travel.
