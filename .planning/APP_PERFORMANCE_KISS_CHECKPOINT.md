# APP PERFORMANCE KISS

Base: d2bb976f58ad380e51c38328a5cffe6d93c65721.
Branch: codex/app-performance-kiss. PR target: codex/home-owner-responsive.
Approved owner plan: startup visible, progressive Home, preserve functions/design,
measure before optimization, scoped runtime/cache fixes and proven cleanup.
No merge/deploy/backend/schema/dependencies/permissions changes.

## Ordered gates
1. Instrumentation only, then baseline release/profile builds and Mi A3 measurements.
2. Startup/core barrier and secondary loading; native brand; notifications.
3. Home/Pico/Garage repeated work; Trip/Driving cache/geometry regressions.
4. Reachability-based cleanup, no deletion of tests/QA functionality without proof.
5. Full gates, physical comparisons/perf, optimized dev release installed; debug simulation separately.

Evidence: temp/APP_PERFORMANCE_KISS. Preserve all previous temp and .planning.
## Resume checkpoint 2026-09-10, final physical validation

AUTHORITATIVE FINAL CUT: ddf60407174e3ee8d447b7eff3ca45e0fd983789, PR64,
normal push, NO MERGE. Mobile CI203/run34538412469 completed SUCCESS.
All local commands finished. Full suite1838PASS10SKIP; separate simulation
flag suite11PASS; DrivingScreen58PASS; format lib/test252 unchanged; analyzePASS.
Pre-existing enlarged Driving brand overflow fixed with Flexible; no other
post-measurement runtime change. Normal profile flows at1bcc, Driving final
and delivered release/simulation atddf6040; report keeps provenance separate.
18 final normal profile60s runs +10 memorycycles complete. Driving3tandas
each3x60s+10memorycycles complete, zero framework/async errors. Apps and
Driving maps FAIL95%raster goal; first Home/Garage and2radar runs also fail.
Do not claim global fluency. All unfavorable results retained.
Final release10cold+10warm complete: Home raster median884.840ms/p952207.026ms
cold inclfirstupdate; warm297.682/331.447ms. Physical tap/scanout not certified.
Phone: NORMAL optimized devRELEASE installed, hash0482e927dbaf294f9a30ed9fe35e95abf9c2caa59a569436b9e8f1d0292d181a
matches on-device base.apk. NO HARNESS INSTALLED. Threevehicles unchanged,
SQLitequick_checkOK, hashv2same before/after, no DB/rowexport, no datacleared.
Report temp/APP_PERFORMANCE_KISS/INFORME_RENDIMIENTO.md; requested ZIP
picoradar_performance_kiss_handoff.zip; external verificationJSON underfinal/.
Remaining acceptance debt: Apps/Driving slowframes, firstload Home/Garage,
touch/splash optical timings, nativecrossfade offset, unknownbanner reflow,
liveViaje/OSRM/profileleaks not certified. No automatic newlot/deploy/merge.
Historical progress below is superseded by this final cut.

Current HEAD c7a8e63820071cffdae23d1324c3538ccae3d384, pushed normally.
PR64 draft -> codex/home-owner-responsive; NO MERGE.
Production frozen. Final artifacts built at1bcc9d9; c7a8e63 only formatter
on Home carousel/test. Final release may be rebuilt after measurements.
cupertino_icons RETAINED: indirect Flutter references proved by release
compiler. pubspec/lock match base. Do not report it removed.
Full suite1838 PASS10SKIP, analyze PASS, source-format252files PASS.
CI201 failed formatting2files, corrected c7a8e63; latest CI pending.
Root-wide local format blocked by broken generated mobile/build path.
Final release physical10cold/10warm completed, no crash. Home raster cold
values2316,898,959,866,918,893,862,857,1094,870ms; first includes update.
Use raster_epoch_us, NOT log emission timestamp (batch delay~1second).
Normal profile installed now; profile-home3x60 command session7661.
Coordinator alone uses Mi A3. Remaining: all other final flows3x60,
memory10cycles, Driving harness3runs, compare captures, normal release
restored last, hashes/data identity/CI/reportZIP. No user data cleared.
APK signature+zipalign verified by Plato: profile size not corruption;
119MB refers compressed entries,147MB actual baseline and final.
Dalton: native launch video + timing evidence; Russell: Graphify+SKIP
audit; Plato: APK integrity report. Agents must not run Flutter/device.
Latest observation Home run1 raster94.85% fails95%target; retain failure.
Never mark globalDONE solely for tests/CI or faster startup.

## Historical baseline (superseded execution status)

Instrumentation committed dda1f9f; profile baseline frozen and measured.
Baseline dev release builds but fails before Flutter: Room WorkDatabase_Impl
no-arg constructor removed by R8. Minimal keep rule implemented, physical release pending.
Do not count failed release launches as usable startup measurements.
Baseline profile 10 cold/10 warm: Android TTID median1510/p951765ms cold,
151/171ms warm. Home post-frame approx2.2s, raster correlation unavailable;
do not label post-frame as exact display/presentation timing.
Baseline Home3x60s saved; raster96.37/98.82/97.24%, UI100%; first8s smoke
raster72.66%, separate first-load from steady state. Garage, Apps, Pico vehicle,
Pico city and Trip form each3x60 complete. Apps raster~83% baseline fails.
Ten memory cycles complete: image cache3386432 bytes stable; no claim leak-free.
Driving baseline harness complete: map camera raster56.33%, radar360 95.17%,
Cocorna map65.88%. One60s per mode; final needs repetitions. JSONs baseline/driving.
Frozen APKs: baseline-dev-release, baseline-dev-profile,
baseline-driving-harness-profile under temp/APP_PERFORMANCE_KISS/apk.
Runtime optimizations authorized after artifact freeze. Russell Home/Pico/Garage,
Dalton startup/native/notifications, Plato Trip/Driving. Flutter slots sequential.
Coordinator owns device and cleanup RootPlaceholder/AppTab placeholderText.
Phone baseline Driving profile harness stopped on launcher (NOT final use build).
Must install final normal dev release at close. No app data cleared.
Source reviews: Dalton secondary-slot stability/errors; Plato stable TileLayer
per generation/viewport after real RED; Russell fleet0/3/20 tests + Graphify.
Slots tests8green and broader192green; final source refinements underway.
Coverage expiry3green and Home/Pico/Garage420green. Trip/Driving563green10skip.
Coordinator initially removed cupertino_icons, then restored it after build
proved indirect font references. Current dependency unchanged from base.
Full gates/final builds/device A-B/PR/push/CI/export still pending.
Device: Mi A3 116f2191b19a; preserve three vehicles, do not clear app data.
Heavy Flutter builds/tests sequential; coordinator alone uses device.
Never declare global DONE solely from CI. Targets remain open until measured.
