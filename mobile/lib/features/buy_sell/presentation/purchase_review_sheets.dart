part of 'buy_sell_screen.dart';

const _purchaseRuntUrl =
    'https://www.runt.gov.co/consultaCiudadana/#/consultaVehiculo';
const _purchaseDirectoryUrl = 'https://www.runt.gov.co/directorio-de-actores';
const _reviewBody = TextStyle(fontSize: 14, height: 1.4);

class _PurchaseReviewSheet extends ConsumerStatefulWidget {
  const _PurchaseReviewSheet({
    required this.step,
    required this.candidate,
    required this.consultation,
    required this.reviewed,
    required this.onReviewedChanged,
    required this.onContextChanged,
    required this.onDocuments,
    required this.onPeritaje,
    required this.onChooseAppraisalCity,
    required this.onContract,
    required this.onNotes,
    required this.onCopy,
  });
  final _PurchaseStep step;
  final BuySellCandidateVehicle candidate;
  final PurchaseConsultationContext consultation;
  final bool reviewed;
  final ValueChanged<bool> onReviewedChanged;
  final Future<void> Function(PurchaseConsultationContext) onContextChanged;
  final Future<void> Function(WalletDocumentType?) onDocuments;
  final Future<void> Function() onPeritaje,
      onChooseAppraisalCity,
      onContract,
      onNotes,
      onCopy;
  @override
  ConsumerState<_PurchaseReviewSheet> createState() =>
      _PurchaseReviewSheetState();
}

class _PurchaseReviewSheetState extends ConsumerState<_PurchaseReviewSheet> {
  late bool _reviewed = widget.reviewed;
  late PurchaseConsultationContext _selection = widget.consultation;
  BuySellCandidateVehicle? _garageContext;
  bool _busy = false;
  String? _error;
  BuySellCandidateVehicle get _candidate => _garageContext ?? widget.candidate;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos completar la acción. Tus datos anteriores se conservan. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String url) async {
    if (!await ref.read(externalLauncherProvider).openExternal(url)) {
      throw StateError('External portal unavailable');
    }
  }

  Future<void> _select(PurchaseConsultationContext next) async {
    await widget.onContextChanged(next);
    if (mounted) setState(() => _selection = next);
  }

  Widget _action(
    String label,
    IconData icon,
    Future<void> Function() action, {
    String? keyName,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: OutlinedButton.icon(
      key: keyName == null ? null : ValueKey(keyName),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: _reviewBody.copyWith(fontWeight: FontWeight.w600),
        alignment: Alignment.centerLeft,
      ),
      onPressed: _busy ? null : () => _run(action),
      icon: Icon(icon, size: 22),
      label: Text(label),
    ),
  );

  Widget _instructions(List<(String, String)> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${i + 1}.',
                  style: _reviewBody.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].$1,
                      style: _reviewBody.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(items[i].$2, style: _reviewBody),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final id = widget.step.id;
    return FractionallySizedBox(
      heightFactor: .9,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Text(
                    '${widget.step.number}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.step.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar revisión',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey('purchase-review-scroll-$id'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.step.body, style: _reviewBody),
                    const SizedBox(height: 12),
                    Text(
                      _candidate.isEmpty
                          ? 'Puedes consultar sin agregar un vehículo'
                          : '${_garageContext == null ? 'Vehículo candidato' : 'Consulta temporal del Garaje'}: ${_candidateSummary(_candidate)}',
                      style: _reviewBody.copyWith(
                        color: _purchaseInk,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_candidate.plate.trim().isNotEmpty)
                      _action(
                        'Copiar placa',
                        Icons.copy,
                        () => Clipboard.setData(
                          ClipboardData(text: _candidate.plate.trim()),
                        ),
                      ),
                    ..._content(id),
                    if ({
                      BuySellPreparationStepIds.comparendos,
                      BuySellPreparationStepIds.taxes,
                      BuySellPreparationStepIds.transfer,
                    }.contains(id)) ...[
                      _action(
                        'Usar un vehículo del Garaje',
                        Icons.directions_car_outlined,
                        _chooseGarage,
                      ),
                      if (_garageContext != null)
                        _action(
                          'Volver al vehículo candidato',
                          Icons.undo,
                          () async {
                            setState(() => _garageContext = null);
                          },
                        ),
                    ],
                    if (_busy && ModalRoute.of(context)?.isCurrent == true)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: _reviewBody.copyWith(color: AppColors.red),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'Revisado significa que tú hiciste las comprobaciones. No certifica deudas, autenticidad ni estado del vehículo.',
                      style: _reviewBody,
                    ),
                    SwitchListTile(
                      key: ValueKey('buy-sell-purchase-reviewed-$id'),
                      contentPadding: EdgeInsets.zero,
                      value: _reviewed,
                      title: const Text(
                        'Marcar como revisado',
                        style: _reviewBody,
                      ),
                      onChanged: (value) {
                        setState(() => _reviewed = value);
                        widget.onReviewedChanged(value);
                      },
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(String id) => switch (id) {
    BuySellPreparationStepIds.comparendos => [
      _action(
        'Consultar en SIMIT',
        Icons.open_in_new,
        () => _open(simitConsultationUrl),
        keyName: 'purchase-open-simit',
      ),
      _instructions(const [
        (
          'Consulta a las personas y al vehículo',
          'En SIMIT puedes buscar por documento del comprador o vendedor, o por placa. Los datos se escriben en el portal oficial, no aquí.',
        ),
        (
          'Revisa el resultado con el vendedor',
          'Comprueba comparendos, multas y acuerdos de pago. Si necesitas aclaraciones, contacta a la autoridad que aparece en el resultado.',
        ),
        (
          'Conserva el soporte',
          'Anota qué consultaste y cuándo. Abrir SIMIT no confirma un paz y salvo.',
        ),
      ]),
      _action(
        'Buscar autoridad de tránsito',
        Icons.search,
        () => _chooseTerritorial(false),
      ),
      _territorialDetails(false),
    ],
    BuySellPreparationStepIds.taxes => [
      _action('Buscar entidad tributaria', Icons.search, _chooseTax),
      _taxDetails(),
      _instructions(const [
        (
          'Identifica la entidad tributaria',
          'Mira dónde está matriculado el vehículo. El impuesto departamental o distrital es distinto de otros derechos locales; Bogotá no es Cundinamarca.',
        ),
        (
          'Consulta las obligaciones',
          'Usa el portal de la entidad y revisa los años que correspondan. La app no calcula la deuda ni determina exenciones.',
        ),
        (
          'Pide los comprobantes',
          'Contrasta los soportes del vendedor con la entidad. Una fecha de calendario no demuestra que el impuesto esté pagado.',
        ),
      ]),
    ],
    BuySellPreparationStepIds.transfer => [
      _instructions(const [
        (
          'Identifica el organismo de matrícula',
          'Lee la licencia de tránsito o consulta RUNT. No depende de dónde estás ahora, ni puede deducirse solo del número de placa.',
        ),
        (
          'Confirma requisitos y soportes',
          'Consulta inscripción e identificación en RUNT, documento de transferencia, verificaciones y formularios exigidos por ese organismo. Los casos especiales tienen requisitos propios.',
        ),
        (
          'Prepara la radicación',
          'Verifica el canal de cita, documentos originales y costos vigentes antes de acudir. El acuerdo de compraventa no sustituye el traspaso.',
        ),
      ]),
      _action(
        'Consultar vehículo en RUNT',
        Icons.open_in_new,
        () => _open(_purchaseRuntUrl),
      ),
      _action(
        'Buscar organismo de tránsito',
        Icons.search,
        () => _chooseTerritorial(true),
      ),
      _territorialDetails(true),
      _action(
        'Directorio oficial RUNT',
        Icons.open_in_new,
        () => _open(_purchaseDirectoryUrl),
      ),
    ],
    BuySellPreparationStepIds.appraisal => [
      _instructions(const [
        (
          'Elige una revisión independiente',
          'Pregunta por la identificación del vehículo, estructura, mecánica y diagnóstico aplicable. Confirma alcance, precio y quién realiza la revisión.',
        ),
        (
          'Solicita un informe escrito',
          'Revisa hallazgos y limitaciones con el profesional. Un resultado en Google Maps no acredita al establecimiento ni garantiza su trabajo.',
        ),
        (
          'Guarda y contrasta el informe',
          'Pide explicación de los hallazgos antes de decidir. Puedes guardar una copia en esta preparación.',
        ),
      ]),
      _action(
        'Buscar peritaje cerca de mí',
        Icons.my_location,
        widget.onPeritaje,
        keyName: 'buy-sell-purchase-open-appraisal',
      ),
      _action(
        'Elegir ciudad',
        Icons.location_city_outlined,
        widget.onChooseAppraisalCity,
      ),
      _action(
        'Informe de peritaje',
        Icons.file_present_outlined,
        () => widget.onDocuments(WalletDocumentType.appraisal),
      ),
    ],
    BuySellPreparationStepIds.documents => [
      _instructions(const [
        (
          'Compara la identificación',
          'Contrasta matrícula, placa y datos del vehículo con los documentos del vendedor. No publiques copias de identificación.',
        ),
        (
          'Consulta los registros',
          'Revisa SOAT y tecnomecánica cuando corresponda en RUNT. El portal puede solicitar placa y datos del propietario.',
        ),
        (
          'Organiza las copias',
          'Guarda matrícula, peritaje, compraventa y soportes de este candidato. Tener una copia no demuestra autenticidad, vigencia ni aceptación oficial.',
        ),
      ]),
      _action(
        'Documentos de esta preparación',
        Icons.folder_open,
        () => widget.onDocuments(null),
        keyName: 'buy-sell-purchase-open-documents',
      ),
      _action(
        'Consultar vehículo en RUNT',
        Icons.open_in_new,
        () => _open(_purchaseRuntUrl),
      ),
    ],
    _ => [
      _instructions(const [
        (
          'Deja el acuerdo por escrito',
          'Confirma precio, forma de pago, condiciones, obligaciones de cada parte y qué sucede si el trámite no puede completarse. Busca asesoría para tu caso.',
        ),
        (
          'Verifica antes de transferir dinero',
          'Comprueba la identidad del destinatario y los datos de la cuenta con la persona correspondiente. No confundas un comprobante enviado con dinero efectivamente recibido.',
        ),
        (
          'Detalla la entrega',
          'Relaciona fecha, kilometraje, estado, llaves, accesorios, documentos y observaciones en una constancia aceptada por las partes.',
        ),
        (
          'Conserva los soportes del trámite',
          'Comprueba la radicación y el resultado del traspaso por el canal oficial. Esta guía no ejecuta pagos ni transfiere la propiedad.',
        ),
      ]),
      _action(
        'Preparar texto de compraventa',
        Icons.description_outlined,
        widget.onContract,
      ),
      _action('Notas de pago y entrega', Icons.notes, widget.onNotes),
      _action('Copiar resumen de preparación', Icons.copy, widget.onCopy),
    ],
  };

  Future<void> _chooseGarage() async {
    final vehicle = await showModalBottomSheet<VehicleProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PurchaseGaragePicker(),
    );
    if (!mounted || vehicle == null) return;
    final city = vehicle.registrationCity ?? '';
    final catalog = ref.read(registrationCityCatalogProvider).asData?.value;
    setState(
      () => _garageContext = BuySellCandidateVehicle(
        plate: vehicle.plate,
        brandLine: [vehicle.brand, vehicle.model].whereType<String>().join(' '),
        modelYear: vehicle.year?.toString() ?? '',
        registrationCity: city,
        registrationCityConfirmed: catalog?.containsDisplayName(city) ?? false,
      ),
    );
  }

  Future<void> _chooseTax() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PurchaseAuthorityPicker(
        taxes: true,
        selectedId: _selection.taxAuthorityId,
      ),
    );
    if (id != null && mounted) {
      await _select(_selection.copyWith(taxAuthorityId: id));
    }
  }

  Future<void> _chooseTerritorial(bool transfer) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PurchaseAuthorityPicker(
        taxes: false,
        transfer: transfer,
        selectedId: transfer
            ? _selection.transitAuthorityId
            : _selection.comparendosAuthorityId,
      ),
    );
    if (id == null || !mounted) return;
    await _select(
      transfer
          ? _selection.copyWith(transitAuthorityId: id)
          : _selection.copyWith(comparendosAuthorityId: id),
    );
  }

  Widget _taxDetails() {
    final value = ref.watch(taxCatalogProvider);
    final cities = ref.watch(registrationCityCatalogProvider).asData?.value;
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) =>
          _action('Reintentar catálogo tributario', Icons.refresh, () async {
            ref.invalidate(taxCatalogProvider);
          }),
      data: (catalog) {
        final suggestion = _candidate.registrationCityConfirmed
            ? suggestTaxAuthority(catalog, cities, _candidate.registrationCity)
            : null;
        final authority = catalog.authorityById(
          _selection.taxAuthorityId.isNotEmpty
              ? _selection.taxAuthorityId
              : suggestion,
        );
        if (authority == null) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Selecciona la entidad que quieres consultar. No necesitas ingresar una placa.',
              style: _reviewBody,
            ),
          );
        }
        final suggested = _selection.taxAuthorityId.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              '${suggested ? 'Sugerida por matrícula' : 'Entidad seleccionada'}: ${authority.name}',
              style: _reviewBody.copyWith(fontWeight: FontWeight.w600),
            ),
            if (suggested)
              _action(
                'Usar esta entidad',
                Icons.check,
                () =>
                    _select(_selection.copyWith(taxAuthorityId: authority.id)),
              ),
            if (authority.portalUrl != null)
              _action(
                'Consultar o pagar en el portal oficial',
                Icons.open_in_new,
                () => _open(authority.portalUrl!),
              ),
            if (authority.portalUrl == null)
              const Text(
                'Enlace directo de consulta pendiente de confirmar.',
                style: _reviewBody,
              ),
            if (authority.institutionalUrl != null)
              _action(
                'Web institucional',
                Icons.language,
                () => _open(authority.institutionalUrl!),
              ),
            _action(
              'Fuente y revisión',
              Icons.info_outline,
              () => _showSources(
                authority.sourceUrls,
                authority.reviewedAt?.toIso8601String(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _territorialDetails(bool transfer) {
    final selected = transfer
        ? _selection.transitAuthorityId
        : _selection.comparendosAuthorityId;
    if (selected.isEmpty) return const SizedBox.shrink();
    return ref
        .watch(territorialCatalogProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) =>
              _action('Reintentar directorio', Icons.refresh, () async {
                ref.invalidate(territorialCatalogProvider);
              }),
          data: (catalog) {
            final authority = catalog.authorities
                .where((a) => a.id == selected)
                .firstOrNull;
            if (authority == null) {
              return const Text(
                'La entidad guardada no está disponible. Busca otra entidad.',
                style: _reviewBody,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  authority.name,
                  style: _reviewBody.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    authority.officeMunicipality,
                    authority.department,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: _reviewBody,
                ),
                if (transfer && !authority.supportsRegistrationProcedures)
                  const Text(
                    'Competencia para matrícula y traspaso pendiente de confirmar. Verifica el organismo en tu licencia o en RUNT.',
                    style: _reviewBody,
                  ),
                if (transfer && authority.transferUrl != null)
                  _action(
                    'Requisitos de traspaso',
                    Icons.checklist,
                    () => _open(authority.transferUrl!),
                  ),
                if (transfer && authority.appointmentUrl != null)
                  _action(
                    'Citas y radicación',
                    Icons.calendar_month,
                    () => _open(authority.appointmentUrl!),
                  ),
                if (transfer && authority.formsUrl != null)
                  _action(
                    'Formularios oficiales',
                    Icons.download_outlined,
                    () => _open(authority.formsUrl!),
                  ),
                if (transfer && authority.phone != null)
                  _action(
                    'Llamar: ${authority.phone}',
                    Icons.phone_outlined,
                    () => _open(
                      'tel:${authority.phone!.replaceAll(RegExp(r'[^+0-9]'), '')}',
                    ),
                  ),
                if (transfer && authority.address != null)
                  Text(authority.address!, style: _reviewBody),
                if (!transfer && authority.consultationUrl != null)
                  _action(
                    'Consulta territorial',
                    Icons.open_in_new,
                    () => _open(authority.consultationUrl!),
                  ),
                if (authority.institutionalUrl != null)
                  _action(
                    'Web institucional',
                    Icons.language,
                    () => _open(authority.institutionalUrl!),
                  ),
                if (authority.institutionalUrl == null)
                  _action(
                    'Consultar directorio oficial RUNT',
                    Icons.open_in_new,
                    () => _open(_purchaseDirectoryUrl),
                  ),
                if (authority.procedureEvidenceUrl != null ||
                    authority.evidenceUrl != null)
                  _action(
                    'Fuente y revisión',
                    Icons.info_outline,
                    () => _showSources(
                      [
                        if (transfer && authority.procedureEvidenceUrl != null)
                          authority.procedureEvidenceUrl!
                        else if (authority.evidenceUrl != null)
                          authority.evidenceUrl!,
                      ],
                      transfer
                          ? authority.procedureReviewedAt
                          : authority.verifiedAt,
                    ),
                  ),
              ],
            );
          },
        );
  }

  Future<void> _showSources(
    List<String> urls,
    String? date,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Fuente y revisión',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          Text(
            'Revisión: ${date == null ? 'pendiente' : date.split('T').first}',
            style: _reviewBody,
          ),
          const Text(
            'Confirma los requisitos vigentes con la entidad. El directorio no acredita habilitación actual ni el estado del vehículo.',
            style: _reviewBody,
          ),
          for (final url in urls)
            ListTile(
              title: Text(Uri.parse(url).host),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                try {
                  await _open(url);
                } catch (_) {
                  if (sheet.mounted) {
                    ScaffoldMessenger.of(sheet).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo abrir la fuente.'),
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
    ),
  );
}

class _PurchaseAuthorityPicker extends ConsumerStatefulWidget {
  const _PurchaseAuthorityPicker({
    required this.taxes,
    this.transfer = false,
    required this.selectedId,
  });
  final bool taxes, transfer;
  final String selectedId;
  @override
  ConsumerState<_PurchaseAuthorityPicker> createState() =>
      _PurchaseAuthorityPickerState();
}

class _PurchaseAuthorityPickerState
    extends ConsumerState<_PurchaseAuthorityPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<({String id, String name, String detail})>> rows =
        widget.taxes
        ? ref
              .watch(taxCatalogProvider)
              .whenData(
                (c) => c.authorities
                    .map(
                      (a) => (id: a.id, name: a.name, detail: a.territoryName),
                    )
                    .toList(),
              )
        : ref
              .watch(territorialCatalogProvider)
              .whenData(
                (c) => c.authorities
                    .map(
                      (a) => (
                        id: a.id,
                        name: a.name,
                        detail:
                            '${a.officeMunicipality} · ${a.department}${widget.transfer && !a.supportsRegistrationProcedures ? ' · Traspaso por confirmar' : ''}',
                      ),
                    )
                    .toList(),
              );
    final confirmedTransfers = ref
        .watch(territorialCatalogProvider)
        .asData
        ?.value
        .authorities
        .where((a) => a.supportsRegistrationProcedures)
        .length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .85,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.taxes
                              ? 'Entidad tributaria'
                              : 'Autoridades de tránsito',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar búsqueda',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  TextField(
                    key: const ValueKey('purchase-authority-search'),
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      labelText: 'Buscar entidad',
                      hintText: 'Nombre, municipio o departamento',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!widget.taxes)
                    Text(
                      widget.transfer && confirmedTransfers != null
                          ? '$confirmedTransfers organismos con traspaso confirmado. Las demás fichas indican su cobertura pendiente.'
                          : 'Inventario nacional. Los canales pendientes se identifican en cada ficha.',
                      style: _reviewBody,
                    ),
                ],
              ),
            ),
            rows.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => SliverToBoxAdapter(
                child: Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    onPressed: () {
                      if (widget.taxes) {
                        ref.invalidate(taxCatalogProvider);
                      } else {
                        ref.invalidate(territorialCatalogProvider);
                      }
                    },
                  ),
                ),
              ),
              data: (values) {
                final terms = normalizeTerritorialText(_query)
                    .split(' ')
                    .where((s) => s.isNotEmpty);
                final matches =
                    values
                        .where(
                          (a) => terms.every(
                            normalizeTerritorialText('${a.name} ${a.detail}')
                                .contains,
                          ),
                        )
                        .toList()
                      ..sort(
                        (a, b) =>
                            normalizeTerritorialText(a.name)
                                .compareTo(normalizeTerritorialText(b.name)),
                      );
                if (matches.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Sin coincidencias. Prueba con otro nombre o territorio.',
                      ),
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final row = matches[index];
                    return ListTile(
                      title: Text(row.name, style: _reviewBody),
                      subtitle: Text(row.detail, style: _reviewBody),
                      trailing: row.id == widget.selectedId
                          ? const Icon(Icons.check)
                          : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, row.id),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseGaragePicker extends ConsumerWidget {
  const _PurchaseGaragePicker();
  @override
  Widget build(BuildContext context, WidgetRef ref) => FractionallySizedBox(
    heightFactor: .6,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Elegir vehículo para esta consulta',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const Text(
            'No cambia el candidato, sus documentos ni tu favorito.',
            style: _reviewBody,
          ),
          Expanded(
            child: ref
                .watch(vehicleListProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(vehicleListProvider),
                      child: const Text('Reintentar Garaje'),
                    ),
                  ),
                  data: (vehicles) => vehicles.isEmpty
                      ? const Center(
                          child: Text(
                            'No tienes vehículos guardados. Puedes continuar sin elegir uno.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: vehicles.length,
                          itemBuilder: (_, i) => ListTile(
                            title: Text(vehicles[i].plate),
                            subtitle: Text(
                              vehicles[i].nickname ??
                                  vehicles[i].brand ??
                                  'Mi vehículo',
                            ),
                            onTap: () => Navigator.pop(context, vehicles[i]),
                          ),
                        ),
                ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar sin elegir'),
          ),
        ],
      ),
    ),
  );
}
