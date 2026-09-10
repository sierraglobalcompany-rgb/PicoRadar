import 'dart:developer' as developer;
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/branding.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/pico_placa/data/restriction_store.dart';
import '../../features/visual_assets/data/vehicle_visual_resolver.dart';
import '../../features/visual_assets/presentation/visual_asset_widgets.dart';
import '../app_providers.dart';
import '../theme/app_tokens.dart';
import 'startup_timing.dart';

// Privacy cleanup is shared across core-data invalidations, never deferred.
final startupPrivacyCleanupProvider = FutureProvider<void>((ref) async {
  final store = ref.watch(privateVehicleDocumentStoreProvider);
  final gateway = ref.watch(vehicleDocumentGatewayProvider);
  await measureStartupPhase('PRIVACY_VIEWER', store.purgeViewerCache);
  await measureStartupPhase('PRIVACY_PICKER', gateway.clearTemporaryFiles);
});

final startupReadinessProvider = FutureProvider.autoDispose<StartupReadiness>((
  ref,
) async {
  Future<T> ready<T>(Future<T> future) async {
    final value = await future;
    if (!ref.mounted) throw StateError('Startup readiness superseded');
    return value;
  }

  await ready(ref.watch(startupPrivacyCleanupProvider.future));
  // This measures waiting for the shared DB/bootstrap work, not exclusive I/O.
  await ready(
    measureStartupPhase(
      'DB_BUNDLED_WAIT',
      () => ref.watch(bundledRestrictionsProvider.future),
    ),
  );
  return measureStartupPhase('CORE_READINESS', () async {
    final vehicles = await ready(ref.watch(vehicleListProvider.future));
    final activeVehicle = await ready(ref.watch(activeVehicleProvider.future));
    final jurisdictions = await ready(
      ref.watch(restrictionJurisdictionsProvider.future),
    );
    final selectedJurisdictionId = await ready(
      ref.watch(selectedPicoJurisdictionIdProvider.future),
    );
    await ready(ref.watch(picoAlertPreferencesProvider.future));

    final selectedJurisdiction = _jurisdictionById(
      jurisdictions,
      selectedJurisdictionId,
    );
    final snapshots = await ready(
      ref.watch(
        homeVehicleSnapshotsProvider(
          HomeVehicleSnapshotsRequest(
            vehicles: vehicles,
            selectedJurisdiction: selectedJurisdiction,
          ),
        ).future,
      ),
    );

    // Reuse available visual metadata; optional catalogs never block core access.
    final avatarCatalog = ref.read(avatarCatalogProvider).asData?.value;
    final selectedAvatar = ref.read(selectedAvatarIdProvider);
    final vehicleCatalog = ref.read(vehicleVisualCatalogProvider).asData?.value;
    final imageAssets = <ImageProvider<Object>>{
      if ((avatarCatalog?.assetById(selectedAvatar.asData?.value) ??
              avatarCatalog?.defaultAsset)
          case final avatar? when selectedAvatar.hasValue)
        visualAssetImageProvider(
          avatar.asset,
          cacheWidth: 112,
          cacheHeight: 112,
        ),
    };

    if (snapshots.isNotEmpty && vehicleCatalog != null) {
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
        final override = ref.read(vehicleVisualOverrideProvider(vehicle.id));
        if (!override.hasValue) continue;
        final visual = resolver.resolve(
          vehicle,
          overrideId: override.asData?.value,
        );
        if (visual != null) {
          imageAssets.add(
            visualAssetImageProvider(visual.asset, cacheWidth: 360),
          );
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

  final List<ImageProvider<Object>> imageAssets;
  final int vehicleCount;
  final String? selectedJurisdictionId;
}

class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({
    required this.child,
    this.isHomeRoute,
    this.onFirstContentFrame,
    this.frameNumberForTesting,
    super.key,
  });

  final Widget child;
  final bool Function()? isHomeRoute;
  final VoidCallback? onFirstContentFrame;
  @visibleForTesting
  final int Function()? frameNumberForTesting;

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
      // This SDK's engine passes its presentation target to onBeginFrame.
      final frameTarget = binding.currentSystemFrameTimeStamp.inMicroseconds;
      final frameNumber =
          widget.frameNumberForTesting?.call() ??
          binding.platformDispatcher.frameData.frameNumber;
      final postFrameTimelineUs = developer.Timeline.now;
      final marker = resumed
          ? (isHome ? 'HOME_RESUME' : 'APP_RESUME')
          : (isHome ? 'HOME_FIRST_USABLE' : 'STARTUP_CONTENT');
      logStartupMarker(
        '${marker}_FRAME',
        extra:
            ' boundary=framework_post_frame frame_number=$frameNumber frame_target_us=$frameTarget'
            ' post_frame_timeline_us=$postFrameTimelineUs',
      );
      final previous = _contentTimingsCallback;
      if (previous != null) binding.removeTimingsCallback(previous);
      _contentTimingsCallback = null;
      if (frameNumber < 0) {
        logStartupMarker(
          'STARTUP_CONTENT_TIMING_UNAVAILABLE',
          extra: ' reason=frame_id_missing',
        );
        if (!resumed) widget.onFirstContentFrame?.call();
        return;
      }
      _contentTimingsCallback = (timings) {
        for (var index = 0; index < timings.length; index++) {
          final timing = timings[index];
          if (timing.frameNumber < frameNumber) continue;
          binding.removeTimingsCallback(_contentTimingsCallback!);
          _contentTimingsCallback = null;
          if (timing.frameNumber == frameNumber) {
            logStartupFrame('${marker}_RASTER', timing);
          } else {
            // One bounded batch of raw values; never substitute a later frame.
            final first = index > 0 ? index - 1 : 0;
            for (final nearby in timings.skip(first).take(3)) {
              logStartupFrame('STARTUP_FRAME_PROBE', nearby);
            }
            logStartupMarker('STARTUP_CONTENT_TIMING_UNAVAILABLE');
          }
          return;
        }
      };
      binding.addTimingsCallback(_contentTimingsCallback!);
      if (!resumed) widget.onFirstContentFrame?.call();
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
                  ref.invalidate(startupPrivacyCleanupProvider);
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
          ref.invalidate(startupPrivacyCleanupProvider);
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
        if (!context.mounted) return;
        await precacheImage(asset, context);
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
