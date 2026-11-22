# C19 V2 — Laravel route, Flutter lock and diagnostic build

## Status
`PARTIAL`

## Lot
`C19 V2 - runnable server and debug APK diagnostics`

## Git
- Base C18: `0a7808370b73c939e0010bd57c341a823bc89957`
- Local integration branch: `codex/c17-v2`
- Authorized remote branch: `feat/platform-integral-national-20261122`
- Integrated A: `46dbc5b` (source agent commit `7d7a48e555345948fed834ce250c369b704ad038`)
- Integrated B: `04b5693` (source agent commit `de22bb2334f7b55b77eefa282186bd20fb981c68`)
- `HEAD_CODE`: `04b5693`
- Worktree: `D:/codex/PicoRadar-C17-V2`

## Outcome
- A repairs the exact invalid route callable. Composer discovery, route listing, and HTTP permission allow/deny check passed. Composer lock stayed unchanged.
- PHPUnit remains partial: CampaignPlanning and C15 navigation passed; restriction/editor files contain errors/failures. Two of three targeted C18 checks passed; the remaining test stopped on a duplicate synthetic country code. No additional national test batch ran.
- B resolved the lock within existing constraints and raised AGP one patch level after Flutter reported its minimum requirement. Analyze/tests still fail; the single permitted diagnostic retry then failed with memory pressure and two Dart compile errors. No APK exists.
- No source change to the Pico y Placa engine, legal dataset, production endpoint, APIs, database or app features.
- Status: `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`.

## Files / areas changed
- `server/routes/web.php`: planning route now invokes `CampaignPlanningController@index`.
- `mobile/pubspec.lock`: seven allowed transitive versions changed; `pubspec.yaml` preserved.
- `mobile/android/settings.gradle.kts`: AGP 9.1.0 → 9.1.1, matching explicit Flutter build requirement.
- `docs/CURRENT.md` updated once; this handoff created.

## Tests executed
| Command / file | Result |
|---|---|
| `php -l routes/web.php` | PASS, exit 0 |
| Composer install from lock | PASS, exit 0; 108 packages, no updates/removals; discovery complete |
| `php artisan route:list --path=admin/campaigns/planning` | PASS, exit 0; route resolves to `CampaignPlanningController@index` |
| HTTP route authorization | PASS: authorized commercial user allowed; editor denied |
| RestrictionRouteIntegrationTest.php | FAIL: 11 tests, 116 assertions; 1 error, 2 failures |
| RestrictionRuleVersionServiceTest.php | FAIL: 2 tests, 19 assertions; 1 error (missing test import) |
| RestrictionMaterialApprovalWorkflowTest.php | FAIL: 9 tests, 136 assertions; 1 pre-existing order-sensitive array comparison failure |
| CampaignPlanningTest.php | PASS: 4 tests, 36 assertions |
| C15NavigationIntegrationTest.php | PASS: 2 tests, 7 assertions |
| Targeted C18 route/service methods after test-only corrections in isolated agent worktree | 2 PASS (29 assertions); 1 ERROR (2 assertions) on duplicate synthetic `CO` row; corrections not committed/integrated |
| `flutter pub get` | FAIL, exit 1; Windows plugin symlink support/Developer Mode required; not a network failure |
| `flutter pub get --enforce-lockfile` | PASS, exit 0; `Got dependencies!` |
| `dart format --output=none --set-exit-if-changed` on 8 C18 Dart files | PASS, exit 0; no files changed |
| `flutter analyze --no-pub` | FAIL, exit 1; 159 findings, including test/source compile errors |
| Focal settings + C18 Inicio/CDA/maintenance batch | FAIL, exit 1; CDA passed 26 tests, four other files did not compile |
| First `flutter build apk --debug --no-pub` | FAIL, exit 1 after 185.4 s; AGP 9.1.0 below Flutter minimum 9.1.1 |
| Single adjusted build retry after AGP 9.1.1 | FAIL, exit 1 after 446.2 s; virtual-memory reservation failure plus Dart compile errors |
| `git -c core.whitespace=cr-at-eol diff --check` | PASS, exit 0 |

The first PHPUnit batch needed a process-only test APP_KEY; the one retry produced the file results above. No APP_KEY was persisted. `composer.lock` unchanged. There is no APK at `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

## Manual QA
- Route listing and HTTP authorization allow/deny test passed in isolated test mode.
- No API/manifest/client smoke was attempted because the server/mobile acceptance gates did not pass.

## Physical Android QA
`Not required`
- Device: none
- Android: none
- Evidence: no ADB or phone interaction.

## Data / migration impact
- None. PHPUnit used ephemeral SQLite only. No production database, real dataset or migration touched.

## Security / privacy review
- No production URLs, credentials, plates, GPS or private documents were added. Advertising/payments remain OFF.
- The temporary random APP_KEY existed only in the test process.

## Dependencies added/changed
- No direct Dart dependency or `pubspec.yaml` change.
- Seven transitive packages changed inside declared constraints; exact versions and lock hashes are in `DEPENDENCIES.md` in the C19 return ZIP.
- Android Gradle plugin changed from 9.1.0 to 9.1.1 only in response to the explicit build error.

## Known risks / debt — maximum 3
1. PHP restriction/editor suite remains red or indeterminate in existing C18 tests: synthetic country `CO` uniqueness, missing test import/markup expectation, and an existing order-sensitive array comparison.
2. Flutter analyze reports 159 findings; focal files fail compilation, including a missing app-account mock method and a restriction test argument mismatch.
3. No APK: after the authorized AGP adjustment, build failed from memory pressure and Dart compile errors in `service_provider_catalog.dart` and `home_vehicle_carousel.dart`.

## Stop conditions encountered
- Focal PHPUnit gate did not pass; `NationalDatasetIntegrityTest` and extra C13–C17 tests were not run.
- One local AGP adjustment and one build retry were used; no additional patch/build attempt.
- Flutter has no APK output; no install or device QA.

## Next lot(s) unblocked
- Correct the synthetic test fixtures and remaining focused OFF/editor test defects; repair the localized Dart compile/analyze errors; then, with adequate memory, perform only the explicitly authorized focused verification/build.

## Do not forget
- A then B were integrated from the same C18 base. No push/merge/main/PR/Hostinger/deployment/device action occurred before the final documented push.
- The final remote SHA and push confirmation are recorded in C19 `GITHUB_STATE.md`.
