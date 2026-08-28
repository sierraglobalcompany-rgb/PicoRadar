import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../vehicle_status/data/vehicle_status_catalog.dart';
import '../../vehicle_status/domain/vehicle_obligation.dart';
import '../../vehicle_status/platform/obligation_notifications.dart';
import '../data/vehicle_profile.dart';
import 'vehicle_display.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);

    return SafeArea(
      child: vehicles.when(
        data: (items) {
          final vehicle = _findVehicle(items, vehicleId);
          if (vehicle == null) {
            return _MissingVehicle(onBack: () => context.go('/garage'));
          }

          return _VehicleDetail(
            vehicle: vehicle,
            active: active.asData?.value?.id == vehicle.id,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(error.toString()),
          );
        },
      ),
    );
  }

  VehicleProfile? _findVehicle(List<VehicleProfile> vehicles, String id) {
    for (final vehicle in vehicles) {
      if (vehicle.id == id) {
        return vehicle;
      }
    }
    return null;
  }
}

class _VehicleDetail extends ConsumerWidget {
  const _VehicleDetail({required this.vehicle, required this.active});

  final VehicleProfile vehicle;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = vehicleAccent(vehicle);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del vehículo'),
        leading: IconButton(
          onPressed: () => context.go('/garage'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(vehicleIcon(vehicle), color: accent, size: 48),
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
                            Text(active ? 'Activo' : 'No activo'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _DetailField(
                    label: 'Ciudad',
                    value: vehicle.registrationCity,
                  ),
                  _DetailField(label: 'Apodo', value: vehicle.nickname),
                  _DetailField(
                    label: 'Marca / modelo',
                    value: vehicleMakeModel(vehicle),
                  ),
                  _DetailField(
                    label: 'Año',
                    value: vehicle.year == null ? null : '${vehicle.year}',
                  ),
                  _DetailField(label: 'Color', value: vehicle.color),
                  const SizedBox(height: AppSpacing.l),
                  Wrap(
                    spacing: AppSpacing.m,
                    runSpacing: AppSpacing.m,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('detail-make-active'),
                        onPressed: active
                            ? null
                            : () async {
                                await ref
                                    .read(vehicleRepositoryProvider)
                                    .setActiveVehicle(vehicle.id);
                                ref.invalidate(activeVehicleProvider);
                                ref.invalidate(vehicleListProvider);
                              },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Hacer activo'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('detail-edit-vehicle'),
                        onPressed: () =>
                            context.push('/garage/vehicle/${vehicle.id}/edit'),
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('detail-delete-vehicle'),
                        onPressed: () => _confirmDelete(context, ref),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _StatusCard(
                    title: 'Pico y Placa',
                    status: 'Pendiente de activar datos de movilidad',
                    icon: Icons.traffic,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _VehicleStatusSummaryCards(vehicle: vehicle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Eliminar este vehículo?'),
          content: Text(vehicle.plate),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('confirm-delete-vehicle'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final repository = ref.read(vehicleRepositoryProvider);
    final activeBeforeDelete = await repository.getActiveVehicle();
    final wasActive = activeBeforeDelete?.id == vehicle.id;
    await repository.deleteVehicle(vehicle.id);

    if (wasActive) {
      final remaining = await repository.listVehicles();
      if (remaining.isNotEmpty) {
        await repository.setActiveVehicle(remaining.first.id);
      } else {
        await repository.clearActiveVehicle();
      }
    }

    ref.invalidate(activeVehicleProvider);
    ref.invalidate(vehicleListProvider);
    ref.invalidate(obligationNotificationSyncProvider);
    if (context.mounted) {
      context.go('/garage');
    }
  }
}

class _VehicleStatusSummaryCards extends ConsumerWidget {
  const _VehicleStatusSummaryCards({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligations = ref.watch(vehicleObligationsProvider(vehicle.id));
    final nowBogota = ref.watch(bogotaNowProvider);
    return obligations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Text(error.toString()),
      data: (items) {
        final byType = {for (final item in items) item.type: item};
        return Column(
          children: [
            _StatusCard(
              key: const ValueKey('detail-status-soat'),
              title: 'SOAT',
              status: _summary(
                VehicleObligationType.soat,
                byType[VehicleObligationType.soat],
                nowBogota,
              ),
              icon: Icons.assignment_outlined,
              onTap: () => _open(context, VehicleObligationType.soat),
            ),
            const SizedBox(height: AppSpacing.m),
            _StatusCard(
              key: const ValueKey('detail-status-rtm'),
              title: 'Tecnomecánica',
              status: _summary(
                VehicleObligationType.rtm,
                byType[VehicleObligationType.rtm],
                nowBogota,
              ),
              icon: Icons.build_outlined,
              onTap: () => _open(context, VehicleObligationType.rtm),
            ),
            const SizedBox(height: AppSpacing.m),
            _StatusCard(
              key: const ValueKey('detail-status-insurance'),
              title: 'Seguro',
              status: _summary(
                VehicleObligationType.insurance,
                byType[VehicleObligationType.insurance],
                nowBogota,
              ),
              icon: Icons.health_and_safety_outlined,
              onTap: () => _open(context, VehicleObligationType.insurance),
            ),
            const SizedBox(height: AppSpacing.m),
            _StatusCard(
              key: const ValueKey('detail-status-tax'),
              title: 'Impuestos',
              status: _taxSummary(byType[VehicleObligationType.tax]),
              icon: Icons.account_balance_outlined,
              onTap: () => _open(context, VehicleObligationType.tax),
            ),
          ],
        );
      },
    );
  }

  void _open(BuildContext context, VehicleObligationType type) {
    context.push('${obligationRouteForType(type)}?vehicleId=${vehicle.id}');
  }

  String _summary(
    VehicleObligationType type,
    VehicleObligation? obligation,
    DateTime nowBogota,
  ) {
    final state = evaluateVehicleObligationState(
      dueDate: obligation?.dueDate,
      nowBogota: nowBogota,
    );
    if (obligation?.dueDate != null &&
        (state == VehicleObligationState.valid ||
            state == VehicleObligationState.dueSoon)) {
      return 'Vence ${formatShortDate(obligation!.dueDate!)} · según fecha guardada';
    }
    return obligationStatusText(type, state);
  }

  String _taxSummary(VehicleObligation? obligation) {
    final calendar =
        taxCalendarByAuthority(obligation?.details['authorityId']) ??
        suggestTaxCalendar(vehicle.registrationCity);
    return calendar == null
        ? 'Calendario pendiente de actualización'
        : 'Consulta calendario oficial';
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(value!),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    super.key,
    required this.title,
    required this.status,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String status;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(status),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.s),
                  const Icon(Icons.chevron_right),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingVehicle extends StatelessWidget {
  const _MissingVehicle({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vehículo no encontrado'),
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              onPressed: onBack,
              child: const Text('Volver al Garaje'),
            ),
          ],
        ),
      ),
    );
  }
}
