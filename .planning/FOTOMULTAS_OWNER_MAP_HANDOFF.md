# Fotomultas owner map handoff

## Latest revision: conditional selection, translucent controls and inventory header

Installed optimized dev release, data kept, SHA256
93ea8d2d5c9bc78ff0b72ea2f9e8df737617c6b16171be49c267611a7c0d6888.
64 focused tests passed; analysis/format/build clean. Physical national/Antioquia
screenshots inspected. Full handoff: temp/FOTOMULTAS_OWNER_MAP/COMPACT_SELECTION_HANDOFF.md.
APK: PicoRadar-fotomultas-header-dev-release.apk in that folder. Approval pending.

## Earlier owner revision: no dedicated island inset

The owner requested removal of the San Andres/Providencia/Santa Catalina inset.
Removed `_IslandInset`, its extra FlutterMap and label exclusion rectangle.
Geometry/catalog remain intact and the long-name search test still passes.
62 focused tests pass; analyze clean; two changed Dart files format clean.
Optimized dev release built and installed -r on Mi A3; physical screenshot inspected:
`temp/FOTOMULTAS_OWNER_MAP/physical/final-no-inset.png`.
Current APK: `temp/FOTOMULTAS_OWNER_MAP/PicoRadar-fotomultas-no-inset-dev-release.apk`.
Exported/installed SHA256:
`0025bf001c152c70ad453bdad3df21a0bf8bcb1afff3cb9b5c9e292643b23963`.
No other feature changes, commits or merge. Remaining preview gates below unchanged.

## Status
PARTIAL - preview implemented and physically installed; owner visual approval,
formal performance QA, full suite and publication remain open.

## Lot
C16 / Flow 05 owner-authorized manual Apps inventory explorer exception.
Scope: Fotomultas only. No Driving matcher, GPS or dataset changes.

## Git
- Branch: `codex/fotomultas-owner-map`.
- HEAD: `ddf60407174e3ee8d447b7eff3ca45e0fd983789` (unchanged).
- Entry/base branch: `codex/pico-city-owner-mockup`, with extensive prior WIP.
- Worktree: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner`.
- Git status: 42 tracked modifications and 23 untracked entries, including prior
  Home/Garage/Pico/Detail/Apps changes. No new commit, push, PR or merge this run.
- HEAD alone does not reproduce the installed APK. Do not reset this worktree.
- `temp/FOTOMULTAS_OWNER_MAP/entry-fotomultas.patch` records the pre-existing
  Fotomultas changes relative to HEAD; isolate new work against that baseline
  before publishing. Do not claim the entire HEAD diff as this implementation.

## Outcome
- Real DANE national polygons, 33 territories, progressive measured labels,
  pan/pinch/reset, ambiguous selection sheet, search, explicit camera opening.
- Stable selection area with accessibility fallback and partial-coverage sheet.
- Projected camera groups preserve all records; zoom controls, coincident record
  picker, explicit location, empty-filter/view-toggle camera preservation.
- Local geometry errors remain visible with explicit retry. No new runtime deps.

## Files / areas changed
- `mobile/lib/features/fotomultas/presentation/fotomultas_screen.dart`
- `mobile/lib/features/fotomultas/presentation/department_geometry.dart`
- `mobile/lib/features/fotomultas/presentation/national_department_map.dart`
- `mobile/lib/features/fotomultas/presentation/national_department_view.dart`
- `mobile/lib/features/fotomultas/presentation/department_camera_map.dart`
- `mobile/test/features/fotomultas/presentation/fotomultas_screen_test.dart`
- `mobile/test/features/fotomultas/presentation/department_geometry_test.dart`
- `mobile/assets/maps/colombia_departments_dane2025.geojson` and `README.md`
- `mobile/tool/prepare_department_geometry.mjs`
- `mobile/pubspec.yaml`: only local asset registration in this run.
- This checkpoint/handoff and ignored local `temp/FOTOMULTAS_OWNER_MAP` evidence.

## Tests executed
Run from `mobile` using Flutter 3.47.1 in local `.codex/tooling`.

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib/features/fotomultas/presentation test/features/fotomultas/presentation` | 7 files, zero changes |
| `flutter analyze --no-pub` | No issues |
| `flutter test test/features/fotomultas/presentation --reporter expanded --no-pub` | 62 passed, latest run exported final automated screenshots |
| `flutter build apk --release --flavor dev --dart-define=APP_ENV=dev` | Success, final build 54.9 seconds |
| `adb -s 116f2191b19a install -r ...apk` | Success, no data clear/uninstall |
| Local SHA256 vs installed base.apk SHA256 | Equal |

TDD failures observed before correction: rectangles/no PolygonLayer; map controller
destroyed by empty filter; no dedicated empty-inventory sheet; geometry error hidden
by automatic retry. All associated tests now pass. Ten mount/unmount cycles are
widget lifecycle checks, not a memory leak test.

## Manual QA
- Real-font/geometry captures with bottom shell: 360x780, 360x800, 390x844,
  412x915, 430x932, text 1/1.5/2. Long archipelago title also checked.
- Automated pinch/pan do not select or reload; small-territory candidates, label
  collision checks, inventory counts, every coincident fixture record, source errors.

## Physical Android QA
Required and partially passed; formal performance/pinch/offline work still open.
- Device: Mi A3 `116f2191b19a`, Android 11, 720x1560, 320 dpi.
- Actual national screen, selection via map and search, zoom +/-, nested department
  exploration, hardware-back restoration, island selection, empty inventory and
  sources inspected. National screen fits without outer scrolling at normal text.
- Actual camera group 76 separated to 69+7, then 63+6 on repeated group zoom.
- Full physical screenshot index: `temp/FOTOMULTAS_OWNER_MAP/README.md`.
- Phone left on Fotomultas national view. Private vehicles/settings preserved.

## APK
- `temp/FOTOMULTAS_OWNER_MAP/PicoRadar-fotomultas-owner-map-dev-release.apk`
- 96,617,745 bytes, SHA256:
  `9ede57ef744a4540d21be229462c6aed24786ad55259b46c2e46dc2987ec6160`.
- Dev release optimized local signature; not a store publication; no debug-only
  Driving simulation. Installed package is `co.picoradar.app.dev`.

## Data / migration impact
- No schema, camera inventory, vehicles or preferences changes.
- New 2,090,116-byte geometry derived from DANE 2025: 33 unique units, 90 components,
  72 shared-boundary adjacency pairs preserved. Attribution/provenance in asset README.

## Security / privacy review
- No GPS requests in national or department exploration, no route history.
- National map uses no tiles; department uses existing OSM policy-compliant network
  provider identification/default cache. No singleton reconfiguration or bulk downloads.
- Camera/source links remain user-triggered. Source speed is not a verified limit.
- Tests use fake tiles; artifacts are local. No private data uploaded.

## Dependencies added/changed
- Runtime: none. Existing flutter_map 8.3.2 retained.
- Development-only: `npx --package mapshaper@0.7.61` for joint simplification;
  Node built-ins transformation script. Raw/intermediate geometry stays under temp.

## Known risks / debt
- Owner visual acceptance not obtained. Do not claim pixel-perfect fidelity.
- Need physical two-finger gesture verification, Flutter UI/raster profiling,
  memory/cache measurements and Viaje-before/after cache regression.
- `dumpsys gfxinfo` saw only host-view frames, unsuitable for Flutter FPS evidence.
- No physical offline/network interruption or TalkBack/tablet certification yet.
- Camera grouping tests and sampled physical interaction are not a visit to all 360
  records. The inventory remains partial and may have anomalous declared locations.
- Full Flutter suite, broader regressions and CI deferred until visual approval.
- Existing Cierre Global/Flow05 no-map exception is owner-authorized in checkpoint;
  formal final documentation update belongs to the post-approval closure.
- OSM HTTP cache is default library behavior, not a new guaranteed hard size limit.
- APK-size optimization and earlier unrelated performance debts remain separate.

## Stop conditions encountered
No implementation blocker. Preview boundary reached; owner approval required for
visual closure. Large prior WIP prohibits indiscriminate commit/publication.

## Next lot(s) unblocked
None declared closed/unblocked. Continue this scoped review with owner feedback,
then complete outstanding QA and isolate publication. Preserve `.planning/`.

## Do not forget
No merge performed or authorized. No reset, rebase or cleanup of earlier WIP.
