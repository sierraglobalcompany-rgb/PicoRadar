# LOT C12 — Apps launcher + module registry

**Suggested branch:** `feat/C12-apps-launcher`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement the central 9-dot launcher with 9 primary modules and secondary list.

## SOURCE OF TRUTH

- Flujo 04
- Cierre Global §7

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C01
- C08

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Apps root grid 3x3 in frozen order.
- More for your vehicle list.
- Typed ModuleRegistry metadata.
- Active vehicle chip.
- Requires-vehicle guard.
- Feature flags from local/default config.
- Offline visual behavior.

## OUT OF SCOPE

- Feature module internals.
- Search/reorder/favorites.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Nine primary modules exact order.
- [ ] No gaps when hidden feature flag.
- [ ] Vehicle guard returns correctly.
- [ ] Apps central remains selected.

## TESTS REQUIRED

- `widget/router tests`
- `text scaling tests`

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

- None beyond global.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not add search/reordering.
- Do not duplicate Viaje/Conducir as full modules.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
