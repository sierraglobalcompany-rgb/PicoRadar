# LOT C07 — Onboarding + add car/motorcycle flow

**Suggested branch:** `feat/C07-onboarding-ui`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement Flow 01 using the local vehicle repository and just-in-time permissions.

## SOURCE OF TRUTH

- Flujo 01
- Design System
- Cierre Global §8–9

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C01
- C06

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- First-open welcome.
- Empty garage/add vehicle entry.
- Car vs motorcycle.
- Generic subtype selector.
- Vehicle fields and optional insurance/SOAT/RTM setup per Flow 01.
- Draft persistence.
- Alert preference setup without forcing permission until activated.
- Completion route to Home/Garage as specified.

## OUT OF SCOPE

- Cloud/login.
- Real insurer data import.
- Document scan.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] User can install → add vehicle → reach app without account.
- [ ] Permissions are requested only at point of use.
- [ ] Cancel/restart retains safe draft where specified.

## TESTS REQUIRED

- `widget tests key screens`
- `validation tests`
- `flutter build apk dev`

## PHYSICAL QA

Notification permission smoke on real device recommended, not gate.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- OS permission behavior differs materially from flow; document and propose adaptation.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not add login.
- Do not request location/camera on first launch.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
