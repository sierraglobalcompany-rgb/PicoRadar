import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/branding.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/location/application/location_controller.dart';
import '../../features/pico_placa/data/restriction_store.dart';
import '../../features/visual_assets/data/vehicle_visual_resolver.dart';
import '../app_providers.dart';
import '../theme/app_tokens.dart';
import 'startup_timing.dart';

final startupReadinessProvider = FutureProvider<StartupReadiness>((ref) async {
  await ref.watch(bundledRestrictionsProvider.future);
  final vehicles = await ref.watch(vehicleListProvider.future);
  final activeVehicle = await ref.watch(activeVehicleProvider.future);
  final jurisdictions = await ref.watch(
    restrictionJurisdictionsProvider.future,
  );
  final selectedJurisdictionId = await ref.watch(
    selectedPicoJurisdictionIdProvider.future,
  );
  await ref.watch(picoAlertPreferencesProvider.future);
  await ref.watch(locationStateProvider.future);
  final avatarCatalog = await ref.watch(avatarCatalogProvider.future);
  final selectedAvatarId = await ref.watch(selectedAvatarIdProvider.future);
  final vehicleCatalog = await ref.watch(vehicleVisualCatalogProvider.future);
  await ref.watch(homeBannerConfigProvider.future);
  await ref.watch(homeBannerCampaignProvider.future);

  final visualOverrides = <String, String?>{};
  for (final vehicle in vehicles) {
    visualOverrides[vehicle.id] = await ref.watch(
      vehicleVisualOverrideProvider(vehicle.id).future,
    );
  }
  await Future.wait([
    for (final vehicle in vehicles)
      ref.watch(vehicleObligationsProvider(vehicle.id).future),
  ]);

  final selectedJurisdiction = _jurisdictionById(
    jurisdictions,
    selectedJurisdictionId,
  );
  final snapshots = await ref.watch(
    homeVehicleSnapshotsProvider(
      HomeVehicleSnapshotsRequest(
        vehicles: vehicles,
        selectedJurisdiction: selectedJurisdiction,
      ),
    ).future,
  );

  final imageAssets = <String>{
    if ((avatarCatalog.assetById(selectedAvatarId) ??
            avatarCatalog.defaultAsset)
        case final avatar?)
      avatar.asset,
  };

  if (snapshots.isNotEmpty) {
    final focusedIndex = pickInitialHomeVehicleIndex(
      snapshots: snapshots,
      activeVehicleId: activeVehicle?.id,
    );
    final resolver = VehicleVisualResolver(vehicleCatalog);
    for (final index in _initialVehicleIndexes(
      focusedIndex,
      snapshots.length,
    )) {
      final vehicle = snapshots[index].vehicle;
      final visual = resolver.resolve(
        vehicle,
        overrideId: visualOverrides[vehicle.id],
      );
      if (visual != null) {
        imageAssets.add(visual.asset);
      }
    }
  }

  logStartupMarker(
    'HOME_CRITICAL_DATA_READY',
    extra: ' vehicles=${vehicles.length}',
  );
  return StartupReadiness(
    imageAssets: imageAssets.toList(growable: false),
    vehicleCount: vehicles.length,
    selectedJurisdictionId: selectedJurisdiction?.id,
  );
});

class StartupReadiness {
  const StartupReadiness({
    required this.imageAssets,
    required this.vehicleCount,
    required this.selectedJurisdictionId,
  });

  final List<String> imageAssets;
  final int vehicleCount;
  final String? selectedJurisdictionId;
}

class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool _ready = false;
  Future<void>? _precacheFuture;

  @override
  void initState() {
    super.initState();
    logStartupMarker('STARTUP_GATE_VISIBLE');
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return AnimatedSwitcher(
        duration: _reducedMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: const ValueKey('startup-ready-child'),
          child: widget.child,
        ),
      );
    }

    final readiness = ref.watch(startupReadinessProvider);
    return readiness.when(
      data: (data) {
        _precacheFuture ??= _precacheInitialImages(context, data);
        return FutureBuilder<void>(
          future: _precacheFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StartupError(
                onRetry: () {
                  setState(() => _precacheFuture = null);
                  ref.invalidate(startupReadinessProvider);
                },
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const _StartupSurface();
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_ready) {
                setState(() => _ready = true);
              }
            });
            return const _StartupSurface();
          },
        );
      },
      loading: () => const _StartupSurface(),
      error: (error, stackTrace) => _StartupError(
        onRetry: () {
          setState(() => _precacheFuture = null);
          ref.invalidate(startupReadinessProvider);
        },
      ),
    );
  }

  Future<void> _precacheInitialImages(
    BuildContext context,
    StartupReadiness readiness,
  ) async {
    for (final asset in readiness.imageAssets) {
      await precacheImage(AssetImage(asset), context);
    }
    logStartupMarker(
      'HOME_VISUAL_READY',
      extra: ' image_count=${readiness.imageAssets.length}',
    );
  }
}

class _StartupSurface extends StatefulWidget {
  const _StartupSurface();

  @override
  State<_StartupSurface> createState() => _StartupSurfaceState();
}

class _StartupSurfaceState extends State<_StartupSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reducedMotion(context)) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reducedMotion(context);
    return ColoredBox(
      key: const ValueKey('startup-loader'),
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: reduceMotion
                    ? const AlwaysStoppedAnimation<double>(0)
                    : _controller,
                child: const PicoRadarBrandMark(size: 58),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'PicoRadar',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Preparando PicoRadar',
                key: const ValueKey('startup-loader-copy'),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.navy.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              SizedBox(
                width: 28,
                height: 28,
                child: reduceMotion
                    ? const CircularProgressIndicator(strokeWidth: 2.4)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('startup-error'),
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PicoRadarBrandMark(size: 48),
                const SizedBox(height: AppSpacing.l),
                Text(
                  'No pudimos preparar PicoRadar',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.copyWith(
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                FilledButton.icon(
                  key: const ValueKey('startup-retry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<int> _initialVehicleIndexes(int focusedIndex, int count) {
  final indexes = <int>{focusedIndex};
  if (focusedIndex > 0) {
    indexes.add(focusedIndex - 1);
  }
  if (focusedIndex + 1 < count) {
    indexes.add(focusedIndex + 1);
  }
  return indexes.toList(growable: false)..sort();
}

RestrictionJurisdiction? _jurisdictionById(
  List<RestrictionJurisdiction> jurisdictions,
  String? id,
) {
  if (id == null) {
    return null;
  }
  for (final jurisdiction in jurisdictions) {
    if (jurisdiction.id == id) {
      return jurisdiction;
    }
  }
  return null;
}

bool _reducedMotion(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  return (mediaQuery?.disableAnimations ?? false) ||
      (mediaQuery?.accessibleNavigation ?? false);
}
