part of 'fotomultas_screen.dart';

// Test overrides replace only this feature's tiles, never the shared cache.
final fotomultasTileProviderFactory = Provider<TileProvider Function()>(
  (ref) =>
      () => NetworkTileProvider(),
);

class _DepartmentMapView extends StatefulWidget {
  const _DepartmentMapView({
    super.key,
    required this.cameras,
    required this.onShowDetails,
    required this.geometry,
    required this.departmentCode,
    required this.overlayPadding,
    required this.onShowList,
  });
  final List<TrafficCamera> cameras;
  final ValueChanged<TrafficCamera> onShowDetails;
  final DepartmentGeometry? geometry;
  final String departmentCode;
  final EdgeInsets overlayPadding;
  final VoidCallback onShowList;
  @override
  State<_DepartmentMapView> createState() => _DepartmentMapViewState();
}

class _DepartmentMapViewState extends State<_DepartmentMapView> {
  final _controller = MapController();
  late TileProvider _tiles;
  bool _initialized = false, _ready = false, _tileError = false;
  int _tileGeneration = 0;
  List<TrafficCamera>? _groupedInput;
  double? _groupedZoom;
  List<_CameraCluster> _groups = [];

  void locate(TrafficCamera camera) {
    if (_ready && _hasValidCoordinate(camera)) {
      _controller.move(LatLng(camera.latitude, camera.longitude), 16);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _tiles = ProviderScope.containerOf(context)
          .read(fotomultasTileProviderFactory)();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CameraFit get _initialFit {
    final geo = widget.geometry;
    if (geo != null && geo.labelParts.containsKey(widget.departmentCode)) {
      return CameraFit.bounds(
        bounds: geo.boundsFor(widget.departmentCode),
        padding: widget.overlayPadding,
        maxZoom: 13,
      );
    }
    final valid = widget.cameras
        .where(_hasValidCoordinate)
        .map((c) => LatLng(c.latitude, c.longitude))
        .toList();
    return CameraFit.bounds(
      bounds: valid.isEmpty
          ? LatLngBounds(const LatLng(-4.3, -79), const LatLng(12.5, -67))
          : LatLngBounds.fromPoints(valid),
      padding: widget.overlayPadding,
      maxZoom: 13,
    );
  }

  void _openGroup(_CameraCluster group) {
    if (group.cameras.length == 1) {
      widget.onShowDetails(group.cameras.single);
      return;
    }
    final locations = group.cameras
        .map((c) => LatLng(c.latitude, c.longitude))
        .toList();
    final bounds = LatLngBounds.fromPoints(locations);
    final coincident =
        bounds.north - bounds.south < 0.000001 &&
        bounds.east - bounds.west < 0.000001;
    if (!coincident && _controller.camera.zoom < 17.99) {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: widget.overlayPadding,
          maxZoom: 18,
          minZoom: math.min(18, _controller.camera.zoom + 1),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${group.cameras.length} cámaras en este grupo',
                  style: AppTextStyles.h2,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('fotomultas-cluster-records'),
                  itemCount: group.cameras.length,
                  itemBuilder: (context, index) {
                    final camera = group.cameras[index];
                    return ListTile(
                      key: ValueKey('fotomultas-cluster-record-${camera.id}'),
                      title: Text(
                        _valueOrFallback(
                          camera.address,
                          'Cámara del inventario',
                        ),
                      ),
                      subtitle: Text(_location(camera)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onShowDetails(camera);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_CameraCluster> _clusters(MapCamera camera) {
    if (identical(widget.cameras, _groupedInput) &&
        camera.zoom == _groupedZoom) {
      return _groups;
    }
    _groupedInput = widget.cameras;
    _groupedZoom = camera.zoom;
    final cameras = widget.cameras.where(_hasValidCoordinate).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final positions = cameras
        .map((c) => camera.projectAtZoom(LatLng(c.latitude, c.longitude)))
        .toList();
    final groups = <List<int>>[];
    for (var i = 0; i < cameras.length; i++) {
      final group = groups
          .where(
            (g) => g.any((j) => (positions[i] - positions[j]).distance < 64),
          )
          .firstOrNull;
      if (group == null) {
        groups.add([i]);
      } else {
        group.add(i);
      }
    }
    Offset center(List<int> group) =>
        group.map((i) => positions[i]).reduce((a, b) => a + b) /
        group.length.toDouble();
    // Merge neighboring centroids as well: separate grid buckets can still overlap.
    var merged = true;
    while (merged) {
      merged = false;
      for (var a = 0; a < groups.length && !merged; a++) {
        for (var b = a + 1; b < groups.length; b++) {
          if ((center(groups[a]) - center(groups[b])).distance >= 64) continue;
          groups[a].addAll(groups.removeAt(b));
          merged = true;
          break;
        }
      }
    }
    _groups = groups
        .map(
          (g) => _CameraCluster(
            id: cameras[g.first].id,
            center: camera.unprojectAtZoom(center(g)),
            cameras: g.map((i) => cameras[i]).toList(),
          ),
        )
        .toList();
    return _groups;
  }

  void _retryTiles() {
    setState(() {
      _tileError = false;
      _tiles = ProviderScope.containerOf(context)
          .read(fotomultasTileProviderFactory)();
      _tileGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          key: const ValueKey('fotomultas-department-map'),
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: _initialFit,
            minZoom: 4,
            maxZoom: 18,
            onMapReady: () => setState(() => _ready = true),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (_, _) {
              if (_ready) setState(() {});
            },
          ),
          children: [
            TileLayer(
              key: ValueKey('fotomultas-tiles-$_tileGeneration'),
              tileProvider: _tiles,
              urlTemplate: _tileUrlTemplate,
              userAgentPackageName: _tileUserAgent,
              tileDisplay: const TileDisplay.instantaneous(),
              errorTileCallback: (_, _, _) {
                if (_tileError) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_tileError) setState(() => _tileError = true);
                });
                WidgetsBinding.instance.ensureVisualUpdate();
              },
            ),
            Builder(
              builder: (context) {
                final camera = MapCamera.of(context);
                final visible = (Offset.zero & camera.nonRotatedSize).inflate(
                  48,
                );
                return MarkerLayer(
                  markers: [
                    for (final group in _clusters(camera))
                      if (visible.contains(
                        camera.latLngToScreenOffset(group.center),
                      ))
                        Marker(
                          key: ValueKey('fotomultas-map-cluster-${group.id}'),
                          point: group.center,
                          width: 48,
                          height: 48,
                          child: Semantics(
                            label: '${group.cameras.length} cámaras',
                            button: true,
                            child: _CameraMapMarker(
                              count: group.cameras.length,
                              onTap: () => _openGroup(group),
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
        Positioned(
          top: widget.overlayPadding.top,
          right: 12,
          child: Column(
            children: [
              _CountryMapControl(
                key: const ValueKey('fotomultas-department-zoom-in'),
                tooltip: 'Acercar cámaras',
                icon: Icons.add,
                onPressed: !_ready || _controller.camera.zoom >= 18
                    ? null
                    : () => _controller.move(
                        _controller.camera.center,
                        math.min(18, _controller.camera.zoom + 1),
                      ),
              ),
              _CountryMapControl(
                key: const ValueKey('fotomultas-department-zoom-out'),
                tooltip: 'Alejar cámaras',
                icon: Icons.remove,
                onPressed: !_ready || _controller.camera.zoom <= 4
                    ? null
                    : () => _controller.move(
                        _controller.camera.center,
                        math.max(4, _controller.camera.zoom - 1),
                      ),
              ),
              _CountryMapControl(
                key: const ValueKey('fotomultas-department-reset'),
                tooltip: 'Ver departamento',
                icon: Icons.fit_screen,
                onPressed: _ready
                    ? () => _controller.fitCamera(_initialFit)
                    : null,
              ),
            ],
          ),
        ),
        if (_tileError || widget.cameras.isEmpty)
          Positioned(
            top: widget.overlayPadding.top,
            left: 16,
            right: 76,
            child: Material(
              key: const ValueKey('fotomultas-map-status'),
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_tileError)
                      Text(
                        'Mapa no disponible',
                        style: _departmentStyle(context, 14),
                      ),
                    if (widget.cameras.isEmpty)
                      Text(
                        'Sin resultados',
                        key: const ValueKey('fotomultas-empty-search'),
                        style: _departmentStyle(context, 14),
                      ),
                    if (_tileError) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          IconButton.outlined(
                            key: const ValueKey('fotomultas-retry-tiles'),
                            tooltip: 'Reintentar mapa',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: _retryTiles,
                            icon: const Icon(Icons.refresh),
                          ),
                          IconButton.outlined(
                            tooltip: 'Ver lista de cámaras',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: widget.onShowList,
                            icon: const Icon(Icons.list),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              key: const ValueKey('fotomultas-map-attribution'),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: _departmentStyle(context, 11),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
