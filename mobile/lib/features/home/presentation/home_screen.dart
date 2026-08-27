import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../../pico_placa/data/restriction_store.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../pico_placa/platform/pico_notifications.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(bundledRestrictionsProvider);
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);
    final jurisdictions = ref.watch(restrictionJurisdictionsProvider);
    final selectedJurisdiction = ref.watch(selectedPicoJurisdictionIdProvider);
    final alertPreferences = ref.watch(picoAlertPreferencesProvider);

    return SafeArea(
      child: seed.when(
        data: (_) => vehicles.when(
          data: (items) {
            if (items.isEmpty) {
              _updateWidgetNoVehicle(ref);
              return const _HomeWelcome();
            }
            return active.when(
              data: (vehicle) {
                final resolvedVehicle = vehicle ?? items.first;
                if (vehicle == null) {
                  _setInitialActiveVehicle(ref, resolvedVehicle.id);
                }
                return jurisdictions.when(
                  data: (cities) => selectedJurisdiction.when(
                    data: (jurisdictionId) => alertPreferences.when(
                      data: (alerts) => _HomeReady(
                        vehicles: items,
                        activeVehicle: resolvedVehicle,
                        jurisdictions: cities,
                        selectedJurisdictionId: jurisdictionId,
                        alertPreferences: alerts,
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) =>
                          _LoadError(message: error.toString()),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) =>
                        _LoadError(message: error.toString()),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      _LoadError(message: error.toString()),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  _LoadError(message: error.toString()),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _LoadError(message: error.toString()),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(message: error.toString()),
      ),
    );
  }

  void _setInitialActiveVehicle(WidgetRef ref, String vehicleId) {
    Future<void>.microtask(() async {
      await ref.read(vehicleRepositoryProvider).setActiveVehicle(vehicleId);
      ref.invalidate(activeVehicleProvider);
    });
  }

  void _updateWidgetNoVehicle(WidgetRef ref) {
    final bridge = ref.read(picoWidgetBridgeProvider);
    Future<void>.microtask(() async {
      try {
        await bridge.updateNoVehicle();
      } on MissingPluginException {
        return;
      }
    });
  }
}

class _HomeReady extends ConsumerWidget {
  const _HomeReady({
    required this.vehicles,
    required this.activeVehicle,
    required this.jurisdictions,
    required this.selectedJurisdictionId,
    required this.alertPreferences,
  });

  final List<VehicleProfile> vehicles;
  final VehicleProfile activeVehicle;
  final List<RestrictionJurisdiction> jurisdictions;
  final String? selectedJurisdictionId;
  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jurisdiction = _selectedJurisdiction;
    if (jurisdiction == null) {
      _updateWidgetMissingJurisdiction(ref);
      return _HomeScaffold(
        children: [
          _ActiveVehicleCard(
            vehicle: activeVehicle,
            jurisdictionName: 'Sin ciudad',
          ),
          const SizedBox(height: AppSpacing.l),
          _JurisdictionPrompt(
            vehicle: activeVehicle,
            jurisdictions: jurisdictions,
          ),
        ],
      );
    }

    return FutureBuilder<RestrictionRuleSet>(
      future: ref
          .read(restrictionStoreProvider)
          .loadCoverage(
            jurisdiction.id,
            activeVehicle.kind,
            activeVehicle.serviceType,
            ref.read(bogotaNowProvider),
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = ref.read(bogotaNowProvider);
        final today = _evaluate(snapshot.data!, jurisdiction, now);
        final tomorrow = _evaluate(
          snapshot.data!,
          jurisdiction,
          DateTime(now.year, now.month, now.day + 1),
        );
        _updateWidgetConfigured(ref, jurisdiction.name);
        _rescheduleIfAllowed(ref, jurisdiction, alertPreferences);
        return _HomeScaffold(
          children: [
            Text(
              'PicoRadar',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.m),
            _ActiveVehicleCard(
              vehicle: activeVehicle,
              jurisdictionName: jurisdiction.name,
            ),
            const SizedBox(height: AppSpacing.l),
            _StatusCard(
              title: 'HOY',
              evaluation: today,
              mainText: _todayText(today.status),
              showWindows: true,
            ),
            const SizedBox(height: AppSpacing.m),
            _StatusCard(
              title: 'MAÑANA',
              evaluation: tomorrow,
              mainText: _tomorrowText(tomorrow.status),
            ),
            const SizedBox(height: AppSpacing.l),
            Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.s,
              children: [
                FilledButton.icon(
                  key: const ValueKey('home-open-pico-detail'),
                  onPressed: () => context.push(AppRoute.pico.path),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Ver detalle'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('home-change-jurisdiction'),
                  onPressed: () => _showJurisdictionSheet(context, ref),
                  icon: const Icon(Icons.location_city),
                  label: const Text('Cambiar ciudad'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            _NotificationCard(alertPreferences: alertPreferences),
          ],
        );
      },
    );
  }

  RestrictionJurisdiction? get _selectedJurisdiction {
    for (final jurisdiction in jurisdictions) {
      if (jurisdiction.id == selectedJurisdictionId) {
        return jurisdiction;
      }
    }
    return null;
  }

  RestrictionDayEvaluation _evaluate(
    RestrictionRuleSet rules,
    RestrictionJurisdiction jurisdiction,
    DateTime date,
  ) {
    return evaluateRestrictionDay(
      ruleSet: rules,
      jurisdictionId: jurisdiction.id,
      plate: activeVehicle.plate,
      vehicleKind: activeVehicle.kind,
      serviceType: activeVehicle.serviceType,
      date: date,
    );
  }

  Future<void> _showJurisdictionSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Text('¿Dónde vas a conducir?'),
            ),
            for (final jurisdiction in jurisdictions)
              ListTile(
                key: ValueKey('jurisdiction-${jurisdiction.id}'),
                title: Text(jurisdiction.name),
                onTap: () async {
                  await ref
                      .read(appPreferencesProvider)
                      .setString(
                        picoJurisdictionPreferenceKey,
                        jurisdiction.id,
                      );
                  ref.invalidate(selectedPicoJurisdictionIdProvider);
                  if (context.mounted) {
                    context.pop();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _updateWidgetMissingJurisdiction(WidgetRef ref) {
    final bridge = ref.read(picoWidgetBridgeProvider);
    Future<void>.microtask(() async {
      try {
        await bridge.updateMissingJurisdiction(activeVehicle);
      } on MissingPluginException {
        return;
      }
    });
  }

  void _updateWidgetConfigured(WidgetRef ref, String jurisdictionName) {
    final bridge = ref.read(picoWidgetBridgeProvider);
    Future<void>.microtask(() async {
      try {
        await bridge.updateConfigured(
          vehicle: activeVehicle,
          jurisdictionName: jurisdictionName,
        );
      } on MissingPluginException {
        return;
      }
    });
  }

  void _rescheduleIfAllowed(
    WidgetRef ref,
    RestrictionJurisdiction jurisdiction,
    PicoAlertPreferences alertPreferences,
  ) {
    if (!alertPreferences.permissionRequested) {
      return;
    }
    final store = ref.read(restrictionStoreProvider);
    final now = ref.read(bogotaNowProvider);
    final scheduler = ref.read(picoNotificationSchedulerProvider);
    Future<void>.microtask(() async {
      final plans = await buildPicoNotificationPlans(
        store: store,
        now: now,
        vehicles: vehicles,
        jurisdiction: jurisdiction,
        alertPreferences: alertPreferences,
      );
      try {
        await scheduler.initialize();
        await scheduler.reschedule(plans);
      } on MissingPluginException {
        return;
      }
    });
  }
}

Future<List<PicoNotificationPlan>> buildPicoNotificationPlans({
  required RestrictionStore store,
  required DateTime now,
  required List<VehicleProfile> vehicles,
  required RestrictionJurisdiction jurisdiction,
  required PicoAlertPreferences alertPreferences,
}) async {
  final days = <PicoVehicleRestrictionDay>[];
  for (final vehicle in vehicles) {
    final ruleSet = await store.loadCoverage(
      jurisdiction.id,
      vehicle.kind,
      vehicle.serviceType,
      now,
    );
    for (var offset = 0; offset < 14; offset += 1) {
      final date = DateTime(now.year, now.month, now.day + offset);
      days.add(
        PicoVehicleRestrictionDay(
          vehicle: vehicle,
          jurisdictionName: jurisdiction.name,
          date: date,
          evaluation: evaluateRestrictionDay(
            ruleSet: ruleSet,
            jurisdictionId: jurisdiction.id,
            plate: vehicle.plate,
            vehicleKind: vehicle.kind,
            serviceType: vehicle.serviceType,
            date: date,
          ),
        ),
      );
    }
  }
  return planPicoNotifications(
    days: days,
    settings: PicoNotificationSettings(
      enabled: alertPreferences.enabled,
      dayBeforeEnabled: alertPreferences.dayBeforeEnabled,
      sameDayEnabled: alertPreferences.sameDayEnabled,
      dayBeforeMinute: alertPreferences.dayBeforeMinute,
      sameDayMinute: alertPreferences.sameDayMinute,
    ),
    nowBogota: now,
  );
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _ActiveVehicleCard extends StatelessWidget {
  const _ActiveVehicleCard({
    required this.vehicle,
    required this.jurisdictionName,
  });

  final VehicleProfile vehicle;
  final String jurisdictionName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            Icon(vehicleIcon(vehicle), color: vehicleAccent(vehicle), size: 32),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.plate,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${shortVehicleTypeLabel(vehicle)} · $jurisdictionName'),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey('home-change-vehicle'),
              onPressed: () => context.go(AppRoute.garage.path),
              child: const Text('Cambiar vehículo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _JurisdictionPrompt extends ConsumerWidget {
  const _JurisdictionPrompt({
    required this.vehicle,
    required this.jurisdictions,
  });

  final VehicleProfile vehicle;
  final List<RestrictionJurisdiction> jurisdictions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = _suggestedJurisdiction(vehicle, jurisdictions);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Dónde vas a conducir?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (suggestion != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text('Sugerencia por matrícula: ${suggestion.name}'),
            ],
            const SizedBox(height: AppSpacing.m),
            DropdownButtonFormField<String>(
              key: const ValueKey('home-jurisdiction-selector'),
              decoration: const InputDecoration(labelText: 'Ciudad'),
              items: [
                for (final jurisdiction in jurisdictions)
                  DropdownMenuItem(
                    value: jurisdiction.id,
                    child: Text(jurisdiction.name),
                  ),
              ],
              onChanged: (value) async {
                if (value == null) {
                  return;
                }
                await ref
                    .read(appPreferencesProvider)
                    .setString(picoJurisdictionPreferenceKey, value);
                ref.invalidate(selectedPicoJurisdictionIdProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.evaluation,
    required this.mainText,
    this.showWindows = false,
  });

  final String title;
  final RestrictionDayEvaluation evaluation;
  final String mainText;
  final bool showWindows;

  @override
  Widget build(BuildContext context) {
    final color = switch (evaluation.status) {
      RestrictionDayStatus.restricted => AppColors.red,
      RestrictionDayStatus.allowed => AppColors.green,
      RestrictionDayStatus.unknown => AppColors.blue,
      RestrictionDayStatus.stale => AppColors.orange,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_statusIcon(evaluation.status), color: color),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    mainText,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (showWindows && evaluation.effectiveWindows.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Text(_formatWindows(evaluation.effectiveWindows)),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alertas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s),
            const Text('Recordatorios locales, sin cuenta ni servidor.'),
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              key: const ValueKey('home-enable-notifications'),
              onPressed: () async {
                await ref
                    .read(appPreferencesProvider)
                    .setBool(picoNotificationPermissionRequestedKey, true);
                var granted = false;
                try {
                  final scheduler = ref.read(picoNotificationSchedulerProvider);
                  await scheduler.initialize();
                  granted = await scheduler.requestPermission();
                } on MissingPluginException {
                  granted = true;
                }
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permiso de notificaciones denegado.'),
                    ),
                  );
                }
                ref.invalidate(picoAlertPreferencesProvider);
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Activar notificaciones'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeWelcome extends StatelessWidget {
  const _HomeWelcome();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Icon(
                Icons.radar_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'PicoRadar',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.s),
              const Text(
                'Tu vehículo, tus alertas y tu ruta en un solo lugar.',
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                key: const ValueKey('home-add-vehicle'),
                onPressed: () => context.push(AppRoute.vehicleOnboarding.path),
                icon: const Icon(Icons.add),
                label: const Text('Agregar mi vehículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message),
    );
  }
}

RestrictionJurisdiction? _suggestedJurisdiction(
  VehicleProfile vehicle,
  List<RestrictionJurisdiction> jurisdictions,
) {
  final registrationCity = vehicle.registrationCity?.toLowerCase();
  if (registrationCity == null || registrationCity.isEmpty) {
    return null;
  }
  for (final jurisdiction in jurisdictions) {
    if (jurisdiction.name.toLowerCase().contains(registrationCity)) {
      return jurisdiction;
    }
  }
  return null;
}

String _todayText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'HOY TIENES PICO Y PLACA',
    RestrictionDayStatus.allowed => 'HOY PUEDES CIRCULAR',
    RestrictionDayStatus.unknown => 'NO PODEMOS CONFIRMAR TU PICO Y PLACA',
    RestrictionDayStatus.stale => 'DATOS PENDIENTES DE ACTUALIZACIÓN',
  };
}

String _tomorrowText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'Tienes Pico y Placa',
    RestrictionDayStatus.allowed => 'Puedes circular',
    RestrictionDayStatus.unknown => 'No podemos confirmar',
    RestrictionDayStatus.stale => 'Datos desactualizados',
  };
}

IconData _statusIcon(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => Icons.warning_amber_rounded,
    RestrictionDayStatus.allowed => Icons.check_circle_outline,
    RestrictionDayStatus.unknown => Icons.help_outline,
    RestrictionDayStatus.stale => Icons.update,
  };
}

String _formatWindows(List<RestrictionDayWindow> windows) {
  return windows
      .map(
        (window) =>
            '${_formatMinute(window.startMinute)} - ${_formatMinute(window.endMinute)}',
      )
      .join(', ');
}

String _formatMinute(int minute) {
  if (minute == 1440) {
    return '24:00';
  }
  final hour = minute ~/ 60;
  final minutes = minute % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}
