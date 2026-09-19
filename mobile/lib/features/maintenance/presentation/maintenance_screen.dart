import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../location/application/location_controller.dart';
import '../../location/platform/device_location_gateway.dart';
import '../../onboarding/data/registration_city_catalog.dart';
import '../../services/data/google_maps_service_search.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../data/maintenance_record.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({required this.vehicleId, super.key});

  final String? vehicleId;

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  String? _selectedVehicleId;
  var _findingWorkshop = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.vehicleId?.trim();
    _selectedVehicleId = initial == null || initial.isEmpty ? null : initial;
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider);
    final availableVehicles =
        vehicles.asData?.value ?? const <VehicleProfile>[];
    final selectedVehicleId = _resolveVehicleId(availableVehicles);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talleres'),
        actions: [
          IconButton(
            key: const ValueKey('maintenance-find-workshop'),
            tooltip: 'Buscar taller cerca de mí',
            onPressed: _findingWorkshop ? null : _findWorkshop,
            icon: _findingWorkshop
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.near_me_outlined),
          ),
        ],
      ),
      floatingActionButton: selectedVehicleId == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('maintenance-add'),
              onPressed: () => _openEditor(context, ref, selectedVehicleId),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            ),
      body: SafeArea(
        child: vehicles.when(
          data: (items) {
            final effectiveVehicleId = _resolveVehicleId(items);
            if (effectiveVehicleId == null) {
              return const _MissingMaintenanceVehicleState();
            }
            final selectedVehicle = items.firstWhere(
              (vehicle) => vehicle.id == effectiveVehicleId,
            );
            final records = ref.watch(
              maintenanceRecordsProvider(effectiveVehicleId),
            );
            return records.when(
              data: (records) => Column(
                children: [
                  _MaintenanceHeader(
                    vehicles: items,
                    selectedVehicle: selectedVehicle,
                    records: records,
                    onVehicleSelected: (vehicleId) {
                      setState(() => _selectedVehicleId = vehicleId);
                    },
                    onFindWorkshop: _findingWorkshop ? null : _findWorkshop,
                  ),
                  Expanded(
                    child: _MaintenanceList(
                      records: records,
                      onEdit: (record) => _openEditor(
                        context,
                        ref,
                        effectiveVehicleId,
                        record: record,
                      ),
                      onDelete: (record) => _deleteRecord(
                        context,
                        ref,
                        effectiveVehicleId,
                        record,
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _MaintenanceError(
                error: error,
                onRetry: () => ref.invalidate(
                  maintenanceRecordsProvider(effectiveVehicleId),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _MaintenanceError(
            error: error,
            onRetry: () => ref.invalidate(vehicleListProvider),
          ),
        ),
      ),
    );
  }

  String? _resolveVehicleId(List<VehicleProfile> vehicles) {
    if (vehicles.isEmpty) return null;
    final selected = _selectedVehicleId;
    if (selected != null && vehicles.any((vehicle) => vehicle.id == selected)) {
      return selected;
    }
    final explicit = widget.vehicleId?.trim();
    if (explicit != null &&
        explicit.isNotEmpty &&
        vehicles.any((vehicle) => vehicle.id == explicit)) {
      return explicit;
    }
    if (explicit != null && explicit.isNotEmpty) return null;
    return vehicles.first.id;
  }

  Future<void> _findWorkshop() async {
    if (_findingWorkshop) return;
    setState(() => _findingWorkshop = true);
    try {
      final gateway = ref.read(deviceLocationGatewayProvider);
      if (!await gateway.isLocationServiceEnabled()) {
        await _recoverWorkshopSearch(DeviceLocationFailure.serviceDisabled);
        return;
      }
      var permission = await gateway.checkPermission();
      if (permission == DeviceLocationPermission.denied ||
          permission == DeviceLocationPermission.notRequested) {
        permission = await gateway.requestPermission();
      }
      if (permission != DeviceLocationPermission.granted) {
        await _recoverWorkshopSearch(
          permission == DeviceLocationPermission.deniedForever
              ? DeviceLocationFailure.permissionDeniedForever
              : DeviceLocationFailure.permissionDenied,
        );
        return;
      }
      final result = await gateway.getCurrentPosition();
      if (!mounted) return;
      if (result case DeviceLocationSuccess(:final point)
          when _validLocation(point)) {
        await _openWorkshopUri(
          googleMapsNearbyServiceSearchUri(
            category: GoogleMapsServiceCategory.mechanic,
            latitude: point.latitude,
            longitude: point.longitude,
          ),
        );
      } else {
        await _recoverWorkshopSearch(DeviceLocationFailure.positionUnavailable);
      }
    } catch (_) {
      if (mounted) {
        await _recoverWorkshopSearch(DeviceLocationFailure.positionUnavailable);
      }
    } finally {
      if (mounted) setState(() => _findingWorkshop = false);
    }
  }

  bool _validLocation(DeviceLocationPoint point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.accuracyMeters.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;

  Future<void> _recoverWorkshopSearch(DeviceLocationFailure failure) async {
    if (!mounted) return;
    final choice = await showModalBottomSheet<_WorkshopRecoveryChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => _WorkshopRecoverySheet(failure: failure),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _WorkshopRecoveryChoice.retry:
        if (mounted) setState(() => _findingWorkshop = false);
        await _findWorkshop();
        return;
      case _WorkshopRecoveryChoice.settings:
        final gateway = ref.read(deviceLocationGatewayProvider);
        if (failure == DeviceLocationFailure.serviceDisabled) {
          await gateway.openLocationSettings();
        } else {
          await gateway.openAppSettings();
        }
        return;
      case _WorkshopRecoveryChoice.city:
        final catalog = await ref.read(registrationCityCatalogProvider.future);
        if (!mounted) return;
        final city = await showModalBottomSheet<RegistrationCity>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => _MaintenanceCitySheet(catalog: catalog),
        );
        if (city != null) {
          await _openWorkshopUri(
            googleMapsCityServiceSearchUri(
              category: GoogleMapsServiceCategory.mechanic,
              city: city.displayName,
            ),
          );
        }
        return;
    }
  }

  Future<void> _openWorkshopUri(Uri uri) async {
    final opened = await ref
        .read(externalLauncherProvider)
        .openExternal(uri.toString());
    if (mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir Google Maps.')),
      );
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    String vehicleId, {
    MaintenanceRecord? record,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (context) {
        return _MaintenanceEditorSheet(vehicleId: vehicleId, record: record);
      },
    );
    if (!context.mounted) {
      return;
    }
    if (saved == true) {
      ref.invalidate(maintenanceRecordsProvider(vehicleId));
      ref.invalidate(maintenanceNotificationSyncProvider);
    }
  }

  Future<void> _deleteRecord(
    BuildContext context,
    WidgetRef ref,
    String vehicleId,
    MaintenanceRecord record,
  ) async {
    final repository = ref.read(maintenanceRepositoryProvider);
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
    if (!context.mounted) {
      return;
    }
    try {
      await repository.delete(record.id);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos eliminar el mantenimiento. Intenta de nuevo.',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    ref.invalidate(maintenanceRecordsProvider(vehicleId));
    ref.invalidate(maintenanceNotificationSyncProvider);
  }
}

class _MaintenanceHeader extends StatelessWidget {
  const _MaintenanceHeader({
    required this.vehicles,
    required this.selectedVehicle,
    required this.records,
    required this.onVehicleSelected,
    required this.onFindWorkshop,
  });

  final List<VehicleProfile> vehicles;
  final VehicleProfile selectedVehicle;
  final List<MaintenanceRecord> records;
  final ValueChanged<String> onVehicleSelected;
  final VoidCallback? onFindWorkshop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PopupMenuButton<String>(
            key: const ValueKey('maintenance-vehicle-selector'),
            onSelected: onVehicleSelected,
            itemBuilder: (context) => [
              for (final vehicle in vehicles)
                PopupMenuItem(
                  value: vehicle.id,
                  child: Text(_vehicleLabel(vehicle)),
                ),
            ],
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Vehículo',
                prefixIcon: Icon(Icons.directions_car_outlined),
                suffixIcon: Icon(Icons.expand_more),
              ),
              child: Text(
                _vehicleLabel(selectedVehicle),
                style: AppTextStyles.bodyStrong,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          _MaintenanceSummary(records: records),
          const SizedBox(height: AppSpacing.s),
          OutlinedButton.icon(
            key: const ValueKey('maintenance-find-workshop-inline'),
            onPressed: onFindWorkshop,
            icon: const Icon(Icons.near_me_outlined),
            label: const Text('Buscar taller mecánico cerca de mí'),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceSummary extends StatelessWidget {
  const _MaintenanceSummary({required this.records});

  final List<MaintenanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final totalCents = records.fold<int>(
      0,
      (total, record) => total + (record.costCents ?? 0),
    );
    final latestOdometer = records
        .map((record) => record.odometer)
        .whereType<int>()
        .fold<int?>(null, (latest, value) {
          if (latest == null || value > latest) return value;
          return latest;
        });
    final today = DateTime.now();
    final overdue = records.where((record) {
      final dateDue =
          record.nextServiceDate != null &&
          record.nextServiceDate!.isBefore(
            DateTime(today.year, today.month, today.day),
          );
      final distanceDue =
          latestOdometer != null &&
          record.nextOdometer != null &&
          latestOdometer >= record.nextOdometer!;
      return dateDue || distanceDue;
    }).length;
    return Semantics(
      container: true,
      label:
          '${records.length} mantenimientos, $overdue vencidos, costo ${_formatCurrency(totalCents)}',
      child: DecoratedBox(
        key: const ValueKey('maintenance-summary'),
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  value: '${records.length}',
                  label: 'Servicios',
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  value: '$overdue',
                  label: 'Vencidos',
                  alert: overdue > 0,
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  value: 'Total ${_formatCurrency(totalCents)}',
                  label: 'Invertido',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.value,
    required this.label,
    this.alert = false,
  });

  final String value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.red : AppColors.navy;
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyStrong.copyWith(color: color),
        ),
        Text(label, style: AppTextStyles.caption.copyWith(color: color)),
      ],
    );
  }
}

String _vehicleLabel(VehicleProfile vehicle) {
  final nickname = vehicle.nickname?.trim();
  if (nickname != null && nickname.isNotEmpty) {
    return '$nickname · ${vehicle.plate}';
  }
  return vehicle.plate;
}

class _MissingMaintenanceVehicleState extends StatelessWidget {
  const _MissingMaintenanceVehicleState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('maintenance-missing-vehicle'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        96,
      ),
      children: [
        DecoratedBox(
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
                Text('Talleres y mantenimiento', style: AppTextStyles.h2),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Elige un vehículo del Garaje para registrar servicios y próximos mantenimientos.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                FilledButton(
                  key: const ValueKey('maintenance-go-garage'),
                  onPressed: () => context.go('/garage'),
                  child: const Text('Ir a Garaje'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                              if (MediaQuery.textScalerOf(context).scale(14) >
                                  14)
                                Text(detail)
                              else
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
  var _saving = false;

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
              onPressed: _saving ? null : () => _pickServiceDate(context),
              icon: const Icon(Icons.calendar_month),
              label: Text('Fecha: ${_formatDate(_serviceDate)}'),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('maintenance-type-field'),
              controller: _typeController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Tipo',
                hintText: 'Cambio de aceite',
                suffixIcon: PopupMenuButton<String>(
                  key: const ValueKey('maintenance-category-menu'),
                  tooltip: 'Elegir categoría',
                  icon: const Icon(Icons.expand_more),
                  onSelected: (category) {
                    _typeController.text = category;
                    setState(() {});
                  },
                  itemBuilder: (context) => [
                    for (final category in const [
                      'Aceite y filtros',
                      'Frenos',
                      'Llantas',
                      'Batería',
                      'Revisión general',
                    ])
                      PopupMenuItem(value: category, child: Text(category)),
                  ],
                ),
              ),
            ),
            if (_nextServiceDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('maintenance-clear-next-date'),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _nextServiceDate = null),
                  icon: const Icon(Icons.close),
                  label: const Text('Quitar próxima fecha'),
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
              onPressed: _saving ? null : () => _pickNextServiceDate(context),
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
              decoration: InputDecoration(
                labelText: 'Próximo kilometraje',
                suffixIcon: IconButton(
                  key: const ValueKey('maintenance-clear-next-odometer'),
                  tooltip: 'Quitar próximo kilometraje',
                  onPressed: _saving
                      ? null
                      : () => _nextOdometerController.clear(),
                  icon: const Icon(Icons.close),
                ),
              ),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton.icon(
              key: const ValueKey('maintenance-save'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Guardando' : 'Guardar'),
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
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
    if (picked != null) {
      setState(() => _nextServiceDate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
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
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _saving = true);
    try {
      final odometer = _optionalInt(_odometerController.text);
      final costPesos = _optionalInt(_costController.text);
      final nextOdometer = _optionalInt(_nextOdometerController.text);
      if (record == null) {
        await repository.create(
          vehicleId: widget.vehicleId,
          serviceDate: _serviceDate,
          type: type,
          description: description,
          odometer: odometer,
          costCents: costPesos == null ? null : costPesos * 100,
          nextServiceDate: _nextServiceDate,
          nextOdometer: nextOdometer,
        );
      } else {
        await repository.edit(
          id: record.id,
          serviceDate: _serviceDate,
          type: type,
          description: description,
          odometer: odometer,
          costCents: costPesos == null ? null : costPesos * 100,
          nextServiceDate: _nextServiceDate,
          nextOdometer: nextOdometer,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos guardar el mantenimiento. Intenta de nuevo.',
          ),
        ),
      );
      return;
    }
    final recordsProvider = maintenanceRecordsProvider(widget.vehicleId);
    if (container.exists(recordsProvider)) {
      container.invalidate(recordsProvider);
    }
    container.invalidate(maintenanceNotificationSyncProvider);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }
}

enum _WorkshopRecoveryChoice { retry, settings, city }

class _WorkshopRecoverySheet extends StatelessWidget {
  const _WorkshopRecoverySheet({required this.failure});

  final DeviceLocationFailure failure;

  @override
  Widget build(BuildContext context) {
    final title = switch (failure) {
      DeviceLocationFailure.serviceDisabled => 'GPS apagado',
      DeviceLocationFailure.permissionDenied ||
      DeviceLocationFailure.permissionDeniedForever =>
        'Ubicación no disponible',
      DeviceLocationFailure.positionUnavailable => 'Sin señal GPS',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            const Text(
              'Puedes reintentar, abrir los ajustes o elegir una ciudad del catálogo local.',
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _WorkshopRecoveryChoice.retry),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _WorkshopRecoveryChoice.city),
              icon: const Icon(Icons.location_city_outlined),
              label: const Text('Elegir ciudad'),
            ),
            TextButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _WorkshopRecoveryChoice.settings),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Abrir ajustes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCitySheet extends StatefulWidget {
  const _MaintenanceCitySheet({required this.catalog});

  final RegistrationCityCatalog catalog;

  @override
  State<_MaintenanceCitySheet> createState() => _MaintenanceCitySheetState();
}

class _MaintenanceCitySheetState extends State<_MaintenanceCitySheet> {
  final _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_refresh);
  }

  @override
  void dispose() {
    _queryController.removeListener(_refresh);
    _queryController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final results = widget.catalog.search(_queryController.text, limit: 40);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Elegir ciudad', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('maintenance-city-search'),
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar municipio o departamento',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final city in results)
                    ListTile(
                      title: Text(city.displayName),
                      onTap: () => Navigator.pop(context, city),
                    ),
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                      child: Text('Sin resultados en el catálogo local.'),
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

class _MaintenanceError extends StatelessWidget {
  const _MaintenanceError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('maintenance-error'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No pudimos cargar los mantenimientos.',
              style: AppTextStyles.body.copyWith(color: AppColors.red),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
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
