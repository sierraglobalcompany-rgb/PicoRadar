import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';
import 'package:picoradar/features/cda/presentation/cda_finder_screen.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../vehicle_status/presentation/v01b_obligations_test_font.dart';

void main() {
  setUpAll(loadV01bObligationsTestFont);
  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('V01B CDA name and detail reachable $size scale $scale', (
        tester,
      ) async {
        final launcher = _FakeExternalLauncher();
        await _pumpScreen(
          tester,
          launcher: launcher,
          size: size,
          textScale: scale,
          productionTheme: true,
        );
        expect(tester.takeException(), isNull);
        final name = find.descendant(
          of: find.text('CDA Bogotá Uno'),
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(name);
        final word = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 4, extentOffset: 10),
        );
        expect(
          word.map((box) => box.top).toSet(),
          hasLength(1),
          reason:
              'Bogotá must remain a readable word alongside the details CTA',
        );
        final details = find.byKey(const ValueKey('cda-detail-cda-bog'));
        final actionParagraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: details, matching: find.byType(RichText)),
        );
        expect(
          actionParagraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 4, extentOffset: 12),
              )
              .map((box) => box.top)
              .toSet(),
          hasLength(1),
          reason: 'The details CTA must also keep its word readable',
        );
        await tester.ensureVisible(details);
        await tester.pumpAndSettle();
        expect(details.hitTestable(), findsOneWidget);
        expect(tester.getSize(details).height, greaterThanOrEqualTo(44));
        await tester.tap(details);
        await tester.pumpAndSettle();
        final source = find.byKey(const ValueKey('cda-open-source'));
        await tester.ensureVisible(source);
        await tester.pumpAndSettle();
        expect(source.hitTestable(), findsOneWidget);
        await tester.tap(source);
        await tester.pump();
        expect(launcher.openedUris, [cdaCatalogSourceUrl]);
        expect(find.text('julio 2026'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

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
    expect(find.text('No publicado en la fuente RUNT.'), findsOneWidget);
  });

  testWidgets('detail sheet opens directions as external map search', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpScreen(tester, launcher: launcher, size: const Size(390, 1200));

    await tester.tap(find.byKey(const ValueKey('cda-detail-cda-bog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cda-open-directions')));
    await tester.pump();

    expect(launcher.openedUris, hasLength(1));
    expect(launcher.openedUris.single, startsWith('https://www.google.com/'));
    expect(launcher.openedUris.single, contains('maps/search'));
    expect(launcher.openedUris.single, contains('CDA+Bogot'));
    expect(launcher.openedUris.single, contains('Colombia'));
  });

  testWidgets('detail sheet reports external launcher failures', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      launcher: _FakeExternalLauncher(openResult: false),
      size: const Size(390, 1200),
    );

    await tester.tap(find.byKey(const ValueKey('cda-detail-cda-bog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cda-open-directions')));
    await tester.pump();

    expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
  });

  testWidgets('detail sheet reports external launcher exceptions', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      launcher: _FakeExternalLauncher(throwOnOpen: true),
      size: const Size(390, 1200),
    );
    await tester.tap(find.byKey(const ValueKey('cda-detail-cda-bog')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('cda-open-waze')));
    await tester.tap(find.byKey(const ValueKey('cda-open-waze')));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir Waze.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({this.openResult = true, this.throwOnOpen = false});

  final bool openResult;
  final bool throwOnOpen;
  final openedUris = <String>[];
  final calledPhones = <String>[];

  @override
  Future<bool> callPhone(String phone) async {
    calledPhones.add(phone);
    return true;
  }

  @override
  Future<bool> openExternal(String uri) async {
    if (throwOnOpen) {
      throw StateError('launcher failed');
    }
    openedUris.add(uri);
    return openResult;
  }
}
