# Lot A Navigation and Driving Handoff

## Status
`PARTIAL`

Implementation and automated verification are complete. Physical Android QA is
still required for GPS, foreground/background behavior, TTS/Bluetooth, HUD,
keep-awake, and final resource release.

## Lot
`Lot A - Navigation / Driving`

## Git
- Branch: `codex/lot-a-driving`
- HEAD: final local commit reported in the owner handoff response
- Base commit: `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`
- Worktree: `C:/Users/felip/.codex/worktrees/owner-driving/PicoRadar_ Pico y Placa`
- No merge or push performed.

## Outcome
- Back navigation now gives the Apps launcher first precedence, pops nested
  routes normally, confirms before ending an active driving session, and returns
  inactive tab roots to Inicio.
- Internal tab and Apps-launcher changes cannot leave an active driving session
  hidden; confirmed exits stop the session before navigation.
- Pausing or hiding the app preserves active GPS/voice behavior for external
  Maps/Waze use. Only explicit finish or final detach stops the session.
- The GPS status opens diagnostics and recovery actions rather than acting as an
  off toggle.
- Voice is a persistent preference and its displayed/effective state also
  reflects native Android TTS readiness.
- The speedometer scale and ticks are capped visually at 160 km/h while the
  numeric value continues to show actual samples above 160 km/h.
- Active and HUD speed displays use an em dash when no fresh sample exists.

## Files / areas changed
- `mobile/lib/app/shell/app_shell.dart`
- `mobile/lib/features/driving/application/driving_controller.dart`
- `mobile/lib/features/driving/platform/driving_feedback_gateway.dart`
- `mobile/lib/features/driving/presentation/driving_screen.dart`
- `mobile/android/app/src/main/kotlin/co/picoradar/app/MainActivity.kt`
- `mobile/test/app/driving_navigation_test.dart`
- Driving application and presentation test fakes/tests under
  `mobile/test/features/driving/`

## Tests executed
| Command / test | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Passed after formatting the changed driving test |
| `flutter analyze --no-pub` | Passed, no issues |
| Focused navigation + controller + screen tests | Passed, 93 tests |
| `flutter test --no-pub test/features/driving test/app/driving_navigation_test.dart` | Passed, 249 tests with 10 existing skips |
| `flutter build apk --debug --flavor dev --no-pub` | Passed; generated `app-dev-debug.apk` before final generated-state cleanup |
| `flutter test --no-pub` | Passed, whole-project suite (570 seconds) |

## Manual QA
- Automated widget coverage exercised Back precedence, cancel/confirm exit,
  tab guarding, GPS diagnostic dispatch, Voice preference/effective state,
  lifecycle retention, 160 km/h scale semantics, over-scale numeric display,
  and stale-sample em dash behavior.
- No manual desktop/emulator result is represented as physical Android evidence.

## Physical Android QA
`Blocked`
- Device: Mi A3 (`laurel_sprout`) detected, but no isolated install/QA slot was
  available in the shared multi-agent session
- Android: not run
- Evidence: the branch APK was not installed because it could overwrite another
  worktree's active device build. A dedicated pass remains required by
  `codex/ANDROID_PHYSICAL_QA.md` for real GPS and weak signal, Maps/Waze
  background, TTS/Bluetooth, HUD and keep-awake, battery/lifecycle, and final
  stop releasing GPS/native resources.

## Data / migration impact
- No schema, migration, dataset, backend, or stored vehicle/document changes.
- The existing local Driving Voice preference remains the source of truth.

## Security / privacy review
- GPS remains local and temporary; no route history, continuous server upload,
  exact-location logging, analytics payload, or backend hot-path was added.
- External Maps/Waze foreground behavior preserves the existing background
  contract and does not introduce an internal navigation engine.

## Dependencies added/changed
- None.

## Known risks / debt
- Native TTS readiness can change after Android initializes or resumes; the app
  refreshes on resume and preference changes, but physical timing remains to be
  validated.
- Android may terminate the process while an external navigation app is in the
  foreground; operating-system kill/relaunch behavior remains a physical QA item.
- GPS settings recovery opens the appropriate system surface; successful service
  and permission recovery must be confirmed on a device.

## Stop conditions encountered
- Physical Android QA was not run without an isolated device slot. No product,
  architecture, privacy, dependency, or migration stop condition encountered.

## Next lot(s) unblocked
- Owner physical QA and integration review for Lot A.

## Do not forget
- No merge performed unless human explicitly approved.
