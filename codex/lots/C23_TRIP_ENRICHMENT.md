# LOT C23 — Trip enrichment: tolls + restrictions + incidents + recommendation

**Suggested branch:** `feat/C23-trip-enrichment`  
**Status at pack creation:** NOT STARTED

## GOAL

Apply Colombian mobility intelligence to real/mock routes.

## SOURCE OF TRUTH

- Flujo 06 §7–18
- C09/C10
- contracts/DATASET_CONTRACTS.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C21
- C22
- C10

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Toll station/rate tables/import fixture if not present.
- TollMatcher on route geometry.
- RestrictionRouteEvaluator using ETA/jurisdiction.
- RoadIncidentRepository/Matcher with fixture/offline source abstraction.
- CameraRouteSummary (count/segments, not navigation alert logic).
- Explainable RouteRecommendationService.
- Open external Waze/Google Maps action + disclosure that external app may recalc.
- CTA to start Conducir.

## OUT OF SCOPE

- Own turn-by-turn map.
- Real-time traffic engine.
- Ad ranking.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Recommendation has reason code.
- [ ] Restriction conflict is visible by ETA.
- [ ] Partial failure doesn't erase routes.
- [ ] Sponsored data cannot influence recommendation.

## TESTS REQUIRED

- `matcher/evaluator unit tests`
- `integration trip fixtures`

## PHYSICAL QA

External navigation smoke recommended.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Third-party route license prevents required geometry use; stop with options.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not select route based on fewer cameras as dominant factor.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
