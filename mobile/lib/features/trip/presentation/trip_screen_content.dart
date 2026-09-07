import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/shell/picoradar_app_header.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../../home/presentation/pico_notification_sheet.dart';
import '../application/trip_services.dart';
import '../data/trip_municipality_catalog.dart';
import '../domain/trip_draft.dart';

class TripContent extends ConsumerWidget {
  const TripContent({
    required this.scrollController,
    required this.resultsAnchorKey,
    required this.resultsFocusNode,
    required this.originFocusNode,
    required this.destinationFocusNode,
    required this.vehicleFocusNode,
    required this.timeFocusNode,
    required this.onUserScroll,
    required this.formKey,
    required this.originController,
    required this.destinationController,
    required this.selectedDate,
    required this.departureMinute,
    required this.originError,
    required this.destinationError,
    required this.timeError,
    required this.vehicleError,
    required this.vehicleConfiguration,
    required this.onVehicleConfigurationChanged,
    required this.onTimeChanged,
    required this.isPlanning,
    required this.planError,
    required this.onPreview,
    required this.onCancelPreview,
    required this.planResult,
    required this.instantRestrictions,
    required this.completedChecklist,
    required this.vehicles,
    required this.selectedVehicle,
    required this.restoredVehicleMissing,
    required this.originSuggestions,
    required this.destinationSuggestions,
    required this.originRestriction,
    required this.destinationRestriction,
    required this.draftRestored,
    required this.localConsultationStarted,
    required this.localDepartureLabel,
    required this.onVehicleChanged,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onOriginSelected,
    required this.onDestinationSelected,
    required this.onSwapLocations,
    required this.onDateChanged,
    required this.onChecklistChanged,
    required this.onSaveDraft,
    required this.onDeleteDraft,
    required this.onGoogleMaps,
    required this.onWaze,
    required this.onInvias,
    super.key,
  });

  final ScrollController scrollController;
  final GlobalKey resultsAnchorKey;
  final FocusNode resultsFocusNode;
  final FocusNode originFocusNode;
  final FocusNode destinationFocusNode;
  final FocusNode vehicleFocusNode;
  final FocusNode timeFocusNode;
  final VoidCallback onUserScroll;
  final GlobalKey<FormState> formKey;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final DateTime selectedDate;
  final int? departureMinute;
  final String? originError;
  final String? destinationError;
  final String? timeError;
  final String? vehicleError;
  final TripVehicleConfiguration vehicleConfiguration;
  final ValueChanged<TripVehicleConfiguration> onVehicleConfigurationChanged;
  final ValueChanged<int?> onTimeChanged;
  final bool isPlanning;
  final String? planError;
  final VoidCallback onPreview;
  final VoidCallback onCancelPreview;
  final Widget? planResult;
  final Widget instantRestrictions;
  final Set<TripChecklistItem> completedChecklist;
  final List<VehicleProfile> vehicles;
  final VehicleProfile? selectedVehicle;
  final bool restoredVehicleMissing;
  final List<TripMunicipality> originSuggestions;
  final List<TripMunicipality> destinationSuggestions;
  final AsyncValue<TripEndpointRestriction> originRestriction;
  final AsyncValue<TripEndpointRestriction> destinationRestriction;
  final bool draftRestored;
  final bool localConsultationStarted;
  final String? localDepartureLabel;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<TripMunicipality> onOriginSelected;
  final ValueChanged<TripMunicipality> onDestinationSelected;
  final VoidCallback onSwapLocations;
  final ValueChanged<DateTime> onDateChanged;
  final void Function(TripChecklistItem item, bool selected) onChecklistChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onDeleteDraft;
  final VoidCallback onGoogleMaps;
  final VoidCallback onWaze;
  final VoidCallback onInvias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPlan = planResult != null;
    final endpointSummary =
        '${originController.text.trim().isEmpty ? 'Origen pendiente' : originController.text.trim()} → '
        '${destinationController.text.trim().isEmpty ? 'Destino pendiente' : destinationController.text.trim()}';
    final vehicleSummary = selectedVehicle == null
        ? 'Vehículo pendiente'
        : '${_vehicleType(selectedVehicle!)} · ${selectedVehicle!.plate}';
    final previewAction = Column(
      key: const ValueKey('trip-preview-action-group'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const ValueKey('trip-preview'),
          onPressed: isPlanning ? null : onPreview,
          icon: const Icon(Icons.route_outlined),
          label: Text(
            isPlanning ? 'Consultando plan de viaje' : 'Ver plan de viaje',
          ),
        ),
        if (isPlanning) ...[
          const SizedBox(height: AppSpacing.s),
          const LinearProgressIndicator(),
          TextButton.icon(
            key: const ValueKey('trip-cancel-preview'),
            onPressed: onCancelPreview,
            icon: const Icon(Icons.close),
            label: const Text('Cancelar consulta'),
          ),
        ],
        const SizedBox(height: AppSpacing.s),
        const Text(
          'Al consultar se envían municipios, salida y categoría al servicio de rutas. La placa permanece en este dispositivo.',
        ),
      ],
    );
    final preparation = _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TripFields(
            originController: originController,
            destinationController: destinationController,
            originFocusNode: originFocusNode,
            destinationFocusNode: destinationFocusNode,
            originError: originError,
            destinationError: destinationError,
            originSuggestions: originSuggestions,
            destinationSuggestions: destinationSuggestions,
            onOriginChanged: onOriginChanged,
            onDestinationChanged: onDestinationChanged,
            onOriginSelected: onOriginSelected,
            onDestinationSelected: onDestinationSelected,
            onSwapLocations: onSwapLocations,
          ),
          const SizedBox(height: AppSpacing.m),
          _TripDepartureGroup(
            selectedDate: selectedDate,
            departureMinute: departureMinute,
            timeFocusNode: timeFocusNode,
            timeError: timeError,
            onDateChanged: onDateChanged,
            onTimeChanged: onTimeChanged,
            vehicles: vehicles,
            vehicle: selectedVehicle,
            restoredVehicleMissing: restoredVehicleMissing,
            vehicleFocusNode: vehicleFocusNode,
            vehicleError: vehicleError,
            vehicleConfiguration: vehicleConfiguration,
            onVehicleChanged: onVehicleChanged,
            onVehicleConfigurationChanged: onVehicleConfigurationChanged,
          ),
        ],
      ),
    );
    final alerts =
        ref.watch(picoAlertPreferencesProvider).asData?.value ??
        const PicoAlertPreferences(
          enabled: true,
          dayBeforeEnabled: true,
          sameDayEnabled: true,
          dayBeforeMinute: 1140,
          sameDayMinute: 300,
          permissionRequested: false,
          permissionGranted: false,
        );

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) onUserScroll();
        return false;
      },
      child: ListView(
        controller: scrollController,
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
                    PicoRadarAppHeader(
                      alertPreferences: alerts,
                      onNotificationsPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (context) =>
                            PicoNotificationSheet(alertPreferences: alerts),
                      ),
                      headerKey: const ValueKey('trip-app-header'),
                      brandKey: const ValueKey('trip-brand-lockup'),
                      capsuleKey: const ValueKey('trip-user-controls-capsule'),
                      bellKey: const ValueKey('trip-notification-bell'),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text('Planea tu viaje', style: AppTextStyles.h1),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Compara rutas, peajes, cámaras y restricciones antes de salir.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.navy.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    if (hasPlan)
                      ExpansionTile(
                        key: const ValueKey('trip-preparation-compact'),
                        initiallyExpanded: false,
                        maintainState: false,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(
                          bottom: AppSpacing.s,
                        ),
                        title: Column(
                          key: const ValueKey('trip-preparation-summary'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preparación del viaje',
                              style: AppTextStyles.bodyStrong,
                            ),
                            Text(endpointSummary),
                            Text(vehicleSummary),
                          ],
                        ),
                        subtitle: const Text(
                          'Toca para editar sin perder tus datos',
                        ),
                        children: [preparation],
                      )
                    else
                      KeyedSubtree(
                        key: const ValueKey('trip-preparation-expanded'),
                        child: preparation,
                      ),
                    const SizedBox(height: AppSpacing.m),
                    previewAction,
                    if (planResult != null) ...[
                      const SizedBox(height: AppSpacing.l),
                      SizedBox(key: resultsAnchorKey),
                      Focus(
                        focusNode: resultsFocusNode,
                        child: Semantics(
                          liveRegion: true,
                          container: true,
                          child: planResult!,
                        ),
                      ),
                    ],
                    if (localConsultationStarted) ...[
                      const SizedBox(height: AppSpacing.l),
                      Text(
                        'Lo que ya podemos consultar',
                        style: AppTextStyles.h2,
                      ),
                      if (localDepartureLabel != null)
                        Text(localDepartureLabel!),
                      if (planError != null) ...[
                        const SizedBox(height: AppSpacing.m),
                        Semantics(
                          liveRegion: true,
                          child: _RoutesUnavailable(reason: planError!),
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.l),
                    Text('Pico y placa del viaje', style: AppTextStyles.h2),
                    const SizedBox(height: AppSpacing.m),
                    instantRestrictions,
                    const SizedBox(height: AppSpacing.l),
                    const Text(
                      'Vista previa por fecha, sin evaluar la hora de llegada.',
                    ),
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
                    OutlinedButton.icon(
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
      ),
    );
  }
}

class _TripDepartureGroup extends StatelessWidget {
  const _TripDepartureGroup({
    required this.selectedDate,
    required this.departureMinute,
    required this.timeFocusNode,
    required this.timeError,
    required this.onDateChanged,
    required this.onTimeChanged,
    required this.vehicles,
    required this.vehicle,
    required this.restoredVehicleMissing,
    required this.vehicleFocusNode,
    required this.vehicleError,
    required this.vehicleConfiguration,
    required this.onVehicleChanged,
    required this.onVehicleConfigurationChanged,
  });

  final DateTime selectedDate;
  final int? departureMinute;
  final FocusNode timeFocusNode;
  final String? timeError;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int?> onTimeChanged;
  final List<VehicleProfile> vehicles;
  final VehicleProfile? vehicle;
  final bool restoredVehicleMissing;
  final FocusNode vehicleFocusNode;
  final String? vehicleError;
  final TripVehicleConfiguration vehicleConfiguration;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<TripVehicleConfiguration> onVehicleConfigurationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('trip-departure-group'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            if (context.mounted && selected != null) {
              onDateChanged(DateUtils.dateOnly(selected));
            }
          },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('Fecha · ${_formatDate(selectedDate)}'),
        ),
        const SizedBox(height: AppSpacing.s),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('trip-time-button'),
                focusNode: timeFocusNode,
                onPressed: () async {
                  final minute = departureMinute;
                  final selected = await showTimePicker(
                    context: context,
                    initialTime: minute == null
                        ? const TimeOfDay(hour: 8, minute: 0)
                        : TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (context.mounted && selected != null) {
                    onTimeChanged(selected.hour * 60 + selected.minute);
                  }
                },
                icon: const Icon(Icons.schedule),
                label: Text(
                  departureMinute == null
                      ? 'Hora opcional · Sin definir'
                      : 'Hora de salida · ${_minuteLabel(departureMinute!)}',
                ),
              ),
            ),
            if (departureMinute != null) ...[
              const SizedBox(width: AppSpacing.s),
              IconButton.outlined(
                key: const ValueKey('trip-clear-time'),
                tooltip: 'Quitar hora de salida',
                onPressed: () => onTimeChanged(null),
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
        const Text('Hora de Colombia', style: AppTextStyles.caption),
        if (timeError != null) _FieldError(timeError!),
        const SizedBox(height: AppSpacing.s),
        _VehicleCard(
          vehicles: vehicles,
          vehicle: vehicle,
          restoredVehicleMissing: restoredVehicleMissing,
          focusNode: vehicleFocusNode,
          onChanged: onVehicleChanged,
        ),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          key: const ValueKey('trip-standard-vehicle'),
          behavior: HitTestBehavior.translucent,
          onTap: () => onVehicleConfigurationChanged(
            TripVehicleConfiguration.standardTwoAxle,
          ),
          child: Text(
            _vehicleCategoryLabel(vehicle, vehicleConfiguration),
            key: const ValueKey('trip-vehicle-category'),
            style: AppTextStyles.caption.copyWith(color: AppColors.teal),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('trip-vehicle-options'),
            onPressed: vehicle == null
                ? null
                : () => _showVehicleOptions(context),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Opciones del vehículo'),
          ),
        ),
        if (vehicleConfiguration == TripVehicleConfiguration.unsupported)
          const Text(
            'Tarifas no soportadas para remolque o configuración distinta. Los datos locales siguen disponibles.',
          ),
        if (vehicleError != null) _FieldError(vehicleError!),
      ],
    );
  }

  Future<void> _showVehicleOptions(BuildContext context) async {
    final selected = await showModalBottomSheet<TripVehicleConfiguration>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _VehicleOptionTile(
              title: 'Categoría estándar del vehículo',
              subtitle: _standardCategoryLabel(vehicle),
              selected:
                  vehicleConfiguration ==
                  TripVehicleConfiguration.standardTwoAxle,
              onTap: () =>
                  Navigator.of(context)
                      .pop(TripVehicleConfiguration.standardTwoAxle),
            ),
            _VehicleOptionTile(
              title: 'Remolque o configuración distinta',
              subtitle: 'Tarifa no soportada en esta versión',
              selected:
                  vehicleConfiguration == TripVehicleConfiguration.unsupported,
              onTap: () =>
                  Navigator.of(context)
                      .pop(TripVehicleConfiguration.unsupported),
            ),
          ],
        ),
      ),
    );
    if (selected != null) onVehicleConfigurationChanged(selected);
  }
}

class _VehicleOptionTile extends StatelessWidget {
  const _VehicleOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.radio_button_unchecked),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicles,
    required this.vehicle,
    required this.restoredVehicleMissing,
    required this.focusNode,
    required this.onChanged,
  });

  final List<VehicleProfile> vehicles;
  final VehicleProfile? vehicle;
  final bool restoredVehicleMissing;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = vehicle;
    return Row(
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
              Text('Vehículo para este viaje', style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.xs),
              Text(
                restoredVehicleMissing
                    ? 'El vehículo del borrador ya no está disponible.'
                    : current == null
                    ? 'Selecciona un vehículo para consultar el plan.'
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
          focusNode: focusNode,
          onPressed: vehicles.isEmpty
              ? null
              : () => _showVehicleSelector(context),
          icon: const Icon(Icons.swap_horiz),
        ),
      ],
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
    required this.originFocusNode,
    required this.destinationFocusNode,
    required this.originError,
    required this.destinationError,
    required this.originSuggestions,
    required this.destinationSuggestions,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onOriginSelected,
    required this.onDestinationSelected,
    required this.onSwapLocations,
  });

  final TextEditingController originController;
  final TextEditingController destinationController;
  final FocusNode originFocusNode;
  final FocusNode destinationFocusNode;
  final String? originError;
  final String? destinationError;
  final List<TripMunicipality> originSuggestions;
  final List<TripMunicipality> destinationSuggestions;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<TripMunicipality> onOriginSelected;
  final ValueChanged<TripMunicipality> onDestinationSelected;
  final VoidCallback onSwapLocations;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('trip-location-group'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('trip-origin-field'),
                  controller: originController,
                  focusNode: originFocusNode,
                  onChanged: onOriginChanged,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => destinationFocusNode.requestFocus(),
                  decoration: InputDecoration(
                    labelText: 'Origen',
                    prefixIcon: const Icon(Icons.trip_origin),
                    errorText: originError,
                    errorMaxLines: 5,
                  ),
                  validator: _requiredField('Ingresa el origen.'),
                ),
                _MunicipalitySuggestions(
                  field: 'origin',
                  suggestions: originSuggestions,
                  onSelected: onOriginSelected,
                ),
                const SizedBox(height: AppSpacing.s),
                TextFormField(
                  key: const ValueKey('trip-destination-field'),
                  controller: destinationController,
                  focusNode: destinationFocusNode,
                  onChanged: onDestinationChanged,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => destinationFocusNode.unfocus(),
                  decoration: InputDecoration(
                    labelText: 'Destino',
                    prefixIcon: const Icon(Icons.place_outlined),
                    errorText: destinationError,
                    errorMaxLines: 5,
                  ),
                  validator: _requiredField('Ingresa el destino.'),
                ),
                _MunicipalitySuggestions(
                  field: 'destination',
                  suggestions: destinationSuggestions,
                  onSelected: onDestinationSelected,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Semantics(
            label: 'Intercambiar origen y destino',
            button: true,
            onTap: onSwapLocations,
            child: ExcludeSemantics(
              child: IconButton.outlined(
                key: const ValueKey('trip-swap-locations'),
                tooltip: 'Intercambiar origen y destino',
                onPressed: onSwapLocations,
                icon: const Icon(Icons.swap_vert),
              ),
            ),
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
            const SizedBox(height: AppSpacing.s),
            const Text(
              'Google Maps y Waze pueden recalcular el recorrido y cambiar los tiempos y peajes. La alternativa seleccionada no se conserva en el enlace.',
            ),
            const SizedBox(height: AppSpacing.s),
            const Text(
              'INVÍAS es una fuente vial separada; sus cierres no están confirmados en este plan.',
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

class _RoutesUnavailable extends StatelessWidget {
  const _RoutesUnavailable({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rutas y precios todavía no disponibles',
          style: AppTextStyles.bodyStrong,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(reason),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Puedes revisar las reglas locales y abrir Maps o Waze con el destino; el navegador puede recalcular.',
        ),
      ],
    ),
  );
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

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

String _minuteLabel(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
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

String _vehicleCategoryLabel(
  VehicleProfile? vehicle,
  TripVehicleConfiguration configuration,
) {
  if (configuration == TripVehicleConfiguration.unsupported) {
    return 'Configuración no soportada';
  }
  return _standardCategoryLabel(vehicle);
}

String _standardCategoryLabel(VehicleProfile? vehicle) {
  if (vehicle == null) return 'Categoría pendiente';
  if (vehicle.kind == VehicleKind.motorcycle) return 'Moto · categoría propia';
  if (vehicle.serviceType == VehicleServiceType.taxi) {
    return 'Taxi · categoría propia';
  }
  return 'Particular · 2 ejes';
}

String _restrictionLabel(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.allowed => 'Sin restricción para ese día',
    RestrictionDayStatus.restricted => 'No circula',
    RestrictionDayStatus.unknown => 'Sin información vigente',
    RestrictionDayStatus.stale => 'Información desactualizada',
  };
}
