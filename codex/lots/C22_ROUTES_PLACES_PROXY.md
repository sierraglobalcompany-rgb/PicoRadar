# LOT C22 — Laravel Places/Routes proxy + quotas/rate limits

**Suggested branch:** `feat/C22-routes-places-proxy`  
**Status at pack creation:** NOT STARTED

## GOAL

Add server-side provider integration without exposing API keys in the APK.

## SOURCE OF TRUTH

- Arquitectura §25–26
- contracts/API_CONTRACT_BASELINE.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C00 server

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- RouteProvider server abstraction.
- Google Routes implementation baseline.
- Places Autocomplete proxy.
- Input validation.
- Field masks minimal.
- Rate limit by IP/installation token strategy without account.
- Timeout/error normalization.
- Mock/fake provider for tests.
- Environment key config only server-side.

## OUT OF SCOPE

- Storing trip history.
- Tolls/restrictions enrichment.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] No Google key sent to mobile.
- [ ] Provider can be mocked.
- [ ] Rate limits and errors tested.
- [ ] No trip persistence by default.

## TESTS REQUIRED

- `Laravel unit/feature tests`
- `contract examples`

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

- Real credentials unavailable: complete mock/provider contract and mark real integration BLOCKED, do not hardcode key.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not log full user route payload in production logs.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
