# LOT C14 — Comparendos + SIMIT / transit official links

**Suggested branch:** `feat/C14-comparendos-official-links`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement Flow 03 comparendos entry without scraping or storing personal results.

## SOURCE OF TRUTH

- Flujo 03 CMP
- Cierre Global §16
- AGENTS privacy

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C08
- C05

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Official links dataset/schema.
- SIMIT national card.
- Nearby transit authority cards based on jurisdiction context.
- Copy plate action.
- Safe external/custom-tab style launcher as platform permits.
- Verified official source label.

## OUT OF SCOPE

- SIMIT data scraping.
- CAPTCHA bypass.
- Storing fine results.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] No web scraping.
- [ ] User can reach official portals and return cleanly.
- [ ] Offline shows cached links.

## TESTS REQUIRED

- `widget/link validation tests`

## PHYSICAL QA

External link smoke on Android recommended.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Official site blocks in-app browser; fall back to system browser, document.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not automate form submission to protected portals.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
