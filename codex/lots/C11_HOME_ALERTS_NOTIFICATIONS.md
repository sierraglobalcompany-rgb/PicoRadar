# LOT C11 — Inicio + pico status + local notifications

**Suggested branch:** `feat/C11-home-alerts-notifications`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement Flow 02 core using local rules and schedule local alerts.

## SOURCE OF TRUTH

- Flujo 02
- Design System
- C10

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C07
- C10

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Home states allowed/restricted/offline/stale.
- Vehicle and jurisdiction selector flows.
- Today/tomorrow and detail/calendar/source UI.
- Notification preference UI.
- flutter_local_notifications scheduling/rescheduling.
- Center notification list local model if needed for Flow 02.
- Offline last-updated display.

## OUT OF SCOPE

- Push FCM invalidation.
- Ads.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Home renders immediately from local DB.
- [ ] Rule update causes local alert reschedule.
- [ ] Stale/unknown never shown as confident allowed.
- [ ] No network required for normal daily view.

## TESTS REQUIRED

- `widget tests states`
- `notification scheduling unit tests`
- `flutter build dev`

## PHYSICAL QA

Real Android notification permission + tap smoke recommended.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Android exact alarm/policy requirement forces architecture change; degrade to supported scheduling and document.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not add backend today endpoint.
- Do not hide stale source.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
