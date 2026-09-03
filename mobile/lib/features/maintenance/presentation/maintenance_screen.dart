import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../data/maintenance_record.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(maintenanceRecordsProvider(vehicleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Talleres y mantenimiento')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('maintenance-add'),
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: SafeArea(
        child: records.when(
          data: (items) => _MaintenanceList(
            records: items,
            onEdit: (record) => _openEditor(context, ref, record: record),
            onDelete: (record) => _deleteRecord(context, ref, record),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _MaintenanceError(error: error),
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    MaintenanceRecord? record,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _MaintenanceEditorSheet(vehicleId: vehicleId, record: record);
      },
    );
    ref.invalidate(maintenanceRecordsProvider(vehicleId));
  }

  Future<void> _deleteRecord(
    BuildContext context,
    WidgetRef ref,
    MaintenanceRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mantenimiento'),
        content: Text('Se eliminará "${record.type}" de este vehículo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('maintenance-confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(maintenanceRepositoryProvider).delete(record.id);
    ref.invalidate(maintenanceRecordsProvider(vehicleId));
  }
}

class _MaintenanceList extends StatelessWidget {
  const _MaintenanceList({
    required this.records,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MaintenanceRecord> records;
  final ValueChanged<MaintenanceRecord> onEdit;
  final ValueChanged<MaintenanceRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return ListView(
        key: const ValueKey('maintenance-empty'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l,
          96,
        ),
        children: const [_EmptyMaintenanceCard()],
      );
    }

    return ListView.separated(
      key: const ValueKey('maintenance-list'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        96,
      ),
      itemBuilder: (context, index) {
        final record = records[index];
        return _MaintenanceRecordCard(
          record: record,
          onEdit: () => onEdit(record),
          onDelete: () => onDelete(record),
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.s),
      itemCount: records.length,
    );
  }
}

class _EmptyMaintenanceCard extends StatelessWidget {
  const _EmptyMaintenanceCard();

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.car_repair, color: AppColors.teal),
            const SizedBox(height: AppSpacing.m),
            Text('Sin registros todavía', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Guarda mantenimientos hechos, costos y próximos servicios para este vehículo.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.navy.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceRecordCard extends StatelessWidget {
  const _MaintenanceRecordCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final MaintenanceRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (record.odometer != null) '${_formatNumber(record.odometer!)} km',
      if (record.costCents != null) _formatCurrency(record.costCents!),
      if (record.nextServiceDate != null)
        'Próximo: ${_formatDate(record.nextServiceDate!)}',
      if (record.nextOdometer != null)
        'Próximo: ${_formatNumber(record.nextOdometer!)} km',
    ];
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        key: ValueKey('maintenance-card-${record.id}'),
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.10),
                  child: const Icon(
                    Icons.build_outlined,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.type, style: AppTextStyles.bodyStrong),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_formatDate(record.serviceDate)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        record.description,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.72),
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s),
                        Wrap(
                          spacing: AppSpacing.s,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final detail in details)
                              Chip(
                                label: Text(detail),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: ValueKey('maintenance-menu-${record.id}'),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceEditorSheet extends ConsumerStatefulWidget {
  const _MaintenanceEditorSheet({required this.vehicleId, this.record});

  final String vehicleId;
  final MaintenanceRecord? record;

  @override
  ConsumerState<_MaintenanceEditorSheet> createState() =>
      _MaintenanceEditorSheetState();
}

class _MaintenanceEditorSheetState
    extends ConsumerState<_MaintenanceEditorSheet> {
  late DateTime _serviceDate;
  DateTime? _nextServiceDate;
  late final TextEditingController _typeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _odometerController;
  late final TextEditingController _costController;
  late final TextEditingController _nextOdometerController;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _serviceDate = record?.serviceDate ?? DateTime.now();
    _nextServiceDate = record?.nextServiceDate;
    _typeController = TextEditingController(text: record?.type ?? '');
    _descriptionController = TextEditingController(
      text: record?.description ?? '',
    );
    _odometerController = TextEditingController(
      text: record?.odometer?.toString() ?? '',
    );
    _costController = TextEditingController(
      text: record?.costCents == null
          ? ''
          : (record!.costCents! ~/ 100).toString(),
    );
    _nextOdometerController = TextEditingController(
      text: record?.nextOdometer?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _descriptionController.dispose();
    _odometerController.dispose();
    _costController.dispose();
    _nextOdometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final isEditing = widget.record != null;
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('maintenance-editor'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l + viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Editar mantenimiento' : 'Nuevo mantenimiento',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: AppSpacing.m),
            OutlinedButton.icon(
              key: const ValueKey('maintenance-service-date'),
              onPressed: () => _pickServiceDate(context),
              icon: const Icon(Icons.calendar_month),
              label: Text('Fecha: ${_formatDate(_serviceDate)}'),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('maintenance-type-field'),
              controller: _typeController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                hintText: 'Cambio de aceite',
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('maintenance-description-field'),
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('maintenance-odometer-field'),
              controller: _odometerController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Kilometraje'),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('maintenance-cost-field'),
              controller: _costController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Costo en pesos'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('maintenance-next-date'),
              onPressed: () => _pickNextServiceDate(context),
              icon: const Icon(Icons.event_repeat),
              label: Text(
                _nextServiceDate == null
                    ? 'Próxima fecha'
                    : 'Próxima: ${_formatDate(_nextServiceDate!)}',
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('maintenance-next-odometer-field'),
              controller: _nextOdometerController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Próximo kilometraje',
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton.icon(
              key: const ValueKey('maintenance-save'),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickServiceDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() => _serviceDate = picked);
    }
  }

  Future<void> _pickNextServiceDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextServiceDate ?? _serviceDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
    );
    if (picked != null) {
      setState(() => _nextServiceDate = picked);
    }
  }

  Future<void> _save() async {
    final type = _typeController.text.trim();
    final description = _descriptionController.text.trim();
    if (type.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega tipo y descripción.')),
      );
      return;
    }

    final repository = ref.read(maintenanceRepositoryProvider);
    final record = widget.record;
    final costPesos = _optionalInt(_costController.text);
    if (record == null) {
      await repository.create(
        vehicleId: widget.vehicleId,
        serviceDate: _serviceDate,
        type: type,
        description: description,
        odometer: _optionalInt(_odometerController.text),
        costCents: costPesos == null ? null : costPesos * 100,
        nextServiceDate: _nextServiceDate,
        nextOdometer: _optionalInt(_nextOdometerController.text),
      );
    } else {
      await repository.edit(
        id: record.id,
        serviceDate: _serviceDate,
        type: type,
        description: description,
        odometer: _optionalInt(_odometerController.text),
        costCents: costPesos == null ? null : costPesos * 100,
        nextServiceDate: _nextServiceDate,
        nextOdometer: _optionalInt(_nextOdometerController.text),
      );
    }
    ref.invalidate(maintenanceRecordsProvider(widget.vehicleId));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _MaintenanceError extends StatelessWidget {
  const _MaintenanceError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('maintenance-error'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(
          'No pudimos cargar los mantenimientos.',
          style: AppTextStyles.body.copyWith(color: AppColors.red),
        ),
      ),
    );
  }
}

int? _optionalInt(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : int.parse(trimmed);
}

String _formatDate(DateTime date) {
  const months = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i += 1) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

String _formatCurrency(int cents) {
  final pesos = cents ~/ 100;
  return '\$${_formatNumber(pesos)}';
}
