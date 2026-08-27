import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

import '../../../test_app_harness.dart';

void main() {
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  testWidgets('sin vehículo muestra bienvenida', (tester) async {
    await _pumpHome(tester, harness);

    expect(
      find.text('Tu vehículo, tus alertas y tu ruta en un solo lugar.'),
      findsOneWidget,
    );
  });

  testWidgets('vehículo sin jurisdicción muestra selector', (tester) async {
    await _createVehicle(harness, plate: 'ABC123');

    await _pumpHome(tester, harness);

    expect(find.text('¿Dónde vas a conducir?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-jurisdiction-selector')),
      findsOneWidget,
    );
  });

  testWidgets('particular Medellín restricted', (tester) async {
    await _readyHome(
      harness,
      plate: 'ABC123',
      jurisdictionId: 'co-ant-medellin',
    );

    await _pumpHome(tester, harness);

    expect(find.text('HOY TIENES PICO Y PLACA'), findsOneWidget);
  });

  testWidgets('particular Medellín allowed', (tester) async {
    await _readyHome(
      harness,
      plate: 'ABC124',
      jurisdictionId: 'co-ant-medellin',
    );

    await _pumpHome(tester, harness);

    expect(find.text('HOY PUEDES CIRCULAR'), findsOneWidget);
  });

  testWidgets('moto Medellín uses firstNumeric', (tester) async {
    await _readyHome(
      harness,
      plate: 'A3B999',
      kind: VehicleKind.motorcycle,
      jurisdictionId: 'co-ant-medellin',
    );

    await _pumpHome(tester, harness);

    expect(find.text('HOY TIENES PICO Y PLACA'), findsOneWidget);
  });

  testWidgets('taxi Bogotá restricted', (tester) async {
    await _readyHome(
      harness,
      plate: 'TAX056',
      serviceType: VehicleServiceType.taxi,
      jurisdictionId: 'co-dc-bogota',
    );

    await _pumpHome(tester, harness);

    expect(find.text('HOY TIENES PICO Y PLACA'), findsOneWidget);
    expect(find.textContaining('05:30 - 21:00'), findsOneWidget);
  });

  testWidgets('taxi Bogotá allowed', (tester) async {
    await _readyHome(
      harness,
      plate: 'TAX123',
      serviceType: VehicleServiceType.taxi,
      jurisdictionId: 'co-dc-bogota',
    );

    await _pumpHome(tester, harness);

    expect(find.text('HOY PUEDES CIRCULAR'), findsOneWidget);
  });

  testWidgets('taxi Medellín is unknown', (tester) async {
    await _readyHome(
      harness,
      plate: 'TAX123',
      serviceType: VehicleServiceType.taxi,
      jurisdictionId: 'co-ant-medellin',
    );

    await _pumpHome(tester, harness);

    expect(find.text('NO PODEMOS CONFIRMAR TU PICO Y PLACA'), findsOneWidget);
    expect(find.text('HOY PUEDES CIRCULAR'), findsNothing);
  });

  testWidgets('stale nunca muestra allowed', (tester) async {
    harness.now = DateTime(2026, 9);
    await _readyHome(harness, plate: 'ABC128', jurisdictionId: 'co-dc-bogota');

    await _pumpHome(tester, harness);

    expect(find.text('DATOS PENDIENTES DE ACTUALIZACIÓN'), findsOneWidget);
    expect(find.text('HOY PUEDES CIRCULAR'), findsNothing);
  });

  testWidgets('missing coverage nunca muestra allowed', (tester) async {
    await _readyHome(
      harness,
      plate: 'TAX456',
      serviceType: VehicleServiceType.taxi,
      jurisdictionId: 'co-ant-medellin',
    );

    await _pumpHome(tester, harness);

    expect(find.text('NO PODEMOS CONFIRMAR TU PICO Y PLACA'), findsOneWidget);
    expect(find.text('HOY PUEDES CIRCULAR'), findsNothing);
  });

  testWidgets('tomorrow uses next day evaluation', (tester) async {
    await _readyHome(
      harness,
      plate: 'TAX078',
      serviceType: VehicleServiceType.taxi,
      jurisdictionId: 'co-dc-bogota',
    );

    await _pumpHome(tester, harness);

    expect(find.text('Tienes Pico y Placa'), findsOneWidget);
  });

  testWidgets('pico detail shows próximos 7 días', (tester) async {
    await _readyHome(
      harness,
      plate: 'TAX078',
      serviceType: VehicleServiceType.taxi,
      jurisdictionId: 'co-dc-bogota',
    );

    await _pumpDetail(tester, harness);

    expect(find.text('Próximos 7 días'), findsOneWidget);
    expect(find.text('Fuente oficial: bogota.gov.co'), findsOneWidget);
  });

  testWidgets('festivo Bogotá no aplica cuando la regla lo define', (
    tester,
  ) async {
    harness.now = DateTime(2026, 8, 7, 12);
    await _readyHome(harness, plate: 'ABC128', jurisdictionId: 'co-dc-bogota');

    await _pumpHome(tester, harness);

    expect(find.text('HOY PUEDES CIRCULAR'), findsOneWidget);
  });

  testWidgets('active vehicle changes Home', (tester) async {
    final first = await _createVehicle(harness, plate: 'ABC123');
    final second = await _createVehicle(harness, plate: 'ABC124');
    await harness.repository.setActiveVehicle(first.id);
    await harness.preferences.setString(
      picoJurisdictionPreferenceKey,
      'co-ant-medellin',
    );

    await _pumpHome(tester, harness);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('HOY TIENES PICO Y PLACA'), findsOneWidget);

    await harness.repository.setActiveVehicle(second.id);
    await _pumpHome(tester, harness);

    expect(find.text('ABC124'), findsOneWidget);
    expect(find.text('HOY PUEDES CIRCULAR'), findsOneWidget);
  });
}

Future<void> _pumpHome(WidgetTester tester, TestAppHarness harness) async {
  await _pump(tester, harness, const Scaffold(body: HomeScreen()));
}

Future<void> _pumpDetail(WidgetTester tester, TestAppHarness harness) async {
  await _pump(tester, harness, const PicoDetailScreen());
}

Future<void> _pump(
  WidgetTester tester,
  TestAppHarness harness,
  Widget child,
) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('co.picoradar.app/widget'),
        (_) async => null,
      );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await harness.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('co.picoradar.app/widget'),
          null,
        );
  });
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async => _jurisdictions,
        ),
        restrictionStoreProvider.overrideWithValue(
          _FakeRestrictionStore(harness.database, harness.now),
        ),
        bogotaNowProvider.overrideWithValue(harness.now),
      ],
      child: MaterialApp(home: child),
    ),
  );
  for (var i = 0; i < 5; i += 1) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _readyHome(
  TestAppHarness harness, {
  required String plate,
  required String jurisdictionId,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
}) async {
  final vehicle = await _createVehicle(
    harness,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
  );
  await harness.repository.setActiveVehicle(vehicle.id);
  await harness.preferences.setString(
    picoJurisdictionPreferenceKey,
    jurisdictionId,
  );
}

const _jurisdictions = [
  RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogotá'),
  RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellín'),
];

class _FakeRestrictionStore extends RestrictionStore {
  _FakeRestrictionStore(super.database, this.now);

  final DateTime now;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    if (jurisdictionId == 'co-ant-medellin' &&
        serviceType == VehicleServiceType.taxi) {
      return const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      );
    }

    final stale = this.now.isAfter(DateTime(2026, 8, 31, 23, 59));
    if (jurisdictionId == 'co-ant-medellin') {
      return RestrictionRuleSet(
        coverageKnown: true,
        dataIsStale: stale,
        rules: [
          _rule(
            id: 'medellin-particular-thursday',
            jurisdictionId: jurisdictionId,
            vehicleKinds: {vehicleKind},
            serviceTypes: {serviceType},
            weekdays: {DateTime.thursday},
            digitPosition: vehicleKind == VehicleKind.motorcycle
                ? RestrictionDigitPosition.firstNumeric
                : RestrictionDigitPosition.lastNumeric,
            digits: {3},
          ),
        ],
        verifiedAt: DateTime(2026, 8, 1),
        sourceUrls: const ['https://www.medellin.gov.co/source'],
      );
    }

    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: stale,
      rules: [
        _rule(
          id: 'bogota-private-thursday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.private},
          weekdays: {DateTime.thursday},
          digits: {3},
          appliesOnHolidays: false,
        ),
        _rule(
          id: 'bogota-taxi-thursday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.taxi},
          weekdays: {DateTime.thursday},
          digits: {5, 6},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 330, endMinute: 1260),
          ],
        ),
        _rule(
          id: 'bogota-taxi-friday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.taxi},
          weekdays: {DateTime.friday},
          digits: {7, 8},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 330, endMinute: 1260),
          ],
        ),
      ],
      verifiedAt: DateTime(2026, 8, 1),
      sourceUrls: const ['https://bogota.gov.co/source'],
    );
  }
}

RestrictionRule _rule({
  required String id,
  required String jurisdictionId,
  required Set<VehicleKind> vehicleKinds,
  required Set<VehicleServiceType> serviceTypes,
  required Set<int> weekdays,
  required Set<int> digits,
  RestrictionDigitPosition digitPosition = RestrictionDigitPosition.lastNumeric,
  List<RestrictionTimeWindow> timeWindows = const [
    RestrictionTimeWindow(startMinute: 360, endMinute: 1260),
  ],
  bool appliesOnHolidays = true,
}) {
  return RestrictionRule(
    id: id,
    jurisdictionId: jurisdictionId,
    priority: 100,
    effect: RestrictionEffect.restrict,
    validFrom: DateTime(2026, 8),
    validUntil: DateTime(2026, 8, 31),
    vehicleKinds: vehicleKinds,
    serviceTypes: serviceTypes,
    weekdays: weekdays,
    digitPosition: digitPosition,
    digits: digits,
    timeWindows: timeWindows,
    appliesOnHolidays: appliesOnHolidays,
  );
}

Future<VehicleProfile> _createVehicle(
  TestAppHarness harness, {
  required String plate,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
}) {
  return harness.repository.createVehicle(
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    registrationCity: 'Bogota',
  );
}
