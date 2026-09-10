import 'dart:ui' show FramePhase, FrameTiming;

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
  await measureStartupPhase(
    'PRIVACY_VIEWER',
    () => ref.watch(privateVehicleDocumentStoreProvider).purgeViewerCache(),
  );
  await measureStartupPhase(
    'PRIVACY_PICKER',
    () => ref.watch(vehicleDocumentGatewayProvider).clearTemporaryFiles(),
  );
  // This measures waiting for the shared DB/bootstrap work, not exclusive I/O.
  await measureStartupPhase(
    'DB_BUNDLED_WAIT',
    () => ref.watch(bundledRestrictionsProvider.future),
  );
  return measureStartupPhase('CORE_READINESS', () async {
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
  const StartupGate({required this.child, this.isHomeRoute, super.key});

  final Widget child;
  final bool Function()? isHomeRoute;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  Future<void>? _precacheFuture;
  bool _contentFrameScheduled = false;
  int _frameMarkerGeneration = 0;
  void Function(List<FrameTiming>)? _contentTimingsCallback;

  void _scheduleContentFrameMarker({bool resumed = false}) {
    if (!resumed && _contentFrameScheduled) return;
    _contentFrameScheduled = true;
    final generation = ++_frameMarkerGeneration;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!mounted || generation != _frameMarkerGeneration) return;
      final isHome = widget.isHomeRoute?.call() ?? false;
      final vsyncStart = binding.currentSystemFrameTimeStamp.inMicroseconds;
      final marker = resumed
          ? (isHome ? 'HOME_RESUME' : 'APP_RESUME')
          : (isHome ? 'HOME_FIRST_USABLE' : 'STARTUP_CONTENT');
      logStartupMarker(
        '${marker}_FRAME',
        extra: ' boundary=framework_post_frame vsync_start_us=$vsyncStart',
      );
      final previous = _contentTimingsCallback;
      if (previous != null) binding.removeTimingsCallback(previous);
      _contentTimingsCallback = (timings) {
        for (final timing in timings) {
          final start = timing.timestampInMicroseconds(FramePhase.vsyncStart);
          if (start < vsyncStart) continue;
          binding.removeTimingsCallback(_contentTimingsCallback!);
          _contentTimingsCallback = null;
          if (start == vsyncStart) {
            logStartupFrame('${marker}_RASTER', timing);
          } else {
            logStartupMarker('STARTUP_CONTENT_TIMING_UNAVAILABLE');
          }
          return;
        }
      };
      binding.addTimingsCallback(_contentTimingsCallback!);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final callback = _contentTimingsCallback;
    if (callback != null) {
      WidgetsBinding.instance.removeTimingsCallback(callback);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) {
      // Observe the next natural frame; never request one for diagnostics.
      _scheduleContentFrameMarker(resumed: true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    logStartupMarker('STARTUP_GATE_VISIBLE');
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      _scheduleContentFrameMarker();
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
            _ready = true;
            _scheduleContentFrameMarker();
            return AnimatedSwitcher(
              duration: _reducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: const ValueKey('startup-ready-child'),
                child: widget.child,
              ),
            );
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
    await measureStartupPhase('IMAGE_PRECACHE', () async {
      for (final asset in readiness.imageAssets) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    logStartupMarker(
      'HOME_VISUAL_READY',
      extra:
          ' image_count=${readiness.imageAssets.length} meaning=precache_completed',
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
