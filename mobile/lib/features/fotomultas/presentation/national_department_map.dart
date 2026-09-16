part of 'fotomultas_screen.dart';

class _NationalMap extends StatefulWidget {
  const _NationalMap({
    super.key,
    required this.geometry,
    required this.selectedCode,
    required this.names,
    required this.onCandidates,
    required this.onReset,
  });
  final DepartmentGeometry geometry;
  final String? selectedCode;
  final Map<String, String> names;
  final ValueChanged<List<String>> onCandidates;
  final VoidCallback onReset;
  @override
  State<_NationalMap> createState() => _NationalMapState();
}

class _NationalMapState extends State<_NationalMap> {
  final _controller = MapController();
  double _minimumZoom = 0;
  bool _ready = false;
  String? _pendingFit;
  final _labelSizes = <(String, TextStyle, TextScaler), Size>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _labelSizes.clear();
  }

  @override
  void didUpdateWidget(covariant _NationalMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geometry != widget.geometry) _labelSizes.clear();
  }

  CameraFit get _countryFit => CameraFit.bounds(
    bounds: widget.geometry.continentalBounds,
    padding: const EdgeInsets.fromLTRB(52, 12, 60, 14),
    maxZoom: 8,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void fitDepartment(String code) {
    if (!_ready) {
      _pendingFit = code;
      return;
    }
    if (!widget.geometry.labelParts.containsKey(code)) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: widget.geometry.boundsFor(code),
        padding: const EdgeInsets.fromLTRB(48, 60, 60, 32),
        maxZoom: 11.0,
        minZoom: _minimumZoom,
      ),
    );
  }

  void _reset() {
    widget.onReset();
    // The selection card is removed first, so fit uses the expanded viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _minimumZoom = _countryFit.fit(_controller.camera).zoom);
      _controller.fitCamera(_countryFit);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        key: const ValueKey('fotomultas-colombia-map'),
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: const LatLng(4.5, -74),
              backgroundColor: const Color(0xfff6fafb),
              initialCameraFit: _countryFit,
              minZoom: _minimumZoom,
              maxZoom: 12,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(
                  const LatLng(-6, -84),
                  const LatLng(16, -65),
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom |
                    InteractiveFlag.flingAnimation,
              ),
              onMapReady: () {
                _ready = true;
                setState(
                  () => _minimumZoom = _countryFit.fit(_controller.camera).zoom,
                );
                final pending = _pendingFit ?? widget.selectedCode;
                if (pending != null) fitDepartment(pending);
              },
              onTap: (_, point) => widget.onCandidates(
                widget.geometry.candidates(point, _controller.camera.zoom),
              ),
              onPositionChanged: (_, _) {
                if (_ready) setState(() {});
              },
            ),
            children: [
              PolygonLayer<String>(
                polygonCulling: true,
                simplificationTolerance: 0,
                polygons: [
                  for (final part in widget.geometry.parts)
                    part.cameraCode == widget.selectedCode
                        ? part.selectedPolygon()
                        : part.polygon,
                ],
              ),
              Builder(
                builder: (context) => _labels(context, MapCamera.of(context)),
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 12,
            child: _CountryMapControl(
              key: const ValueKey('fotomultas-country-reset'),
              tooltip: 'Ver Colombia',
              icon: Icons.fit_screen,
              label: MediaQuery.textScalerOf(context).scale(13) <= 17
                  ? 'Ver Colombia'
                  : null,
              onPressed: _ready ? _reset : null,
            ),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: Column(
              children: [
                _CountryMapControl(
                  key: const ValueKey('fotomultas-country-zoom-in'),
                  tooltip: 'Acercar Colombia',
                  icon: Icons.add,
                  onPressed: !_ready || _controller.camera.zoom >= 12
                      ? null
                      : () => _controller.move(
                          _controller.camera.center,
                          math.min(12, _controller.camera.zoom + 1),
                        ),
                ),
                _CountryMapControl(
                  key: const ValueKey('fotomultas-country-zoom-out'),
                  tooltip: 'Alejar Colombia',
                  icon: Icons.remove,
                  onPressed:
                      !_ready || _controller.camera.zoom <= _minimumZoom + 0.001
                      ? null
                      : () => _controller.move(
                          _controller.camera.center,
                          math.max(_minimumZoom, _controller.camera.zoom - 1),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labels(BuildContext context, MapCamera camera) {
    if (camera.zoom < _minimumZoom + 1) return const SizedBox.shrink();
    final factor = math.pow(2, camera.zoom).toDouble();
    final size = camera.nonRotatedSize;
    final occupied = <Rect>[
      const Rect.fromLTWH(0, 0, 156, 60),
      Rect.fromLTWH(size.width - 68, 0, 68, 120),
    ];
    final parts = widget.geometry.labelParts.values.toList()
      ..sort((a, b) {
        if (a.cameraCode == widget.selectedCode) return -1;
        if (b.cameraCode == widget.selectedCode) return 1;
        final area = (b.worldBounds.width * b.worldBounds.height).compareTo(
          a.worldBounds.width * a.worldBounds.height,
        );
        return area != 0 ? area : a.daneCode.compareTo(b.daneCode);
      });
    final labels = <Widget>[];
    for (final part in parts) {
      final name = widget.names[part.cameraCode]!;
      final style = DefaultTextStyle.of(context).style.merge(
        TextStyle(
          fontSize: 14,
          fontWeight: part.cameraCode == widget.selectedCode
              ? FontWeight.w700
              : FontWeight.w500,
          color: part.cameraCode == widget.selectedCode
              ? Colors.white
              : AppColors.navy,
        ),
      );
      final scaler = MediaQuery.textScalerOf(context);
      final labelSize = _labelSizes.putIfAbsent((name, style, scaler), () {
        final painter = TextPainter(
          text: TextSpan(text: name, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final size = painter.size;
        painter.dispose();
        return size;
      });
      final point = camera.latLngToScreenOffset(part.anchor);
      final rect = Rect.fromCenter(
        center: point,
        width: labelSize.width,
        height: labelSize.height,
      );
      final radius = math.sqrt(
        math.pow(rect.width / 2 + 4, 2) + math.pow(rect.height / 2 + 4, 2),
      );
      final fits =
          part.labelRadius * factor > radius &&
          rect.left >= 4 &&
          rect.top >= 4 &&
          rect.right <= size.width - 4 &&
          rect.bottom <= size.height - 4 &&
          !occupied.any((other) => other.overlaps(rect.inflate(4)));
      if (!fits) continue;
      occupied.add(rect.inflate(4));
      labels.add(
        Positioned.fromRect(
          rect: rect,
          child: Text(
            name,
            key: ValueKey('fotomultas-map-label-${part.cameraCode}'),
            style: style,
            maxLines: 1,
          ),
        ),
      );
    }
    return IgnorePointer(child: Stack(children: labels));
  }
}

class _CountryMapControl extends StatelessWidget {
  const _CountryMapControl({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.label,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      label: tooltip,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 48,
              width: label == null ? 48 : null,
              child: Center(
                widthFactor: 1,
                child: Container(
                  height: 36,
                  width: label == null ? 36 : null,
                  padding: label == null
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: label == null ? 22 : 18,
                        color: onPressed == null ? Colors.grey : AppColors.teal,
                      ),
                      if (label != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          label!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
