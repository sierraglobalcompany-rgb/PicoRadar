import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';
import 'package:picoradar/features/trip/presentation/trip_plan_result.dart';

void main() {
  final request = TripPlanRequest(
    requestId: 'test-request',
    origin: const TripMunicipality(code: '05001', municipality: 'Medellín', department: 'Antioquia'),
    destination: const TripMunicipality(code: '11001', municipality: 'Bogotá', department: 'Bogotá'),
    vehicle: VehicleProfile(id: 'local-only', plate: 'ABC123', kind: VehicleKind.car,
      serviceType: VehicleServiceType.private, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    departureUtc: DateTime.utc(2026, 9, 6, 4, 30),
    standardVehicleConfirmed: true,
  );
  TripRouteOption route(String id, TripTolls tolls, {int seconds = 7200}) => TripRouteOption(
    id: id, summary: 'Corredor $id', distanceMeters: 125500,
    durationSeconds: seconds, timeBasis: 'static', tolls: tolls,
  );
  TripPlan plan(List<TripRouteOption> routes) => TripPlan(
    requestId: request.requestId, generatedAtUtc: DateTime.utc(2026, 9, 5, 12),
    provider: 'Proveedor de prueba', attribution: 'Atribución de prueba',
    origin: const TripResolvedPoint(label: 'Referencia Medellín', latitude: 6.2, longitude: -75.5),
    destination: const TripResolvedPoint(label: 'Referencia Bogotá', latitude: 4.7, longitude: -74.1),
    routes: routes,
  );
  Future<void> pump(WidgetTester tester, List<TripRouteOption> routes, {double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = routes.first.id;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: StatefulBuilder(builder: (context, setState) => SingleChildScrollView(
        child: TripPlanResult(request: request, plan: plan(routes), selectedRouteId: selected,
          onRouteSelected: (id) => setState(() => selected = id), onSource: (_) {}),
      )),
    ))));
  }

  testWidgets('route selection binds toll details and next-day Bogota arrival', (tester) async {
    final routes = [
      route('a', TripTolls(coverage: TripTollCoverage.complete, vehicleCategory: 'car', totalMinor: 2400000,
        charges: const [TripTollCharge(name: 'Estación A', amountMinor: 1200000), TripTollCharge(name: 'Estación A', amountMinor: 1200000)])),
      route('b', TripTolls(coverage: TripTollCoverage.partial, vehicleCategory: 'car', subtotalMinor: 500000, missingRates: 1,
        charges: const [TripTollCharge(name: 'Estación B', amountMinor: 500000), TripTollCharge(name: 'Sin tarifa')]), seconds: 10800),
    ];
    await pump(tester, routes);
    expect(find.textContaining('2026-09-06 01:30'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('trip-toll-details-a')));
    await tester.tap(find.byKey(const ValueKey('trip-toll-details-a')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Estación A'), findsNWidgets(2));
    await tester.ensureVisible(find.byKey(const ValueKey('trip-select-route-b')));
    await tester.tap(find.byKey(const ValueKey('trip-select-route-b')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-toll-details-a')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('trip-toll-details-b')));
    await tester.tap(find.byKey(const ValueKey('trip-toll-details-b')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Estación B'), findsOneWidget);
    expect(find.textContaining('Estación A'), findsNothing);
    expect(find.textContaining('Subtotal conocido'), findsWidgets);
  });

  testWidgets('unknown cannot win cheapest and empty unknown is not zero', (tester) async {
    await pump(tester, [
      route('unknown', TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car')),
      route('paid', TripTolls(coverage: TripTollCoverage.complete, vehicleCategory: 'car', totalMinor: 1200000,
        charges: const [TripTollCharge(name: 'Peaje', amountMinor: 1200000)])),
    ]);
    final unknown = find.byKey(const ValueKey('trip-route-unknown'));
    expect(find.descendant(of: unknown, matching: find.textContaining('Menor costo')), findsNothing);
    expect(find.descendant(of: unknown, matching: find.textContaining('COP 0')), findsNothing);
    expect(find.descendant(of: unknown, matching: find.textContaining('0 peajes')), findsNothing);
    expect(find.textContaining('Menor costo de peajes'), findsNothing);
  });

  for (final coverage in TripTollCoverage.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('toll coverage $coverage at scale $scale stays truthful and fits', (tester) async {
        await pump(tester, [route('one', TripTolls(coverage: coverage, vehicleCategory: 'motorcycle',
          totalMinor: coverage == TripTollCoverage.complete ? 1200000 : coverage == TripTollCoverage.noChargeConfirmed ? 0 : null,
          subtotalMinor: coverage == TripTollCoverage.partial ? 1200000 : null,
          missingRates: coverage == TripTollCoverage.partial ? 1 : 0,
          charges: coverage == TripTollCoverage.complete || coverage == TripTollCoverage.partial
            ? const [TripTollCharge(name: 'Estación con nombre largo para comprobar ajuste de texto', amountMinor: 1200000)] : const []))], scale: scale);
        await tester.ensureVisible(find.byKey(const ValueKey('trip-toll-details-one')));
        await tester.tap(find.byKey(const ValueKey('trip-toll-details-one')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (coverage == TripTollCoverage.noChargeConfirmed) expect(find.textContaining('Sin cobro confirmado'), findsWidgets);
        if (coverage == TripTollCoverage.unsupportedVehicle) expect(find.textContaining('Categoría no soportada'), findsWidgets);
      });
    }
  }
}
