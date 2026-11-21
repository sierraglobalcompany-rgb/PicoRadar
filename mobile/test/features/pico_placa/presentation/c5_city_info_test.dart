import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';

import '../../../plate_test_fonts.dart';
import '../../../test_app_harness.dart';

const _initialCityId = 'c5-initial-city';
const _availableCityId = 'c5-available-city';
const _upcomingCityId = 'c5-upcoming-city';
const _initialCityName = 'Ciudad inicial de prueba';
const _availableCityName = 'Ciudad disponible de prueba';
const _upcomingCityName = 'Ciudad próxima de prueba';
const _upcomingDepartment = 'Departamento de prueba';

void main() {
  setUpAll(loadPlateTestFonts);

  late TestAppHarness harness;
  late VehicleProfile vehicle;

  setUp(() async {
    harness = TestAppHarness();
    await harness.preferences.setString(
      picoJurisdictionPreferenceKey,
      _initialCityId,
    );
    vehicle = await harness.repository.createVehicle(
      plate: 'ABC125',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: _initialCityName,
    );
    await harness.repository.setActiveVehicle(vehicle.id);
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets(
    'upcoming city opens accessible information without selecting or networking',
    (tester) async {
      final previousHttpOverrides = HttpOverrides.current;
      final httpBlocker = _HttpCallBlocker();
      HttpOverrides.global = httpBlocker;
      addTearDown(() => HttpOverrides.global = previousHttpOverrides);
      final store = _SyntheticRestrictionStore(
        harness.database,
        states: const {},
      );
      await _pumpCityScreen(tester, harness, store: store);

      await tester.tap(find.byKey(const ValueKey('pico-city-change')));
      await tester.pumpAndSettle();
      final option = find.byKey(
        const ValueKey('pico-city-option-$_upcomingCityId'),
      );
      await tester.ensureVisible(option);
      final optionSemantics = tester.getSemantics(option);
      expect(optionSemantics.label, contains(_upcomingCityName));
      expect(optionSemantics.label, contains(_upcomingDepartment));
      expect(optionSemantics.label, contains('Consulta no disponible'));

      await tester.tap(option);
      await tester.pumpAndSettle();
      final infoSheet = find.byKey(
        const ValueKey('pico-city-info-sheet-$_upcomingCityId'),
      );
      expect(infoSheet, findsOneWidget);
      expect(
        find.descendant(of: infoSheet, matching: find.text(_upcomingCityName)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: infoSheet,
          matching: find.text(_upcomingDepartment),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: infoSheet,
          matching: find.text('Consulta no disponible'),
        ),
        findsOneWidget,
      );
      const uncertainty =
          'No hay información verificada para determinar si tiene restricción.';
      expect(find.text(uncertainty), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('pico-city-info-close-$_upcomingCityId')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pico-city-selector')), findsOneWidget);

      final selector = find.byKey(const ValueKey('pico-city-selector'));
      Navigator.of(tester.element(selector)).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pico-city-info-sheet-$_upcomingCityId')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('pico-city-hero')), findsOneWidget);
      final citySemantics = tester
          .getSemantics(
            find.byKey(const ValueKey('pico-city-status-semantics')),
          )
          .label;
      expect(citySemantics, contains(_initialCityName));
      final storedCity = await harness.preferences.getString(
        picoJurisdictionPreferenceKey,
      );
      expect(storedCity, _initialCityId);
      final storedVehicle = await tester.runAsync(
        harness.repository.getActiveVehicle,
      );
      expect(storedVehicle?.id, vehicle.id);
      expect(httpBlocker.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('available city selection keeps its existing behavior', (
    tester,
  ) async {
    final store = _SyntheticRestrictionStore(
      harness.database,
      states: const {},
    );
    await _pumpCityScreen(tester, harness, store: store);

    await tester.tap(find.byKey(const ValueKey('pico-city-change')));
    await tester.pumpAndSettle();
    final option = find.byKey(
      const ValueKey('pico-city-option-$_availableCityId'),
    );
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pico-city-selector')), findsNothing);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('pico-city-status-semantics')),
          )
          .label,
      contains(_availableCityName),
    );
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      _initialCityId,
    );
    final selectedVehicle = await tester.runAsync(
      harness.repository.getActiveVehicle,
    );
    expect(selectedVehicle?.id, vehicle.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UNKNOWN and STALE city results never announce permission', (
    tester,
  ) async {
    const cases = <(_CoverageState, String)>[
      (_CoverageState.unknown, 'Por verificar'),
      (_CoverageState.stale, 'Datos vencidos'),
    ];

    for (final (state, visibleStatus) in cases) {
      final store = _SyntheticRestrictionStore(
        harness.database,
        states: {_initialCityId: state},
      );
      await _pumpCityScreen(
        tester,
        harness,
        store: store,
        scopeKey: state.name,
      );
      final hero = find.byKey(const ValueKey('pico-city-hero'));
      expect(
        find.descendant(of: hero, matching: find.text(visibleStatus)),
        findsOneWidget,
      );
      final announcement = tester
          .getSemantics(
            find.byKey(const ValueKey('pico-city-status-semantics')),
          )
          .label;
      expect(announcement, contains(visibleStatus));
      expect(announcement, isNot(contains('Sin restricción hoy')));
      expect(announcement, isNot(contains('Puede circular')));
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpCityScreen(
  WidgetTester tester,
  TestAppHarness harness, {
  required _SyntheticRestrictionStore store,
  String scopeKey = 'default',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey('c5-city-info-$scopeKey'),
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        picoJurisdictionCatalogProvider.overrideWith((ref) async => _catalog),
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async => const [
            RestrictionJurisdiction(
              id: _initialCityId,
              name: _initialCityName,
              consultationEnabled: true,
            ),
            RestrictionJurisdiction(
              id: _availableCityId,
              name: _availableCityName,
              consultationEnabled: true,
            ),
          ],
        ),
        selectedPicoJurisdictionIdProvider.overrideWith(
          (ref) async => _initialCityId,
        ),
        restrictionStoreProvider.overrideWithValue(store),
        currentInstantProvider.overrideWithValue(
          DateTime.utc(2026, 11, 20, 17),
        ),
        bogotaNowProvider.overrideWithValue(DateTime(2026, 11, 20, 12)),
      ],
      child: const MaterialApp(home: PicoDetailScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

final _catalog = PicoJurisdictionCatalog(
  records: [
    PicoJurisdictionCatalogEntry(
      id: _initialCityId,
      name: _initialCityName,
      department: 'Departamento inicial',
      classification: 'SUPPORTED_CURRENT',
      sourceDate: '2026-11-20',
      status: PicoOperationalStatus.verified,
      engineEnabled: true,
      engineJurisdictionId: _initialCityId,
    ),
    PicoJurisdictionCatalogEntry(
      id: _availableCityId,
      name: _availableCityName,
      department: 'Departamento disponible',
      classification: 'SUPPORTED_CURRENT',
      sourceDate: '2026-11-20',
      status: PicoOperationalStatus.verified,
      engineEnabled: true,
      engineJurisdictionId: _availableCityId,
    ),
    PicoJurisdictionCatalogEntry(
      id: _upcomingCityId,
      name: _upcomingCityName,
      department: _upcomingDepartment,
      classification: 'PENDING',
      sourceDate: '2026-11-20',
      status: PicoOperationalStatus.pending,
    ),
  ],
);

enum _CoverageState { unknown, stale }

class _SyntheticRestrictionStore extends RestrictionStore {
  _SyntheticRestrictionStore(super.database, {required this.states});

  final Map<String, _CoverageState> states;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    if (states[jurisdictionId] == _CoverageState.stale) {
      return RestrictionRuleSet(
        coverageKnown: true,
        dataIsStale: true,
        coverageCompleteness: CoverageCompleteness.complete,
        jurisdictionName: jurisdictionId == _initialCityId
            ? _initialCityName
            : _availableCityName,
        verifiedAt: DateTime(2026, 11, 1),
        staleAfter: DateTime(2026, 11, 19),
        sourceUrls: const ['https://movilidad.example.test/pico'],
        rules: const [],
      );
    }
    return const RestrictionRuleSet(
      coverageKnown: false,
      dataIsStale: false,
      rules: [],
    );
  }
}

class _HttpCallBlocker extends HttpOverrides {
  int requests = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    requests++;
    throw StateError('HTTP must not run while showing local city information.');
  }
}
