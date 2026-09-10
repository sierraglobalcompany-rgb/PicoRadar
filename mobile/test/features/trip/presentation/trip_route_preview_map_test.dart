import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/trip/application/trip_route_associations.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';
import 'package:picoradar/features/trip/presentation/trip_route_preview_map.dart';

void main() {
  testWidgets(
    'performance: marker selection retains the route polyline widget',
    (tester) async {
      await tester.pumpWidget(_app(config: _neutralConfig()));
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('trip-route-polyline'));
      final original = tester.widget<PolylineLayer>(finder);

      _openTollDetails(tester);
      await tester.pump();
      expect(find.text('Peaje de prueba'), findsWidgets);
      expect(tester.widget<PolylineLayer>(finder), same(original));

      _openCameraDetails(tester);
      await tester.pump();
      expect(tester.widget<PolylineLayer>(finder), same(original));
      expect(find.byKey(const ValueKey('trip-route-start')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-route-end')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'performance: changed route geometry replaces the cached polyline',
    (tester) async {
      await tester.pumpWidget(_app(config: _neutralConfig()));
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('trip-route-polyline'));
      final original = tester.widget<PolylineLayer>(finder);
      const nextGeometry = [
        TripCoordinate(latitude: 6.239, longitude: -75.580),
        TripCoordinate(latitude: 6.240, longitude: -75.570),
        TripCoordinate(latitude: 6.250, longitude: -75.570),
      ];
      await tester.pumpWidget(
        _app(config: _neutralConfig(), geometry: nextGeometry),
      );
      await tester.pumpAndSettle();
      final next = tester.widget<PolylineLayer>(finder);
      expect(next, isNot(same(original)));
      expect(next.polylines.single.points.first.latitude, 6.239);
      expect(next.polylines.single.points, hasLength(nextGeometry.length));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders route endpoints and honest nearby layers', (
    tester,
  ) async {
    await tester.pumpWidget(_app(config: _neutralConfig()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-route-polyline')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-route-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-route-end')), findsOneWidget);
    expect(find.textContaining('1 peaje inventariado próximo'), findsOneWidget);
    expect(find.textContaining('1 cámara registrada próxima'), findsOneWidget);
    expect(find.textContaining('tarifas locales cargando'), findsOneWidget);
  });

  testWidgets('toll marker shows owner tariff by physical id', (tester) async {
    await tester.pumpWidget(
      _app(config: _neutralConfig(), tollTariffCatalog: _tariffCatalog()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Cat I disponible para 1 de 1'), findsOneWidget);

    _openTollDetails(tester);
    await tester.pump();

    expect(find.text('Peaje de prueba'), findsWidgets);
    expect(find.textContaining('Tarifas propias'), findsOneWidget);
    expect(find.textContaining(r'Cat I: $18.500'), findsOneWidget);
    expect(find.textContaining('Oficial · 2026-09-08'), findsOneWidget);
    expect(
      find.textContaining('Este punto físico no confirma un cobro activo'),
      findsOneWidget,
    );
  });

  testWidgets('zero nearby cameras never claims the route is camera-free', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        cameraPack: _cameraPack(cameras: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('0 cámaras próximas'), findsOneWidget);
    expect(
      find.textContaining('No significa ruta libre de cámaras'),
      findsOneWidget,
    );
  });

  testWidgets('toll historical and camera marker targets are at least 48x48', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        tollInventory: _tollDataset(
          records: [
            _toll(),
            _toll(
              id: 'historical',
              longitude: -75.576,
              classification:
                  TollOperationClassification.nonOperationalHistorical,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('trip-map-toggle-historical-tolls')),
    );
    await tester.pump();

    for (final key in const [
      'trip-map-toll-toll-1-0',
      'trip-map-toll-historical-0',
      'trip-map-camera-camera-1-0',
    ]) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
  });

  testWidgets('tiles stay disabled when any explicit gate is invalid', (
    tester,
  ) async {
    for (final config in [
      TripRouteMapConfig(
        tileUrlTemplate: 'http://tiles.test/{z}/{x}/{y}.png',
        attributionLabel: 'Proveedor inseguro',
        userAgentPackageName: 'co.picoradar.app.dev',
        approved: true,
        tileProvider: _NeverTileProvider(),
      ),
      TripRouteMapConfig(
        tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
        attributionLabel: 'Proveedor sin agente',
        userAgentPackageName: '',
        approved: true,
        tileProvider: _NeverTileProvider(),
      ),
      TripRouteMapConfig(
        tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
        attributionLabel: '',
        userAgentPackageName: 'co.picoradar.app.dev',
        approved: true,
        tileProvider: _NeverTileProvider(),
      ),
    ]) {
      await tester.pumpWidget(_app(config: config));
      await tester.pump();

      expect(find.byType(TileLayer), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('enabling an approved tile config starts its bounded timeout', (
    tester,
  ) async {
    final provider = _NeverTileProvider();
    TripRouteMapConfig config({required bool approved}) => TripRouteMapConfig(
      tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
      attributionLabel: 'Proveedor cartográfico de prueba',
      userAgentPackageName: 'co.picoradar.app.dev',
      approved: approved,
      tileReadyTimeout: const Duration(milliseconds: 20),
      tileProvider: provider,
    );

    await tester.pumpWidget(_app(config: config(approved: false)));
    expect(find.byType(TileLayer), findsNothing);

    await tester.pumpWidget(_app(config: config(approved: true)));
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.byType(TileLayer), findsNothing);
    expect(find.textContaining('mapa base no está disponible'), findsOneWidget);
  });

  testWidgets('layer toggles hide pins while keeping the supplied snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(_app(config: _neutralConfig()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-toggle-route')));
    await tester.pump();
    expect(find.byKey(const ValueKey('trip-route-polyline')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trip-map-toggle-tolls')));
    await tester.pump();
    expect(find.byKey(const ValueKey('trip-map-toll-toll-1-0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trip-map-toggle-cameras')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('trip-map-camera-camera-1-0')),
      findsNothing,
    );
  });

  testWidgets(
    'shows unique and passage counts while historical tolls require opt-in',
    (tester) async {
      const repeatedRoute = [
        TripCoordinate(latitude: 6.240, longitude: -75.580),
        TripCoordinate(latitude: 6.240, longitude: -75.570),
        TripCoordinate(latitude: 6.250, longitude: -75.570),
        TripCoordinate(latitude: 6.250, longitude: -75.580),
        TripCoordinate(latitude: 6.240, longitude: -75.580),
        TripCoordinate(latitude: 6.240, longitude: -75.570),
      ];
      await tester.pumpWidget(
        _app(
          config: _neutralConfig(),
          geometry: repeatedRoute,
          tollInventory: _tollDataset(
            records: [
              _toll(),
              _toll(
                id: 'historical',
                longitude: -75.576,
                classification:
                    TollOperationClassification.nonOperationalHistorical,
              ),
            ],
          ),
          cameraPack: _cameraPack(cameras: [_camera(longitude: -75.574)]),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '1 peaje inventariado próximo: '
          '1 ubicación única · 2 pasos candidatos',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '1 cámara registrada próxima al recorrido: '
          '1 ubicación única · 2 pasos candidatos',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('trip-map-toll-historical-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('trip-map-toggle-historical-tolls')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('trip-map-toggle-historical-tolls')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('trip-map-toll-historical-0')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Históricos visibles: 1 ubicación única · 2 pasos candidatos',
        ),
        findsOneWidget,
      );
      _openTollDetailsById(tester, 'historical');
      await tester.pump();
      expect(
        find.text('Registro histórico reportado como no operativo'),
        findsOneWidget,
      );
      expect(
        find.textContaining('no confirma un cobro activo'),
        findsOneWidget,
      );
    },
  );

  testWidgets('supports map drag, zoom controls and reframe', (tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      _app(config: _neutralConfig(), mapController: controller),
    );
    await tester.pumpAndSettle();
    final initialCenter = controller.camera.center;
    final initialZoom = controller.camera.zoom;

    await tester.drag(
      find.byKey(const ValueKey('trip-route-map')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.camera.center, isNot(initialCenter));

    await tester.tap(find.byKey(const ValueKey('trip-map-zoom-in')));
    await tester.pump();
    expect(controller.camera.zoom, greaterThan(initialZoom));

    await tester.tap(find.byKey(const ValueKey('trip-map-reframe')));
    await tester.pump();
    expect(controller.camera.zoom, lessThanOrEqualTo(16));
  });

  testWidgets('supports pinch zoom with the supplied association snapshot', (
    tester,
  ) async {
    final controller = MapController();
    await tester.pumpWidget(
      _app(config: _neutralConfig(), mapController: controller),
    );
    await tester.pumpAndSettle();
    final map = find.byKey(const ValueKey('trip-route-map'));
    final center = tester.getCenter(map);
    final initialZoom = controller.camera.zoom;
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(center - const Offset(30, 0));
    await second.down(center + const Offset(30, 0));
    await tester.pump();
    await first.moveTo(center - const Offset(80, 0));
    await second.moveTo(center + const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, greaterThan(initialZoom));
  });

  testWidgets('reframes when the selected route geometry changes', (
    tester,
  ) async {
    final controller = MapController();
    await tester.pumpWidget(
      _app(config: _neutralConfig(), mapController: controller),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        routeId: 'route-b',
        geometry: const [
          TripCoordinate(latitude: 4.700, longitude: -74.120),
          TripCoordinate(latitude: 4.710, longitude: -74.100),
        ],
        mapController: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.camera.center.latitude, closeTo(4.705, 0.01));
    expect(controller.camera.center.longitude, closeTo(-74.110, 0.01));
  });

  testWidgets('clears an open marker detail when the route changes', (
    tester,
  ) async {
    final tollInventory = _tollDataset();
    final cameraPack = _cameraPack();
    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        tollInventory: tollInventory,
        cameraPack: cameraPack,
      ),
    );
    await tester.pumpAndSettle();
    _openTollDetails(tester);
    await tester.pump();
    expect(find.text('Peaje de prueba'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        routeId: 'route-b',
        tollInventory: tollInventory,
        cameraPack: cameraPack,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Peaje de prueba'), findsNothing);
  });

  testWidgets('clears marker detail when either dataset identity changes', (
    tester,
  ) async {
    final records = [_toll()];
    final originalTolls = _tollDataset(records: records);
    final originalCameras = _cameraPack();
    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        tollInventory: originalTolls,
        cameraPack: originalCameras,
      ),
    );
    await tester.pumpAndSettle();
    _openTollDetails(tester);
    await tester.pump();

    final updatedTolls = _tollDataset(version: 'v2', records: records);
    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        tollInventory: updatedTolls,
        cameraPack: originalCameras,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Peaje de prueba'), findsNothing);

    _openCameraDetails(tester);
    await tester.pump();
    expect(find.text('Vía de prueba'), findsOneWidget);
    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        tollInventory: updatedTolls,
        cameraPack: _cameraPack(fetchedAtUtc: '2026-09-01T00:00:00Z'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vía de prueba'), findsNothing);
  });

  testWidgets('camera pack version change clears an open camera detail', (
    tester,
  ) async {
    final tollInventory = _tollDataset();
    final cameraPack = _cameraPack();
    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        tollInventory: tollInventory,
        cameraPack: cameraPack,
      ),
    );
    await tester.pumpAndSettle();
    _openCameraDetails(tester);
    await tester.pump();

    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        tollInventory: tollInventory,
        cameraPack: cameraPack,
        cameraPackVersion: '2026.09.01-ansv',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vía de prueba'), findsNothing);
  });

  testWidgets('marker sheets preserve uncertainty and provenance', (
    tester,
  ) async {
    await tester.pumpWidget(_app(config: _neutralConfig()));
    await tester.pumpAndSettle();

    _openTollDetails(tester);
    await tester.pump();
    expect(find.text('Peaje de prueba'), findsOneWidget);
    expect(find.textContaining('no confirma un cobro activo'), findsOneWidget);
    expect(find.textContaining('Tarifas propias cargando'), findsOneWidget);
    expect(find.text('Inventario v1 · corte 2026-08-31'), findsOneWidget);
    expect(
      find.text('El corte no confirma vigencia operativa.'),
      findsOneWidget,
    );
    expect(
      find.text('Fuente inventario: https://example.test/inventory'),
      findsOneWidget,
    );
    expect(find.text('Fuente GPS: https://example.test/gps'), findsOneWidget);

    _openCameraDetails(tester);
    await tester.pump();
    expect(find.text('Vía de prueba'), findsOneWidget);
    expect(find.textContaining('sentido no está confirmado'), findsOneWidget);
    expect(
      find.text('Pack 2026.08.31-ansv · captura 2026-08-31'),
      findsOneWidget,
    );
    expect(
      find.text('La captura no confirma vigencia operativa.'),
      findsOneWidget,
    );
    expect(find.text('Fuente: ANSV'), findsOneWidget);
    expect(find.text('https://example.test/cameras'), findsOneWidget);
  });

  testWidgets('missing geometry shows fallback and does not build a map', (
    tester,
  ) async {
    await tester.pumpWidget(_app(config: _neutralConfig(), geometry: const []));

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('no incluyó geometría'), findsOneWidget);
  });

  testWidgets('repeated coordinates show the honest no-route fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        config: _neutralConfig(),
        geometry: const [
          TripCoordinate(latitude: 6.24, longitude: -75.58),
          TripCoordinate(latitude: 6.24, longitude: -75.58),
        ],
      ),
    );

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byKey(const ValueKey('trip-route-polyline')), findsNothing);
    expect(find.byKey(const ValueKey('trip-route-start')), findsNothing);
    expect(find.byKey(const ValueKey('trip-route-end')), findsNothing);
    expect(find.textContaining('no incluyó geometría'), findsOneWidget);
  });

  testWidgets('tile timeout keeps vector state and offers bounded retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        config: TripRouteMapConfig(
          tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
          attributionLabel: 'Proveedor cartográfico de prueba',
          userAgentPackageName: 'co.picoradar.app.dev',
          approved: true,
          tileReadyTimeout: const Duration(milliseconds: 20),
          tileProvider: _NeverTileProvider(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.byKey(const ValueKey('trip-route-polyline')), findsOneWidget);
    expect(find.textContaining('mapa base no está disponible'), findsOneWidget);
    expect(find.text('Reintentar mapa'), findsOneWidget);

    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Reintentar mapa'))
        .onPressed!();
    await tester.pump();
    expect(find.byKey(const ValueKey('trip-route-polyline')), findsOneWidget);
  });

  testWidgets('tile load error switches immediately to the neutral fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        config: TripRouteMapConfig(
          tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
          attributionLabel: 'Proveedor cartográfico de prueba',
          userAgentPackageName: 'co.picoradar.app.dev',
          approved: true,
          tileReadyTimeout: const Duration(seconds: 5),
          tileProvider: _NeverTileProvider(),
        ),
      ),
    );
    final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
    tileLayer.errorTileCallback!(
      _testTileImage(),
      StateError('synthetic tile failure'),
      StackTrace.current,
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('mapa base no está disponible'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-route-polyline')), findsOneWidget);
  });

  testWidgets('exposes legible attribution and expandable preview', (
    tester,
  ) async {
    await tester.pumpWidget(_app(config: _neutralConfig()));

    expect(find.text('Proveedor cartográfico de prueba'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-map-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.text('Vista previa de la ruta'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-map-close-fullscreen')),
      findsOneWidget,
    );
  });

  testWidgets('fullscreen reuses the immutable association snapshot', (
    tester,
  ) async {
    final snapshot = const TripRouteAssociator().associate(
      routeId: 'route-a',
      geometry: const [
        TripCoordinate(latitude: 6.240, longitude: -75.580),
        TripCoordinate(latitude: 6.240, longitude: -75.570),
        TripCoordinate(latitude: 6.250, longitude: -75.570),
      ],
      tolls: [_toll()],
      cameras: [_camera()],
    );
    await tester.pumpWidget(
      _app(config: _neutralConfig(), associations: snapshot),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-fullscreen')));
    await tester.pumpAndSettle();

    expect(find.text('Vista previa de la ruta'), findsOneWidget);
    final fullscreen = tester.widget<TripRoutePreviewMap>(
      find.byType(TripRoutePreviewMap).last,
    );
    expect(identical(fullscreen.associations, snapshot), isTrue);
  });

  testWidgets('fullscreen fits 360x780 at 2x text scale without clipping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(config: _neutralConfig(), textScale: 2, scrollable: true),
    );
    await tester.pumpAndSettle();

    final openFullscreen = find.byKey(const ValueKey('trip-map-fullscreen'));
    await tester.ensureVisible(openFullscreen);
    await tester.pump();
    await tester.tap(openFullscreen);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Vista previa de la ruta'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-map-close-fullscreen')).hitTestable(),
      findsOneWidget,
    );

    final fullscreen = find.byType(TripRoutePreviewMap).last;
    final viewport = find.byKey(const ValueKey('trip-map-fullscreen-scroll'));
    expect(viewport, findsOneWidget);
    for (final summary in [
      find.descendant(
        of: fullscreen,
        matching: find.textContaining('tarifas locales cargando'),
      ),
      find.descendant(
        of: fullscreen,
        matching: find.textContaining('cámara registrada próxima'),
      ),
    ]) {
      expect(summary, findsOneWidget);
      await tester.ensureVisible(summary);
      await tester.pumpAndSettle();
      final viewportRect = tester.getRect(viewport);
      final summaryRect = tester.getRect(summary);
      expect(summaryRect.top, greaterThanOrEqualTo(viewportRect.top));
      expect(summaryRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
    }
  });
}

Widget _app({
  required TripRouteMapConfig config,
  String routeId = 'route-a',
  List<TripCoordinate> geometry = const [
    TripCoordinate(latitude: 6.240, longitude: -75.580),
    TripCoordinate(latitude: 6.240, longitude: -75.570),
    TripCoordinate(latitude: 6.250, longitude: -75.570),
  ],
  MapController? mapController,
  TripRouteAssociations? associations,
  TollInventoryDataset? tollInventory,
  TollTariffCatalog? tollTariffCatalog,
  CameraPack? cameraPack,
  String cameraPackVersion = '2026.08.31-ansv',
  double textScale = 1,
  bool scrollable = false,
}) {
  final tolls = tollInventory ?? _tollDataset();
  final cameras = cameraPack ?? _cameraPack();
  final snapshot =
      associations ??
      const TripRouteAssociator().associate(
        routeId: routeId,
        geometry: geometry,
        tolls: tolls.records,
        cameras: cameras.cameras,
      );
  final preview = Center(
    child: SizedBox(
      width: 360,
      child: TripRoutePreviewMap(
        routeId: routeId,
        geometry: geometry,
        tollInventory: tolls,
        tollTariffCatalog: tollTariffCatalog,
        cameraPack: cameras,
        cameraPackVersion: cameraPackVersion,
        associations: snapshot,
        config: config,
        mapController: mapController,
      ),
    ),
  );
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: scrollable ? SingleChildScrollView(child: preview) : preview,
    ),
  );
}

void _openTollDetails(WidgetTester tester) {
  _openTollDetailsById(tester, 'toll-1');
}

void _openTollDetailsById(WidgetTester tester, String id) {
  tester
      .widget<IconButton>(
        find.descendant(
          of: find.byKey(ValueKey('trip-map-toll-$id-0')),
          matching: find.byType(IconButton),
        ),
      )
      .onPressed!();
}

void _openCameraDetails(WidgetTester tester) {
  tester
      .widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('trip-map-camera-camera-1-0')),
          matching: find.byType(IconButton),
        ),
      )
      .onPressed!();
}

TollInventoryDataset _tollDataset({
  String version = 'v1',
  List<TollInventoryRecord>? records,
}) => TollInventoryDataset(
  version: version,
  sourceTimestamp: DateTime.utc(2026, 8, 31),
  records: records ?? [_toll()],
);

CameraPack _cameraPack({
  String fetchedAtUtc = '2026-08-31T00:00:00Z',
  List<TrafficCamera>? cameras,
}) => CameraPack(
  source: CameraPackSource(
    name: 'ANSV',
    pageUrl: 'https://example.test/cameras',
    dataUrl: 'https://example.test/cameras.json',
    fetchedAtUtc: fetchedAtUtc,
  ),
  cameras: cameras ?? [_camera()],
);

TripRouteMapConfig _neutralConfig() => const TripRouteMapConfig(
  tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
  attributionLabel: 'Proveedor cartográfico de prueba',
  userAgentPackageName: 'co.picoradar.app.dev',
  forceNeutralFallback: true,
);

TollInventoryRecord _toll({
  String id = 'toll-1',
  String name = 'Peaje de prueba',
  double latitude = 6.2402,
  double longitude = -75.575,
  TollOperationClassification classification =
      TollOperationClassification.inventoriedOperationNotConfirmed,
}) => TollInventoryRecord(
  id: id,
  name: name,
  exactSourceName: name.toUpperCase(),
  department: 'Antioquia',
  recordKind: TollRecordKind.physicalStation,
  operationStatusRaw: 'Inventariado',
  operationClassification: classification,
  latitude: latitude,
  longitude: longitude,
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
  inventorySource: 'https://example.test/inventory',
  gpsSource: 'https://example.test/gps',
);

TollTariffCatalog _tariffCatalog() => TollTariffCatalog(
  version: '2026.09.08-upload-a',
  currency: 'COP',
  amountUnit: 'whole_pesos',
  source: const TollTariffSource(
    fileName: 'PicoRadar_Peajes_Colombia_AUDITADO_2026-09-08.xlsx',
    sha256: 'source-sha',
    consultationCutoffAsStated: '2026-09-08',
    independentExternalReverification: false,
    jsonFileName: 'tolls_tariffs_source_2026_09_08.json',
    jsonSha256: 'json-sha',
  ),
  counts: const TollTariffCounts(
    stations: 1,
    generalRates: 1,
    specialRates: 0,
    numericGeneralRates: 1,
    officialGeneralRates: 1,
    secondaryGeneralRates: 0,
    candidatesOutsideBase: 0,
  ),
  stations: [
    TollTariffStation(
      id: 'toll-1',
      name: 'Peaje de prueba',
      department: 'Antioquia',
      latitude: 6.2402,
      longitude: -75.575,
      operationStatus: 'Tarifa publicada',
      publicationControl: 'VALIDAR_RUTA_Y_CATEGORIA',
      routeRule: 'Aplicar una tarifa por paso según categoría y sentido.',
      logicalChargeGroup: null,
      evidenceQuality: 'OFICIAL_2026',
      generalRates: const [
        TollTariffRate(
          categoryCode: 'I',
          vehicleDescription: 'Clasificación local I',
          rateType: 'General',
          amountCop: 18500,
          collectionMultiplier: 1,
          boothBaseChargeCop: 18500,
          dataStatus: 'PUBLICADA_2026',
          sourceDate: '2026-09-08',
          sourceDatePrecision: 'Día',
          consultedOn: '2026-09-08',
          sourceType: 'Oficial',
          amountSourceId: 'OWNER',
          amountSourceUrl: 'https://example.test/tarifas',
          chargeSourceUrl: 'https://example.test/tarifas',
          conditions: 'No sumar inventario.',
          publicationControl: 'VALIDAR_RUTA_Y_CATEGORIA',
        ),
      ],
      specialRates: const [],
    ),
  ],
);

TrafficCamera _camera({
  String id = 'camera-1',
  double latitude = 6.2402,
  double longitude = -75.576,
}) => TrafficCamera(
  id: id,
  department: 'Antioquia',
  municipality: 'Medellín',
  jurisdiction: 'Medellín',
  address: 'Vía de prueba',
  latitude: latitude,
  longitude: longitude,
  status: 'Aprobada',
  technology: null,
  kind: CameraKind.mixed,
  speedLimitKmh: null,
);

class _NeverTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return const _NeverImageProvider();
  }
}

TileImage _testTileImage() => TileImage(
  vsync: const TestVSync(),
  coordinates: const TileCoordinates(0, 0, 0),
  imageProvider: const _NeverImageProvider(),
  onLoadComplete: (_) {},
  onLoadError: (_, _, _) {},
  tileDisplay: const TileDisplay.instantaneous(),
  errorImage: null,
  cancelLoading: Completer<void>(),
);

class _NeverImageProvider extends ImageProvider<_NeverImageProvider> {
  const _NeverImageProvider();

  @override
  Future<_NeverImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_NeverImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _NeverImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}
