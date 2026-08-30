# R03 Reference Plan

Status: BLOCKED_ON_OWNER_REFERENCES
Branch: feat/R03-status-surfaces-visual-recovery
Scope: Pico and vehicle-status visual recovery planning only.

## Required Owner References

R03 UI implementation must not start until owner-selected references are available for:

- `docs/design/reference/pico_owner_v1.png`
- `docs/design/reference/soat_owner_v1.png`
- `docs/design/reference/rtm_owner_v1.png`

Do not create fake images, generated mockups, or inferred dimensions for these surfaces.

## Future Surfaces

Future R03 may visually recover:

- Pico y placa detail
- SOAT detail
- Tecnomecanica detail
- Seguro y asistencia status surface
- Impuestos status surface

First implementation priority after references arrive:

- Pico
- SOAT
- Tecnomecanica

## Logic Preservation

Future R03 must preserve C09-C13 logic, explicit vehicleId handoff, location/jurisdiction authority, fail-closed restriction states, official source links, stale/unknown states, SOAT/RTM obligations, insurance, tax calendar behavior, and notification semantics.

## Current Lot Boundary

No UI code is implemented in this branch.

CODEGEN_NOT_REQUIRED.
