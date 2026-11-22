# C18 V2 — OFF safety, UI bridge and runtime handoff

## Status
`PARTIAL`

## Lot
`C18 V2 - OFF jurisdiction guard + V01B accessibility bridge`

## Git
- Local branch: `codex/c17-v2`
- Authorized remote target: `feat/platform-integral-national-20261122`
- Base: `ba8c8de9719e9f59f84876e29443ed7f02d83697`
- `HEAD_CODE`: `b1242b0795e6375ae657aab12d69377dfacd96de`
- A commit: `65ecb7085601c07f94f66eb519d933710d3ca41e`
- B commit: `b1242b0795e6375ae657aab12d69377dfacd96de`
- Worktree: `D:/codex/PicoRadar-C17-V2`

## Outcome
- A code-complete: OFF jurisdictions require schema2 payloads with a persisted matching jurisdiction, valid municipality DIVIPOLA membership, and consultation disabled globally and on every coverage. Controller, version service and publication transaction guard creation, editing, duplication, publish and rollback. OFF-only publication continues through the existing validation/review/approval flow; no autopublish.
- B code-complete for the missing V01B fragments: four of thirteen routes ported. Tomorrow status and readable vehicle state in Inicio, enlarged-text CDA details CTA, and non-truncating maintenance totals. Nine routes already met the focused behavior and were left intact. OTA C16/C17 retained.
- Runtime acceptance remains partial: new tests are written, but none has a verifiable execution result. Legal certification and release remain NO-GO.

## Files / areas changed
- A: six Laravel source files and three feature test files.
- B: five Flutter source files and three widget test files.
- `docs/CURRENT.md` updated once for current C18 state and to correct the C17 test count from 14 to 15.
- No schema, dependency, dataset, legal rule, secret, real data or original checkout changes.

## Tests executed
| Command / test | Result |
|---|---|
| `php -l` on all 9 changed PHP files | PASS, exit 0 |
| `dart format --output=none --set-exit-if-changed` on 8 changed Dart files | PASS, exit 0; emitted missing `flutter_lints` package-resolution warnings |
| `git -c core.whitespace=cr-at-eol diff --check` | PASS, exit 0 |
| `flutter pub get --enforce-lockfile` | FAIL, exit 65; resolution would change seven locked dependencies; lockfile unchanged |
| `flutter test --no-pub --plain-name 'C18' test/features` | FAIL before tests, exit 1; `package:flutter_test` / `package:test` unavailable |
| `flutter analyze --no-pub` | NOT VERIFIED; invocation had no captured completion code/output |
| Composer install / PHPUnit | Composer package discovery failed because `/admin/campaigns/planning` registers non-invokable `CampaignPlanningController`; the PHPUnit focal command had no captured completion code/output |

Seven new test methods were written (3 Laravel, 4 Flutter); one existing Laravel test was expanded. `TESTS_EXECUTED=0` verified. The 68 C13–C17 cases were not repeated. No APK, ADB, device, or phone QA.

## Manual QA
- Static review of OFF persistence and transaction lock order; no database-backed behavior claimed.
- Static comparison against the V01B source at `e9ef37511df3110ffb0fc006ef06be781df432ac`; exact 13-route result is in `BRIDGE_RESULT.md` in the return ZIP.

## Physical Android QA
`Not required`
- Device: none
- Android: none
- Evidence: no device commands were run.

## Data / migration impact
- No schema or migration changes. No real dataset or production database touched.

## Security / privacy review
- No secret-like high-confidence patterns found in the C18 diff. No secrets, PII, GPS, plate or document data added.
- OFF payload checks are repeated against locked persisted jurisdiction state before release mutation. Existing editorial approval remains required for material publication.

## Dependencies added/changed
- None. `composer.lock` and `pubspec.lock` unchanged.

## Known risks / debt
- Laravel tests lack a complete captured result; Composer's existing route discovery blocker needs a separately scoped resolution or a compatible isolated runtime.
- Flutter analyzer and widget tests remain unverified because the locked package set is unavailable in the current SDK/cache state.
- Source-level checks do not prove runtime or legal correctness. National legal status remains `NO_GO`; release remains `NO_GO`; main bridge remains `HOLD`.

## Stop conditions encountered
- Flutter lock-preserving dependency resolution failed; no retry or lockfile change.
- Composer package discovery failed once; no retry or unrelated route modification.
- No APK or physical QA attempted.

## Next lot(s) unblocked
- Resolve the isolated PHP route/bootstrap blocker and provide a Flutter dependency cache consistent with the existing lockfile; then run the approved focal tests once. Do not infer a release or legal certification from the static implementation.

## Do not forget
- No merge, PR, main, Hostinger, deployment, release, APK or phone intervention performed.
- GitHub push and final remote SHA are recorded in the C18 `GITHUB_STATE.md` after the normal fast-forward verification.
