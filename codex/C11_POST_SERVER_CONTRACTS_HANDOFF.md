# Lot Handoff

## Status
`DONE`

## Lot
`C11 - Post-C11 server and mode contract preparation`

## Git
- Branch: `chore/C11-post-server-contracts`
- HEAD: commit containing this handoff; resolve with `git rev-parse HEAD`
- Base branch: `fix/C11-home-sponsor-carousel`
- Base SHA: `2e8f2ed381eb4d10254532724aa3026c8c310317`
- Safety checkpoint: `codex/checkpoint-before-post-c11-server-modes`
- Worktree: isolated Codex worktree `post-c11-server-modes`

## Outcome
- Preserved C11 byte-for-byte in its four protected implementation/test files.
- Corrected maintenance date reminders so they require explicit per-vehicle
  opt-in and remain disabled by default.
- Removed plate and maintenance detail from lock-screen notification content;
  Android visibility is now `secret`.
- Reconciled the post-C11 action inventory without activating Lite, accounts,
  ads, Pro, payments or WhatsApp.
- Added a read-only, fail-closed server preflight, staging example without
  secrets, runbook, hosting decision and next-lot boundary.
- Clarified the privacy boundary for remote map tiles.

## Files / areas changed
- `mobile/lib/features/maintenance/`
- `mobile/lib/features/pico_placa/platform/pico_notifications.dart`
- `mobile/lib/app/app_providers.dart`
- `scripts/server_preflight.ps1` and its synthetic test
- `server/.env.staging.example`
- `docs/post_c11/`, `docs/CURRENT.md` and privacy documentation

## Tests executed
| Command / test | Result |
|---|---|
| Dart format on modified Dart files | Clean; 7 files, 0 changes on final pass |
| `flutter analyze --no-pub` | No issues |
| Maintenance/notification focused tests | 84 passed |
| Protected Home/C11 tests | 192 passed |
| Full Flutter suite | 3234 passed, 10 skipped, 0 failed |
| `scripts/tests/test_server_preflight.ps1` | Passed |
| Laravel suite with process-local SQLite and test key | 166 passed, 2373 assertions, 337 warnings, 0 failed |
| `flutter build apk --flavor dev --release --dart-define=APP_ENV=dev --no-pub` | Passed; APK compiled only |
| `git diff --check` | Clean |

## Manual QA
- Confirmed no `HomeBannerSlot` remains in Inicio.
- Confirmed shared banner configuration remains because SOAT/RTM consume it.
- Confirmed live preflight reads no `.env` and reports hosting capabilities as
  unknown instead of pretending staging is ready.

## Physical Android QA
`Not required`
- No APK was installed and no phone data was accessed or modified, as required
  by the owner for this lot.

## Data / migration impact
- No Drift or server schema migration.
- One new local preference key per vehicle:
  `maintenance.notifications.date.<vehicleId>`.
- Existing users default to reminders off until they opt in.
- National datasets were not changed or re-dated.

## Security / privacy review
- Maintenance notification bodies no longer expose plate or maintenance title.
- Preflight never reads `.env` values, installs packages, migrates databases or
  starts services.
- Staging flags for trips, OSRM and partner inquiries remain disabled.
- Remote tile-provider metadata exposure is documented separately from the
  prohibition on continuous GPS transmission to PicoRadar's backend.

## Dependencies added/changed
- No runtime package was added or changed.
- Composer dependencies were installed only in the ignored isolated worktree to
  execute the locked server suite.

## Known risks / debt
- Private staging is not ready until HTTPS, cron, persistent processes and
  writable storage are confirmed on the chosen host.
- The OSRM source metadata exists, but the heavy graph is absent and was not
  downloaded or rebuilt.
- Lite, accounts, real ads, Pro, payments and WhatsApp remain proposal-only.
- PHPUnit reports 337 environment/framework warnings; there are no failed tests.

## Stop conditions encountered
- Hosting capabilities are unknown, so no deployment or activation was
  attempted.

## Next lot(s) unblocked
- Private synthetic staging after the owner confirms the exact Hostinger plan
  and whether it provides VPS/root, SSH, cron, persistent processes, PHP,
  Composer, MariaDB, domain and HTTPS.

## Do not forget
- No merge, push, deployment, purchase, phone installation or data mutation was
  performed.
