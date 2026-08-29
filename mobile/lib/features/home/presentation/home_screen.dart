import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/actions_and_badges.dart';
import '../../../core/design_system/branding.dart';
import '../../../core/design_system/surfaces.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../../pico_placa/data/restriction_store.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../vehicle_status/domain/vehicle_obligation.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';

part 'home_vehicle_carousel.dart';
part 'home_status_section.dart';
part 'home_notification_sheet.dart';

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

    return PicoSurface(
      child: seed.when(
        data: (_) => vehicles.when(
          data: (items) => active.when(
            data: (activeVehicle) => jurisdictions.when(
              data: (cities) => selectedJurisdiction.when(
                data: (jurisdictionId) => alertPreferences.when(
                  data: (alerts) => _HomeDataGate(
                    vehicles: items,
                    activeVehicleId: activeVehicle?.id,
                    jurisdictions: cities,
                    selectedJurisdictionId: jurisdictionId,
                    alertPreferences: alerts,
                  ),
                  loading: () => const _HomeSkeleton(),
                  error: (error, stackTrace) =>
                      _LoadError(message: error.toString()),
                ),
                loading: () => const _HomeSkeleton(),
                error: (error, stackTrace) =>
                    _LoadError(message: error.toString()),
              ),
              loading: () => const _HomeSkeleton(),
              error: (error, stackTrace) =>
                  _LoadError(message: error.toString()),
            ),
            loading: () => const _HomeSkeleton(),
            error: (error, stackTrace) => _LoadError(message: error.toString()),
          ),
          loading: () => const _HomeSkeleton(),
          error: (error, stackTrace) => _LoadError(message: error.toString()),
        ),
        loading: () => const _HomeSkeleton(),
        error: (error, stackTrace) => _LoadError(message: error.toString()),
      ),
    );
  }
}

class HomeVehicleSnapshot {
  const HomeVehicleSnapshot({
    required this.vehicle,
    required this.today,
    required this.tomorrow,
  });

  final VehicleProfile vehicle;
  final RestrictionDayEvaluation today;
  final RestrictionDayEvaluation tomorrow;
}

int pickInitialHomeVehicleIndex({
  required List<HomeVehicleSnapshot> snapshots,
  required String? activeVehicleId,
}) {
  if (snapshots.isEmpty) {
    return 0;
  }

  final activeIndex = snapshots.indexWhere(
    (snapshot) => snapshot.vehicle.id == activeVehicleId,
  );
  if (activeIndex >= 0 &&
      snapshots[activeIndex].today.status == RestrictionDayStatus.restricted) {
    return activeIndex;
  }

  final restrictedIndex = snapshots.indexWhere(
    (snapshot) => snapshot.today.status == RestrictionDayStatus.restricted,
  );
  if (restrictedIndex >= 0) {
    return restrictedIndex;
  }

  if (activeIndex >= 0) {
    return activeIndex;
  }

  return 0;
}

class _HomeDataGate extends ConsumerWidget {
  const _HomeDataGate({
    required this.vehicles,
    required this.activeVehicleId,
    required this.jurisdictions,
    required this.selectedJurisdictionId,
    required this.alertPreferences,
  });

  final List<VehicleProfile> vehicles;
  final String? activeVehicleId;
  final List<RestrictionJurisdiction> jurisdictions;
  final String? selectedJurisdictionId;
  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jurisdiction = selectedJurisdiction;
    if (vehicles.isEmpty) {
      return _HomeEmpty(alertPreferences: alertPreferences);
    }

    if (jurisdiction == null) {
      return _HomeReady(
        snapshots: [
          for (final vehicle in vehicles)
            HomeVehicleSnapshot(
              vehicle: vehicle,
              today: _unknownEvaluation,
              tomorrow: _unknownEvaluation,
            ),
        ],
        activeVehicleId: activeVehicleId,
        jurisdictions: jurisdictions,
        selectedJurisdiction: null,
        alertPreferences: alertPreferences,
      );
    }

    return FutureBuilder<List<HomeVehicleSnapshot>>(
      future: _buildSnapshots(ref, jurisdiction),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _HomeSkeleton();
        }
        return _HomeReady(
          snapshots: snapshot.data!,
          activeVehicleId: activeVehicleId,
          jurisdictions: jurisdictions,
          selectedJurisdiction: jurisdiction,
          alertPreferences: alertPreferences,
        );
      },
    );
  }

  RestrictionJurisdiction? get selectedJurisdiction {
    for (final jurisdiction in jurisdictions) {
      if (jurisdiction.id == selectedJurisdictionId) {
        return jurisdiction;
      }
    }
    return null;
  }

  Future<List<HomeVehicleSnapshot>> _buildSnapshots(
    WidgetRef ref,
    RestrictionJurisdiction jurisdiction,
  ) async {
    final store = ref.read(restrictionStoreProvider);
    final currentInstant = ref.read(currentInstantProvider);
    final now = ref.read(bogotaNowProvider);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final snapshots = <HomeVehicleSnapshot>[];
    for (final vehicle in vehicles) {
      final rules = await store.loadCoverage(
        jurisdiction.id,
        vehicle.kind,
        vehicle.serviceType,
        currentInstant,
      );
      snapshots.add(
        HomeVehicleSnapshot(
          vehicle: vehicle,
          today: evaluateRestrictionDay(
            ruleSet: rules,
            jurisdictionId: jurisdiction.id,
            plate: vehicle.plate,
            vehicleKind: vehicle.kind,
            serviceType: vehicle.serviceType,
            date: now,
          ),
          tomorrow: evaluateRestrictionDay(
            ruleSet: rules,
            jurisdictionId: jurisdiction.id,
            plate: vehicle.plate,
            vehicleKind: vehicle.kind,
            serviceType: vehicle.serviceType,
            date: tomorrow,
          ),
        ),
      );
    }
    return snapshots;
  }
}

class _HomeReady extends ConsumerStatefulWidget {
  const _HomeReady({
    required this.snapshots,
    required this.activeVehicleId,
    required this.jurisdictions,
    required this.selectedJurisdiction,
    required this.alertPreferences,
  });

  final List<HomeVehicleSnapshot> snapshots;
  final String? activeVehicleId;
  final List<RestrictionJurisdiction> jurisdictions;
  final RestrictionJurisdiction? selectedJurisdiction;
  final PicoAlertPreferences alertPreferences;

  @override
  ConsumerState<_HomeReady> createState() => _HomeReadyState();
}

class _HomeReadyState extends ConsumerState<_HomeReady> {
  late int _focusedIndex;
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _focusedIndex = pickInitialHomeVehicleIndex(
      snapshots: widget.snapshots,
      activeVehicleId: widget.activeVehicleId,
    );
    _controller = PageController(
      initialPage: _focusedIndex,
      viewportFraction: _homeCarouselViewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant _HomeReady oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusedIndex >= widget.snapshots.length) {
      _focusedIndex = pickInitialHomeVehicleIndex(
        snapshots: widget.snapshots,
        activeVehicleId: widget.activeVehicleId,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(_focusedIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.snapshots[_focusedIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 380
            ? AppSpacing.l
            : AppSpacing.xl;
        return SingleChildScrollView(
          key: const ValueKey('home-v2-scroll'),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.s,
            horizontalPadding,
            AppSpacing.m,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(alertPreferences: widget.alertPreferences),
                  const SizedBox(height: AppSpacing.m),
                  _VehicleCarousel(
                    controller: _controller,
                    snapshots: widget.snapshots,
                    focusedIndex: _focusedIndex,
                    onChanged: (index) {
                      setState(() => _focusedIndex = index);
                    },
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _CarouselIndicator(
                    count: widget.snapshots.length,
                    index: _focusedIndex,
                  ),
                  if (widget.selectedJurisdiction == null) ...[
                    const SizedBox(height: AppSpacing.l),
                    _NoCityCard(
                      vehicle: focused.vehicle,
                      jurisdictions: widget.jurisdictions,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.m),
                  _FocusedStatusGrid(snapshot: focused),
                  const SizedBox(height: AppSpacing.m),
                  _StartDrivingCta(
                    focusedVehicleId: focused.vehicle.id,
                    activeVehicleId: widget.activeVehicleId,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  const _HomePromoBanner(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: PicoRadarBrandLockup(
                key: ValueKey('home-brand-lockup'),
                markSize: 30,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Abrir notificaciones',
                child: Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  elevation: 3,
                  shadowColor: AppColors.navy.withValues(alpha: 0.14),
                  child: IconButton(
                    key: const ValueKey('home-notification-bell'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (context) => _NotificationSheet(
                        alertPreferences: alertPreferences,
                      ),
                    ),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.navy,
                        ),
                        if (alertPreferences.permissionGranted &&
                            alertPreferences.enabled)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.teal,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            const HomeAvatarButton(),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola!',
                    style: AppTextStyles.h1.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Así están tus vehículos hoy',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NoCityCard extends ConsumerWidget {
  const _NoCityCard({required this.vehicle, required this.jurisdictions});

  final VehicleProfile vehicle;
  final List<RestrictionJurisdiction> jurisdictions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = _suggestedJurisdiction(vehicle, jurisdictions);
    return AppCard(
      key: const ValueKey('home-no-city-card'),
      backgroundColor: AppColors.orange.withValues(alpha: 0.06),
      borderColor: AppColors.orange.withValues(alpha: 0.24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_city_outlined, color: AppColors.orange),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecciona dónde vas a conducir',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  suggestion == null
                      ? 'Necesitamos la ciudad para verificar restricciones.'
                      : 'Sugerencia por matrícula: ${suggestion.name}. Confirma la ciudad antes de salir.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.m),
                SecondaryButton(
                  key: const ValueKey('home-select-jurisdiction'),
                  label: 'Seleccionar ciudad',
                  icon: Icons.keyboard_arrow_down_rounded,
                  onPressed: () =>
                      _showJurisdictionSheet(context, ref, jurisdictions),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeHeader(alertPreferences: alertPreferences),
          const SizedBox(height: AppSpacing.xl),
          EmptyState(
            key: const ValueKey('home-empty-state'),
            title: 'No tienes vehículos todavía',
            message: 'Agrega tu primer vehículo para ver su pico y placa y recordatorios locales.',
            actionLabel: 'Agregar vehículo',
            onActionPressed: () =>
                context.push(AppRoute.vehicleOnboarding.path),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: PicoRadarBrandLockup(markSize: 34)),
          const SizedBox(height: AppSpacing.xl),
          const AppSkeleton(width: 180, height: 28),
          const SizedBox(height: AppSpacing.s),
          const AppSkeleton(width: 230, height: 18),
          const SizedBox(height: AppSpacing.xl),
          AppSkeleton(
            height: 300,
            borderRadius: AppRadius.card,
            width: MediaQuery.sizeOf(context).width,
          ),
          const SizedBox(height: AppSpacing.l),
          const _StatusGridSkeleton(),
        ],
      ),
    );
  }
}

class _StatusGridSkeleton extends StatelessWidget {
  const _StatusGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 340
            ? (constraints.maxWidth - AppSpacing.m) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.m,
          runSpacing: AppSpacing.m,
          children: [
            for (var i = 0; i < 4; i += 1)
              AppSkeleton(
                width: width,
                height: 96,
                borderRadius: AppRadius.card,
              ),
          ],
        );
      },
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

const _unknownEvaluation = RestrictionDayEvaluation(
  status: RestrictionDayStatus.unknown,
  effectiveWindows: [],
);

Color statusColor(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => AppColors.red,
    RestrictionDayStatus.allowed => AppColors.green,
    RestrictionDayStatus.unknown => AppColors.blue,
    RestrictionDayStatus.stale => AppColors.orange,
  };
}

IconData statusIcon(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => Icons.warning_amber_rounded,
    RestrictionDayStatus.allowed => Icons.check_circle_outline,
    RestrictionDayStatus.unknown => Icons.help_outline,
    RestrictionDayStatus.stale => Icons.update,
  };
}

String todayStatusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'Pico y placa hoy',
    RestrictionDayStatus.allowed => 'Puede circular',
    RestrictionDayStatus.unknown => 'Sin confirmar',
    RestrictionDayStatus.stale => 'Datos pendientes',
  };
}

String _vehiclePrimaryLabel(VehicleProfile vehicle) {
  if (vehicle.nickname != null && vehicle.nickname!.trim().isNotEmpty) {
    return vehicle.nickname!.trim();
  }
  if (vehicle.subtype != null && vehicle.subtype!.trim().isNotEmpty) {
    return vehicle.subtype!.trim();
  }
  if (vehicle.serviceType == VehicleServiceType.taxi) {
    return 'Taxi';
  }
  return shortVehicleTypeLabel(vehicle);
}

String? _vehicleSecondaryLabel(VehicleProfile vehicle) {
  final parts = [
    if (vehicle.brand != null && vehicle.brand!.trim().isNotEmpty)
      vehicle.brand!.trim(),
    if (vehicle.model != null && vehicle.model!.trim().isNotEmpty)
      vehicle.model!.trim(),
    if (vehicle.year != null) vehicle.year.toString(),
  ];
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' ');
}

String _tomorrowValue(RestrictionDayEvaluation evaluation) {
  return switch (evaluation.status) {
    RestrictionDayStatus.restricted =>
      _formatWindows(evaluation.effectiveWindows) ?? 'Pico y placa',
    RestrictionDayStatus.allowed => 'Puede circular',
    RestrictionDayStatus.unknown => 'Sin confirmar',
    RestrictionDayStatus.stale => 'Datos pendientes',
  };
}

String _tomorrowMessage(RestrictionDayEvaluation evaluation) {
  return switch (evaluation.status) {
    RestrictionDayStatus.restricted => 'Pico y placa',
    RestrictionDayStatus.allowed => 'Sin restricción local',
    RestrictionDayStatus.unknown => 'Verifica ciudad y datos',
    RestrictionDayStatus.stale => 'Actualiza datos locales',
  };
}

String _obligationValue(
  List<VehicleObligation> obligations,
  VehicleObligationType type,
  DateTime now,
) {
  final obligation = _obligationOfType(obligations, type);
  if (obligation == null || obligation.dueDate == null) {
    return 'Sin configurar';
  }
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(
    obligation.dueDate!.year,
    obligation.dueDate!.month,
    obligation.dueDate!.day,
  );
  final days = due.difference(today).inDays;
  if (days < 0) {
    return 'Vencido';
  }
  if (days == 0) {
    return 'Vence hoy';
  }
  return '$days días';
}

String _obligationMessage(
  List<VehicleObligation> obligations,
  VehicleObligationType type,
  DateTime now,
) {
  final obligation = _obligationOfType(obligations, type);
  if (obligation == null || obligation.dueDate == null) {
    return 'Sin fecha';
  }
  final state = evaluateVehicleObligationState(
    dueDate: obligation.dueDate,
    nowBogota: now,
  );
  return obligationStatusText(type, state);
}

VehicleObligation? _obligationOfType(
  List<VehicleObligation> obligations,
  VehicleObligationType type,
) {
  for (final obligation in obligations) {
    if (obligation.type == type) {
      return obligation;
    }
  }
  return null;
}

Future<void> _showJurisdictionSheet(
  BuildContext context,
  WidgetRef ref,
  List<RestrictionJurisdiction> jurisdictions,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.s,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: [
          Text('¿Dónde vas a conducir?', style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.m),
          for (final jurisdiction in jurisdictions)
            ListTile(
              key: ValueKey('jurisdiction-${jurisdiction.id}'),
              title: Text(jurisdiction.name),
              onTap: () async {
                await ref
                    .read(appPreferencesProvider)
                    .setString(picoJurisdictionPreferenceKey, jurisdiction.id);
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

String? _formatWindows(List<RestrictionDayWindow> windows) {
  if (windows.isEmpty) {
    return null;
  }
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

bool _reduceMotion(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  return (mediaQuery?.disableAnimations ?? false) ||
      (mediaQuery?.accessibleNavigation ?? false);
}
