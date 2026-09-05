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

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
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
        selectedPicoJurisdictionIdProvider.overrideWith(
          (ref) async => 'co-ant-medellin',
        ),
        vehicleListProvider.overrideWith(
          (ref) async => vehicle == null ? const [] : [vehicle],
        ),
        activeVehicleProvider.overrideWith((ref) async => vehicle),
        restrictionStoreProvider.overrideWithValue(store),
        bogotaNowProvider.overrideWithValue(currentDate),
        currentInstantProvider.overrideWithValue(currentDate.toUtc()),
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
  _WeeklyRestrictionStore(super.database);

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
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
        ),
        _rule(
          'tuesday',
          DateTime.tuesday,
          motorcycle ? {2, 4} : {1, 4},
          vehicleKind: vehicleKind,
        ),
        _rule(
          'wednesday',
          DateTime.wednesday,
          motorcycle ? {1, 3, 5, 7, 9} : {0, 1, 2, 3, 4},
          vehicleKind: vehicleKind,
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
    timeWindows: const [
      RestrictionTimeWindow(startMinute: 300, endMinute: 1200),
    ],
    appliesOnHolidays: appliesOnHolidays,
  );
}
