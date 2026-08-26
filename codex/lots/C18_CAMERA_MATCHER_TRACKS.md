# LOT C18 — CameraMatcher + synthetic driving tracks

**Suggested branch:** `feat/C18-camera-matcher-tracks`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement deterministic camera candidate/matching logic with reproducible synthetic tracks.

## SOURCE OF TRUTH

- Flujo 05 §10–13
- C16
- C17

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C16
- C17

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Haversine distance/bearing helpers.
- Candidate scoring: distance, heading difference, approaching trend, optional official direction/corridor.
- Confidence thresholds.
- Synthetic track fixtures: straight, opposite, parallel, turn-away, U-turn, two cameras, jitter.
- No UI.
- Debug trace output only in tests/dev.

## OUT OF SCOPE

- TTS/threshold alerts.
- Background Android.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Opposite/parallel obvious cameras rejected in fixtures.
- [ ] Approaching correct camera selected.
- [ ] Jitter does not flip candidate excessively.

## TESTS REQUIRED

- `full synthetic track unit suite`

## PHYSICAL QA

Not required yet.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Heuristic cannot distinguish a fixture without map/corridor data; document limitation rather than adding ML.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not add ML/geospatial heavyweight engine.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
