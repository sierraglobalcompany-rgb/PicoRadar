part of 'fotomultas_screen.dart';

String _inventoryDate(String raw, {bool compact = false}) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return 'Fecha no disponible';
  final date = parsed.toUtc().subtract(const Duration(hours: 5));
  if (compact) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${(date.year % 100).toString().padLeft(2, '0')}';
  }
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sept',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

AppBar _nationalAppBar(BuildContext context, CameraPack? pack) {
  final base = Theme.of(context).textTheme.bodyMedium!;
  final titleStyle = base.merge(AppTextStyles.h2);
  final countStyle = base.merge(
    const TextStyle(
      fontSize: 14,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: AppColors.navy,
    ),
  );
  final dateStyle = base.merge(
    const TextStyle(fontSize: 12, height: 1.25, color: AppColors.navy),
  );
  final count = pack == null ? '' : '${pack.cameras.length} cámaras';
  final date = pack == null
      ? ''
      : 'ANSV · ${_inventoryDate(pack.source.fetchedAtUtc, compact: true)}';
  final scaler = MediaQuery.textScalerOf(context);
  Size measure(
    String value,
    TextStyle style, [
    double width = double.infinity,
  ]) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textScaler: scaler,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: width);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  final available = math.max(
    1.0,
    MediaQuery.sizeOf(context).width - 48 - 4 - 16,
  );
  final inventoryWidth = math.min(
    available,
    math.max(
          measure(count, countStyle).width + 22,
          measure(date, dateStyle).width,
        ) +
        12,
  );
  final stacked =
      pack != null &&
      measure('Fotomultas', titleStyle).width + 12 + inventoryWidth > available;
  final titleHeight = measure('Fotomultas', titleStyle, available).height;
  final inventoryHeight =
      math.max(
        16.0,
        measure(count, countStyle, math.max(1, inventoryWidth - 34)).height,
      ) +
      2 +
      measure(date, dateStyle, math.max(1, inventoryWidth - 12)).height +
      12;
  final height = pack == null
      ? math.max(56.0, titleHeight + 16)
      : math.max(
          56.0,
          stacked
              ? titleHeight + 8 + inventoryHeight + 16
              : inventoryHeight + 8,
        );
  final title = Text(
    'Fotomultas',
    key: const ValueKey('fotomultas-header-title'),
    style: titleStyle,
  );
  final inventory = pack == null
      ? const SizedBox.shrink()
      : Semantics(
          label:
              '$count. Fuente ANSV. Fecha del inventario: ${_inventoryDate(pack.source.fetchedAtUtc)}',
          child: ExcludeSemantics(
            child: Container(
              key: const ValueKey('fotomultas-header-inventory'),
              width: inventoryWidth,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        size: 16,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(count, style: countStyle)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    key: const ValueKey('fotomultas-source-date'),
                    style: dateStyle,
                  ),
                ],
              ),
            ),
          ),
        );
  return AppBar(
    key: const ValueKey('fotomultas-national-header'),
    leadingWidth: 48,
    titleSpacing: 4,
    toolbarHeight: height,
    centerTitle: false,
    title: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: pack == null
          ? title
          : stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: inventory),
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                inventory,
              ],
            ),
    ),
  );
}

class _NationalDepartmentView extends StatefulWidget {
  const _NationalDepartmentView({
    required this.pack,
    required this.departments,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
    required this.onOpenDriving,
    required this.onSelect,
    required this.geometry,
    required this.onRetryGeometry,
    required this.onOpenSource,
  });
  final CameraPack pack;
  final List<_DepartmentSummary> departments;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOpenDriving, onRetryGeometry, onOpenSource;
  final ValueChanged<String> onSelect;
  final AsyncValue<DepartmentGeometry> geometry;
  @override
  State<_NationalDepartmentView> createState() =>
      _NationalDepartmentViewState();
}

class _NationalDepartmentViewState extends State<_NationalDepartmentView> {
  final _mapKey = GlobalKey<_NationalMapState>();
  String? _highlighted;
  _DepartmentSummary? get selected =>
      widget.departments.where((d) => d.code == _highlighted).firstOrNull;

  void _select(String code, {bool fit = false}) {
    setState(() => _highlighted = code);
    if (fit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _highlighted == code) {
          _mapKey.currentState?.fitDepartment(code);
        }
      });
    }
  }

  Future<void> _search({List<String>? candidates}) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) {
          final all = _filterDepartments(
            widget.departments,
            candidates == null ? widget.controller.text : '',
          );
          final items = candidates == null
              ? all
              : all.where((d) => candidates.contains(d.code)).take(5).toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      candidates == null
                          ? 'Departamentos y Bogotá'
                          : 'Departamentos cercanos',
                      style: AppTextStyles.h2,
                    ),
                    if (candidates == null)
                      TextField(
                        key: const ValueKey(
                          'fotomultas-department-search-field',
                        ),
                        controller: widget.controller,
                        autofocus: false,
                        decoration: const InputDecoration(
                          labelText: 'Buscar departamento o Bogotá',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          widget.onQueryChanged(value);
                          update(() {});
                        },
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(
                              child: Text('No encontramos departamentos.'),
                            )
                          : ListView.separated(
                              key: const ValueKey('fotomultas-department-list'),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) => _DepartmentTile(
                                department: items[index],
                                onTap: () =>
                                    Navigator.pop(context, items[index].code),
                              ),
                            ),
                    ),
                    if (candidates != null && candidates.length > 5)
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'search'),
                        child: const Text('Todos los departamentos'),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || code == null) return;
    if (code == 'search') {
      await _search();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _select(code, fit: candidates == null);
  }

  void _tapMap(List<String> codes) {
    if (codes.length == 1) {
      _select(codes.single);
    } else if (codes.isNotEmpty) {
      _search(candidates: codes);
    }
  }

  void _information() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            key: const ValueKey('fotomultas-information-sheet'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Información y fuentes', style: AppTextStyles.h2),
                const SizedBox(height: 12),
                const Text(
                  'Este módulo no consulta comparendos ni confirma una sanción. La velocidad reportada no reemplaza la señalización de la vía.',
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.pack.cameras.length} cámaras del inventario. Cobertura parcial: sin registros no significa que no existan cámaras.',
                ),
                Text(
                  '${widget.pack.cameras.where((c) => c.speedLimitKmh != null).length} con velocidad reportada',
                ),
                const SizedBox(height: 12),
                Text(widget.pack.source.name),
                Text(
                  'Fecha del inventario: ${_inventoryDate(widget.pack.source.fetchedAtUtc)}',
                ),
                OutlinedButton.icon(
                  key: const ValueKey('fotomultas-country-source'),
                  onPressed: widget.onOpenSource,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir fuente ANSV'),
                ),
                const Divider(),
                const Text(
                  'Cartografía: Departamento Administrativo Nacional de Estadística - DANE: www.dane.gov.co. Marco departamental 2025. Geometría simplificada para visualización; no delimita una sanción.',
                ),
                const Text(
                  'Atribución CC BY 4.0. La vista de Colombia y el inventario son locales; el mapa de calles departamental requiere teselas disponibles.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _selectionNameStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const _selectionCountStyle = TextStyle(fontSize: 14, height: 1.3);
  static const _selectionActionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  Size _measureSelectionText(String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  double get _selectionActionWidth =>
      _measureSelectionText(
        'Ver cámaras',
        _selectionActionStyle,
        double.infinity,
      ).width +
      24;

  String _selectionCount(_DepartmentSummary department) => department.count == 0
      ? 'Sin registros en este inventario'
      : '${department.count} cámaras';

  double _selectionHeight(double width) {
    final department = selected;
    if (department == null) return 0;
    final textWidth = math.max(1.0, width - 24 - 12 - _selectionActionWidth);
    final textHeight =
        _measureSelectionText(
          department.name,
          _selectionNameStyle,
          textWidth,
        ).height +
        4 +
        _measureSelectionText(
          _selectionCount(department),
          _selectionCountStyle,
          textWidth,
        ).height;
    return math.max(72, textHeight + 24);
  }

  Widget _selectionContent({bool sheet = false}) {
    final department = selected;
    if (department == null) return const SizedBox.shrink();
    final identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(department.name, style: _selectionNameStyle),
        const SizedBox(height: 4),
        Text(_selectionCount(department), style: _selectionCountStyle),
      ],
    );
    final action = FilledButton(
      key: const ValueKey('fotomultas-view-cameras'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: DefaultTextStyle.of(context).style
            .merge(_selectionActionStyle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {
        if (sheet) Navigator.of(context, rootNavigator: true).pop();
        widget.onSelect(department.code);
      },
      child: const Text('Ver cámaras'),
    );
    if (!sheet) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              SizedBox(width: _selectionActionWidth, child: action),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [identity, const SizedBox(height: 12), action],
      ),
    );
  }

  void _selectionSheet() {
    if (selected == null) {
      _search();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(child: _selectionContent(sheet: true)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final compact = scale > 1.3 || constraints.maxHeight < 520;
        return Column(
          key: const ValueKey('fotomultas-country-screen'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Material(
                color: const Color(0xffeaf1f4),
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  key: const ValueKey('fotomultas-open-department-search'),
                  borderRadius: BorderRadius.circular(28),
                  onTap: _search,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.navy),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Buscar departamento o Bogotá',
                            style: TextStyle(
                              fontSize: compact ? 14 : 16,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, available) {
                  final department = selected;
                  final useSheet =
                      department != null &&
                      available.maxHeight -
                              _selectionHeight(available.maxWidth - 32) -
                              4 <
                          220;
                  final selectionLabel =
                      department != null &&
                          useSheet &&
                          available.maxHeight -
                                  math.max(
                                    48,
                                    _measureSelectionText(
                                          department.name,
                                          _selectionCountStyle,
                                          math.max(1, available.maxWidth - 80),
                                        ).height +
                                        16,
                                  ) <
                              220
                      ? 'Ver departamento'
                      : department?.name;
                  return Column(
                    children: [
                      Expanded(
                        child: widget.geometry.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              key: ValueKey('fotomultas-geometry-loading'),
                            ),
                          ),
                          error: (_, _) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No pudimos cargar el mapa.',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: widget.onRetryGeometry,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                          data: (geometry) => _NationalMap(
                            key: _mapKey,
                            geometry: geometry,
                            selectedCode: _highlighted,
                            names: {
                              for (final d in widget.departments)
                                d.code: d.name,
                            },
                            onCandidates: _tapMap,
                            onReset: () => setState(() => _highlighted = null),
                          ),
                        ),
                      ),
                      if (department != null && useSheet)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Tooltip(
                            message: department.name,
                            child: TextButton(
                              key: const ValueKey(
                                'fotomultas-compact-selection',
                              ),
                              onPressed: _selectionSheet,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectionLabel!,
                                      style: _selectionCountStyle,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (department != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Container(
                            key: const ValueKey(
                              'fotomultas-selected-department',
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _selectionContent(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (compact)
                    IconButton(
                      tooltip: 'Información y fuentes',
                      onPressed: _information,
                      icon: const Icon(Icons.info_outline),
                    )
                  else
                    Expanded(
                      child: TextButton(
                        onPressed: _information,
                        child: const Text(
                          'Información y fuentes',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('fotomultas-open-driving'),
                      onPressed: widget.onOpenDriving,
                      icon: const Icon(Icons.drive_eta_outlined, size: 20),
                      label: const Text(
                        'Abrir Conducir',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
