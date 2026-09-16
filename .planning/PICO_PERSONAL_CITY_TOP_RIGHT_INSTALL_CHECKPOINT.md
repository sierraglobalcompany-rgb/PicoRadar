# Checkpoint - Mi Pico city chip top-right install

Date: 2026-09-11
Branch: codex/garage-single-favorite
Base HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789

Scope:
- Install the dev release APK where the Mi Pico city chip moves to the upper-right of the hero.
- City chip is compact for Bucaramanga/Villavicencio and keeps full text in tooltip/semantics.
- Plate remains centered below the vehicle with additional breathing room before the summary card.
- Preserve app data with `adb install -r`.

Changed files in scope:
- mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart
- mobile/test/features/pico_placa/presentation/pico_detail_screen_test.dart

Verification before install:
- `dart format --output=none --set-exit-if-changed lib/features/pico_placa/presentation/pico_detail_screen.dart test/features/pico_placa/presentation/pico_detail_screen_test.dart`
- `flutter test test/features/pico_placa/presentation/pico_detail_screen_test.dart`
- `flutter analyze`
- `flutter build apk --release --flavor dev`

APK:
- temp/PICO_PERSONAL_CITY_TOP_RIGHT_APK_20260911/picoradar-mi-pico-city-top-right-dev-release.apk
- SHA256: BB32581099F84D2735EF1590DAAA48588B00A50B9612C72FD48C7A4063BD7F15

Device:
- adb device: 116f2191b19a
