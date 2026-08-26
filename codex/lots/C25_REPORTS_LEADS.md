# LOT C25 — Incorrect-data reports + lead/consent foundation

**Suggested branch:** `feat/C25-reports-leads`  
**Status at pack creation:** NOT STARTED

## GOAL

Add low-risk server interactions for directory corrections and future voluntary leads.

## SOURCE OF TRUTH

- Flujo 08 §19–28
- contracts/API_CONTRACT_BASELINE.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C24
- C00 server

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- POST reports backend + rate limit.
- App report incorrect place flow.
- Lead domain/service gated by feature flag.
- Consent version and named partner model.
- Free 1.0 may keep leads feature disabled if no real partner.
- Analytics excludes PII.

## OUT OF SCOPE

- Marketplace.
- Multi-partner hidden lead sale.
- Payments.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Reports never directly edit production data.
- [ ] Lead cannot submit without explicit consent and partner.
- [ ] Feature OFF collapses UI cleanly.

## TESTS REQUIRED

- `server validation/rate-limit tests`
- `widget consent tests`

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

- No legitimate partner/data policy available: keep lead OFF and complete only technical gate.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not fan out to multiple partners without user knowledge.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
