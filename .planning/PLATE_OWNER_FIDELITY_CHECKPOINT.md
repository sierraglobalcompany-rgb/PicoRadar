# Plate owner fidelity

## Latest installed: countdown with moving hand (2026-09-11)

Owner requested a clock hand advancing every second after countdown preview.
Implemented private 16 dp CustomPainter with local decorative 1 Hz timer and
isolated repaint. Circle and short hand stay fixed; long hand advances 6 degrees
per second. Shared restriction clock and displayed countdown stay per-minute.
Timer stops for disabled TickerMode, covered ModalRoute, background, reduced
motion and disposal. Pixel tests verify rotation/static modes, route covering,
resume, and unchanged daily snapshot. No new dependency/provider/backend change.
399 focused tests PASS; analysis PASS; source format PASS; diff check PASS;
dev release build PASS. This is preview acceptance, not full-lot closeout.
APK: temp/PLATE_OWNER_FIDELITY/apk/picoradar-home-clock-hand-dev-release.apk
SHA256: 2746049C639DC458FF04E90CFCCCA491BC0D985899552E042B4F2D474D610A49
Installed package hash matches; install -r, data retained, no harness.
Physical evidence: clock-hand-frame-a.png / clock-hand-frame-b.png, same 01:49
minute and countdown text; 49 changed pixels within the 32 x 32 px clock ROI.
Video: temp/PLATE_OWNER_FIDELITY/screenshots/clock-hand-mi-a3.mp4 (8s recording).
Phone left on Home BOG127. All required build/test/record processes completed.
No commit/push/merge. Wait for visual approval before full regression/publication.
Report: temp/PLATE_OWNER_FIDELITY/INFORME_CONTADOR_INICIO.md.

## Latest countdown preview + requested clock hand (2026-09-11)

Countdown implemented on shared minute clock, 397 focused tests PASS, analysis
PASS, source format PASS, release build PASS. Installed APK matches hash:
09C94DAE246C2FA5DDB08BC47FED22F6DEAFEF067696E5A5B11BF40CA579153E
APK: temp/PLATE_OWNER_FIDELITY/apk/picoradar-home-countdown-dev-release.apk.
Physical BOG127: 01:35 -> Empieza en 3 h 25 min; left untouched, 01:37 ->
Empieza en 3 h 23 min. Card remains 100 dp. Evidence countdown-after.png and
countdown-next-minute.png; report INFORME_CONTADOR_INICIO.md.
NEWEST REQUEST: animate ONLY clock hand once per second. Text stays per minute.
Implement small isolated repaint, stop when hidden/background/reduced motion.
This explicitly supersedes the earlier static-icon requirement, not the shared
clock/data contracts. Not implemented yet at this checkpoint.
No commit/push/merge; full-lot closure still awaiting visual approval.

## Latest title centering correction (2026-09-11)

Owner additionally reported off-center nickname/brand/fallback. Confirmed
16 dp offset by three failing geometry tests; corrected symmetric title reserves
(32 dp left and right) and enlarged-text width measurement (card width - 88).
350 focused tests PASS, including 12 additional width/text-scale cases.
Analyze PASS, source format 255 files / 0 changes PASS, diff check PASS,
dev release build PASS. Installed with data preserved and identical package hash.
APK: temp/PLATE_OWNER_FIDELITY/apk/picoradar-home-centered-title-dev-release.apk
SHA256: 7CD73F266E35F678C789AF2AB10B4C5EE8F04D992D1CEF552FA39DD93010669D
Physical screenshots: centered-title-home-first/brand/fallback.png.
Phone left on first vehicle. No tests/build sessions running.
96 dp plate and 64 dp obligation cards retained; no behavior/data changes.
Full lot closeout (full suite, performance, publication, CI) remains pending.
No commit/push/merge. Prior entries below are history, not latest APK identity.

## Latest 96 dp + compact obligations preview (2026-09-11)

LATEST: owner explicitly approved the 96 dp plate visual design in conversation.
Then requested shorter SOAT/RTM cards, retaining internal text/icon sizes.
Implemented 72 -> 64 dp normal height, vertical padding 8 -> 4 dp. Existing
carousel measurement gains 8 dp. No changes to data, GPS, detection or backend.
Plate geometry: 96 x ~46 dp, 20 sp number / 7 dp emblem / 10 sp caption.
Three rows; footer baseline region shares lower slot row. Home plate padding 2/4.
Physical actual vehicle body width 162.5 and 163 dp vs 96 dp plate after cards.
Evidence: temp/PLATE_OWNER_FIDELITY/INFORME_COMPACTO_96.md.
APK: temp/PLATE_OWNER_FIDELITY/apk/picoradar-home-compact-obligations-dev-release.apk
SHA256: 355FBE5ECCA7163A547E1E8C6FB9881827CAEFF3FA58BE3C1933DDF3BF9D02E4
Installed package SHA matches independently; install -r, no data reset.
338 focused tests PASS (export test not enabled in final focused run).
Analyze PASS; source format 255 files / 0 changes PASS; diff check PASS;
dev release build PASS. Previous 96 dp run: 335 tests including image export.
Current branch codex/plate-owner-fidelity, HEAD ddf6040; no commit/push/PR/merge.
Full suite, performance regression and CI still pending for lot closeout.
Do not reuse old 1843-pass suite as certification. Prior performance debt open.
Phone left on Home first vehicle with latest normal release, no harness.
Owner approval of plate does not imply approval of all earlier implementation.

## Historical 128 dp preview (superseded)

## Active correction 2026-09-11

LATEST / WAITING FOR OWNER VISUAL APPROVAL:
Owner liked the plate design but rejected 136 dp as still too large and asked
for larger internal letters. Installed latest variant: 128 dp, approx 60 dp
height, 26 sp number, 9 dp emblem, 3 dp outer margin. Trial 124 dp failed wide
groups; 128 dp passes them horizontally without deforming or shrinking glyphs.
APK: temp/PLATE_OWNER_FIDELITY/apk/picoradar-plates-compact128-preview-dev-release.apk
SHA256: A00EAC766BDC13419524CDCE49AF9795A7B9B800F3D9BC56A32418B7221C8490
Installed package hash independently matches. adb install -r, no data reset.
334 focused tests including automated export PASS; analyze PASS; source format
255 files / 0 changes PASS; git diff --check PASS; dev release build PASS.
Physical captured: both Home and Garage vehicles, personal Pico from Home and
city shortcut, full city shortcuts, Home focus retained after return. Phone
left on Home second vehicle. No active build/test processes remain.
Evidence/report: temp/PLATE_OWNER_FIDELITY/INFORME_VISTA_PREVIA.md.
DO NOT run closure/commit/push/PR until visual approval. No commit/push/merge
made for this lot. Full suite and CI need rerun AFTER approval of latest code;
old 1843-pass full suite was before these visual changes. Performance debt open.

Owner rejected 160 dp plate and missing emblem on legacy six-character record.
Superseding approved plan: compact 136 dp / 24 sp number / 9 dp emblem;
visual 3+3 grouping of all six alphanumeric characters without data mutation.
Home allowed-day summary now follows green-check reference, white main text,
no underline; restricted/unknown/stale phases remain unchanged.
IMPORTANT: install preview and await OWNER VISUAL APPROVAL before closeout.
No new commit/push/PR until that approval. Existing WIP preserved.
First rejected APK hash EEC658576968A471F8845A2A2202CF504C198155696CC112F0666B58EA9389C7.
Focused correction tests running; do not reuse old full-suite pass to certify new changes.

## Earlier implementation history (not current acceptance)

Approved scope: Home, Garage, personal Pico and vehicle shortcuts in city Pico.
Branch: codex/plate-owner-fidelity from ddf60407174e3ee8d447b7eff3ca45e0fd983789.
PR target: codex/app-performance-kiss. NO MERGE / NO DATA RESET.

Implemented WIP: shared plate with one inset border, separate character groups,
original transit-inspired circular emblem, four horizontal fixing slots.
VehiclePlateBadge reuses local registration catalog for municipality only;
motorcycles always COLOMBIA. Persistent vehicle fields unchanged.
Legacy unrelated consumers preserved. Adaptive content height preserves vehicle
space at enlarged text; fixed-height Pico shortcut layout now measures plate.

Verification: red tests reproduced old outer border and absent group widgets.
New plate geometry/adapter/48-case layout matrix and visual export PASS (5 tests).
Initial integration failures captured under temp/PLATE_OWNER_FIDELITY/logs.
Third integration pass running; prior failures include stale text finders,
enlarged layout, async city picker test. Do not claim completion yet.

Next: finish integration/full gates, physical optimized APK QA, comparisons,
docs/report, normal commit/push/PR and CI. Keep phone data; install -r only.
Evidence directory: temp/PLATE_OWNER_FIDELITY. No requested ZIP for this lot.
Prior performance debt remains open; this visual lot does not close it.
