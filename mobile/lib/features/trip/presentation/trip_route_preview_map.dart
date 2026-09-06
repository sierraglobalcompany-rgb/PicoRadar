import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_tokens.dart';
import '../../driving/domain/traffic_camera.dart';
import '../application/route_geometry_index.dart';
import '../application/trip_route_associations.dart';
import '../application/trip_tile_config.dart';
import '../data/toll_inventory.dart';
import '../domain/trip_plan.dart';

class TripRouteMapConfig {
  const TripRouteMapConfig({
    required this.tileUrlTemplate,
    required this.attributionLabel,
    required this.userAgentPackageName,
    this.approved = false,
    this.tileReadyTimeout = const Duration(seconds: 8),
    this.forceNeutralFallback = false,
    this.tileProvider,
  });

  final String tileUrlTemplate;
  final String attributionLabel;
  final String userAgentPackageName;
  final bool approved;
  final Duration tileReadyTimeout;
  final bool forceNeutralFallback;
  final TileProvider? tileProvider;

  bool get tilesEnabled =>
      !forceNeutralFallback &&
      resolveTripTileConfig(
        approved: approved,
        urlTemplate: tileUrlTemplate,
        userAgent: userAgentPackageName,
        attribution: attributionLabel,
      ).enabled;
}

class TripRoutePreviewMap extends StatefulWidget {
  const TripRoutePreviewMap({
    required this.routeId,
    required this.geometry,
    required this.tollInventory,
    required this.cameraPack,
    required this.cameraPackVersion,
    required this.associations,
    required this.config,
    this.mapController,
    this.allowFullscreen = true,
    super.key,
  });

  const TripRoutePreviewMap._fullscreen({
    required this.routeId,
    required this.geometry,
    required this.tollInventory,
    required this.cameraPack,
    required this.cameraPackVersion,
    required this.config,
    required this.associations,
  }) : mapController = null,
       allowFullscreen = false;

  final String routeId;
  final List<TripCoordinate> geometry;
  final TollInventoryDataset tollInventory;
  final CameraPack cameraPack;
  final String cameraPackVersion;
  final TripRouteAssociations associations;
  final TripRouteMapConfig config;
  final MapController? mapController;
  final bool allowFullscreen;

  @override
  State<TripRoutePreviewMap> createState() => _TripRoutePreviewMapState();
}

class _TripRoutePreviewMapState extends State<TripRoutePreviewMap> {
  late final MapController _mapController;
  late final bool _ownsController;
  Timer? _tileTimer;
  var _showRoute = true;
  var _showTolls = true;
  var _showHistoricalTolls = false;
  var _showCameras = true;
  var _tilesUnavailable = false;
  var _tileAttempt = 0;
  Object? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.mapController == null;
    _mapController = widget.mapController ?? MapController();
    _startTileTimer();
  }

  @override
  void didUpdateWidget(covariant TripRoutePreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged =
        oldWidget.routeId != widget.routeId ||
        !identical(oldWidget.geometry, widget.geometry);
    final tollDatasetChanged =
        oldWidget.tollInventory.version != widget.tollInventory.version ||
        !identical(
          oldWidget.tollInventory.records,
          widget.tollInventory.records,
        );
    final cameraDatasetChanged =
        _cameraPackIdentity(
              oldWidget.cameraPack,
              oldWidget.cameraPackVersion,
            ) !=
            _cameraPackIdentity(widget.cameraPack, widget.cameraPackVersion) ||
        !identical(oldWidget.cameraPack.cameras, widget.cameraPack.cameras);
    if (routeChanged ||
        tollDatasetChanged ||
        cameraDatasetChanged ||
        !identical(oldWidget.associations, widget.associations)) {
      _selectedLocation = null;
    }
    final tileConfigChanged =
        oldWidget.config.tilesEnabled != widget.config.tilesEnabled ||
        oldWidget.config.tileReadyTimeout != widget.config.tileReadyTimeout ||
        oldWidget.config.tileUrlTemplate != widget.config.tileUrlTemplate ||
        oldWidget.config.userAgentPackageName !=
            widget.config.userAgentPackageName ||
        oldWidget.config.tileProvider != widget.config.tileProvider;
    if (routeChanged || tileConfigChanged) {
      _tileTimer?.cancel();
      _tilesUnavailable = false;
      _tileAttempt++;
      _startTileTimer();
    }
    if (routeChanged &&
        widget.associations.geometryQuality == RouteGeometryQuality.polyline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reframe();
        }
      });
    }
  }

  @override
  void dispose() {
    _tileTimer?.cancel();
    if (_ownsController) {
      _mapController.dispose();
    }
    super.dispose();
  }

  void _startTileTimer() {
    _tileTimer?.cancel();
    if (!widget.config.tilesEnabled ||
        widget.associations.geometryQuality != RouteGeometryQuality.polyline) {
      return;
    }
    _tileTimer = Timer(widget.config.tileReadyTimeout, _markTilesUnavailable);
  }

  void _markTileReady() {
    if (_tilesUnavailable) {
      return;
    }
    _tileTimer?.cancel();
  }

  void _markTilesUnavailable() {
    if (!mounted || _tilesUnavailable) {
      return;
    }
    _tileTimer?.cancel();
    setState(() => _tilesUnavailable = true);
  }

  void _retryTiles() {
    _tileTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _tilesUnavailable = false;
      _tileAttempt++;
    });
    _startTileTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.associations.geometryQuality != RouteGeometryQuality.polyline) {
      return const _MissingGeometry();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            FilterChip(
              key: const ValueKey('trip-map-toggle-route'),
              selected: _showRoute,
              avatar: const Icon(Icons.route_rounded, size: 18),
              label: const Text('Ruta'),
              onSelected: (value) => setState(() => _showRoute = value),
            ),
            FilterChip(
              key: const ValueKey('trip-map-toggle-tolls'),
              selected: _showTolls,
              avatar: const Icon(Icons.toll_rounded, size: 18),
              label: const Text('Peajes'),
              onSelected: (value) => setState(() => _showTolls = value),
            ),
            FilterChip(
              key: const ValueKey('trip-map-toggle-historical-tolls'),
              selected: _showHistoricalTolls,
              avatar: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Históricos'),
              onSelected: (value) =>
                  setState(() => _showHistoricalTolls = value),
            ),
            FilterChip(
              key: const ValueKey('trip-map-toggle-cameras'),
              selected: _showCameras,
              avatar: const Icon(Icons.photo_camera_rounded, size: 18),
              label: const Text('Cámaras'),
              onSelected: (value) => setState(() => _showCameras = value),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (widget.allowFullscreen)
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: _buildMap(context),
            ),
          )
        else
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: _buildMap(context),
            ),
          ),
        const SizedBox(height: AppSpacing.s),
        Text(_tollSummary, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        Text(_cameraSummary, style: AppTextStyles.caption),
      ],
    );
  }

  String get _tollSummary {
    final count = widget.associations.uniqueCurrentTollLocationCount;
    final noun = count == 1
        ? 'peaje inventariado próximo'
        : 'peajes inventariados próximos';
    final historical = widget.associations.uniqueHistoricalTollLocationCount;
    final historicalSummary = _showHistoricalTolls
        ? 'Históricos visibles: ${_locationCount(historical)} · '
              '${_passageCount(widget.associations.historicalTolls.length)}'
        : 'Históricos: $historical en capa separada oculta';
    return '$count $noun: ${_locationCount(count)} · '
        '${_passageCount(widget.associations.currentTolls.length)}. '
        '$historicalSummary; '
        'tarifas no disponibles y cobro activo no confirmado.';
  }

  String get _cameraSummary {
    final count = widget.associations.uniqueCameraLocationCount;
    if (count == 0) {
      return '0 cámaras próximas: 0 ubicaciones únicas · 0 pasos candidatos. '
          'No significa ruta libre de cámaras.';
    }
    final noun = count == 1
        ? 'cámara registrada próxima'
        : 'cámaras registradas próximas';
    return '$count $noun al recorrido: ${_locationCount(count)} · '
        '${_passageCount(widget.associations.cameras.length)}; '
        'vía y sentido no confirmados.';
  }

  Widget _buildMap(BuildContext context) {
    final coordinates = widget.geometry
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          key: const ValueKey('trip-route-map'),
          mapController: _mapController,
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: coordinates,
              padding: const EdgeInsets.fromLTRB(34, 38, 58, 44),
              maxZoom: 16,
              minZoom: 5,
            ),
            minZoom: 4,
            maxZoom: 18,
            backgroundColor: const Color(0xFFE8EEF1),
            interactionOptions: const InteractionOptions(
              flags:
                  InteractiveFlag.drag |
                  InteractiveFlag.flingAnimation |
                  InteractiveFlag.pinchMove |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.scrollWheelZoom,
            ),
          ),
          children: [
            if (widget.config.tilesEnabled && !_tilesUnavailable)
              TileLayer(
                key: ValueKey('trip-map-tiles-$_tileAttempt'),
                urlTemplate: widget.config.tileUrlTemplate,
                userAgentPackageName: widget.config.userAgentPackageName,
                tileProvider: widget.config.tileProvider,
                tileDisplay: const TileDisplay.instantaneous(),
                tileBuilder: (context, tileWidget, tile) {
                  if (!tile.loadError && tile.readyToDisplay) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _markTileReady(),
                    );
                  }
                  return tileWidget;
                },
                errorTileCallback: (_, _, _) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _markTilesUnavailable(),
                  );
                },
              ),
            if (_showRoute)
              PolylineLayer(
                key: const ValueKey('trip-route-polyline'),
                polylines: [
                  Polyline(
                    points: coordinates,
                    color: AppColors.teal,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(markers: _markers(coordinates)),
            if (widget.config.attributionLabel.isNotEmpty)
              RichAttributionWidget(
                attributions: [
                  LogoSourceAttribution(
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          widget.config.attributionLabel,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    height: 24,
                  ),
                ],
                showFlutterMapAttribution: false,
              ),
          ],
        ),
        Positioned(
          right: AppSpacing.s,
          top: AppSpacing.s,
          child: _MapControls(
            onZoomIn: () => _moveZoom(1),
            onZoomOut: () => _moveZoom(-1),
            onReframe: _reframe,
            onFullscreen: widget.allowFullscreen
                ? () => _showFullscreen(context)
                : null,
          ),
        ),
        if (_tilesUnavailable)
          Positioned(
            left: AppSpacing.s,
            right: 58,
            bottom: AppSpacing.s,
            child: _TileFailure(onRetry: _retryTiles),
          ),
        if (_selectedLocation case final location?)
          Positioned(
            left: AppSpacing.s,
            right: 58,
            bottom: AppSpacing.s,
            child: _MarkerDetails(
              location: location,
              tollInventory: widget.tollInventory,
              cameraPack: widget.cameraPack,
              cameraPackVersion: widget.cameraPackVersion,
              onClose: () => setState(() => _selectedLocation = null),
            ),
          ),
      ],
    );
  }

  List<Marker> _markers(List<LatLng> coordinates) => [
    Marker(
      point: coordinates.first,
      width: 38,
      height: 38,
      child: const _EndpointMarker(
        key: ValueKey('trip-route-start'),
        label: 'Inicio',
        icon: Icons.trip_origin_rounded,
        color: AppColors.green,
      ),
    ),
    Marker(
      point: coordinates.last,
      width: 38,
      height: 38,
      child: const _EndpointMarker(
        key: ValueKey('trip-route-end'),
        label: 'Destino',
        icon: Icons.location_on_rounded,
        color: AppColors.red,
      ),
    ),
    if (_showTolls)
      for (final association in widget.associations.currentTolls)
        Marker(
          point: LatLng(
            association.location.latitude,
            association.location.longitude,
          ),
          width: 48,
          height: 48,
          child: _MapMarkerButton(
            key: ValueKey(
              'trip-map-toll-${association.location.id}-${association.passageIndex}',
            ),
            tooltip: 'Ver peaje inventariado ${association.location.name}',
            icon: Icons.toll_rounded,
            color: AppColors.orange,
            onPressed: () =>
                setState(() => _selectedLocation = association.location),
          ),
        ),
    if (_showHistoricalTolls)
      for (final association in widget.associations.historicalTolls)
        Marker(
          point: LatLng(
            association.location.latitude,
            association.location.longitude,
          ),
          width: 48,
          height: 48,
          child: _MapMarkerButton(
            key: ValueKey(
              'trip-map-toll-${association.location.id}-${association.passageIndex}',
            ),
            tooltip:
                'Ver peaje histórico no operativo ${association.location.name}',
            icon: Icons.history_rounded,
            color: Colors.blueGrey,
            onPressed: () =>
                setState(() => _selectedLocation = association.location),
          ),
        ),
    if (_showCameras)
      for (final association in widget.associations.cameras)
        Marker(
          point: LatLng(
            association.location.latitude,
            association.location.longitude,
          ),
          width: 48,
          height: 48,
          child: _MapMarkerButton(
            key: ValueKey(
              'trip-map-camera-${association.location.id}-${association.passageIndex}',
            ),
            tooltip:
                'Ver cámara registrada ${association.location.address ?? association.location.id}',
            icon: Icons.photo_camera_rounded,
            color: AppColors.blue,
            onPressed: () =>
                setState(() => _selectedLocation = association.location),
          ),
        ),
  ];

  void _moveZoom(double delta) {
    _mapController.move(
      _mapController.camera.center,
      (_mapController.camera.zoom + delta).clamp(4, 18),
    );
  }

  void _reframe() {
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: widget.geometry
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false),
        padding: const EdgeInsets.fromLTRB(34, 38, 58, 44),
        maxZoom: 16,
        minZoom: 5,
      ),
    );
  }

  Future<void> _showFullscreen(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Vista previa de la ruta'),
            leading: IconButton(
              key: const ValueKey('trip-map-close-fullscreen'),
              tooltip: 'Cerrar mapa ampliado',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: TripRoutePreviewMap._fullscreen(
                routeId: widget.routeId,
                geometry: widget.geometry,
                tollInventory: widget.tollInventory,
                cameraPack: widget.cameraPack,
                cameraPackVersion: widget.cameraPackVersion,
                config: widget.config,
                associations: widget.associations,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _cameraPackIdentity(CameraPack pack, String version) =>
    '$version|${pack.source.dataUrl}|${pack.source.fetchedAtUtc}';

class _MissingGeometry extends StatelessWidget {
  const _MissingGeometry();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, color: AppColors.navy, size: 36),
          SizedBox(height: AppSpacing.s),
          Text(
            'Vista previa no disponible: la ruta no incluyó geometría vial suficiente.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong,
          ),
        ],
      ),
    );
  }
}

class _EndpointMarker extends StatelessWidget {
  const _EndpointMarker({
    required this.label,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 23),
    ),
  );
}

class _MapMarkerButton extends StatelessWidget {
  const _MapMarkerButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white, width: 2),
    ),
    icon: Icon(icon, size: 20),
  );
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReframe,
    required this.onFullscreen,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReframe;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.card),
    elevation: 2,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button('trip-map-zoom-in', 'Acercar', Icons.add_rounded, onZoomIn),
        _button('trip-map-zoom-out', 'Alejar', Icons.remove_rounded, onZoomOut),
        _button(
          'trip-map-reframe',
          'Ver ruta completa',
          Icons.center_focus_strong_rounded,
          onReframe,
        ),
        if (onFullscreen != null)
          _button(
            'trip-map-fullscreen',
            'Ampliar mapa',
            Icons.fullscreen_rounded,
            onFullscreen!,
          ),
      ],
    ),
  );

  Widget _button(
    String keyName,
    String tooltip,
    IconData icon,
    VoidCallback onPressed,
  ) => IconButton(
    key: ValueKey(keyName),
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}

class _TileFailure extends StatelessWidget {
  const _TileFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.95),
    borderRadius: BorderRadius.circular(AppRadius.card),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'El mapa base no está disponible. La ruta y los puntos siguen visibles.',
              style: AppTextStyles.caption,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar mapa')),
        ],
      ),
    ),
  );
}

class _MarkerDetails extends StatelessWidget {
  const _MarkerDetails({
    required this.location,
    required this.tollInventory,
    required this.cameraPack,
    required this.cameraPackVersion,
    required this.onClose,
  });

  final Object location;
  final TollInventoryDataset tollInventory;
  final CameraPack cameraPack;
  final String cameraPackVersion;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final (title, lines) = switch (location) {
      TollInventoryRecord record => (
        record.name,
        [
          record.previewOperationLabel,
          'Este punto físico no confirma un cobro activo.',
          'Tarifa actual no disponible',
          'Inventario ${tollInventory.version} · corte ${_dateOnly(tollInventory.sourceTimestamp)}',
          'El corte no confirma vigencia operativa.',
          'Fuente inventario: ${record.inventorySource}',
          'Fuente GPS: ${record.gpsSource}',
        ],
      ),
      TrafficCamera camera => (
        camera.address ?? camera.locality,
        [
          'Cámara registrada próxima al recorrido; el sentido no está confirmado.',
          'Pack $cameraPackVersion · captura ${_cameraSnapshotDate(cameraPack.source.fetchedAtUtc)}',
          'La captura no confirma vigencia operativa.',
          'Fuente: ${cameraPack.source.name}',
          cameraPack.source.pageUrl,
        ],
      ),
      _ => ('Detalle no disponible', const <String>[]),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 238),
      child: Material(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppTextStyles.bodyStrong),
                      for (final line in lines)
                        Text(line, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar detalle',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _cameraSnapshotDate(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? 'no disponible' : _dateOnly(parsed.toUtc());
}

String _locationCount(int count) =>
    count == 1 ? '1 ubicación única' : '$count ubicaciones únicas';

String _passageCount(int count) =>
    count == 1 ? '1 paso candidato' : '$count pasos candidatos';
