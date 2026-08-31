import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';
import 'package:picoradar/features/cda/presentation/cda_finder_screen.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

void main() {
  testWidgets('typing local search does not request GPS permission', (
    tester,
  ) async {
    final gateway = _FakeLocationGateway();
    await _pumpScreen(tester, gateway: gateway);

    await tester.enterText(
      find.byKey(const ValueKey('cda-search-field')),
      'bogota',
    );
    await tester.pump();

    expect(gateway.requestPermissionCalls, 0);
    expect(find.text('CDA Bogotá Uno'), findsOneWidget);
  });

  testWidgets('location use filters by city without inventing distance', (
    tester,
  ) async {
    final gateway = _FakeLocationGateway(
      point: const DeviceLocationPoint(
        latitude: 6.2442,
        longitude: -75.5812,
        accuracyMeters: 25,
      ),
    );
    await _pumpScreen(tester, gateway: gateway);

    await tester.tap(find.byKey(const ValueKey('cda-use-location')));
    await tester.pumpAndSettle();

    expect(gateway.requestPermissionCalls, 1);
    expect(find.text('CDA en Medellín · según tu ubicación'), findsOneWidget);
    expect(find.text('CDA Medellín Uno'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
  });

  testWidgets('sponsored section is absent when no config exists', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Patrocinado'), findsNothing);
    expect(find.text('CDA Bogotá Uno'), findsOneWidget);
  });

  testWidgets('detail sheet keeps the official-source framing', (tester) async {
    await _pumpScreen(tester, size: const Size(390, 1200));

    await tester.tap(find.byKey(const ValueKey('cda-detail-cda-bog')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cda-detail-sheet')), findsOneWidget);
    expect(find.text('Estado de fuente oficial'), findsOneWidget);
    expect(find.text('RUNT / MinTransporte'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  DeviceLocationGateway? gateway,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cdaCatalogProvider.overrideWithValue(AsyncValue.data(_catalog())),
        bogotaNowProvider.overrideWithValue(DateTime(2026, 8, 31)),
        deviceLocationGatewayProvider.overrideWithValue(
          gateway ?? _FakeLocationGateway(),
        ),
      ],
      child: const MaterialApp(home: CdaFinderScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

CdaCatalog _catalog() {
  final timestamp = DateTime.utc(2026, 8, 31);
  return CdaCatalog(
    source: CdaCatalogSource(
      provider: 'Ministerio de Transporte / RUNT 2.0',
      datasetId: 'epfm-5fhb',
      datasetName: 'ACTORES RUNT POR MUNICIPIO Y DEPARTAMENTO RUNT2.0',
      sourceUrl: cdaCatalogSourceUrl,
      sourceVerifiedAt: timestamp,
      latestSourceYear: 2025,
      latestSourceMonth: 7,
      latestSourceMonthName: 'JULIO',
    ),
    metrics: const CdaCatalogMetrics(
      sourceRows: 3,
      cdaSourceRows: 3,
      uniqueCdaCount: 3,
      excludedCurrentStatusCount: 0,
      municipalityCount: 2,
      departmentCount: 2,
      sponsoredCdaCount: 0,
    ),
    entries: [
      _entry(
        id: 'cda-bog',
        name: 'CDA Bogotá Uno',
        municipality: 'BOGOTA',
        department: 'BOGOTA D.C.',
      ),
      _entry(
        id: 'cda-med',
        name: 'CDA Medellín Uno',
        municipality: 'MEDELLIN',
        department: 'ANTIOQUIA',
      ),
      _entry(
        id: 'cda-med-2',
        name: 'Revisión Antioquia',
        municipality: 'MEDELLIN',
        department: 'ANTIOQUIA',
      ),
    ],
  );
}

CdaCatalogEntry _entry({
  required String id,
  required String name,
  required String municipality,
  required String department,
}) {
  final timestamp = DateTime.utc(2026, 8, 31);
  return CdaCatalogEntry(
    id: id,
    name: name,
    nit: null,
    municipality: municipality,
    department: department,
    departmentCode: '05',
    sourceYear: 2025,
    sourceMonth: 7,
    sourceMonthName: 'JULIO',
    certified: true,
    novelty: 'NO',
    sourceVerifiedAt: timestamp,
    generatedAt: timestamp,
  );
}

class _FakeLocationGateway implements DeviceLocationGateway {
  _FakeLocationGateway({
    this.point = const DeviceLocationPoint(
      latitude: 4.7110,
      longitude: -74.0721,
      accuracyMeters: 20,
    ),
  });

  final DeviceLocationPoint point;
  int requestPermissionCalls = 0;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    return DeviceLocationSuccess(point);
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.granted;
  }
}
