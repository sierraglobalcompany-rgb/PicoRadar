# LOT C09 — Pico y placa rule engine + fixtures

**Suggested branch:** `feat/C09-pico-rule-engine`  
**Status at pack creation:** NOT STARTED

## GOAL

Build the deterministic local engine before connecting real datasets/UI.

## SOURCE OF TRUTH

- Flujo 02
- Cierre Global §13
- contracts/DATASET_CONTRACTS.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C03

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Typed RestrictionEvaluation: allowed/restricted/unknown/stale.
- Rule representation supporting weekday/date parity/digits/digit position/multiple windows/validity/holiday flags/registration origin/priority override.
- Fixture-driven tests for representative city patterns.
- Priority/temporary override behavior.
- No UI.

## OUT OF SCOPE

- Network sync.
- All 33 jurisdictions real data.
- Notification scheduling.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Engine has no Flutter UI dependency.
- [ ] Tests cover normal, temporary suspension, emergency override, local/foreign registration differences.
- [ ] Unknown/stale are explicit.

## TESTS REQUIRED

- `unit fixture suite`

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

- A real jurisdiction cannot be represented by current rule contract; stop and ADR rather than hardcode.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not put city-specific if/else in widgets.
- Do not assume car and motorcycle rules are same.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
