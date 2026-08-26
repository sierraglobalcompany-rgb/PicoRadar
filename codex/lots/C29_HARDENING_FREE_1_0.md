# LOT C29 — Hardening + performance + store/privacy readiness

**Suggested branch:** `feat/C29-hardening-free-1-0`  
**Status at pack creation:** NOT STARTED

## GOAL

Close Free 1.0 with technical, privacy, physical and policy gates; monetization remains OFF.

## SOURCE OF TRUTH

- Cierre Global §31
- Arquitectura §44, §47–49
- ANDROID_PHYSICAL_QA.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- All core lots required by release

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Full analyze/test/build gates.
- DB migration upgrade tests.
- Dataset corruption/offline/recovery tests.
- Performance profiling and startup checks.
- Driving battery/background physical QA.
- Accessibility pass.
- Crashlytics sanitation review.
- Android API 36 permissions/service behavior.
- Privacy/Data Safety matrix and policy draft inputs.
- Release AAB/signing process setup.
- Verify ads/payments/cloud flags OFF.
- Final regression checklist.

## OUT OF SCOPE

- Activating ads/payments/subscription.
- iOS release.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Free 1.0 gate checklist passes.
- [ ] No critical crash/data-loss/privacy issue.
- [ ] Driving physical QA has evidence.
- [ ] AAB builds reproducibly.
- [ ] Monetization flags verified false.

## TESTS REQUIRED

- `full mobile CI`
- `full server CI`
- `physical Android QA`
- `release build smoke`

## PHYSICAL QA

REQUIRED comprehensive.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Any critical privacy/data loss/GPS lifecycle/store policy blocker.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not waive failing gate to meet schedule.
- Do not turn monetization on.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
