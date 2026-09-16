# Servicios GPS Mockup Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair Apps -> Mas -> Servicios so the screen matches the approved mockup more closely, uses real one-shot GPS for nearby Google Maps searches, and never shows a vehicle registration city as if it were the current location.

**Architecture:** Keep `ServicesScreen` as the coordinator and preserve the existing launch-to-Google-Maps contract. Split only private presentation helpers inside the Services feature if the file becomes too large; no backend, no provider directory, no persistent GPS history, and no global city writes.

**Tech Stack:** Flutter, Riverpod, existing `DeviceLocationGateway`, existing `ExternalLauncher`, existing app shell and bottom navigation, existing Google Maps URL helpers.

**Spec:** User-provided Servicios mockup and follow-up corrections on 2026-09-15: GPS module top right, no redundant visible "Servicios" title, faithful composition, avatar higher, no text collision, no fake Bogota location while the user is in Medellin.

## Global Constraints

- The module is **Apps -> Mas -> Servicios** only.
- Do not modify CDA, Conducir, Garage, global city, favorites, or vehicle data contracts.
- Do not store GPS location, history, or inferred city in preferences.
- Do not start continuous GPS tracking.
- Do not open Google Maps until the user taps a service action.
- Use GPS first for Grua, Bateria, Llantas, and Taller mecanico.
- City fallback is explicit only after GPS failure or denial.
- Bottom navigation remains exact: Inicio, Garaje, Apps, Viaje, Conducir.
- No new runtime dependency.
- Text must remain scalable; no `FittedBox` or hidden essential copy.
- Normal text target: one visible portada without vertical scroll on Mi A3.
- Accessibility target: one vertical scroll is allowed only when text scale makes it necessary.

---

## Audit Summary

**Evidence captured:** `C:/Users/felip/AppData/Local/Temp/services-audit-current.png`

**Current observed defects:**
- The top-right location pill displays `Bogota - Bogota D.C.` while the user is in Medellin. This is a state truth bug, not just a visual bug.
- The implementation is still farther from the mockup than acceptable: no location card rhythm, the hero art does not match the visual balance, and the lower CDA/disclaimer area is partly hidden by the bottom navigation.
- The current `ListView` lets the page exceed the desired one-screen composition at normal text.
- Secondary cards compete with their arrow buttons; the third card is especially fragile with "Buscar taller mecanico".
- The code has started to introduce `_LocationPillState`, but the installed build and tests still allow registration-city behavior to leak into the visible GPS state.

**Graphify finding:** the Services module is centered on `services_screen.dart`, `google_maps_service_search.dart`, `DeviceLocationGateway`, `ExternalLauncher`, `activeVehicleProvider`, and CDA navigation. Changes should stay in that boundary.

---

## File Structure

- Modify: `mobile/lib/features/services/presentation/services_screen.dart`
  - Owns the Servicios portada, GPS state, fallback sheets, and service taps.
  - Must not use vehicle registration city for the visible top-right GPS pill.
  - Should use a measured layout rather than a simple long `ListView` for normal text.
- Modify: `mobile/lib/features/services/data/google_maps_service_search.dart`
  - Keep helpers for category + coordinate and category + city fallback.
  - No personal data in URLs.
- Modify: `mobile/test/features/services/presentation/services_screen_test.dart`
  - Add tests proving Medellin GPS overrides Bogota vehicle registration.
  - Add layout and fallback tests.
- Modify: `mobile/test/features/services/data/google_maps_service_search_test.dart`
  - Keep URL encoding and coordinate formatting coverage.
- Optional create: `mobile/lib/features/services/presentation/services_layout.dart`
  - Only if `services_screen.dart` remains too large after cleanup.
  - Private layout helpers only; no public API.

---

## Task 1: GPS Truth and State Separation

**Files:**
- Modify: `mobile/lib/features/services/presentation/services_screen.dart`
- Test: `mobile/test/features/services/presentation/services_screen_test.dart`

**Interfaces:**
- Consumes: `DeviceLocationGateway`, `DeviceLocationPoint`, `DeviceLocationFailure`.
- Produces: `_LocationPillState`, `_refreshLocationPill`, `_setLocationPillFromPoint`, `_cityLabelForPoint`.

- [ ] **Step 1: Write failing tests for city truth**

Add tests that prove:

```dart
testWidgets('GPS detected city overrides vehicle registration city', (tester) async {
  await _pumpServices(
    tester,
    activeVehicle: _vehicle(registrationCity: 'Bogota D. C.'),
    locationGateway: _FakeDeviceLocationGateway.success(
      const DeviceLocationPoint(
        latitude: 6.244203,
        longitude: -75.581212,
        accuracyMeters: 18,
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Medellin'), findsOneWidget);
  expect(find.textContaining('Bogota'), findsNothing);
});

testWidgets('location pill does not show vehicle city before GPS permission', (tester) async {
  await _pumpServices(
    tester,
    activeVehicle: _vehicle(registrationCity: 'Bogota D. C.'),
    locationGateway: _FakeDeviceLocationGateway(
      checkPermissionResult: DeviceLocationPermission.notRequested,
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Usar GPS'), findsOneWidget);
  expect(find.textContaining('Bogota'), findsNothing);
});
```

- [ ] **Step 2: Run tests and confirm failure**

Run:

```powershell
cd mobile
flutter test test/features/services/presentation/services_screen_test.dart --no-pub --reporter compact
```

Expected: the new city-truth tests fail until the GPS pill ignores registration city.

- [ ] **Step 3: Implement GPS-only pill state**

Rules:
- On first render, call `_refreshLocationPill(requestPermission: false)`.
- If permission is already granted, read one position and show a detected city.
- If permission is not granted, show `Usar GPS`.
- If GPS service is off, show `GPS apagado`.
- On tap, call `_refreshLocationPill(requestPermission: true)`.
- Never use `activeVehicle.registrationCity` in `_TopChrome` or `_LocationPillState`.
- Use registration city only as initial text inside the fallback city sheet after GPS fails.

City resolver:

```dart
const _serviceLocationLabels = <String, String>{
  'co-dc-bogota': 'Bogota',
  'co-ant-medellin': 'Medellin',
  'co-vac-cali': 'Cali',
  'co-bol-cartagena': 'Cartagena',
  'co-san-bucaramanga': 'Bucaramanga',
  'co-atl-barranquilla': 'Barranquilla',
  'co-cal-manizales': 'Manizales',
  'co-cau-popayan': 'Popayan',
  'co-met-villavicencio': 'Villavicencio',
};
```

Pick the nearest `jurisdictionLocationHints` match inside its radius. If none matches, show `GPS activo`, not a guessed city.

- [ ] **Step 4: Make service taps update the GPS pill**

After a service search gets `_ResolvedLocation(point)`, call `_setLocationPillFromPoint(point)` before opening Google Maps. After a failure, call `_setLocationPillFailure(failure)`.

- [ ] **Step 5: Verify tests pass**

Run:

```powershell
cd mobile
flutter test test/features/services/presentation/services_screen_test.dart --no-pub --reporter compact
```

Expected: all Services widget tests pass. Update request counts where initial non-prompt GPS refresh intentionally reads location.

---

## Task 2: Mockup-Faithful One-Screen Layout

**Files:**
- Modify: `mobile/lib/features/services/presentation/services_screen.dart`
- Test: `mobile/test/features/services/presentation/services_screen_test.dart`

**Interfaces:**
- Consumes: existing service actions and launch handlers.
- Produces: layout contract for normal and accessibility text.

- [ ] **Step 1: Add layout tests**

Create assertions for 360 x 780 and text scale 1.0:

```dart
testWidgets('normal Mi A3 viewport shows the full portada without scrolling', (tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 780);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await _pumpServices(tester, activeVehicle: _vehicle(registrationCity: 'Bogota'));
  await tester.pumpAndSettle();

  expect(find.text('Servicios para\ntu vehiculo'), findsOneWidget);
  expect(find.text('Buscar grua 24 horas'), findsOneWidget);
  expect(find.text('CDA en PicoRadar'), findsOneWidget);
  expect(find.textContaining('PicoRadar no presta'), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

Use exact strings from the codebase with the existing accent convention.

- [ ] **Step 2: Replace long-list normal layout with measured layout**

Use `LayoutBuilder` and `MediaQuery`:
- Normal scale `< 1.3`: build a fixed-height vertical composition that fits the shell height.
- Scale `>= 1.3`: allow a single `ListView`.
- Do not subtract bottom navigation manually if the shell already gives the available area.

Height budget on Mi A3 normal:
- Top chrome: 48 dp.
- Hero: 136-148 dp.
- Primary grua card: 104-112 dp.
- Other section heading: 32 dp including spacing.
- Secondary cards: 154-166 dp.
- CDA card: 88-96 dp.
- Disclaimer: 76-88 dp.
- Spacing total: keep under 64 dp.

- [ ] **Step 3: Remove redundant visible title**

Keep only:
- back arrow at top left;
- GPS pill top right;
- hero title `Servicios para tu vehiculo`.

Do not show a separate header text `Servicios`.

- [ ] **Step 4: Keep GPS module top-right**

The top-right GPS pill should have:
- icon `gps_fixed`;
- city or state label;
- max width that prevents pushing the back arrow;
- 48 dp hit target;
- no multiline text.

- [ ] **Step 5: Validate no hidden bottom content**

The CDA card and yellow disclaimer must be fully visible above the bottom navigation at normal text. If one element must compact, compact the disclaimer first, then the CDA subtitle, never the GPS truth state.

---

## Task 3: Hero and Avatar Alignment

**Files:**
- Modify: `mobile/lib/features/services/presentation/services_screen.dart`
- Test: visual/widget smoke coverage in `mobile/test/features/services/presentation/services_screen_test.dart`

**Interfaces:**
- Consumes: local vehicle image asset.
- Produces: `_ServicesHero` matching the mockup hierarchy.

- [ ] **Step 1: Move vehicle avatar higher**

Target:
- vehicle art begins near the top third of the hero, not bottom-aligned;
- no collision with the subtitle;
- the art reads as secondary to the title, not floating below it.

Implementation:
- For 360 width, use right-side art width around 150-165 dp.
- Place at `top: 8-16` inside hero stack.
- Keep the subtitle width no more than 58-62% of the available row.

- [ ] **Step 2: Restore mockup balance**

The mockup has:
- large left title;
- short subtitle;
- right illustration;
- generous white space, but not dead space.

Avoid:
- title colliding with car;
- city blocks heavier than the vehicle;
- car placed below the subtitle baseline.

- [ ] **Step 3: Capture and compare**

After implementation, capture:

```powershell
adb exec-out screencap -p > "$env:TEMP\services-hero-after.png"
```

Compare against:

`C:/Users/felip/AppData/Local/Temp/codex-clipboard-cd4757c3-7b07-48be-9555-f9afc174d627.png`

Acceptance: car is visibly higher and the text no longer competes with the avatar.

---

## Task 4: Service Cards and Action Density

**Files:**
- Modify: `mobile/lib/features/services/presentation/services_screen.dart`
- Test: `mobile/test/features/services/presentation/services_screen_test.dart`

**Interfaces:**
- Consumes: `_ServiceSearchAction`.
- Produces: primary and compact cards with stable tap targets.

- [ ] **Step 1: Primary grua card**

Target:
- The grua card should be important but not oversized.
- Text block left, illustration right.
- Height 104-116 dp normal.
- CTA text remains visible.
- Card icon can be vector/icon, but should not dominate the text.

- [ ] **Step 2: Secondary cards**

Target:
- Three equal-width cards.
- Icon circle near top.
- Title below.
- Caption below title.
- Arrow button bottom-right with 48 dp target.
- Text must not run under the arrow.

For the third card:
- Prefer title layout `Buscar taller` + `mecanico` on two or three lines.
- Caption should be `Google Maps` only if vertical space is tight.

- [ ] **Step 3: Loading state**

When tapping a service:
- only that card shows loading;
- other cards remain tappable-looking but ignored while operation is active;
- loading text must not change card height enough to jump the whole screen.

---

## Task 5: GPS Failure, Fallback, and Google Maps Launch

**Files:**
- Modify: `mobile/lib/features/services/presentation/services_screen.dart`
- Modify: `mobile/lib/features/services/data/google_maps_service_search.dart`
- Test: services data and widget tests.

**Interfaces:**
- Consumes: existing launch APIs.
- Produces: correct URLs and recovery UI.

- [ ] **Step 1: Keep coordinate searches exact**

Coordinate query format:

```text
grua 24 horas cerca de 6.244203,-75.581212
bateria cerca de 6.244203,-75.581212
llantas cerca de 6.244203,-75.581212
taller mecanico cerca de 6.244203,-75.581212
```

Use current accented copy if already established in `google_maps_service_search.dart`; tests should match the actual encoded query.

- [ ] **Step 2: Failure sheet**

For GPS failures:
- service disabled: title `Activa la ubicacion`;
- denied: title `Permiso de ubicacion`;
- denied forever: offer app settings;
- unavailable: offer retry and city fallback.

All failures offer:
- `Reintentar`;
- `Elegir ciudad`;
- settings action only where applicable.

- [ ] **Step 3: City fallback stays temporary**

Fallback city can use vehicle registration city as initial text, but:
- it is inside the sheet only;
- it is visibly editable;
- it never appears as detected location;
- it never writes global city, favorites, or vehicle.

---

## Task 6: Verification and Physical QA

**Files:**
- Modify tests as needed.
- Do not modify unrelated feature files.

- [ ] **Step 1: Format touched Services files**

Run:

```powershell
cd mobile
dart format lib/features/services/data/google_maps_service_search.dart lib/features/services/presentation/services_screen.dart test/features/services/data/google_maps_service_search_test.dart test/features/services/presentation/services_screen_test.dart
```

- [ ] **Step 2: Run focused Services tests**

Run:

```powershell
cd mobile
flutter test test/features/services --no-pub --reporter compact
```

- [ ] **Step 3: Run analyzer**

Run:

```powershell
cd mobile
flutter analyze --no-pub
```

- [ ] **Step 4: Build and install dev release**

Run:

```powershell
cd mobile
flutter build apk --release --flavor dev --dart-define=APP_ENV=dev --no-pub
adb install -r build/app/outputs/flutter-apk/app-dev-release.apk
```

- [ ] **Step 5: Physical verification in Medellin**

On the Mi A3:
- Open Apps -> Mas -> Servicios.
- If permissions are not granted, tap GPS pill and grant permission.
- Confirm pill shows `Medellin` or `GPS activo`, never `Bogota - Bogota D.C.`.
- Tap Grua, Bateria, Llantas, Taller.
- Confirm Google Maps opens with nearby coordinate search.
- Return to PicoRadar after each search.

- [ ] **Step 6: Capture evidence**

Capture:

```powershell
adb exec-out screencap -p > "$env:TEMP\services-final-medellin.png"
```

Capture at least:
- initial portada with GPS state;
- one loading/tapped state if possible;
- GPS failure/fallback only if permission is intentionally denied for testing.

---

## Self-Review

**Spec coverage:** Covers GPS-first behavior, top-right GPS module, no fake Bogota, no redundant title, mockup hierarchy, smaller grua card, non-colliding secondary cards, raised avatar, CDA access, fallback, tests, build, and physical QA.

**Known limits:** This plan does not create a provider directory inside PicoRadar; the module still delegates providers to Google Maps as requested. It does not change CDA internals.

**Stop condition:** If the physical device reports Bogota coordinates from Android itself, do not patch around it by guessing Medellin. Inspect Android location settings/mock-location state and report the OS-level source before claiming the app is fixed.
