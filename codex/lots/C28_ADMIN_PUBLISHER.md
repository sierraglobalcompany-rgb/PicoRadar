# LOT C28 — Laravel admin/control plane + dataset publisher

**Suggested branch:** `feat/C28-admin-publisher`  
**Status at pack creation:** NOT STARTED

## GOAL

Build the minimal operational backend to curate and publish production datasets safely.

## SOURCE OF TRUTH

- Arquitectura §15–20, §45–47
- Cierre Global §11, §27

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C00 server
- C05

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Admin authentication and roles baseline.
- 2FA before production-ready gate if practical with Laravel ecosystem.
- Source registry.
- Jurisdictions/restriction rules/dataset releases models.
- Minimal camera/toll/directory/legal publication models needed by current datasets.
- Draft → validate → publish workflow.
- Publisher outputs immutable files + manifest + SHA-256.
- Audit log.
- Local/staging object output; CDN deployment adapter.
- Laravel Scheduler hooks for future automation.

## OUT OF SCOPE

- n8n/AI automation.
- Full CMS polish.
- User accounts.
- Ads billing.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] App-compatible manifest published from admin data.
- [ ] Cannot publish invalid dataset without validation.
- [ ] Audit trail exists.
- [ ] No scraper auto-publishes.

## TESTS REQUIRED

- `server feature tests`
- `publisher contract tests`
- `manifest hash tests`

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

- Hostinger lacks required PHP/cron/storage capability: prepare deployment adapter/VPS option, do not change mobile contract.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not build microservices.
- Do not store mobile user identity.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
