import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';
import 'package:picoradar/features/cda/data/cda_geography.dart';
import 'package:picoradar/features/cda/presentation/cda_finder_screen.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../vehicle_status/presentation/v01b_obligations_test_font.dart';

void main() {
  setUpAll(loadV01bObligationsTestFont);

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('CDA home keeps key words whole $size scale $scale', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          size: size,
          textScale: scale,
          productionTheme: true,
        );
        const title = 'Tu próximo CDA';
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(title),
            matching: find.byType(RichText),
          ),
        );
        for (final word in ['próximo', 'CDA']) {
          final start = title.indexOf(word);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + word.length),
          );
          expect(boxes, isNotEmpty);
          expect(
            boxes.map((box) => box.top).toSet(),
            hasLength(1),
            reason: '$word must remain readable in the CDA home title',
          );
        }
        expect(find.text('Directorio RUNT'), findsOneWidget);
        expect(find.text('Cerca de mí'), findsOneWidget);
        expect(find.text('Explorar mapa'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('home opens directory empty until query and never asks GPS', (
    tester,
  ) async {
    final gateway = _FakeLocationGateway();
    await _pumpScreen(tester, gateway: gateway);

    await tester.tap(find.byKey(const ValueKey('cda-directory-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cda-directory-initial')), findsOneWidget);
    expect(find.text('CDA Bogotá Uno'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('cda-directory-search')),
      'bogota',
    );
    await tester.pumpAndSettle();

    expect(gateway.requestPermissionCalls, 0);
    expect(find.text('CDA Bogotá Uno'), findsOneWidget);
  });

  testWidgets('map and near me explain incomplete geography gate', (
    tester,
  ) async {
    final gateway = _FakeLocationGateway();
    await _pumpScreen(tester, gateway: gateway);

    await tester.tap(find.byKey(const ValueKey('cda-use-location')));
    await tester.pumpAndSettle();

    expect(gateway.requestPermissionCalls, 0);
    expect(find.byKey(const ValueKey('cda-geography-gate')), findsOneWidget);
    expect(find.textContaining('0 de 3'), findsOneWidget);
    expect(find.textContaining('dirección respaldada'), findsOneWidget);
    expect(find.textContaining('coordenada para mapa'), findsOneWidget);
  });

  testWidgets('sponsored section is absent when no config exists', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Patrocinado'), findsNothing);
    expect(find.text('Directorio RUNT'), findsOneWidget);
  });

  testWidgets(
    'detail sheet keeps official-source and pending-location framing',
    (tester) async {
      await _pumpScreen(tester, size: const Size(390, 1200));
      await tester.tap(find.byKey(const ValueKey('cda-directory-open')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('cda-directory-search')),
        'bogota',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('cda-directory-entry-cda-bog')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Catálogo RUNT'), findsOneWidget);
      expect(
        find.textContaining('Ubicación de esta sede por verificar'),
        findsOneWidget,
      );
      expect(find.textContaining('Por confirmar'), findsOneWidget);
      expect(find.byKey(const ValueKey('cda-open-source')), findsOneWidget);
    },
  );

  testWidgets('source sheet opens the official RUNT source and reports gate', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpScreen(tester, launcher: launcher, size: const Size(390, 1200));
    await tester.tap(find.byKey(const ValueKey('cda-source-open')));
    await tester.pumpAndSettle();
    expect(find.text('Fuente y actualización'), findsOneWidget);
    expect(find.textContaining('0 CDA con dirección'), findsOneWidget);
    expect(find.textContaining('3 registros pendientes'), findsOneWidget);
    await tester.tap(find.text('Abrir fuente RUNT'));
    await tester.pump();
    expect(launcher.openedUris, [cdaCatalogSourceUrl]);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  DeviceLocationGateway? gateway,
  ExternalLauncher? launcher,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool productionTheme = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cdaCatalogProvider.overrideWithValue(AsyncValue.data(_catalog())),
        cdaGeographyProvider.overrideWithValue(AsyncValue.data(_geography())),
        bogotaNowProvider.overrideWithValue(DateTime(2026, 8, 31)),
        deviceLocationGatewayProvider.overrideWithValue(
          gateway ?? _FakeLocationGateway(),
        ),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp(
        theme: productionTheme ? buildPicoRadarTheme() : null,
        home: const CdaFinderScreen(),
      ),
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
      latestSourceYear: 2026,
      latestSourceMonth: 7,
      latestSourceMonthName: 'JULIO',
    ),
    metrics: const CdaCatalogMetrics(
      sourceRows: 3,
      cdaSourceRows: 3,
      latestSourcePeriod: '2026-07',
      globalLatestSourcePeriod: '2026-12',
      futureSourcePeriodsIgnored: true,
      latestPeriodCdaRows: 3,
      currentUniqueCdaCount: 3,
      staleHistoricalCdaExcludedCount: 0,
      certificoNotSiCount: 0,
      unsafeNoveltyCount: 0,
      ambiguousCurrentDuplicateCount: 0,
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

CdaGeography _geography() => CdaGeography(
  version: 'pending-fixture',
  catalogPeriod: '2026-07',
  approved: false,
  sites: const [],
);

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
    sourceYear: 2026,
    sourceMonth: 7,
    sourceMonthName: 'JULIO',
    certified: true,
    novelty: 'NO',
    sourceVerifiedAt: timestamp,
    generatedAt: timestamp,
  );
}

class _FakeLocationGateway implements DeviceLocationGateway {
  int requestPermissionCalls = 0;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    return const DeviceLocationSuccess(
      DeviceLocationPoint(
        latitude: 4.7110,
        longitude: -74.0721,
        accuracyMeters: 20,
      ),
    );
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

class _FakeExternalLauncher implements ExternalLauncher {
  final openedUris = <String>[];
  final calledPhones = <String>[];

  @override
  Future<bool> callPhone(String phone) async {
    calledPhones.add(phone);
    return true;
  }

  @override
  Future<bool> openExternal(String uri) async {
    openedUris.add(uri);
    return true;
  }
}
