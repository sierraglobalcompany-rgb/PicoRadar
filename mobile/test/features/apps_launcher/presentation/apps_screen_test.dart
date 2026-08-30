import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/features/apps_launcher/data/module_registry.dart';
import 'package:picoradar/features/apps_launcher/presentation/apps_launcher_panel.dart';
import 'package:picoradar/features/apps_launcher/presentation/apps_screen.dart';
import 'package:picoradar/features/apps_launcher/presentation/module_placeholder_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
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

  test('launcher destinations append vehicleId only when required', () {
    expect(appsLauncherLocation(primaryModules.first, 'vehicle-b'), '/pico');
    expect(
      appsLauncherLocation(
        primaryModules.singleWhere((module) => module.id == 'soat'),
        'vehicle-b',
      ),
      '/apps/module/soat?vehicleId=vehicle-b',
    );
    expect(
      appsLauncherLocation(
        secondaryModules.singleWhere(
          (module) => module.id == 'peajes_estado_vial',
        ),
        'vehicle-b',
      ),
      '/trip',
    );
  });

  testWidgets('Apps center action opens overlay above Home', (tester) async {
    await _openApps(tester, harness);

    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('apps-launcher-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('apps-launcher-scrim')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-empty-state')), findsOneWidget);
    expect(find.byType(AppsScreen), findsNothing);
    expect(_selectedBottomNavLabels(tester), contains('Apps'));
  });

  testWidgets('Apps overlay shows primary first and secondary in Más', (
    tester,
  ) async {
    await _openApps(tester, harness);

    expect(
      find.byKey(const ValueKey('apps-launcher-primary-grid')),
      findsOneWidget,
    );
    for (final module in primaryModules) {
      expect(find.byKey(ValueKey('app-module-${module.id}')), findsOneWidget);
    }
    for (final module in secondaryModules) {
      expect(find.byKey(ValueKey('app-secondary-${module.id}')), findsNothing);
    }

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('apps-launcher-more-list')),
      findsOneWidget,
    );
    for (final module in secondaryModules) {
      expect(
        find.byKey(ValueKey('app-secondary-${module.id}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('Apps overlay closes with toggle, scrim and Android Back', (
    tester,
  ) async {
    await _openApps(tester, harness);
    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(24, 72));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsNothing);
  });

  testWidgets('tapping another tab closes overlay and navigates', (
    tester,
  ) async {
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('tab-trip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsNothing);
    expect(find.text('Planeacion de ruta sin mapa propio.'), findsOneWidget);
  });

  testWidgets('Pico y placa opens the city overview route', (tester) async {
    await _createVehicle(harness, plate: 'AAA111');
    await harness.preferences.setString(
      picoJurisdictionPreferenceKey,
      'co-dc-bogota',
    );
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-pico')));
    await _pumpPicoRoute(tester);

    expect(find.byType(PicoDetailScreen), findsOneWidget);
    expect(
      GoRouter.of(
        tester.element(find.byType(PicoDetailScreen)),
      ).routerDelegate.currentConfiguration.uri.toString(),
      '/pico',
    );
  });

  testWidgets('Peajes y estado vial opens the Viaje tab', (tester) async {
    await _openApps(tester, harness);
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    final shortcut = find.byKey(
      const ValueKey('app-secondary-peajes_estado_vial'),
    );
    await tester.drag(
      find.byKey(const ValueKey('apps-launcher-more-list')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(shortcut.last);
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

  testWidgets('direct Apps route still shows active vehicle chip', (
    tester,
  ) async {
    final taxi = _vehicle(
      id: 'vehicle-taxi',
      plate: 'TAX123',
      serviceType: VehicleServiceType.taxi,
    );

    await _pumpDirectAppsScreen(tester, vehicles: [taxi], active: taxi);

    expect(find.text('TAX123 · Taxi'), findsOneWidget);
  });

  testWidgets('direct Apps route still shows no vehicle state', (tester) async {
    await _pumpDirectAppsScreen(tester);

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

  test('Home launcher uses focused vehicle without mutating active', () {
    expect(
      resolveAppsLauncherVehicleId(
        currentIndex: AppTab.home.index,
        homeIndex: AppTab.home.index,
        focusedVehicleId: 'vehicle-b',
        activeVehicleId: 'vehicle-a',
        vehicleIds: const ['vehicle-a', 'vehicle-b'],
      ),
      'vehicle-b',
    );
    expect(
      resolveAppsLauncherVehicleId(
        currentIndex: AppTab.home.index,
        homeIndex: AppTab.home.index,
        focusedVehicleId: 'missing',
        activeVehicleId: 'vehicle-a',
        vehicleIds: const ['vehicle-a', 'vehicle-b'],
      ),
      'vehicle-a',
    );
  });

  testWidgets('Garage launcher uses active vehicle', (tester) async {
    final active = await _createVehicle(harness, plate: 'AAA111');
    await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(active.id);
    _usePortraitPhone(tester);
    await harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('tab-garage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-module-soat')));
    await tester.pumpAndSettle();

    expect(find.text('AAA111'), findsOneWidget);
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
  _usePortraitPhone(tester);
  await harness.pump(tester, moduleFeatureFlags: moduleFeatureFlags);
  await tester.tap(find.byKey(const ValueKey('tab-apps')));
  await tester.pumpAndSettle();
}

Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _pumpPicoRoute(WidgetTester tester) async {
  for (var i = 0; i < 10; i += 1) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byType(PicoDetailScreen).evaluate().isNotEmpty) {
      return;
    }
  }
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
  final vehicle = _vehicle(id: 'vehicle-1', plate: 'AAA111');
  await _pumpDirectAppsScreen(
    tester,
    vehicles: [vehicle],
    active: vehicle,
    scale: scale,
  );
}

Future<void> _pumpDirectAppsScreen(
  WidgetTester tester, {
  List<VehicleProfile> vehicles = const [],
  VehicleProfile? active,
  double scale = 1,
}) async {
  _usePortraitPhone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vehicleListProvider.overrideWith((ref) async => vehicles),
        activeVehicleProvider.overrideWith((ref) async => active),
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

void _usePortraitPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

VehicleProfile _vehicle({
  required String id,
  required String plate,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

List<String> _selectedBottomNavLabels(WidgetTester tester) {
  return tester
      .widgetList<Semantics>(find.byType(Semantics))
      .where((widget) => widget.properties.selected == true)
      .map((widget) => widget.properties.label)
      .whereType<String>()
      .toList();
}
