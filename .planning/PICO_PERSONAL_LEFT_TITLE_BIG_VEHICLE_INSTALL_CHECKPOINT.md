# Checkpoint: Mi Pico y Placa left title and larger vehicle

Date: 2026-09-11
Branch: codex/garage-single-favorite

## Context

User approved the city chip placement but requested:

- Smaller visible back button circle.
- Vehicle nickname/make/`Mi vehículo` placed on the left under the back button.
- Larger vehicle art.

## Changes Made

- Kept the city chip at the approved top-right position.
- Changed the hero title to left alignment under the back button.
- Kept the back button touch target at 48x48 dp while reducing the visible
  circle to 40x40 dp.
- Increased normal vehicle art scale and hero height so the vehicle regains
  prominence without touching the title.
- Second pass increased the normal vehicle scale further, targeting the user's
  requested roughly 30% larger visual vehicle.
- Physical screenshot showed that pass was invalid: the vehicle roof was cut
  because the scaled image was clipped by its local art slot.
- Third pass changed the growth to a safer 25% style treatment: slightly taller
  hero, controlled scale, and no local art-slot clipping, so the hero rounded
  frame is the only visual boundary.
- Preserved the micro plate, summary, calendar and restriction logic.
- Updated geometry tests for left-aligned title, title/art gap, and existing
  city chip placement.

## Verification Before Install

- `flutter test test/features/pico_placa/presentation/pico_detail_screen_test.dart`
  passed, 77 tests.
- `dart format --output=none --set-exit-if-changed ...` passed, 0 changed.
- `flutter analyze` passed, no issues found.
- `flutter build apk --release --flavor dev` passed.

## APK

- Path:
  `temp/PICO_PERSONAL_LEFT_TITLE_BIG_VEHICLE_20260911/picoradar-mi-pico-vehicle-safe-25-dev-release.apk`
- SHA256:
  `BB440AC3900E9E7B631EF5D7CA271745102944BE04C82F31D6B4A7DAC930E12A`

## Next Step

Install on Mi A3, open Mi Pico y Placa, and capture the updated hero for visual
approval. Do not use the preloader screenshot as evidence.

## Physical Install And Screenshot

- Installed on Mi A3 with `adb install -r`: success.
- Opened deep link:
  `picoradar:///home/pico?vehicleId=visual-check`
- Valid screenshot after load:
  `temp/PICO_PERSONAL_LEFT_TITLE_BIG_VEHICLE_20260911/after-install-vehicle-safe-25.png`
- Visual result checked: vehicle is larger and complete; roof is not clipped;
  title, city chip and plate keep their approved hierarchy.

## 2026-09-12 Physical Result

- Built and installed:
  `temp/PICO_PERSONAL_LEFT_TITLE_BIG_VEHICLE_20260911/picoradar-mi-pico-hero-up-compact-dev-release.apk`
- SHA256:
  `38BB37ED71798716BB73F2C4314AB309B1E531EB8EC56F5F5FF5B96C8B5352A9`
- Physical screenshot:
  `temp/PICO_PERSONAL_LEFT_TITLE_BIG_VEHICLE_20260911/after-install-hero-up-compact.png`
- Visual result checked: hero is shorter, vehicle moved upward, vehicle remains
  complete, and the plate/summary spacing stays usable.

## 2026-09-12 Motorcycle Framing Fix

- Before screenshot:
  `temp/PICO_PERSONAL_LEFT_TITLE_BIG_VEHICLE_20260911/current-moto-cut.png`
- Change: motorcycles now receive an exclusive hero transform:
  scale `1.52` / translateY `-14 dp` with normal text, and scale `1.22` /
  translateY `-10 dp` with enlarged text.
- Cars keep their approved transform: scale `1.55`, translateY `0`.
- Built and installed:
  `temp/PICO_PERSONAL_LEFT_TITLE_BIG_VEHICLE_20260911/picoradar-mi-pico-moto-frame-dev-release.apk`
- SHA256:
  `2E6D916D5813E0C97F213D4C9C0DBE36D9DF07CED61EE246EB1AE1EAB2ACE226`
- Physical screenshot:
  `temp/PICO_PERSONAL_LEFT_TITLE_BIG_VEHICLE_20260911/after-install-moto-frame-actual.png`
- Visual result checked: motorcycle wheels are visible, the bike sits higher,
  and car geometry remains covered by tests.

## 2026-09-12 Hero Height Tuning

- User requested moving the vehicle up and reducing the hero vertical weight.
- Adjusted normal hero frame from 198 dp to 190 dp and vehicle slot top from 100 dp to 94 dp.
- Adjusted accessibility hero proportionally from 214 dp to 206 dp and slot top from 122 dp to 116 dp.
- Kept vehicle scale controlled at 1.55 normal / 1.24 enlarged text, preserving the no-cut treatment.
- Focal tests passed before build.
