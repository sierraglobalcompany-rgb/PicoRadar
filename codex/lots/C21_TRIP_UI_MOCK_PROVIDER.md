# LOT C21 — Trip planner UI + mock RouteProvider

**Suggested branch:** `feat/C21-trip-ui-mock-provider`  
**Status at pack creation:** NOT STARTED

## GOAL

Build Flow 06 UI and domain contracts independently of Google credentials.

## SOURCE OF TRUTH

- Flujo 06 §1–9
- Cierre Global §15

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C01
- C08

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- TripRequest/RouteCandidate models.
- RouteProvider interface + deterministic mock.
- Origin/destination/date/time/vehicle form.
- Analyze state and partial-failure presentation.
- Compare routes cards.
- Route detail/timeline shell.
- Recommendation reason-code presentation using mock data.

## OUT OF SCOPE

- Real Google API.
- Real toll/restriction enrichment.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] UI supports 2–4 routes.
- [ ] No map required.
- [ ] Can select route and reach detail.
- [ ] Provider is replaceable.

## TESTS REQUIRED

- `widget/domain tests`

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

- Do not embed Google API key.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
