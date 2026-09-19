import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/features/buy_sell/presentation/buy_sell_screen.dart';
import 'package:picoradar/features/apps_launcher/data/module_registry.dart';
import 'package:picoradar/features/apps_launcher/domain/app_module.dart';
import 'package:picoradar/features/apps_launcher/presentation/apps_screen.dart';
import 'package:picoradar/features/apps_launcher/presentation/module_placeholder_screen.dart';
import 'package:picoradar/features/cda/presentation/cda_finder_screen.dart';
import 'package:picoradar/features/comparendos/presentation/comparendos_screen.dart';
import 'package:picoradar/features/defense/presentation/defense_screen.dart';
import 'package:picoradar/features/documents/presentation/documents_screen.dart';
import 'package:picoradar/features/fotomultas/presentation/fotomultas_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/maintenance/presentation/maintenance_screen.dart';
import 'package:picoradar/features/peritajes/presentation/peritajes_screen.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';
import 'package:picoradar/features/services/presentation/services_screen.dart';
import 'package:picoradar/features/tramites/presentation/tramites_screen.dart';
import 'package:picoradar/features/trip/presentation/trip_screen.dart';

import '../../../test_app_harness.dart';
import '../../../plate_test_fonts.dart';
import '../../home/presentation/v01b_test_font.dart';

void main() {
  setUpAll(loadV01bTestFont);
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
    expect(primaryModules, hasLength(9));
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
    expect(secondaryModules, hasLength(7));
    expect(secondaryModules.map((module) => module.title), [
      'CDA',
      'Servicios',
      'Compra/Venta',
      'Trámites',
      'Peritajes',
      'Talleres',
      'Peajes y estado vial',
    ]);
  });

  test('launcher destinations append vehicleId only when required', () {
    expect(appModuleLocation(primaryModules.first, 'vehicle-b'), '/apps/pico');
    expect(
      appModuleLocation(
        primaryModules.singleWhere((module) => module.id == 'soat'),
        'vehicle-b',
      ),
      '/apps/module/soat?vehicleId=vehicle-b',
    );
    expect(
      appModuleLocation(
        secondaryModules.singleWhere((module) => module.id == 'cda'),
        'vehicle-b',
      ),
      '/apps/cda',
    );
    expect(
      appModuleLocation(
        secondaryModules.singleWhere(
          (module) => module.id == 'peajes_estado_vial',
        ),
        'vehicle-b',
      ),
      '/trip',
    );
    expect(
      appModuleLocation(
        secondaryModules.singleWhere((module) => module.id == 'talleres'),
        null,
      ),
      '/apps/module/talleres',
    );
    expect(
      appModuleLocation(
        secondaryModules.singleWhere((module) => module.id == 'talleres'),
        ' vehicle-b ',
      ),
      '/apps/module/talleres?vehicleId=vehicle-b',
    );
  });

  test('default Apps visibility exposes all Wave2 modules fail-closed', () {
    expect(
      visibleModules(
        primaryModules,
        defaultModuleFeatureFlags,
      ).map((module) => module.title),
      _visiblePrimaryTitles,
    );
    expect(
      visibleModules(
        secondaryModules,
        defaultModuleFeatureFlags,
      ).map((module) => module.title),
      _visibleSecondaryTitles,
    );
    expect(_hiddenModules, isEmpty);
    expect(
      visibleModules(primaryModules, const {}),
      isEmpty,
      reason: 'unknown flags must not expose unfinished modules',
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
    for (final id in _visiblePrimaryIds) {
      expect(find.byKey(ValueKey('app-module-$id')), findsOneWidget);
    }
    for (final id in _hiddenModuleIds) {
      expect(find.byKey(ValueKey('app-module-$id')), findsNothing);
      expect(find.byKey(ValueKey('app-secondary-$id')), findsNothing);
    }

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('apps-launcher-more-list')),
      findsOneWidget,
    );
    for (final id in _visibleSecondaryIds) {
      expect(find.byKey(ValueKey('app-secondary-$id')), findsOneWidget);
    }
    for (final id in _hiddenModuleIds) {
      expect(find.byKey(ValueKey('app-module-$id')), findsNothing);
      expect(find.byKey(ValueKey('app-secondary-$id')), findsNothing);
    }
  });

  testWidgets(
    'Apps overlay module exposes one complete button semantics label',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await _openApps(tester, harness);

        final semantics = tester.getSemantics(
          find.byKey(const ValueKey('app-module-tecnomecanica')),
        );
        expect(semantics.label, 'Tecnomecánica');
        expect(
          semantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

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
    expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
    expect(find.text('Ver plan de viaje'), findsOneWidget);
  });

  testWidgets('P02 Apps opens and closes repeatedly from main branches', (
    tester,
  ) async {
    _usePortraitPhone(tester);
    await harness.pump(tester);

    for (final tabKey in ['tab-home', 'tab-garage', 'tab-trip']) {
      await tester.tap(find.byKey(ValueKey(tabKey)));
      await tester.pumpAndSettle();
      for (var cycle = 0; cycle < 10; cycle += 1) {
        await tester.tap(find.byKey(const ValueKey('tab-apps')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('apps-launcher-overlay')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('tab-apps')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('apps-launcher-overlay')),
          findsNothing,
        );
      }
    }
  });

  testWidgets('P03 Apps opens overlay over shell-preserved Pico', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'AAA111');
    await harness.preferences.setString(
      picoJurisdictionPreferenceKey,
      'co-dc-bogota',
    );
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-pico')));
    await _pumpPicoRoute(tester);
    expect(find.byType(PicoDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('app-bottom-navigation')), findsOneWidget);
    expect(_selectedBottomNavLabels(tester), contains('Apps'));

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await _pumpRoute(tester);
    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await _pumpRoute(tester);
    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsNothing);
    expect(find.byType(PicoDetailScreen), findsOneWidget);
  });

  testWidgets('Apps Más shows implemented modules by default', (tester) async {
    await _openApps(tester, harness);
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    for (final id in _visibleSecondaryIds) {
      expect(find.byKey(ValueKey('app-secondary-$id')), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('apps-launcher-more-list')),
        matching: find.byType(ListTile),
      ),
      findsNWidgets(_visibleSecondaryIds.length),
    );
    for (final id in _hiddenSecondaryIds) {
      expect(find.byKey(ValueKey('app-secondary-$id')), findsNothing);
    }
  });

  testWidgets('Apps Más opens the official CDA finder', (tester) async {
    await _openApps(tester, harness);
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-secondary-cda')));
    await _pumpRoute(tester);

    expect(find.byType(CdaFinderScreen), findsOneWidget);
    expect(find.text('Buscar CDA'), findsWidgets);
  });

  testWidgets('Apps Más opens the Trámites hub', (tester) async {
    await _openApps(tester, harness);
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-secondary-tramites')));
    await _pumpRoute(tester);

    expect(find.byType(TramitesScreen), findsOneWidget);
    expect(find.text('Trámites'), findsWidgets);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('Apps Más opens the Services hub', (tester) async {
    await _openSecondaryModuleFromApps(tester, harness, 'servicios');

    expect(find.byType(ServicesScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('services-screen')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('Apps opens Defensa with active vehicle', (tester) async {
    await _createVehicle(harness, plate: 'DEF123');
    await _openModuleFromApps(tester, harness, 'defensa', settle: false);
    await _pumpUntil(tester, find.byKey(const ValueKey('defense-screen')));

    expect(find.byType(DefenseScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('defense-screen')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('Apps Más opens Compra/Venta', (tester) async {
    await _openSecondaryModuleFromApps(tester, harness, 'compra_venta');

    expect(find.byType(BuySellScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('buy-sell-screen')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('Apps Más opens Peritajes with active vehicle', (tester) async {
    await _createVehicle(harness, plate: 'PER123');
    await _openSecondaryModuleFromApps(tester, harness, 'peritajes');

    expect(find.byType(PeritajesScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('peritajes-screen')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('Apps Más opens Maintenance with active vehicle', (tester) async {
    await _createVehicle(harness, plate: 'TLL123');
    await _openSecondaryModuleFromApps(tester, harness, 'talleres');

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(find.text('Talleres y mantenimiento'), findsWidgets);
    expect(
      find.byKey(const ValueKey('maintenance-missing-vehicle')),
      findsNothing,
    );
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
    expect(find.byType(DocumentsScreen), findsNothing);
  });

  testWidgets(
    'Back from Maintenance restores the Más launcher over its origin',
    (tester) async {
      await _createVehicle(harness, plate: 'TLL456');
      await _openSecondaryModuleFromApps(tester, harness, 'talleres');

      expect(find.byType(MaintenanceScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(MaintenanceScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('apps-launcher-overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('apps-launcher-more-list')),
        findsOneWidget,
      );
      expect(_selectedBottomNavLabels(tester), contains('Apps'));
      await tester.tap(find.byKey(const ValueKey('tab-apps')));
      await tester.pumpAndSettle();
      expect(_selectedBottomNavLabels(tester), contains('Inicio'));
    },
  );

  testWidgets('Apps Más opens Trip from Peajes y estado vial', (tester) async {
    await _openSecondaryModuleFromApps(tester, harness, 'peajes_estado_vial');

    expect(find.byType(TripScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('Fotomultas opens the real camera explorer', (tester) async {
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-fotomultas')));
    await _pumpRoute(tester);

    expect(find.byType(FotomultasScreen), findsOneWidget);
    expect(find.text('Fotomultas'), findsWidgets);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('Comparendos opens the official shortcuts screen', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'CMP123');
    await _openApps(tester, harness);

    await tester.tap(find.byKey(const ValueKey('app-module-comparendos')));
    await _pumpRoute(tester);

    expect(find.byType(ComparendosScreen), findsOneWidget);
    expect(findPlateNumber('CMP123'), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('Documentos opens the encrypted vehicle wallet', (tester) async {
    await _createVehicle(harness, plate: 'DOC123');
    await _openModuleFromApps(tester, harness, 'documentos', settle: false);

    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('documents-go-garage')), findsNothing);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('direct Apps route sends active vehicle to Documentos', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'DIR123');
    String? routedVehicleId;
    await harness.repository.setActiveVehicle(vehicle.id);
    await _pumpRoutedAppsLocation(
      tester,
      harness,
      '/apps',
      onDocumentsVehicleId: (vehicleId) => routedVehicleId = vehicleId,
    );

    await tester.tap(find.byKey(const ValueKey('app-module-documentos')));
    await _pumpRoute(tester);

    expect(routedVehicleId, vehicle.id);
    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('documents-go-garage')), findsNothing);
  });

  testWidgets('direct Apps route sends active vehicle to Talleres', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'TDR123');
    String? routedVehicleId;
    await harness.repository.setActiveVehicle(vehicle.id);
    await _pumpRoutedAppsLocation(
      tester,
      harness,
      '/apps',
      onMaintenanceVehicleId: (vehicleId) => routedVehicleId = vehicleId,
    );

    await tester.ensureVisible(find.text('Más para tu vehículo'));
    await tester.tap(find.byKey(const ValueKey('app-secondary-talleres')));
    await _pumpRoute(tester);

    expect(routedVehicleId, vehicle.id);
    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('maintenance-empty')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('maintenance-missing-vehicle')),
      findsNothing,
    );
    expect(find.byType(DocumentsScreen), findsNothing);
  });

  testWidgets('Talleres route without vehicle renders maintenance guard', (
    tester,
  ) async {
    await _pumpRoutedAppsLocation(tester, harness, '/apps/module/talleres');

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('maintenance-missing-vehicle')),
      findsOneWidget,
    );
    expect(find.byType(DocumentsScreen), findsNothing);
  });

  testWidgets('unfinished modules are not visible from Apps', (tester) async {
    await _createVehicle(harness, plate: 'AAA111');
    await _openApps(tester, harness);

    for (final id in _hiddenPrimaryIds) {
      expect(find.byKey(ValueKey('app-module-$id')), findsNothing);
    }
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    for (final id in _hiddenSecondaryIds) {
      expect(find.byKey(ValueKey('app-secondary-$id')), findsNothing);
    }
    expect(find.text('Próximamente'), findsNothing);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('C13 vehicle status modules open real screens', (tester) async {
    final vehicle = await _createVehicle(harness, plate: 'AAA111');

    await _openModuleFromApps(tester, harness, 'soat', settle: false);
    await _pumpUntil(tester, find.byKey(const ValueKey('owner-primary-soat')));
    expect(find.text('SOAT'), findsWidgets);
    expect(find.text('SOAT SIN CONFIGURAR'), findsOneWidget);
    expect(find.text('Configura tu SOAT'), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);

    await _openModuleFromApps(tester, harness, 'tecnomecanica', settle: false);
    await _pumpUntil(tester, find.byKey(const ValueKey('owner-primary-rtm')));
    expect(find.text('Tecnomecánica / RTM'), findsOneWidget);
    expect(find.byKey(const ValueKey('owner-primary-rtm')), findsOneWidget);
    expect(find.text('BUSCAR CDA'), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);

    await _openModuleFromApps(
      tester,
      harness,
      'seguro_asistencia',
      settle: false,
    );
    await _pumpUntil(
      tester,
      find.byKey(const ValueKey('insurance-owner-content')),
    );
    expect(
      find.byKey(const ValueKey('insurance-owner-content')),
      findsOneWidget,
    );
    expect(find.byType(ModulePlaceholderScreen), findsNothing);

    await _openModuleFromApps(tester, harness, 'impuestos', settle: false);
    await _pumpUntil(tester, find.byKey(ValueKey('tax-owner-${vehicle.id}')));
    expect(find.text('Impuestos'), findsWidgets);
    expect(find.byKey(ValueKey('tax-owner-${vehicle.id}')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
  });

  testWidgets('RTM Buscar CDA opens finder without mutating active vehicle', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'RTM789');
    await harness.repository.setActiveVehicle(vehicle.id);

    await _openModuleFromApps(tester, harness, 'tecnomecanica');
    await tester.tap(find.byKey(const ValueKey('owner-primary-rtm')));
    await _pumpRoute(tester);
    await _pumpUntil(tester, find.byKey(const ValueKey('cda-use-location')));

    expect(find.byType(CdaFinderScreen), findsOneWidget);
    expect(
      await harness.preferences.getString(
        VehicleRepository.activeVehiclePreferenceKey,
      ),
      vehicle.id,
    );
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
    expect(find.text('MOT123'), findsWidgets);
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

    expect(find.text('¿Qué conduces?'), findsOneWidget);
  });

  testWidgets(
    'visible module without vehicle requirement opens without guard',
    (tester) async {
      await _openApps(tester, harness);

      await tester.tap(find.byKey(const ValueKey('app-module-pico')));
      await _pumpRoute(tester);

      expect(find.byType(PicoDetailScreen), findsOneWidget);
      expect(find.byType(ModulePlaceholderScreen), findsNothing);
      expect(
        find.text('Agrega un vehículo para usar esta función.'),
        findsNothing,
      );
    },
  );

  testWidgets('hidden feature flag compacts the grid without a gap', (
    tester,
  ) async {
    await _openApps(
      tester,
      harness,
      moduleFeatureFlags: {
        ...defaultModuleFeatureFlags,
        'module_soat_enabled': false,
      },
    );

    expect(find.byKey(const ValueKey('app-module-soat')), findsNothing);
    expect(
      find.byKey(const ValueKey('app-module-tecnomecanica')),
      findsOneWidget,
    );
    expect(
      visibleModules(primaryModules, {
        ...defaultModuleFeatureFlags,
        'module_soat_enabled': false,
      }),
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scale 2.0 keeps launcher readable', (tester) async {
    await _pumpAppsScreenAtScale(tester, 2.0);

    expect(find.text('Seguro y asistencia'), findsOneWidget);
    expect(find.text('Tecnomecánica'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary Apps grid does not overflow on target phones', (
    tester,
  ) async {
    const sizes = [Size(360, 800), Size(390, 844), Size(412, 915)];
    const scales = [1.0, 1.5, 2.0];

    for (final size in sizes) {
      for (final scale in scales) {
        await _pumpAppsScreenAtScale(tester, scale, size: size);

        expect(find.byKey(const ValueKey('apps-primary-grid')), findsOneWidget);
        for (final module in primaryModules.where(
          (module) => _visiblePrimaryIds.contains(module.id),
        )) {
          expect(
            find.byKey(ValueKey('app-module-${module.id}')),
            findsOneWidget,
            reason: '${module.title} should remain visible in K2B',
          );
          expect(find.text(module.title), findsOneWidget);
        }
        for (final id in _hiddenModuleIds) {
          expect(find.byKey(ValueKey('app-module-$id')), findsNothing);
          expect(find.byKey(ValueKey('app-secondary-$id')), findsNothing);
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'Apps overflow at ${size.width}x${size.height}, scale $scale',
        );
      }
    }
  });

  testWidgets(
    'primary module tile exposes one complete button semantics label',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await _pumpAppsScreenAtScale(tester, 2.0, size: const Size(360, 800));

        final semantics = tester.getSemantics(
          find.byKey(const ValueKey('app-module-tecnomecanica')),
        );
        expect(semantics.label, 'Tecnomecánica');
        expect(
          semantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}

const _visiblePrimaryIds = [
  'pico',
  'fotomultas',
  'comparendos',
  'soat',
  'tecnomecanica',
  'impuestos',
  'documentos',
  'seguro_asistencia',
  'defensa',
];

const _visiblePrimaryTitles = [
  'Pico y placa',
  'Fotomultas',
  'Comparendos',
  'SOAT',
  'Tecnomecánica',
  'Impuestos',
  'Documentos',
  'Seguro y asistencia',
  'Defensa',
];

const _visibleSecondaryIds = [
  'cda',
  'servicios',
  'compra_venta',
  'tramites',
  'peritajes',
  'talleres',
  'peajes_estado_vial',
];
const _visibleSecondaryTitles = [
  'CDA',
  'Servicios',
  'Compra/Venta',
  'Trámites',
  'Peritajes',
  'Talleres',
  'Peajes y estado vial',
];

const _hiddenPrimaryIds = <String>[];

const _hiddenSecondaryIds = <String>[];

const _hiddenModuleIds = [..._hiddenPrimaryIds, ..._hiddenSecondaryIds];

List<AppModule> get _hiddenModules => [
  ...primaryModules.where((module) => _hiddenPrimaryIds.contains(module.id)),
  ...secondaryModules.where(
    (module) => _hiddenSecondaryIds.contains(module.id),
  ),
];

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

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i += 1) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pumpPicoRoute(WidgetTester tester) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(const ValueKey('pico-city-screen')).evaluate().isNotEmpty ||
        find.text('MI PICO Y PLACA').evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _openModuleFromApps(
  WidgetTester tester,
  TestAppHarness harness,
  String moduleId, {
  bool settle = true,
}) async {
  await _openApps(tester, harness);
  final module = find.byKey(ValueKey('app-module-$moduleId'));
  await tester.ensureVisible(module);
  await tester.tap(module);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await _pumpRoute(tester);
  }
}

Future<void> _openSecondaryModuleFromApps(
  WidgetTester tester,
  TestAppHarness harness,
  String moduleId,
) async {
  await _openApps(tester, harness);
  await tester.tap(find.text('Más'));
  await tester.pumpAndSettle();
  final module = find.byKey(ValueKey('app-secondary-$moduleId'));
  await tester.ensureVisible(module);
  await tester.pumpAndSettle();
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  if (tester.getCenter(module).dy > viewportHeight - 96) {
    await tester.drag(
      find.byKey(const ValueKey('apps-launcher-more-list')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }
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

Future<void> _pumpAppsScreenAtScale(
  WidgetTester tester,
  double scale, {
  Size size = const Size(390, 844),
}) async {
  final vehicle = _vehicle(id: 'vehicle-1', plate: 'AAA111');
  await _pumpDirectAppsScreen(
    tester,
    vehicles: [vehicle],
    active: vehicle,
    scale: scale,
    size: size,
  );
}

Future<void> _pumpRoutedAppsLocation(
  WidgetTester tester,
  TestAppHarness harness,
  String initialLocation, {
  ValueChanged<String?>? onDocumentsVehicleId,
  ValueChanged<String?>? onMaintenanceVehicleId,
}) async {
  _usePortraitPhone(tester);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/apps',
        builder: (context, state) => const AppsScreen(),
        routes: [
          GoRoute(
            path: 'module/:id',
            builder: (context, state) {
              final moduleId = state.pathParameters['id']!;
              if (moduleId == 'documentos') {
                final vehicleId = state.uri.queryParameters['vehicleId'];
                onDocumentsVehicleId?.call(vehicleId);
                return DocumentsScreen(vehicleId);
              }
              if (moduleId == 'talleres') {
                final vehicleId = state.uri.queryParameters['vehicleId'];
                onMaintenanceVehicleId?.call(vehicleId);
                return MaintenanceScreen(vehicleId: vehicleId);
              }
              return ModulePlaceholderScreen(
                moduleId: moduleId,
                category: state.uri.queryParameters['category'],
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/garage',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/onboarding/vehicle',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await harness.pump(
    tester,
    childOverride: MaterialApp.router(routerConfig: router),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDirectAppsScreen(
  WidgetTester tester, {
  List<VehicleProfile> vehicles = const [],
  VehicleProfile? active,
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  _usePortraitPhone(tester, size: size);
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

void _usePortraitPhone(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
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
