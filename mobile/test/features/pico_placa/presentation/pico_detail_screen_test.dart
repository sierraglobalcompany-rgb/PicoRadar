import '../../../plate_test_fonts.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';

import '../../../test_app_harness.dart';

void main() {
  setUpAll(loadPlateTestFonts);
  late TestAppHarness harness;

  setUp(() async {
    harness = TestAppHarness();
    await harness.preferences.setString(
      picoJurisdictionPreferenceKey,
      'co-ant-medellin',
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('personal monthly mockup is the default vehicle view', (
    tester,
  ) async {
    final vehicle = await harness.repository.createVehicle(
      plate: 'ABC125',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: 'Medellín',
    );
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      vehicle: vehicle,
      now: DateTime(2026, 8, 31, 4, 59),
      viewportSize: const Size(360, 780),
    );
    expect(find.text('Mi pico y placa'), findsNothing);
    expect(find.byKey(const ValueKey('pico-personal-header')), findsNothing);
    expect(
      find.byKey(const ValueKey('pico-personal-hero-city')),
      findsOneWidget,
    );
    final hero = tester.getRect(
      find.byKey(const ValueKey('pico-personal-hero-city')),
    );
    final back = tester.getRect(
      find.byKey(const ValueKey('pico-personal-hero-back')),
    );
    expect(back.left, greaterThanOrEqualTo(hero.left));
    expect(back.top, greaterThanOrEqualTo(hero.top));
    expect(back.size.width, greaterThanOrEqualTo(48));
    expect(back.size.height, greaterThanOrEqualTo(48));
    expect(
      find.byKey(const ValueKey('pico-personal-change-city')),
      findsOneWidget,
    );
    final citySelector = tester.getRect(
      find.byKey(const ValueKey('pico-personal-change-city')),
    );
    final plate = tester.getRect(
      find.byKey(const ValueKey('colombian-plate-badge')),
    );
    final vehicleName = tester.getRect(
      find.byKey(const ValueKey('pico-personal-vehicle-name')),
    );
    final vehicleArtSlot = tester.getRect(
      find.byKey(const ValueKey('pico-personal-vehicle-art-slot')),
    );
    expect(citySelector.top, greaterThanOrEqualTo(hero.top + 8));
    expect(citySelector.top, lessThanOrEqualTo(hero.top + 16));
    expect(citySelector.center.dx, greaterThan(hero.center.dx));
    expect(citySelector.right, lessThanOrEqualTo(hero.right - 8));
    expect(citySelector.overlaps(vehicleName), isFalse);
    expect(vehicleArtSlot.top, greaterThanOrEqualTo(vehicleName.bottom + 10));
    expect(citySelector.bottom, lessThan(plate.top - 40));
    expect(find.text('Cambiar ciudad'), findsNothing);
    expect(find.text('Medellín'), findsWidgets);
    expect(findPlateNumber(vehicle.plate), findsOneWidget);
    expect(find.text('Tiene pico y placa hoy'), findsOneWidget);
    expect(find.text('Empieza en 1 min'), findsOneWidget);
    expect(find.text('Hoy · Lun 31/08/2026'), findsNothing);
    expect(find.text('Aplica por el último dígito: 5'), findsNothing);
    expect(find.text('Estado inmediato'), findsNothing);
    expect(find.text('Próximos días'), findsNothing);
    expect(find.text('Mes'), findsNothing);
    final summary = find.byKey(const ValueKey('pico-summary-today'));
    expect(summary, findsOneWidget);
    expect(tester.getSize(summary).height, lessThanOrEqualTo(112));
    expect(tester.getRect(summary).top - plate.bottom, greaterThanOrEqualTo(8));
    final calendar = find.byKey(const ValueKey('pico-personal-month-calendar'));
    expect(calendar, findsOneWidget);
    expect(
      tester.getBottomRight(calendar).dy,
      greaterThan(tester.getTopLeft(summary).dy),
    );
    for (final weekday in const [
      'Lun',
      'Mar',
      'Mié',
      'Jue',
      'Vie',
      'Sáb',
      'Dom',
    ]) {
      expect(find.text(weekday), findsOneWidget);
    }
    expect(
      tester
          .getSize(find.byKey(const ValueKey('pico-month-day-2026-08-31')))
          .width,
      greaterThanOrEqualTo(44),
    );
    final monthDaySize = tester.getSize(
      find.byKey(const ValueKey('pico-month-day-2026-08-31')),
    );
    expect(monthDaySize.height, lessThanOrEqualTo(monthDaySize.width + 2));
    expect(monthDaySize.height, lessThanOrEqualTo(50));
    expect(
      find.byKey(
        const ValueKey('pico-month-status-icon-2026-08-31-restricted'),
      ),
      findsOneWidget,
    );
    final dayCell = find.byKey(const ValueKey('pico-month-day-2026-08-31'));
    final dayNumber = find.descendant(of: dayCell, matching: find.text('31'));
    final dayBadge = find.byKey(
      const ValueKey('pico-month-status-icon-2026-08-31-restricted'),
    );
    expect(tester.getSize(dayBadge).width, lessThanOrEqualTo(10));
    expect(tester.getSize(dayBadge).height, lessThanOrEqualTo(10));
    expect(
      tester.getRect(dayBadge).top,
      greaterThan(tester.getRect(dayNumber).bottom),
    );
    expect(find.text('Libre'), findsOneWidget);
    expect(find.text('Restricción'), findsOneWidget);
    expect(find.text('Por verificar'), findsOneWidget);
    final calendarRect = tester.getRect(
      find.byKey(const ValueKey('pico-personal-month-calendar')),
    );
    final legend = tester.getRect(
      find.byKey(const ValueKey('pico-calendar-legend')),
    );
    expect(legend.center.dx, closeTo(calendarRect.center.dx, 1));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-month-day-2026-08-31')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pico-month-day-2026-08-31')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pico-month-day-detail-sheet')),
      findsOneWidget,
    );
    expect(find.text('Aplica por el último dígito: 5'), findsOneWidget);
    await tester.tapAt(const Offset(16, 16));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-personal-source-row')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pico-personal-source-row')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pico-personal-source-sheet')),
      findsOneWidget,
    );
    expect(find.textContaining('Última verificación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal city chip handles long city names compactly', (
    tester,
  ) async {
    final vehicle = await harness.repository.createVehicle(
      plate: 'ABC125',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: 'Medellín',
    );
    const jurisdictions = [
      RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellín'),
      RestrictionJurisdiction(id: 'co-san-bucaramanga', name: 'Bucaramanga'),
      RestrictionJurisdiction(
        id: 'co-met-villavicencio',
        name: 'Villavicencio',
      ),
    ];

    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      vehicle: vehicle,
      transientJurisdictionId: 'co-san-bucaramanga',
      viewportSize: const Size(360, 780),
      jurisdictions: jurisdictions,
    );
    final bucCity = tester.getRect(
      find.byKey(const ValueKey('pico-personal-change-city')),
    );
    final bucHero = tester.getRect(
      find.byKey(const ValueKey('pico-personal-hero-city')),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pico-personal-change-city')),
        matching: find.text('Bucaramanga'),
      ),
      findsOneWidget,
    );
    expect(bucCity.width, lessThanOrEqualTo(136));
    expect(bucCity.center.dx, greaterThan(bucHero.center.dx));
    expect(tester.takeException(), isNull);

    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      vehicle: vehicle,
      transientJurisdictionId: 'co-met-villavicencio',
      viewportSize: const Size(360, 780),
      textScaleFactor: 2,
      jurisdictions: jurisdictions,
    );
    final longCity = tester.getRect(
      find.byKey(const ValueKey('pico-personal-change-city')),
    );
    final longHero = tester.getRect(
      find.byKey(const ValueKey('pico-personal-hero-city')),
    );
    expect(longCity.width, lessThanOrEqualTo(136));
    expect(longCity.right, lessThanOrEqualTo(longHero.right - 8));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == 'Villavicencio',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal hero uses a horizontal micro plate and short city', (
    tester,
  ) async {
    final vehicle = await harness.repository.createVehicle(
      plate: 'ZVV73D',
      kind: VehicleKind.motorcycle,
      serviceType: VehicleServiceType.private,
      nickname: 'Auteco Agility',
      registrationCity: 'Medellín',
    );
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      vehicle: vehicle,
      now: DateTime(2026, 9, 11, 15),
      viewportSize: const Size(360, 780),
      jurisdictions: const [
        RestrictionJurisdiction(
          id: 'co-ant-medellin',
          name: 'Medellín · Valle de Aburrá',
        ),
        RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogotá'),
      ],
    );

    expect(find.text('Medellín · Valle de Aburrá'), findsNothing);
    expect(find.text('Medellín'), findsWidgets);

    final hero = tester.getRect(
      find.byKey(const ValueKey('pico-personal-identity')),
    );
    final plate = tester.getRect(
      find.byKey(const ValueKey('colombian-plate-badge')),
    );
    expect(plate.width, inInclusiveRange(82, 88));
    expect(plate.width / plate.height, greaterThan(2.0));
    expect(plate.center.dx, closeTo(hero.center.dx, 1));

    final first = tester.getRect(
      find.byKey(const ValueKey('colombian-plate-first-group')),
    );
    final separator = tester.getRect(
      find.byKey(const ValueKey('colombian-plate-separator')),
    );
    final last = tester.getRect(
      find.byKey(const ValueKey('colombian-plate-last-group')),
    );
    expect((first.center.dy - last.center.dy).abs(), lessThanOrEqualTo(2));
    expect(first.right, lessThan(separator.left));
    expect(separator.right, lessThan(last.left));
    expect(findPlateNumber(vehicle.plate), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pico-personal-change-city')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal hero lifts motorcycles above the plate', (
    tester,
  ) async {
    final motorcycle = await harness.repository.createVehicle(
      plate: 'ZVV73D',
      kind: VehicleKind.motorcycle,
      serviceType: VehicleServiceType.private,
      nickname: 'Auteco Agility',
      registrationCity: 'Medellín',
    );
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      vehicle: motorcycle,
      now: DateTime(2026, 9, 12, 12),
      viewportSize: const Size(360, 780),
    );
    final motorcycleOffset = tester.widget<Transform>(
      find.byKey(const ValueKey('pico-personal-vehicle-art-offset')),
    );
    final motorcycleScale = tester.widget<Transform>(
      find.byKey(const ValueKey('pico-personal-vehicle-art-scale')),
    );
    expect(motorcycleOffset.transform.storage[13], -14);
    expect(motorcycleScale.transform.storage[0], 1.52);
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal hero keeps car geometry unchanged', (tester) async {
    final car = await harness.repository.createVehicle(
      plate: 'BOG127',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: 'Bogotá',
    );
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      vehicle: car,
      now: DateTime(2026, 9, 12, 12),
      viewportSize: const Size(360, 780),
    );
    final carOffset = tester.widget<Transform>(
      find.byKey(const ValueKey('pico-personal-vehicle-art-offset')),
    );
    final carScale = tester.widget<Transform>(
      find.byKey(const ValueKey('pico-personal-vehicle-art-scale')),
    );
    expect(carOffset.transform.storage[13], 0);
    expect(carScale.transform.storage[0], 1.55);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('personal identity and source geometry $width $scale', (
        tester,
      ) async {
        final vehicle = await harness.repository.createVehicle(
          plate: 'ABC125',
          kind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          registrationCity: 'Medellín',
        );
        await _pumpCityPico(
          tester,
          harness,
          store: _WeeklyRestrictionStore(harness.database),
          vehicle: vehicle,
          viewportSize: Size(width, width == 360 ? 780 : 915),
          textScaleFactor: scale,
        );
        final identity = tester.getRect(
          find.byKey(const ValueKey('pico-personal-identity')),
        );
        final name = tester.getRect(
          find.byKey(const ValueKey('pico-personal-vehicle-name')),
        );
        final plate = tester.getRect(
          find.byKey(const ValueKey('colombian-plate-badge')),
        );
        final vehicleArtSlot = tester.getRect(
          find.byKey(const ValueKey('pico-personal-vehicle-art-slot')),
        );
        final nameText = tester.widget<Text>(
          find.byKey(const ValueKey('pico-personal-vehicle-name')),
        );
        expect(name.left, lessThanOrEqualTo(identity.left + 32));
        expect(nameText.textAlign, TextAlign.left);
        expect(vehicleArtSlot.top, greaterThanOrEqualTo(name.bottom + 10));
        expect(plate.center.dx, closeTo(identity.center.dx, 1));
        expect(plate.top, greaterThan(name.bottom));
        expect(plate.right, lessThanOrEqualTo(identity.right));
        expect(plate.width, inInclusiveRange(82, 88));
        expect(plate.width / plate.height, greaterThan(2.0));
        expect(find.text('Carro particular'), findsNothing);
        expect(find.text('Mi vehículo'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('pico-personal-change-city')),
          findsOneWidget,
        );
        if (scale == 1) {
          expect(identity.height, inInclusiveRange(206, 212));
          expect(plate.center.dy, greaterThan(identity.bottom - 28));
        }
        if (const bool.fromEnvironment('PICO_CAPTURE')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '../temp/PLATE_OWNER_FIDELITY/screenshots/pico-clarity-auto-$width-$scale.png',
              );
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        final source = find.byKey(const ValueKey('pico-personal-source-row'));
        await tester.scrollUntilVisible(
          source,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(source);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('pico-personal-source-sheet')),
          findsOneWidget,
        );
        expect(find.textContaining('Vigencia publicada:'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scenario in [
    (hour: 1, minute: 0, countdown: 'Empieza en 4 h'),
    (hour: 4, minute: 59, countdown: 'Empieza en 1 min'),
    (hour: 5, minute: 0, countdown: 'Termina en 15 h'),
    (hour: 12, minute: 0, countdown: 'Termina en 8 h'),
    (hour: 19, minute: 59, countdown: 'Termina en 1 min'),
    (hour: 20, minute: 0, countdown: null),
  ]) {
    testWidgets(
      'personal summary phase at ${scenario.hour}:${scenario.minute}',
      (tester) async {
        final vehicle = await harness.repository.createVehicle(
          plate: 'ABC125',
          kind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          registrationCity: 'Medellín',
        );
        await _pumpCityPico(
          tester,
          harness,
          store: _WeeklyRestrictionStore(harness.database),
          vehicle: vehicle,
          now: DateTime(2026, 8, 31, scenario.hour, scenario.minute),
          viewportSize: const Size(390, 2400),
        );
        final summary = find.byKey(const ValueKey('pico-personal-screen'));
        expect(
          find.descendant(
            of: summary,
            matching: find.text('Tiene pico y placa hoy'),
          ),
          findsOneWidget,
        );
        expect(find.text('Estado inmediato'), findsNothing);
        final main = tester.widget<Text>(
          find.byKey(const ValueKey('pico-summary-main')),
        );
        expect(
          main.data!.replaceAll('\u00a0', ' '),
          scenario.countdown == null
              ? 'Restricción finalizada'
              : '5:00 a. m. – 8:00 p. m.',
        );
        if (scenario.countdown != null) {
          expect(find.text(scenario.countdown!), findsOneWidget);
        } else {
          expect(
            find.byKey(const ValueKey('pico-summary-countdown')),
            findsNothing,
          );
        }
        expect(find.text('Hoy · Lun 31/08/2026'), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('pico-next-restriction')))
              .data,
          startsWith('Lun 07/09/2026'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario in [
    (hour: 6, countdown: 'Este tramo termina en 2 h'),
    (hour: 12, countdown: 'Próximo tramo en 4 h'),
    (hour: 17, countdown: 'Este tramo termina en 3 h'),
    (hour: 21, countdown: null),
  ]) {
    testWidgets('personal split windows at ${scenario.hour}', (tester) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'ABC125',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      await _pumpCityPico(
        tester,
        harness,
        store: _WeeklyRestrictionStore(
          harness.database,
          windows: const [
            RestrictionTimeWindow(startMinute: 300, endMinute: 480),
            RestrictionTimeWindow(startMinute: 960, endMinute: 1200),
          ],
        ),
        vehicle: vehicle,
        now: DateTime(2026, 8, 31, scenario.hour),
        viewportSize: const Size(390, 2400),
      );
      final main = tester.widget<Text>(
        find.byKey(const ValueKey('pico-summary-main')),
      );
      expect(
        main.data!.replaceAll('\u00a0', ' '),
        scenario.countdown == null
            ? 'Restricción finalizada'
            : '5:00 a. m. – 8:00 a. m.\n4:00 p. m. – 8:00 p. m.',
      );
      if (scenario.countdown != null) {
        expect(find.text(scenario.countdown!), findsOneWidget);
      } else {
        expect(
          find.byKey(const ValueKey('pico-summary-countdown')),
          findsNothing,
        );
      }
      if (scenario.hour == 12) {
        expect(find.text('Sin restricción ahora'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final status in ['allowed', 'unknown', 'stale']) {
    testWidgets('personal instant $status stays honest', (tester) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'ABC123',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      await _pumpCityPico(
        tester,
        harness,
        store: switch (status) {
          'unknown' => _NoCoverageStore(harness.database),
          'stale' => _StaleCoverageStore(harness.database),
          _ => _WeeklyRestrictionStore(harness.database),
        },
        vehicle: vehicle,
        viewportSize: const Size(390, 2400),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pico-summary-main')))
            .data,
        switch (status) {
          'unknown' => 'Por verificar',
          'stale' => 'Datos vencidos',
          _ => 'Puede circular',
        },
      );
      expect(find.text('Hoy · Lun 31/08/2026'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('personal minute tick updates phase without reloading coverage', (
    tester,
  ) async {
    final vehicle = await harness.repository.createVehicle(
      plate: 'ABC125',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: 'Medellín',
    );
    final clock = ValueNotifier(DateTime(2026, 8, 31, 4, 59));
    addTearDown(clock.dispose);
    final store = _WeeklyRestrictionStore(harness.database);
    await _pumpCityPico(
      tester,
      harness,
      store: store,
      vehicle: vehicle,
      clock: clock,
      viewportSize: const Size(390, 2400),
    );
    expect(find.text('Empieza en 1 min'), findsOneWidget);
    final requestCount = store.requestedJurisdictions.length;
    clock.value = DateTime(2026, 8, 31, 5);
    await tester.pumpAndSettle();
    expect(find.text('Termina en 15 h'), findsOneWidget);
    clock.value = DateTime(2026, 8, 31, 20);
    await tester.pumpAndSettle();
    expect(find.text('Restricción finalizada'), findsOneWidget);
    expect(store.requestedJurisdictions.length, requestCount);
  });

  testWidgets(
    'midnight clears old green while coverage loads and refreshes upcoming days',
    (tester) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'ABC121',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      final clock = ValueNotifier(DateTime(2026, 8, 31, 23, 59));
      addTearDown(clock.dispose);
      final store = _DelayedRestrictionStore(harness.database);
      await _pumpCityPico(
        tester,
        harness,
        store: store,
        vehicle: vehicle,
        clock: clock,
        viewportSize: const Size(390, 2400),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pico-summary-main')))
            .data,
        'Puede circular',
      );
      store.pending = Completer<void>();
      clock.value = DateTime(2026, 9, 1);
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pico-summary-main')))
            .data,
        'Por verificar',
      );
      expect(find.text('Hoy · Mar 01/09/2026'), findsNothing);
      expect(
        find.byKey(const ValueKey('pico-month-day-2026-09-02')),
        findsOneWidget,
      );
      store.pending!.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pico-summary-main')))
            .data,
        '5:00\u00a0a.\u00a0m. – 8:00\u00a0p.\u00a0m.',
      );
      expect(find.text('Tiene pico y placa hoy'), findsOneWidget);
    },
  );

  for (final navigate in [false, true]) {
    testWidgets(
      'midnight month rollover preserves consulted month: $navigate',
      (tester) async {
        final vehicle = await harness.repository.createVehicle(
          plate: 'ABC125',
          kind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          registrationCity: 'Medellín',
        );
        final clock = ValueNotifier(DateTime(2026, 8, 31, 23, 59));
        addTearDown(clock.dispose);
        await _pumpCityPico(
          tester,
          harness,
          store: _WeeklyRestrictionStore(harness.database),
          vehicle: vehicle,
          clock: clock,
          viewportSize: const Size(390, 2400),
        );
        Finder todayMarker(String date, String status) => find.ancestor(
          of: find.byKey(ValueKey('pico-month-day-$date')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Hoy · $date $status' &&
                widget.properties.selected == true,
          ),
        );
        // Rendered semantics may merge the date label with the day number.
        expect(todayMarker('2026-08-31', 'Con pico y placa'), findsOneWidget);
        if (navigate) {
          await tester.tap(find.byKey(const ValueKey('pico-month-previous')));
          await tester.pumpAndSettle();
        }
        clock.value = DateTime(2026, 9, 1);
        await tester.pumpAndSettle();
        expect(
          find.text(navigate ? 'Julio 2026' : 'Septiembre 2026'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('pico-personal-month-calendar')),
          findsOneWidget,
        );
        expect(find.text('Hoy · Mar 01/09/2026'), findsNothing);
        expect(todayMarker('2026-08-31', 'Con pico y placa'), findsNothing);
        if (!navigate) {
          expect(todayMarker('2026-09-01', 'Sin pico y placa'), findsOneWidget);
        }
        expect(
          await harness.preferences.getString(picoJurisdictionPreferenceKey),
          'co-ant-medellin',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'personal coverage error preserves consulted calendar through recovery',
    (tester) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'ABC125',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      final clock = ValueNotifier(DateTime(2026, 8, 31, 23, 59));
      addTearDown(clock.dispose);
      final store = _DelayedRestrictionStore(harness.database);
      await _pumpCityPico(
        tester,
        harness,
        store: store,
        vehicle: vehicle,
        clock: clock,
        viewportSize: const Size(390, 2400),
      );
      await tester.tap(find.byKey(const ValueKey('pico-month-previous')));
      await tester.pumpAndSettle();
      expect(find.text('Julio 2026'), findsOneWidget);

      store.pending = Completer<void>();
      clock.value = DateTime(2026, 9, 1);
      await tester.pump();
      store.pending!.completeError(StateError('Test coverage failure'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos cargar la cobertura. Estado sin confirmar.'),
        findsOneWidget,
      );
      expect(find.text('Julio 2026'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pico-personal-month-calendar')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pico-summary-main')))
            .data,
        'Por verificar',
      );

      store.pending = null;
      clock.value = DateTime(2026, 9, 2);
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos cargar la cobertura. Estado sin confirmar.'),
        findsNothing,
      );
      expect(find.text('Julio 2026'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pico-personal-month-calendar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('city change stays neutral until new coverage completes', (
    tester,
  ) async {
    final store = _DelayedRestrictionStore(harness.database);
    await _pumpCityPico(
      tester,
      harness,
      store: store,
      viewportSize: const Size(390, 1600),
    );
    final hero = find.byKey(const ValueKey('pico-city-hero'));
    expect(
      find.descendant(of: hero, matching: find.text('Pico y placa hoy')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('pico-city-change')));
    await tester.pumpAndSettle();
    final option = find.byKey(const ValueKey('pico-city-option-co-dc-bogota'));
    await tester.ensureVisible(option);
    store.pending = Completer<void>();
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Bogotá'), findsWidgets);
    expect(
      find.descendant(of: hero, matching: find.text('Cargando cobertura')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('Sin restricción hoy')),
      findsNothing,
    );
    expect(
      find.descendant(of: hero, matching: find.text('Pico y placa hoy')),
      findsNothing,
    );
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-ant-medellin',
    );
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: hero, matching: find.text('Sin restricción hoy')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final change in ['date', 'seed']) {
    testWidgets(
      'city $change renewal discards old coverage and caches minute ticks',
      (tester) async {
        final clock = ValueNotifier(DateTime(2026, 8, 31, 23, 58));
        addTearDown(clock.dispose);
        final store = _DelayedRestrictionStore(harness.database);
        await _pumpCityPico(
          tester,
          harness,
          store: store,
          clock: clock,
          viewportSize: const Size(390, 1600),
        );
        final hero = find.byKey(const ValueKey('pico-city-hero'));
        expect(
          find.descendant(of: hero, matching: find.text('Pico y placa hoy')),
          findsOneWidget,
        );
        final requestCount = store.requestedJurisdictions.length;
        clock.value = DateTime(2026, 8, 31, 23, 59);
        await tester.pumpAndSettle();
        expect(store.requestedJurisdictions.length, requestCount);
        await tester.tap(
          find.byKey(const ValueKey('pico-city-category-motorcycles')),
        );
        await tester.pumpAndSettle();
        expect(store.requestedJurisdictions.length, requestCount);
        store.pending = Completer<void>();
        if (change == 'date') {
          clock.value = DateTime(2026, 9, 1);
        } else {
          ProviderScope.containerOf(
            tester.element(find.byType(PicoDetailScreen)),
          ).invalidate(bundledRestrictionsProvider);
        }
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: hero, matching: find.text('Cargando cobertura')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: hero, matching: find.text('Sin restricción hoy')),
          findsNothing,
        );
        expect(
          find.descendant(of: hero, matching: find.text('Pico y placa hoy')),
          findsNothing,
        );
        expect(_cityDigits(_cityDay(0), '7 · 9'), findsNothing);
        expect(_cityDigits(_cityDay(1), '2 · 4'), findsNothing);
        store.pending!.complete();
        await tester.pumpAndSettle();
        expect(store.requestedJurisdictions.length, requestCount + 3);
        expect(
          find.descendant(of: hero, matching: find.text('Pico y placa hoy')),
          findsOneWidget,
        );
        expect(
          _cityDigits(hero, change == 'date' ? '2 · 4' : '7 · 9'),
          findsOneWidget,
        );
        expect(_cityDigits(_cityDay(0), '7 · 9'), findsOneWidget);
        expect(_cityDigits(_cityDay(1), '2 · 4'), findsOneWidget);
        clock.value = change == 'date'
            ? clock.value.add(const Duration(minutes: 1))
            : clock.value.subtract(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(store.requestedJurisdictions.length, requestCount + 3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'personal state and split hours wrap at $width scale $scale',
        (tester) async {
          final vehicle = await harness.repository.createVehicle(
            plate: 'ABC125',
            kind: VehicleKind.car,
            serviceType: VehicleServiceType.private,
            registrationCity: 'Medellín',
          );
          await _pumpCityPico(
            tester,
            harness,
            store: _WeeklyRestrictionStore(
              harness.database,
              windows: const [
                RestrictionTimeWindow(startMinute: 300, endMinute: 480),
                RestrictionTimeWindow(startMinute: 960, endMinute: 1200),
              ],
            ),
            vehicle: vehicle,
            viewportSize: Size(width, 915),
            textScaleFactor: scale,
          );
          expect(tester.takeException(), isNull);
          final hours = find.byKey(const ValueKey('pico-summary-main'));
          await tester.ensureVisible(hours);
          await tester.pumpAndSettle();
          final hoursText = tester.widget<Text>(hours);
          expect(hoursText.maxLines, isNull);
          expect(hoursText.overflow, isNot(TextOverflow.ellipsis));
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('pico-summary-main')),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('pico-summary-main')))
                .maxLines,
            isNull,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('pico-personal-month-calendar')),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('explicit city is consulted without changing global preference', (
    tester,
  ) async {
    final store = _WeeklyRestrictionStore(harness.database);
    await _pumpCityPico(
      tester,
      harness,
      store: store,
      transientJurisdictionId: 'co-dc-bogota',
    );

    expect(find.byKey(const ValueKey('pico-city-screen')), findsOneWidget);
    expect(find.text('Bogotá'), findsWidgets);
    expect(find.text('Medellín'), findsNothing);
    expect(find.byKey(const ValueKey('pico-city-adopt')), findsNothing);
    expect(store.requestedJurisdictions, isNotEmpty);
    expect(store.requestedJurisdictions, everyElement('co-dc-bogota'));
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-ant-medellin',
    );
  });

  testWidgets('city view shows short city and category-specific hero art', (
    tester,
  ) async {
    final store = _WeeklyRestrictionStore(harness.database);
    await _pumpCityPico(
      tester,
      harness,
      store: store,
      jurisdictions: const [
        RestrictionJurisdiction(
          id: 'co-ant-medellin',
          name: 'Medellín · Valle de Aburrá',
        ),
      ],
      viewportSize: const Size(390, 1200),
    );

    final selector = find.byKey(const ValueKey('pico-city-change'));
    expect(
      find.descendant(of: selector, matching: find.text('Medellín')),
      findsOneWidget,
    );
    expect(find.text('Medellín · Valle de Aburrá'), findsNothing);

    final art = find.byKey(const ValueKey('pico-city-hero-art'));
    expect(
      find.descendant(
        of: art,
        matching: find.byKey(const ValueKey('pico-city-hero-vehicle-art-cars')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: art, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: art,
        matching: find.byIcon(Icons.directions_car_filled_rounded),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('pico-city-category-motorcycles')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: art,
        matching: find.byKey(
          const ValueKey('pico-city-hero-vehicle-art-motorcycles'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: art,
        matching: find.byIcon(Icons.two_wheeler_rounded),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('pico-city-category-taxis')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: art,
        matching: find.byKey(
          const ValueKey('pico-city-hero-vehicle-art-taxis'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: art, matching: find.byIcon(Icons.local_taxi_rounded)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('consulted city is adopted only inside its selector', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      transientJurisdictionId: 'co-dc-bogota',
    );
    final adopt = find.byKey(const ValueKey('pico-city-adopt'));
    expect(adopt, findsNothing);
    await tester.tap(find.byKey(const ValueKey('pico-city-change')));
    await tester.pumpAndSettle();
    final selector = find.byKey(const ValueKey('pico-city-selector'));
    expect(find.descendant(of: selector, matching: adopt), findsOneWidget);
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-ant-medellin',
    );
    await tester.ensureVisible(adopt);
    await tester.tap(adopt);
    await tester.pumpAndSettle();
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-dc-bogota',
    );
    expect(tester.takeException(), isNull);
  });

  for (final status in ['restricted', 'allowed', 'unknown', 'stale']) {
    testWidgets('city hero has the approved $status label', (tester) async {
      final store = switch (status) {
        'unknown' => _NoCoverageStore(harness.database),
        'stale' => _StaleCoverageStore(harness.database),
        _ => _WeeklyRestrictionStore(harness.database),
      };
      final label = switch (status) {
        'restricted' => 'Pico y placa hoy',
        'allowed' => 'Sin restricción hoy',
        'unknown' => 'Por verificar',
        _ => 'Datos vencidos',
      };
      await _pumpCityPico(
        tester,
        harness,
        store: store,
        now: DateTime(2026, 9, status == 'allowed' ? 3 : 1, 12),
      );
      final hero = find.byKey(const ValueKey('pico-city-hero'));
      expect(
        find.descendant(of: hero, matching: find.text(label)),
        findsOneWidget,
      );
      if (status == 'unknown' || status == 'stale') {
        expect(
          find.descendant(of: hero, matching: find.text('Sin restricción hoy')),
          findsNothing,
        );
        expect(_cityDigits(hero, '1 · 4'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final consultedCity in ['co-ant-medellin', 'co-dc-bogota']) {
    testWidgets('vehicle sheet opens explicit vehicle in $consultedCity', (
      tester,
    ) async {
      final favorite = await harness.repository.createVehicle(
        plate: 'ABC125',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      final other = await harness.repository.createVehicle(
        plate: 'XYZ129',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      await harness.repository.setActiveVehicle(favorite.id);
      Uri? destination;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PicoDetailScreen(jurisdictionId: consultedCity),
          ),
          GoRoute(
            path: '/apps/pico',
            builder: (_, state) {
              destination = state.uri;
              return PicoDetailScreen(
                vehicleId: state.uri.queryParameters['vehicleId'],
                jurisdictionId: state.uri.queryParameters['jurisdictionId'],
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      final store = _WeeklyRestrictionStore(harness.database);
      await _pumpCityPico(
        tester,
        harness,
        store: store,
        vehicles: [favorite, other],
        activeVehicle: favorite,
        router: router,
      );
      expect(
        find.byKey(ValueKey('pico-city-vehicle-${other.id}')),
        findsNothing,
      );
      final open = find.byKey(const ValueKey('pico-city-vehicles-open'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('pico-city-vehicles-sheet'));
      expect(sheet, findsOneWidget);
      for (final vehicle in [favorite, other]) {
        expect(
          find.descendant(
            of: sheet,
            matching: find.byKey(ValueKey('pico-city-vehicle-${vehicle.id}')),
          ),
          findsOneWidget,
        );
      }
      final target = find.byKey(ValueKey('pico-city-vehicle-${other.id}'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(destination?.queryParameters['vehicleId'], other.id);
      expect(destination?.queryParameters['jurisdictionId'], consultedCity);
      expect(
        find.byKey(const ValueKey('pico-personal-screen')),
        findsOneWidget,
      );
      expect(findPlateNumber(other.plate), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, favorite.id);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
      expect(store.requestedJurisdictions, everyElement(consultedCity));
      expect(tester.takeException(), isNull);
    });
  }

  for (final change in ['date', 'seed', 'expiry']) {
    testWidgets('vehicle sheet renews on $change without minute queries', (
      tester,
    ) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'ABC125',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      final clock = ValueNotifier(
        change == 'date'
            ? DateTime(2026, 8, 31, 23, 58)
            : DateTime(2026, 8, 31, 11, 59),
      );
      addTearDown(clock.dispose);
      final store = _SheetRestrictionStore(
        harness.database,
        expiresAt: change == 'expiry' ? DateTime.utc(2026, 8, 31, 17, 1) : null,
      );
      await _pumpCityPico(
        tester,
        harness,
        store: store,
        vehicles: [vehicle],
        activeVehicle: vehicle,
        clock: clock,
      );
      final initialRequests = store.attempts;
      final sheet = await _openCityVehicles(tester);
      final row = find.byKey(ValueKey('pico-city-vehicle-${vehicle.id}'));
      // Daily evaluation is already stale when coverage expires within today.
      // The expiry boundary must still trigger a fresh load of the open sheet.
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            change == 'expiry' ? 'Datos vencidos' : 'Con pico y placa',
          ),
        ),
        findsOneWidget,
      );
      expect(
        store.attempts,
        initialRequests,
        reason: 'Opening the sheet reuses the loaded category coverage.',
      );
      clock.value = clock.value.add(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(store.attempts, initialRequests);

      store.pending = Completer<void>();
      if (change == 'date') {
        clock.value = DateTime(2026, 9, 1);
      } else if (change == 'expiry') {
        clock.value = DateTime(2026, 8, 31, 12, 1);
      } else {
        store.allowAll = true;
        ProviderScope.containerOf(tester.element(sheet))
            .invalidate(bundledRestrictionsProvider);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: row),
        findsNothing,
        reason: 'Old vehicle verdicts must disappear during renewal.',
      );
      store.pending!.complete();
      await tester.pumpAndSettle();
      expect(store.attempts, greaterThan(initialRequests));
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            change == 'expiry' ? 'Datos vencidos' : 'Sin pico y placa',
          ),
        ),
        findsOneWidget,
      );
      final renewedRequests = store.attempts;
      clock.value = clock.value.add(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(store.attempts, renewedRequests);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'vehicle sheet refreshes inserted and removed vehicles while open',
    (tester) async {
      final first = await harness.repository.createVehicle(
        plate: 'ABC125',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      final second = await harness.repository.createVehicle(
        plate: 'XYZ129',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      final vehicles = ValueNotifier<List<VehicleProfile>>([first]);
      addTearDown(vehicles.dispose);
      await _pumpCityPico(
        tester,
        harness,
        store: _SheetRestrictionStore(harness.database),
        vehicleChanges: vehicles,
        activeVehicle: first,
      );
      final sheet = await _openCityVehicles(tester);
      final firstRow = find.byKey(ValueKey('pico-city-vehicle-${first.id}'));
      final secondRow = find.byKey(ValueKey('pico-city-vehicle-${second.id}'));
      expect(find.descendant(of: sheet, matching: firstRow), findsOneWidget);
      expect(secondRow, findsNothing);
      vehicles.value = [first, second];
      await tester.pumpAndSettle();
      expect(find.descendant(of: sheet, matching: secondRow), findsOneWidget);
      vehicles.value = [second];
      await tester.pumpAndSettle();
      expect(find.descendant(of: sheet, matching: firstRow), findsNothing);
      expect(find.descendant(of: sheet, matching: secondRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'vehicle sheet retry fetches fresh coverage after cached failure',
    (tester) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'ABC125',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      final store = _SheetRestrictionStore(harness.database)..fail = true;
      await _pumpCityPico(
        tester,
        harness,
        store: store,
        vehicles: [vehicle],
        activeVehicle: vehicle,
      );
      final requestsBeforeOpen = store.attempts;
      final sheet = await _openCityVehicles(tester);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('No pudimos cargar tus vehículos.'),
        ),
        findsOneWidget,
      );
      expect(store.attempts, requestsBeforeOpen);
      store.fail = false;
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Reintentar')),
      );
      await tester.pumpAndSettle();
      expect(store.attempts, greaterThan(requestsBeforeOpen));
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('No pudimos cargar tus vehículos.'),
        ),
        findsNothing,
      );
      final row = find.byKey(ValueKey('pico-city-vehicle-${vehicle.id}'));
      expect(find.descendant(of: sheet, matching: row), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Con pico y placa')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'vehicle list failure leaves city usable and sheet retry recovers',
    (tester) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'ABC125',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      var fail = true;
      var loads = 0;
      await _pumpCityPico(
        tester,
        harness,
        store: _WeeklyRestrictionStore(harness.database),
        loadVehicles: () async {
          loads++;
          if (fail) throw StateError('Test vehicle list failure');
          return [vehicle];
        },
      );
      expect(loads, 0, reason: 'City consultation must not load vehicles.');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PicoDetailScreen)),
      );
      await expectLater(
        container.read(vehicleListProvider.future),
        throwsStateError,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pico-city-screen')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pico-city-hero')),
          matching: find.text('Pico y placa hoy'),
        ),
        findsOneWidget,
      );
      expect(_cityDigits(_cityDay(0), '5 · 8'), findsOneWidget);

      final sheet = await _openCityVehicles(tester);
      final error = find.descendant(
        of: sheet,
        matching: find.text('No pudimos cargar tus vehículos.'),
      );
      expect(error, findsOneWidget);
      final failedLoads = loads;
      fail = false;
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Reintentar')),
      );
      await tester.pumpAndSettle();
      expect(loads, greaterThan(failedLoads));
      expect(error, findsNothing);
      expect(
        find.descendant(
          of: sheet,
          matching: find.byKey(ValueKey('pico-city-vehicle-${vehicle.id}')),
        ),
        findsOneWidget,
      );
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();
      expect(_cityDigits(_cityDay(0), '5 · 8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty vehicle sheet offers add vehicle without an error', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      vehicles: const [],
    );
    final sheet = await _openCityVehicles(tester);
    final add = find.descendant(
      of: sheet,
      matching: find.byKey(const ValueKey('pico-city-add-vehicle')),
    );
    expect(add.hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: add, matching: find.text('Agregar vehículo')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('No pudimos cargar tus vehículos.'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('pico-city-vehicle-');
        }),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rule and source entry points select the correct sheet tab', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(
        harness.database,
        sourceUrls: const [
          _cityOfficialSource,
          _cityOfficialSource,
          _cityOtherSource,
        ],
      ),
    );
    final sheet = find.byKey(const ValueKey('pico-city-rule-source-sheet'));
    final rule = find.byKey(const ValueKey('pico-city-rule-open'));
    await tester.ensureVisible(rule);
    await tester.tap(rule);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Regla y vigencia')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Fuentes')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining('Vigencia')),
      findsWidgets,
    );
    expect(find.text(_cityOfficialSource).hitTestable(), findsNothing);
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Fuentes')),
    );
    await tester.pumpAndSettle();
    _expectCitySources(sheet);
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
    final source = find.byKey(const ValueKey('pico-city-source-row'));
    await tester.ensureVisible(source);
    await tester.tap(source);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    _expectCitySources(sheet);
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Regla y vigencia')),
    );
    await tester.pumpAndSettle();
    expect(find.text(_cityOfficialSource).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each dated day opens its own rule details', (tester) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
    );
    for (final entry in [
      (0, 'Último dígito 5 y 8'),
      (1, 'Último dígito 1 y 4'),
      (2, 'Último dígito 0, 1, 2, 3 y 4'),
    ]) {
      final day = _cityDay(entry.$1);
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text(entry.$2)),
        findsOneWidget,
      );
      final date = DateTime(2026, 8, 31 + entry.$1);
      final dateLabel =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}';
      expect(
        find.descendant(of: sheet, matching: find.textContaining(dateLabel)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('5:00 a. m.')),
        findsWidgets,
      );
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('dated week evaluates an override only on its published date', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _DatedRestrictionStore(harness.database),
      now: DateTime(2026, 9, 2, 12),
    );
    _expectCityWeek(tester, monday: DateTime(2026, 8, 31), expectDates: true);
    expect(_cityDigits(_cityDay(0), '5 · 8'), findsOneWidget);
    expect(_cityDigits(_cityDay(1), '6'), findsOneWidget);
    expect(_cityDigits(_cityDay(1), '1 · 4'), findsNothing);
    expect(_cityDigits(_cityDay(2), '0 · 1 · 2 · 3 · 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final invalidId in ['unknown-city', '']) {
    testWidgets('invalid explicit city "$invalidId" does not fall back', (
      tester,
    ) async {
      final store = _WeeklyRestrictionStore(harness.database);
      await _pumpCityPico(
        tester,
        harness,
        store: store,
        transientJurisdictionId: invalidId,
      );

      expect(find.text('No reconocemos la ciudad solicitada.'), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-city-screen')), findsNothing);
      expect(store.requestedJurisdictions, isEmpty);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
    });
  }

  testWidgets('ordinary city view uses the saved global preference', (
    tester,
  ) async {
    await harness.preferences.setString(
      picoJurisdictionPreferenceKey,
      'co-dc-bogota',
    );
    final store = _WeeklyRestrictionStore(harness.database);
    await _pumpCityPico(tester, harness, store: store);

    expect(find.text('Bogotá'), findsWidgets);
    expect(find.byKey(const ValueKey('pico-city-adopt')), findsNothing);
    expect(store.requestedJurisdictions, isNotEmpty);
    expect(store.requestedJurisdictions, everyElement('co-dc-bogota'));
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-dc-bogota',
    );
  });

  testWidgets(
    'city composition has one vertical week and compact entry points',
    (tester) async {
      await _pumpCityPico(
        tester,
        harness,
        store: _WeeklyRestrictionStore(harness.database),
        viewportSize: const Size(390, 1400),
      );

      final page = find.byKey(const ValueKey('pico-city-screen'));
      expect(tester.widget(page), isA<SingleChildScrollView>());
      expect(
        tester.widget<SingleChildScrollView>(page).scrollDirection,
        Axis.vertical,
      );
      final hero = find.byKey(const ValueKey('pico-city-hero'));
      final week = find.byKey(const ValueKey('pico-city-week-card'));
      expect(week, findsOneWidget);
      expect(
        tester.getRect(hero).bottom,
        lessThanOrEqualTo(tester.getRect(week).top),
      );
      for (final key in [
        'pico-city-change',
        'pico-city-category-segment',
        'pico-city-week-card',
        'pico-city-rule-open',
        'pico-city-source-row',
        'pico-city-vehicles-open',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
        expect(
          find.descendant(of: hero, matching: find.byKey(ValueKey(key))),
          findsNothing,
        );
      }
      for (final key in [
        'pico-city-rotation-card',
        'pico-city-rule-summary-card',
        'pico-city-vehicles-card',
        'pico-city-vehicles-list',
        'pico-city-adopt',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      expect(find.text('Cómo aplica'), findsNothing);
      expect(find.text('Rotación vigente'), findsNothing);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Semana'), findsNothing);
      _expectNoHorizontalScroll();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('city week keeps all seven dated days in calendar order', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
      viewportSize: const Size(390, 1400),
    );

    _expectCityWeek(tester, monday: DateTime(2026, 8, 31));
    expect(_cityDigits(_cityDay(0), '5 · 8'), findsOneWidget);
    expect(_cityDigits(_cityDay(1), '1 · 4'), findsOneWidget);
    expect(_cityDigits(_cityDay(2), '0 · 1 · 2 · 3 · 4'), findsOneWidget);
    for (var index = 3; index < 7; index++) {
      expect(
        find.descendant(
          of: _cityDay(index),
          matching: find.text(index >= 5 ? 'Sin restricción' : 'Libre'),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('week shows restricted digits evaluated independently per day', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-city-week-card')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(_cityDigits(_cityDay(0), '5 · 8'), findsOneWidget);
    expect(_cityDigits(_cityDay(1), '1 · 4'), findsOneWidget);
  });

  testWidgets('week uses the selected vehicle category rules', (tester) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
    );

    await tester.tap(
      find.byKey(const ValueKey('pico-city-category-motorcycles')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-city-week-card')),
      260,
      scrollable: find.byType(Scrollable).first,
    );

    expect(_cityDigits(_cityDay(0), '7 · 9'), findsOneWidget);
  });

  testWidgets('city schedule groups split hours once and excludes free days', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(
        harness.database,
        mondayWindows: const [
          RestrictionTimeWindow(startMinute: 360, endMinute: 600),
          RestrictionTimeWindow(startMinute: 960, endMinute: 1200),
        ],
      ),
    );
    final schedule = find.byKey(const ValueKey('pico-city-schedule'));
    await tester.ensureVisible(schedule);
    await tester.pumpAndSettle();
    const splitHours = '6:00 a. m. – 10:00 a. m.\n4:00 p. m. – 8:00 p. m.';
    const continuousHours = '5:00 a. m. – 8:00 p. m.';
    for (final group in [('Lun', splitHours), ('Mar · Mié', continuousHours)]) {
      final row = find.descendant(
        of: schedule,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Flex &&
              widget.children.any(
                (child) => child is Text && child.data == group.$1,
              ),
        ),
      );
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text(group.$2)),
        findsOneWidget,
      );
    }
    expect(
      tester
          .widgetList<Text>(
            find.descendant(of: schedule, matching: find.byType(Text)),
          )
          .map((text) => text.data),
      unorderedEquals([
        'Horario de aplicación',
        'Lun',
        splitHours,
        'Mar · Mié',
        continuousHours,
      ]),
    );
    for (var index = 3; index < 7; index++) {
      final day = _cityDay(index);
      expect(
        find.descendant(
          of: day,
          matching: find.text(index >= 5 ? 'Sin restricción' : 'Libre'),
        ),
        findsOneWidget,
      );
      expect(tester.getSemantics(day).label, isNot(matches(r'\d{1,2}:\d{2}')));
    }
    _expectCompleteText(tester, schedule);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holiday exemption is evaluated for the displayed date', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _HolidayRestrictionStore(harness.database),
      now: DateTime(2026, 8, 17, 12),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-city-week-card')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final holiday = find.byKey(const ValueKey('pico-city-week-day-0'));

    expect(
      find.descendant(of: holiday, matching: find.text('Libre')),
      findsOneWidget,
    );
    expect(_cityDigits(holiday, '5 · 8'), findsNothing);
  });

  testWidgets('week reports missing current coverage without claiming free', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _NoCoverageStore(harness.database),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-city-week-card')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final monday = find.byKey(const ValueKey('pico-city-week-day-0'));
    expect(
      find.descendant(of: monday, matching: find.text('Por verificar')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monday, matching: find.text('Libre')),
      findsNothing,
    );
  });

  testWidgets('stale week never presents expired coverage as free', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _StaleCoverageStore(harness.database),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-city-week-card')),
      260,
      scrollable: find.byType(Scrollable).first,
    );

    final monday = find.byKey(const ValueKey('pico-city-week-day-0'));
    expect(
      find.descendant(of: monday, matching: find.text('Datos vencidos')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monday, matching: find.text('Libre')),
      findsNothing,
    );
  });

  for (final viewport in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
    Size(768, 1024),
  ]) {
    for (final textScale in const [1.0, 1.5, 2.0]) {
      testWidgets('compact city and complete week fit at ${viewport.width.toInt()}x'
          '${viewport.height.toInt()} scale $textScale', (tester) async {
        await _pumpCityPico(
          tester,
          harness,
          store: _WeeklyRestrictionStore(harness.database),
          viewportSize: viewport,
          textScaleFactor: textScale,
        );
        _expectNoHorizontalScroll();
        _expectCityWeek(tester, monday: DateTime(2026, 8, 31));
        await _captureCity(
          tester,
          'city-${viewport.width.toInt()}x${viewport.height.toInt()}-$textScale',
        );
        _expectCitySectionsDoNotOverlap(tester, viewport.width);
        for (var index = 0; index < 7; index++) {
          await tester.ensureVisible(_cityDay(index));
          await tester.pumpAndSettle();
          _expectCompleteText(tester, _cityDay(index));
        }
        expect(_cityDigits(_cityDay(2), '0 · 1 · 2 · 3 · 4'), findsOneWidget);
        await _captureCity(
          tester,
          'week-${viewport.width.toInt()}x${viewport.height.toInt()}-$textScale',
        );
        expect(tester.takeException(), isNull);

        final sourceRow = find.byKey(const ValueKey('pico-city-source-row'));
        await tester.ensureVisible(sourceRow);
        await tester.pumpAndSettle();
        _expectCompleteText(tester, sourceRow);
        await tester.tap(sourceRow);
        await tester.pumpAndSettle();
        final sheet = find.byKey(const ValueKey('pico-city-rule-source-sheet'));
        expect(sheet, findsOneWidget);
        await _captureCity(
          tester,
          'sources-${viewport.width.toInt()}x${viewport.height.toInt()}-$textScale',
        );
        _expectCompleteText(tester, sheet);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'unknown week copy stays complete at ${viewport.width.toInt()}x'
        '${viewport.height.toInt()} scale $textScale',
        (tester) async {
          await _pumpCityPico(
            tester,
            harness,
            store: _NoCoverageStore(harness.database),
            viewportSize: viewport,
            textScaleFactor: textScale,
          );
          _expectCityWeek(tester, monday: DateTime(2026, 8, 31));
          _expectCitySectionsDoNotOverlap(tester, viewport.width);
          for (var index = 0; index < 7; index++) {
            await tester.ensureVisible(_cityDay(index));
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: _cityDay(index),
                matching: find.text('Por verificar'),
              ),
              findsOneWidget,
            );
            _expectCompleteText(tester, _cityDay(index));
          }
          _expectNoHorizontalScroll();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'personal Pico keeps its vehicle and does not mutate the global city',
    (tester) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'ABC123',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Medellín',
      );
      await harness.repository.setActiveVehicle(vehicle.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpCityPico(
        tester,
        harness,
        store: _WeeklyRestrictionStore(harness.database),
        vehicle: vehicle,
        transientJurisdictionId: 'co-dc-bogota',
      );

      expect(find.text('Mi pico y placa'), findsNothing);
      expect(
        find.byKey(const ValueKey('pico-personal-hero-city')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pico-personal-hero-back')),
        findsOneWidget,
      );
      expect(findPlateNumber(vehicle.plate), findsOneWidget);
      expect(find.text('Pico y placa de la ciudad'), findsNothing);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
      expect((await harness.repository.getActiveVehicle())?.id, vehicle.id);
    },
  );
}

const _cityOfficialSource =
    'https://secretaria-de-movilidad.medellin.gov.co/fuente-oficial/';
const _cityOtherSource = 'https://www.medellin.gov.co/decreto-prueba/';

Finder _cityDay(int index) => find.byKey(ValueKey('pico-city-week-day-$index'));

Finder _cityDigits(Finder parent, String digits) => find.descendant(
  of: parent,
  matching: find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final text = widget.data ?? widget.textSpan?.toPlainText();
    return text == digits ||
        text == 'Último dígito: $digits' ||
        text == 'Primer dígito: $digits';
  }),
);

void _expectNoHorizontalScroll() {
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
    ),
    findsNothing,
  );
}

void _expectCityWeek(
  WidgetTester tester, {
  required DateTime monday,
  bool expectDates = false,
}) {
  final week = find.byKey(const ValueKey('pico-city-week-card'));
  expect(week, findsOneWidget);
  const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  Rect? previous;
  for (var index = 0; index < 7; index++) {
    final day = _cityDay(index);
    expect(find.descendant(of: week, matching: day), findsOneWidget);
    final date = DateTime(monday.year, monday.month, monday.day + index);
    final datedLabel = '${labels[index]} ${date.day}';
    final fullDate =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    expect(tester.getSemantics(day).label, contains(fullDate));
    expect(
      find.descendant(
        of: day,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == labels[index] || widget.data == datedLabel),
        ),
      ),
      findsOneWidget,
    );
    if (expectDates) {
      expect(
        find.descendant(
          of: day,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data == '${date.day}' || widget.data == datedLabel),
          ),
        ),
        findsOneWidget,
      );
    }
    final rect = tester.getRect(day);
    final weekRect = tester.getRect(week);
    expect(rect.left, greaterThanOrEqualTo(weekRect.left - 0.000001));
    expect(rect.right, lessThanOrEqualTo(weekRect.right + 0.000001));
    if (previous != null) {
      expect(rect.overlaps(previous), isFalse);
      expect(
        rect.top > previous.top ||
            ((rect.top - previous.top).abs() < 1 &&
                rect.left >= previous.right),
        isTrue,
        reason: 'Days must read Monday through Sunday.',
      );
    }
    previous = rect;
  }
}

void _expectCitySectionsDoNotOverlap(WidgetTester tester, double width) {
  final rects = <String, Rect>{};
  for (final key in [
    'pico-city-change',
    'pico-city-category-segment',
    'pico-city-hero',
    'pico-city-week-card',
    'pico-city-source-row',
    'pico-city-vehicles-open',
  ]) {
    final finder = find.byKey(ValueKey(key));
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(0), reason: key);
    expect(rect.right, lessThanOrEqualTo(width), reason: key);
    for (final other in rects.entries) {
      expect(
        rect.overlaps(other.value),
        isFalse,
        reason: '$key overlaps ${other.key}',
      );
    }
    rects[key] = rect;
    _expectCompleteText(tester, finder);
  }
}

void _expectCompleteText(WidgetTester tester, Finder parent) {
  final parentRect = tester.getRect(parent);
  final paragraphs = find.descendant(
    of: parent,
    matching: find.byType(RichText),
  );
  final textRects = <Rect>[];
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    if (text.trim().isEmpty) continue;
    expect(paragraph.didExceedMaxLines, isFalse, reason: text);
    expect(paragraph.overflow, isNot(TextOverflow.ellipsis), reason: text);
    expect(
      paragraph.getMinIntrinsicHeight(paragraph.size.width),
      lessThanOrEqualTo(paragraph.size.height + 0.5),
      reason: text,
    );
    final origin = paragraph.localToGlobal(Offset.zero);
    final rect = origin & paragraph.size;
    expect(
      rect.left,
      greaterThanOrEqualTo(parentRect.left - 0.5),
      reason: text,
    );
    expect(rect.right, lessThanOrEqualTo(parentRect.right + 0.5), reason: text);
    for (final other in textRects) {
      expect(rect.overlaps(other), isFalse, reason: 'Text overlaps: $text');
    }
    textRects.add(rect);
    // Tight font boxes can extend above a line with a custom height. Use
    // intrinsic height vertically and visible glyphs (not trailing spaces)
    // horizontally, since wrapped lines may retain whitespace outside the box.
    final boxes = [
      for (final word in RegExp(r'\S+').allMatches(text))
        ...paragraph.getBoxesForSelection(
          TextSelection(baseOffset: word.start, extentOffset: word.end),
        ),
    ];
    expect(boxes, isNotEmpty, reason: text);
    for (final box in boxes) {
      expect(box.left, greaterThanOrEqualTo(-0.5), reason: text);
      expect(
        box.right,
        lessThanOrEqualTo(paragraph.size.width + 0.5),
        reason: text,
      );
    }
  }
}

void _expectCitySources(Finder sheet) {
  for (final url in [_cityOfficialSource, _cityOtherSource]) {
    expect(
      find.descendant(of: sheet, matching: find.text(url)),
      findsOneWidget,
    );
  }
  expect(
    find.descendant(
      of: sheet,
      matching: find.textContaining('Última verificación'),
    ),
    findsOneWidget,
  );
}

Future<Finder> _openCityVehicles(WidgetTester tester) async {
  final open = find.byKey(const ValueKey('pico-city-vehicles-open'));
  await tester.ensureVisible(open);
  await tester.tap(open);
  await tester.pumpAndSettle();
  final sheet = find.byKey(const ValueKey('pico-city-vehicles-sheet'));
  expect(sheet, findsOneWidget);
  return sheet;
}

Future<void> _captureCity(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('PICO_CITY_CAPTURE')) return;
  final context = tester.element(find.byType(PicoDetailScreen).first);
  final assets = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .toList();
  await tester.runAsync(() async {
    for (final asset in assets) {
      await precacheImage(asset, context);
    }
  });
  await tester.pumpAndSettle();
  for (final image in tester.widgetList<RawImage>(
    find.descendant(
      of: find.byKey(const ValueKey('pico-city-hero')),
      matching: find.byType(RawImage),
    ),
  )) {
    expect(
      image.image,
      isNotNull,
      reason: 'City capture assets must be decoded.',
    );
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../temp/PICO_CITY_OWNER_MOCKUP/automated/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _pumpCityPico(
  WidgetTester tester,
  TestAppHarness harness, {
  required RestrictionStore store,
  VehicleProfile? vehicle,
  List<VehicleProfile>? vehicles,
  Future<List<VehicleProfile>> Function()? loadVehicles,
  ValueNotifier<List<VehicleProfile>>? vehicleChanges,
  VehicleProfile? activeVehicle,
  GoRouter? router,
  String? transientJurisdictionId,
  Size viewportSize = const Size(390, 844),
  double textScaleFactor = 1,
  DateTime? now,
  ValueNotifier<DateTime>? clock,
  List<RestrictionJurisdiction>? jurisdictions,
}) async {
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final currentDate = now ?? DateTime(2026, 8, 31, 12);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        if (vehicle == null)
          picoJurisdictionCatalogProvider.overrideWith(
            (ref) async => PicoJurisdictionCatalog.fromJson(
              jsonDecode(
                File(picoJurisdictionCatalogAssetPath).readAsStringSync(),
              ) as Map<String, Object?>,
            ),
          ),
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async =>
              jurisdictions ??
              const [
                RestrictionJurisdiction(
                  id: 'co-ant-medellin',
                  name: 'Medellín',
                ),
                RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogotá'),
              ],
        ),
        vehicleListProvider.overrideWith((ref) async {
          if (loadVehicles != null) return loadVehicles();
          if (vehicleChanges != null) {
            vehicleChanges.addListener(ref.invalidateSelf);
            ref.onDispose(
              () => vehicleChanges.removeListener(ref.invalidateSelf),
            );
          }
          return vehicleChanges?.value ??
              vehicles ??
              (vehicle == null ? const [] : [vehicle]);
        }),
        activeVehicleProvider.overrideWith(
          (ref) async => activeVehicle ?? vehicle,
        ),
        restrictionStoreProvider.overrideWithValue(store),
        bogotaNowProvider.overrideWith((ref) {
          if (clock != null) {
            clock.addListener(ref.invalidateSelf);
            ref.onDispose(() => clock.removeListener(ref.invalidateSelf));
          }
          return clock?.value ?? currentDate;
        }),
        currentInstantProvider.overrideWith((ref) {
          final local = ref.watch(bogotaNowProvider);
          return DateTime.utc(
            local.year,
            local.month,
            local.day,
            local.hour + 5,
            local.minute,
          );
        }),
      ],
      child: router != null
          ? MaterialApp.router(routerConfig: router)
          : MaterialApp(
              home: PicoDetailScreen(
                vehicleId: vehicle?.id,
                jurisdictionId: transientJurisdictionId,
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

class _WeeklyRestrictionStore extends RestrictionStore {
  _WeeklyRestrictionStore(
    super.database, {
    this.windows,
    this.mondayWindows,
    this.sourceUrls = const [_cityOfficialSource],
  });

  final List<RestrictionTimeWindow>? windows;
  final List<RestrictionTimeWindow>? mondayWindows;
  final List<String> sourceUrls;

  final requestedJurisdictions = <String>[];

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    requestedJurisdictions.add(jurisdictionId);
    final motorcycle = vehicleKind == VehicleKind.motorcycle;
    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: false,
      staleAfter: DateTime.utc(2027),
      verifiedAt: DateTime.utc(2026, 8, 30),
      sourceUrls: sourceUrls,
      rules: [
        _rule(
          'monday',
          DateTime.monday,
          motorcycle ? {7, 9} : {5, 8},
          vehicleKind: vehicleKind,
          timeWindows: mondayWindows ?? windows,
        ),
        _rule(
          'tuesday',
          DateTime.tuesday,
          motorcycle ? {2, 4} : {1, 4},
          vehicleKind: vehicleKind,
          timeWindows: windows,
        ),
        _rule(
          'wednesday',
          DateTime.wednesday,
          motorcycle ? {1, 3, 5, 7, 9} : {0, 1, 2, 3, 4},
          vehicleKind: vehicleKind,
          timeWindows: windows,
        ),
      ],
    );
  }
}

class _DelayedRestrictionStore extends _WeeklyRestrictionStore {
  _DelayedRestrictionStore(super.database);

  Completer<void>? pending;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    final wait = pending;
    if (wait != null) await wait.future;
    return super.loadCoverage(jurisdictionId, vehicleKind, serviceType, now);
  }
}

class _SheetRestrictionStore extends _DelayedRestrictionStore {
  _SheetRestrictionStore(super.database, {this.expiresAt});

  final DateTime? expiresAt;
  int attempts = 0;
  bool fail = false;
  bool allowAll = false;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    attempts++;
    if (fail) throw StateError('Test coverage load failure');
    final base = await super.loadCoverage(
      jurisdictionId,
      vehicleKind,
      serviceType,
      now,
    );
    return RestrictionRuleSet(
      coverageKnown: base.coverageKnown,
      dataIsStale: expiresAt != null && !now.isBefore(expiresAt!),
      staleAfter: expiresAt ?? base.staleAfter,
      verifiedAt: base.verifiedAt,
      sourceUrls: base.sourceUrls,
      rules: allowAll ? const [] : base.rules,
    );
  }
}

class _DatedRestrictionStore extends _WeeklyRestrictionStore {
  _DatedRestrictionStore(super.database);

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    final base = await super.loadCoverage(
      jurisdictionId,
      vehicleKind,
      serviceType,
      now,
    );
    return RestrictionRuleSet(
      coverageKnown: base.coverageKnown,
      dataIsStale: base.dataIsStale,
      staleAfter: base.staleAfter,
      verifiedAt: base.verifiedAt,
      sourceUrls: base.sourceUrls,
      rules: [
        ...base.rules,
        RestrictionRule(
          id: 'september-first-only',
          jurisdictionId: jurisdictionId,
          priority: 200,
          effect: RestrictionEffect.restrict,
          validFrom: DateTime(2026, 9, 1),
          validUntil: DateTime(2026, 9, 1, 23, 59, 59),
          vehicleKinds: {vehicleKind},
          serviceTypes: {serviceType},
          digitPosition: RestrictionDigitPosition.lastNumeric,
          digits: const {6},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 300, endMinute: 1200),
          ],
          appliesOnHolidays: true,
        ),
      ],
    );
  }
}

class _NoCoverageStore extends RestrictionStore {
  _NoCoverageStore(super.database);

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    return const RestrictionRuleSet(
      coverageKnown: false,
      dataIsStale: false,
      rules: [],
    );
  }
}

class _StaleCoverageStore extends RestrictionStore {
  _StaleCoverageStore(super.database);

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    return const RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: true,
      rules: [],
    );
  }
}

class _HolidayRestrictionStore extends RestrictionStore {
  _HolidayRestrictionStore(super.database);

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: false,
      staleAfter: DateTime.utc(2027),
      rules: [
        _rule('holiday-exempt-monday', DateTime.monday, {
          5,
          8,
        }, appliesOnHolidays: false),
      ],
    );
  }
}

RestrictionRule _rule(
  String id,
  int weekday,
  Set<int> digits, {
  VehicleKind vehicleKind = VehicleKind.car,
  bool appliesOnHolidays = true,
  List<RestrictionTimeWindow>? timeWindows,
}) {
  return RestrictionRule(
    id: id,
    jurisdictionId: 'co-ant-medellin',
    priority: 100,
    effect: RestrictionEffect.restrict,
    validFrom: DateTime(2026, 8),
    validUntil: DateTime(2026, 12, 31, 23, 59, 59),
    vehicleKinds: {vehicleKind},
    serviceTypes: const {VehicleServiceType.private},
    weekdays: {weekday},
    digitPosition: RestrictionDigitPosition.lastNumeric,
    digits: digits,
    timeWindows:
        timeWindows ??
        const [RestrictionTimeWindow(startMinute: 300, endMinute: 1200)],
    appliesOnHolidays: appliesOnHolidays,
  );
}
