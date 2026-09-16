# Pico city owner mockup checkpoint

Date: 2026-09-12. Stage: implementation started, not visually approved.
Worktree: temp/VIAJE-R1-real-planner.
Branch: codex/pico-city-owner-mockup.
Base HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
Previous branch: codex/garage-single-favorite; extensive previous WIP preserved.
The base commit alone does not reproduce the installed application.

Scope: only Apps / city Pico presentation. No personal Pico, Home, Garage,
Driving, dataset or engine redesign. Sources, dates and vehicle context remain
local. A dated week replaces duplicate rotation/rule/week blocks. Rule/source
and vehicle lists move into sheets. Navbar stays fixed. Scroll only when needed.

Before evidence and scoped file copies: temp/PICO_CITY_OWNER_MOCKUP/before/.
Reference: temp/PICO_CITY_OWNER_MOCKUP/reference.png.
These copies identify the new delta within the pre-existing modified files.

Execution: UI -> targeted tests/analyze -> checkpoint -> dev release build ->
install -r preserving data -> physical screenshots and owner visual approval.
Full-suite closure/publication follows owner approval. No merge.

## Pre-install checkpoint

Implementation candidate: dated week, grouped windows, integrated navy scene,
category assets, source/rule sheet and explicit vehicle selector. Old collective
cards removed; private UI isolated in city_pico_widgets.dart. Personal view kept.
Visual text measurements now inherit the rendered font. A dated exception
earlier in the displayed week retains date labels. Vehicle-sheet expiry,
midnight, dataset, retry and list updates are covered by focused tests.

Validation before APK: 114 focused tests passed before the last isolation of
vehicle loading from the city page; final rerun in progress. Analyzer passed.
Automated snapshots are under temp/PICO_CITY_OWNER_MOCKUP/automated/;
names containing viewport width x height identify the updated captures.
Physical pre-install capture: before/device-before-install.png.

Install only the successful dev release APK with adb install -r, serial
116f2191b19a. Do not uninstall or clear data. Release does not expose simulation;
debug simulation remains a separate variant, not claimed for this APK.
Physical comparison and owner approval remain pending at this checkpoint.

Final focused rerun before build: 116 tests passed, including vehicle-list error
isolation/recovery and empty list. Log: temp/PICO_CITY_OWNER_MOCKUP/focused-tests.log.
Formatting check passed for the three scoped Dart files. APK build starts only
after the final analyzer completes successfully.

## Installed preview / handoff

2026-09-12: dev release built and installed on Mi A3 with -r. APK SHA256:
34BE13B7F42FAC7489A9AD706139FBF7E906583935950DE5BB91F1F4B5D5BD5E.
Pulled installed base.apk matches. Data preserved. GPS auto restored in Medellin
after explicit-adoption QA; current screen left at city Medellin/carros.
Final focused set: 117 tests pass; extra test covers distinct/multiple windows.
Report, command logs and screenshot index: temp/PICO_CITY_OWNER_MOCKUP/REVIEW.md.
APK: temp/PICO_CITY_OWNER_MOCKUP/PicoRadar-pico-ciudad-dev-release.apk.
Physical evidence: temp/PICO_CITY_OWNER_MOCKUP/physical/.
Owner visual approval still pending. No new production edits after the build.
Next: obtain visual feedback before full-suite closure, contract publication,
isolated commits and CI. No merge. Preserve all previous WIP and checkpoints.
