# LOT C02 — CI, linting and quality gates

**Suggested branch:** `feat/C02-ci-quality-gates`  
**Status at pack creation:** NOT STARTED

## GOAL

Make every later lot fail fast on formatting, analysis, tests and basic builds.

## SOURCE OF TRUTH

- Arquitectura §33
- AGENTS.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C00

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- GitHub Actions mobile workflow: pub get, format check, analyze, build_runner if configured, test, debug dev APK.
- Server workflow: composer install, test, formatter/static checks chosen conservatively.
- Add dependency update bot config weekly with no auto-merge.
- Document local equivalents.

## OUT OF SCOPE

- Release signing.
- Play deploy.
- Coverage threshold wars.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] PR CI is deterministic and green on baseline.
- [ ] No auto-merge dependency updates.
- [ ] Commands match README.

## TESTS REQUIRED

- `Run workflows locally where possible / validate YAML`
- `flutter test`
- `php artisan test`

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

- CI environment lacks required SDK/API setup; pin/setup explicitly rather than weakening checks.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not introduce a complex build platform.
- Do not add release deployment.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
