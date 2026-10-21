import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_tokens.dart';
import '../../location/application/location_controller.dart';
import '../../location/platform/device_location_gateway.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../data/cda_catalog.dart';
import '../data/cda_geography.dart';
import '../domain/cda_spatial_query.dart';

final cdaTileProviderFactory = Provider<TileProvider Function()>(
  (ref) =>
      () =>
          NetworkTileProvider(headers: {'User-Agent': 'co.picoradar.app.cda'}),
);

class CdaMapView extends ConsumerStatefulWidget {
  const CdaMapView({
    super.key,
    required this.catalog,
    required this.geography,
    required this.onOpen,
    required this.now,
    this.nearMe = false,
  });

  final CdaCatalog catalog;
  final CdaGeography geography;
  final ValueChanged<CdaCatalogEntry> onOpen;
  final DateTime now;
  final bool nearMe;

  @override
  ConsumerState<CdaMapView> createState() => _CdaMapViewState();
}

enum _CdaMapMode { map, list }

class _CdaMapViewState extends ConsumerState<CdaMapView> {
  final _controller = MapController();
  late TileProvider _tiles;
  _CdaMapMode _mode = _CdaMapMode.map;
  String _query = '';
  LatLng? _origin;
  double? _accuracyMeters;
  String? _locationMessage;
  int _operation = 0;
  List<CdaSpatialMatch> _results = const [];
  List<CdaSpatialMatch>? _groupInput;
  double? _groupZoom;
  List<CdaSpatialGroup> _groups = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tiles = ref.read(cdaTileProviderFactory)();
    _mode = _CdaMapMode.map;
    _requery();
    if (widget.nearMe) _requestLocation();
  }

  @override
  void dispose() {
    _operation++;
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _requery({bool viewport = false}) {
    _results = queryCdaSites(
      catalog: widget.catalog,
      geography: widget.geography,
      now: widget.now,
      query: _query,
      origin: _origin,
      radiusMeters: _origin != null && !viewport ? 15000 : null,
      bounds: viewport && _controller.camera.nonRotatedSize != Size.zero
          ? CdaSpatialBounds(
              south: _controller.camera.visibleBounds.south,
              west: _controller.camera.visibleBounds.west,
              north: _controller.camera.visibleBounds.north,
              east: _controller.camera.visibleBounds.east,
            )
          : null,
    );
    _groupInput = null;
  }

  Future<void> _openAttribution() async {
    var opened = false;
    try {
      opened = await ref
          .read(externalLauncherProvider)
          .openExternal('https://www.openstreetmap.org/copyright');
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la atribución del mapa.'),
        ),
      );
  }

  Future<void> _requestLocation() async {
    final operation = ++_operation;
    final gateway = ref.read(deviceLocationGatewayProvider);
    if (!await gateway.isLocationServiceEnabled()) {
      if (!mounted || operation != _operation) return;
      setState(() => _locationMessage = 'Servicio de ubicación desactivado');
      return;
    }
    var permission = await gateway.checkPermission();
    if (permission != DeviceLocationPermission.granted) {
      permission = await gateway.requestPermission();
    }
    if (permission != DeviceLocationPermission.granted) {
      if (!mounted || operation != _operation) return;
      setState(() => _locationMessage = 'permiso de ubicación requerido');
      return;
    }
    final result = await gateway.getCurrentPosition();
    if (!mounted || operation != _operation) return;
    if (result is! DeviceLocationSuccess) {
      setState(() => _locationMessage = 'Ubicación no disponible');
      return;
    }
    final point = result.point;
    final origin = LatLng(point.latitude, point.longitude);
    setState(() {
      _origin = origin;
      _accuracyMeters = point.accuracyMeters;
      _locationMessage = null;
      _requery();
      _mode = _CdaMapMode.map;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || operation != _operation) return;
      _controller.move(origin, 13);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      IndexedStack(
        index: _mode.index,
        children: [_map(context), _list(context)],
      ),
      Positioned(left: 16, right: 16, top: 8, child: _toolbar(context)),
      if (_mode == _CdaMapMode.map)
        Positioned(
          top: _toolbarHeight(context) + 16,
          right: 8,
          child: Column(
            children: [
              _MapControl(
                tooltip: 'Ubicarme',
                icon: Icons.my_location,
                onPressed: _requestLocation,
              ),
              _MapControl(
                tooltip: 'Acercar',
                icon: Icons.add,
                onPressed: () => _controller.move(
                  _controller.camera.center,
                  math.min(18, _controller.camera.zoom + 1),
                ),
              ),
              _MapControl(
                tooltip: 'Alejar',
                icon: Icons.remove,
                onPressed: () => _controller.move(
                  _controller.camera.center,
                  math.max(4, _controller.camera.zoom - 1),
                ),
              ),
            ],
          ),
        ),
      if (_mode == _CdaMapMode.map && _locationMessage != null)
        Positioned(
          left: 16,
          right: 72,
          top: _toolbarHeight(context) + 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _locationMessage!,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reintentar ubicación',
                    onPressed: _requestLocation,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
        ),
      if (_mode == _CdaMapMode.map)
        Positioned(
          left: 8,
          bottom: 8,
          child: TextButton(
            key: const ValueKey('cda-attribution'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.86),
              minimumSize: const Size(48, 48),
            ),
            onPressed: _openAttribution,
            child: const Text('© OpenStreetMap contributors'),
          ),
        ),
    ],
  );

  Widget _map(BuildContext context) => FlutterMap(
    mapController: _controller,
    options: MapOptions(
      initialCameraFit: CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(
            CdaSpatialBounds.national.south,
            CdaSpatialBounds.national.west,
          ),
          LatLng(
            CdaSpatialBounds.national.north,
            CdaSpatialBounds.national.east,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(48, 96, 64, 64),
        maxZoom: 7,
      ),
      minZoom: 4,
      maxZoom: 18,
      interactionOptions: const InteractionOptions(
        flags:
            InteractiveFlag.drag |
            InteractiveFlag.pinchZoom |
            InteractiveFlag.doubleTapZoom |
            InteractiveFlag.scrollWheelZoom |
            InteractiveFlag.flingAnimation,
      ),
      onPositionChanged: (_, hasGesture) {
        if (!hasGesture) {
          setState(() {});
          return;
        }
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          setState(() => _requery(viewport: true));
        });
      },
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'co.picoradar.app.cda',
        tileProvider: _tiles,
        tileDisplay: const TileDisplay.instantaneous(),
      ),
      Builder(
        builder: (context) {
          final camera = MapCamera.of(context);
          return MarkerLayer(
            markers: [
              if (_origin != null)
                Marker(
                  point: _origin!,
                  width: 58,
                  height: 58,
                  child: const _UserMarker(),
                ),
              for (final group in _groupsFor(camera))
                Marker(
                  point: group.anchor.point,
                  width: 54,
                  height: 54,
                  child: _CdaMarker(
                    key: ValueKey('cda-group-${group.anchor.entry.id}'),
                    count: group.members.length,
                    onTap: () => _openGroup(group),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _toolbar(BuildContext context) => Column(
    key: const ValueKey('cda-map-toolbar'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: 'Buscar CDA',
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: _search,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.navy),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _query.isEmpty ? 'Buscar CDA' : _query,
                        style: AppTextStyles.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Ver lista',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _mode == _CdaMapMode.list
                      ? AppColors.teal
                      : Colors.white.withValues(alpha: 0.94),
                  foregroundColor: _mode == _CdaMapMode.list
                      ? Colors.white
                      : AppColors.navy,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => setState(() => _mode = _CdaMapMode.list),
                icon: const Icon(Icons.list),
                label: const Text('Lista'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: 'Ver mapa',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _mode == _CdaMapMode.map
                      ? AppColors.teal
                      : Colors.white.withValues(alpha: 0.94),
                  foregroundColor: _mode == _CdaMapMode.map
                      ? Colors.white
                      : AppColors.navy,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => setState(() => _mode = _CdaMapMode.map),
                icon: const Icon(Icons.map_outlined),
                label: Text(_mode == _CdaMapMode.map ? 'Mapa' : 'Ver mapa'),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  double _toolbarHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return 112 * math.min(scale, 1.6);
  }

  Widget _list(BuildContext context) {
    final status = _origin != null
        ? '${(_results.isEmpty ? 0 : 15)} km · ${_accuracyMeters?.round() ?? 0} m'
        : _locationMessage;
    return ColoredBox(
      color: AppColors.background,
      child: ListView.builder(
        key: const ValueKey('cda-results'),
        padding: EdgeInsets.fromLTRB(16, _toolbarHeight(context) + 32, 16, 72),
        itemCount: math.max(1, _results.length + 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      status ?? '${_results.length} centros',
                      style: AppTextStyles.caption,
                    ),
                  ),
                  if (_locationMessage != null)
                    IconButton(
                      tooltip: 'Reintentar ubicación',
                      onPressed: _requestLocation,
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
            );
          }
          final match = _results[index - 1];
          return Material(
            key: ValueKey('cda-result-${match.entry.id}'),
            color: Colors.white,
            child: ListTile(
              minTileHeight: 64,
              title: Text(match.entry.name, style: AppTextStyles.bodyStrong),
              subtitle: Text(
                '${match.entry.municipality} · ${match.entry.department}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onOpen(match.entry),
            ),
          );
        },
      ),
    );
  }

  List<CdaSpatialGroup> _groupsFor(MapCamera camera) {
    if (identical(_groupInput, _results) && _groupZoom == camera.zoom) {
      return _groups;
    }
    _groupInput = _results;
    _groupZoom = camera.zoom;
    _groups = groupCdaSites(
      _results,
      project: (lat, lon) {
        final offset = camera.latLngToScreenOffset(LatLng(lat, lon));
        return (x: offset.dx, y: offset.dy);
      },
    );
    return _groups;
  }

  Future<void> _search() async {
    var draft = _query;
    final next = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('cda-search-input'),
                initialValue: draft,
                autofocus: true,
                onChanged: (value) => draft = value,
                decoration: const InputDecoration(
                  hintText: 'Nombre, ciudad o departamento',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.teal,
                ),
                onPressed: () => Navigator.of(context).pop(draft),
                child: const Text('Aplicar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (next == null || !mounted) return;
    setState(() {
      _operation++;
      _query = next.trim();
      _origin = null;
      _accuracyMeters = null;
      _locationMessage = null;
      _requery();
      _mode = _CdaMapMode.map;
    });
  }

  void _openGroup(CdaSpatialGroup group) {
    if (group.members.length == 1) {
      widget.onOpen(group.anchor.entry);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: ListView.builder(
            key: const ValueKey('cda-group-members'),
            itemCount: group.members.length,
            itemBuilder: (context, index) {
              final match = group.members[index];
              return ListTile(
                key: ValueKey('cda-member-${match.entry.id}'),
                title: Text(match.entry.name),
                subtitle: Text(match.entry.municipality),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onOpen(match.entry);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Material(
          color: Colors.white.withValues(alpha: 0.78),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 22, color: AppColors.navy),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CdaMarker extends StatelessWidget {
  const _CdaMarker({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count CDA',
    child: GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.teal,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(blurRadius: 10, color: Color(0x33000000)),
          ],
        ),
        child: Center(
          child: count == 1
              ? const Icon(Icons.garage_outlined, color: Colors.white)
              : Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
      ),
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    ],
  );
}

// Keeps the test tile fully self-contained and avoids real network in widgets.
ImageProvider cdaTransparentPixel() => MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
);
