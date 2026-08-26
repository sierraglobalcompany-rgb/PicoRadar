# LOT C20 — Android foreground/background Driving + HUD + battery gate

**Suggested branch:** `feat/C20-driving-background-hud`  
**Status at pack creation:** NOT STARTED

## GOAL

Make Driving reliable while Waze/Maps is foreground and complete HUD on physical Android.

## SOURCE OF TRUTH

- Flujo 05 §14–17, §23–25
- ANDROID_PHYSICAL_QA.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C19

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Android foreground/background location configuration/service.
- Persistent notification while Driving active as required.
- Foreground↔background lifecycle.
- Lock-screen behavior.
- HUD mirrored presentation, keep-awake/brightness controls as feasible.
- Finalization fully stops GPS/service.
- Battery profiling and Bluetooth/TTS QA.
- Document platform constraints.

## OUT OF SCOPE

- iOS background implementation.
- Auto-start via Bluetooth.
- Android Auto.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Waze/Maps foreground + alerts continue.
- [ ] Finalizing releases foreground service/GPS.
- [ ] HUD works and exits safely.
- [ ] Physical battery evidence recorded.

## TESTS REQUIRED

- `integration/lifecycle tests where possible`
- `flutter build APK`

## PHYSICAL QA

REQUIRED: full Driving QA checklist including 30/60/120 min battery session.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Google Play policy/Android service type requirement conflicts; update architecture with ADR before proceeding.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not declare DONE on emulator only.
- Do not keep GPS active after user stops Driving.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
