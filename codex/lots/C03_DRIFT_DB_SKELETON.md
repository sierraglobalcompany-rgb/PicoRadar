# LOT C03 — Drift SQLite schema skeleton + migration harness

**Suggested branch:** `feat/C03-drift-db-skeleton`  
**Status at pack creation:** NOT STARTED

## GOAL

Create the local persistence foundation with migrations and no feature UI dependency.

## SOURCE OF TRUTH

- Arquitectura §9, §35
- Cierre Global §10

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C00

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Add Drift/drift_flutter + dev tooling.
- Create database bootstrap and migration strategy.
- Create initial tables needed early: vehicles, vehicle_obligations, notification_preferences, dataset_versions.
- Add placeholders/tables for restriction rules only if needed for migration contracts; avoid all 18 tables prematurely if that adds risk.
- Add indexes required for current tables.
- Migration tests from schema 1.
- Repository access stays behind feature-owned code later.

## OUT OF SCOPE

- Vehicle UI.
- Dataset imports.
- Camera pack.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] DB creates reliably.
- [ ] Migration tests pass.
- [ ] No raw SQL scattered outside DB layer.
- [ ] Schema version documented.

## TESTS REQUIRED

- `flutter test DB/migrations`
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

- Drift baseline package incompatible with Flutter baseline.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not add SQLCipher.
- Do not model every future field unless required by baseline contracts.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
