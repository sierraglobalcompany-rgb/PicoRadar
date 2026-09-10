import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/driving_preferences.dart';
import '../domain/camera_matcher.dart';
import 'driving_map_episode.dart';
import 'driving_radar.dart';

export 'driving_radar.dart' show DrivingVisualTarget, DrivingVisualTargetKind;

final drivingMapConfigProvider = Provider<DrivingMapConfig>(
  (ref) => DrivingMapConfig.fromEnvironment(),
);

class DrivingMapConfig {
  const DrivingMapConfig({
    required this.tileUrlTemplate,
    required this.attributionLabel,
    required this.userAgentPackageName,
    required this.forceOfflineFallback,
    this.tileProvider,
  });

  factory DrivingMapConfig.fromEnvironment() => const DrivingMapConfig(
    tileUrlTemplate: String.fromEnvironment(
      'PICORADAR_DRIVING_TILE_URL_TEMPLATE',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    attributionLabel: 'OpenStreetMap contributors',
    userAgentPackageName: String.fromEnvironment(
      'PICORADAR_DRIVING_TILE_USER_AGENT',
      defaultValue: 'co.picoradar.app.dev',
    ),
    forceOfflineFallback: bool.fromEnvironment(
      'PICORADAR_FORCE_CAMERA_MAP_FALLBACK',
    ),
  );

  final String tileUrlTemplate;
  final String attributionLabel;
  final String userAgentPackageName;
  final bool forceOfflineFallback;
  final TileProvider? tileProvider;
}

/// Keeps the existing 40/120/320 m scale bands, with a 10% dead band.
class DrivingMapScale {
  int? _band;

  double maximumZoom(double distanceMeters) {
    const limits = [40.0, 120.0, 320.0];
    var band = _band ?? limits.where((limit) => distanceMeters > limit).length;
    while (band < 3 && distanceMeters > limits[band] * 1.1) {
      band++;
    }
    while (band > 0 && distanceMeters < limits[band - 1] * 0.9) {
      band--;
    }
    _band = band;
    return 17.0 - band;
  }
}

/// Projects both real coordinates, then translates the camera to the vehicle
/// anchor. Rotation is heading-up; markers never use a synthetic bearing point.
MapCamera drivingProximityCamera({
  required Size size,
  required DrivingPoint currentPoint,
  required DrivingVisualTarget target,
  required double headingDegrees,
  required int targetingConeDegrees,
  required double maximumZoom,
}) {
  const crs = Epsg3857();
  final user = LatLng(currentPoint.latitude, currentPoint.longitude);
  final destination = LatLng(target.latitude, target.longitude);
  final anchor = drivingVehicleAnchor(size, targetingConeDegrees);
  final rotation = -headingDegrees % 360;
  final radians = rotation * math.pi / 180;
  Offset rotate(Offset p, double angle) => Offset(
    p.dx * math.cos(angle) - p.dy * math.sin(angle),
    p.dx * math.sin(angle) + p.dy * math.cos(angle),
  );
  var delta =
      crs.latLngToOffset(destination, maximumZoom) -
      crs.latLngToOffset(user, maximumZoom);
  final world = crs.scale(maximumZoom);
  if (delta.dx.abs() > world / 2) {
    delta = Offset(delta.dx - delta.dx.sign * world, delta.dy);
  }
  final screenDelta = rotate(delta, radians);
  const margin = 26.0;
  final availableX = math.max(
    1.0,
    screenDelta.dx < 0 ? anchor.dx - margin : size.width - anchor.dx - margin,
  );
  final availableY = math.max(
    1.0,
    screenDelta.dy < 0 ? anchor.dy - margin : size.height - anchor.dy - margin,
  );
  final fit = math.min(
    1.0,
    math.min(
      screenDelta.dx == 0 ? 1.0 : availableX / screenDelta.dx.abs(),
      screenDelta.dy == 0 ? 1.0 : availableY / screenDelta.dy.abs(),
    ),
  );
  final zoom = maximumZoom + math.log(fit) / math.ln2;
  final userPixel = crs.latLngToOffset(user, zoom);
  final centerPixel =
      userPixel - rotate(anchor - size.center(Offset.zero), -radians);
  return MapCamera(
    crs: crs,
    center: crs.offsetToLatLng(centerPixel, zoom),
    zoom: zoom,
    rotation: rotation,
    nonRotatedSize: size,
  );
}

/// Exact tile/rotated-viewport intersection (separating axis theorem).
/// TileLayer uses 256 px tiles and rounded native zoom, with retina disabled.
Set<TileCoordinates> drivingViewportTiles(MapCamera camera) {
  final zoom = camera.zoom.round().clamp(0, 19);
  final size = camera.nonRotatedSize;
  final polygon =
      [
            Offset.zero,
            Offset(size.width, 0),
            Offset(size.width, size.height),
            Offset(0, size.height),
          ]
          .map(
            (p) => camera.projectAtZoom(
              camera.screenOffsetToLatLng(p),
              zoom.toDouble(),
            ),
          )
          .toList();
  final center = camera.projectAtZoom(camera.center, zoom.toDouble());
  final world = 256.0 * math.pow(2, zoom);
  for (var i = 0; i < polygon.length; i++) {
    final p = polygon[i];
    polygon[i] = Offset(
      p.dx + ((center.dx - p.dx) / world).round() * world,
      p.dy,
    );
  }
  final minX = polygon.map((p) => p.dx).reduce(math.min);
  final maxX = polygon.map((p) => p.dx).reduce(math.max);
  final minY = polygon.map((p) => p.dy).reduce(math.min);
  final maxY = polygon.map((p) => p.dy).reduce(math.max);
  final tiles = <TileCoordinates>{};
  for (var x = (minX / 256).floor(); x < (maxX / 256).ceil(); x++) {
    for (var y = (minY / 256).floor(); y < (maxY / 256).ceil(); y++) {
      final rect = Rect.fromLTWH(x * 256.0, y * 256.0, 256, 256);
      final corners = [
        rect.topLeft,
        rect.topRight,
        rect.bottomRight,
        rect.bottomLeft,
      ];
      final axes = [
        const Offset(1, 0),
        const Offset(0, 1),
        polygon[1] - polygon[0],
        polygon[3] - polygon[0],
      ];
      final intersects = axes.every((axis) {
        double dot(Offset p) => p.dx * axis.dx + p.dy * axis.dy;
        final a = polygon.map(dot);
        final b = corners.map(dot);
        return a.reduce(math.max) > b.reduce(math.min) + 1e-7 &&
            b.reduce(math.max) > a.reduce(math.min) + 1e-7;
      });
      if (intersects) tiles.add(TileCoordinates(x, y, zoom));
    }
  }
  return tiles;
}

class DrivingProximityMap extends StatefulWidget {
  const DrivingProximityMap({
    required this.target,
    required this.currentPoint,
    required this.reliableHeadingDegrees,
    required this.targetingConeDegrees,
    required this.episodeKey,
    required this.visualizationMode,
    required this.alertColor,
    required this.height,
    required this.config,
    this.onTap,
    this.retryToken = 0,
    super.key,
  });

  final DrivingVisualTarget target;
  final DrivingPoint currentPoint;

  /// A reliable course supplied by the domain layer, or null. Never defaults north.
  final double? reliableHeadingDegrees;
  final int targetingConeDegrees;
  final String episodeKey;
  final CameraVisualizationMode visualizationMode;
  final Color alertColor;
  final double height;
  final DrivingMapConfig config;
  final VoidCallback? onTap;
  final int retryToken;

  @override
  State<DrivingProximityMap> createState() => _DrivingProximityMapState();
}

class _DrivingProximityMapState extends State<DrivingProximityMap> {
  final _controller = MapController();
  final _episode = CameraMapEpisodeStateMachine();
  DrivingMapScale _scale = DrivingMapScale();
  final _tiles = <TileCoordinates, TileImage>{};
  Set<TileCoordinates> _required = {};
  MapCamera? _desired;
  Timer? _timeout;
  TileProvider? _defaultTileProvider;
  var _attemptStarted = false;
  var _generation = 0;
  var _viewport = 0;
  var _mapReady = false;
  var _positioned = false;
  var _checkScheduled = false;
  var _moveScheduled = false;

  bool get _radarOnly =>
      widget.visualizationMode == CameraVisualizationMode.radar;
  bool get _headingReliable => widget.reliableHeadingDegrees?.isFinite ?? false;
  bool get _canMap =>
      !_radarOnly &&
      _headingReliable &&
      !widget.config.forceOfflineFallback &&
      widget.config.tileUrlTemplate.trim().isNotEmpty;
  bool get _failed => _episode.state == CameraMapEpisodeViewState.fallback;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  void _begin({bool retry = false}) {
    _generation++;
    _timeout?.cancel();
    _timeout = null;
    _tiles.clear();
    _required = {};
    _desired = null;
    _positioned = false;
    _checkScheduled = false;
    _moveScheduled = false;
    _scale = DrivingMapScale();
    _defaultTileProvider = null;
    if (retry) CameraMapEpisodeCache.remove(widget.episodeKey);
    _attemptStarted =
        CameraMapEpisodeCache.pendingSince(widget.episodeKey) != null;
    _episode.retry(
      widget.episodeKey,
      CameraMapEpisodeCache.pendingSince(widget.episodeKey) ?? DateTime.now(),
    );
    if (CameraMapEpisodeCache.read(widget.episodeKey) ==
        CameraMapEpisodeViewState.fallback) {
      _episode.markFallback(widget.episodeKey);
    }
  }

  @override
  void didUpdateWidget(covariant DrivingProximityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeKey != widget.episodeKey) {
      _begin();
    } else if (oldWidget.retryToken != widget.retryToken) {
      _begin(retry: true);
    } else if (oldWidget.config.tileUrlTemplate !=
            widget.config.tileUrlTemplate ||
        oldWidget.config.tileProvider != widget.config.tileProvider ||
        oldWidget.config.userAgentPackageName !=
            widget.config.userAgentPackageName) {
      // Configuration changes invalidate callbacks, but never clear sticky failure.
      _begin();
    }
    if (!_canMap) {
      _defaultTileProvider = null;
      _mapReady = false;
      _positioned = false;
      _tiles.clear();
      _timeout?.cancel();
      _timeout = null;
      _generation++;
      _checkScheduled = false;
      _moveScheduled = false;
    }
  }

  void _persist() => CameraMapEpisodeCache.write(
    widget.episodeKey,
    _episode.state,
    pendingSince: _episode.pendingSince,
  );

  void _ensureDeadline() {
    if (_timeout != null || _failed || !_canMap) return;
    final generation = _generation;
    final elapsed = DateTime.now().difference(_episode.pendingSince!);
    final remaining = drivingMapTileReadinessTimeout - elapsed;
    _persist();
    _timeout = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!mounted || generation != _generation || !_canMap) return;
      _fallback();
    });
  }

  void _fallback() {
    if (!_episode.markFallback(widget.episodeKey)) return;
    _timeout?.cancel();
    _timeout = null;
    _persist();
    _tiles.clear();
    _defaultTileProvider = null;
    setState(() {});
  }

  bool get _covered =>
      _positioned &&
      _required.isNotEmpty &&
      _required.every((key) {
        final tile = _tiles[key];
        return tile != null &&
            !tile.cancelLoading.isCompleted &&
            tile.readyToDisplay &&
            !tile.loadError;
      });

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _checkScheduled = false;
      if (!_canMap || _failed) return;
      if (_required.any((key) => _tiles[key]?.loadError ?? false)) {
        _fallback();
      } else if (_covered) {
        if (_episode.markReady(widget.episodeKey)) {
          _timeout?.cancel();
          _timeout = null;
          _persist();
          setState(() {});
        }
      } else {
        if (_episode.revalidate(widget.episodeKey, DateTime.now())) {
          setState(() {});
        }
        _ensureDeadline();
      }
    });
  }

  void _plan(MapCamera camera) {
    if (_failed) {
      _desired = camera;
      return;
    }
    if (!_attemptStarted) {
      _episode.retry(widget.episodeKey, DateTime.now());
      _attemptStarted = true;
    }
    final old = _desired;
    if (old == null ||
        old.center != camera.center ||
        old.zoom != camera.zoom ||
        old.rotation != camera.rotation ||
        old.nonRotatedSize != camera.nonRotatedSize) {
      final nextRequired = drivingViewportTiles(camera);
      final keepsCoverage =
          _positioned &&
          _episode.state == CameraMapEpisodeViewState.ready &&
          _required.length == nextRequired.length &&
          _required.containsAll(nextRequired) &&
          nextRequired.every((key) {
            final tile = _tiles[key];
            return tile != null &&
                !tile.cancelLoading.isCompleted &&
                tile.readyToDisplay &&
                !tile.loadError;
          });
      _desired = camera;
      if (!keepsCoverage) {
        _viewport++;
        _positioned = false;
        _required = nextRequired;
        _tiles.removeWhere((key, _) => !_required.contains(key));
        _episode.revalidate(widget.episodeKey, DateTime.now());
      }
      _scheduleMove();
    }
    if (_episode.state == CameraMapEpisodeViewState.pending) _ensureDeadline();
  }

  void _scheduleMove() {
    if (!_mapReady || _moveScheduled) return;
    _moveScheduled = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // flutter_map emits its captured resize camera at end of frame. Move
      // afterwards so that stale resize events cannot prune the new zoom tiles.
      scheduleMicrotask(() {
        if (!mounted || generation != _generation) return;
        _moveScheduled = false;
        if (!_canMap || !_mapReady) return;
        final camera = _desired!;
        final needsCoverageCheck = !_positioned;
        _controller.moveAndRotate(camera.center, camera.zoom, camera.rotation);
        if (needsCoverageCheck) {
          setState(() => _positioned = true);
          _scheduleCheck();
        }
      });
    });
  }

  @override
  void dispose() {
    _generation++;
    _timeout?.cancel();
    _tiles.clear();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_canMap) {
            _plan(
              drivingProximityCamera(
                size: size,
                currentPoint: widget.currentPoint,
                target: widget.target,
                headingDegrees: widget.reliableHeadingDegrees!,
                targetingConeDegrees: widget.targetingConeDegrees,
                maximumZoom: _scale.maximumZoom(widget.target.distanceMeters),
              ),
            );
          }
          final showMap =
              _canMap &&
              !_failed &&
              _covered &&
              _episode.state == CameraMapEpisodeViewState.ready;
          final generation = _generation;
          final viewport = _viewport;
          final desired = _desired;
          final showUnavailable =
              !_radarOnly &&
              _headingReliable &&
              (_failed ||
                  widget.config.forceOfflineFallback ||
                  widget.config.tileUrlTemplate.trim().isEmpty);
          final status = showUnavailable
              ? _fallbackStatus(context, size)
              : null;
          final radarTarget = _headingReliable
              ? widget.target
              : DrivingVisualTarget(
                  id: widget.target.id,
                  latitude: widget.target.latitude,
                  longitude: widget.target.longitude,
                  distanceMeters: widget.target.distanceMeters,
                  relativeBearingDegrees: null,
                  kind: widget.target.kind,
                );
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_canMap && desired != null)
                FlutterMap(
                  key: const ValueKey('driving-real-mini-map'),
                  mapController: _controller,
                  options: MapOptions(
                    onTap: (_, _) => widget.onTap?.call(),
                    initialCenter: desired.center,
                    initialZoom: desired.zoom,
                    initialRotation: desired.rotation,
                    backgroundColor: const Color(0xFF07111B),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                    onMapReady: () {
                      _mapReady = true;
                      _scheduleMove();
                    },
                  ),
                  children: [
                    if (!_failed)
                      TileLayer(
                        key: ValueKey('driving-proximity-tiles-$generation'),
                        urlTemplate: widget.config.tileUrlTemplate,
                        userAgentPackageName:
                            widget.config.userAgentPackageName,
                        tileProvider:
                            widget.config.tileProvider ??
                            (_defaultTileProvider ??= NetworkTileProvider(
                              cachingProvider:
                                  const DisabledMapCachingProvider(),
                            )),
                        keepBuffer: 0,
                        panBuffer: 0,
                        retinaMode: false,
                        tileDisplay: const TileDisplay.instantaneous(),
                        tileBuilder: (context, tileWidget, tile) {
                          if (generation == _generation &&
                              viewport == _viewport &&
                              _required.contains(tile.coordinates)) {
                            _tiles[tile.coordinates] = tile;
                            _scheduleCheck();
                          }
                          return tileWidget;
                        },
                        errorTileCallback: (tile, error, stackTrace) {
                          if (generation == _generation &&
                              viewport == _viewport &&
                              _required.contains(tile.coordinates)) {
                            _tiles[tile.coordinates] = tile;
                            _scheduleCheck();
                          }
                        },
                      ),
                    MarkerLayer(
                      rotate: true,
                      markers: [
                        Marker(
                          point: LatLng(
                            widget.currentPoint.latitude,
                            widget.currentPoint.longitude,
                          ),
                          width: 34,
                          height: 34,
                          child: const _MapMarker(
                            key: ValueKey('driving-map-user-marker'),
                            icon: Icons.navigation_rounded,
                            color: Color(0xFF2F6FED),
                          ),
                        ),
                        Marker(
                          point: LatLng(
                            widget.target.latitude,
                            widget.target.longitude,
                          ),
                          width: 34,
                          height: 34,
                          child: _MapMarker(
                            key:
                                widget.target.kind ==
                                    DrivingVisualTargetKind.camera
                                ? const ValueKey('driving-map-camera-marker')
                                : ValueKey(
                                    'driving-map-target-${widget.target.id}',
                                  ),
                            icon:
                                widget.target.kind ==
                                    DrivingVisualTargetKind.camera
                                ? Icons.photo_camera
                                : Icons.toll,
                            color: widget.alertColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              if (showMap)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _MapConePainter(widget.targetingConeDegrees),
                  ),
                ),
              if (!showMap)
                Positioned.fill(
                  bottom: status?.$2 ?? 0,
                  child: DrivingRadarView(
                    key: const ValueKey('driving-map-offline-fallback'),
                    target: radarTarget,
                    currentPoint: widget.currentPoint,
                    targetingConeDegrees: widget.targetingConeDegrees,
                    alertColor: widget.alertColor,
                  ),
                ),
              if (showMap)
                Positioned(
                  right: 6,
                  left: 6,
                  bottom: 4,
                  child: Text(
                    '\u00a9 ${widget.config.attributionLabel}',
                    key: const ValueKey('driving-map-attribution'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              if (status != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: status.$2,
                  child: status.$1,
                ),
              if (!_headingReliable)
                const Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Text(
                    'Rumbo no disponible',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  (Widget, double) _fallbackStatus(BuildContext context, Size size) {
    const label = 'Mapa no disponible · Radar';
    final narrow = size.width < 220;
    final textWidth = size.width - 12 - (narrow ? 0 : 48);
    final scaler = MediaQuery.textScalerOf(context);
    final baseStyle = DefaultTextStyle.of(context).style
        .copyWith(color: Colors.white, height: 1.2);
    var fontSize = 11.0;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    );
    void measure() {
      painter.text = TextSpan(
        text: label,
        style: baseStyle.copyWith(fontSize: fontSize),
      );
      painter.layout(maxWidth: textWidth);
    }

    measure();
    // Preserve a radar region and the 48 px retry target in compact alert cards.
    while (narrow && painter.height + 56 > size.height - 48 && fontSize > 8) {
      fontSize -= 0.25;
      measure();
    }
    final height =
        (narrow ? painter.height + 48 : math.max(48.0, painter.height)) + 8;
    painter.dispose();
    final text = Text(
      label,
      key: const ValueKey('driving-map-fallback-label'),
      style: baseStyle.copyWith(fontSize: fontSize),
    );
    final retry = SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        tooltip: 'Reintentar mapa',
        onPressed: _canMap ? () => setState(() => _begin(retry: true)) : null,
        icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
      ),
    );
    return (
      ColoredBox(
        color: const Color(0xFF07111B),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: narrow
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    text,
                    Align(alignment: Alignment.centerRight, child: retry),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: text),
                    retry,
                  ],
                ),
        ),
      ),
      height,
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.icon, required this.color, super.key});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );
}

class _MapConePainter extends CustomPainter {
  const _MapConePainter(this.cone);
  final int cone;

  @override
  void paint(Canvas canvas, Size size) {
    final anchor = drivingVehicleAnchor(size, cone);
    final radius = drivingRadarRadius(size, cone);
    final rect = Rect.fromCircle(center: anchor, radius: radius);
    final paint = Paint()..color = const Color(0x180B7A75);
    if (cone >= 360) {
      canvas.drawCircle(anchor, radius, paint);
    } else {
      canvas.drawArc(
        rect,
        -math.pi / 2 - cone * math.pi / 360,
        cone * math.pi / 180,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MapConePainter oldDelegate) => oldDelegate.cone != cone;
}
