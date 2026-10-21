import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../application/defense_case_providers.dart';
import '../data/defense_case.dart';
import '../data/defense_case_summary.dart';

const defenseSimitUrl = 'https://www.simit.org.co/';
const defenseC038Url =
    'https://www.corteconstitucional.gov.co/Relatoria/2020/C-038-20.htm';
const defenseC321Url =
    'https://www.corteconstitucional.gov.co/Relatoria/2022/C-321-22.htm';

class DefenseScreen extends ConsumerWidget {
  const DefenseScreen({this.vehicleId, super.key});

  final String? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    final active = vehicleId?.trim().isNotEmpty == true
        ? const AsyncValue<VehicleProfile?>.data(null)
        : ref.watch(activeVehicleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Defensa')),
      body: SafeArea(
        child: vehicles.when(
          data: (items) => active.when(
            data: (activeVehicle) {
              final vehicle = _resolveVehicle(
                vehicles: items,
                activeVehicle: activeVehicle,
                vehicleId: vehicleId,
              );
              if (vehicle == null) {
                return const _NoVehiclePane();
              }
              return _DefenseContent(vehicle: vehicle);
            },
            loading: () => const _LoadingPane(),
            error: (error, stackTrace) => const _ErrorPane(
              message: 'No pudimos cargar el vehiculo favorito.',
            ),
          ),
          loading: () => const _LoadingPane(),
          error: (error, stackTrace) =>
              const _ErrorPane(message: 'No pudimos cargar los vehiculos.'),
        ),
      ),
    );
  }
}

class _DefenseContent extends ConsumerWidget {
  const _DefenseContent({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(defenseCasesProvider(vehicle.id));

    return SingleChildScrollView(
      key: const ValueKey('defense-screen'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        96,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VehicleSummary(vehicle: vehicle),
              const SizedBox(height: AppSpacing.l),
              const _PrudentNotice(),
              const SizedBox(height: AppSpacing.l),
              FilledButton.icon(
                key: const ValueKey('defense-create-case'),
                onPressed: () => _createCase(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo expediente'),
              ),
              const SizedBox(height: AppSpacing.l),
              _OfficialLinksCard(vehicle: vehicle),
              const SizedBox(height: AppSpacing.l),
              cases.when(
                data: (items) => items.isEmpty
                    ? const _EmptyCasesPane()
                    : _CaseList(vehicle: vehicle, cases: items),
                loading: () => const _InlineLoading(),
                error: (error, stackTrace) => const _ErrorPane(
                  message: 'No pudimos leer los expedientes de Defensa.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCase(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<DefenseCaseDraft>(
      context: context,
      builder: (context) => _DefenseCaseDialog(vehicleId: vehicle.id),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(defenseCaseStoreProvider).createCase(result);
      if (!context.mounted) {
        return;
      }
      ref.invalidate(defenseCasesProvider(vehicle.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expediente guardado localmente.')),
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos guardar el expediente.')),
        );
      }
    }
  }
}

class _CaseList extends StatelessWidget {
  const _CaseList({required this.vehicle, required this.cases});

  final VehicleProfile vehicle;
  final List<DefenseCase> cases;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('defense-case-list'),
      children: [
        for (final item in cases) ...[
          _DefenseCaseCard(vehicle: vehicle, defenseCase: item),
          const SizedBox(height: AppSpacing.m),
        ],
      ],
    );
  }
}

class _DefenseCaseCard extends ConsumerWidget {
  const _DefenseCaseCard({required this.vehicle, required this.defenseCase});

  final VehicleProfile vehicle;
  final DefenseCase defenseCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = defenseCase.reference;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        defenseCase.authority,
                        key: ValueKey('defense-authority-${defenseCase.id}'),
                        style: AppTextStyles.h2,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Hecho: ${formatDefenseDate(defenseCase.incidentDate)}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('defense-edit-${defenseCase.id}'),
                  tooltip: 'Editar',
                  onPressed: () => _editCase(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: ValueKey('defense-delete-${defenseCase.id}'),
                  tooltip: 'Eliminar',
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (reference != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text('Referencia: $reference', style: AppTextStyles.bodyStrong),
            ],
            const SizedBox(height: AppSpacing.s),
            Text(
              defenseCase.facts,
              key: ValueKey('defense-facts-${defenseCase.id}'),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.m),
            OutlinedButton.icon(
              key: ValueKey('defense-copy-${defenseCase.id}'),
              onPressed: () => _copySummary(context),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar resumen neutral'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCase(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<DefenseCaseDraft>(
      context: context,
      builder: (context) =>
          _DefenseCaseDialog(vehicleId: vehicle.id, initial: defenseCase),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(defenseCaseStoreProvider)
          .updateCase(caseId: defenseCase.id, draft: result);
      if (!context.mounted) {
        return;
      }
      ref.invalidate(defenseCasesProvider(vehicle.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expediente actualizado.')));
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos actualizar el expediente.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar expediente'),
        content: const Text(
          'Esta accion borra solo la informacion local de este expediente.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('defense-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('defense-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(defenseCaseStoreProvider).deleteCase(defenseCase.id);
      if (!context.mounted) {
        return;
      }
      ref.invalidate(defenseCasesProvider(vehicle.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expediente eliminado.')));
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos eliminar el expediente.')),
        );
      }
    }
  }

  Future<void> _copySummary(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copiar expediente'),
        content: const Text(
          'El resumen saldra del almacenamiento cifrado de PicoRadar y quedara en el portapapeles del sistema.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('defense-copy-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('defense-copy-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Copiar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final copied = await _copyTextToClipboard(
      buildDefenseCaseNeutralSummary(
        defenseCase: defenseCase,
        vehicle: vehicle,
      ),
    );
    if (!context.mounted) {
      return;
    }
    final message = copied
        ? 'Resumen neutral copiado.'
        : 'No pudimos copiar el resumen al portapapeles.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _copyTextToClipboard(String text) async {
    try {
      final result = await SystemChannels.platform.invokeMethod<Object?>(
        'Clipboard.setData',
        <String, dynamic>{'text': text},
      );
      return result != false;
    } on Object {
      return false;
    }
  }
}

class _DefenseCaseDialog extends StatefulWidget {
  const _DefenseCaseDialog({required this.vehicleId, this.initial});

  final String vehicleId;
  final DefenseCase? initial;

  @override
  State<_DefenseCaseDialog> createState() => _DefenseCaseDialogState();
}

class _DefenseCaseDialogState extends State<_DefenseCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _referenceController;
  late final TextEditingController _authorityController;
  late final TextEditingController _incidentDateController;
  late final TextEditingController _notificationDateController;
  late final TextEditingController _factsController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _referenceController = TextEditingController(
      text: initial?.reference ?? '',
    );
    _authorityController = TextEditingController(
      text: initial?.authority ?? '',
    );
    _incidentDateController = TextEditingController(
      text: initial == null ? '' : formatDefenseDate(initial.incidentDate),
    );
    _notificationDateController = TextEditingController(
      text: initial?.notificationDate == null
          ? ''
          : formatDefenseDate(initial!.notificationDate!),
    );
    _factsController = TextEditingController(text: initial?.facts ?? '');
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _authorityController.dispose();
    _incidentDateController.dispose();
    _notificationDateController.dispose();
    _factsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo expediente' : 'Editar caso'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('defense-reference-field'),
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia opcional',
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                TextFormField(
                  key: const ValueKey('defense-authority-field'),
                  controller: _authorityController,
                  decoration: const InputDecoration(labelText: 'Autoridad'),
                  validator: _requiredText,
                ),
                const SizedBox(height: AppSpacing.s),
                TextFormField(
                  key: const ValueKey('defense-incident-date-field'),
                  controller: _incidentDateController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha del hecho',
                    hintText: 'AAAA-MM-DD',
                  ),
                  validator: _requiredDate,
                ),
                const SizedBox(height: AppSpacing.s),
                TextFormField(
                  key: const ValueKey('defense-notification-date-field'),
                  controller: _notificationDateController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de notificacion opcional',
                    hintText: 'AAAA-MM-DD',
                  ),
                  validator: _optionalDate,
                ),
                const SizedBox(height: AppSpacing.s),
                TextFormField(
                  key: const ValueKey('defense-facts-field'),
                  controller: _factsController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Hechos escritos por ti',
                  ),
                  validator: _requiredText,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('defense-form-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('defense-form-save'),
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      DefenseCaseDraft(
        vehicleId: widget.vehicleId,
        reference: _referenceController.text,
        authority: _authorityController.text,
        incidentDate: parseDefenseDate(_incidentDateController.text),
        notificationDate: _notificationDateController.text.trim().isEmpty
            ? null
            : parseDefenseDate(_notificationDateController.text),
        facts: _factsController.text,
      ),
    );
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }

  String? _requiredDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return _dateValidation(value);
  }

  String? _optionalDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return _dateValidation(value);
  }

  String? _dateValidation(String value) {
    try {
      parseDefenseDate(value);
      return null;
    } on FormatException {
      return 'Usa AAAA-MM-DD';
    }
  }
}

class _OfficialLinksCard extends ConsumerWidget {
  const _OfficialLinksCard({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fuentes y consulta', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Puedes abrir fuentes oficiales y volver para completar tu expediente.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.m),
            OutlinedButton.icon(
              key: const ValueKey('defense-open-simit'),
              onPressed: () => _openExternal(
                context,
                ref,
                defenseSimitUrl,
                'No pudimos abrir SIMIT.',
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir SIMIT'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('defense-open-c038'),
              onPressed: () => _openExternal(
                context,
                ref,
                defenseC038Url,
                'No pudimos abrir C-038/20.',
              ),
              icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Abrir C-038/20'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('defense-open-c321'),
              onPressed: () => _openExternal(
                context,
                ref,
                defenseC321Url,
                'No pudimos abrir C-321/22.',
              ),
              icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Abrir C-321/22'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternal(
    BuildContext context,
    WidgetRef ref,
    String url,
    String failureMessage,
  ) async {
    final launcher = ref.read(externalLauncherProvider);
    var opened = false;
    try {
      opened = await launcher.openExternal(url);
    } on Object {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }
}

class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            Icon(
              vehicleIcon(vehicle),
              size: AppIconSize.l,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.plate,
                    key: const ValueKey('defense-plate'),
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    vehicle.registrationCity?.trim().isEmpty ?? true
                        ? 'Vehiculo local'
                        : vehicle.registrationCity!.trim(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrudentNotice extends StatelessWidget {
  const _PrudentNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(
          defensePrudentDisclaimer,
          key: const ValueKey('defense-prudent-disclaimer'),
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

class _EmptyCasesPane extends StatelessWidget {
  const _EmptyCasesPane();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('defense-empty-cases'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(
          'Aun no tienes expedientes locales para este vehiculo.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

class _NoVehiclePane extends StatelessWidget {
  const _NoVehiclePane();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('defense-no-vehicle'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined, size: 48),
            const SizedBox(height: AppSpacing.m),
            Text('Agrega un vehiculo', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Defensa necesita asociar cada expediente a un vehiculo local.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('defense-loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('defense-cases-loading'),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.l),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('defense-error'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message, style: AppTextStyles.body),
    );
  }
}

VehicleProfile? _resolveVehicle({
  required List<VehicleProfile> vehicles,
  required VehicleProfile? activeVehicle,
  required String? vehicleId,
}) {
  final requestedId = vehicleId?.trim();
  if (requestedId != null && requestedId.isNotEmpty) {
    for (final vehicle in vehicles) {
      if (vehicle.id == requestedId) {
        return vehicle;
      }
    }
    return null;
  }
  return activeVehicle ?? (vehicles.isEmpty ? null : vehicles.first);
}
