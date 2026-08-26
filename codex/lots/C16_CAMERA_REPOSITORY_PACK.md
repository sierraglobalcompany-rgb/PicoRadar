# LOT C16 — Camera model + local repository + pilot regional pack

**Suggested branch:** `feat/C16-camera-repository-pack`  
**Status at pack creation:** NOT STARTED

## GOAL

Create the local camera data layer used by Driving.

## SOURCE OF TRUTH

- Flujo 05 §3, §18
- contracts/DATASET_CONTRACTS.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C05
- C03

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Camera schema/table and indexes.
- Camera pack JSON schema and importer.
- Pilot regional pack fixture with source/verified metadata.
- Bounding-box candidate query by region and lat/lon ranges.
- Speed limit verification flag.
- Dataset version integration.

## OUT OF SCOPE

- Matching/heading.
- Live GPS.
- All national cameras.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Local candidates query without network.
- [ ] Unknown speed limit preserved unknown.
- [ ] Pack import atomic.

## TESTS REQUIRED

- `DB importer/query tests`

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

- Pilot source cannot provide sufficient fields; allow optional direction but do not invent.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not build nearby-cameras backend endpoint.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
