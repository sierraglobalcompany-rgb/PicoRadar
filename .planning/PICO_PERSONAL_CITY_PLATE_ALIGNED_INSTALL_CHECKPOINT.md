# Checkpoint - Mi Pico city aligned with plate install

Date: 2026-09-11
Branch: codex/garage-single-favorite
Base HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789

Scope:
- Install the dev release APK where the Mi Pico city selector is centered in the right-side slot aligned with the vehicle plate.
- Preserve app data with `adb install -r`.
- No merge and no change to Inicio, Garaje, Conducir, GPS, or restriction engine.

Changed files in scope:
- mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart
- mobile/test/features/pico_placa/presentation/pico_detail_screen_test.dart

Verification before install:
- `dart format --output=none --set-exit-if-changed lib/features/pico_placa/presentation/pico_detail_screen.dart test/features/pico_placa/presentation/pico_detail_screen_test.dart`
- `flutter test test/features/pico_placa/presentation/pico_detail_screen_test.dart`
- `flutter analyze`
- `flutter build apk --release --flavor dev`

APK:
- temp/PICO_PERSONAL_CITY_PLATE_ALIGNED_APK_20260911/picoradar-mi-pico-city-plate-aligned-dev-release.apk
- SHA256: A9A78723221BEF6151C537E7AEC819D9C9144D85A71F22B98F1F75B6D28EA624

Device:
- adb device: 116f2191b19a
