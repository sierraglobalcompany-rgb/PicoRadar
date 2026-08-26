# LOT C27 — Defense templates + PDF + filing/deadline tracking

**Suggested branch:** `feat/C27-defense-pdf-deadlines`  
**Status at pack creation:** NOT STARTED

## GOAL

Complete beta document generation and follow-up while payment remains disabled.

## SOURCE OF TRUTH

- Flujo 07 §16–30
- C26

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C26

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Template model/version/status.
- Document composer from controlled variables.
- PDF preview/generation local where feasible.
- Generated document metadata/hash/version.
- Manual filing record + radicado/date.
- DeadlineCalculator by petition modality.
- Local reminder integration.
- EntitlementService stub AlwaysAllowedBeta.

## OUT OF SCOPE

- Payment.
- Automatic filing.
- Legal representation.
- Email/WhatsApp.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Suspended/retired template cannot generate final PDF.
- [ ] PDF includes template/legal version.
- [ ] Deadline not always assumed 15 days.
- [ ] PII remains local by default.

## TESTS REQUIRED

- `template fixture tests`
- `PDF content tests`
- `deadline tests`

## PHYSICAL QA

PDF preview/print/share smoke recommended.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- A template requires professional review not available; keep template beta/suspended.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not add paywall.
- Do not permit arbitrary text injection into legal template body without validation.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
