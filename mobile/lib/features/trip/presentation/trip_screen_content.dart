import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../domain/trip_draft.dart';

class TripContent extends StatelessWidget {
  const TripContent({
    required this.formKey,
    required this.originController,
    required this.destinationController,
    required this.selectedDate,
    required this.completedChecklist,
    required this.activeVehicle,
    required this.draftRestored,
    required this.onDateChanged,
    required this.onChecklistChanged,
    required this.onSaveDraft,
    required this.onDeleteDraft,
    required this.onGoogleMaps,
    required this.onWaze,
    required this.onInvias,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final DateTime selectedDate;
  final Set<TripChecklistItem> completedChecklist;
  final VehicleProfile? activeVehicle;
  final bool draftRestored;
  final ValueChanged<DateTime> onDateChanged;
  final void Function(TripChecklistItem item, bool selected) onChecklistChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onDeleteDraft;
  final VoidCallback onGoogleMaps;
  final VoidCallback onWaze;
  final VoidCallback onInvias;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('trip-screen'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        96,
      ),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Planea tu viaje', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'PicoRadar no calcula rutas, ETA ni peajes en esta versión.',
                    key: const ValueKey('trip-local-limits-copy'),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _VehicleCard(vehicle: activeVehicle),
                  const SizedBox(height: AppSpacing.l),
                  _TripFields(
                    originController: originController,
                    destinationController: destinationController,
                    selectedDate: selectedDate,
                    onDateChanged: onDateChanged,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _ChecklistCard(
                    completedChecklist: completedChecklist,
                    onChanged: onChecklistChanged,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _ExternalNotice(draftRestored: draftRestored),
                  const SizedBox(height: AppSpacing.l),
                  FilledButton.icon(
                    key: const ValueKey('trip-open-google-maps'),
                    onPressed: onGoogleMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Abrir Google Maps'),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  OutlinedButton.icon(
                    key: const ValueKey('trip-open-waze'),
                    onPressed: onWaze,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Abrir Waze'),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  OutlinedButton.icon(
                    key: const ValueKey('trip-open-invias'),
                    onPressed: onInvias,
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Consultar estado vial en INVÍAS'),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          key: const ValueKey('trip-save-draft'),
                          onPressed: onSaveDraft,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar borrador'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      IconButton.outlined(
                        key: const ValueKey('trip-delete-draft'),
                        tooltip: 'Borrar borrador',
                        onPressed: onDeleteDraft,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final VehicleProfile? vehicle;

  @override
  Widget build(BuildContext context) {
    final current = vehicle;
    return _Card(
      child: Row(
        children: [
          Icon(
            current == null
                ? Icons.directions_car_outlined
                : vehicleIcon(current),
            size: AppIconSize.l,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vehículo activo', style: AppTextStyles.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  current == null
                      ? 'Opcional para este borrador.'
                      : '${_vehicleType(current)} · ${current.plate}',
                  key: const ValueKey('trip-active-vehicle'),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripFields extends StatelessWidget {
  const _TripFields({
    required this.originController,
    required this.destinationController,
    required this.selectedDate,
    required this.onDateChanged,
  });

  final TextEditingController originController;
  final TextEditingController destinationController;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('trip-origin-field'),
            controller: originController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Origen',
              prefixIcon: Icon(Icons.trip_origin),
            ),
            validator: _requiredField('Ingresa el origen.'),
          ),
          const SizedBox(height: AppSpacing.m),
          TextFormField(
            key: const ValueKey('trip-destination-field'),
            controller: destinationController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Destino',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: _requiredField('Ingresa el destino.'),
          ),
          const SizedBox(height: AppSpacing.m),
          OutlinedButton.icon(
            key: const ValueKey('trip-date-button'),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2026),
                lastDate: DateTime(2035, 12, 31),
              );
              if (selected != null) {
                onDateChanged(DateUtils.dateOnly(selected));
              }
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('Fecha · ${_formatDate(selectedDate)}'),
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.completedChecklist,
    required this.onChanged,
  });

  final Set<TripChecklistItem> completedChecklist;
  final void Function(TripChecklistItem item, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Checklist temporal', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.s),
          for (final item in TripChecklistItem.values)
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                key: ValueKey('trip-checklist-${item.key}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(item.label),
                value: completedChecklist.contains(item),
                onChanged: (value) => onChanged(item, value ?? false),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExternalNotice extends StatelessWidget {
  const _ExternalNotice({required this.draftRestored});

  final bool draftRestored;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La navegación y el estado vial se consultan en servicios externos.',
              key: const ValueKey('trip-external-services-copy'),
              style: AppTextStyles.body,
            ),
            if (draftRestored) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                'Borrador local restaurado.',
                key: const ValueKey('trip-draft-restored'),
                style: AppTextStyles.caption.copyWith(color: AppColors.teal),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.l), child: child),
    );
  }
}

FormFieldValidator<String> _requiredField(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  };
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _vehicleType(VehicleProfile vehicle) {
  if (vehicle.kind == VehicleKind.motorcycle) {
    return 'Moto';
  }
  return switch (vehicle.serviceType) {
    VehicleServiceType.taxi => 'Taxi',
    VehicleServiceType.private => 'Particular',
  };
}
