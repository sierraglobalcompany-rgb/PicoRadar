import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/features/apps_launcher/data/module_registry.dart';
import 'package:picoradar/features/apps_launcher/presentation/apps_screen.dart';
import 'package:picoradar/features/apps_launcher/presentation/module_placeholder_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';

import '../../../test_app_harness.dart';

void main() {
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('Apps remains the central shell tab', () {
    expect(AppTab.values.indexOf(AppTab.apps), 2);
    expect(AppTab.values.map((tab) => tab.label), [
      'Inicio',
      'Garaje',
      'Apps',
      'Viaje',
      'Conducir',
    ]);
  });

  test('primary modules keep the approved 1 to 9 order', () {
    expect(primaryModules.map((module) => module.title), [
      'Pico y placa',
      'Fotomultas',
      'Comparendos',
      'SOAT',
      'Tecnomecánica',
      'Impuestos',
      'Documentos',
      'Seguro y asistencia',
      'Defensa',
    ]);
  });

  test('secondary modules keep the approved order', () {
    expect(secondaryModules.map((module) => module.title), [
      'Servicios',
      'Compra/Venta',
      'Trámites',
      'Peritajes',
      'Talleres',
      'Peajes y estado vial',
    ]);
  });

  testWidgets('Apps shows 9 primary and 6 secondary modules', (tester) async {
    await _openApps(tester, harness);

    for (final module in primaryModules) {
      expect(find.byKey(ValueKey('app-module-${module.id}')), findsOneWidget);
    }
    for (final module in secondaryModules) {
      expect(
        find.byKey(ValueKey('app-secondary-${module.id}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('Pico y placa opens the existing pico detail route', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'AAA111');
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-pico')));
    await _pumpRoute(tester);

    expect(find.text('Pico y Placa'), findsOneWidget);
  });

  testWidgets('Peajes y estado vial opens the Viaje tab', (tester) async {
    await _openApps(tester, harness);

    final shortcut = find.byKey(
      const ValueKey('app-secondary-peajes_estado_vial'),
    );
    await tester.ensureVisible(shortcut);
    await tester.tap(shortcut);
    await _pumpRoute(tester);

    expect(find.text('Planeacion de ruta sin mapa propio.'), findsOneWidget);
  });

  testWidgets('unimplemented modules open one neutral placeholder', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'AAA111');
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-comparendos')));
    await _pumpRoute(tester);

    expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
    expect(find.text('Próximamente'), findsOneWidget);
    expect(
      find.text('Este módulo estará disponible en una próxima etapa.'),
      findsOneWidget,
    );
  });

  testWidgets('Documentos and Defensa remain placeholders', (tester) async {
    await _createVehicle(harness, plate: 'AAA111');

    await _openModuleFromApps(tester, harness, 'documentos');
    expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
    expect(find.text('Documentos'), findsWidgets);

    await _openModuleFromApps(tester, harness, 'defensa');
    expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
    expect(find.text('Defensa'), findsWidgets);
  });

  testWidgets('C13 vehicle status modules open real screens', (tester) async {
    await _createVehicle(harness, plate: 'AAA111');

    await _openModuleFromApps(tester, harness, 'soat');
    expect(find.text('SOAT'), findsWidgets);
    expect(
      find.text(
        'La fecha mostrada fue guardada en este dispositivo. Verifica la vigencia oficial en RUNT.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ModulePlaceholderScreen), findsNothing);

    await _openModuleFromApps(tester, harness, 'tecnomecanica');
    expect(find.text('Tecnomecánica / RTM'), findsOneWidget);
    expect(find.byKey(const ValueKey('rtm-find-cda')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);

    await _openModuleFromApps(tester, harness, 'seguro_asistencia');
    expect(find.text('Seguro y asistencia'), findsWidgets);
    expect(
      find.text('Disponible según las coberturas y condiciones de tu póliza.'),
      findsOneWidget,
    );
    expect(find.byType(ModulePlaceholderScreen), findsNothing);

    await _openModuleFromApps(tester, harness, 'impuestos');
    expect(find.text('Impuestos'), findsWidgets);
    expect(
      find.text('No calculamos ni estimamos el impuesto.'),
      findsOneWidget,
    );
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('vehicle status modules work for taxi and motorcycle', (
    tester,
  ) async {
    await _createVehicle(
      harness,
      plate: 'TAX123',
      serviceType: VehicleServiceType.taxi,
    );
    await _openModuleFromApps(tester, harness, 'soat');
    expect(find.text('TAX123'), findsOneWidget);
    expect(find.text('SOAT'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final motorcycleHarness = TestAppHarness();
    addTearDown(motorcycleHarness.dispose);
    await _createVehicle(
      motorcycleHarness,
      plate: 'MOT123',
      kind: VehicleKind.motorcycle,
    );
    await _openModuleFromApps(tester, motorcycleHarness, 'tecnomecanica');
    expect(find.text('MOT123'), findsOneWidget);
    expect(find.text('Tecnomecánica / RTM'), findsOneWidget);
  });

  testWidgets('taxi appears in active vehicle chip', (tester) async {
    await _createVehicle(
      harness,
      plate: 'TAX123',
      serviceType: VehicleServiceType.taxi,
    );

    await _openApps(tester, harness);

    expect(find.text('TAX123 · Taxi'), findsOneWidget);
  });

  testWidgets('private car appears in active vehicle chip', (tester) async {
    await _createVehicle(harness, plate: 'AAA111');

    await _openApps(tester, harness);

    expect(find.text('AAA111 · Particular'), findsOneWidget);
  });

  testWidgets('motorcycle appears in active vehicle chip', (tester) async {
    await _createVehicle(
      harness,
      plate: 'MOT123',
      kind: VehicleKind.motorcycle,
    );

    await _openApps(tester, harness);

    expect(find.text('MOT123 · Moto'), findsOneWidget);
  });

  testWidgets('Apps shows no vehicle state', (tester) async {
    await _openApps(tester, harness);

    expect(find.text('Sin vehículo'), findsOneWidget);
  });

  testWidgets('requiresVehicle module is guarded without a vehicle', (
    tester,
  ) async {
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-soat')));
    await _pumpRoute(tester);

    expect(
      find.text('Agrega un vehículo para usar esta función.'),
      findsOneWidget,
    );
  });

  testWidgets('vehicle guard CTA opens onboarding with apps return', (
    tester,
  ) async {
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-soat')));
    await _pumpRoute(tester);
    await tester.tap(find.byKey(const ValueKey('vehicle-guard-add')));
    await _pumpRoute(tester);

    expect(find.text('Agregar vehículo'), findsOneWidget);
  });

  testWidgets('module without vehicle requirement opens without guard', (
    tester,
  ) async {
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-fotomultas')));
    await _pumpRoute(tester);

    expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
    expect(find.text('Próximamente'), findsOneWidget);
    expect(
      find.text('Agrega un vehículo para usar esta función.'),
      findsNothing,
    );
  });

  testWidgets('hidden feature flag compacts the grid without a gap', (
    tester,
  ) async {
    await _openApps(
      tester,
      harness,
      moduleFeatureFlags: {'module_soat_enabled': false},
    );

    expect(find.byKey(const ValueKey('app-module-soat')), findsNothing);
    expect(
      find.byKey(const ValueKey('app-module-tecnomecanica')),
      findsOneWidget,
    );
    expect(
      visibleModules(primaryModules, {'module_soat_enabled': false}),
      hasLength(8),
    );
  });

  testWidgets('text scale 1.5 keeps launcher readable', (tester) async {
    await _pumpAppsScreenAtScale(tester, 1.5);

    expect(find.text('Seguro y asistencia'), findsOneWidget);
    expect(find.text('Tecnomecánica'), findsOneWidget);
  });

  testWidgets('text scale 2.0 keeps launcher readable', (tester) async {
    await _pumpAppsScreenAtScale(tester, 2.0);

    expect(find.text('Seguro y asistencia'), findsOneWidget);
    expect(find.text('Tecnomecánica'), findsOneWidget);
  });
}

Future<void> _openApps(
  WidgetTester tester,
  TestAppHarness harness, {
  Map<String, bool> moduleFeatureFlags = const {},
}) async {
  await harness.pump(tester, moduleFeatureFlags: moduleFeatureFlags);
  await tester.tap(find.byKey(const ValueKey('tab-apps')));
  await tester.pumpAndSettle();
}

Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _openModuleFromApps(
  WidgetTester tester,
  TestAppHarness harness,
  String moduleId,
) async {
  await _openApps(tester, harness);
  final module = find.byKey(ValueKey('app-module-$moduleId'));
  await tester.ensureVisible(module);
  await tester.tap(module);
  await tester.pumpAndSettle();
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

Future<void> _pumpAppsScreenAtScale(WidgetTester tester, double scale) async {
  final vehicle = VehicleProfile(
    id: 'vehicle-1',
    plate: 'AAA111',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vehicleListProvider.overrideWith((ref) async => [vehicle]),
        activeVehicleProvider.overrideWith((ref) async => vehicle),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const AppsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
