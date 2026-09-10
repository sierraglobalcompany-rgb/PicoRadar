import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/presentation/driving_map_episode.dart';
import 'package:picoradar/features/driving/presentation/driving_proximity_map.dart';
import 'package:picoradar/features/driving/presentation/driving_radar.dart';

const _mapKey = ValueKey('driving-real-mini-map');
const _boundaryKey = ValueKey('map-pixels');
const _radarKey = ValueKey('driving-map-offline-fallback');

void main() {
  setUp(CameraMapEpisodeCache.resetForTesting);

  test(
    'real geographic positions fit exact anchors for every cone and heading',
    () {
      for (final size in const [
        Size(180, 156),
        Size(390, 270),
        Size(412, 320),
      ]) {
        for (final cone in [45, 90, 180, 360]) {
          for (final heading in [0.0, 45.0, 90.0, 181.0, 270.0]) {
            for (final bearing
                in cone == 360
                    ? [0.0, 90.0, -90.0, 180.0]
                    : [-cone / 2, 0.0, cone / 2]) {
              final target = _target(heading: heading, bearing: bearing);
              final camera = drivingProximityCamera(
                size: size,
                currentPoint: _point(),
                target: target,
                headingDegrees: heading,
                targetingConeDegrees: cone,
                maximumZoom: 17,
              );
              final vehicle = camera.latLngToScreenOffset(
                const LatLng(6.25, -75.57),
              );
              final marker = camera.latLngToScreenOffset(
                LatLng(target.latitude, target.longitude),
              );
              expect(vehicle.dx, closeTo(size.width / 2, 1e-6));
              expect(
                vehicle.dy,
                closeTo(size.height * (cone == 360 ? 0.5 : 0.72), 1e-6),
              );
              expect(marker.dx, inInclusiveRange(25.99, size.width - 25.99));
              expect(marker.dy, inInclusiveRange(25.99, size.height - 25.99));
              final direction = marker - vehicle;
              expect(
                angularDistanceDegrees(
                  math.atan2(direction.dx, -direction.dy) * 180 / math.pi,
                  bearing,
                ),
                lessThan(0.3),
              );
            }
          }
        }
      }
    },
  );

  test('scale keeps threshold jitter stable and releases after dead band', () {
    final scale = DrivingMapScale();
    expect(scale.maximumZoom(110), 16);
    for (final distance in [119.0, 121.0, 118.0, 122.0]) {
      expect(scale.maximumZoom(distance), 16);
    }
    expect(scale.maximumZoom(133), 15);
    expect(scale.maximumZoom(110), 15);
    expect(scale.maximumZoom(107), 16);
  });

  test('tile set covers every sampled viewport pixel, including rotation', () {
    for (final angle in [0.0, 45.0, 90.0, 137.0, 270.0]) {
      final camera = drivingProximityCamera(
        size: const Size(390, 270),
        currentPoint: _point(),
        target: _target(heading: angle),
        headingDegrees: angle,
        targetingConeDegrees: 90,
        maximumZoom: 15.4,
      );
      final tiles = drivingViewportTiles(camera);
      expect(tiles.length, greaterThan(1));
      for (var y = 0.5; y < 270; y += 5) {
        for (var x = 0.5; x < 390; x += 5) {
          final point = camera.projectAtZoom(
            camera.screenOffsetToLatLng(Offset(x, y)),
            camera.zoom.roundToDouble(),
          );
          expect(
            tiles,
            contains(
              TileCoordinates(
                (point.dx / 256).floor(),
                (point.dy / 256).floor(),
                camera.zoom.round(),
              ),
            ),
          );
        }
      }
    }
  });

  test(
    '360 radar retains behind/lateral bearing and unknown bearing has no point',
    () {
      const size = Size(180, 156);
      final user = drivingVehicleAnchor(size, 360);
      final radius = drivingRadarRadius(size, 360);
      final behind = drivingRadarTargetPoint(
        user: user,
        target: _target(bearing: 180),
        radarRadius: radius,
        radarRangeMeters: 600,
      )!;
      final right = drivingRadarTargetPoint(
        user: user,
        target: _target(bearing: 90),
        radarRadius: radius,
        radarRangeMeters: 600,
      )!;
      expect(user, const Offset(90, 78));
      expect(behind.dx, closeTo(user.dx, 1e-9));
      expect(behind.dy, greaterThan(user.dy));
      expect(right.dy, closeTo(user.dy, 1e-9));
      expect(right.dx, greaterThan(user.dx));
      expect(
        drivingRadarTargetPoint(
          user: user,
          target: const DrivingVisualTarget(
            id: 'unknown',
            latitude: 6,
            longitude: -75,
            distanceMeters: 50,
            relativeBearingDegrees: null,
            kind: DrivingVisualTargetKind.toll,
          ),
          radarRadius: radius,
          radarRangeMeters: 80,
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'full coverage reveals same map and paints tiles across viewport',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      expect(find.byKey(_radarKey), findsOneWidget);
      final original = tester.state(find.byKey(_mapKey));
      final requested = provider.requests.length;
      expect(requested, greaterThan(1));
      provider.completeAll();
      await _frames(tester);
      expect(find.byKey(_radarKey), findsNothing);
      expect(identical(original, tester.state(find.byKey(_mapKey))), isTrue);
      expect(provider.requests.length, requested);
      final camera = tester
          .widget<FlutterMap>(find.byKey(_mapKey))
          .mapController!
          .camera;
      final origin = tester.getTopLeft(find.byKey(_boundaryKey));
      final user =
          tester.getCenter(
            find.byKey(const ValueKey('driving-map-user-marker')),
          ) -
          origin;
      expect(user.dx, closeTo(195, 0.01));
      expect(user.dy, closeTo(270 * 0.72, 0.01));
      final target = _target();
      final targetPosition =
          tester.getCenter(
            find.byKey(ValueKey('driving-map-target-${target.id}')),
          ) -
          origin;
      expect(
        (targetPosition -
                camera.latLngToScreenOffset(
                  LatLng(target.latitude, target.longitude),
                ))
            .distance,
        lessThan(0.01),
      );
      await _expectTilePixels(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'performance: unchanged camera reuses tiles without rebuilding TileLayer',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      provider.completeAll();
      await _frames(tester);
      expect(find.byKey(_radarKey), findsNothing);
      final original = tester.widget<TileLayer>(find.byType(TileLayer));
      final requests = provider.requests.length;
      var builds = 0;
      final previousCallback = debugOnRebuildDirtyWidget;
      addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget is TileLayer) builds++;
        previousCallback?.call(element, builtOnce);
      };

      for (var update = 0; update < 3; update++) {
        await tester.pumpWidget(_host(provider));
        await _frames(tester);
      }
      expect(
        builds,
        0,
        reason: 'Parent updates with identical camera must not rebuild tiles.',
      );
      expect(tester.widget<TileLayer>(find.byType(TileLayer)), same(original));
      expect(provider.requests.length, requests);
      expect(find.byKey(_radarKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'performance: covered GPS movement reuses TileLayer but updates camera',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      provider.completeAll();
      await _frames(tester);
      final original = tester.widget<TileLayer>(find.byType(TileLayer));
      final controller = tester
          .widget<FlutterMap>(find.byKey(_mapKey))
          .mapController!;
      final center = controller.camera.center;
      final requests = provider.requests.length;

      await tester.pumpWidget(
        _host(provider, point: _point(latitude: 6.25001)),
      );
      await _frames(tester);
      expect(controller.camera.center, isNot(center));
      expect(find.byKey(_radarKey), findsNothing);
      expect(provider.requests.length, requests);
      final next = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(next, same(original));
      expect(next.tileBuilder, same(original.tileBuilder));
      expect(next.errorTileCallback, same(original.errorTileCallback));
      await _expectTilePixels(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final change in ['episode', 'retry', 'url', 'userAgent', 'provider']) {
    testWidgets('performance: $change replaces the captured tile layer', (
      tester,
    ) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      provider.completeAll();
      await _frames(tester);
      final original = tester.widget<TileLayer>(find.byType(TileLayer));
      final nextProvider = change == 'provider' ? _ControlledTiles() : provider;
      if (change == 'provider') addTearDown(nextProvider.release);

      await tester.pumpWidget(
        _host(
          nextProvider,
          episode: change == 'episode' ? 'toll:2' : 'toll:1',
          retryToken: change == 'retry' ? 1 : 0,
          tileUrlTemplate: change == 'url'
              ? 'https://alternate.invalid/{z}/{x}/{y}'
              : 'https://tiles.invalid/{z}/{x}/{y}',
          userAgent: change == 'userAgent'
              ? 'test.alternate'
              : 'test.picoradar',
        ),
      );
      await _frames(tester);
      final next = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(next, isNot(same(original)));
      expect(next.key, isNot(original.key));
      expect(next.tileBuilder, isNot(same(original.tileBuilder)));
      expect(next.errorTileCallback, isNot(same(original.errorTileCallback)));
      nextProvider.completeAll();
      await _frames(tester);
      expect(find.byKey(_radarKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'half coverage never exposes map; GPS updates cannot reset deadline',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      final minY = provider.requests.keys.map((key) => key.y).reduce(math.min);
      provider.completeWhere((key) => key.y == minY);
      await _frames(tester);
      expect(find.byKey(_radarKey), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(
          _host(provider, point: _point(latitude: 6.25 + i * 0.000001)),
        );
        await _frames(tester);
      }
      expect(find.text('Mapa no disponible · Radar'), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      provider.completeAll();
      await _frames(tester);
      expect(find.text('Mapa no disponible · Radar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a lower viewport tile error is sticky and explicit retry works',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      final camera = tester
          .widget<FlutterMap>(find.byKey(_mapKey))
          .mapController!
          .camera;
      final lower = drivingViewportTiles(camera)
          .reduce((a, b) => a.y > b.y ? a : b);
      provider.completeWhere((key) => key != lower);
      await _frames(tester);
      expect(find.byKey(_radarKey), findsOneWidget);
      provider.fail(lower);
      await _frames(tester);
      expect(find.text('Mapa no disponible · Radar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      expect(find.text('Mapa no disponible · Radar'), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      provider.newAttempt();
      await tester.tap(find.byTooltip('Reintentar mapa'));
      await _frames(tester);
      provider.completeAll();
      await _frames(tester);
      expect(find.byKey(_radarKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'rotation revalidates all new tiles and renders nonblank corners',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      provider.completeAll();
      await _frames(tester);
      final original = tester.state(find.byKey(_mapKey));
      final oldLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      await tester.pumpWidget(
        _host(provider, heading: 45, target: _target(heading: 45)),
      );
      await _frames(tester);
      final nextLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(nextLayer, isNot(same(oldLayer)));
      expect(nextLayer.key, oldLayer.key);
      expect(nextLayer.tileBuilder, isNot(same(oldLayer.tileBuilder)));
      expect(
        nextLayer.errorTileCallback,
        isNot(same(oldLayer.errorTileCallback)),
      );
      expect(identical(original, tester.state(find.byKey(_mapKey))), isTrue);
      expect(find.byKey(_radarKey), findsOneWidget);
      provider.completeAll();
      await _frames(tester);
      expect(find.byKey(_radarKey), findsNothing);
      await _expectTilePixels(tester);
      final camera = tester
          .widget<FlutterMap>(find.byKey(_mapKey))
          .mapController!
          .camera;
      expect(camera.rotation, 315);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('small GPS updates keep a fully covered viewport visible', (
    tester,
  ) async {
    final provider = _ControlledTiles();
    addTearDown(provider.release);
    await tester.pumpWidget(_host(provider));
    await _frames(tester);
    provider.completeAll();
    await _frames(tester);
    expect(find.byKey(_radarKey), findsNothing);
    final requested = provider.requests.length;

    await tester.pumpWidget(_host(provider, point: _point(latitude: 6.25001)));
    expect(find.byKey(_radarKey), findsNothing);
    await _frames(tester);

    expect(find.byKey(_radarKey), findsNothing);
    expect(provider.requests.length, requested);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'zoom and size changes cover radar until the entire new viewport loads',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      provider.completeAll();
      await _frames(tester);
      final oldCamera = tester
          .widget<FlutterMap>(find.byKey(_mapKey))
          .mapController!
          .camera;
      await tester.pumpWidget(
        _host(
          provider,
          target: _target(distance: 30),
          size: const Size(412, 320),
        ),
      );
      await _frames(tester);
      final newCamera = tester
          .widget<FlutterMap>(find.byKey(_mapKey))
          .mapController!
          .camera;
      expect(newCamera.zoom, greaterThan(oldCamera.zoom));
      expect(newCamera.nonRotatedSize, const Size(412, 320));
      expect(find.byKey(_radarKey), findsOneWidget);
      provider.completeAll();
      await _frames(tester);
      expect(find.byKey(_radarKey), findsNothing);
      await _expectTilePixels(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late callbacks from a previous episode and viewport cannot reveal or fail the map',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(_host(provider));
      await _frames(tester);
      final oldLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      final oldTiles = provider.requests.keys.toList();
      final oldTile = TileImage(
        vsync: const TestVSync(),
        coordinates: oldTiles.first,
        imageProvider: _ControlledImage(Completer<ui.Image>().future),
        onLoadComplete: (_) {},
        onLoadError: (_, _, _) {},
        tileDisplay: const TileDisplay.instantaneous(),
        errorImage: null,
        cancelLoading: Completer<void>(),
      );
      addTearDown(oldTile.dispose);
      provider.newAttempt();
      await tester.pumpWidget(
        _host(provider, episode: 'toll:2', target: _target(distance: 30)),
      );
      await _frames(tester);
      oldLayer.errorTileCallback!(oldTile, StateError('late'), null);
      for (final key in oldTiles) {
        provider.completePrevious(key);
      }
      await _frames(tester);
      expect(find.byKey(_radarKey), findsOneWidget);
      expect(find.text('Mapa no disponible · Radar'), findsNothing);
      provider.completeAll();
      await _frames(tester);
      expect(find.byKey(_radarKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('radar mode and unreliable heading perform no tile requests', (
    tester,
  ) async {
    final provider = _ControlledTiles();
    addTearDown(provider.release);
    await tester.pumpWidget(
      _host(provider, mode: CameraVisualizationMode.radar),
    );
    await _frames(tester);
    expect(provider.requests, isEmpty);
    expect(find.byType(FlutterMap), findsNothing);
    await tester.pumpWidget(_host(provider, heading: null));
    await _frames(tester);
    expect(provider.requests, isEmpty);
    expect(find.text('Rumbo no disponible'), findsOneWidget);
    await tester.pumpWidget(_host(provider));
    await _frames(tester);
    expect(provider.requests, isNotEmpty);
    await tester.pumpWidget(
      _host(provider, mode: CameraVisualizationMode.radar),
    );
    await _frames(tester);
    final count = provider.requests.length;
    provider.completeAll();
    await tester.pump(const Duration(seconds: 4));
    await _frames(tester);
    expect(provider.requests.length, count);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Mapa no disponible · Radar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'compact fallback keeps full text and 48px retry at text scale 2',
    (tester) async {
      final provider = _ControlledTiles();
      addTearDown(provider.release);
      await tester.pumpWidget(
        _host(provider, size: const Size(116, 156), textScale: 2),
      );
      await _frames(tester);
      await tester.pump(const Duration(seconds: 3));
      await _frames(tester);
      final label = find.byKey(const ValueKey('driving-map-fallback-label'));
      final bounds = tester.getRect(find.byKey(_boundaryKey));
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(bounds.contains(tester.getRect(label).topLeft), isTrue);
      expect(
        bounds.contains(
          tester.getRect(label).bottomRight - const Offset(0.01, 0.01),
        ),
        isTrue,
      );
      final button = tester.getSize(find.byTooltip('Reintentar mapa'));
      expect(button.width, 48);
      expect(button.height, 48);
      final radar = tester.getRect(find.byKey(_radarKey));
      expect(radar.bottom, lessThanOrEqualTo(tester.getRect(label).top));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('ready map settles without a callback-driven rebuild loop', (
    tester,
  ) async {
    final provider = _ControlledTiles();
    addTearDown(provider.release);
    await tester.pumpWidget(_host(provider));
    await _frames(tester);
    provider.completeAll();
    await _frames(tester);
    expect(find.byKey(_radarKey), findsNothing);
    final frames = await tester.pumpAndSettle(
      const Duration(milliseconds: 10),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 1),
    );
    expect(frames, lessThan(4));
    await tester.pumpWidget(const SizedBox());
  });
}

DrivingPoint _point({double latitude = 6.25}) => DrivingPoint(
  latitude: latitude,
  longitude: -75.57,
  accuracyMeters: 5,
  speedKmh: 40,
  recordedAt: DateTime.utc(2026, 9, 9),
  headingDegrees: 0,
);

DrivingVisualTarget _target({
  double heading = 0,
  double bearing = 0,
  double distance = 300,
}) {
  final point = const Distance().offset(
    const LatLng(6.25, -75.57),
    distance,
    heading + bearing,
  );
  return DrivingVisualTarget(
    id: 'real-toll',
    latitude: point.latitude,
    longitude: point.longitude,
    distanceMeters: distance,
    relativeBearingDegrees: bearing,
    kind: DrivingVisualTargetKind.toll,
  );
}

Widget _host(
  _ControlledTiles provider, {
  DrivingPoint? point,
  DrivingVisualTarget? target,
  double? heading = 0,
  String episode = 'toll:1',
  CameraVisualizationMode mode = CameraVisualizationMode.auto,
  Size size = const Size(390, 270),
  double textScale = 1,
  int retryToken = 0,
  String tileUrlTemplate = 'https://tiles.invalid/{z}/{x}/{y}',
  String userAgent = 'test.picoradar',
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: RepaintBoundary(
        key: _boundaryKey,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: DrivingProximityMap(
            target: target ?? _target(),
            currentPoint: point ?? _point(),
            reliableHeadingDegrees: heading,
            targetingConeDegrees: 90,
            episodeKey: episode,
            retryToken: retryToken,
            visualizationMode: mode,
            alertColor: Colors.orange,
            height: size.height,
            config: DrivingMapConfig(
              tileUrlTemplate: tileUrlTemplate,
              attributionLabel: 'Controlled test tiles',
              userAgentPackageName: userAgent,
              forceOfflineFallback: false,
              tileProvider: provider,
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Future<void> _expectTilePixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final image = boundary.toImageSync(pixelRatio: 1);
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  var green = 0;
  var samples = 0;
  for (var y = 3; y < image.height - 25; y += 9) {
    for (var x = 3; x < image.width - 3; x += 9) {
      final index = (y * image.width + x) * 4;
      if (bytes.getUint8(index + 1) > 125 &&
          bytes.getUint8(index + 1) > bytes.getUint8(index)) {
        green++;
      }
      samples++;
    }
  }
  expect(
    green / samples,
    greaterThan(0.95),
    reason: 'Tiles must paint across the whole viewport',
  );
  for (final pixel in [
    const Offset(3, 3),
    Offset(image.width - 4.0, 3),
    Offset(3, image.height - 26.0),
    Offset(image.width - 4.0, image.height - 26.0),
  ]) {
    final index = (pixel.dy.toInt() * image.width + pixel.dx.toInt()) * 4;
    expect(
      bytes.getUint8(index + 1),
      greaterThan(125),
      reason: 'Rotated corner must be covered',
    );
  }
  image.dispose();
}

class _ControlledTiles extends TileProvider {
  final requests = <TileCoordinates, Completer<ui.Image>>{};
  final _previous = <TileCoordinates, Completer<ui.Image>>{};
  late final ui.Image _image = _makeImage();

  ui.Image _makeImage() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()..color = const Color(0xFF75B884),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(256, 256);
    picture.dispose();
    return image;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final completer = requests.putIfAbsent(
      coordinates,
      Completer<ui.Image>.new,
    );
    return _ControlledImage(completer.future);
  }

  void completeWhere(bool Function(TileCoordinates) predicate) {
    for (final entry in requests.entries) {
      if (predicate(entry.key) && !entry.value.isCompleted) {
        entry.value.complete(_image);
      }
    }
  }

  void completeAll() => completeWhere((_) => true);
  void fail(TileCoordinates key) =>
      requests[key]!.completeError(StateError('controlled tile failure'));
  void newAttempt() {
    _previous.addAll(requests);
    requests.clear();
  }

  void completePrevious(TileCoordinates key) {
    final request = _previous[key]!;
    if (!request.isCompleted) request.complete(_image);
  }

  void release() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _image.dispose();
  }
}

class _ControlledImage extends ImageProvider<_ControlledImage> {
  const _ControlledImage(this.frame);
  final Future<ui.Image> frame;

  @override
  Future<_ControlledImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _ControlledImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    frame.then((image) => ImageInfo(image: image.clone())),
  );
}
