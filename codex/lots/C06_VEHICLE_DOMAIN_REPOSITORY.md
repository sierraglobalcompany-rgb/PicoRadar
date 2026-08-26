# LOT C06 — Vehicle models + local repository + active vehicle

**Suggested branch:** `feat/C06-vehicle-domain-repository`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement the local vehicle domain used by onboarding, home, garage, trip and modules.

## SOURCE OF TRUTH

- Flujo 01
- Flujo 03
- Cierre Global §8–9

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C03

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Vehicle model with car/moto type, generic subtype, plate, registration city, optional brand/model/year/color/fuel.
- CRUD repository in Drift.
- activeVehicleId state.
- Plate normalization/validation rules suitable for Colombia without over-restricting edge cases.
- Tests for multiple vehicles and active switching.

## OUT OF SCOPE

- Onboarding UI.
- SOAT/RTM UI.
- Cloud sync.
- Brand logos.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Multiple vehicles persist.
- [ ] Active vehicle persists locally.
- [ ] No account dependency.
- [ ] Generic visual subtype is stored.

## TESTS REQUIRED

- `unit/repository tests`
- `flutter analyze`

## PHYSICAL QA

Not required.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Product rule requires an unmodeled mandatory field; report before making it mandatory.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not store manufacturer logo assets.
- Do not require brand/model/year.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
