# Checkpoint: Mi Pico y Placa city chip top-right fix

Date: 2026-09-11
Branch: codex/garage-single-favorite

## Context

User rejected the previous Mi Pico y Placa city chip placement because the
`Medellín` chip rendered over the vehicle instead of the actual top-right of
the hero.

## Current Evidence

- Before screenshot:
  `temp/PICO_PERSONAL_CITY_CHIP_AUDIT_20260911/current-mi-pico-city.png`
- APK built before installation:
  `temp/PICO_PERSONAL_CITY_CHIP_AUDIT_20260911/picoradar-mi-pico-city-chip-top-right-dev-release.apk`
- APK SHA256:
  `EEBB745F0C4A881D56B139628FBF6ECFE41BFF27E53B650B4DE42306ED7404D2`

## Changes Made

- Moved the Mi Pico y Placa city chip to the hero top-right rail.
- Moved the vehicle name below the top control rail to avoid overlap.
- Shifted the vehicle image down slightly and reduced its hero scale so the
  chip no longer sits on the vehicle.
- Hardened `pico_detail_screen_test.dart` so the city chip must be within
  8-16 dp from the hero top, not overlap the vehicle name, and remain well
  above the plate.

## Verification Before Install

- `dart format --output=none --set-exit-if-changed lib/features/pico_placa/presentation/pico_detail_screen.dart test/features/pico_placa/presentation/pico_detail_screen_test.dart`
  passed, 0 changed.
- `flutter test test/features/pico_placa/presentation/pico_detail_screen_test.dart`
  passed, 77 tests.
- `flutter analyze` passed, no issues found.
- `flutter build apk --release --flavor dev` passed.

## Physical Install And Screenshot

- Installed APK on Mi A3 with `adb install -r`: success.
- After screenshot:
  `temp/PICO_PERSONAL_CITY_CHIP_AUDIT_20260911/after-install-mi-pico-deeplink.png`
- The city chip renders in the top-right of the hero and no longer sits on the
  vehicle body.
