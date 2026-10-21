# Compra/Venta Owner Handoff - 2026-09-15

## Status
`PARTIAL`

## Lot
`C12 - Apps launcher / Compra-Venta owner redesign`

## Git
- Branch: `codex/cda-owner-map`
- HEAD: `ddf60407174e3ee8d447b7eff3ca45e0fd983789`
- Base branch: `main`
- Worktree: dirty before this change; previous WIP preserved.

## Outcome
- Replaced the Compra/Venta form-first screen with a commercial cover matching the approved mockup direction: full-width sponsored demo carousel, circular back button inside the banner, buy/sell preparation routes, and a tools row.
- Added three public demo banners, all explicitly marked `Patrocinado - Demostracion`, with no ad network, leads, partner submission, or official/accredited claim.
- Follow-up visual correction: replaced the oversized fixed `440dp` banner with an adaptive sponsor banner capped at 32% of the viewport, moved the yellow `Conocer al aliado` CTA inside the banner, and compacted the preparation cards so tools begin in the first compact viewport.
- Added persistent local preparation progress for `Preparar mi compra` and `Preparar mi venta`.
- Added a text-only compraventa draft with preview and copy action. PDF generation and file sharing remain intentionally out of scope.
- Rewired Peritajes from Compra/Venta to one-shot GPS plus Google Maps search, with local catalog city fallback.
- Kept Comparendos, Tramites and Documentos routed to the existing modules.
- Final compact-cover correction: kept the approved sponsor banner intact, removed the vertical-scroll dependency in normal text on Mi A3, reduced the buy/sell cards and tools row, shortened the visible title to `¿Comprar o vender?`, and moved the guide explanation behind the compact info action when space is tight.
- Sponsor prominence follow-up: increased the sponsor banner height within a 35% viewport cap, kept the CTA inside the banner, and replaced the heavy opaque back circle with a smaller translucent visual circle while preserving a 48dp tap target.
- Tools emphasis follow-up: increased the four `Herramientas` tiles from 84/76dp to 92/84dp and enlarged their icons while keeping labels, one-row layout, routes and bottom navigation unchanged.

## Files / areas changed
- `mobile/lib/features/buy_sell/data/buy_sell_draft.dart`
- `mobile/lib/features/buy_sell/presentation/buy_sell_screen.dart`
- `mobile/assets/pico/buy_sell_banner_automotive_demo_v1.webp`
- `mobile/assets/pico/buy_sell_banner_appraisal_demo_v1.webp`
- `mobile/assets/pico/buy_sell_banner_transfer_demo_v1.webp`
- `mobile/lib/features/services/data/google_maps_service_search.dart`
- `mobile/lib/app/router/app_router.dart`
- `mobile/test/features/buy_sell/presentation/buy_sell_screen_test.dart`
- `.planning/BUY_SELL_OWNER_CHECKPOINT_20260915.md`
- `.planning/buy_sell_full_tests_initial_path_issue_20260915.log`

## Tests executed
| Command / test | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib/features/buy_sell/data/buy_sell_draft.dart lib/features/buy_sell/presentation/buy_sell_screen.dart lib/features/services/data/google_maps_service_search.dart lib/app/router/app_router.dart test/features/buy_sell/presentation/buy_sell_screen_test.dart` | Passed |
| `flutter analyze` | Passed, no issues found |
| `flutter test test/features/buy_sell/presentation/buy_sell_screen_test.dart` | Passed, 10 tests |
| `flutter test test/features/services/data/google_maps_service_search_test.dart` | Passed, 3 tests |
| `flutter test test/features/apps_launcher/presentation/apps_screen_test.dart test/features/services/data/google_maps_service_search_test.dart` | Failed in pre-existing adjacent WIP: Services overflow/pumpAndSettle timeout, Comparendos text expectation, Insurance title expectation. Compra/Venta route test passed inside this run. |
| `flutter build apk --flavor dev --release` | Passed, `mobile/build/app/outputs/flutter-apk/app-dev-release.apk` |
| `adb install -r mobile/build/app/outputs/flutter-apk/app-dev-release.apk` | Passed, streamed install `Success` on device `116f2191b19a` |
| Follow-up `adb devices` after visual correction | Passed after USB authorization; device `116f2191b19a` listed as `device` |
| `adb install -r mobile/build/app/outputs/flutter-apk/app-dev-release.apk` after visual correction | Passed, streamed install `Success` |
| Physical capture after visual correction | Passed, saved `C:\Users\felip\AppData\Local\Temp\picoradar-buy-sell-final.png` |
| Final compact-cover `dart format --output=none --set-exit-if-changed mobile/lib/features/buy_sell/presentation/buy_sell_screen.dart mobile/test/features/buy_sell/presentation/buy_sell_screen_test.dart` | Passed |
| Final compact-cover `flutter test test/features/buy_sell/presentation/buy_sell_screen_test.dart` | Passed, 10 tests |
| Final compact-cover `flutter analyze` from `mobile/` | Passed, no issues found |
| Final compact-cover `flutter build apk --flavor dev --release` | Passed, `mobile/build/app/outputs/flutter-apk/app-dev-release.apk` |
| Final compact-cover `adb install -r mobile/build/app/outputs/flutter-apk/app-dev-release.apk` | Passed, streamed install `Success` |
| Sponsor prominence follow-up `dart format --output=none --set-exit-if-changed mobile/lib/features/buy_sell/presentation/buy_sell_screen.dart mobile/test/features/buy_sell/presentation/buy_sell_screen_test.dart` | Passed |
| Sponsor prominence follow-up `flutter test test/features/buy_sell/presentation/buy_sell_screen_test.dart` | Passed, 10 tests |
| Sponsor prominence follow-up `flutter analyze` from `mobile/` | Passed, no issues found |
| Sponsor prominence follow-up `flutter build apk --flavor dev --release` | Passed, `mobile/build/app/outputs/flutter-apk/app-dev-release.apk` |
| Sponsor prominence follow-up `adb install -r mobile/build/app/outputs/flutter-apk/app-dev-release.apk` | Passed after `adb kill-server` / `adb start-server`, streamed install `Success` |
| Tools emphasis follow-up `dart format --output=none --set-exit-if-changed mobile/lib/features/buy_sell/presentation/buy_sell_screen.dart mobile/test/features/buy_sell/presentation/buy_sell_screen_test.dart` | Passed |
| Tools emphasis follow-up `flutter test test/features/buy_sell/presentation/buy_sell_screen_test.dart` | Passed, 10 tests |
| Tools emphasis follow-up `flutter analyze` from `mobile/` | Passed, no issues found |
| Tools emphasis follow-up `flutter build apk --flavor dev --release` | Passed, `mobile/build/app/outputs/flutter-apk/app-dev-release.apk` |
| Tools emphasis follow-up `adb install -r mobile/build/app/outputs/flutter-apk/app-dev-release.apk` | Passed, streamed install `Success` |

## Manual QA
- Automated widget checks cover the commercial cover, no visible `Compra/Venta` app-bar title, carousel labels, guide persistence, route callbacks, peritajes GPS URL, city fallback, and contract text flow.
- Follow-up widget checks cover banner height in 390x844, compact 360x780 visibility, CTA placement inside the sponsor banner, tools row visibility, and large-text compact variants.
- Physical visual QA on Mi A3 captured the corrected compact cover: adaptive banner preserved, yellow CTA inside the banner, buy/sell cards visible, `Herramientas` plus all four tools visible above the bottom navigation without scrolling.

## Physical Android QA
`Completed for visual checkpoint`
- Device: Mi A3
- Android: physical size `720x1560`, density `320`
- Evidence: latest tools emphasis APK installed preserving data; capture saved at `C:\Users\felip\AppData\Local\Temp\picoradar-buy-sell-larger-tool-icons.png`.

## Data / migration impact
- Preference key remains `buy_sell.draft.v1` for compatibility.
- Draft payload now writes schema version 2.
- Legacy v1 JSON migrates into the active buy/sell preparation without discarding old notes/checklist.
- No SQLite migration, backend change, or server sync.

## Security / privacy review
- No scraping, SIMIT automation, lead capture, payments, marketplace, chat, reservations, or ad network.
- Peritajes opens Google Maps only by explicit action.
- GPS is one-shot for peritajes and not persisted.
- Contract draft does not generate PDF and does not share files in this phase.

## Dependencies added/changed
- None.

## Known risks / debt
- Full suite is not green because of adjacent WIP outside this lot: Services, Comparendos and Insurance tests need their own stabilization.
- Initial full-suite checkpoint failed before execution because `flutter` was not in the default PowerShell PATH; later checks used `C:\Users\felip\.codex\tooling\flutter_3.47.1\flutter\bin\flutter.bat`.
- The commercial banner now uses generated local demo bitmap backgrounds without embedded text; custom final sponsor artwork can replace them later without changing logic.
- PDF generation for compraventa is explicitly deferred.
- Verified peritaje directory is explicitly deferred; current phase uses GPS/city Google Maps search.
- Latest APK SHA-256 after tools emphasis correction: `DB47B19AED19E00652A55012E8252FD474AC153F453EB98333CBEA48002952D6`.

## Stop conditions encountered
- Full visual approval and screenshot matrix remain pending. Physical Mi A3 capture for the primary Compra/Venta cover is complete; adjacent suite regressions remain outside Compra/Venta.

## Next lot(s) unblocked
- Compra/Venta visual QA on device.
- Future compraventa PDF generation.
- Future verified peritaje directory.

## Do not forget
- No merge performed unless human explicitly approved.
