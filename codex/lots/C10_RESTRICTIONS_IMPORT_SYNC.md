# LOT C10 — Restrictions dataset importer + pilot real data

**Suggested branch:** `feat/C10-restrictions-import-sync`  
**Status at pack creation:** NOT STARTED

## GOAL

Connect versioned restriction data to the local rule engine with a small verified pilot dataset.

## SOURCE OF TRUTH

- Flujo 02
- Arquitectura §17–20
- C09

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C05
- C09

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Define restrictions dataset schema v1.
- Importer into Drift transaction.
- Pilot verified jurisdictions (e.g., Medellín/Valle de Aburrá + Bogotá + one special-case city) from baseline data fixtures.
- Dataset version and verified_at/source URL.
- Integration tests import → evaluate.
- Manual fixture source notes.

## OUT OF SCOPE

- National automation n8n.
- All Colombia coverage if source curation is not yet ready.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Import is atomic.
- [ ] Engine evaluates pilot dataset correctly.
- [ ] Source/verified_at surfaced in result metadata.

## TESTS REQUIRED

- `import tests`
- `engine integration tests`

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

- Source data is not sufficiently verified; use fixture marked non-production and stop production release claim.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not scrape broad web automatically in this lot.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
