# LOT C19 — AlertEngine + TTS/haptics + Driving UI

**Suggested branch:** `feat/C19-alert-engine-driving-ui`  
**Status at pack creation:** NOT STARTED

## GOAL

Turn matched camera events into anti-spam distance/overspeed alerts and the main driving UI.

## SOURCE OF TRUTH

- Flujo 05 §4, §7–9, §12
- C18

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C18

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Threshold profiles Basic/Normal/Detailed/Custom.
- Per-camera session memory, hysteresis, cooldown.
- Overspeed only if `speed_limit_verified`.
- flutter_tts wrapper and audio-coordination basics.
- HapticFeedback/natively simple haptic.
- D-001/D-002/D-003/D-004 screens.
- Zero ads.

## OUT OF SCOPE

- Background service.
- HUD final.
- Bluetooth-specific custom routing beyond platform TTS defaults.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Threshold fires once per approach.
- [ ] Unknown limit never overspeed warns.
- [ ] UI calm without camera; warning states clear.
- [ ] TTS respects settings.

## TESTS REQUIRED

- `AlertEngine unit tests`
- `widget driving states`

## PHYSICAL QA

Recommended TTS smoke.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- TTS package platform issue requires new dependency; stop and evaluate.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not add police-style red/blue strobe.
- Do not persist tracks.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
