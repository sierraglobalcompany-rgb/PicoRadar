import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../data/vehicle_status_catalog.dart';
import '../domain/vehicle_obligation.dart';
import '../platform/external_launcher.dart';
import 'soat_rtm_owner_content.dart';

export '../platform/external_launcher.dart';

class VehicleStatusScreen extends ConsumerStatefulWidget {
  const VehicleStatusScreen({
    required this.moduleId,
    required this.vehicleId,
    super.key,
  });

  final String moduleId;
  final String? vehicleId;

  @override
  ConsumerState<VehicleStatusScreen> createState() =>
      _VehicleStatusScreenState();
}

class _VehicleStatusScreenState extends ConsumerState<VehicleStatusScreen> {
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.vehicleId;
  }

  @override
  void didUpdateWidget(VehicleStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleId != widget.vehicleId) {
      _selectedVehicleId = widget.vehicleId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _typeFromModule(widget.moduleId);
    if (type == null) {
      return const _MissingStatusModule();
    }
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle(type))),
      body: SafeArea(
        child: vehicles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorText(message: error.toString()),
          data: (items) {
            final vehicle = _resolveVehicle(
              items,
              active.asData?.value,
              _selectedVehicleId,
            );
            if (vehicle == null) {
              return const Center(
                child: Text('Agrega un vehículo para usar esta función.'),
              );
            }
            final obligation = ref.watch(
              vehicleObligationProvider((vehicle.id, type)),
            );
            return obligation.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  _ErrorText(message: error.toString()),
              data: (value) {
                if (type == VehicleObligationType.soat ||
                    type == VehicleObligationType.rtm) {
                  return SoatRtmOwnerContent(
                    vehicle: vehicle,
                    vehicles: items,
                    type: type,
                    obligation: value,
                    onEdit: () =>
                        _editObligation(context, ref, vehicle, type, value),
                    onSelectVehicle: (selected) {
                      setState(() => _selectedVehicleId = selected.id);
                    },
                  );
                }
                return _VehicleStatusContent(
                  vehicle: vehicle,
                  type: type,
                  obligation: value,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _VehicleStatusContent extends ConsumerWidget {
  const _VehicleStatusContent({
    required this.vehicle,
    required this.type,
    required this.obligation,
  });

  final VehicleProfile vehicle;
  final VehicleObligationType type;
  final VehicleObligation? obligation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowBogota = ref.watch(bogotaNowProvider);
    final state = evaluateVehicleObligationState(
      dueDate: obligation?.dueDate,
      nowBogota: nowBogota,
    );
    final details = obligation?.details ?? const <String, String>{};

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VehicleHeader(vehicle: vehicle),
                const SizedBox(height: AppSpacing.xl),
                if (type == VehicleObligationType.tax)
                  _TaxPanel(vehicle: vehicle, obligation: obligation)
                else ...[
                  _StatusPanel(
                    type: type,
                    obligation: obligation,
                    state: state,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _DetailPanel(type: type, details: details),
                  const SizedBox(height: AppSpacing.l),
                  _ReminderPanel(
                    type: type,
                    vehicleId: vehicle.id,
                    obligation: obligation,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  FilledButton.icon(
                    key: const ValueKey('vehicle-status-edit'),
                    onPressed: () => _editObligation(
                      context,
                      ref,
                      vehicle,
                      type,
                      obligation,
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar / guardar'),
                  ),
                ],
                const SizedBox(height: AppSpacing.l),
                _OfficialActions(type: type),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(vehicleIcon(vehicle), color: vehicleAccent(vehicle), size: 44),
        const SizedBox(width: AppSpacing.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.plate,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(vehicleTypeLabel(vehicle)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.type,
    required this.obligation,
    required this.state,
  });

  final VehicleObligationType type;
  final VehicleObligation? obligation;
  final VehicleObligationState state;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            obligationStatusText(type, state),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          const Text(
            'La fecha mostrada fue guardada en este dispositivo. Verifica la vigencia oficial en RUNT.',
          ),
          const SizedBox(height: AppSpacing.m),
          _DateLine(label: _startLabel(type), date: obligation?.startDate),
          _DateLine(label: 'Fecha vencimiento', date: obligation?.dueDate),
        ],
      ),
    );
  }
}

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({required this.type, required this.details});

  final VehicleObligationType type;
  final Map<String, String> details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneKeys = switch (type) {
      VehicleObligationType.insurance => [
        ('assistancePhone', 'Asistencia'),
        ('towPhone', 'Grúa'),
        ('designatedDriverPhone', 'Conductor elegido'),
      ],
      _ => const <(String, String)>[],
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in _detailRows(type, details))
            _TextLine(label: entry.$1, value: entry.$2),
          if (type == VehicleObligationType.insurance) ...[
            const SizedBox(height: AppSpacing.s),
            const Text(
              'Disponible según las coberturas y condiciones de tu póliza.',
            ),
            const SizedBox(height: AppSpacing.s),
            for (final phone in phoneKeys)
              if ((details[phone.$1] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s),
                  child: OutlinedButton.icon(
                    key: ValueKey('call-${phone.$1}'),
                    onPressed: () => ref
                        .read(externalLauncherProvider)
                        .callPhone(details[phone.$1]!),
                    icon: const Icon(Icons.call),
                    label: Text('Llamar ${phone.$2}'),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _ReminderPanel extends ConsumerWidget {
  const _ReminderPanel({
    required this.type,
    required this.vehicleId,
    required this.obligation,
  });

  final VehicleObligationType type;
  final String vehicleId;
  final VehicleObligation? obligation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(picoAlertPreferencesProvider);
    final permissionGranted = alerts.asData?.value.permissionGranted ?? false;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recordatorio',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Switch(
                key: const ValueKey('obligation-reminder-enabled'),
                value: obligation?.reminderEnabled ?? true,
                onChanged: (value) async {
                  await _saveReminderOnly(
                    ref,
                    vehicleId,
                    type,
                    obligation,
                    value,
                  );
                },
              ),
            ],
          ),
          const Text('30, 7 y 1 día antes a las 09:00.'),
          if (!permissionGranted)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.s),
              child: Text(
                'Activa las notificaciones desde Inicio para recibir recordatorios.',
              ),
            ),
        ],
      ),
    );
  }
}

class _TaxPanel extends ConsumerWidget {
  const _TaxPanel({required this.vehicle, required this.obligation});

  final VehicleProfile vehicle;
  final VehicleObligation? obligation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowBogota = ref.watch(bogotaNowProvider);
    final authorityId =
        obligation?.details['authorityId'] ??
        suggestTaxCalendar(vehicle.registrationCity)?.authorityId;
    final calendar = taxCalendarByAuthority(authorityId);
    final current = calendar?.isCurrent(nowBogota) ?? false;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No calculamos ni estimamos el impuesto.'),
          const SizedBox(height: AppSpacing.m),
          DropdownButtonFormField<String>(
            key: const ValueKey('tax-authority-field'),
            initialValue: calendar?.authorityId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Entidad tributaria'),
            items: [
              for (final item in vehicleTaxCalendars)
                DropdownMenuItem(
                  value: item.authorityId,
                  child: Text(item.authorityName),
                ),
            ],
            onChanged: (value) async {
              if (value == null) {
                return;
              }
              await ref
                  .read(vehicleObligationStoreProvider)
                  .upsert(
                    vehicleId: vehicle.id,
                    type: VehicleObligationType.tax,
                    details: {'authorityId': value},
                    reminderEnabled: false,
                  );
              ref.invalidate(
                vehicleObligationProvider((
                  vehicle.id,
                  VehicleObligationType.tax,
                )),
              );
              ref.invalidate(vehicleObligationsProvider(vehicle.id));
            },
          ),
          const SizedBox(height: AppSpacing.m),
          if (calendar == null)
            const Text(
              'Todavía no tenemos calendario local verificado para esta matrícula.',
            )
          else ...[
            Text(
              calendar.authorityName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              current
                  ? 'Calendario oficial disponible ${calendar.year}.'
                  : 'Calendario pendiente de actualización.',
            ),
            if (!current)
              const Text(
                'Consulta el calendario actualizado en el portal oficial.',
              ),
            const SizedBox(height: AppSpacing.m),
            for (final date in calendar.importantDates)
              _TextLine(label: date.label, value: formatFullDate(date.date)),
          ],
        ],
      ),
    );
  }
}

class _OfficialActions extends ConsumerWidget {
  const _OfficialActions({required this.type});

  final VehicleObligationType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launcher = ref.watch(externalLauncherProvider);
    final link = switch (type) {
      VehicleObligationType.soat ||
      VehicleObligationType.rtm => runtVehicleByPlateLink,
      VehicleObligationType.insurance => fasecoldaAutomovilesLink,
      VehicleObligationType.tax => null,
    };
    final taxLinks = type == VehicleObligationType.tax
        ? vehicleTaxCalendars.map((calendar) => calendar.portalLink).toList()
        : const <OfficialVehicleLink>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (link != null)
          OutlinedButton.icon(
            key: ValueKey('official-link-${link.id}'),
            onPressed: () => launcher.openExternal(link.uri),
            icon: const Icon(Icons.open_in_new),
            label: Text('${link.title} · ${link.sourceName}'),
          ),
        for (final taxLink in taxLinks)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: OutlinedButton.icon(
              key: ValueKey('official-link-${taxLink.id}'),
              onPressed: () => launcher.openExternal(taxLink.uri),
              icon: const Icon(Icons.open_in_new),
              label: Text('${taxLink.title} · ${taxLink.sourceName}'),
            ),
          ),
        if (type == VehicleObligationType.rtm)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: OutlinedButton.icon(
              key: const ValueKey('rtm-find-cda'),
              onPressed: () => context.push('/apps/cda'),
              icon: const Icon(Icons.search),
              label: const Text('Buscar CDA'),
            ),
          ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.l), child: child),
    );
  }
}

class _DateLine extends StatelessWidget {
  const _DateLine({required this.label, required this.date});

  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return _TextLine(
      label: label,
      value: date == null ? 'Sin guardar' : formatFullDate(date!),
    );
  }
}

class _TextLine extends StatelessWidget {
  const _TextLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(value),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message),
    );
  }
}

class _MissingStatusModule extends StatelessWidget {
  const _MissingStatusModule();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Módulo no disponible')));
  }
}

Future<void> _editObligation(
  BuildContext context,
  WidgetRef ref,
  VehicleProfile vehicle,
  VehicleObligationType type,
  VehicleObligation? obligation,
) async {
  final details = obligation?.details ?? const <String, String>{};
  final startController = TextEditingController(
    text: _inputDate(obligation?.startDate),
  );
  final dueController = TextEditingController(
    text: _inputDate(obligation?.dueDate),
  );
  final firstController = TextEditingController(
    text: details[_firstDetailKey(type)] ?? '',
  );
  final policyController = TextEditingController(
    text: details['policyNumber'] ?? '',
  );
  final certificateController = TextEditingController(
    text: details['certificateNumber'] ?? '',
  );
  final assistanceController = TextEditingController(
    text: details['assistancePhone'] ?? '',
  );
  final towController = TextEditingController(text: details['towPhone'] ?? '');
  final driverController = TextEditingController(
    text: details['designatedDriverPhone'] ?? '',
  );
  var selectedProvider = _insuranceInitialProvider(details);

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Editar ${_screenTitle(type)}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const ValueKey('status-start-date-field'),
                    controller: startController,
                    decoration: InputDecoration(
                      labelText: _startLabel(type),
                      hintText: 'AAAA-MM-DD',
                    ),
                  ),
                  TextField(
                    key: const ValueKey('status-due-date-field'),
                    controller: dueController,
                    decoration: const InputDecoration(
                      labelText: 'Fecha vencimiento',
                      hintText: 'AAAA-MM-DD',
                    ),
                  ),
                  if (type == VehicleObligationType.insurance)
                    DropdownButtonFormField<String>(
                      key: const ValueKey('insurance-provider-field'),
                      initialValue: selectedProvider,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Aseguradora',
                      ),
                      items: [
                        for (final provider in insuranceProviderOptions)
                          DropdownMenuItem(
                            value: provider,
                            child: Text(provider),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedProvider = value),
                    )
                  else
                    TextField(
                      key: ValueKey('status-${_firstDetailKey(type)}-field'),
                      controller: firstController,
                      decoration: InputDecoration(
                        labelText: _firstDetailLabel(type),
                      ),
                    ),
                  if (type == VehicleObligationType.insurance &&
                      selectedProvider == 'Otra / no aparece')
                    TextField(
                      key: const ValueKey('insurance-custom-provider-field'),
                      controller: firstController,
                      decoration: const InputDecoration(
                        labelText: 'Aseguradora',
                      ),
                    ),
                  if (type != VehicleObligationType.rtm)
                    TextField(
                      key: const ValueKey('status-policy-number-field'),
                      controller: policyController,
                      decoration: const InputDecoration(
                        labelText: 'Número póliza',
                      ),
                    )
                  else
                    TextField(
                      key: const ValueKey('status-certificate-number-field'),
                      controller: certificateController,
                      decoration: const InputDecoration(
                        labelText: 'N. de certificado',
                      ),
                    ),
                  if (type == VehicleObligationType.insurance) ...[
                    TextField(
                      key: const ValueKey('insurance-assistance-phone-field'),
                      controller: assistanceController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono asistencia',
                      ),
                    ),
                    TextField(
                      key: const ValueKey('insurance-tow-phone-field'),
                      controller: towController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono grúa',
                      ),
                    ),
                    TextField(
                      key: const ValueKey('insurance-driver-phone-field'),
                      controller: driverController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono conductor elegido',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const ValueKey('status-save-button'),
                onPressed: () async {
                  await _saveObligation(
                    ref,
                    vehicle.id,
                    type,
                    startController.text,
                    dueController.text,
                    firstController.text,
                    selectedProvider,
                    policyController.text,
                    certificateController.text,
                    assistanceController.text,
                    towController.text,
                    driverController.text,
                    obligation?.reminderEnabled ?? true,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );
    },
  );

  await Future<void>.delayed(const Duration(milliseconds: 300));
  startController.dispose();
  dueController.dispose();
  firstController.dispose();
  policyController.dispose();
  certificateController.dispose();
  assistanceController.dispose();
  towController.dispose();
  driverController.dispose();
}

Future<void> _saveObligation(
  WidgetRef ref,
  String vehicleId,
  VehicleObligationType type,
  String startDate,
  String dueDate,
  String firstDetail,
  String? selectedProvider,
  String policyNumber,
  String certificateNumber,
  String assistancePhone,
  String towPhone,
  String driverPhone,
  bool reminderEnabled,
) async {
  final details = <String, String>{};
  switch (type) {
    case VehicleObligationType.soat:
      details['insurerName'] = firstDetail;
      details['policyNumber'] = policyNumber;
    case VehicleObligationType.rtm:
      details['cdaName'] = firstDetail;
      details['certificateNumber'] = certificateNumber;
    case VehicleObligationType.insurance:
      details['providerName'] = selectedProvider == 'Otra / no aparece'
          ? firstDetail
          : (selectedProvider ?? firstDetail);
      details['policyNumber'] = policyNumber;
      details['assistancePhone'] = assistancePhone;
      details['towPhone'] = towPhone;
      details['designatedDriverPhone'] = driverPhone;
    case VehicleObligationType.tax:
      return;
  }
  await ref
      .read(vehicleObligationStoreProvider)
      .upsert(
        vehicleId: vehicleId,
        type: type,
        startDate: _parseInputDate(startDate),
        dueDate: _parseInputDate(dueDate),
        details: details,
        reminderEnabled: reminderEnabled,
      );
  ref.invalidate(vehicleObligationProvider((vehicleId, type)));
  ref.invalidate(vehicleObligationsProvider(vehicleId));
  ref.invalidate(obligationNotificationSyncProvider);
}

Future<void> _saveReminderOnly(
  WidgetRef ref,
  String vehicleId,
  VehicleObligationType type,
  VehicleObligation? obligation,
  bool enabled,
) async {
  await ref
      .read(vehicleObligationStoreProvider)
      .upsert(
        vehicleId: vehicleId,
        type: type,
        startDate: obligation?.startDate,
        dueDate: obligation?.dueDate,
        details: obligation?.details ?? const {},
        reminderEnabled: enabled,
      );
  ref.invalidate(vehicleObligationProvider((vehicleId, type)));
  ref.invalidate(vehicleObligationsProvider(vehicleId));
  ref.invalidate(obligationNotificationSyncProvider);
}

VehicleProfile? _resolveVehicle(
  List<VehicleProfile> vehicles,
  VehicleProfile? active,
  String? vehicleId,
) {
  if (vehicleId != null) {
    for (final vehicle in vehicles) {
      if (vehicle.id == vehicleId) {
        return vehicle;
      }
    }
  }
  return active ?? (vehicles.isEmpty ? null : vehicles.first);
}

VehicleObligationType? _typeFromModule(String moduleId) {
  return switch (moduleId) {
    'soat' => VehicleObligationType.soat,
    'tecnomecanica' => VehicleObligationType.rtm,
    'seguro_asistencia' => VehicleObligationType.insurance,
    'impuestos' => VehicleObligationType.tax,
    _ => null,
  };
}

String _screenTitle(VehicleObligationType type) {
  return switch (type) {
    VehicleObligationType.soat => 'SOAT',
    VehicleObligationType.rtm => 'Tecnomecánica / RTM',
    VehicleObligationType.insurance => 'Seguro y asistencia',
    VehicleObligationType.tax => 'Impuestos',
  };
}

String _startLabel(VehicleObligationType type) {
  return switch (type) {
    VehicleObligationType.rtm => 'Fecha expedición/inicio',
    _ => 'Fecha inicio',
  };
}

String _firstDetailKey(VehicleObligationType type) {
  return switch (type) {
    VehicleObligationType.soat => 'insurerName',
    VehicleObligationType.rtm => 'cdaName',
    VehicleObligationType.insurance => 'providerName',
    VehicleObligationType.tax => 'authorityId',
  };
}

String _firstDetailLabel(VehicleObligationType type) {
  return switch (type) {
    VehicleObligationType.soat => 'Aseguradora',
    VehicleObligationType.rtm => 'CDA donde se realizó',
    VehicleObligationType.insurance => 'Aseguradora',
    VehicleObligationType.tax => 'Entidad',
  };
}

List<(String, String)> _detailRows(
  VehicleObligationType type,
  Map<String, String> details,
) {
  return switch (type) {
    VehicleObligationType.soat => [
      ('Aseguradora', details['insurerName'] ?? ''),
      ('Número póliza', details['policyNumber'] ?? ''),
    ],
    VehicleObligationType.rtm => [
      ('CDA', details['cdaName'] ?? ''),
      ('N. de certificado', details['certificateNumber'] ?? ''),
    ],
    VehicleObligationType.insurance => [
      ('Aseguradora', details['providerName'] ?? ''),
      ('Número póliza', details['policyNumber'] ?? ''),
      ('Teléfono asistencia', details['assistancePhone'] ?? ''),
      ('Teléfono grúa', details['towPhone'] ?? ''),
      ('Teléfono conductor elegido', details['designatedDriverPhone'] ?? ''),
    ],
    VehicleObligationType.tax => const [],
  };
}

String? _insuranceInitialProvider(Map<String, String> details) {
  final provider = details['providerName'];
  if (provider == null || provider.isEmpty) {
    return null;
  }
  return insuranceProviderOptions.contains(provider)
      ? provider
      : 'Otra / no aparece';
}

DateTime? _parseInputDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final parts = trimmed.split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

String _inputDate(DateTime? date) {
  if (date == null) {
    return '';
  }
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String formatFullDate(DateTime date) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${date.day} de ${months[date.month - 1]} de ${date.year}';
}
