# Checkpoint: Mi Pico y Placa title/vehicle gap

Date: 2026-09-11
Branch: codex/garage-single-favorite

## Context

The city chip placement was accepted, but the vehicle title/name was too close
to the vehicle art. On motorcycle assets the handlebars could touch the text.

## Current Evidence

- Before screenshot:
  `temp/PICO_PERSONAL_CITY_CHIP_AUDIT_20260911/current-title-vehicle-gap.png`
- APK built before installation:
  `temp/PICO_PERSONAL_TITLE_GAP_20260911/picoradar-mi-pico-title-gap-dev-release.apk`
- APK SHA256:
  `EC7FD679B70C51834EC45D81E7547279DBBAC0A83645FAD7BB287DFDE736E2A7`

## Changes Made

- Added a clipped vehicle art slot with key
  `pico-personal-vehicle-art-slot`.
- Moved the vehicle art slot below the title band.
- Reduced the hero vehicle transform scale slightly, especially with enlarged
  system text, so tall assets cannot paint over the title.
- Kept the city chip, back button, plate, summary and calendar unchanged.
- Added geometry assertions for the title-to-vehicle gap.

## Verification Before Install

- `flutter test test/features/pico_placa/presentation/pico_detail_screen_test.dart`
  passed, 77 tests.
- `dart format --output=none --set-exit-if-changed ...` passed, 0 changed.
- `flutter analyze` passed, no issues found.
- `flutter build apk --release --flavor dev` passed.

## Next Step

Install on Mi A3, capture Mi Pico y Placa with motorcycle/car if available, and
compare against the before screenshot.

## Physical Install And Screenshot

- Installed APK on Mi A3 with `adb install -r`: success.
- After screenshot:
  `temp/PICO_PERSONAL_TITLE_GAP_20260911/after-install-title-gap.png`
- The visible car hero now has a clear gap between `Mi vehículo` and the
  vehicle art while keeping the city chip in the approved top-right position.
- Motorcycle-specific physical capture was not forced because the release dev
  APK is not debuggable, so local vehicle ids could not be read with `run-as`.
  The test suite covers the title-to-art slot gap generically for vehicle art
  and enlarged text.
