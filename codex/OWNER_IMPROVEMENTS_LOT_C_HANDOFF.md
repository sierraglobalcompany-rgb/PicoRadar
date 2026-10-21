# Owner Improvements Lot C Handoff

## Status
`DONE`

## Lot
`Owner improvements C - Apps origin and maintenance`

## Git
- Branch: `codex/lot-c-apps-maintenance`
- Base branch: `codex/forensic-alerts`
- Base SHA: `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`
- Worktree: `C:\Users\felip\.codex\worktrees\owner-maintenance\PicoRadar_ Pico y Placa`

## Outcome
- Apps modules opened from `Más` return to the same launcher section and shell branch.
- Talleres now supports a local vehicle selection, service status and cost summaries, editable categories, clearable next-service fields, GPS/city workshop search, and maintenance reminders.
- Date reminders are scheduled notifications. Kilometre reminders are evaluated only when an odometer value is available; no passive tracking is implied.

## Files / areas changed
- Shell and Apps launcher origin handling.
- Maintenance presentation and reminder planning.
- Notification scheduling integration.
- Focused widget, navigation, and reminder tests.

## Tests executed
| Command / test | Result |
|---|---|
| Dart format check for `mobile/lib` and `mobile/test` | Passed, 366 files, 0 changes |
| Maintenance and Apps launcher focused suite | Passed, 70 tests |
| Pico notification and startup notification suite | Passed, 58 tests |
| `flutter analyze --no-pub` | Passed, no issues |

## Manual QA
- Automated shell navigation verifies returning from Talleres restores `Más` over the original tab.
- GPS workshop search is covered with a punctual location fixture and external launcher fake.

## Physical Android QA
`Required and pending integration APK`
- Device: Mi A3
- The integrated APK must verify launcher return, GPS search, and notification reconciliation.

## Data / migration impact
- No schema migration.
- Maintenance reminder scheduling is derived from existing maintenance records and vehicle odometer data.

## Security / privacy review
- Punctual GPS is used only after an explicit workshop search action.
- No GPS history, global city, favorite vehicle, or background odometer tracking is added.

## Dependencies added/changed
- None.

## Known risks / debt
- Android physical notification delivery remains part of integration QA.
- Kilometre reminders require an explicit odometer update by design.

## Stop conditions encountered
- None.

## Next lot(s) unblocked
- Owner improvements integration and physical QA.

## Do not forget
- No merge to `main` was performed.
