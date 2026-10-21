# Preparar compra: visual handoff (2026-09-15)

## Status
Visual correction installed and physically inspected. Owner approval pending;
global suite failures and real attachment import remain open. Not a lot closure.

## Lot
C24 / owner-authorized Compra/Venta presentation refinement. No commercial activation.

## Git
- Branch: codex/cda-owner-map (existing owner WIP).
- HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
- Before checkpoint: refs/checkpoints/purchase-layout-before-20260915,
  6597c8583005a271d8f53fc29a4a027df433a653.
- First candidate checkpoint: refs/checkpoints/purchase-layout-candidate-20260915,
  efb4e8c327c387bf00f9e3e71c82b9a266c39d7c.
- Final tracked-WIP checkpoint: refs/checkpoints/purchase-layout-final-20260915,
  e98d4e5b202b06d046401af9d2d5dd61a15d30cf. Untracked files remain in place;
  the checkpoint does not include this untracked handoff or generated evidence.
- Worktree: temp/VIAJE-R1-real-planner. Earlier tracked and untracked WIP preserved.
- No merge or publication performed.

## Outcome
- Full-screen purchase preparation uses actual shell constraints. Normal text
  has a bounded column; larger text has one vertical scroll and measured columns.
- Plain step numbers, 32 dp icons, 14 sp titles, 13 sp status, 48 dp action targets.
- Instructions moved into About. Data/attachment buttons retain stable labels.
- Owner rejected the first 108 dp header as too narrow. Latest correction restores
  approximately 164 dp and uses colors measured from the supplied mockup:
  header #143963, reviewed #1D62C6, text #0A2252, action #078B90.

## Files / areas changed
- mobile/lib/features/buy_sell/presentation/buy_sell_screen.dart
- mobile/test/features/buy_sell/presentation/buy_sell_screen_test.dart
- docs/DESIGN_CONTRACT.md, docs/CURRENT.md and this handoff.
- No changes to draft schema, storage, routes, sponsor assets or document imports.

## Verification
- First compact candidate: 27 focused tests passed; flutter analyze passed.
- Tests load Roboto and use AppShell with a real GoRouter branch Navigator.
  The earlier cover has its own sizing issue under this harness; only that
  entry page gets an OverflowBox. Pushed purchase routes use unmodified shell
  constraints. Normal purchase pixel output matched the installed phone.
- Matrix: 360x780, 360x800, 390x844, 412x915, 430x932; text 1/1.5/2.
- Tests check taps, actual rectangles, text bounds, zero normal scroll extent,
  all six step transitions, stable control bounds, persistence, and 0/2/6 states.
- Final correction: all 27 focused tests pass, including exact header color,
  reviewed tile color and 160-168 dp header bounds.

## Physical QA
- Device: Mi A3, adb 116f2191b19a; 720x1560 px at density 320.
- Final corrected candidate installed with adb install -r; data preserved.
- Opening Comparendos displayed the correct sheet and closing it preserved 0 of 6.
- Vertical swipe changed zero sampled content pixels (y=70..1299).
- Superseded evidence: C:/Users/felip/AppData/Local/Temp/purchase-final-20260915.png.
- Final evidence: C:/Users/felip/AppData/Local/Temp/purchase-final-color-20260915.png.
- After swipe: C:/Users/felip/AppData/Local/Temp/purchase-color-after-swipe-20260915.png.
- Final physical header: y=35..199 dp, 164 dp high; sampled #143963.
- Grid: approximately 119 dp per row. Save bottom y=646 dp; navigation y=650 dp.
- Final swipe comparison: zero changed pixels sampled every 2 px in y=70..1299.
- Phone state remains 0 of 6; reviewed-color evidence uses automated fixtures,
  not changes to the owner's saved preparation.
- Automated 2/6 reviewed evidence: mobile/build/purchase-review/.
- No personal documents imported or external service calls made for QA.

## Known risks / debt
- Actual registration file import remains unimplemented in the inherited code;
  stored attachment states are not proof of a stored image/PDF.
- The first full-suite attempt exhausted system memory when run alongside Gradle.
  It was restarted serially; final builds run separately.
- Global formatting of '.' encountered a missing generated Android build path;
  changed Dart files pass the scoped format check.
- Other modules' pre-existing suite failures are not closed by this visual work.
- Final visual approval belongs to the owner. No other lot is declared complete.

## Final verification
- Working directory for commands below: mobile/.
- `dart format --output=none --set-exit-if-changed lib/features/buy_sell/presentation/buy_sell_screen.dart test/features/buy_sell/presentation/buy_sell_screen_test.dart`: exit 0, 2 files unchanged.
- `flutter analyze --no-pub`: exit 0, no issues (final-analyze.log).
- `flutter test --no-pub --concurrency=1 --dart-define=PURCHASE_CAPTURE=true test/features/buy_sell/presentation/buy_sell_screen_test.dart`: exit 0, 27 passed (final-focused.log).
- `flutter test --no-pub --concurrency=1 --reporter expanded`: exit 1,
  2783 passed, 10 skipped, 87 failures (full-tests-serial.log). Affected areas:
  dataset composition, startup cleanup/timeouts, Apps expectations, Garage,
  Home/Pico, K7 navigation/contracts. No Buy/Sell failure. This run preceded
  the final color/header adjustment; the fresh focused run covers that change.
- `flutter build apk --no-pub --flavor dev --release`: exit 0, 100.4 MB (final-build.log).
- Logs and automated images: mobile/build/purchase-review/ (local artifacts).
- APK: mobile/build/app/outputs/flutter-apk/app-dev-release.apk.
- Local APK and installed base.apk SHA256 both:
  `46A13FE89252F0CE2EF198C3D129E6F800CC317FAFFA2C13FA5C0A1DB269B64B`.
- ADB install: Success. Launch, navigation to preparation, screenshot and swipe
  checked on Mi A3. No emulator-only claim of physical validation.
- Git status remains the owner's large tracked/untracked WIP. No clean-worktree,
  global test success, CI, publication, merge or real attachment-import claim.

## Next gate
Owner visual approval of the installed correction. No subsequent lot unlocked
by this visual change; global stabilization and attachment import need their
own scoped follow-up.
