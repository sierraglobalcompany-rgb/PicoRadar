import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/design_system/branding.dart';
import 'package:picoradar/core/design_system/navigation.dart';
import 'package:picoradar/features/comparendos/data/territorial_catalog.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';

import '../../../plate_test_fonts.dart';
import 'comparendos_test_fixture.dart';

void main() {
  setUpAll(loadPlateTestFonts);

  for (final type in ['motorcycle', 'taxi']) {
    for (final size in const [Size(360, 780), Size(430, 932)]) {
      for (final scale in [1.0, 2.0]) {
        final name =
            '$type-${size.width.toInt()}x${size.height.toInt()}-$scale';
        testWidgets('actual vehicle bitmap plate and geometry $name', (
          tester,
        ) async {
          final motorcycle = type == 'motorcycle';
          final vehicle = comparendosVehicle(
            kind: motorcycle ? VehicleKind.motorcycle : VehicleKind.car,
            serviceType: motorcycle
                ? VehicleServiceType.private
                : VehicleServiceType.taxi,
            plate: motorcycle ? 'ABC12D' : 'ABC123',
            nickname: motorcycle ? 'Mi moto' : 'Mi taxi',
          );
          final preferences = ComparendosPreferences();
          preferences.values[picoJurisdictionPreferenceKey] = 'co-ant-medellin';
          final container = await pumpComparendos(
            tester,
            preferences: preferences,
            vehicles: [vehicle],
            active: vehicle,
            size: size,
            textScale: scale,
            bottomNavigation: true,
          );
          await tester.pumpAndSettle();
          final image = find.descendant(
            of: comparendosKey('vehicle-art'),
            matching: find.byType(Image),
          );
          expect(image, findsOneWidget);
          final imageWidget = tester.widget<Image>(image);
          final provider = imageWidget.image;
          final asset =
              (provider is ResizeImage ? provider.imageProvider : provider)
                  as AssetImage;
          final visual = container
              .read(vehicleVisualCatalogProvider)
              .requireValue
              .items
              .singleWhere((entry) => entry.asset == asset.assetName);
          expect(visual.kind, vehicle.kind.value);
          expect(visual.serviceType, vehicle.serviceType.value);
          await tester.runAsync(
            () => precacheImage(provider, tester.element(image)),
          );
          await tester.pumpAndSettle();
          final bitmap = tester
              .renderObject<RenderImage>(
                find.descendant(of: image, matching: find.byType(RawImage)),
              )
              .image;
          expect(bitmap, isNotNull);
          expect(bitmap!.width, greaterThan(1));
          expect(bitmap.height, greaterThan(1));
          final badge = tester.widget<ColombianPlateBadge>(
            find.byType(ColombianPlateBadge),
          );
          expect(badge.plate, vehicle.plate);
          expect(badge.publicService, !motorcycle);
          if (motorcycle) expect(badge.registrationLabel, 'COLOMBIA');
          expect(find.text('Matrícula: Medellín'), findsOneWidget);
          expect(find.text('Moto'), findsNothing);
          expect(find.text('Taxi'), findsNothing);
          final plateRect = tester.getRect(comparendosKey('plate'));
          final copyRect = tester.getRect(comparendosKey('copy-plate'));
          expect(plateRect.overlaps(copyRect), isFalse);
          expect(copyRect.width, greaterThanOrEqualTo(44));
          expect(copyRect.height, greaterThanOrEqualTo(44));
          expect(plateRect.left, greaterThanOrEqualTo(0));
          expect(copyRect.right, lessThanOrEqualTo(size.width));
          _expectTextFits(tester, size);
          expect(tester.takeException(), isNull);
          await captureComparendos(tester, name);
          final navRect = tester.getRect(find.byType(AppBottomNav));
          await tapComparendos(tester, 'mark-checked');
          expect(
            preferences.values['comparendos.last_checked.${vehicle.id}'],
            '2026-09-03',
          );
          expect(tester.getRect(find.byType(AppBottomNav)), navRect);
        });
      }
    }
  }

  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}-$scale';
      testWidgets(
        'geometry and working selectors with fixed navigation $name',
        (tester) async {
          final preferences = ComparendosPreferences();
          preferences.values[picoJurisdictionPreferenceKey] = 'co-ant-medellin';
          final first = comparendosVehicle(
            nickname: 'Mi vehículo familiar para viajar',
          );
          final second = comparendosVehicle(
            id: 'vehicle-b',
            plate: 'XYZ789',
            nickname: 'Vehículo de trabajo',
          );
          final launcher = ComparendosLauncher();
          await pumpComparendos(
            tester,
            preferences: preferences,
            vehicles: [first, second],
            active: first,
            size: size,
            textScale: scale,
            bottomNavigation: true,
            launcher: launcher,
          );
          await tester.pumpAndSettle();
          final nav = find.byType(AppBottomNav);
          final navRect = tester.getRect(nav);
          expect(
            tester.getRect(comparendosKey('screen')).bottom,
            lessThanOrEqualTo(navRect.top),
          );
          expect(navRect.bottom, lessThanOrEqualTo(size.height));
          expect(navRect.width, size.width);
          for (final label in [
            'Inicio',
            'Garaje',
            'Apps',
            'Viaje',
            'Conducir',
          ]) {
            expect(
              find.descendant(of: nav, matching: find.text(label)),
              findsOneWidget,
            );
          }
          expect(
            tester
                .getCenter(
                  find.descendant(of: nav, matching: find.text('Apps')),
                )
                .dx,
            closeTo(size.width / 2, 1),
          );
          expect(find.text('Matrícula: Medellín'), findsOneWidget);
          expect(find.text('Carro'), findsNothing);
          expect(findPlateNumber(first.plate), findsOneWidget);

          final image = find.descendant(
            of: comparendosKey('vehicle-art'),
            matching: find.byType(Image),
          );
          expect(
            image,
            findsOneWidget,
            reason: 'The real vehicle asset must resolve',
          );
          final imageWidget = tester.widget<Image>(image);
          await tester.runAsync(
            () => precacheImage(imageWidget.image, tester.element(image)),
          );
          await tester.pumpAndSettle();
          final rendered = tester.renderObject<RenderImage>(
            find.descendant(of: image, matching: find.byType(RawImage)),
          );
          expect(
            rendered.image,
            isNotNull,
            reason: 'The vehicle bitmap must decode',
          );
          expect(rendered.image!.width, greaterThan(1));
          expect(rendered.image!.height, greaterThan(1));
          _expectTextFits(tester, size);
          expect(tester.takeException(), isNull);
          await captureComparendos(tester, 'screen-$name');

          for (final key in [
            'change-vehicle',
            'copy-plate',
            'open-simit',
            'change-city',
            'open-territorial',
            'mark-checked',
          ]) {
            final control = comparendosKey(key);
            expect(control, findsOneWidget);
            await tester.ensureVisible(control);
            await tester.pumpAndSettle();
            final rect = tester.getRect(control);
            expect(rect.width, greaterThanOrEqualTo(44), reason: key);
            expect(rect.height, greaterThanOrEqualTo(44), reason: key);
            expect(rect.left, greaterThanOrEqualTo(0), reason: key);
            expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
            expect(
              rect.bottom,
              lessThanOrEqualTo(navRect.top + .1),
              reason: key,
            );
            expect(control.hitTestable(), findsOneWidget, reason: key);
            expect(
              tester.getRect(nav),
              navRect,
              reason: 'Navigation moves after scrolling $key',
            );
          }
          await tapComparendos(tester, 'mark-checked');
          expect(
            preferences.values['comparendos.last_checked.${first.id}'],
            '2026-09-03',
          );
          await tester.ensureVisible(comparendosKey('local-note'));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(comparendosKey('local-note')).bottom,
            lessThanOrEqualTo(navRect.top),
          );
          await captureComparendos(tester, 'checked-$name');

          await tapComparendos(tester, 'change-vehicle');
          _expectTextFits(tester, size);
          expect(
            comparendosKey('choose-${second.id}').hitTestable(),
            findsOneWidget,
          );
          await captureComparendos(tester, 'vehicle-sheet-$name');
          await tapComparendos(tester, 'choose-${second.id}');
          expect(findPlateNumber(second.plate), findsOneWidget);
          expect(comparendosKey('last-checked'), findsNothing);

          await tapComparendos(tester, 'change-city');
          expect(comparendosKey('city-search').hitTestable(), findsOneWidget);
          await tester.enterText(comparendosKey('city-search'), 'bogota');
          await tester.pumpAndSettle();
          expect(comparendosKey('city-11001'), findsOneWidget);
          await captureComparendos(tester, 'city-sheet-$name');
          _expectTextFits(tester, size);
          await tapComparendos(tester, 'city-11001');
          await tapComparendos(tester, 'open-territorial');
          expect(launcher.opened, [testBogotaUrl]);
          expect(
            preferences.values[picoJurisdictionPreferenceKey],
            'co-ant-medellin',
          );
          expect(tester.getRect(nav), navRect);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets(
      'city search stays usable above the keyboard at 360x780 scale $scale',
      (tester) async {
        final vehicle = comparendosVehicle();
        await pumpComparendos(
          tester,
          preferences: ComparendosPreferences(),
          vehicles: [vehicle],
          active: vehicle,
          size: const Size(360, 780),
          textScale: scale,
          bottomNavigation: true,
        );
        await tapComparendos(tester, 'change-city');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(comparendosKey('city-search'), 'bogota');
        await tester.pumpAndSettle();
        final field = tester.getRect(comparendosKey('city-search'));
        expect(field.bottom, lessThanOrEqualTo(520));
        await captureComparendos(tester, 'city-keyboard-360x780-$scale');
        await tester.scrollUntilVisible(
          comparendosKey('city-11001'),
          80,
          scrollable: find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Scrollable),
              )
              .last,
          maxScrolls: 10,
        );
        await tester.pumpAndSettle();
        expect(comparendosKey('city-11001').hitTestable(), findsOneWidget);
        expect(
          tester.getRect(comparendosKey('city-11001')).bottom,
          lessThanOrEqualTo(520),
        );
        expect(tester.takeException(), isNull);
        await captureComparendos(tester, 'city-keyboard-360x780-$scale');
        await tester.tap(comparendosKey('city-11001'));
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(comparendosKey('consultation-city')).data,
          'Bogotá',
        );
      },
    );
  }

  for (final authority in [
    pendingComparendosAuthority,
    regionalComparendosAuthority,
  ]) {
    testWidgets(
      'authority details remain readable at 360x780 scale2 ${authority.id}',
      (tester) async {
        final vehicle = comparendosVehicle();
        await pumpComparendos(
          tester,
          preferences: ComparendosPreferences(),
          vehicles: [vehicle],
          active: vehicle,
          size: const Size(360, 780),
          textScale: 2,
          bottomNavigation: true,
          directoryLoader: () async =>
              TerritorialCatalog(authorities: [authority]),
        );
        await tapComparendos(tester, 'change-city');
        await tester.enterText(comparendosKey('city-search'), authority.name);
        await tester.pumpAndSettle();
        await captureComparendos(
          tester,
          'authority-search-${authority.id}-360x780-2',
        );
        _expectTextFits(tester, const Size(360, 780));
        await tapComparendos(tester, 'authority-${authority.id}');
        await tapComparendos(tester, 'authority-info');
        final sheet = find.byType(BottomSheet);
        _expectTextFits(tester, const Size(360, 780));
        expect(tester.getRect(sheet).bottom, lessThanOrEqualTo(780));
        expect(tester.takeException(), isNull);
        await captureComparendos(
          tester,
          'authority-info-${authority.id}-360x780-2',
        );
        final lastText = find
            .descendant(of: sheet, matching: find.byType(Text))
            .last;
        await tester.ensureVisible(lastText);
        await tester.pumpAndSettle();
        expect(tester.getRect(lastText).bottom, lessThanOrEqualTo(780));
        await captureComparendos(
          tester,
          'authority-info-bottom-${authority.id}-360x780-2',
        );
        Navigator.of(tester.element(sheet)).pop();
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(comparendosKey('consultation-city')).data,
          'Autoridad seleccionada',
        );
      },
    );
  }
}

void _expectTextFits(WidgetTester tester, Size viewport) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: paragraph.text.toPlainText(),
    );
    final origin = paragraph.localToGlobal(Offset.zero);
    expect(
      origin.dx,
      greaterThanOrEqualTo(-.1),
      reason: paragraph.text.toPlainText(),
    );
    expect(
      paragraph.localToGlobal(Offset(paragraph.size.width, 0)).dx,
      lessThanOrEqualTo(viewport.width + .1),
      reason: paragraph.text.toPlainText(),
    );
  }
}
