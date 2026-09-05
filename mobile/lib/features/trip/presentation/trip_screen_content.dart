import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../application/trip_services.dart';
import '../data/trip_municipality_catalog.dart';
import '../domain/trip_draft.dart';

class TripContent extends StatelessWidget {
  const TripContent({
    required this.formKey,
    required this.originController,
    required this.destinationController,
    required this.selectedDate,
    required this.completedChecklist,
    required this.vehicles,
    required this.selectedVehicle,
    required this.restoredVehicleMissing,
    required this.originSuggestions,
    required this.destinationSuggestions,
    required this.originRestriction,
    required this.destinationRestriction,
    required this.draftRestored,
    required this.onVehicleChanged,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onOriginSelected,
    required this.onDestinationSelected,
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
  final List<VehicleProfile> vehicles;
  final VehicleProfile? selectedVehicle;
  final bool restoredVehicleMissing;
  final List<TripMunicipality> originSuggestions;
  final List<TripMunicipality> destinationSuggestions;
  final AsyncValue<TripEndpointRestriction> originRestriction;
  final AsyncValue<TripEndpointRestriction> destinationRestriction;
  final bool draftRestored;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<TripMunicipality> onOriginSelected;
  final ValueChanged<TripMunicipality> onDestinationSelected;
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
                  Text(
                    'PicoRadar no calcula rutas, ETA ni peajes en esta versión.',
                    key: const ValueKey('trip-local-limits-copy'),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _VehicleCard(
                    vehicles: vehicles,
                    vehicle: selectedVehicle,
                    restoredVehicleMissing: restoredVehicleMissing,
                    onChanged: onVehicleChanged,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _TripFields(
                    originController: originController,
                    destinationController: destinationController,
                    selectedDate: selectedDate,
                    originSuggestions: originSuggestions,
                    destinationSuggestions: destinationSuggestions,
                    onOriginChanged: onOriginChanged,
                    onDestinationChanged: onDestinationChanged,
                    onOriginSelected: onOriginSelected,
                    onDestinationSelected: onDestinationSelected,
                    onDateChanged: onDateChanged,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _RestrictionSummary(
                    date: selectedDate,
                    origin: originRestriction,
                    destination: destinationRestriction,
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
  const _VehicleCard({
    required this.vehicles,
    required this.vehicle,
    required this.restoredVehicleMissing,
    required this.onChanged,
  });

  final List<VehicleProfile> vehicles;
  final VehicleProfile? vehicle;
  final bool restoredVehicleMissing;
  final ValueChanged<String> onChanged;

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
                Text(
                  'Vehículo para este viaje',
                  style: AppTextStyles.bodyStrong,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  restoredVehicleMissing
                      ? 'El vehículo del borrador ya no está disponible.'
                      : current == null
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
          const SizedBox(width: AppSpacing.s),
          IconButton.outlined(
            key: const ValueKey('trip-select-vehicle'),
            tooltip: 'Elegir vehículo para este viaje',
            onPressed: vehicles.isEmpty
                ? null
                : () => _showVehicleSelector(context),
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
    );
  }

  Future<void> _showVehicleSelector(BuildContext context) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in vehicles)
              ListTile(
                title: Text('${_vehicleType(item)} · ${item.plate}'),
                selected: item.id == vehicle?.id,
                onTap: () => Navigator.of(context).pop(item.id),
              ),
          ],
        ),
      ),
    );
    if (selectedId != null) {
      onChanged(selectedId);
    }
  }
}

class _TripFields extends StatelessWidget {
  const _TripFields({
    required this.originController,
    required this.destinationController,
    required this.selectedDate,
    required this.originSuggestions,
    required this.destinationSuggestions,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onOriginSelected,
    required this.onDestinationSelected,
    required this.onDateChanged,
  });

  final TextEditingController originController;
  final TextEditingController destinationController;
  final DateTime selectedDate;
  final List<TripMunicipality> originSuggestions;
  final List<TripMunicipality> destinationSuggestions;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<TripMunicipality> onOriginSelected;
  final ValueChanged<TripMunicipality> onDestinationSelected;
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
            onChanged: onOriginChanged,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Origen',
              prefixIcon: Icon(Icons.trip_origin),
            ),
            validator: _requiredField('Ingresa el origen.'),
          ),
          _MunicipalitySuggestions(
            field: 'origin',
            suggestions: originSuggestions,
            onSelected: onOriginSelected,
          ),
          const SizedBox(height: AppSpacing.m),
          TextFormField(
            key: const ValueKey('trip-destination-field'),
            controller: destinationController,
            onChanged: onDestinationChanged,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Destino',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: _requiredField('Ingresa el destino.'),
          ),
          _MunicipalitySuggestions(
            field: 'destination',
            suggestions: destinationSuggestions,
            onSelected: onDestinationSelected,
          ),
          const SizedBox(height: AppSpacing.m),
          OutlinedButton.icon(
            key: const ValueKey('trip-date-button'),
            onPressed: () async {
              final range = _datePickerRange(selectedDate);
              final selected = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: range.firstDate,
                lastDate: range.lastDate,
              );
              if (!context.mounted) {
                return;
              }
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

class _MunicipalitySuggestions extends StatelessWidget {
  const _MunicipalitySuggestions({
    required this.field,
    required this.suggestions,
    required this.onSelected,
  });

  final String field;
  final List<TripMunicipality> suggestions;
  final ValueChanged<TripMunicipality> onSelected;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      key: ValueKey('trip-$field-suggestions'),
      children: [
        const SizedBox(height: AppSpacing.xs),
        for (final municipality in suggestions)
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(municipality.displayName),
              onTap: () => onSelected(municipality),
            ),
          ),
      ],
    );
  }
}

class _RestrictionSummary extends StatelessWidget {
  const _RestrictionSummary({
    required this.date,
    required this.origin,
    required this.destination,
  });

  final DateTime date;
  final AsyncValue<TripEndpointRestriction> origin;
  final AsyncValue<TripEndpointRestriction> destination;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pico y placa', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.s),
          _RestrictionEndpoint(label: 'Origen', date: date, evaluation: origin),
          const SizedBox(height: AppSpacing.m),
          _RestrictionEndpoint(
            label: 'Destino',
            date: date,
            evaluation: destination,
          ),
        ],
      ),
    );
  }
}

class _RestrictionEndpoint extends StatelessWidget {
  const _RestrictionEndpoint({
    required this.label,
    required this.date,
    required this.evaluation,
  });

  final String label;
  final DateTime date;
  final AsyncValue<TripEndpointRestriction> evaluation;

  @override
  Widget build(BuildContext context) {
    return evaluation.when(
      loading: () => Text('$label · Consultando'),
      error: (error, stackTrace) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · Sin información vigente'),
          const Text('Fuente de reglas no disponible.'),
          Text('Consultado para ${_formatDate(date)}'),
        ],
      ),
      data: (result) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · ${_restrictionLabel(result.status)}'),
          Text(result.sourceUrl ?? 'Fuente de reglas no disponible.'),
          Text('Consultado para ${_formatDate(date)}'),
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

_TripDatePickerRange _datePickerRange(DateTime selectedDate) {
  final currentYear = DateTime.now().year;
  final selectedYear = selectedDate.year;
  final firstYear = selectedYear < currentYear ? selectedYear : currentYear;
  final lastYear = selectedYear > currentYear + 10
      ? selectedYear
      : currentYear + 10;
  return _TripDatePickerRange(
    firstDate: DateTime(firstYear),
    lastDate: DateTime(lastYear, 12, 31),
  );
}

class _TripDatePickerRange {
  const _TripDatePickerRange({required this.firstDate, required this.lastDate});

  final DateTime firstDate;
  final DateTime lastDate;
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

String _restrictionLabel(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.allowed => 'Sin restricción para ese día',
    RestrictionDayStatus.restricted => 'No circula',
    RestrictionDayStatus.unknown => 'Sin información vigente',
    RestrictionDayStatus.stale => 'Información desactualizada',
  };
}
