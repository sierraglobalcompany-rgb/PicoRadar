# LOT C08 — Garaje root + vehicle detail minimum

**Suggested branch:** `feat/C08-garage-root-detail`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement the second permanent tab and multi-vehicle management shell.

## SOURCE OF TRUTH

- Flujo 03 §1–3
- Cierre Global §6, §16

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C01
- C06

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Garaje list/cards.
- Active vehicle selection.
- Vehicle detail page shell with status sections/placeholders.
- Add/edit/delete vehicle entry points.
- Safe delete confirmation and active vehicle fallback.
- Generic vehicle illustration component using local assets.

## OUT OF SCOPE

- Full SOAT/RTM/insurance content C13.
- Scanner C15.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Tab label Garaje.
- [ ] Multiple vehicles switch correctly.
- [ ] Deleting active vehicle picks deterministic next/none.
- [ ] No brand logos.

## TESTS REQUIRED

- `widget/repository tests`
- `flutter test`

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

- Do not rename Garaje to Vehículo.
- Do not implement server sync.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
