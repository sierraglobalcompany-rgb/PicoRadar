import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';

import '../../../test_app_harness.dart';

void main() {
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

  for (final scenario in [
    (hour: 4, minute: 59, label: 'Empieza a las 5:00 a. m.'),
    (hour: 5, minute: 0, label: 'No puede circular'),
    (hour: 12, minute: 0, label: 'No puede circular'),
    (hour: 19, minute: 59, label: 'No puede circular'),
    (hour: 20, minute: 0, label: 'Restricción finalizada'),
    (hour: 21, minute: 0, label: 'Restricción finalizada'),
  ]) {
    testWidgets(
      'personal daily and instant states at ${scenario.hour}:${scenario.minute}',
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

        final hero = find.byKey(const ValueKey('pico-personal-screen'));
        expect(
          find.descendant(of: hero, matching: find.text('Pico y placa hoy')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: hero,
            matching: find.text('Hoy tienes pico y placa'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: hero,
            matching: find.text('5:00 a. m. – 8:00 p. m.'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: hero, matching: find.text('No puede circular')),
          findsNothing,
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('pico-immediate-verdict')),
              )
              .data,
          scenario.label,
        );
        expect(find.text('Hoy · Lun 31/08/2026'), findsOneWidget);
        expect(find.text('Próxima restricción'), findsOneWidget);
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
    (hour: 6, label: 'No puede circular'),
    (hour: 12, label: 'Sin restricción ahora'),
    (hour: 17, label: 'No puede circular'),
    (hour: 21, label: 'Restricción finalizada'),
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
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pico-immediate-verdict')))
            .data,
        scenario.label,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pico-personal-screen')),
          matching: find.text(
            '5:00 a. m. – 8:00 a. m.\n4:00 p. m. – 8:00 p. m.',
          ),
        ),
        findsOneWidget,
      );
      if (scenario.hour == 12) {
        expect(find.text('Vuelve a empezar a las 4:00 p. m.'), findsOneWidget);
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
            .widget<Text>(find.byKey(const ValueKey('pico-immediate-verdict')))
            .data,
        switch (status) {
          'unknown' => 'Por verificar',
          'stale' => 'Datos vencidos',
          _ => 'Sin pico y placa hoy',
        },
      );
      expect(find.text('Hoy · Lun 31/08/2026'), findsOneWidget);
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
    expect(find.text('Empieza a las 5:00 a. m.'), findsOneWidget);
    final requestCount = store.requestedJurisdictions.length;
    clock.value = DateTime(2026, 8, 31, 5);
    await tester.pumpAndSettle();
    expect(find.text('No puede circular'), findsOneWidget);
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
            .widget<Text>(find.byKey(const ValueKey('pico-immediate-verdict')))
            .data,
        'Sin pico y placa hoy',
      );
      store.pending = Completer<void>();
      clock.value = DateTime(2026, 9, 1);
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pico-immediate-verdict')))
            .data,
        'Por verificar',
      );
      expect(find.text('Hoy · Mar 01/09/2026'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pico-calendar-day-1')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      store.pending!.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pico-immediate-verdict')))
            .data,
        'Empieza a las 5:00 a. m.',
      );
      expect(find.text('Hoy tienes pico y placa'), findsOneWidget);
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
        await tester.tap(find.text('Mes'));
        await tester.pumpAndSettle();
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
        expect(find.text('Hoy · Mar 01/09/2026'), findsOneWidget);
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
      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
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
            .widget<Text>(find.byKey(const ValueKey('pico-immediate-verdict')))
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
      find.descendant(of: hero, matching: find.text('No puedes circular')),
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
      find.descendant(of: hero, matching: find.text('Sin confirmar')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('Puedes circular')),
      findsNothing,
    );
    expect(
      find.descendant(of: hero, matching: find.text('No puedes circular')),
      findsNothing,
    );
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-ant-medellin',
    );
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: hero, matching: find.text('Puedes circular')),
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
          find.descendant(of: hero, matching: find.text('No puedes circular')),
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
          find.descendant(of: hero, matching: find.text('Sin confirmar')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: hero, matching: find.text('Puedes circular')),
          findsNothing,
        );
        expect(
          find.descendant(of: hero, matching: find.text('No puedes circular')),
          findsNothing,
        );
        store.pending!.complete();
        await tester.pumpAndSettle();
        expect(store.requestedJurisdictions.length, requestCount + 3);
        expect(
          find.descendant(
            of: hero,
            matching: find.text(
              'Restringidos: ${change == 'date' ? '2 · 4' : '7 · 9'}',
              findRichText: true,
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [360.0, 390.0, 412.0]) {
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
          final metrics = find.byKey(
            const ValueKey('pico-personal-status-grid'),
          );
          await tester.ensureVisible(metrics);
          await tester.pumpAndSettle();
          final hours = find.descendant(
            of: metrics,
            matching: find.text(
              '5:00 a. m. – 8:00 a. m.\n4:00 p. m. – 8:00 p. m.',
            ),
          );
          final hoursText = tester.widget<Text>(hours);
          expect(hoursText.maxLines, isNull);
          expect(hoursText.overflow, isNot(TextOverflow.ellipsis));
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('pico-immediate-verdict')),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('pico-immediate-verdict')),
                )
                .maxLines,
            isNull,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('pico-personal-calendar')),
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
    expect(find.byKey(const ValueKey('pico-city-adopt')), findsOneWidget);
    expect(store.requestedJurisdictions, isNotEmpty);
    expect(store.requestedJurisdictions, everyElement('co-dc-bogota'));
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-ant-medellin',
    );
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
    'city composition places current rotation before how it applies',
    (tester) async {
      await _pumpCityPico(
        tester,
        harness,
        store: _WeeklyRestrictionStore(harness.database),
        viewportSize: const Size(390, 1400),
      );

      final rotationY = tester
          .getTopLeft(find.byKey(const ValueKey('pico-city-rotation-card')))
          .dy;
      final appliesY = tester
          .getTopLeft(find.byKey(const ValueKey('pico-city-rule-summary-card')))
          .dy;

      expect(rotationY, lessThan(appliesY));
    },
  );

  testWidgets('week shows restricted digits evaluated independently per day', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _WeeklyRestrictionStore(harness.database),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-city-week-list')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pico-city-week-day-0')),
        matching: find.text('5 · 8'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pico-city-week-day-1')),
        matching: find.text('1 · 4'),
      ),
      findsOneWidget,
    );
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
      find.byKey(const ValueKey('pico-city-week-list')),
      260,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pico-city-week-day-0')),
        matching: find.text('7 · 9'),
      ),
      findsOneWidget,
    );
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
      find.byKey(const ValueKey('pico-city-week-list')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final holiday = find.byKey(const ValueKey('pico-city-week-day-0'));

    expect(
      find.descendant(of: holiday, matching: find.text('Libre')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: holiday, matching: find.text('5 · 8')),
      findsNothing,
    );
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
      find.byKey(const ValueKey('pico-city-week-list')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final monday = find.byKey(const ValueKey('pico-city-week-day-0'));
    expect(
      find.descendant(
        of: monday,
        matching: find.text('Sin información vigente'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monday, matching: find.text('Libre')),
      findsNothing,
    );
  });

  testWidgets('stale week uses the same no-data truth as missing coverage', (
    tester,
  ) async {
    await _pumpCityPico(
      tester,
      harness,
      store: _StaleCoverageStore(harness.database),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-city-week-list')),
      260,
      scrollable: find.byType(Scrollable).first,
    );

    final monday = find.byKey(const ValueKey('pico-city-week-day-0'));
    expect(
      find.descendant(
        of: monday,
        matching: find.text('Sin información vigente'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monday, matching: find.text('Libre')),
      findsNothing,
    );
  });

  for (final viewport in const [
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
  ]) {
    for (final textScale in const [1.0, 1.5, 2.0]) {
      testWidgets(
        'week and source do not truncate at ${viewport.width.toInt()}x'
        '${viewport.height.toInt()} scale $textScale',
        (tester) async {
          await _pumpCityPico(
            tester,
            harness,
            store: _WeeklyRestrictionStore(harness.database),
            viewportSize: viewport,
            textScaleFactor: textScale,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('pico-city-week-list')),
            260,
            scrollable: find.byType(Scrollable).first,
          );
          final fiveDigits = tester.widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('pico-city-week-day-2')),
              matching: find.text('0 · 1 · 2 · 3 · 4'),
            ),
          );
          expect(fiveDigits.overflow, isNot(TextOverflow.ellipsis));
          expect(tester.takeException(), isNull);

          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('pico-official-source-block')),
            260,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final source = tester.widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('pico-official-source-block')),
              matching: find.textContaining(
                'Fuente oficial: secretaria-de-movilidad.medellin.gov.co',
              ),
            ),
          );
          expect(source.overflow, isNot(TextOverflow.ellipsis));
          expect(tester.takeException(), isNull);
        },
      );

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
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('pico-city-week-list')),
            260,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();

          final copy = tester.widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('pico-city-week-day-0')),
              matching: find.text('Sin información vigente'),
            ),
          );
          expect(copy.overflow, isNot(TextOverflow.ellipsis));
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

      expect(find.text('MI PICO Y PLACA'), findsOneWidget);
      expect(find.text(vehicle.plate), findsOneWidget);
      expect(find.text('Pico y placa de la ciudad'), findsNothing);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
      expect((await harness.repository.getActiveVehicle())?.id, vehicle.id);
    },
  );
}

Future<void> _pumpCityPico(
  WidgetTester tester,
  TestAppHarness harness, {
  required RestrictionStore store,
  VehicleProfile? vehicle,
  String? transientJurisdictionId,
  Size viewportSize = const Size(390, 844),
  double textScaleFactor = 1,
  DateTime? now,
  ValueNotifier<DateTime>? clock,
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
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async => const [
            RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellín'),
            RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogotá'),
          ],
        ),
        vehicleListProvider.overrideWith(
          (ref) async => vehicle == null ? const [] : [vehicle],
        ),
        activeVehicleProvider.overrideWith((ref) async => vehicle),
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
      child: MaterialApp(
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
  _WeeklyRestrictionStore(super.database, {this.windows});

  final List<RestrictionTimeWindow>? windows;

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
      sourceUrls: const [
        'https://secretaria-de-movilidad.medellin.gov.co/fuente-oficial/',
      ],
      rules: [
        _rule(
          'monday',
          DateTime.monday,
          motorcycle ? {7, 9} : {5, 8},
          vehicleKind: vehicleKind,
          timeWindows: windows,
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
