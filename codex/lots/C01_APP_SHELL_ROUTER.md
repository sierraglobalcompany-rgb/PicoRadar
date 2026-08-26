# LOT C01 — Design tokens + AppShell + five permanent tabs

**Suggested branch:** `feat/C01-app-shell-router`  
**Status:** DONE locally; pending PR review/merge

## GOAL

Implement the global shell and frozen navigation: Inicio · Garaje · Apps · Viaje · Conducir, with Apps always central.

## SOURCE OF TRUTH

- Wireframes/Design System
- Cierre Global §6
- Flujo 04 §1–3
- Arquitectura §6

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C00

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Add baseline color/type/spacing/radius tokens.
- Add Riverpod and go_router baseline packages.
- Use StatefulShellRoute.indexedStack or equivalent stable shell.
- Create exactly five root placeholder screens: Home, Garage, Apps, Trip, Drive.
- Bottom nav order fixed; Apps index 2 with 9-dot icon.
- Route immersive screens outside shell placeholder path structure.
- Widget/router tests for tab switching and state preservation basics.

## OUT OF SCOPE

- Feature content.
- Launcher 3x3 (C12).
- Onboarding.
- Ads.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [x] Exactly five visible destinations in correct order.
- [x] Apps is always central.
- [x] Second tab label is Garaje, never Vehículo.
- [x] Switching tabs does not create duplicate navigation stacks.
- [x] Back behavior is predictable.
- [x] Design tokens are centralized.

## TESTS REQUIRED

- `flutter analyze`
- `flutter test (router/widget tests)`
- `flutter build apk --debug --flavor dev`

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

- go_router baseline is incompatible with current Flutter and requires major migration; report options.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not add a sixth tab.
- Do not add account/avatar behavior beyond placeholder.
- Do not implement module grids.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.

## GITHUB ADDENDUM

Canonical remote: `https://github.com/sierraglobalcompany-rgb/PicoRadar.git`

Before coding C01, bootstrap remote `main` at approved C00 SHA exactly as described in `GITHUB_REPOSITORY.md`. After C01, push branch and open PR to `main`; do not merge.
