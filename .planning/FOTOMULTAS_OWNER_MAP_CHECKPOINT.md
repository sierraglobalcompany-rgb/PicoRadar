# Fotomultas owner map checkpoint

## Follow-up: inventory in header - 2026-09-12

Completed final preview: 64 tests, clean analysis/format, dev release built in 55.1 s.
Installed -r, actual base.apk hash matches exported header APK:
93ea8d2d5c9bc78ff0b72ea2f9e8df737617c6b16171be49c267611a7c0d6888.
Reviewed physical/header-after-national.png and header-after-antioquia.png.
Device left with Antioquia selected. Approval/full suite/publication remain open.

Pre-build/pre-install gate: 64 tests PASS, analyze clean, format 4 files unchanged.
Header uses Fotomultas 20 sp close to back (48 dp leading + 4 dp spacing), right
summary camera/count 14 sp and ANSV + dd/MM/yy 12 sp. True inventory date only.
Text metrics determine side-by-side versus stacked accessibility layout. Removed
duplicate body metrics; existing search, map, compact selection and footer retained.
Automated header-automated captures reviewed; replacement release authorized.

- Owner requests moving inventory summary to the right of Fotomultas and moving
  title closer to back. Two lines: camera icon/count, ANSV and real short date.
- Before: compact-after-national.png / compact-after-antioquia.png. Compact APK
  already installed and verified; preserve conditional card/translucent controls.
- Scope national header only; enlarged text may reflow instead of clipping.
- New checkpoint before edits and later replacement release/install.

## Entry: conditional compact selection - 2026-09-12

### Pre-build / pre-install

Completed preview: optimized dev APK built, installed -r on Mi A3 and SHA matched:
d6c09d3a5f03a689fd9381cf0467638132aedac686379d1b5daab7287538aa84.
64 tests/analyze/format passed. Physical empty/Antioquia/zoom/back/reset inspected.
Device left on country map; owner approval still pending. Delivery and exact
commands: temp/FOTOMULTAS_OWNER_MAP/COMPACT_SELECTION_HANDOFF.md.

- Implemented conditional selection below flexible map. Normal card measured
  approximately 74 dp including border (was 140); no empty widget or reservation.
- Name/count and camera button share a row. Measured long/scaled content falls
  back to the existing sheet access if the map would fall below 220 dp. Extreme
  long names use Ver departamento; tooltip/sheet retain full name without clipping.
- Country controls: 36 dp translucent surface (white alpha .78), 48 dp tap area;
  reset has 13 sp label or accessible icon with enlarged text. Explorer unchanged.
- Selection retains map controller/center/zoom. Search/reset fit after new layout.
- 64 focused tests PASS; analyze PASS; format gate 3 files / no changes.
- Screenshots reviewed in compact-automated (5 viewports x 3 scales, long names).
- Fresh physical before screenshots: physical/compact-before.png (Cauca),
  physical/compact-before-antioquia.png; no-selection baseline final-no-inset.png.
- Ready to build release dev APP_ENV=dev then install -r only on authorized Mi A3.
- Still pending physical QA, owner approval and later full-suite/publication.

- Owner approved removal of the empty 140 dp selection reservation. Selected
  department card stays below the map, with name/count and explicit camera action.
- Keep national map flexible, other controls content-sized; preserve camera when
  selection changes, fit current viewport only on explicit country reset/search.
- Preserve removed island inset, inventory and all earlier WIP. No merge.
- Before: physical/final-no-inset.png and physical/final-antioquia.png under
  temp/FOTOMULTAS_OWNER_MAP. Current installed APK hash remains
  0025bf001c152c70ad453bdad3df21a0bf8bcb1afff3cb9b5c9e292643b23963.
- Next: independent layout/camera regressions, minimal private presentation edits,
  focused tests/analyze, pre-install checkpoint, optimized APK and physical QA.

## Owner correction: remove island inset - 2026-09-12

- Requested removal of the San Andres/Providencia/Santa Catalina module.
- Removed the dedicated inset and its extra FlutterMap, plus the label exclusion
  rectangle. The national geometry/catalog/inventory remain intact; the territory
  can still be found via search. Zero inventory records are not proof of no cameras.
- Updated regression test verifies no inset and only one national FlutterMap at
  scales 1/1.5/2, retaining the long-name test via the search sheet.
- Regression was red before removing the inset. No changes to other features.
- Checkpoint before replacement release build/install; results and new APK hash
  will be recorded in the delivery report after validation.
- Completed: 62 focused tests, analyze and formatting passed; release built and
  installed -r on Mi A3. Inspected `physical/final-no-inset.png`: inset absent.
- Current APK `PicoRadar-fotomultas-no-inset-dev-release.apk`, installed/exported
  SHA256 `0025bf001c152c70ad453bdad3df21a0bf8bcb1afff3cb9b5c9e292643b23963`.

## Entry - 2026-09-12

- Worktree: temp/VIAJE-R1-real-planner.
- Entry branch: codex/pico-city-owner-mockup.
- HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
- Extensive pre-existing WIP in Garage, Home, Personal/City Pico, vehicle detail,
  other Apps modules and documentation is preserved. HEAD is NOT the installed UI.
- Existing Fotomultas screen/test already contain uncommitted integral-plan work.
- Baseline focused suite: 30 tests passed during physical audit.
- Before screenshots: OS temp/fotomultas-plan-{current,middle,antioquia,group}.png.

## Approved scope

Real local DANE department geometry; national map with progressive labels, search,
selection then explicit camera explorer; compact footer. Correct camera groups and
zoom within the existing explorer. No other feature redesign or data migration.
National explorer is the owner-approved exception to baseline no-map for Apps only:
no GPS, navigation, camera inventory expansion or Driving matcher changes.

## Execution gates

1. Preserve WIP; create codex/fotomultas-owner-map.
2. Prepare and verify local geometry with reproducible development-only tooling.
3. Implement national UI and department group correction; focused tests/analyze.
4. Checkpoint before release APK/install -r on Mi A3; physical comparisons.
5. Wait for visual approval before full-suite closure and isolated publication.

Release APK does not expose debug-only driving simulation. No merge.
Implementation, physical QA, visual acceptance and publication are separate gates.

## Pre-build / pre-install checkpoint - 2026-09-12

- Branch now `codex/fotomultas-owner-map`; HEAD unchanged. All earlier WIP preserved.
- National map uses local DANE geometry with 33 territories / 90 components;
  source 42 MB simplified jointly to 2,090,116 bytes, 72 adjacencies retained.
- Added geometry preparation script and provenance README; no runtime dependency.
- New private map/view parts, geographic hit testing, progressive labels, search
  sheet, explicit selection/open, island inset, compact footer and error recovery.
- Department map groups by projected 64 dp separation at current zoom, opens all
  coincident records, preserves camera when toggling views/empty filters, provides
  explicit individual location. Driving and inventory data remain unchanged.
- Format gate: 7 files, zero changes required.
- `flutter analyze --no-pub`: no issues.
- `flutter test test/features/fotomultas/presentation --reporter expanded --no-pub`:
  58 passed. Includes geometry, real inventory, 5 viewport sizes x 3 text scales,
  bottom navigation, pan/pinch without selection/reload, small territory ambiguity,
  coincident records and restoration. Public tiles replaced in tests.
- Test captures: `temp/FOTOMULTAS_OWNER_MAP/automated/`.
- Fresh physical BEFORE: `temp/FOTOMULTAS_OWNER_MAP/physical/before-national.png`.
- Mi A3 `116f2191b19a` authorized/connected; install only with `adb install -r`.
- Next: build `--release --flavor dev --dart-define=APP_ENV=dev`, export APK/hash,
  install, compare physical national/selected/zoomed/explorer screenshots.
- Still open: physical fidelity and pan/pinch performance; 10-cycle lifecycle /
  memory evidence, owner approval, full suite, documentation closure and CI.
- Do not describe this checkpoint or passing tests as visual acceptance.

## Second candidate checkpoint - before final build/install

- First release built (92.1 MB), installed with data preserved, physical national,
  candidates, Antioquia highlight/zoom and explorer captures inspected.
- Physical clustering: national ANT group 76 separated to 69 + 7, then 63 + 6
  when zooming; markers no longer overlap. Tap-to-select does not auto-open.
- Follow-up fixes: zero-inventory territory opens explanatory sheet without tiles;
  explorer inventory date is readable; title uses existing navy typography.
- Recovery test exposed automatic Riverpod retry hiding the local geometry error;
  local geometry now retries only through the explicit action.
- Final focused suite: 62 passed; analyze: no issues; formatted files unchanged.
- Ten mount/unmount cycles passed as widget lifecycle checks, NOT a memory-leak
  measurement. Physical pinch and Flutter UI/raster profile still need formal QA.
- Native `dumpsys gfxinfo` observed only 2 host-view frames despite map interaction;
  it cannot certify Flutter frame timing and is not used as performance evidence.
- Next: rebuild release, install -r, export matching APK/hash, refresh final captures,
  handoff with open approval and performance gates. No publication or merge yet.

## Preview delivered - 2026-09-12

- Final suite 62 passed, analyze clean, formatting gate clean; final release built.
- Exported and installed APK SHA256 both:
  `9ede57ef744a4540d21be229462c6aed24786ad55259b46c2e46dc2987ec6160`.
- APK: `temp/FOTOMULTAS_OWNER_MAP/PicoRadar-fotomultas-owner-map-dev-release.apk`.
- Final physical captures inspected: national, Antioquia selected, explorer,
  hardware-back restoration, island/long name, empty inventory sheet, sources.
- Report/index: `temp/FOTOMULTAS_OWNER_MAP/README.md`.
- Handoff: `.planning/FOTOMULTAS_OWNER_MAP_HANDOFF.md`.
- Waiting for owner visual approval. Formal performance/memory, physical pinch,
  full regressions and publication remain explicitly open. No merge.
