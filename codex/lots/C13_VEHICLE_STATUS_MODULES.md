# LOT C13 — SOAT + RTM + insurance + taxes local modules

**Suggested branch:** `feat/C13-vehicle-status-modules`  
**Status at pack creation:** NOT STARTED

## GOAL

Complete the main vehicle-status modules inside Garaje/Apps using local data and official-link contracts.

## SOURCE OF TRUTH

- Flujo 03 §SOAT/RTM/Seguro/Impuestos
- Cierre Global §16

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C08

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- vehicle_obligations persistence for SOAT/RTM/insurance dates.
- SOAT view/alerts.
- RTM view + CTA to CDA.
- Insurance provider selection and assistance-channel model.
- Taxes/obligations calendar/link view.
- Semaforización/sistematización as catalog items when applicable.
- Reminder scheduling integration with existing notification layer.

## OUT OF SCOPE

- Buying SOAT.
- Insurance quote lead.
- Tax estimation.
- Real national directory completeness.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] No tax estimate.
- [ ] Assistance states explain depends on policy.
- [ ] Dates editable/local.
- [ ] Portals are external verified-link objects.

## TESTS REQUIRED

- `unit status/date tests`
- `widget states`

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

- A portal requires unsupported authentication flow; open external safely instead.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not claim debt amount.
- Do not hardcode advertiser partner.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
