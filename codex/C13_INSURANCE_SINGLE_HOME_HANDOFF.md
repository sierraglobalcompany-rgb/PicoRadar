# C13 Insurance Single Home Revision

## Latest Size/Legibility Delivery (2026-09-14)

Status: PARTIAL lot closure; requested visual changes implemented, tested and
installed. Final owner approval/full-suite/CI remain outside this handoff.
This section supersedes older 96 dp/small-vehicle descriptions below.

Git: codex/insurance-owner-mockup, unchanged HEAD/base
ddf60407174e3ee8d447b7eff3ca45e0fd983789. Worktree:
C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner.
191 tracked/untracked WIP entries at final audit, including explicit QA logs and
prior changes. No reset, commit, publication or merge. .planning preserved.

Scoped changes this iteration:
- insurance_owner_content.dart: native 80 dp plate, recovered image space,
  normal compact inline actions with 48 dp targets. Banner unchanged.
- branding.dart / vehicle_plate_badge.dart: optional microNumberFontSize, enabled
  only by Insurance at 20 dp. Default rendering in other modules is unchanged.
  Layout fits number and caption independently, preserving all characters.
- insurance_owner_screen_test.dart: transformed numeral height >=17 dp,
  plate 80 dp/2.15 ratio, legacy motorcycle, 144 dp target, viewport matrix.
- insurance_owner_review_test.dart: locate the same vehicle badge within its
  graphic frame; retain owner/focus/swipe assertions.
- plate_fidelity_test.dart: three cases for native small plate legibility and
  complete single-line legacy number; default plate tests retained.
- CURRENT, DESIGN_CONTRACT, checkpoint, this handoff and evidence LEEME.

Tests (mobile cwd, Flutter 3.47.1):
- dart format --output=none --set-exit-if-changed on the six Dart files: clean.
- flutter analyze: clean, temp-insurance-extra-vehicle-analyze.log.
- flutter test on the six insurance files listed below plus
  test/core/design_system/plate_fidelity_test.dart and
  test/features/pico_placa/presentation/pico_detail_screen_test.dart
  --dart-define=INSURANCE_SCREENSHOTS=true --reporter expanded: 355/355 pass.
  Log: temp-insurance-extra-vehicle-full-tests.log.
- flutter build apk --release --flavor dev --dart-define=APP_ENV=dev: pass,
  96.5 MB, log temp-insurance-extra-vehicle-build.log.
- Red tests documented actual number 10.714 dp and art slot 112 dp before fixes.

Physical QA: required and passed for this geometry on Mi A3, Android 11,
serial 116f2191b19a, 720x1560 / density 320; settings not changed.
Install -r preserved data. No policy/vehicle edits, calls, messages or documents.
Final APK PicoRadar-seguro-vehiculo-30-placa-legible-dev-release.apk, exported and
installed SHA256:
750e415b841cc2c0dd61130c43bb269ac977289dafebc44c9c3873391d8e6d76
Evidence directory: ../C13_INSURANCE_OWNER_QA_20260913/portada-unica/.
11 car /12 motorcycle are final physical screenshots; 09/10 precede the extra
30% request. 07 is the rejected small-number candidate, not final evidence.
The interrupted 08 capture was a demo sheet, moved to validacion and not labeled
as a motorcycle. No demo submission or data entry occurred.

Measured results: art 112 ->144 dp; sedan dark-pixel bounds (RGB<175 inside art
ROI, excluding shadow) 320x150 ->412x193 px, +28.8% width and +28.7% height.
Original small sedan was 203x95 px. Banner region x0..719/y70..627 has zero
changed pixels between 09 and 11. Plate 80x37.2 dp, 48 dp touch controls; car
roof/wheels and motorcycle wheels/mirrors complete, no home scroll.

Data/migrations/dependencies: none. Private wallet behavior and demo OFF-public
gates preserved. Earlier physical positive-auth/PDF-import debt remains open.
No broader release/performance claim. No next lot unblocked; approval pending.
Global git diff --check reports pre-existing CRLF/trailing whitespace in unrelated
C15/garage WIP. Left untouched rather than reformat another lot. Scoped Dart
formatter is clean; no global clean-worktree claim is made.

## Status
Owner-authorized correction of the rejected insurance preview. Implementation
and focused gates pass; physical installation/captures and owner approval are
tracked below. This is not global release approval or C15 debt closure.

## Git / Checkpoint
- Branch: codex/insurance-owner-mockup.
- HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789 (unchanged base).
- Worktree: temp/VIAJE-R1-real-planner.
- Extensive prior tracked/untracked WIP and .planning preserved.
- Checkpoint: .planning/INSURANCE_OWNER_CHECKPOINT.md.
- No reset, stage-all, unrelated rollback, commit, push or merge.

## Changes Owned by This Revision
- mobile/lib/features/vehicle_status/presentation/insurance_owner_content.dart:
  one home, no AppBar/title/tabs, integrated back, adaptive promotional hierarchy,
  stable contained carousel, tap-to-policy, centered fixed plate, improved
  policy/assistance/directory actions and metadata-independent document access.
- mobile/test/features/vehicle_status/presentation/insurance_owner_screen_test.dart:
  replace old tab assumptions with single-home geometry, loading/error, full
  viewport/text matrix and back target/surface bounds.
- mobile/test/features/vehicle_status/presentation/insurance_owner_review_test.dart:
  explicit-ID focus, no accidental opening on swipe, correct-owner authentication,
  metadata-less documents, names and two-line insurer header regression.
- docs/DESIGN_CONTRACT.md, docs/CURRENT.md and this checkpoint/handoff record the
  approved replacement, not a redesign of other modules.

## Behavior and Design
Back has a 36 dp translucent surface inside a 48 dp target, 8 dp from banner top
and left. Production/no-data states retain compact back navigation without a
promotional gap. No public commercial activation or transmission was added.
The 96 dp horizontal plate remains centered independently of adjacent controls;
legacy registration labels retain their renderer's measured height.
Full and compact compositions share one mounted PageController. Bigger screens
favor artwork; accessibility simplifies secondary content into existing sheets.
Normal constrained phones use a shorter banner and two side-by-side footer
actions. Larger screens can retain the ally link and stacked configured actions.
This deliberate adaptation avoids tabs/scroll without reducing font scaling.
Assistance still uses the opaque, ad-free existing route; documents use the
existing protected Wallet. No schema, dependency, catalog or metadata changes.

## Tests / Commands
Flutter 3.47.1, mobile/ working directory. Serial execution on Windows.
- Scoped dart format --output=none --set-exit-if-changed: three files, no changes.
- flutter analyze: no issues.
- flutter test (six files below) --dart-define=INSURANCE_SCREENSHOTS=true
  --reporter expanded: 226/226 pass (including 48 screen cases).
  insurance_directory_test.dart; insurance_quote_demo_test.dart;
  insurance_owner_screen_test.dart; insurance_owner_review_test.dart;
  insurance_owner_sheets_test.dart; vehicle_status_screen_test.dart.
  Paths are under test/features/vehicle_status/data/ for directory and
  test/features/vehicle_status/presentation/ for the other five.
- Visual run: flutter test
  test/features/vehicle_status/presentation/insurance_owner_screen_test.dart
  --dart-define=INSURANCE_SCREENSHOTS=true --reporter expanded.
  Final captures generated by the passing six-file invocation, not a failed run.
- Build: flutter build apk --release --flavor dev --dart-define=APP_ENV=dev.
- No full app-suite/publication/CI claim; owner visual approval remains required.

## Audit and Residual Risk
The original candidate failed real glyph bounds for banner/footer at enlarged
text, and a screenshot revealed plate-control overlap from a shrink-wrapped
Stack. Both were corrected, not accepted on widget-existence assertions.
The independent review identified the two-line insurer label/contact boundary;
it is fixed and covered by an added geometry regression.
Physical feedback rejected the 70fa2663 candidate: its early compact level hid
the headline. Level 2 now retains the image, headline and CTA, reducing policy
and footer first. Only extreme accessibility level 3 uses the short banner.
Actual Mi A3 system insets and long-name geometry have a dedicated regression.
Enlarged titles reflow to the full banner width when needed, without shrinking
fonts or clipping a long word. Registration height uses the catalog caption.
Latest feedback then requested 50% more promotional height: normal Mi A3 banner
increases from 186 to 279 dp. The short-phone artwork budget may fall below the
original indicative 112 dp, but stays contained and tappable. Text accessibility
retains compact alternatives without internal tabs. Latest 226 tests cover this.
Final owner correction restores exact quote/compare mockup headline and supporting
paragraph at normal scale. Height is at least 279 dp and grows for actual text.
Geometry checks every non-whitespace word: trailing line-wrap spaces no longer
produce false ink overflow; all visible bounds keep the original thresholds.
No physical import or positive credential authentication certification is added.
The previous directory audit remains valid evidence only of published sources,
not live channel response or exhaustive national coverage. No real phone call,
WhatsApp message or lead is required for this preview.

## Delivery / Next Step
Evidence folder: ../C13_INSURANCE_OWNER_QA_20260913/portada-unica/.
Final dev release built and installed -r on Mi A3 on 2026-09-14. Export and
installed hash match:
ff9b47cd86bce81a41497b4916cc26588498bbc473263e05bd5be5903c7896b3
APK: PicoRadar-seguro-portada-unica-dev-release.apk in the evidence folder.
Physical: normal banner 558 px / 279 dp instead of 372 px / 186 dp, +50%.
Headline and supporting paragraph restored for both states; quote/compare title
wraps in three lines without crossing the shield. Vehicle is smaller at this
priority on Mi A3, complete and tappable. No vertical home scroll or tabs.
Fresh captures 01-05: unconfigured, fictitious SURA, selector, ad-free assistance,
motorcycle. Temporary QAQ014 / QA-POL-014 only; no real policy edits or calls.
QA vehicle and its associated policy removed through Garage after the undo period;
four original vehicles remain and BOG127 is still the unique favorite.
Protected policy sheet opened on the correct owner; screencap rejected, not
disabled. No private document copied for evidence. Prior positive-auth/import
debt stays open. Legacy 9-character motorcycle plate keeps existing line grouping.
Git status: 176 tracked/untracked WIP entries at audit, preserved; no commit or
publication. Final approval and full-suite/CI remain pending. No next lot unlocked.
