# LOT C00 — Repository foundation + Flutter/Laravel scaffold + flavors

**Suggested branch:** `feat/C00-repo-scaffold-flavors`  
**Status at pack creation:** NOT STARTED


## PICORADAR NAMING OVERRIDE

This package adopts the project name **PicoRadar** and store title **PicoRadar: Pico y Placa**.

For C00:
- prod application ID: `co.picoradar.app`
- staging: `co.picoradar.app.staging`
- dev: `co.picoradar.app.dev`
- prod label: `PicoRadar: Pico y Placa`
- staging label: `PicoRadar Staging`
- dev label: `PicoRadar Dev`

This naming override supersedes older generic references to “App Movilidad Colombia”.

## GOAL

Create the KISS monorepo foundation and prove Android dev + Laravel test builds work before product UI begins.

## SOURCE OF TRUTH

- Cierre Global §25–29
- Arquitectura Técnica §1–4, §7–8, §15, §36, §39

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- None

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Create monorepo folders: mobile/, server/, docs/, data/, scripts/.
- Create Flutter app in mobile/ using the technical baseline.
- Create Laravel 13 app in server/ using PHP 8.3+.
- Configure Flutter flavors dev/staging/prod with distinct app IDs/suffixes and app labels.
- Android: minSdk 24, targetSdk 36, Java 17; compileSdk compatible with current Flutter/AGP baseline.
- Add .env.example / dart-define examples without secrets.
- Copy or reference AGENTS.md and baseline docs in repo.
- Create minimal smoke tests for Flutter and Laravel.
- Create README with exact local setup commands.

## OUT OF SCOPE

- Product navigation UI (C01).
- Drift DB (C03).
- CI (C02).
- Firebase.
- Real API keys.
- Any feature screen.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] `flutter --version` baseline is recorded.
- [ ] `flutter pub get` succeeds.
- [ ] Dev Flutter app launches/builds as a minimal scaffold.
- [ ] `flutter build apk --debug --flavor dev` succeeds.
- [ ] Laravel application boots and `php artisan test` succeeds.
- [ ] No secrets are committed.
- [ ] Repo tree matches the approved monorepo shape.

## TESTS REQUIRED

- `flutter test`
- `flutter analyze`
- `flutter build apk --debug --flavor dev`
- `php artisan test`

## PHYSICAL QA

Not required; emulator/smoke launch is enough.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Flutter/AGP setup cannot target API 36.
- PHP/Composer environment cannot run Laravel 13.
- Creating flavors requires changing product baseline.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not implement the five bottom tabs.
- Do not add Firebase.
- Do not add architecture packages beyond scaffold needs.
- Do not merge.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
