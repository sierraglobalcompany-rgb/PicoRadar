# LOT C17 — LocationService + permission + lifecycle foundation

**Suggested branch:** `feat/C17-location-service`  
**Status at pack creation:** NOT STARTED

## GOAL

Provide a small platform-safe location abstraction before camera matching.

## SOURCE OF TRUTH

- Flujo 05 §6, §11, §14–15
- Arquitectura §23

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C00

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- geolocator service wrapper.
- Permission state model.
- Precise location start/stop.
- LocationSample model: time, lat/lon, accuracy, speed, heading where available.
- In-memory short buffer helper.
- Foreground configuration hooks but no full Driving service yet.
- Fake LocationService for tests.

## OUT OF SCOPE

- Camera matching.
- Background service.
- Persistent GPS history.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Start/stop releases stream.
- [ ] Permission denied/restricted handled.
- [ ] No DB/server logging of samples.

## TESTS REQUIRED

- `unit fake/lifecycle tests`
- `widget permission state tests`

## PHYSICAL QA

Recommended location smoke.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Platform permission requirement conflicts with Flow 05; document.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not request background permission on app launch.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
