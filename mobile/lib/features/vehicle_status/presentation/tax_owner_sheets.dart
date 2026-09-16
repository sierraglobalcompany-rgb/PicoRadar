part of 'tax_owner_content.dart';

extension _TaxSheets on _TaxOwnerContentState {
  Future<void> _chooseAuthority(TaxCatalog catalog, String? selectedId) async {
    final choice = await showModalBottomSheet<({String id, bool save})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TaxAuthoritySheet(
        catalog: catalog,
        selectedId: selectedId,
        vehicleLabel: widget.vehicle.plate,
      ),
    );
    if (!mounted || choice == null) return;
    _preview(choice.id);
    if (choice.save) {
      final authority = catalog.authorityById(choice.id);
      if (authority != null) await _save(authority);
    }
  }

  Future<void> _chooseYear(
    TaxCatalog catalog,
    TaxAuthority authority,
    int currentYear,
  ) async {
    final years = {
      currentYear,
      ...catalog.calendars
          .where((item) => item.authorityId == authority.id)
          .map((item) => item.year),
    }.toList()..sort((a, b) => b.compareTo(a));
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Calendario', style: _sectionTitle),
            ),
            for (final year in years)
              ListTile(
                title: Text('$year'),
                subtitle: catalog.calendarFor(authority.id, year) == null
                    ? const Text('Pendiente de verificar')
                    : null,
                trailing: year == (_year ?? currentYear)
                    ? const Icon(Icons.check, color: AppColors.teal)
                    : null,
                onTap: () => Navigator.pop(context, year),
              ),
          ],
        ),
      ),
    );
    if (mounted && chosen != null) _changeYear(chosen);
  }

  Future<void> _information(
    TaxAuthority authority,
    TaxCalendar? calendar,
  ) async {
    final urls = {
      ...authority.sourceUrls,
      ...?calendar?.sourceUrls,
      for (final event in calendar?.events ?? <TaxCalendarEvent>[])
        ...event.sourceUrls,
    }.toList();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Información y fuentes', style: _sectionTitle),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(authority.territoryName, style: _sectionTitle),
                  Text(authority.name),
                  const SizedBox(height: 12),
                  const Text(
                    'PicoRadar no calcula el impuesto, no consulta deuda y no confirma si está pagado.',
                  ),
                  const SizedBox(height: 12),
                  if (calendar != null) ...[
                    Text(
                      _conceptLabel(calendar.obligationKind),
                      style: _sectionTitle,
                    ),
                    Text('Año tributario: ${calendar.year}'),
                    Text(
                      calendar.reviewedAt == null
                          ? 'Calendario sin revisión confirmada'
                          : 'Calendario revisado: ${_shortDate(calendar.reviewedAt!)} ${calendar.reviewedAt!.year}',
                    ),
                    if (calendar.reviewAfter != null)
                      Text(
                        'Revisión prevista: ${_shortDate(calendar.reviewAfter!)} ${calendar.reviewAfter!.year}',
                      ),
                    const SizedBox(height: 8),
                    for (final event in calendar.activeEvents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(event.label),
                        subtitle: Text(
                          '${_shortDate(event.date)} ${event.date.year}${event.condition == null ? '' : '\n${event.condition}'}',
                        ),
                      ),
                  ],
                  Text(
                    authority.reviewedAt == null
                        ? 'Portal pendiente de revisión'
                        : 'Entidad revisada: ${_shortDate(authority.reviewedAt!)} ${authority.reviewedAt!.year}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La revisión de los datos no es una fecha de vencimiento legal ni una confirmación de pago. Las condiciones y modificaciones se consultan en la fuente oficial.',
                  ),
                  if (calendar?.events.any(
                        (event) => event.status != 'active',
                      ) ??
                      false) ...[
                    const SizedBox(height: 16),
                    const Text('Historial normativo', style: _sectionTitle),
                    for (final event in calendar!.events.where(
                      (event) => event.status != 'active',
                    ))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${event.label} · ${_shortDate(event.date)} ${event.date.year}',
                        ),
                        subtitle: Text(
                          event.status == 'superseded'
                              ? _replacementDescription(calendar, event)
                              : 'Plazo retirado. Consulta su fuente.',
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Fuentes oficiales', style: _sectionTitle),
                  for (var i = 0; i < urls.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        'Fuente ${i + 1} · ${Uri.parse(urls[i]).host}',
                      ),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => Navigator.pop(context, urls[i]),
                    ),
                  const Divider(),
                  TextButton.icon(
                    key: const ValueKey('tax-refresh'),
                    onPressed: () => Navigator.pop(context, 'refresh'),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Buscar actualizaciones'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'refresh') {
      await _refresh();
    } else {
      await _open(result);
    }
  }
}

String _replacementDescription(TaxCalendar calendar, TaxCalendarEvent event) {
  final replacement = calendar.events
      .where((item) => item.id == event.supersededBy)
      .firstOrNull;
  if (replacement == null) {
    return 'Plazo sustituido. Consulta la fuente oficial.';
  }
  return 'Sustituido por: ${replacement.label}, ${_shortDate(replacement.date)} ${replacement.date.year}. No es un vencimiento adicional.';
}

class _TaxAuthoritySheet extends StatefulWidget {
  const _TaxAuthoritySheet({
    required this.catalog,
    required this.selectedId,
    required this.vehicleLabel,
  });
  final TaxCatalog catalog;
  final String? selectedId;
  final String vehicleLabel;
  @override
  State<_TaxAuthoritySheet> createState() => _TaxAuthoritySheetState();
}

class _TaxAuthoritySheetState extends State<_TaxAuthoritySheet> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = normalizeRegistrationCityText(_search.text);
    final options =
        widget.catalog.authorities
            .where(
              (item) => normalizeRegistrationCityText(
                '${item.territoryName} ${item.name}',
              ).contains(needle),
            )
            .toList()
          ..sort(
            (a, b) =>
                normalizeRegistrationCityText(a.territoryName)
                    .compareTo(normalizeRegistrationCityText(b.territoryName)),
          );
    final selected = widget.catalog.authorityById(widget.selectedId);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                MediaQuery.paddingOf(context).top) *
            .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Buscar entidad tributaria',
                      style: _sectionTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const ValueKey('tax-authority-search'),
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: options.isEmpty
                  ? const Center(child: Text('No encontramos esa entidad.'))
                  : ListView.builder(
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final item = options[index];
                        return ListTile(
                          key: ValueKey('tax-authority-${item.id}'),
                          title: Text(
                            item.territoryName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.name}${item.portalUrl == null ? '\nPortal de pago por verificar' : ''}',
                          ),
                          trailing: item.id == widget.selectedId
                              ? const Icon(Icons.check, color: AppColors.teal)
                              : const Icon(Icons.chevron_right),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            Navigator.pop(context, (id: item.id, save: false));
                          },
                        );
                      },
                    ),
            ),
            if (selected != null && _search.text.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  key: const ValueKey('tax-sheet-save-authority'),
                  onPressed: () =>
                      Navigator.pop(context, (id: selected.id, save: true)),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    'Guardar ${selected.territoryName} para ${widget.vehicleLabel}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
