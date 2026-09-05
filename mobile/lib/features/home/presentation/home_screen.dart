import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/shell/picoradar_app_header.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/actions_and_badges.dart';
import '../../../core/design_system/branding.dart';
import '../../../core/design_system/surfaces.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../location/application/location_controller.dart';
import '../../location/data/location_preferences.dart';
import '../../location/domain/jurisdiction_location_resolver.dart';
import '../../location/platform/device_location_gateway.dart';
import '../data/home_banner_config.dart';
import 'pico_notification_sheet.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../../pico_placa/data/restriction_store.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../vehicle_status/domain/vehicle_obligation.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';

part 'home_vehicle_carousel.dart';
part 'home_status_section.dart';
part 'home_notification_sheet.dart';
part 'home_banner_slot.dart';

final homeFocusedVehicleIdProvider =
    NotifierProvider<HomeFocusedVehicleNotifier, String?>(
      HomeFocusedVehicleNotifier.new,
    );

@visibleForTesting
final homeGpsClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final homeVehicleSnapshotsProvider =
    FutureProvider.family<
      List<HomeVehicleSnapshot>,
      HomeVehicleSnapshotsRequest
    >((ref, request) async {
      if (request.selectedJurisdiction == null) {
        return [
          for (final vehicle in request.vehicles)
            HomeVehicleSnapshot(
              vehicle: vehicle,
              today: _unknownEvaluation,
              tomorrow: _unknownEvaluation,
            ),
        ];
      }

      final store = ref.watch(restrictionStoreProvider);
      final currentInstant = ref.watch(currentInstantProvider);
      final now = ref.watch(bogotaNowProvider);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final snapshots = <HomeVehicleSnapshot>[];
      for (final vehicle in request.vehicles) {
        final rules = await store.loadCoverage(
          request.selectedJurisdiction!.id,
          vehicle.kind,
          vehicle.serviceType,
          currentInstant,
        );
        snapshots.add(
          HomeVehicleSnapshot(
            vehicle: vehicle,
            today: evaluateRestrictionDay(
              ruleSet: rules,
              jurisdictionId: request.selectedJurisdiction!.id,
              plate: vehicle.plate,
              vehicleKind: vehicle.kind,
              serviceType: vehicle.serviceType,
              date: now,
            ),
            tomorrow: evaluateRestrictionDay(
              ruleSet: rules,
              jurisdictionId: request.selectedJurisdiction!.id,
              plate: vehicle.plate,
              vehicleKind: vehicle.kind,
              serviceType: vehicle.serviceType,
              date: tomorrow,
            ),
          ),
        );
      }
      return snapshots;
    });

class HomeFocusedVehicleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFocusedVehicleId(String? vehicleId) {
    state = vehicleId;
  }
}

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

class HomeVehicleSnapshotsRequest {
  const HomeVehicleSnapshotsRequest({
    required this.vehicles,
    required this.selectedJurisdiction,
  });

  final List<VehicleProfile> vehicles;
  final RestrictionJurisdiction? selectedJurisdiction;

  @override
  bool operator ==(Object other) {
    return other is HomeVehicleSnapshotsRequest &&
        other.selectedJurisdiction?.id == selectedJurisdiction?.id &&
        _sameVehicleInputs(other.vehicles, vehicles);
  }

  @override
  int get hashCode {
    return Object.hash(
      selectedJurisdiction?.id,
      Object.hashAll(
        vehicles.map(
          (vehicle) => Object.hash(
            vehicle.id,
            vehicle.plate,
            vehicle.kind,
            vehicle.serviceType,
            vehicle.subtype,
            vehicle.nickname,
            vehicle.registrationCity,
            vehicle.brand,
            vehicle.model,
            vehicle.year,
            vehicle.color,
            vehicle.fuel,
            vehicle.updatedAt,
          ),
        ),
      ),
    );
  }
}

bool _sameVehicleInputs(List<VehicleProfile> a, List<VehicleProfile> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    if (a[i].id != b[i].id ||
        a[i].plate != b[i].plate ||
        a[i].kind != b[i].kind ||
        a[i].serviceType != b[i].serviceType ||
        a[i].subtype != b[i].subtype ||
        a[i].nickname != b[i].nickname ||
        a[i].registrationCity != b[i].registrationCity ||
        a[i].brand != b[i].brand ||
        a[i].model != b[i].model ||
        a[i].year != b[i].year ||
        a[i].color != b[i].color ||
        a[i].fuel != b[i].fuel ||
        a[i].updatedAt != b[i].updatedAt) {
      return false;
    }
  }
  return true;
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

    final snapshots = ref.watch(
      homeVehicleSnapshotsProvider(
        HomeVehicleSnapshotsRequest(
          vehicles: vehicles,
          selectedJurisdiction: jurisdiction,
        ),
      ),
    );
    return snapshots.when(
      skipLoadingOnRefresh: true,
      data: (items) {
        return _HomeReady(
          snapshots: items,
          activeVehicleId: activeVehicleId,
          jurisdictions: jurisdictions,
          selectedJurisdiction: jurisdiction,
          alertPreferences: alertPreferences,
        );
      },
      loading: () => const _HomeSkeleton(),
      error: (error, stackTrace) => _LoadError(message: error.toString()),
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
  final _lifecycleObserver = _HomeLocationLifecycleObserver();

  @override
  void initState() {
    super.initState();
    _lifecycleObserver.onResume = () {
      ref.read(locationStateProvider.notifier).refreshGpsIfDue();
    };
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _focusedIndex = pickInitialHomeVehicleIndex(
      snapshots: widget.snapshots,
      activeVehicleId: widget.activeVehicleId,
    );
    _syncFocusedVehicle();
    _controller = PageController(
      initialPage: _focusedIndex,
      viewportFraction: _homeCarouselViewportFraction,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(locationStateProvider.notifier).refreshGpsIfDue();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomeReady oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusedIndex >= widget.snapshots.length) {
      _focusedIndex = pickInitialHomeVehicleIndex(
        snapshots: widget.snapshots,
        activeVehicleId: widget.activeVehicleId,
      );
      _syncFocusedVehicle();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(_focusedIndex);
        }
      });
    } else if (oldWidget.snapshots[_focusedIndex].vehicle.id !=
        widget.snapshots[_focusedIndex].vehicle.id) {
      _syncFocusedVehicle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _controller.dispose();
    super.dispose();
  }

  void _syncFocusedVehicle() {
    final vehicleId = widget.snapshots[_focusedIndex].vehicle.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(homeFocusedVehicleIdProvider.notifier)
          .setFocusedVehicleId(vehicleId);
    });
  }

  void _setFocusedIndex(int index) {
    setState(() => _focusedIndex = index);
    _syncFocusedVehicle();
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
            AppSpacing.xs,
            horizontalPadding,
            0,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(alertPreferences: widget.alertPreferences),
                  const SizedBox(height: 2),
                  _HomeLocationCard(
                    jurisdictions: widget.jurisdictions,
                    selectedJurisdiction: widget.selectedJurisdiction,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _VehicleCarousel(
                    controller: _controller,
                    snapshots: widget.snapshots,
                    focusedIndex: _focusedIndex,
                    onChanged: _setFocusedIndex,
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
                  const SizedBox(height: AppSpacing.xs),
                  _FocusedStatusGrid(snapshot: focused),
                  const SizedBox(height: AppSpacing.xs),
                  const HomeBannerSlot(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeLocationLifecycleObserver extends WidgetsBindingObserver {
  VoidCallback? onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume?.call();
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context) {
    return PicoRadarAppHeader(
      alertPreferences: alertPreferences,
      onNotificationsPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) =>
            HomeNotificationSheet(alertPreferences: alertPreferences),
      ),
      headerKey: const ValueKey('home-compact-top-bar'),
      brandKey: const ValueKey('home-brand-lockup'),
      capsuleKey: const ValueKey('home-user-controls-capsule'),
      bellKey: const ValueKey('home-notification-bell'),
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
                      _showLocationSettingsSheet(context, jurisdictions),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLocationCard extends ConsumerStatefulWidget {
  const _HomeLocationCard({
    required this.jurisdictions,
    required this.selectedJurisdiction,
  });

  final List<RestrictionJurisdiction> jurisdictions;
  final RestrictionJurisdiction? selectedJurisdiction;

  @override
  ConsumerState<_HomeLocationCard> createState() => _HomeLocationCardState();
}

enum _HomeGpsAvailability { unknown, available, disabled }

class _HomeLocationCardState extends ConsumerState<_HomeLocationCard>
    with WidgetsBindingObserver {
  _HomeGpsAvailability _gpsAvailability = _HomeGpsAvailability.unknown;
  int _gpsProbeGeneration = 0;
  Timer? _gpsExpiryTimer;
  DateTime? _scheduledGpsExpiryAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _probeGpsAvailability(),
    );
  }

  @override
  void dispose() {
    _gpsProbeGeneration += 1;
    _gpsExpiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _probeGpsAvailability();
    }
  }

  Future<void> _probeGpsAvailability() async {
    if (!mounted) {
      return;
    }
    final generation = ++_gpsProbeGeneration;
    if (_gpsAvailability != _HomeGpsAvailability.unknown) {
      setState(() => _gpsAvailability = _HomeGpsAvailability.unknown);
    }
    final gateway = ref.read(deviceLocationGatewayProvider);
    try {
      final serviceEnabled = await gateway.isLocationServiceEnabled();
      if (!mounted || generation != _gpsProbeGeneration) {
        return;
      }
      if (!serviceEnabled) {
        _setGpsAvailability(_HomeGpsAvailability.disabled, generation);
        return;
      }
      final permission = await gateway.checkPermission();
      if (!mounted || generation != _gpsProbeGeneration) {
        return;
      }
      _setGpsAvailability(
        permission == DeviceLocationPermission.granted
            ? _HomeGpsAvailability.available
            : _HomeGpsAvailability.disabled,
        generation,
      );
    } on Object {
      _setGpsAvailability(_HomeGpsAvailability.unknown, generation);
    }
  }

  void _setGpsAvailability(_HomeGpsAvailability availability, int generation) {
    if (mounted &&
        generation == _gpsProbeGeneration &&
        availability != _gpsAvailability) {
      setState(() => _gpsAvailability = availability);
    }
  }

  Future<void> _openLocationSettings() async {
    await _showLocationSettingsSheet(context, widget.jurisdictions);
    if (mounted) {
      await _probeGpsAvailability();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationStateProvider);
    final state = locationState.asData?.value;
    final city = _locationCityName(
      widget.jurisdictions,
      state?.effectiveJurisdictionId,
      widget.selectedJurisdiction,
    );
    final gpsVisualState = _homeGpsVisualState(
      availability: _gpsAvailability,
      locationState: state,
      now: ref.watch(homeGpsClockProvider)(),
    );
    _scheduleGpsVisualExpiry(state);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactText = textScale >= 1.4;
    final iconSize = compactText ? 22.0 : 24.0;
    final height = compactText ? 64.0 : 48.0;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _locationCardWidth(
          screenWidth: screenWidth,
          availableWidth: constraints.maxWidth,
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: cardWidth),
            child: Semantics(
              button: true,
              container: true,
              explicitChildNodes: true,
              label: 'Ubicación ${city ?? 'sin ciudad'}',
              child: Material(
                color: AppColors.surface,
                elevation: 3,
                shadowColor: AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('home-location-card'),
                  onTap: _openLocationSettings,
                  child: Container(
                    height: height,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.72),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppColors.navy,
                          size: iconSize,
                        ),
                        SizedBox(
                          width: compactText ? AppSpacing.s : AppSpacing.m,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                city ?? 'Sin ciudad',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: AppColors.navy,
                                  fontSize: compactText ? 15 : 15.5,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: compactText ? 32 : 30,
                          color: AppColors.border,
                          margin: EdgeInsets.symmetric(
                            horizontal: compactText
                                ? AppSpacing.s
                                : AppSpacing.m,
                          ),
                        ),
                        _HomeSatelliteStatus(
                          state: gpsVisualState,
                          iconSize: compactText ? 20 : 21,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleGpsVisualExpiry(LocationState? state) {
    final now = ref.read(homeGpsClockProvider)().toUtc();
    final lastRefresh = state?.lastGpsRefreshAt;
    final expiryAt =
        _gpsAvailability == _HomeGpsAvailability.available &&
            state?.mode == LocationMode.gpsAuto &&
            state?.refreshStatus == LocationRefreshStatus.detected &&
            lastRefresh != null &&
            !lastRefresh.isAfter(now)
        ? lastRefresh.add(locationRefreshTtl)
        : null;
    if (expiryAt == _scheduledGpsExpiryAt &&
        (_gpsExpiryTimer?.isActive ?? false)) {
      return;
    }
    _gpsExpiryTimer?.cancel();
    _gpsExpiryTimer = null;
    _scheduledGpsExpiryAt = expiryAt;
    if (expiryAt == null || !expiryAt.isAfter(now)) {
      return;
    }
    _gpsExpiryTimer = Timer(expiryAt.difference(now), () {
      if (!mounted || _scheduledGpsExpiryAt != expiryAt) {
        return;
      }
      _scheduledGpsExpiryAt = null;
      setState(() {});
    });
  }
}

enum _HomeGpsVisualState { active, disabled, unknown }

_HomeGpsVisualState _homeGpsVisualState({
  required _HomeGpsAvailability availability,
  required LocationState? locationState,
  required DateTime now,
}) {
  if (availability == _HomeGpsAvailability.disabled) {
    return _HomeGpsVisualState.disabled;
  }
  if (availability != _HomeGpsAvailability.available ||
      locationState == null ||
      locationState.mode != LocationMode.gpsAuto ||
      locationState.refreshStatus != LocationRefreshStatus.detected ||
      locationState.lastGpsRefreshAt == null ||
      locationState.lastGpsRefreshAt!.isAfter(now.toUtc()) ||
      now.toUtc().difference(locationState.lastGpsRefreshAt!) >=
          locationRefreshTtl) {
    return _HomeGpsVisualState.unknown;
  }
  return _HomeGpsVisualState.active;
}

class _HomeSatelliteStatus extends StatelessWidget {
  const _HomeSatelliteStatus({required this.state, required this.iconSize});

  final _HomeGpsVisualState state;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      _HomeGpsVisualState.active => 'GPS activo',
      _HomeGpsVisualState.disabled => 'GPS desactivado',
      _HomeGpsVisualState.unknown => 'Estado GPS desconocido',
    };
    final color = switch (state) {
      _HomeGpsVisualState.active => AppColors.green,
      _HomeGpsVisualState.disabled => AppColors.navy.withValues(alpha: 0.42),
      _HomeGpsVisualState.unknown => AppColors.blue.withValues(alpha: 0.72),
    };
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: SizedBox.square(
          dimension: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.satellite_alt_outlined,
                key: const ValueKey('home-location-satellite-status'),
                color: color,
                size: iconSize,
              ),
              if (state == _HomeGpsVisualState.disabled)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Icon(
                    Icons.lock_rounded,
                    key: const ValueKey('home-location-satellite-lock'),
                    color: color,
                    size: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

double _locationCardWidth({
  required double screenWidth,
  required double availableWidth,
}) {
  final targetWidth = switch (screenWidth) {
    < 380 => 212.0,
    < 400 => 220.0,
    _ => 228.0,
  };
  return math.min(targetWidth, availableWidth);
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
          const SizedBox(
            height: 56,
            child: Center(child: PicoRadarBrandLockup(markSize: 28)),
          ),
          const SizedBox(height: AppSpacing.l),
          AppSkeleton(
            height: _homeCarouselBaseHeight,
            borderRadius: AppRadius.card,
            width: MediaQuery.sizeOf(context).width,
          ),
          const SizedBox(height: AppSpacing.m),
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
            ? (constraints.maxWidth - AppSpacing.s) / 2
            : constraints.maxWidth;
        return Column(
          children: [
            AppSkeleton(
              width: constraints.maxWidth,
              height: 56,
              borderRadius: AppRadius.input,
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                for (var i = 0; i < 2; i += 1)
                  AppSkeleton(
                    width: width,
                    height: 78,
                    borderRadius: AppRadius.card,
                  ),
              ],
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

String _vehicleCompactLabel(VehicleProfile vehicle) {
  final primary = _vehiclePrimaryLabel(vehicle);
  if (vehicle.year == null) {
    return primary;
  }
  return '$primary · ${vehicle.year}';
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

Future<void> _showLocationSettingsSheet(
  BuildContext context,
  List<RestrictionJurisdiction> jurisdictions,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _LocationSettingsSheet(jurisdictions: jurisdictions),
  );
}

class _LocationSettingsSheet extends ConsumerWidget {
  const _LocationSettingsSheet({required this.jurisdictions});

  final List<RestrictionJurisdiction> jurisdictions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationStateProvider);
    final state = locationState.asData?.value;
    final effectiveJurisdiction = _jurisdictionById(
      jurisdictions,
      state?.effectiveJurisdictionId,
    );
    final mode = state?.mode ?? LocationMode.manual;
    final status = state?.refreshStatus ?? LocationRefreshStatus.idle;
    final isRefreshing =
        locationState.isLoading || status == LocationRefreshStatus.refreshing;

    return SafeArea(
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
          Text('Ubicación', style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Elige cómo PicoRadar determina la ciudad para tus restricciones.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.l),
          _LocationModeTile(
            keyName: 'location-gps-auto-option',
            selected: mode == LocationMode.gpsAuto,
            title: 'Automática por GPS',
            description: 'PicoRadar actualizará tu ciudad al abrir la app o cuando lo solicites.',
            icon: Icons.gps_fixed_rounded,
            trailing: isRefreshing
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : null,
            onTap: isRefreshing
                ? null
                : () async {
                    final result = await ref
                        .read(locationStateProvider.notifier)
                        .enableGpsAuto();
                    if (context.mounted &&
                        result == LocationRefreshStatus.detected) {
                      Navigator.of(context).maybePop();
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.s),
          _LocationFeedback(
            status: status,
            effectiveJurisdiction: effectiveJurisdiction,
            lastGpsRefreshAt: state?.lastGpsRefreshAt,
            onRetry: isRefreshing
                ? null
                : () => ref
                      .read(locationStateProvider.notifier)
                      .refreshGps(requestPermission: true, force: true),
            onOpenAppSettings: () =>
                ref.read(locationStateProvider.notifier).openAppSettings(),
            onOpenLocationSettings: () =>
                ref.read(locationStateProvider.notifier).openLocationSettings(),
          ),
          const SizedBox(height: AppSpacing.m),
          Text('Manual', style: AppTextStyles.bodyStrong),
          const SizedBox(height: AppSpacing.s),
          for (final jurisdiction in [
            ...jurisdictions,
          ]..sort((a, b) => a.name.compareTo(b.name)))
            _ManualJurisdictionTile(
              jurisdiction: jurisdiction,
              selected:
                  mode == LocationMode.manual &&
                  jurisdiction.id == state?.effectiveJurisdictionId,
              onTap: () async {
                await ref
                    .read(locationStateProvider.notifier)
                    .selectManual(jurisdiction);
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                }
              },
            ),
        ],
      ),
    );
  }
}

class _LocationModeTile extends StatelessWidget {
  const _LocationModeTile({
    required this.keyName,
    required this.selected,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final String keyName;
  final bool selected;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.teal.withValues(alpha: 0.08)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(keyName),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.teal : AppColors.navy),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(description, style: AppTextStyles.caption),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? AppColors.teal
                        : AppColors.navy.withValues(alpha: 0.36),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualJurisdictionTile extends StatelessWidget {
  const _ManualJurisdictionTile({
    required this.jurisdiction,
    required this.selected,
    required this.onTap,
  });

  final RestrictionJurisdiction jurisdiction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('jurisdiction-${jurisdiction.id}'),
      leading: const Icon(Icons.location_city_outlined),
      title: Text(_displayJurisdictionName(jurisdiction)),
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected
            ? AppColors.teal
            : AppColors.navy.withValues(alpha: 0.36),
      ),
      onTap: onTap,
    );
  }
}

class _LocationFeedback extends StatelessWidget {
  const _LocationFeedback({
    required this.status,
    required this.effectiveJurisdiction,
    required this.lastGpsRefreshAt,
    required this.onRetry,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
  });

  final LocationRefreshStatus status;
  final RestrictionJurisdiction? effectiveJurisdiction;
  final DateTime? lastGpsRefreshAt;
  final VoidCallback? onRetry;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final message = _locationFeedbackMessage(
      status,
      effectiveJurisdiction,
      lastGpsRefreshAt,
    );
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const ValueKey('location-feedback'),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: _locationFeedbackColor(status).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: _locationFeedbackColor(status).withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTextStyles.caption),
          if (_showsRetry(status) || _showsAppSettings(status)) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                if (_showsRetry(status))
                  SecondaryButton(
                    key: const ValueKey('location-retry-gps'),
                    label: 'Reintentar',
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry,
                  ),
                if (status == LocationRefreshStatus.serviceDisabled)
                  SecondaryButton(
                    key: const ValueKey('location-open-location-settings'),
                    label: 'Abrir ajustes',
                    icon: Icons.settings_outlined,
                    onPressed: onOpenLocationSettings,
                  ),
                if (_showsAppSettings(status))
                  SecondaryButton(
                    key: const ValueKey('location-open-app-settings'),
                    label: 'Abrir configuración',
                    icon: Icons.settings_outlined,
                    onPressed: onOpenAppSettings,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String? _locationCityName(
  List<RestrictionJurisdiction> jurisdictions,
  String? effectiveJurisdictionId,
  RestrictionJurisdiction? selectedJurisdiction,
) {
  final jurisdiction =
      _jurisdictionById(jurisdictions, effectiveJurisdictionId) ??
      selectedJurisdiction;
  return jurisdiction == null ? null : _displayJurisdictionName(jurisdiction);
}

RestrictionJurisdiction? _jurisdictionById(
  List<RestrictionJurisdiction> jurisdictions,
  String? jurisdictionId,
) {
  if (jurisdictionId == null) {
    return null;
  }
  for (final jurisdiction in jurisdictions) {
    if (jurisdiction.id == jurisdictionId) {
      return jurisdiction;
    }
  }
  return null;
}

String _displayJurisdictionName(RestrictionJurisdiction jurisdiction) {
  return switch (jurisdiction.id) {
    'co-dc-bogota' => 'Bogotá',
    'co-ant-medellin' => 'Medellín',
    _ => jurisdiction.name,
  };
}

String? _locationFeedbackMessage(
  LocationRefreshStatus status,
  RestrictionJurisdiction? effectiveJurisdiction,
  DateTime? lastGpsRefreshAt,
) {
  return switch (status) {
    LocationRefreshStatus.idle => null,
    LocationRefreshStatus.refreshing => 'Detectando ubicación...',
    LocationRefreshStatus.detected =>
      'GPS activo en ${effectiveJurisdiction == null ? 'tu ciudad' : _displayJurisdictionName(effectiveJurisdiction)}.',
    LocationRefreshStatus.outsideCoverage => 'Ubicación detectada fuera de cobertura. Puedes elegir ciudad manualmente.',
    LocationRefreshStatus.permissionDenied => 'No hay permiso de ubicación. Puedes reintentar o elegir ciudad manualmente.',
    LocationRefreshStatus.permissionDeniedForever => 'Ubicación desactivada para PicoRadar. Puedes abrir la configuración del sistema o seleccionar ciudad manualmente.',
    LocationRefreshStatus.serviceDisabled =>
      'La ubicación del dispositivo está desactivada.',
    LocationRefreshStatus.positionUnavailable => 'No se pudo actualizar. Conservamos la última ciudad válida cuando existe.',
  };
}

Color _locationFeedbackColor(LocationRefreshStatus status) {
  return switch (status) {
    LocationRefreshStatus.detected => AppColors.teal,
    LocationRefreshStatus.permissionDenied ||
    LocationRefreshStatus.permissionDeniedForever ||
    LocationRefreshStatus.serviceDisabled ||
    LocationRefreshStatus.positionUnavailable ||
    LocationRefreshStatus.outsideCoverage => AppColors.orange,
    LocationRefreshStatus.idle ||
    LocationRefreshStatus.refreshing => AppColors.blue,
  };
}

bool _showsRetry(LocationRefreshStatus status) {
  return switch (status) {
    LocationRefreshStatus.permissionDenied ||
    LocationRefreshStatus.outsideCoverage ||
    LocationRefreshStatus.positionUnavailable => true,
    _ => false,
  };
}

bool _showsAppSettings(LocationRefreshStatus status) {
  return status == LocationRefreshStatus.permissionDeniedForever;
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
