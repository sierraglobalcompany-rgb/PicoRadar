import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../documents/application/wallet_providers.dart';
import '../../documents/data/wallet_models.dart';
import '../../documents/presentation/documents_async_content.dart';
import '../../documents/presentation/documents_recovery_notice.dart';
import '../../documents/presentation/documents_sheets.dart';
import '../../documents/presentation/wallet_actions.dart';
import '../../garage/data/vehicle_profile.dart';
import '../data/insurance_directory.dart';
import '../domain/insurance_policy_value.dart';
import '../domain/vehicle_obligation.dart';
import '../platform/external_launcher.dart';

Future<void> showInsuranceEditor(
  BuildContext context,
  WidgetRef ref,
  VehicleProfile vehicle,
  VehicleObligation? obligation,
) => _showSheet(
  context,
  _InsuranceEditor(vehicle: vehicle, original: obligation),
);

Future<void> showInsuranceDirectory(
  BuildContext context,
  WidgetRef ref, {
  ValueChanged<InsuranceCompany>? onSelected,
  ValueChanged<String>? onManualName,
  String? selectedProviderId,
  String? selectedProviderName,
  bool protectedSession = false,
}) async {
  final session = ref.read(walletSessionProvider);
  final epoch = session.epoch;
  if (protectedSession && !session.isAuthorizedEpoch(epoch)) return;
  final selected = await showModalBottomSheet<_InsuranceSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) {
      final sheet = _InsuranceDirectorySheet(
        selecting: onSelected != null,
        allowManual: onManualName != null,
        selectedProviderId: selectedProviderId,
        selectedProviderName: selectedProviderName,
        protectedSession: protectedSession,
      );
      return protectedSession ? DocumentsSessionSheet(child: sheet) : sheet;
    },
  );
  if (!context.mounted ||
      selected == null ||
      (protectedSession && !session.isAuthorizedEpoch(epoch))) {
    return;
  }
  if (selected.company case final company?) onSelected?.call(company);
  if (selected.manualName case final name?) onManualName?.call(name);
}

class _InsuranceSelection {
  const _InsuranceSelection({this.company, this.manualName});
  final InsuranceCompany? company;
  final String? manualName;
}

Future<void> showInsuranceAssistance(
  BuildContext context,
  WidgetRef ref,
  VehicleProfile? vehicle,
  VehicleObligation? obligation,
) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        body: SafeArea(
          child: _InsuranceAssistance(vehicle: vehicle, original: obligation),
        ),
      ),
    ),
  );
}

Future<void> showInsuranceDocuments(
  BuildContext context,
  WidgetRef ref,
  VehicleProfile vehicle,
) async {
  final session = ref.read(walletSessionProvider);
  final security = ref.read(walletScreenSecurityProvider);
  final owner = Object();
  final originRoute = ModalRoute.of(context);
  final router = GoRouter.maybeOf(context);
  final originUri = router?.routeInformationProvider.value.uri;
  bool stillAtOrigin() =>
      context.mounted &&
      (originRoute?.isCurrent ?? true) &&
      router?.routeInformationProvider.value.uri == originUri;
  try {
    if (!await session.initialize()) {
      if (context.mounted && stillAtOrigin()) {
        _notice(context, 'No se pudo desbloquear Documentos.');
      }
      return;
    }
    if (!stillAtOrigin()) return;
    if (!await session.unlock()) {
      if (context.mounted && stillAtOrigin()) {
        _notice(context, 'No se pudo desbloquear Documentos.');
      }
      return;
    }
    if (!stillAtOrigin()) return;
    // Acquire before building any private metadata; fail closed on platform errors.
    await security.acquire(owner);
    if (!context.mounted || !stillAtOrigin() || !session.accessAllowed) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          body: SafeArea(
            child: DocumentsSessionSheet(
              child: _InsuranceDocuments(vehicle: vehicle),
            ),
          ),
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      _notice(
        context,
        'No se pudo abrir la billetera protegida. Intenta de nuevo.',
      );
    }
  } finally {
    session.lock();
    try {
      await WidgetsBinding.instance.endOfFrame;
      await security.release(owner);
    } catch (_) {
      if (context.mounted) {
        _notice(
          context,
          'La pantalla conserva su protecci\u00f3n de privacidad.',
        );
      }
    }
  }
}

Future<void> openInsuranceChannel(
  BuildContext context,
  WidgetRef ref,
  InsuranceChannel channel,
) async {
  if (!channel.verified) {
    _notice(context, 'Canal por verificar. Consulta la web oficial.');
    return;
  }
  final launcher = ref.read(externalLauncherProvider);
  final kind = channel.kind;
  if (kind == 'phone') {
    await _openPhone(context, launcher, channel.value);
  } else if (kind == 'whatsapp') {
    final raw = channel.value.trim();
    if (!RegExp(r'^573\d{9}$').hasMatch(raw)) {
      _notice(
        context,
        'El enlace de WhatsApp no es utilizable. Consulta la web oficial.',
      );
      return;
    }
    final url = 'https://wa.me/$raw';
    await _launch(context, () => launcher.openExternal(url), url);
  }
}

Future<void> _openPhone(
  BuildContext context,
  ExternalLauncher launcher,
  String value,
) async {
  final normalized = value.replaceAll(RegExp(r'[\s()-]'), '');
  if (!RegExp(r'^\+?[0-9*#]{3,18}$').hasMatch(normalized)) {
    _notice(context, 'Revisa el n\u00famero de tel\u00e9fono.');
    return;
  }
  await _launch(
    context,
    () => launcher.callPhone(normalized),
    value,
    failureMessage: 'No pudimos iniciar la llamada.',
  );
}

Future<void> _website(BuildContext context, WidgetRef ref, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    _notice(context, 'Enlace oficial por verificar.');
    return;
  }
  final launcher = ref.read(externalLauncherProvider);
  await _launch(context, () => launcher.openExternal(uri.toString()), value);
}

Future<void> _launch(
  BuildContext context,
  Future<bool> Function() operation,
  String copy, {
  String failureMessage = 'No pudimos abrir este canal',
}) async {
  var opened = false;
  try {
    opened = await operation();
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  final retry = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(failureMessage),
      content: const Text(
        'Puedes copiarlo o intentar de nuevo. No se envi\u00f3 ning\u00fan mensaje.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Cerrar'),
        ),
        TextButton(
          onPressed: () => _copy(dialog, copy),
          child: const Text('Copiar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
  if (retry == true && context.mounted) {
    await _launch(context, operation, copy, failureMessage: failureMessage);
  }
}

Future<void> _copy(BuildContext context, String value) async {
  try {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) _notice(context, 'Copiado.');
  } catch (_) {
    if (context.mounted) {
      _notice(context, 'No se pudo copiar. Intenta de nuevo.');
    }
  }
}

void _notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

Future<void> _showSheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => child,
    );

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .88,
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _InsuranceDirectorySheet extends ConsumerStatefulWidget {
  const _InsuranceDirectorySheet({
    required this.selecting,
    this.allowManual = false,
    this.selectedProviderId,
    this.selectedProviderName,
    this.protectedSession = false,
  });
  final bool selecting;
  final bool allowManual;
  final String? selectedProviderId;
  final String? selectedProviderName;
  final bool protectedSession;
  @override
  ConsumerState<_InsuranceDirectorySheet> createState() =>
      _InsuranceDirectorySheetState();
}

class _InsuranceDirectorySheetState
    extends ConsumerState<_InsuranceDirectorySheet> {
  var _query = '';
  String? _category;

  Future<void> _manual() async {
    final session = ref.read(walletSessionProvider);
    final epoch = session.epoch;
    if (widget.protectedSession && !session.isAuthorizedEpoch(epoch)) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => widget.protectedSession
          ? const DocumentsSessionSheet(child: _ManualInsurerDialog())
          : const _ManualInsurerDialog(),
    );
    if (!mounted ||
        name == null ||
        (widget.protectedSession && !session.isAuthorizedEpoch(epoch))) {
      return;
    }
    Navigator.pop(context, _InsuranceSelection(manualName: name));
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(insuranceDirectoryProvider);
    return _SheetBody(
      title: 'Directorio de aseguradoras',
      children: [
        const Text('Buscar aseguradora'),
        Semantics(
          label: 'Buscar aseguradora',
          child: TextField(
            key: const ValueKey('insurance-directory-search'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final item in const <String?, String>{
              null: 'Todas',
              'car': 'Carros',
              'motorcycle': 'Motos',
            }.entries)
              ChoiceChip(
                label: Text(item.value),
                selected: _category == item.key,
                onSelected: (_) => setState(() => _category = item.key),
              ),
          ],
        ),
        directory.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            children: [
              const Text('No se pudo cargar el directorio.'),
              TextButton(
                onPressed: () => ref.invalidate(insuranceDirectoryProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
          data: (catalog) {
            final entries = catalog.search(_query, category: _category);
            final selectedId = catalog
                .resolve(widget.selectedProviderId, widget.selectedProviderName)
                ?.id;
            return Column(
              children: [
                if (entries.isEmpty)
                  const Text(
                    'Sin coincidencias. Puedes registrar otra aseguradora manualmente.',
                  ),
                for (final company in entries)
                  ListTile(
                    title: Text(company.name),
                    subtitle: Text(company.legalName),
                    leading: const Icon(Icons.shield_outlined),
                    selected: selectedId == company.id,
                    trailing: Icon(
                      selectedId == company.id
                          ? Icons.check_circle
                          : Icons.chevron_right,
                    ),
                    onTap: () async {
                      if (widget.selecting) {
                        if (widget.protectedSession &&
                            !ref.read(walletSessionProvider).accessAllowed) {
                          return;
                        }
                        Navigator.pop(
                          context,
                          _InsuranceSelection(company: company),
                        );
                        return;
                      }
                      await _showSheet(
                        context,
                        _CompanyDetails(company: company),
                      );
                    },
                  ),
              ],
            );
          },
        ),
        if (widget.allowManual)
          TextButton.icon(
            key: const ValueKey('insurance-directory-manual'),
            onPressed: _manual,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('No encuentro mi aseguradora'),
          ),
      ],
    );
  }
}

class _ManualInsurerDialog extends StatefulWidget {
  const _ManualInsurerDialog();
  @override
  State<_ManualInsurerDialog> createState() => _ManualInsurerDialogState();
}

class _ManualInsurerDialogState extends State<_ManualInsurerDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Otra aseguradora'),
    scrollable: true,
    content: Form(
      key: _form,
      child: TextFormField(
        key: const ValueKey('insurance-editor-providerName'),
        controller: _name,
        decoration: const InputDecoration(
          labelText: 'Nombre de la aseguradora',
        ),
        maxLength: 120,
        validator: (value) {
          final name = value?.trim() ?? '';
          if (name.length < 2 ||
              name.length > 120 ||
              !RegExp(r'[a-zA-Z\u00c0-\u024f]').hasMatch(name) ||
              RegExp(r'[\x00-\x1f<>]|https?://').hasMatch(name)) {
            return 'Escribe un nombre v\u00e1lido de aseguradora.';
          }
          return null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        key: const ValueKey('insurance-manual-accept'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _name.text.trim());
          }
        },
        child: const Text('Aceptar'),
      ),
    ],
  );
}

class _CompanyDetails extends ConsumerWidget {
  const _CompanyDetails({required this.company});
  final InsuranceCompany company;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _SheetBody(
    title: company.name,
    children: [
      Text(company.legalName),
      Text('Revisi\u00f3n del directorio: ${company.reviewedAt}'),
      const Text(
        'El directorio no implica patrocinio ni garantiza cobertura de tu p\u00f3liza.',
      ),
      for (final channel in company.channels)
        _channelTile(context, ref, channel),
      TextButton.icon(
        onPressed: () => _website(context, ref, company.website),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Web oficial'),
      ),
      TextButton.icon(
        onPressed: () => _website(context, ref, company.sourceUrl),
        icon: const Icon(Icons.source_outlined),
        label: const Text('Fuente del directorio'),
      ),
    ],
  );
}

Widget _channelTile(
  BuildContext context,
  WidgetRef ref,
  InsuranceChannel channel,
) => ListTile(
  leading: Icon(
    channel.kind == 'phone' ? Icons.phone_outlined : Icons.chat_outlined,
  ),
  title: Text(channel.label),
  subtitle: Text(
    channel.verified
        ? '${channel.value}\n${channel.purpose == 'assistance' ? 'Asistencia' : 'Atenci\u00f3n al cliente'} \u00b7 Revisado ${channel.reviewedAt}${channel.services.isEmpty ? '' : '\nSolicitudes: ${channel.services.map(_serviceLabel).join(', ')}'}${channel.conditions == null ? '' : '\n${channel.conditions}'}'
        : 'Canal por verificar',
  ),
  onTap: channel.verified
      ? () => openInsuranceChannel(context, ref, channel)
      : null,
  trailing: IconButton(
    tooltip: 'Ver fuente del canal',
    icon: const Icon(Icons.info_outline),
    onPressed: () => _website(context, ref, channel.sourceUrl),
  ),
);

String _serviceLabel(InsuranceService service) => switch (service) {
  InsuranceService.generalAssistance => 'Asistencia general',
  InsuranceService.towing => 'Gr\u00faa',
  InsuranceService.designatedDriver => 'Conductor elegido',
  InsuranceService.roadsideRepair => 'Carro taller',
};

class _InsuranceEditor extends ConsumerStatefulWidget {
  const _InsuranceEditor({
    required this.vehicle,
    required this.original,
    this.protectedSession = false,
  });
  final VehicleProfile vehicle;
  final VehicleObligation? original;
  final bool protectedSession;
  @override
  ConsumerState<_InsuranceEditor> createState() => _InsuranceEditorState();
}

class _InsuranceEditorState extends ConsumerState<_InsuranceEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late bool _reminder;
  String? _providerId;
  var _busy = false;
  String? _error;
  final _premium = TextEditingController();
  InsurancePolicyValue? _valueSource;
  var _valuePeriod = InsuranceValuePeriod.annual;
  var _valueEdited = false;
  var _phonesExpanded = false;
  static const _phones = [
    'assistancePhone',
    'towPhone',
    'designatedDriverPhone',
  ];

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    _providerId = original?.details['providerId'];
    _reminder = original?.reminderEnabled ?? true;
    _valueSource = InsurancePolicyValue.fromDetails(
      original?.details ?? const {},
    );
    _valuePeriod = _valueSource?.period ?? InsuranceValuePeriod.annual;
    _premium.text = _valueSource?.inputFor(_valuePeriod) ?? '';
    _fields = {
      for (final id in ['providerName', 'policyNumber', ..._phones])
        id: TextEditingController(text: original?.details[id]),
      'start': TextEditingController(text: _date(original?.startDate)),
      'due': TextEditingController(text: _date(original?.dueDate)),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _premium.dispose();
    super.dispose();
  }

  bool get _authorized =>
      !widget.protectedSession || ref.read(walletSessionProvider).accessAllowed;

  Future<void> _selectInsurer() => showInsuranceDirectory(
    context,
    ref,
    protectedSession: widget.protectedSession,
    selectedProviderId: _providerId,
    selectedProviderName: _fields['providerName']!.text,
    onSelected: (company) {
      if (!mounted || !_authorized) return;
      setState(() {
        _providerId = company.id;
        _fields['providerName']!.text = company.name;
      });
    },
    onManualName: (name) {
      if (!mounted || !_authorized) return;
      setState(() {
        _providerId = null;
        _fields['providerName']!.text = name;
      });
    },
  );

  Future<void> _selectDate(String id, BuildContext calendarContext) async {
    if (!_authorized || _busy) return;
    final session = ref.read(walletSessionProvider);
    final epoch = session.epoch;
    final today = ref.read(bogotaDateProvider);
    final saved = _parseDate(_fields[id]!.text);
    final initial = saved ?? today;
    final cleared = DateTime(0);
    final date = await showDatePicker(
      context: calendarContext,
      initialDate: initial,
      currentDate: today,
      firstDate: DateTime(initial.year < 1900 ? initial.year : 1900),
      lastDate: DateTime(initial.year > 2200 ? initial.year : 2200, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      calendarDelegate: const _InsuranceCalendarDelegate(),
      helpText: id == 'start' ? 'Inicio de vigencia' : 'Vencimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (dialog, child) {
        final content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: child!),
            if (saved != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.tonalIcon(
                  key: const ValueKey('insurance-calendar-clear'),
                  onPressed: () => Navigator.pop(dialog, cleared),
                  icon: const Icon(Icons.clear),
                  label: const Text('Quitar fecha'),
                ),
              ),
          ],
        );
        return Localizations.override(
          context: dialog,
          locale: const Locale('es', 'CO'),
          delegates: GlobalMaterialLocalizations.delegates,
          child: Theme(
            data: Theme.of(dialog).copyWith(
              datePickerTheme: Theme.of(dialog).datePickerTheme.copyWith(
                dayStyle: const TextStyle(fontSize: 14, letterSpacing: 0),
                weekdayStyle: const TextStyle(fontSize: 14, letterSpacing: 0),
                toggleButtonTextStyle: const TextStyle(
                  fontSize: 14,
                  letterSpacing: 0,
                ),
                headerHeadlineStyle: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 0,
                ),
              ),
            ),
            child: widget.protectedSession
                ? DocumentsSessionSheet(child: content)
                : content,
          ),
        );
      },
    );
    if (!mounted ||
        date == null ||
        (widget.protectedSession && !session.isAuthorizedEpoch(epoch))) {
      return;
    }
    setState(() => _fields[id]!.text = date == cleared ? '' : _date(date));
  }

  void _viewPeriod(InsuranceValuePeriod period) {
    if (!_authorized || period == _valuePeriod) return;
    // Invalid user text must remain visible until corrected or explicitly cleared.
    if (_premium.text.trim().isNotEmpty && _valueSource == null) return;
    setState(() {
      _valuePeriod = period;
      _premium.text = _valueSource?.inputFor(period) ?? '';
    });
  }

  Future<void> _save() async {
    if (_busy || !_authorized) return;
    if (_phones.any((id) => _phoneError(id, _fields[id]!.text) != null)) {
      setState(() {
        _phonesExpanded = true;
        _error = 'Revisa el tel\u00e9fono.';
      });
      return;
    }
    if (!_form.currentState!.validate()) return;
    final start = _parseDate(_fields['start']!.text);
    final due = _parseDate(_fields['due']!.text);
    if (start != null && due != null && due.isBefore(start)) {
      setState(
        () => _error = 'El vencimiento no puede ser anterior al inicio.',
      );
      return;
    }
    final values = {
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
    };
    final providerId = _providerId;
    final reminder = _reminder;
    final valueEdited = _valueEdited;
    final valueSource = _valueSource;
    final session = ref.read(walletSessionProvider);
    final epoch = session.epoch;
    final catalog = ref.read(insuranceDirectoryProvider).asData?.value;
    if (widget.protectedSession && !session.isAuthorizedEpoch(epoch)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final changed =
          values['providerName'] !=
          (widget.original?.details['providerName'] ?? '');
      if (changed &&
          _phones.any(
            (key) => (widget.original?.details[key] ?? '').trim().isNotEmpty,
          )) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialog) {
            final content = AlertDialog(
              title: const Text('Cambiar aseguradora'),
              content: const Text(
                'Se conservar\u00e1n los contactos particulares salvo los que hayas borrado expresamente. Revisa que correspondan a la nueva aseguradora.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Revisar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
            return widget.protectedSession
                ? DocumentsSessionSheet(child: content)
                : content;
          },
        );
        if (confirm != true || !mounted) return;
      }
      if (!mounted) return;
      if (widget.protectedSession && !session.isAuthorizedEpoch(epoch)) return;
      final store = ref.read(vehicleObligationStoreProvider);
      final repository = ref.read(vehicleRepositoryProvider);
      final container = ProviderScope.containerOf(context, listen: false);
      await store.database.transaction(() async {
        if (await repository.getVehicle(widget.vehicle.id) == null) {
          throw const _InsuranceEditFailure(
            'Este veh\u00edculo ya no est\u00e1 disponible.',
          );
        }
        final current = await store.get(
          widget.vehicle.id,
          VehicleObligationType.insurance,
        );
        if (current?.updatedAt != widget.original?.updatedAt ||
            current?.startDate != widget.original?.startDate ||
            current?.dueDate != widget.original?.dueDate ||
            current?.reminderEnabled != widget.original?.reminderEnabled ||
            !mapEquals(current?.details, widget.original?.details)) {
          throw const _InsuranceEditFailure(
            'La p\u00f3liza cambi\u00f3 mientras editabas. Cierra y vuelve a abrir para revisar los datos actuales.',
          );
        }
        final details = {...?current?.details};
        if (valueEdited) {
          for (final key in InsurancePolicyValue.detailKeys) {
            details.remove(key);
          }
          if (valueSource != null) details.addAll(valueSource.toDetails());
        }
        for (final id in ['providerName', 'policyNumber', ..._phones]) {
          details[id] = values[id]!;
        }
        final resolved = catalog?.resolve(providerId, details['providerName']);
        if (resolved != null) {
          details['providerId'] = resolved.id;
        } else if (providerId != null && providerId.isNotEmpty) {
          details['providerId'] = providerId;
        } else {
          details.remove('providerId');
        }
        if (widget.protectedSession && !session.isAuthorizedEpoch(epoch)) {
          throw const _InsuranceEditFailure(
            'La sesi\u00f3n se bloque\u00f3. No se guardaron cambios.',
          );
        }
        await store.upsert(
          vehicleId: widget.vehicle.id,
          type: VehicleObligationType.insurance,
          startDate: start,
          dueDate: due,
          details: details,
          reminderEnabled: reminder,
        );
        if (widget.protectedSession && !session.isAuthorizedEpoch(epoch)) {
          throw const _InsuranceEditFailure(
            'La sesi\u00f3n se bloque\u00f3. No se guardaron cambios.',
          );
        }
      });
      container.invalidate(
        vehicleObligationProvider((
          widget.vehicle.id,
          VehicleObligationType.insurance,
        )),
      );
      container.invalidate(vehicleObligationsProvider(widget.vehicle.id));
      container.invalidate(obligationNotificationSyncProvider);
      if (mounted) Navigator.pop(context);
    } on _InsuranceEditFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar. Tus datos anteriores se conservan; intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Localizations.override(
      context: context,
      locale: const Locale('es', 'CO'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: _SheetBody(
        title: widget.original == null
            ? 'Registrar p\u00f3liza'
            : 'Editar p\u00f3liza',
        children: [
          Text(widget.vehicle.nickname ?? widget.vehicle.plate),
          const Text(
            'Informaci\u00f3n registrada por ti; no verifica cobertura.',
          ),
          Form(
            key: _form,
            child: AbsorbPointer(
              absorbing: _busy,
              child: Column(
                children: [
                  FormField<String>(
                    validator: (_) =>
                        _fields['providerName']!.text.trim().isEmpty
                        ? 'Selecciona o escribe una aseguradora.'
                        : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          key: const ValueKey('insurance-editor-insurer'),
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: 48,
                          leading: const Icon(Icons.shield_outlined),
                          title: const Text('Aseguradora'),
                          subtitle: Text(
                            _fields['providerName']!.text.isEmpty
                                ? 'Seleccionar aseguradora'
                                : _fields['providerName']!.text,
                          ),
                          trailing: const Icon(Icons.expand_more),
                          onTap: _selectInsurer,
                        ),
                        if (field.hasError)
                          Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _field(
                    'policyNumber',
                    'N\u00famero de p\u00f3liza (opcional)',
                  ),
                  _dateField('start', 'Inicio de vigencia'),
                  _dateField('due', 'Vencimiento'),
                  _valueField(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recordatorio de vencimiento'),
                    subtitle: const Text(
                      'Requiere una fecha de vencimiento registrada.',
                    ),
                    value: _reminder,
                    onChanged: (value) => setState(() => _reminder = value),
                  ),
                  ListTile(
                    key: const ValueKey('insurance-editor-phones-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Contactos particulares (opcional)'),
                    subtitle: Text(
                      '${_phones.where((id) => _fields[id]!.text.trim().isNotEmpty).length} guardados',
                    ),
                    trailing: Icon(
                      _phonesExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onTap: () =>
                        setState(() => _phonesExpanded = !_phonesExpanded),
                  ),
                  if (_phonesExpanded) ...[
                    const Text('Sin verificaci\u00f3n del directorio'),
                    _field('assistancePhone', 'Tel\u00e9fono de asistencia'),
                    _field('towPhone', 'Tel\u00e9fono de gr\u00faa'),
                    _field(
                      'designatedDriverPhone',
                      'Tel\u00e9fono de conductor elegido',
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            key: const ValueKey('insurance-editor-save'),
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(_busy ? 'Guardando...' : 'Guardar'),
          ),
        ],
      ),
    ),
  );

  Widget _dateField(String id, String label) => Builder(
    builder: (calendarContext) => ListTile(
      key: ValueKey('insurance-editor-$id'),
      contentPadding: EdgeInsets.zero,
      minTileHeight: 48,
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(label),
      subtitle: Text(_displayDate(_parseDate(_fields[id]!.text))),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _selectDate(id, calendarContext),
    ),
  );

  Widget _valueField() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      const Text('Valor de la p\u00f3liza (opcional)'),
      const SizedBox(height: 8),
      SegmentedButton<InsuranceValuePeriod>(
        segments: const [
          ButtonSegment(
            value: InsuranceValuePeriod.annual,
            label: Text('Anual'),
          ),
          ButtonSegment(
            value: InsuranceValuePeriod.monthly,
            label: Text('Mensual'),
          ),
        ],
        selected: {_valuePeriod},
        onSelectionChanged: (values) => _viewPeriod(values.single),
      ),
      const SizedBox(height: 8),
      TextFormField(
        key: const ValueKey('insurance-editor-premium'),
        controller: _premium,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Valor en COP',
          hintText: '1.200.000,50',
          suffixIcon: IconButton(
            tooltip: 'Quitar valor',
            onPressed: () => setState(() {
              _premium.clear();
              _valueSource = null;
              _valueEdited = true;
            }),
            icon: const Icon(Icons.clear),
          ),
        ),
        onChanged: (text) => setState(() {
          _valueEdited = true;
          final minorUnits = InsurancePolicyValue.parseMinorUnits(text);
          _valueSource = minorUnits == null
              ? null
              : InsurancePolicyValue(
                  minorUnits: minorUnits,
                  period: _valuePeriod,
                );
        }),
        validator: (text) =>
            _valueEdited &&
                (text?.trim().isNotEmpty ?? false) &&
                _valueSource == null
            ? 'Escribe un valor v\u00e1lido en COP.'
            : null,
      ),
      if (_valueSource case final source?)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Equivalente ${_valuePeriod == InsuranceValuePeriod.annual ? 'mensual' : 'anual'}: ${source.formattedFor(_valuePeriod == InsuranceValuePeriod.annual ? InsuranceValuePeriod.monthly : InsuranceValuePeriod.annual)} COP',
          ),
        ),
    ],
  );

  Widget _field(String id, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey('insurance-editor-$id'),
            controller: _fields[id],
            keyboardType: _phones.contains(id)
                ? TextInputType.phone
                : TextInputType.text,
            onChanged: _phones.contains(id) ? (_) => setState(() {}) : null,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              if (_phones.contains(id)) return _phoneError(id, text);
              return null;
            },
          ),
        ),
      ],
    ),
  );

  String? _phoneError(String id, String value) {
    final text = value.trim();
    if (text.isEmpty || text == (widget.original?.details[id] ?? '').trim()) {
      return null;
    }
    return RegExp(r'^\+?[0-9*#]{3,18}$')
            .hasMatch(text.replaceAll(RegExp(r'[\s()-]'), ''))
        ? null
        : 'Revisa el tel\u00e9fono.';
  }
}

class _InsuranceEditFailure implements Exception {
  const _InsuranceEditFailure(this.message);
  final String message;
}

String _date(DateTime? date) => date == null
    ? ''
    : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _displayDate(DateTime? date) => date == null
    ? 'Sin registrar'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
DateTime? _parseDate(String input) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input.trim());
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  return year > 0 && date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

class _InsuranceAssistance extends ConsumerWidget {
  const _InsuranceAssistance({required this.vehicle, required this.original});
  final VehicleProfile? vehicle;
  final VehicleObligation? original;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(insuranceDirectoryProvider);
    final obligation = vehicle == null
        ? null
        : ref.watch(
            vehicleObligationProvider((
              vehicle!.id,
              VehicleObligationType.insurance,
            )),
          );
    final details =
        obligation?.asData?.value?.details ??
        (obligation?.isLoading == true ? original?.details : null) ??
        const <String, String>{};
    return _SheetBody(
      title: 'Necesito asistencia',
      children: [
        const Text('Servicios sujetos a tu p\u00f3liza.'),
        if (vehicle != null) Text(vehicle!.nickname ?? vehicle!.plate),
        if (obligation?.hasError == true) ...[
          const Text('No se pudieron leer los datos de tu p\u00f3liza.'),
          TextButton(
            onPressed: () => ref.invalidate(
              vehicleObligationProvider((
                vehicle!.id,
                VehicleObligationType.insurance,
              )),
            ),
            child: const Text('Reintentar'),
          ),
        ],
        if ((details['providerName'] ?? '').isNotEmpty)
          Text(details['providerName']!),
        if ((details['policyNumber'] ?? '').isNotEmpty)
          ListTile(
            title: const Text('N\u00famero de p\u00f3liza'),
            subtitle: Text(details['policyNumber']!),
            trailing: IconButton(
              tooltip: 'Copiar n\u00famero de p\u00f3liza',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => _copy(context, details['policyNumber']!),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Canales oficiales',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        directory.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(insuranceDirectoryProvider),
            child: const Text('Reintentar directorio'),
          ),
          data: (catalog) {
            final company = catalog.resolve(
              details['providerId'],
              details['providerName'],
            );
            if (company == null) {
              return const Text(
                'Selecciona una aseguradora en el directorio para consultar sus canales.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final channel in company.verifiedChannels)
                  _channelTile(context, ref, channel),
                for (final service in const {
                  InsuranceService.towing: 'Gr\u00faa',
                  InsuranceService.designatedDriver: 'Conductor elegido',
                  InsuranceService.roadsideRepair: 'Carro taller',
                }.entries)
                  if (!company.verifiedChannels.any(
                    (channel) => channel.services.contains(service.key),
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${service.value}: canal espec\u00edfico sin confirmar. Consulta a tu aseguradora.',
                      ),
                    ),
                TextButton(
                  onPressed: () => _website(context, ref, company.website),
                  child: const Text('Web oficial'),
                ),
              ],
            );
          },
        ),
        if ([
          'assistancePhone',
          'towPhone',
          'designatedDriverPhone',
        ].any((key) => (details[key] ?? '').trim().isNotEmpty)) ...[
          const Divider(),
          const Text(
            'Contactos particulares',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final entry in const {
            'assistancePhone': 'Asistencia',
            'towPhone': 'Gr\u00faa',
            'designatedDriverPhone': 'Conductor elegido',
          }.entries)
            if ((details[entry.key] ?? '').trim().isNotEmpty)
              ListTile(
                key: ValueKey('call-${entry.key}'),
                title: Text(entry.value),
                subtitle: Text(
                  '${details[entry.key]}\nContacto particular, no verificado',
                ),
                leading: const Icon(Icons.phone_outlined),
                onTap: () => _openPhone(
                  context,
                  ref.read(externalLauncherProvider),
                  details[entry.key]!,
                ),
              ),
        ],
        TextButton.icon(
          onPressed: () => showInsuranceDirectory(context, ref),
          icon: const Icon(Icons.search),
          label: const Text('Directorio de aseguradoras'),
        ),
      ],
    );
  }
}

class _InsuranceDocuments extends ConsumerWidget {
  const _InsuranceDocuments({required this.vehicle});
  final VehicleProfile vehicle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = WalletOwner.vehicle(vehicle.id);
    final documents = ref.watch(walletDocumentsProvider(owner));
    final obligation = ref.watch(
      vehicleObligationProvider((vehicle.id, VehicleObligationType.insurance)),
    );
    return _SheetBody(
      title: 'Mi p\u00f3liza y documentos',
      children: [
        obligation.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(
              vehicleObligationProvider((
                vehicle.id,
                VehicleObligationType.insurance,
              )),
            ),
            child: const Text('Reintentar datos de p\u00f3liza'),
          ),
          data: (policy) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                policy?.details['providerName'] ?? 'Aseguradora sin registrar',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                [vehicle.nickname, vehicle.brand, vehicle.model, vehicle.plate]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .join(' \u00b7 '),
              ),
              const SizedBox(height: 20),
              const Text('N\u00famero de p\u00f3liza'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (policy?.details['policyNumber'] ?? '').isEmpty
                          ? 'Sin registrar'
                          : policy!.details['policyNumber']!,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if ((policy?.details['policyNumber'] ?? '').isNotEmpty)
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: 'Copiar n\u00famero de p\u00f3liza',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () =>
                          _copy(context, policy!.details['policyNumber']!),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _PolicyDates(start: policy?.startDate, due: policy?.dueDate),
              const SizedBox(height: 16),
              if (InsurancePolicyValue.fromDetails(policy?.details ?? const {})
                  case final value?) ...[
                Text(
                  'Valor ${value.period == InsuranceValuePeriod.annual ? 'anual' : 'mensual'}',
                ),
                Text(
                  '${value.formattedFor(value.period)} COP',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Equivalente ${value.period == InsuranceValuePeriod.annual ? 'mensual' : 'anual'}: ${value.formattedFor(value.period == InsuranceValuePeriod.annual ? InsuranceValuePeriod.monthly : InsuranceValuePeriod.annual)} COP',
                ),
                const Text(
                  'Equivalencia de referencia; no representa cuotas ni financiaci\u00f3n.',
                ),
              ] else
                TextButton.icon(
                  onPressed: () => _edit(context, policy),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar valor de la p\u00f3liza'),
                ),
              const Divider(height: 32),
            ],
          ),
        ),
        DocumentsRecoveryNotice(owner: owner),
        DocumentsAsyncContent(
          value: documents,
          loadingLabel: 'Cargando copia privada',
          errorLabel: 'No se pudo leer la copia. No se ha eliminado ning\u00fan archivo.',
          onRetry: () => ref.invalidate(walletDocumentsProvider(owner)),
          builder: (items) {
            final matches = items
                .where(
                  (item) => item.type == WalletDocumentType.voluntaryInsurance,
                )
                .toList();
            return Column(
              children: [
                if (matches.isEmpty)
                  TextButton.icon(
                    onPressed: () => WalletActions(context, ref).add(
                      owner,
                      WalletDocumentType.voluntaryInsurance,
                      ownerLabel: vehicle.nickname ?? vehicle.plate,
                    ),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Agregar copia de la p\u00f3liza'),
                  ),
                for (final document in matches)
                  ListTile(
                    title: const Text('Copia guardada'),
                    subtitle: const Text('Solo respaldo local'),
                    leading: const Icon(Icons.description_outlined),
                    onTap: () => WalletActions(context, ref).view(document),
                    trailing: IconButton(
                      tooltip: 'Reemplazar o eliminar copia',
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => showWalletDocumentMenu(
                        context,
                        ref,
                        document,
                        ownerLabel: vehicle.nickname ?? vehicle.plate,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (obligation.hasValue) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _edit(context, obligation.asData?.value),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar datos de p\u00f3liza'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Recordatorio de vencimiento'),
            subtitle: Text(
              obligation.asData?.value?.reminderEnabled != true
                  ? 'Desactivado'
                  : obligation.asData?.value?.dueDate == null
                  ? 'Pendiente de fecha'
                  : 'Activado',
            ),
            onTap: () => _edit(context, obligation.asData?.value),
          ),
        ],
      ],
    );
  }

  Future<void> _edit(BuildContext context, VehicleObligation? policy) =>
      _showSheet(
        context,
        DocumentsSessionSheet(
          child: _InsuranceEditor(
            vehicle: vehicle,
            original: policy,
            protectedSession: true,
          ),
        ),
      );
}

class _PolicyDates extends StatelessWidget {
  const _PolicyDates({required this.start, required this.due});
  final DateTime? start;
  final DateTime? due;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      Widget date(String label, DateTime? value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label)),
            ],
          ),
          Text(
            _displayDate(value),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      );
      final startWidget = date('Inicio de vigencia', start);
      final dueWidget = date('Vencimiento', due);
      if (MediaQuery.textScalerOf(context).scale(16) > 20 ||
          constraints.maxWidth < 300) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [startWidget, const SizedBox(height: 12), dueWidget],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: startWidget),
          const SizedBox(width: 16),
          Expanded(child: dueWidget),
        ],
      );
    },
  );
}

// Compact Spanish month/year keeps the standard mode toggle fully visible.
class _InsuranceCalendarDelegate extends GregorianCalendarDelegate {
  const _InsuranceCalendarDelegate();
  @override
  String formatMonthYear(DateTime date, MaterialLocalizations localizations) =>
      DateFormat('MMM y', 'es_CO').format(date);
}
