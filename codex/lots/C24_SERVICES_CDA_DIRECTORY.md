# LOT C24 — Services/CDA directory + nearby search + sponsor separation

**Suggested branch:** `feat/C24-services-cda-directory`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement the useful directory layer before any commercial activation.

## SOURCE OF TRUTH

- Flujo 08 §1–14, §26
- Cierre Global §18

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C05
- C08

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- service_businesses schema/import.
- Services categories root.
- CDA list/filter/detail.
- Near-me calculation local.
- Organic ordering.
- Official/accredited badge from source fields only.
- Peritaje/taller generic list/detail scaffolds.
- Sponsored slot component supported but feature OFF/no campaign.

## OUT OF SCOPE

- Paid sponsor logic live.
- Google Places enrichment required.
- Booking.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Works without account.
- [ ] Sponsor state cannot create accredited badge.
- [ ] Offline cache works.
- [ ] No blank ad slot when OFF.

## TESTS REQUIRED

- `directory/filter/ranking tests`
- `widget tests`

## PHYSICAL QA

Location near-me smoke recommended.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Official CDA data model unavailable; use clearly labeled fixture and block production claim.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not scrape Google Maps.
- Do not call a paid result 'recommended'.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
