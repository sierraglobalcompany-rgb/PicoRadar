import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/trip/application/trip_route_association_resolver.dart';
import 'package:picoradar/features/trip/application/trip_route_associations.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/data/trip_draft_store.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/trip/data/trip_plan_client.dart';
import 'package:picoradar/features/trip/data/trip_route_preview_data.dart';
import 'package:picoradar/features/trip/domain/trip_draft.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';
import 'package:picoradar/features/trip/presentation/trip_route_preview_map.dart';
import 'package:picoradar/features/trip/presentation/trip_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../test_app_harness.dart';

const _evidenceLabel = 'DATOS DE PRUEBA - NO ES UN PLAN REAL';
const _evidenceDirectory = String.fromEnvironment('VIAJE_VISUAL_EVIDENCE_DIR');
const _evidenceFontPath = String.fromEnvironment('VIAJE_VISUAL_FONT_PATH');
const _evidenceIconsPath = String.fromEnvironment('VIAJE_VISUAL_ICONS_PATH');
const _surfaceKey = ValueKey('viaje-r2c-evidence-surface');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadEvidenceFonts);

  testWidgets('VIAJE-R2C test evidence is visibly and exactly labeled', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text(_evidenceLabel), findsOneWidget);
    expect(_semanticsWithLabel(_evidenceLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
  });

  testWidgets('VIAJE-R2C fixtures are absent from the normal widget config', (
    tester,
  ) async {
    await _pumpScreen(tester, showEvidenceLabel: false);

    expect(find.text(_evidenceLabel), findsNothing);
    expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
  });

  for (final viewport in const [
    (name: '360x800', size: Size(360, 800)),
    (name: '390x844', size: Size(390, 844)),
    (name: '412x915', size: Size(412, 915)),
  ]) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('VIAJE-R2C visual matrix ${viewport.name} scale $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final harness = await _pumpScreen(
          tester,
          size: viewport.size,
          textScale: scale,
        );
        final beforeReveal = _tripScroll(tester).position.pixels;

        await _submitFixture(tester, harness.client);

        expect(beforeReveal, 0);
        expect(_tripScroll(tester).position.pixels, greaterThan(0));
        expect(find.text(_evidenceLabel), findsOneWidget);
        expect(_semanticsWithLabel(_evidenceLabel), findsOneWidget);
        expect(find.text('Opciones de ruta · 3'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('trip-route-complete')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('trip-route-partial')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('trip-route-unknown')),
          findsOneWidget,
        );
        expect(find.textContaining('Total estimado de peajes'), findsWidgets);
        expect(find.textContaining('Subtotal conocido'), findsWidgets);
        expect(
          find.byKey(const ValueKey('trip-map-camera-camera-a-0')),
          findsOneWidget,
        );
        expect(find.text('Sin restricción a la hora evaluada'), findsOneWidget);
        expect(find.text('No circula a la hora evaluada'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _capture(
          tester,
          'result-${viewport.name}-scale-${scale.toStringAsFixed(1)}',
        );
        semantics.dispose();
      });
    }
  }

  testWidgets(
    'VIAJE-R2C selection updates once and preserves reading and focus',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = await _pumpScreen(
        tester,
        size: const Size(390, 844),
        textScale: 1.5,
      );

      await _submitFixture(tester, harness.client);
      final revealedOffset = _tripScroll(tester).position.pixels;
      expect(revealedOffset, greaterThan(0));
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'trip-results-focus',
      );
      expect(find.text('No circula a la hora evaluada'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('trip-map-fullscreen')),
            )
            .tooltip,
        'Ampliar mapa',
      );
      await _capture(tester, 'interaction-complete-390x844-scale-1.5');

      await _reveal(tester, const ValueKey('trip-select-route-partial'));
      final readingOffset = _tripScroll(tester).position.pixels;
      final readingFocus = FocusManager.instance.primaryFocus;
      _press(tester, const ValueKey('trip-select-route-partial'));
      await tester.pumpAndSettle();

      expect(harness.client.requests, hasLength(1));
      expect(_tripScroll(tester).position.pixels, readingOffset);
      expect(FocusManager.instance.primaryFocus, same(readingFocus));
      expect(
        find.byKey(const ValueKey('trip-toll-details-partial')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('trip-toll-details-complete')),
        findsNothing,
      );
      expect(find.text('Información desactualizada'), findsOneWidget);
      expect(
        find.textContaining('Subtotal conocido: COP 31.500'),
        findsWidgets,
      );
      expect(find.text('COP 31.500 parcial'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'interaction-partial-390x844-scale-1.5');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_tripScroll(tester).position.pixels, readingOffset);
      expect(harness.client.requests, hasLength(1));

      await _reveal(tester, const ValueKey('trip-map-fullscreen'));
      final beforeFullscreen = _tripScroll(tester).position.pixels;
      await tester.tap(find.byKey(const ValueKey('trip-map-fullscreen')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('trip-map-close-fullscreen')),
        findsOneWidget,
      );
      expect(find.text(_evidenceLabel), findsOneWidget);
      await _capture(tester, 'fullscreen-partial-390x844-scale-1.5');

      await tester.tap(find.byKey(const ValueKey('trip-map-close-fullscreen')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('trip-toll-details-partial')),
        findsOneWidget,
      );
      expect(_tripScroll(tester).position.pixels, beforeFullscreen);
      expect(harness.client.requests, hasLength(1));
      await _capture(tester, 'fullscreen-return-390x844-scale-1.5');
      semantics.dispose();
    },
  );

  testWidgets('VIAJE-R2C tile failure keeps route, cameras, and plan visible', (
    tester,
  ) async {
    final noNetworkTiles = _NoNetworkTileProvider();
    final harness = await _pumpScreen(
      tester,
      size: const Size(360, 800),
      textScale: 2,
      mapConfig: TripRouteMapConfig(
        tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
        attributionLabel: 'Mapa local de prueba',
        userAgentPackageName: 'co.picoradar.test',
        approved: true,
        tileReadyTimeout: const Duration(milliseconds: 20),
        tileProvider: noNetworkTiles,
      ),
    );

    await _submitFixture(tester, harness.client);
    await _reveal(tester, const ValueKey('trip-map-fullscreen'));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('trip-map-preview-slot'))),
      alignment: 0,
    );
    await tester.pumpAndSettle();

    expect(noNetworkTiles.requests, greaterThan(0));
    expect(
      find.textContaining('El mapa base no está disponible'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('trip-route-polyline')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-map-camera-camera-a-0')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);
    expect(find.text(_evidenceLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'tile-failure-360x800-scale-2.0');
  });
}

Future<_Harness> _pumpScreen(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool showEvidenceLabel = true,
  TripRouteMapConfig? mapConfig,
}) async {
  final preferences = MemoryPreferences();
  final client = _FixturePlanClient();
  await TripDraftStore(preferences).saveDraft(
    TripDraft(
      origin: 'Bogota',
      destination: 'Medellin',
      date: DateTime(2026, 9, 7),
      departureMinute: 360,
    ),
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        activeVehicleProvider.overrideWith((ref) async => _vehicle),
        vehicleListProvider.overrideWith((ref) async => [_vehicle]),
        tripMunicipalityCatalogProvider.overrideWith((ref) async => _catalog),
        tripPlanClientProvider.overrideWithValue(client),
        externalLauncherProvider.overrideWithValue(const _FixtureLauncher()),
        tripRestrictionProvider.overrideWith(
          (ref, query) async => _dateRestriction(query.municipality),
        ),
        tripInstantRestrictionProvider.overrideWith(
          (ref, query) async => _instantRestriction(query),
        ),
        tripTollInventoryProvider.overrideWith((ref) async => _tollInventory),
        tripCameraPackSnapshotProvider.overrideWith(
          (ref) async => _cameraSnapshot,
        ),
        tripRouteMapConfigProvider.overrideWithValue(
          mapConfig ?? _neutralMapConfig,
        ),
        tripRouteAssociationResolverProvider.overrideWithValue(
          CachedTripRouteAssociationResolver(
            compute: (request) async => const TripRouteAssociator().associate(
              routeId: request.routeId,
              geometry: request.geometry,
              tolls: request.tolls,
              cameras: request.cameras,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          fontFamily: _evidenceFontPath.isEmpty ? null : 'EvidenceFont',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(
            key: _surfaceKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: showEvidenceLabel ? 40 : 0),
                  child: child!,
                ),
                if (showEvidenceLabel)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: _EvidenceBanner(),
                  ),
              ],
            ),
          ),
        ),
        home: const TripScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(client: client);
}

Future<void> _submitFixture(
  WidgetTester tester,
  _FixturePlanClient client,
) async {
  await _reveal(tester, const ValueKey('trip-standard-vehicle'));
  await tester.tap(find.byKey(const ValueKey('trip-standard-vehicle')));
  await tester.pumpAndSettle();
  _press(tester, const ValueKey('trip-preview'));
  await tester.pump();
  expect(client.requests, hasLength(1));
  client.complete(_fixturePlan(client.requests.single));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
}

void _press(WidgetTester tester, Key key) {
  final widget = tester.widget(find.byKey(key));
  switch (widget) {
    case ButtonStyleButton(:final onPressed):
      onPressed?.call();
    case IconButton(:final onPressed):
      onPressed?.call();
    default:
      fail('The fixture control $key is not pressable.');
  }
}

ScrollableState _tripScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first);

Finder _semanticsWithLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

Future<void> _loadEvidenceFonts() async {
  if (_evidenceDirectory.isEmpty) return;
  final textFont = File(_evidenceFontPath);
  final iconFont = File(_evidenceIconsPath);
  if (_evidenceFontPath.isEmpty || !textFont.existsSync()) {
    fail('VIAJE_VISUAL_FONT_PATH must name a local font for screenshots.');
  }
  if (_evidenceIconsPath.isEmpty || !iconFont.existsSync()) {
    fail('VIAJE_VISUAL_ICONS_PATH must name the local Material Icons font.');
  }
  final bytes = await textFont.readAsBytes();
  final loader = FontLoader('EvidenceFont')
    ..addFont(Future.value(bytes.buffer.asByteData()));
  await loader.load();
  final iconBytes = await iconFont.readAsBytes();
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(iconBytes.buffer.asByteData()));
  await iconLoader.load();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_evidenceDirectory.isEmpty) return;
  final directory = Directory(_evidenceDirectory);
  directory.createSync(recursive: true);
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_surfaceKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) fail('Could not encode visual evidence $name.');
      await File('${directory.path}${Platform.pathSeparator}$name.png')
          .writeAsBytes(data!.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
}

class _EvidenceBanner extends StatelessWidget {
  const _EvidenceBanner();

  @override
  Widget build(BuildContext context) => Semantics(
    label: _evidenceLabel,
    container: true,
    child: Container(
      width: double.infinity,
      height: 40,
      color: const Color(0xFFFFE8A3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: const ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _evidenceLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF3D2B00),
              fontFamily: 'EvidenceFont',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Harness {
  const _Harness({required this.client});

  final _FixturePlanClient client;
}

class _FixturePlanClient implements TripPlanClient {
  final requests = <TripPlanRequest>[];
  final _completions = <Completer<TripPlan>>[];

  @override
  Future<TripPlan> preview(
    TripPlanRequest request, {
    CancelToken? cancelToken,
  }) {
    requests.add(request);
    final completion = Completer<TripPlan>();
    _completions.add(completion);
    return completion.future;
  }

  void complete(TripPlan plan) => _completions.single.complete(plan);
}

class _FixtureLauncher implements ExternalLauncher {
  const _FixtureLauncher();

  @override
  Future<bool> callPhone(String phone) async => false;

  @override
  Future<bool> openExternal(String uri) async => false;
}

class _NoNetworkTileProvider extends TileProvider {
  var requests = 0;

  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    requests++;
    return const _PendingImageProvider();
  }
}

class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  const _PendingImageProvider();

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PendingImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

TripEndpointRestriction _dateRestriction(TripMunicipality? municipality) =>
    TripEndpointRestriction(
      status: municipality?.code == '05001'
          ? RestrictionDayStatus.restricted
          : RestrictionDayStatus.allowed,
      sourceUrl: 'https://example.test/restrictions',
    );

TripEndpointRestriction _instantRestriction(TripInstantRestrictionQuery query) {
  if (query.municipality?.code == '11001') {
    return TripEndpointRestriction(
      status: RestrictionDayStatus.allowed,
      instantStatus: RestrictionStatus.allowed,
      sourceUrl: 'https://example.test/bogota-rule',
      verifiedAt: DateTime.utc(2026, 9, 1, 12),
      evaluatedAtUtc: query.instantUtc,
    );
  }
  if (query.instantUtc.hour < 20) {
    return TripEndpointRestriction(
      status: RestrictionDayStatus.restricted,
      instantStatus: RestrictionStatus.restricted,
      windows: const [RestrictionDayWindow(startMinute: 780, endMinute: 1200)],
      sourceUrl: 'https://example.test/medellin-rule',
      verifiedAt: DateTime.utc(2026, 9, 1, 12),
      evaluatedAtUtc: query.instantUtc,
    );
  }
  if (query.instantUtc.hour < 22) {
    return TripEndpointRestriction(
      status: RestrictionDayStatus.stale,
      instantStatus: RestrictionStatus.stale,
      reason: 'stale_data',
      sourceUrl: 'https://example.test/medellin-rule',
      evaluatedAtUtc: query.instantUtc,
    );
  }
  return TripEndpointRestriction(
    status: RestrictionDayStatus.unknown,
    instantStatus: RestrictionStatus.unknown,
    reason: 'no_coverage',
    evaluatedAtUtc: query.instantUtc,
  );
}

TripPlan _fixturePlan(TripPlanRequest request) => TripPlan(
  requestId: request.requestId,
  generatedAtUtc: DateTime.utc(2026, 9, 6, 12),
  provider: 'Proveedor local de prueba',
  attribution: _evidenceLabel,
  origin: const TripResolvedPoint(
    label: 'Referencia Bogota',
    latitude: 4.711,
    longitude: -74.072,
  ),
  destination: const TripResolvedPoint(
    label: 'Referencia Medellin',
    latitude: 6.245,
    longitude: -75.575,
  ),
  routes: [
    _route(
      id: 'complete',
      summary: 'Ruta central de prueba',
      distanceMeters: 414800,
      durationSeconds: 28800,
      geometry: _completeGeometry,
      tolls: TripTolls(
        coverage: TripTollCoverage.complete,
        vehicleCategory: 'car',
        stationCount: 2,
        payableCount: 2,
        totalMinor: 5800000,
        charges: const [
          TripTollCharge(
            name: 'Peaje Alfa de prueba',
            amountMinor: 2800000,
            effectiveAt: '2026-09-01',
            sourceUrl: 'https://example.test/toll-a',
          ),
          TripTollCharge(
            name: 'Peaje Beta de prueba',
            amountMinor: 3000000,
            effectiveAt: '2026-09-01',
            sourceUrl: 'https://example.test/toll-b',
          ),
        ],
      ),
    ),
    _route(
      id: 'partial',
      summary: 'Alternativa occidental con datos parciales',
      distanceMeters: 432600,
      durationSeconds: 36000,
      geometry: _partialGeometry,
      tolls: TripTolls(
        coverage: TripTollCoverage.partial,
        vehicleCategory: 'car',
        stationCount: 4,
        payableCount: 2,
        subtotalMinor: 3150000,
        missingRates: 2,
        charges: const [
          TripTollCharge(
            name: 'Peaje Gamma de prueba',
            amountMinor: 3150000,
            effectiveAt: '2026-08-15',
            sourceUrl: 'https://example.test/toll-c',
          ),
          TripTollCharge(name: 'Peaje sin tarifa confirmada'),
        ],
      ),
    ),
    _route(
      id: 'unknown',
      summary: 'Alternativa sin tarifas verificadas',
      distanceMeters: 448200,
      durationSeconds: 43200,
      geometry: _unknownGeometry,
      tolls: TripTolls(
        coverage: TripTollCoverage.unknown,
        vehicleCategory: 'car',
        stationCount: 3,
      ),
    ),
  ],
);

TripRouteOption _route({
  required String id,
  required String summary,
  required int distanceMeters,
  required int durationSeconds,
  required List<TripCoordinate> geometry,
  required TripTolls tolls,
}) => TripRouteOption(
  id: id,
  summary: summary,
  distanceMeters: distanceMeters,
  durationSeconds: durationSeconds,
  timeBasis: 'static',
  geometry: geometry,
  tolls: tolls,
);

const _catalog = TripMunicipalityCatalog(
  records: [
    TripMunicipality(
      code: '11001',
      municipality: 'Bogota',
      department: 'Bogota',
      jurisdictionId: 'bogota',
    ),
    TripMunicipality(
      code: '05001',
      municipality: 'Medellin',
      department: 'Antioquia',
      jurisdictionId: 'medellin',
    ),
  ],
);

final _vehicle = VehicleProfile(
  id: 'visual-fixture-vehicle',
  plate: 'TST123',
  kind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const _completeGeometry = [
  TripCoordinate(latitude: 4.711, longitude: -74.072),
  TripCoordinate(latitude: 5.450, longitude: -74.700),
  TripCoordinate(latitude: 6.245, longitude: -75.575),
];
const _partialGeometry = [
  TripCoordinate(latitude: 4.711, longitude: -74.072),
  TripCoordinate(latitude: 5.350, longitude: -74.950),
  TripCoordinate(latitude: 6.245, longitude: -75.575),
];
const _unknownGeometry = [
  TripCoordinate(latitude: 4.711, longitude: -74.072),
  TripCoordinate(latitude: 5.650, longitude: -74.500),
  TripCoordinate(latitude: 6.245, longitude: -75.575),
];

final _tollInventory = TollInventoryDataset(
  version: 'visual-tolls-test-v1',
  sourceTimestamp: DateTime.utc(2026, 8, 31),
  records: const [
    TollInventoryRecord(
      id: 'toll-a',
      name: 'Peaje inventariado de prueba',
      exactSourceName: 'PEAJE INVENTARIADO DE PRUEBA',
      department: 'Cundinamarca',
      recordKind: TollRecordKind.physicalStation,
      operationStatusRaw: 'Inventariado',
      operationClassification:
          TollOperationClassification.inventoriedOperationNotConfirmed,
      latitude: 5.450,
      longitude: -74.700,
      chargeEventVerified: false,
      tariffsBySourceCategoryCop: {
        'category_1': null,
        'category_2': null,
        'category_3': null,
        'category_4': null,
        'category_5': null,
        'category_6': null,
        'category_7': null,
      },
      inventorySource: 'https://example.test/tolls',
      gpsSource: 'https://example.test/tolls-gps',
    ),
  ],
);

const _cameraSnapshot = TripCameraPackSnapshot(
  version: 'visual-cameras-test-v1',
  pack: CameraPack(
    source: CameraPackSource(
      name: 'ANSV - datos locales de prueba',
      pageUrl: 'https://example.test/cameras',
      dataUrl: 'https://example.test/cameras.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras: [
      TrafficCamera(
        id: 'camera-a',
        department: 'Cundinamarca',
        municipality: 'Guaduas',
        jurisdiction: 'Guaduas',
        address: 'Corredor local de prueba',
        latitude: 5.450,
        longitude: -74.700,
        status: 'Aprobada',
        technology: null,
        kind: CameraKind.mixed,
        speedLimitKmh: null,
      ),
    ],
  ),
);

const _neutralMapConfig = TripRouteMapConfig(
  tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
  attributionLabel: 'Mapa neutral local de prueba',
  userAgentPackageName: 'co.picoradar.test',
  forceNeutralFallback: true,
);
