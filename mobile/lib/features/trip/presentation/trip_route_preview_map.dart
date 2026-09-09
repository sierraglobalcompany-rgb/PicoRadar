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
import '../data/toll_tariff_catalog.dart';
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
    this.demoLabel,
    this.tollTariffCatalog,
    this.mapController,
    this.allowFullscreen = true,
    this.compact = false,
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
    this.demoLabel,
    this.tollTariffCatalog,
  }) : mapController = null,
       allowFullscreen = false,
       compact = false;

  final String routeId;
  final List<TripCoordinate> geometry;
  final TollInventoryDataset tollInventory;
  final TollTariffCatalog? tollTariffCatalog;
  final CameraPack cameraPack;
  final String cameraPackVersion;
  final TripRouteAssociations associations;
  final TripRouteMapConfig config;
  final String? demoLabel;
  final MapController? mapController;
  final bool allowFullscreen;
  final bool compact;

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
        oldWidget.tollTariffCatalog?.version !=
            widget.tollTariffCatalog?.version ||
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
    Widget content(Widget map) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          _buildLayerControls(),
          const SizedBox(height: AppSpacing.s),
        ],
        map,
        if (!widget.compact) ...[
          const SizedBox(height: AppSpacing.s),
          Text(_tollSummary, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(_cameraSummary, style: AppTextStyles.caption),
        ],
      ],
    );

    if (widget.allowFullscreen) {
      return content(
        SizedBox(
          height: widget.compact ? 304 : 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: _buildMap(context),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('trip-map-fullscreen-scroll'),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: content(
            SizedBox(
              height: (constraints.maxHeight * 0.55).clamp(260.0, 480.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: _buildMap(context),
              ),
            ),
          ),
        ),
      ),
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
    final currentIds = widget.associations.currentTolls
        .map((association) => association.location.id)
        .toSet();
    final pricedCount = widget.tollTariffCatalog == null
        ? 0
        : currentIds
              .where(
                (id) =>
                    widget.tollTariffCatalog!.byId(id)?.categoryI?.amountCop !=
                    null,
              )
              .length;
    final tariffSummary = widget.tollTariffCatalog == null
        ? 'tarifas locales cargando'
        : 'Cat I disponible para $pricedCount de ${currentIds.length} ubicaciones';
    return '$count $noun: ${_locationCount(count)} · '
        '${_passageCount(widget.associations.currentTolls.length)}. '
        '$historicalSummary; '
        '$tariffSummary; cobro activo no confirmado.';
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.compact) ...[
                _buildLayerControls(),
                const SizedBox(height: AppSpacing.xs),
              ],
              _MapControls(
                onZoomIn: () => _moveZoom(1),
                onZoomOut: () => _moveZoom(-1),
                onReframe: _reframe,
                onFullscreen: widget.allowFullscreen
                    ? () => _showFullscreen(context)
                    : null,
              ),
            ],
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
              tollTariffCatalog: widget.tollTariffCatalog,
              cameraPack: widget.cameraPack,
              cameraPackVersion: widget.cameraPackVersion,
              demoLabel: widget.demoLabel,
              onClose: () => setState(() => _selectedLocation = null),
            ),
          ),
        if (widget.demoLabel case final label?)
          Positioned(
            left: AppSpacing.s,
            right: 58,
            top: AppSpacing.s,
            child: _MapDemoBanner(label: label),
          ),
      ],
    );
  }

  Widget _buildLayerControls() => _LayerControls(
    showRoute: _showRoute,
    showTolls: _showTolls,
    showHistoricalTolls: _showHistoricalTolls,
    showCameras: _showCameras,
    compact: widget.compact,
    onRoute: (value) => setState(() => _showRoute = value),
    onTolls: (value) => setState(() => _showTolls = value),
    onHistoricalTolls: (value) => setState(() => _showHistoricalTolls = value),
    onCameras: (value) => setState(() => _showCameras = value),
  );

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
                tollTariffCatalog: widget.tollTariffCatalog,
                cameraPack: widget.cameraPack,
                cameraPackVersion: widget.cameraPackVersion,
                config: widget.config,
                associations: widget.associations,
                demoLabel: widget.demoLabel,
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

class _LayerControls extends StatelessWidget {
  const _LayerControls({
    required this.showRoute,
    required this.showTolls,
    required this.showHistoricalTolls,
    required this.showCameras,
    required this.compact,
    required this.onRoute,
    required this.onTolls,
    required this.onHistoricalTolls,
    required this.onCameras,
  });

  final bool showRoute;
  final bool showTolls;
  final bool showHistoricalTolls;
  final bool showCameras;
  final bool compact;
  final ValueChanged<bool> onRoute;
  final ValueChanged<bool> onTolls;
  final ValueChanged<bool> onHistoricalTolls;
  final ValueChanged<bool> onCameras;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _LayerToggle(
        keyName: 'trip-map-toggle-route',
        selected: showRoute,
        icon: Icons.route_rounded,
        label: 'Ruta',
        onSelected: onRoute,
      ),
      _LayerToggle(
        keyName: 'trip-map-toggle-tolls',
        selected: showTolls,
        icon: Icons.toll_rounded,
        label: 'Peajes',
        onSelected: onTolls,
      ),
      _LayerToggle(
        keyName: 'trip-map-toggle-historical-tolls',
        selected: showHistoricalTolls,
        icon: Icons.history_rounded,
        label: 'Históricos',
        onSelected: onHistoricalTolls,
      ),
      _LayerToggle(
        keyName: 'trip-map-toggle-cameras',
        selected: showCameras,
        icon: Icons.photo_camera_rounded,
        label: 'Cámaras',
        onSelected: onCameras,
      ),
    ];
    if (!compact) {
      return Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: chips,
      );
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      elevation: 2,
      child: PopupMenuButton<String>(
        key: const ValueKey('trip-map-layer-menu'),
        tooltip: 'Capas del mapa',
        icon: const Icon(Icons.layers_outlined),
        itemBuilder: (context) => [
          _menuItem('route', 'Ruta', showRoute),
          _menuItem('tolls', 'Peajes', showTolls),
          _menuItem('historical', 'Históricos', showHistoricalTolls),
          _menuItem('cameras', 'Cámaras', showCameras),
        ],
        onSelected: (value) {
          switch (value) {
            case 'route':
              onRoute(!showRoute);
            case 'tolls':
              onTolls(!showTolls);
            case 'historical':
              onHistoricalTolls(!showHistoricalTolls);
            case 'cameras':
              onCameras(!showCameras);
          }
        },
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label, bool selected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(selected ? Icons.check_box : Icons.check_box_outline_blank),
          const SizedBox(width: AppSpacing.s),
          Text(label),
        ],
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
    required this.keyName,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final String keyName;
  final bool selected;
  final IconData icon;
  final String label;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    key: ValueKey(keyName),
    selected: selected,
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onSelected: onSelected,
  );
}

class _TileFailure extends StatelessWidget {
  const _TileFailure({required this.onRetry});

  static const _message =
      'El mapa base no está disponible. La ruta y los puntos siguen visibles.';

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('trip-map-tile-failure'),
    container: true,
    liveRegion: true,
    label: _message,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const message = ExcludeSemantics(
          child: Text(_message, style: AppTextStyles.caption),
        );
        final retry = TextButton(
          onPressed: onRetry,
          child: const Text('Reintentar mapa'),
        );
        final compact =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        return Material(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      message,
                      Align(alignment: Alignment.centerRight, child: retry),
                    ],
                  )
                : Row(
                    children: [
                      const Expanded(child: message),
                      retry,
                    ],
                  ),
          ),
        );
      },
    ),
  );
}

class _MarkerDetails extends StatelessWidget {
  const _MarkerDetails({
    required this.location,
    required this.tollInventory,
    required this.tollTariffCatalog,
    required this.cameraPack,
    required this.cameraPackVersion,
    required this.demoLabel,
    required this.onClose,
  });

  final Object location;
  final TollInventoryDataset tollInventory;
  final TollTariffCatalog? tollTariffCatalog;
  final CameraPack cameraPack;
  final String cameraPackVersion;
  final String? demoLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final (title, lines) = switch (location) {
      TollInventoryRecord record => _tollDetails(record),
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
                      if (demoLabel != null) ...[
                        Text(
                          demoLabel!,
                          key: const ValueKey('trip-demo-marker-detail'),
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF5D4100),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

  (String, List<String>) _tollDetails(TollInventoryRecord record) {
    final station = tollTariffCatalog?.byId(record.id);
    final rateLines = station == null
        ? ['Tarifas propias cargando o no disponibles para este ID.']
        : [
            'Tarifas propias ${tollTariffCatalog!.version} · Cat I: ${_copPesosOrNoData(station.categoryI?.amountCop)}',
            _compactCategories(station.generalRates),
            '${station.publicationControl ?? 'Control no informado'} · ${station.categoryI?.sourceType ?? 'fuente no informada'}${station.categoryI?.sourceDate == null ? '' : ' · ${station.categoryI!.sourceDate}'}',
            if (station.specialRates.isNotEmpty)
              '${station.specialRates.length} tarifa(s) especial(es) no aplicadas sin elegibilidad.',
          ];
    return (
      station?.name ?? record.name,
      [
        record.previewOperationLabel,
        'Este punto físico no confirma un cobro activo.',
        ...rateLines,
        'Inventario ${tollInventory.version} · corte ${_dateOnly(tollInventory.sourceTimestamp)}',
        'El corte no confirma vigencia operativa.',
        'Fuente inventario: ${record.inventorySource}',
        'Fuente GPS: ${record.gpsSource}',
      ],
    );
  }
}

class _MapDemoBanner extends StatelessWidget {
  const _MapDemoBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF3C4).withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(AppRadius.card),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        label,
        key: const ValueKey('trip-demo-map-banner'),
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          color: const Color(0xFF5D4100),
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
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

String _compactCategories(List<TollTariffRate> rates) {
  final visible = rates.where((rate) => rate.categoryCode.length <= 4).take(7);
  return visible
      .map(
        (rate) => '${rate.categoryCode} ${_copPesosOrNoData(rate.amountCop)}',
      )
      .join(' · ');
}

String _copPesosOrNoData(int? pesos) {
  if (pesos == null) {
    return 'sin dato';
  }
  final digits = pesos.abs().toString();
  final buffer = StringBuffer(r'$');
  if (pesos < 0) buffer.write('-');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
