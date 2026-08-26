# LOT C26 — Defense cases + LegalRuleEngine beta

**Suggested branch:** `feat/C26-defense-rule-engine`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement the deterministic guided defense analysis locally, without monetization.

## SOURCE OF TRUTH

- Flujo 07 §1–15, §26–34
- C15 storage

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C03
- C15

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- defense_cases/answers/evidence schema.
- DEF-001..DEF-010 questionnaire/result flow.
- LegalRule model/repository.
- Fixture baseline rules from documented legal sources.
- LegalRuleEngine deterministic evaluation + confidence.
- Source/legal-version metadata.
- Complex-case escalation state.
- All beta/free.

## OUT OF SCOPE

- PDF generation.
- Payment.
- Automatic legal AI answer.
- Automatic filing.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Every conclusion traces to rule/source.
- [ ] No 'guaranteed annulment' language.
- [ ] Cases persist locally and sensitive files encrypted.
- [ ] Suspended rule not evaluated as active.

## TESTS REQUIRED

- `legal fixtures`
- `widget questionnaire tests`

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

- Legal rule is ambiguous/outdated; mark unsupported/escalate rather than invent.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not copy third-party templates.
- Do not create open-ended legal chatbot.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
