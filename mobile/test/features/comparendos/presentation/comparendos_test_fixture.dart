import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/design_system/navigation.dart';
import 'package:picoradar/features/comparendos/data/territorial_catalog.dart';
import 'package:picoradar/features/comparendos/presentation/comparendos_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';

import '../../../test_app_harness.dart';

const testMedellinUrl = 'https://www.medellin.gov.co/portal-movilidad/#/public';
const testBogotaUrl =
    'https://www.movilidadbogota.gov.co/consulta-de-comparendos';

const pendingComparendosAuthority = TerritorialAuthority(
  id: 'test-pending',
  name: 'Autoridad pendiente de revisión',
  platformName: 'Directorio histórico',
  municipalityCodes: [],
  officeMunicipality: 'Medellín',
  officeMunicipalityCode: '05001',
  department: 'Antioquia',
  sourceNames: ['Oficina histórica del registro nacional'],
);

const regionalComparendosAuthority = TerritorialAuthority(
  id: 'test-regional',
  name: 'Autoridad regional de prueba',
  platformName: 'Portal regional',
  municipalityCodes: ['05001', '05360'],
  consultationUrl: 'https://www.example.org/consulta',
  institutionalUrl: 'https://www.example.org/institucion',
  evidenceUrl: 'https://www.example.org/fuente',
  verifiedAt: '2026-09-01',
  verificationStatus: 'verified',
  coverageStatus: 'verified_municipal',
  officeMunicipality: 'Medellín',
  department: 'Antioquia',
);

const comparendosMunicipalities = TripMunicipalityCatalog(
  records: [
    TripMunicipality(
      code: '05001',
      municipality: 'Medellín',
      department: 'Antioquia',
    ),
    TripMunicipality(
      code: '11001',
      municipality: 'Bogotá',
      department: 'Bogotá D.C.',
    ),
    TripMunicipality(
      code: '76001',
      municipality: 'Cali',
      department: 'Valle del Cauca',
    ),
    TripMunicipality(
      code: '05360',
      municipality: 'Itagüí',
      department: 'Antioquia',
    ),
  ],
);

// Presentation fixtures deliberately avoid the changing production directory.
const comparendosAuthorities = TerritorialCatalog(
  authorities: [
    TerritorialAuthority(
      id: 'test-medellin',
      name: 'Secretaría de Movilidad de Medellín',
      platformName: 'Movilidad en Línea',
      municipalityCodes: ['05001'],
      consultationUrl: testMedellinUrl,
    ),
    TerritorialAuthority(
      id: 'test-bogota',
      name: 'Secretaría Distrital de Movilidad de Bogotá',
      platformName: 'Movilidad Bogotá',
      municipalityCodes: ['11001'],
      consultationUrl: testBogotaUrl,
    ),
  ],
);

VehicleProfile comparendosVehicle({
  String id = 'vehicle-a',
  String plate = 'ABC123',
  String nickname = 'Mi vehículo',
  String registrationCity = 'Medellín',
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
}) => VehicleProfile(
  id: id,
  plate: plate,
  nickname: nickname,
  registrationCity: registrationCity,
  kind: kind,
  serviceType: serviceType,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class ComparendosLauncher implements ExternalLauncher {
  final opened = <String>[];
  bool succeeds = true;
  bool throwsOnOpen = false;
  @override
  Future<bool> callPhone(String phone) async => true;
  @override
  Future<bool> openExternal(String uri) async {
    opened.add(uri);
    if (throwsOnOpen) throw StateError('Test launcher unavailable');
    return succeeds;
  }
}

class ComparendosPreferences extends MemoryPreferences {
  final writes = <(String, String)>[];
  final pending = <String, Completer<void>>{};
  bool failWrites = false;
  bool failNoteReads = false;

  @override
  Future<String?> getString(String key) async {
    if (failNoteReads && key.startsWith('comparendos.last_checked.')) {
      throw StateError('Test note read failed');
    }
    return super.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    writes.add((key, value));
    if (failWrites) throw StateError('Test note write failed');
    if (pending[key] case final operation?) await operation.future;
    await super.setString(key, value);
  }
}

final _visuals = VehicleVisualCatalog.fromJson(
  jsonDecode(File(vehicleCatalogAssetPath).readAsStringSync())
      as Map<String, Object?>,
);

Future<ProviderContainer> pumpComparendos(
  WidgetTester tester, {
  required MemoryPreferences preferences,
  List<VehicleProfile> vehicles = const [],
  VehicleProfile? active,
  String? vehicleId,
  Future<VehicleProfile?> Function()? activeLoader,
  Future<List<VehicleProfile>> Function(Ref)? vehicleLoader,
  Future<TerritorialCatalog> Function()? directoryLoader,
  Future<TripMunicipalityCatalog> Function()? municipalityLoader,
  ExternalLauncher? launcher,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool bottomNavigation = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  // A pump denotes a new visit; provider invalidations exercise a live visit.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        vehicleListProvider.overrideWith(
          vehicleLoader ?? (ref) async => vehicles,
        ),
        activeVehicleProvider.overrideWith(
          (ref) async => activeLoader == null ? active : await activeLoader(),
        ),
        tripMunicipalityCatalogProvider.overrideWith(
          (ref) async => municipalityLoader == null
              ? comparendosMunicipalities
              : await municipalityLoader(),
        ),
        territorialCatalogProvider.overrideWith(
          (ref) async => directoryLoader == null
              ? comparendosAuthorities
              : await directoryLoader(),
        ),
        registrationCityCatalogProvider.overrideWithValue(
          AsyncData(TestAppHarness.registrationCatalog),
        ),
        vehicleVisualCatalogProvider.overrideWithValue(AsyncData(_visuals)),
        vehicleVisualOverrideProvider.overrideWith((ref, id) async => null),
        bogotaNowProvider.overrideWithValue(DateTime(2026, 9, 3, 8)),
        externalLauncherProvider.overrideWithValue(
          launcher ?? ComparendosLauncher(),
        ),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(
            key: const ValueKey('comparendos-test-capture'),
            child: child!,
          ),
        ),
        home: bottomNavigation
            ? Scaffold(
                body: ComparendosScreen(vehicleId: vehicleId),
                bottomNavigationBar: AppBottomNav(
                  key: const ValueKey('comparendos-test-nav'),
                  destinations: [
                    for (final tab in AppTab.values)
                      AppBottomNavDestination(
                        label: tab.label,
                        icon: tab.icon,
                        selectedIcon: tab.selectedIcon,
                        color: tab.color,
                        keyName: tab.name,
                      ),
                  ],
                  currentIndex: AppTab.apps.index,
                  onSelect: (_) {},
                ),
              )
            : ComparendosScreen(vehicleId: vehicleId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return ProviderScope.containerOf(
    tester.element(find.byType(ComparendosScreen)),
  );
}

Finder comparendosKey(String name) => find.byKey(ValueKey('comparendos-$name'));

Future<void> tapComparendos(WidgetTester tester, String name) async {
  await tester.ensureVisible(comparendosKey(name));
  await tester.pumpAndSettle();
  await tester.tap(comparendosKey(name));
  await tester.pumpAndSettle();
}

Future<void> chooseComparendosVehicle(WidgetTester tester, String id) async {
  await tapComparendos(tester, 'change-vehicle');
  await tapComparendos(tester, 'choose-$id');
}

Future<void> chooseComparendosCity(
  WidgetTester tester,
  String code,
  String query,
) async {
  await tapComparendos(tester, 'change-city');
  await tester.enterText(comparendosKey('city-search'), query);
  await tester.pumpAndSettle();
  await tapComparendos(tester, 'city-$code');
}

Future<void> captureComparendos(WidgetTester tester, String name) async {
  final directory = Platform.environment['COMPARENDOS_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    comparendosKey('test-capture'),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
