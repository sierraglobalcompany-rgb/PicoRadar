part of 'fotomultas_screen.dart';

TextStyle _departmentStyle(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w600,
}) => Theme.of(context).textTheme.bodyMedium!.copyWith(
  fontSize: size,
  height: 1.2,
  letterSpacing: 0,
  fontWeight: weight,
);

Size _departmentTextSize(
  BuildContext context,
  String text,
  TextStyle style, [
  double width = double.infinity,
]) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: math.max(1, width));
  final size = painter.size;
  painter.dispose();
  return size;
}

double _departmentTextHeight(
  BuildContext context,
  String text,
  double width,
  double size,
) => _departmentTextSize(
  context,
  text,
  _departmentStyle(context, size),
  width,
).height;

AppBar _departmentAppBar(
  BuildContext context, {
  required String name,
  required _DepartmentView view,
  required VoidCallback onBack,
  required VoidCallback onToggle,
}) {
  final titleStyle = _departmentStyle(
    context,
    20,
    weight: FontWeight.w700,
  ).copyWith(color: Colors.white);
  final nameStyle = _departmentStyle(
    context,
    14,
    weight: FontWeight.w400,
  ).copyWith(color: Colors.white);
  final actionStyle = _departmentStyle(
    context,
    14,
  ).copyWith(color: Colors.white);
  final labelledWidth =
      math.max(
        _departmentTextSize(context, 'Lista', actionStyle).width,
        _departmentTextSize(context, 'Mapa', actionStyle).width,
      ) +
      66;
  final available = MediaQuery.sizeOf(context).width - 56;
  final iconOnly =
      _departmentTextSize(context, 'Fotomultas', titleStyle).width >
      available - labelledWidth;
  final actionWidth = iconOnly ? 60.0 : labelledWidth;
  final titleWidth = available - actionWidth;
  final height = math.max(
    72.0,
    _departmentTextSize(context, 'Fotomultas', titleStyle, titleWidth).height +
        _departmentTextSize(context, name, nameStyle, titleWidth).height +
        20,
  );
  final actionLabel = view == _DepartmentView.map ? 'Lista' : 'Mapa';
  final icon = Icon(
    view == _DepartmentView.map ? Icons.list_rounded : Icons.map_outlined,
    size: 20,
  );
  return AppBar(
    key: const ValueKey('fotomultas-department-header'),
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    toolbarHeight: height,
    leadingWidth: 48,
    titleSpacing: 4,
    leading: IconButton(
      tooltip: 'Volver a Colombia',
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_rounded),
    ),
    title: MediaQuery(
      data: MediaQuery.of(context),
      // AppBar's default title style has a one-line limit; do not inherit it.
      child: DefaultTextStyle(
        style: nameStyle,
        softWrap: true,
        overflow: TextOverflow.visible,
        child: SizedBox(
          width: titleWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fotomultas', style: titleStyle, softWrap: true),
              Text(name, style: nameStyle, softWrap: true),
            ],
          ),
        ),
      ),
    ),
    actions: [
      SizedBox(
        width: actionWidth,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: iconOnly
              ? IconButton.outlined(
                  key: const ValueKey('fotomultas-view-toggle'),
                  tooltip: actionLabel,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: onToggle,
                  icon: icon,
                )
              : OutlinedButton(
                  key: const ValueKey('fotomultas-view-toggle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onToggle,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 6),
                      Text(actionLabel, style: actionStyle),
                    ],
                  ),
                ),
        ),
      ),
    ],
  );
}

class _DepartmentExplorer extends StatelessWidget {
  const _DepartmentExplorer({
    required this.mapKey,
    required this.pack,
    required this.department,
    required this.geometry,
    required this.view,
    required this.filter,
    required this.page,
    required this.query,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onPageChanged,
    required this.onShowDetails,
    required this.onOpenDriving,
    required this.onOpenSource,
    required this.onShowList,
  });
  final CameraPack pack;
  final GlobalKey<_DepartmentMapViewState> mapKey;
  final _DepartmentSummary department;
  final DepartmentGeometry? geometry;
  final _DepartmentView view;
  final _SpeedFilter filter;
  final int page;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_SpeedFilter> onFilterChanged;
  final ValueChanged<int> onPageChanged;
  final void Function(TrafficCamera, CameraPackSource) onShowDetails;
  final VoidCallback onOpenDriving, onOpenSource;
  final VoidCallback onShowList;

  Future<void> _search(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _DepartmentSearchSheet(query: query, name: department.name),
    );
    if (context.mounted && result != null) onQueryChanged(result);
  }

  Future<void> _filters(BuildContext context) async {
    var draft = filter;
    final result = await showModalBottomSheet<_SpeedFilter>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Filtros', style: AppTextStyles.h2),
                for (final option in _SpeedFilter.values)
                  ListTile(
                    minVerticalPadding: 12,
                    leading: Icon(
                      draft == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(_filterName(option)),
                    selected: draft == option,
                    onTap: () => setSheetState(() => draft = option),
                  ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      key: const ValueKey('fotomultas-apply-filter'),
                      onPressed: () => Navigator.pop(context, draft),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (context.mounted && result != null) onFilterChanged(result);
  }

  void _source(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            key: const ValueKey('fotomultas-department-source-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Información y fuentes', style: AppTextStyles.h2),
              const SizedBox(height: 12),
              Text(
                'Inventario ANSV · ${_inventoryDate(pack.source.fetchedAtUtc)}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Cobertura parcial del inventario. La fecha corresponde '
                'al paquete, no a la verificación individual de cada cámara. '
                'Información de referencia; no consulta comparendos.',
              ),
              const SizedBox(height: 12),
              const Text('Cartografía: © OpenStreetMap contributors'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('fotomultas-department-source-link'),
                onPressed: () {
                  Navigator.pop(context);
                  onOpenSource();
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir fuente ANSV'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _filterName(_SpeedFilter value) => switch (value) {
    _SpeedFilter.all => 'Todas',
    _SpeedFilter.known => 'Con velocidad reportada',
    _SpeedFilter.unknown => 'Sin velocidad reportada',
  };

  Widget _top(BuildContext context, int count, bool compact, double rowHeight) {
    final label = query.isEmpty ? 'Buscar en ${department.name}' : query;
    final countLabel = '$count de ${department.count}';
    final filterLabel = switch (filter) {
      _SpeedFilter.all => 'Todas',
      _SpeedFilter.known => 'Con dato',
      _SpeedFilter.unknown => 'Sin dato',
    };
    final search = _ExplorerAction(
      key: const ValueKey('fotomultas-open-camera-search'),
      label: label,
      icon: Icons.search,
      iconOnly: compact,
      onTap: () => _search(context),
    );
    final filters = _ExplorerAction(
      key: const ValueKey('fotomultas-speed-filter'),
      label: 'Filtros · $filterLabel',
      semantics: 'Filtros. ${_filterName(filter)}',
      icon: Icons.filter_alt_outlined,
      iconOnly: compact,
      onTap: () => _filters(context),
      trailing: !compact,
    );
    final counter = Tooltip(
      message: '$countLabel cámaras del inventario departamental',
      child: Semantics(
        label: '$countLabel cámaras del inventario departamental',
        child: Container(
          key: const ValueKey('fotomultas-result-count'),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera, size: 20, color: AppColors.teal),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  countLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (compact) {
      return SizedBox(
        height: rowHeight,
        child: Row(
          children: [
            search,
            const SizedBox(width: 8),
            Expanded(child: counter),
            const SizedBox(width: 8),
            filters,
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: rowHeight, width: double.infinity, child: search),
        const SizedBox(height: 8),
        SizedBox(
          height: rowHeight,
          child: Row(
            children: [
              Expanded(flex: 4, child: counter),
              const SizedBox(width: 12),
              Expanded(flex: 6, child: filters),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, bool compact) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        fit: compact ? FlexFit.loose : FlexFit.tight,
        child: _ExplorerAction(
          key: const ValueKey('fotomultas-department-open-source'),
          label:
              'Fuente · ${_inventoryDate(pack.source.fetchedAtUtc, compact: true)}',
          icon: Icons.open_in_new,
          iconOnly: compact,
          onTap: () => _source(context),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        fit: compact ? FlexFit.loose : FlexFit.tight,
        child: _ExplorerAction(
          key: const ValueKey('fotomultas-open-driving'),
          label: 'Abrir Conducir',
          icon: Icons.drive_eta_outlined,
          iconOnly: compact,
          accent: true,
          onTap: onOpenDriving,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final filtered = _filterCameras(department.cameras, query, filter);
    return LayoutBuilder(
      key: const ValueKey('fotomultas-department-screen'),
      builder: (context, constraints) {
        final rowHeight = math.max(
          48.0,
          _departmentTextHeight(
                context,
                'Filtros · Con dato',
                (constraints.maxWidth - 44) * .6 - 60,
                14,
              ) +
              16,
        );
        final footerHeight = math.max(
          48.0,
          _departmentTextHeight(
                context,
                'Fuente · 31/08/26',
                (constraints.maxWidth - 40) / 2 - 44,
                14,
              ) +
              16,
        );
        final attributionHeight =
            _departmentTextHeight(
              context,
              '© OpenStreetMap contributors',
              constraints.maxWidth - 24,
              11,
            ) +
            8;
        final footerBottom = attributionHeight + 16;
        final normalTop = rowHeight * 2 + 8;
        final countFits =
            _departmentTextSize(
              context,
              '${department.count} de ${department.count}',
              _departmentStyle(context, 14, weight: FontWeight.w700),
            ).width <=
            (constraints.maxWidth - 44) * .4 - 46;
        final compact =
            !countFits ||
            constraints.maxHeight -
                    (normalTop + 24) -
                    (footerHeight + footerBottom + 8) <
                220;
        final topHeight = compact
            ? math.max(
                48.0,
                MediaQuery.textScalerOf(context).scale(14) * 1.2 + 16,
              )
            : normalTop;
        final bottomHeight = compact ? 48.0 : footerHeight;
        final insets = EdgeInsets.fromLTRB(
          16,
          topHeight + 24,
          72,
          bottomHeight + footerBottom + 8,
        );
        final top = _top(
          context,
          filtered.length,
          compact,
          compact ? topHeight : rowHeight,
        );
        final footer = SizedBox(
          height: bottomHeight,
          child: _footer(context, compact),
        );
        return IndexedStack(
          index: view == _DepartmentView.map ? 0 : 1,
          children: [
            Stack(
              fit: StackFit.expand,
              children: [
                _DepartmentMapView(
                  key: mapKey,
                  cameras: filtered,
                  geometry: geometry,
                  departmentCode: department.code,
                  overlayPadding: insets,
                  onShowList: onShowList,
                  onShowDetails: (camera) => onShowDetails(camera, pack.source),
                ),
                Positioned(
                  left: 16,
                  right: 72,
                  top: insets.top,
                  bottom: insets.bottom,
                  child: IgnorePointer(
                    child: SizedBox(
                      key: const ValueKey('fotomultas-map-clear-area'),
                    ),
                  ),
                ),
                Positioned(left: 16, right: 16, top: 12, child: top),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: footerBottom,
                  child: footer,
                ),
              ],
            ),
            Column(
              children: [
                Padding(padding: const EdgeInsets.all(12), child: top),
                Expanded(
                  child: filtered.isEmpty
                      ? const _EmptyPane()
                      : _DepartmentCameraList(
                          cameras: filtered,
                          source: pack.source,
                          page: page,
                          onPageChanged: onPageChanged,
                          onShowDetails: onShowDetails,
                        ),
                ),
                Padding(padding: const EdgeInsets.all(12), child: footer),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DepartmentSearchSheet extends StatefulWidget {
  const _DepartmentSearchSheet({required this.query, required this.name});
  final String query, name;
  @override
  State<_DepartmentSearchSheet> createState() => _DepartmentSearchSheetState();
}

class _DepartmentSearchSheetState extends State<_DepartmentSearchSheet> {
  late final _draft = TextEditingController(text: widget.query);
  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Buscar en ${widget.name}', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('fotomultas-search-field'),
            controller: _draft,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
            decoration: const InputDecoration(
              labelText: 'Dirección, municipio o autoridad',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(onPressed: _draft.clear, child: const Text('Limpiar')),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const ValueKey('fotomultas-apply-search'),
                onPressed: () => Navigator.pop(context, _draft.text.trim()),
                child: const Text('Buscar'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ExplorerAction extends StatelessWidget {
  const _ExplorerAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconOnly = false,
    this.accent = false,
    this.trailing = false,
    this.semantics,
  });
  final String label;
  final String? semantics;
  final IconData icon;
  final VoidCallback onTap;
  final bool iconOnly, accent, trailing;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semantics ?? label,
    button: true,
    onTap: onTap,
    child: Tooltip(
      message: semantics ?? label,
      excludeFromSemantics: true,
      child: ExcludeSemantics(
        child: Material(
          color: accent ? AppColors.teal : Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: iconOnly
                  ? SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          icon,
                          size: 20,
                          color: accent ? Colors.white : AppColors.teal,
                        ),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: iconOnly ? 12 : 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: accent ? Colors.white : AppColors.teal,
                          ),
                          if (!iconOnly) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: icon == Icons.search ? 1 : null,
                                overflow: icon == Icons.search
                                    ? TextOverflow.ellipsis
                                    : null,
                                style: _departmentStyle(context, 14).copyWith(
                                  color: accent ? Colors.white : AppColors.navy,
                                ),
                              ),
                            ),
                            if (trailing)
                              const Icon(Icons.expand_more, size: 16),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
