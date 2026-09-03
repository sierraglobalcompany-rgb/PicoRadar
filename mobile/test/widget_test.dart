import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:picoradar/app/router/app_routes.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';

import 'test_app_harness.dart';

void main() {
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('tabs are fixed in the approved C01 order', () {
    expect(AppTab.values.map((tab) => tab.label), [
      'Inicio',
      'Garaje',
      'Apps',
      'Viaje',
      'Conducir',
    ]);
    expect(AppTab.values, hasLength(5));
    expect(AppTab.values.indexOf(AppTab.apps), 2);
    expect(AppTab.values[1].label, 'Garaje');
  });

  test('canonical pico deep links redirect into shell branches', () {
    expect(picoCompatibilityLocation(Uri.parse('/pico')), '/apps/pico');
    expect(
      picoCompatibilityLocation(Uri.parse('/pico?vehicleId=vehicle-b')),
      '/home/pico?vehicleId=vehicle-b',
    );
    expect(
      picoCompatibilityLocation(
        Uri.parse('/pico?origin=garage&vehicleId=vehicle-b'),
      ),
      '/garage/pico?vehicleId=vehicle-b',
    );
    expect(
      picoCompatibilityLocation(
        Uri.parse('/pico?origin=apps&vehicleId=vehicle-b&jurisdictionId=city'),
      ),
      '/apps/pico?vehicleId=vehicle-b&jurisdictionId=city',
    );
  });

  testWidgets('renders the five-tab shell at the home root', (tester) async {
    await harness.pump(tester);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byKey(const ValueKey('app-bottom-navigation')), findsOneWidget);
    expect(find.text('Inicio'), findsAtLeastNWidgets(1));
    expect(find.text('Garaje'), findsAtLeastNWidgets(1));
    expect(find.text('Apps'), findsAtLeastNWidgets(1));
    expect(find.text('Viaje'), findsAtLeastNWidgets(1));
    expect(find.text('Conducir'), findsAtLeastNWidgets(1));
    expect(find.byKey(const ValueKey('home-empty-state')), findsOneWidget);
    expect(find.text('No tienes vehículos todavía'), findsOneWidget);
  });

  testWidgets('bottom navigation opens each root tab', (tester) async {
    await harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('tab-garage')));
    await tester.pumpAndSettle();
    expect(find.text('No tienes vehículos todavía'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('apps-launcher-primary-grid')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-trip')));
    await tester.pumpAndSettle();
    expect(find.text('Planeacion de ruta sin mapa propio.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-drive')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('start-driving')), findsOneWidget);
  });

  testWidgets('indexed stack preserves branch state', (tester) async {
    await harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('tab-trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('state-button-trip')));
    await tester.pumpAndSettle();
    expect(find.text('Estado local 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('apps-launcher-primary-grid')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('tab-trip')));
    await tester.pumpAndSettle();
    expect(find.text('Estado local 1'), findsOneWidget);
  });

  testWidgets('home does not show the scaffold immersive action', (
    tester,
  ) async {
    await harness.pump(tester);
    await tester.tap(find.byKey(const ValueKey('tab-home')));
    await tester.pump();

    expect(find.byKey(const ValueKey('app-bottom-navigation')), findsOneWidget);
    expect(find.text('Probar ruta inmersiva'), findsNothing);
  });

  testWidgets('home skips welcome when a vehicle already exists', (
    tester,
  ) async {
    final vehicle = await harness.repository.createVehicle(
      plate: 'AAA111',
      kind: VehicleKind.car,
    );
    await harness.repository.setActiveVehicle(vehicle.id);

    await harness.pump(tester);

    expect(find.byKey(const ValueKey('home-empty-state')), findsNothing);
  });
}
