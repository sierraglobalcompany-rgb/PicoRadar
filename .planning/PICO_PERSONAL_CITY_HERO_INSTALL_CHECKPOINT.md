# Checkpoint - Mi Pico city hero APK install

Date: 2026-09-11
Branch: codex/garage-single-favorite
Base HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789

Scope:
- Install the latest dev release APK that moves the Mi Pico city selector into the vehicle hero, aligned with the lower-right plate area.
- No merge, no device-side data wipe.

Changed files in scope:
- mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart
- mobile/test/features/pico_placa/presentation/pico_detail_screen_test.dart

APK:
- temp/PICO_PERSONAL_CITY_HERO_APK_20260911/picoradar-mi-pico-city-hero-dev-release.apk
- SHA256: 541AE3FF1CAE5B40D83022EE767536E94447103F7A21BD5AF0578D26264776E2

Verification before install:
- dart format --output=none --set-exit-if-changed lib/features/pico_placa/presentation/pico_detail_screen.dart test/features/pico_placa/presentation/pico_detail_screen_test.dart
- flutter analyze
- flutter test test/features/pico_placa/presentation/pico_detail_screen_test.dart
- flutter build apk --release --flavor dev

Device:
- adb device: 116f2191b19a

Notes:
- Install only, preserving app data with adb install -r.
