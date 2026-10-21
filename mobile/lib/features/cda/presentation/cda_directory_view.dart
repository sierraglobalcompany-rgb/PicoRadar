import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/cda_catalog.dart';

/// Local directory content; the parent owns the header and detail navigation.
class CdaDirectoryView extends StatefulWidget {
  const CdaDirectoryView({
    super.key,
    required this.catalog,
    required this.onOpen,
    this.initialQuery = '',
    this.verifiedVehicleTypes = const {},
  });

  final CdaCatalog catalog;
  final ValueChanged<CdaCatalogEntry> onOpen;
  final String initialQuery;
  final Map<String, Set<String>> verifiedVehicleTypes;

  @override
  State<CdaDirectoryView> createState() => _CdaDirectoryViewState();
}

typedef _City = ({String department, String name});
typedef _Filters = ({
  String? department,
  _City? city,
  _VehicleType type,
  bool descending,
});

enum _VehicleType {
  all('Todos'),
  car('Carros'),
  motorcycle('Motos'),
  both('Ambos');

  const _VehicleType(this.label);
  final String label;

  bool accepts(Set<String> evidence) => switch (this) {
    all => true,
    car => evidence.contains('car'),
    motorcycle => evidence.contains('motorcycle'),
    both => evidence.contains('car') && evidence.contains('motorcycle'),
  };
}

const _defaultFilters = (
  department: null,
  city: null,
  type: _VehicleType.all,
  descending: false,
);
const _labelStyle = TextStyle(fontSize: 14, color: AppColors.navy);
const _titleStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: AppColors.navy,
);

class _CdaDirectoryViewState extends State<CdaDirectoryView> {
  late final _search = TextEditingController(text: widget.initialQuery);
  final _scroll = ScrollController();
  _Filters _filters = _defaultFilters;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _queryChanged(String _) {
    _resetScroll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_search.text);
    final active =
        query.replaceAll(' ', '').length >= 2 ||
        _filters.department != null ||
        _filters.city != null;
    final terms = query.split(' ').where((term) => term.isNotEmpty).toList();
    final results = active
        ? widget.catalog.entries.where((entry) {
            if (_filters.department != null &&
                entry.department != _filters.department) {
              return false;
            }
            if (_filters.city case final city?) {
              if (entry.department != city.department ||
                  entry.municipality != city.name) {
                return false;
              }
            }
            if (!_filters.type.accepts(
              widget.verifiedVehicleTypes[entry.id] ?? const {},
            )) {
              return false;
            }
            final text = _normalize(
              '${entry.name} ${entry.municipality} ${entry.department}',
            );
            return terms.every(text.contains);
          }).toList()
        : <CdaCatalogEntry>[];
    results.sort((a, b) {
      final nameOrder = _compareText(a.name, b.name);
      if (nameOrder != 0) return _filters.descending ? -nameOrder : nameOrder;
      final departmentOrder = _compareText(a.department, b.department);
      if (departmentOrder != 0) return departmentOrder;
      final cityOrder = _compareText(a.municipality, b.municipality);
      if (cityOrder != 0) return cityOrder;
      return a.id.compareTo(b.id);
    });

    return Material(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const ValueKey('cda-directory-search'),
              controller: _search,
              style: const TextStyle(fontSize: 16, color: AppColors.navy),
              textInputAction: TextInputAction.search,
              onChanged: _queryChanged,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Buscar CDA',
                hintStyle: const TextStyle(fontSize: 16, color: AppColors.navy),
                prefixIcon: const Icon(Icons.search, color: AppColors.teal),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: 'Borrar búsqueda',
                        onPressed: () {
                          _search.clear();
                          _queryChanged('');
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    active ? '${results.length} CDA' : 'Directorio CDA',
                    style: _labelStyle,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('cda-directory-filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    minimumSize: const Size(48, 48),
                    textStyle: _labelStyle,
                  ),
                  onPressed: _editFilters,
                  icon: Icon(
                    _filters == _defaultFilters ? Icons.tune : Icons.filter_alt,
                  ),
                  label: const Text('Filtros'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: !active || results.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        active ? 'No encontramos CDA' : 'Busca un CDA',
                        key: ValueKey(
                          active
                              ? 'cda-directory-empty'
                              : 'cda-directory-initial',
                        ),
                        style: _titleStyle,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.builder(
                    key: const ValueKey('cda-directory-results'),
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: results.length,
                    itemBuilder: (context, index) => _resultRow(results[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(CdaCatalogEntry entry) {
    final types = widget.verifiedVehicleTypes[entry.id] ?? const <String>{};
    final compatibility = types.contains('car') && types.contains('motorcycle')
        ? 'Carros y motos'
        : types.contains('car')
        ? 'Carros'
        : types.contains('motorcycle')
        ? 'Motos'
        : 'Compatibilidad por verificar';
    return InkWell(
      key: ValueKey('cda-directory-entry-${entry.id}'),
      onTap: () {
        FocusScope.of(context).unfocus();
        widget.onOpen(entry);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: _titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.municipality} · ${entry.department}',
                    style: _labelStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    compatibility,
                    style: _labelStyle.copyWith(color: AppColors.teal),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.teal),
          ],
        ),
      ),
    );
  }

  Future<void> _editFilters() async {
    FocusScope.of(context).unfocus();
    var draft = _filters;
    final departments =
        widget.catalog.entries.map((entry) => entry.department).toSet().toList()
          ..sort(_compareText);
    final applied = await _showSheet<_Filters>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, update) => _DirectorySheet(
          title: 'Filtros',
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterField(
                key: const ValueKey('cda-filter-department'),
                label: 'Departamento',
                value: draft.department ?? 'Todos los departamentos',
                onTap: () async {
                  final selected = await _pick<String>(
                    context,
                    title: 'Departamento',
                    allLabel: 'Todos los departamentos',
                    options: {for (final value in departments) value: value},
                    selected: draft.department,
                  );
                  if (!context.mounted || selected == null) return;
                  update(
                    () => draft = (
                      department: selected.value,
                      city: selected.value == draft.department
                          ? draft.city
                          : null,
                      type: draft.type,
                      descending: draft.descending,
                    ),
                  );
                },
              ),
              _FilterField(
                key: const ValueKey('cda-filter-city'),
                label: 'Ciudad',
                value: draft.city?.name ?? 'Todas las ciudades',
                onTap: () async {
                  final cities =
                      widget.catalog.entries
                          .where(
                            (entry) =>
                                draft.department == null ||
                                entry.department == draft.department,
                          )
                          .map(
                            (entry) => (
                              department: entry.department,
                              name: entry.municipality,
                            ),
                          )
                          .toSet()
                          .toList()
                        ..sort((a, b) {
                          final order = _compareText(a.name, b.name);
                          return order != 0
                              ? order
                              : _compareText(a.department, b.department);
                        });
                  final selected = await _pick<_City>(
                    context,
                    title: 'Ciudad',
                    allLabel: 'Todas las ciudades',
                    options: {
                      for (final city in cities)
                        city: '${city.name} · ${city.department}',
                    },
                    selected: draft.city,
                  );
                  if (!context.mounted || selected == null) return;
                  update(
                    () => draft = (
                      department:
                          selected.value?.department ?? draft.department,
                      city: selected.value,
                      type: draft.type,
                      descending: draft.descending,
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Tipo de vehículo', style: _titleStyle),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in _VehicleType.values)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 48,
                      ),
                      child: ChoiceChip(
                        label: Text(type.label, style: _labelStyle),
                        selected: draft.type == type,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        selectedColor: AppColors.teal.withValues(alpha: 0.12),
                        onSelected: (_) => update(
                          () => draft = (
                            department: draft.department,
                            city: draft.city,
                            type: type,
                            descending: draft.descending,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              _FilterField(
                key: const ValueKey('cda-filter-order'),
                label: 'Orden',
                value: draft.descending ? 'Nombre Z-A' : 'Nombre A-Z',
                onTap: () async {
                  final selected = await _pick<bool>(
                    context,
                    title: 'Orden',
                    options: const {false: 'Nombre A-Z', true: 'Nombre Z-A'},
                    selected: draft.descending,
                  );
                  if (!context.mounted ||
                      selected == null ||
                      selected.value == null) {
                    return;
                  }
                  update(
                    () => draft = (
                      department: draft.department,
                      city: draft.city,
                      type: draft.type,
                      descending: selected.value!,
                    ),
                  );
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  textStyle: _labelStyle,
                ),
                onPressed: () => update(() => draft = _defaultFilters),
                child: const Text('Restablecer'),
              ),
            ],
          ),
          footer: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const ValueKey('cda-filters-apply'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                minimumSize: const Size(double.infinity, 48),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () => Navigator.of(sheetContext).pop(draft),
              child: const Text('Aplicar'),
            ),
          ),
        ),
      ),
    );
    if (!mounted || applied == null || applied == _filters) return;
    _resetScroll();
    setState(() => _filters = applied);
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _titleStyle),
                  Text(value, style: _labelStyle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, color: AppColors.teal),
          ],
        ),
      ),
    ),
  );
}

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: builder(context),
        ),
      ),
    );

class _DirectorySheet extends StatelessWidget {
  const _DirectorySheet({required this.title, required this.body, this.footer});
  final String title;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              Expanded(child: Text(title, style: _titleStyle)),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: title == 'Filtros'
                    ? 'Cerrar filtros'
                    : 'Cerrar selector',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(child: body),
        ?footer,
      ],
    ),
  );
}

// A null route result cancels; a wrapped null explicitly clears the territory.
Future<({T? value})?> _pick<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  T? selected,
  String? allLabel,
}) async {
  var query = '';
  return _showSheet<({T? value})>(
    context,
    (sheetContext) => StatefulBuilder(
      builder: (context, update) {
        final terms = _normalize(query)
            .split(' ')
            .where((term) => term.isNotEmpty);
        final visible = options.entries
            .where((entry) => terms.every(_normalize(entry.value).contains))
            .toList();
        Widget option(T? value, String label) => ListTile(
          minTileHeight: 48,
          title: Text(label, style: _labelStyle),
          selected: value == selected,
          trailing: value == selected
              ? const Icon(Icons.check, color: AppColors.teal)
              : null,
          onTap: () => Navigator.of(sheetContext).pop((value: value)),
        );
        return _DirectorySheet(
          title: title,
          body: Column(
            children: [
              if (allLabel != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    key: const ValueKey('cda-picker-search'),
                    style: const TextStyle(fontSize: 16),
                    onChanged: (value) => update(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Buscar',
                      hintStyle: _labelStyle,
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: visible.length + (allLabel == null ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (allLabel != null && index == 0) {
                      return option(null, allLabel);
                    }
                    final entry = visible[index - (allLabel == null ? 0 : 1)];
                    return option(entry.key, entry.value);
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

int _compareText(String a, String b) => _normalize(a).compareTo(_normalize(b));

String _normalize(String value) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  var normalized = value.toLowerCase();
  for (final accent in accents.entries) {
    normalized = normalized.replaceAll(accent.key, accent.value);
  }
  return normalized
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll('.', '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
