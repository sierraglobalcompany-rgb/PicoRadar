# Pico Conditional Rule Requirements V1

Date: 2026-08-31

Scope: research-only inventory for future generic Pico y Placa capabilities.
This document is not a runtime implementation plan and does not promote any
jurisdiction.

## Why This Exists

C10B-A demotes Ibague and Villavicencio because their current official rules
need facts the existing rule engine cannot represent safely. C10B-B extends
that finding across the next source candidates so future work can implement one
generic capability instead of one-off city exceptions.

## Required Generic Capabilities

| Capability | Needed for | Why current runtime must fail closed |
|---|---|---|
| Registration city condition | Ibague, Cucuta | A vehicle may use different time windows or rule families depending on where it is matriculated. PicoRadar does not yet have a verified local registration-city fact bound to the vehicle profile. |
| Vehicle model-year exemption | Villavicencio | Some vehicles may qualify by model year and registration location. Applying or ignoring that benefit without user-verified facts can produce false personalized advice. |
| Special permits and legal exemptions | Armenia, Santa Marta, Tunja, Manizales, Pereira | Many decrees exempt emergency, official, health, electric/hybrid, disability, cargo or service vehicles under specific conditions. The app needs an explicit, user-confirmed exemption model before those exceptions affect verdicts. |
| Corridor/perimeter-only rules | Cucuta, Tunja, Armenia, Barranquilla, Manizales | Restrictions can differ by ring road, center zone, event corridor, urban perimeter or national-road carve-out. The current city-level verdict cannot safely decide these without route/zone context. |
| Seasonal/event periods | Manizales, Barranquilla | Temporary earthquake/Carnival/event rules must expire automatically and must not look like permanent city coverage. |
| Hour-valley windows | Ibague, Cucuta, Tunja | A rule may apply in several windows or change by condition. Existing simple windows are not enough when the selected window depends on vehicle registration or zone. |
| Service-specific public transport schedules | Cucuta, Santa Marta | Taxi, collective, special public-service and private categories may be controlled by different decrees. Mixing categories would create false positives. |
| Evidence freshness boundary | Pereira, Pasto, Santa Marta | A source may be official but incomplete, inaccessible, scanned or older than the current year. Runtime needs a documented freshness confidence before promoting. |

## Minimum Product/Data Contract For Future Work

Before any conditional city is promoted to AVAILABLE, a later lot must define:

1. A local-only vehicle fact model for registration city, vehicle model year,
   service type, fuel/technology category and user-claimed exemptions.
2. A source-backed legal-exemption taxonomy with explicit user confirmation.
3. A route/zone or city-area model when a rule applies only to a perimeter,
   corridor, ring road, center district or event zone.
4. A fail-closed evaluation path that returns unknown coverage when required
   facts are absent.
5. Tests proving the app does not claim a personalized verdict without all
   required facts.
6. Source metadata per condition, including decree/resolution URL,
   verified-at date, valid-from, valid-until and stale-after.

## Out Of Scope For C10B-B

- No edits to runtime restriction datasets.
- No edits to active catalog availability.
- No generic exemption engine.
- No registration-city or model-year storage.
- No geofence/corridor runtime.
- No Home or Pico UI changes.
