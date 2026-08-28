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
      viewportFraction: 0.78,
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
            AppSpacing.l,
            horizontalPadding,
            AppSpacing.xl,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(alertPreferences: widget.alertPreferences),
                  const SizedBox(height: AppSpacing.l),
                  _VehicleCarousel(
                    controller: _controller,
                    snapshots: widget.snapshots,
                    focusedIndex: _focusedIndex,
                    onChanged: (index) {
                      setState(() => _focusedIndex = index);
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
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
                  const SizedBox(height: AppSpacing.l),
                  _FocusedStatusGrid(snapshot: focused),
                  const SizedBox(height: AppSpacing.l),
                  _StartDrivingCta(
                    focusedVehicleId: focused.vehicle.id,
                    activeVehicleId: widget.activeVehicleId,
                  ),
                  const SizedBox(height: AppSpacing.l),
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
                markSize: 34,
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
        const SizedBox(height: AppSpacing.xl),
        Text('¡Hola!', style: AppTextStyles.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Así están tus vehículos hoy',
          style: AppTextStyles.body.copyWith(
            color: AppColors.navy.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _VehicleCarousel extends StatelessWidget {
  const _VehicleCarousel({
    required this.controller,
    required this.snapshots,
    required this.focusedIndex,
    required this.onChanged,
  });

  final PageController controller;
  final List<HomeVehicleSnapshot> snapshots;
  final int focusedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carrusel de vehículos',
      child: SizedBox(
        key: const ValueKey('home-vehicle-carousel'),
        height: _carouselHeight(context),
        child: PageView.builder(
          key: const ValueKey('home-vehicle-page-view'),
          controller: controller,
          itemCount: snapshots.length,
          pageSnapping: true,
          onPageChanged: onChanged,
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                var page = focusedIndex.toDouble();
                if (controller.hasClients &&
                    controller.position.haveDimensions &&
                    controller.page != null) {
                  page = controller.page!;
                }
                final distance = (page - index).abs().clamp(0.0, 1.0);
                final scale = 1.0 - (distance * 0.12);
                final opacity = 1.0 - (distance * 0.18);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                        vertical: AppSpacing.s,
                      ),
                      child: _HomeVehicleCard(
                        snapshot: snapshots[index],
                        focused: index == focusedIndex,
                        onTap: () => context.push(
                          '/garage/vehicle/${snapshots[index].vehicle.id}',
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  double _carouselHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return scale >= 1.8 ? 390 : (scale >= 1.4 ? 350 : 330);
  }
}

class _HomeVehicleCard extends StatefulWidget {
  const _HomeVehicleCard({
    required this.snapshot,
    required this.focused,
    required this.onTap,
  });

  final HomeVehicleSnapshot snapshot;
  final bool focused;
  final VoidCallback onTap;

  @override
  State<_HomeVehicleCard> createState() => _HomeVehicleCardState();
}

class _HomeVehicleCardState extends State<_HomeVehicleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.restrictedPulse,
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _HomeVehicleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reduceMotion(context);
    final restricted =
        widget.snapshot.today.status == RestrictionDayStatus.restricted;
    final border = restricted
        ? AppColors.red
        : AppColors.border.withValues(alpha: widget.focused ? 1 : 0.78);
    return Semantics(
      button: true,
      label:
          '${widget.snapshot.vehicle.plate}, ${todayStatusText(widget.snapshot.today.status)}',
      child: GestureDetector(
        key: ValueKey('home-vehicle-card-${widget.snapshot.vehicle.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulse = reduceMotion
                ? 0.0
                : (0.5 + (math.sin(_controller.value * math.pi * 2) * 0.5));
            final pulseColor = Color.lerp(
              AppColors.red,
              AppColors.blue,
              pulse,
            )!;
            return Material(
              color: AppColors.surface,
              elevation: widget.focused ? 4 : 1,
              shadowColor: restricted
                  ? pulseColor.withValues(alpha: reduceMotion ? 0.16 : 0.28)
                  : AppColors.navy.withValues(alpha: 0.09),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: BorderSide(
                  color: restricted && widget.focused ? pulseColor : border,
                  width: restricted ? 1.4 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TodayChip(status: widget.snapshot.today.status),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                    child: _GenericVehicleVisual(
                      vehicle: widget.snapshot.vehicle,
                    ),
                  ),
                ),
                Text(
                  _vehiclePrimaryLabel(widget.snapshot.vehicle),
                  key: ValueKey(
                    'home-vehicle-label-${widget.snapshot.vehicle.id}',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h2,
                ),
                if (_vehicleSecondaryLabel(widget.snapshot.vehicle) !=
                    null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _vehicleSecondaryLabel(widget.snapshot.vehicle)!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s),
                ColombianPlateBadge(plate: widget.snapshot.vehicle.plate),
                const SizedBox(height: AppSpacing.s),
                _TodaySummary(evaluation: widget.snapshot.today),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.focused &&
        widget.snapshot.today.status == RestrictionDayStatus.restricted;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }
}

class _TodayChip extends StatelessWidget {
  const _TodayChip({required this.status});

  final RestrictionDayStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), color: color, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              todayStatusText(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenericVehicleVisual extends StatelessWidget {
  const _GenericVehicleVisual({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey('home-generic-vehicle-${vehicle.id}'),
      painter: _VehiclePainter(vehicle, vehicleAccent(vehicle)),
      child: const SizedBox.expand(),
    );
  }
}

class _VehiclePainter extends CustomPainter {
  const _VehiclePainter(this.vehicle, this.color);

  final VehicleProfile vehicle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final soft = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.12);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final centerY = size.height * 0.58;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, centerY + 28),
        width: size.width * 0.7,
        height: 14,
      ),
      soft,
    );

    if (vehicle.kind == VehicleKind.motorcycle) {
      final y = centerY + 6;
      canvas.drawCircle(Offset(size.width * 0.27, y + 18), 16, stroke);
      canvas.drawCircle(Offset(size.width * 0.73, y + 18), 16, stroke);
      canvas.drawLine(
        Offset(size.width * 0.31, y + 14),
        Offset(size.width * 0.5, y - 16),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * 0.5, y - 16),
        Offset(size.width * 0.69, y + 12),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * 0.44, y - 6),
        Offset(size.width * 0.58, y - 6),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * 0.54, y - 18),
        Offset(size.width * 0.68, y - 30),
        stroke,
      );
      canvas.drawCircle(Offset(size.width * 0.45, y - 10), 5, paint);
      return;
    }

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.16, centerY - 16, size.width * 0.68, 46),
      const Radius.circular(18),
    );
    final cabin = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.31, centerY - 46, size.width * 0.34, 38),
      const Radius.circular(12),
    );
    canvas.drawRRect(body, soft);
    canvas.drawRRect(body, stroke);
    canvas.drawRRect(cabin, soft);
    canvas.drawRRect(cabin, stroke);
    canvas.drawCircle(Offset(size.width * 0.3, centerY + 30), 12, paint);
    canvas.drawCircle(Offset(size.width * 0.7, centerY + 30), 12, paint);
    if (vehicle.serviceType == VehicleServiceType.taxi) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, centerY - 56),
            width: 46,
            height: 18,
          ),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter oldDelegate) {
    return oldDelegate.vehicle != vehicle || oldDelegate.color != color;
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.evaluation});

  final RestrictionDayEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final status = evaluation.status;
    final color = statusColor(status);
    final windows = _formatWindows(evaluation.effectiveWindows);
    final main = switch (status) {
      RestrictionDayStatus.restricted => 'Hoy no puedes circular',
      RestrictionDayStatus.allowed => 'Estado hoy',
      RestrictionDayStatus.unknown => 'Sin confirmar',
      RestrictionDayStatus.stale => 'Datos pendientes',
    };
    final detail = status == RestrictionDayStatus.restricted && windows != null
        ? 'Aplica $windows'
        : todayStatusText(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Icon(statusIcon(status), color: color, size: 22),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  main,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.78),
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

class _CarouselIndicator extends StatelessWidget {
  const _CarouselIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Semantics(
        label: 'Vehículo ${index + 1} de $count',
        child: Row(
          key: const ValueKey('home-carousel-indicator'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i += 1)
              AnimatedContainer(
                key: ValueKey('home-carousel-dot-$i'),
                duration: AppMotion.fade,
                width: i == index ? 10 : 8,
                height: i == index ? 10 : 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i == index
                      ? AppColors.navy
                      : AppColors.navy.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: AppSpacing.m),
            Text(
              '${index + 1} de $count',
              key: const ValueKey('home-carousel-counter'),
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusedStatusGrid extends ConsumerWidget {
  const _FocusedStatusGrid({required this.snapshot});

  final HomeVehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligations = ref.watch(
      vehicleObligationsProvider(snapshot.vehicle.id),
    );
    return obligations.when(
      data: (items) => _StatusGrid(snapshot: snapshot, obligations: items),
      loading: () => const _StatusGridSkeleton(),
      error: (error, stackTrace) => _LoadError(message: error.toString()),
    );
  }
}

class _StatusGrid extends ConsumerWidget {
  const _StatusGrid({required this.snapshot, required this.obligations});

  final HomeVehicleSnapshot snapshot;
  final List<VehicleObligation> obligations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(bogotaNowProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final twoColumns = constraints.maxWidth >= 340 && textScale <= 1.6;
        final width = twoColumns
            ? (constraints.maxWidth - AppSpacing.m) / 2
            : constraints.maxWidth;
        final cards = [
          _HomeStatusCard(
            key: const ValueKey('home-status-tomorrow'),
            title: 'MAÑANA',
            value: _tomorrowValue(snapshot.tomorrow),
            message: _tomorrowMessage(snapshot.tomorrow),
            icon: Icons.calendar_month_rounded,
            color: AppColors.orange,
          ),
          _HomeStatusCard(
            key: const ValueKey('home-status-soat'),
            title: 'SOAT',
            value: _obligationValue(
              obligations,
              VehicleObligationType.soat,
              now,
            ),
            message: _obligationMessage(
              obligations,
              VehicleObligationType.soat,
              now,
            ),
            icon: Icons.shield_outlined,
            color: AppColors.green,
            onTap: () => context.push(
              '/apps/module/soat?vehicleId=${snapshot.vehicle.id}',
            ),
          ),
          _HomeStatusCard(
            key: const ValueKey('home-status-rtm'),
            title: 'Tecnomecánica',
            value: _obligationValue(
              obligations,
              VehicleObligationType.rtm,
              now,
            ),
            message: _obligationMessage(
              obligations,
              VehicleObligationType.rtm,
              now,
            ),
            icon: Icons.assignment_turned_in_outlined,
            color: AppColors.blue,
            onTap: () => context.push(
              '/apps/module/tecnomecanica?vehicleId=${snapshot.vehicle.id}',
            ),
          ),
          _HomeStatusCard(
            key: const ValueKey('home-status-comparendos'),
            title: 'Comparendos',
            value: 'Consultar',
            message: 'Verifica en fuente oficial',
            icon: Icons.fact_check_outlined,
            color: AppColors.navy,
            onTap: () => context.push(
              '/apps/module/comparendos?vehicleId=${snapshot.vehicle.id}',
            ),
          ),
        ];
        return Wrap(
          key: const ValueKey('home-status-grid'),
          spacing: AppSpacing.m,
          runSpacing: AppSpacing.m,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _HomeStatusCard extends StatelessWidget {
  const _HomeStatusCard({
    required this.title,
    required this.value,
    required this.message,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title, $value, $message',
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.m),
        backgroundColor: color.withValues(alpha: 0.06),
        borderColor: color.withValues(alpha: 0.2),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _StartDrivingCta extends ConsumerStatefulWidget {
  const _StartDrivingCta({
    required this.focusedVehicleId,
    required this.activeVehicleId,
  });

  final String focusedVehicleId;
  final String? activeVehicleId;

  @override
  ConsumerState<_StartDrivingCta> createState() => _StartDrivingCtaState();
}

class _StartDrivingCtaState extends ConsumerState<_StartDrivingCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reduceMotion(context);
    return GestureDetector(
      key: const ValueKey('home-start-driving'),
      behavior: HitTestBehavior.opaque,
      onTap: _startDriving,
      onTapDown: (_) {
        if (!reduceMotion) {
          setState(() => _pressed = true);
        }
      },
      onTapCancel: () {
        if (!reduceMotion) {
          setState(() => _pressed = false);
        }
      },
      onTapUp: (_) {
        if (!reduceMotion) {
          setState(() => _pressed = false);
        }
      },
      child: AnimatedScale(
        key: const ValueKey('home-driving-cta-scale'),
        scale: _pressed ? 0.985 : 1,
        duration: AppMotion.fade,
        curve: AppMotion.standardCurve,
        child: Semantics(
          button: true,
          label: 'Iniciar conducción',
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            backgroundColor: AppColors.teal,
            borderColor: AppColors.teal,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Iniciar conducción',
                        style: AppTextStyles.h2.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Todo listo para tu viaje',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startDriving() async {
    final router = GoRouter.of(context);
    if (widget.focusedVehicleId != widget.activeVehicleId) {
      await ref
          .read(vehicleRepositoryProvider)
          .setActiveVehicle(widget.focusedVehicleId);
      ref.invalidate(activeVehicleProvider);
    }
    router.go(AppRoute.drive.path);
  }
}

class _HomePromoBanner extends StatelessWidget {
  const _HomePromoBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('home-truthful-banner'),
      padding: const EdgeInsets.all(AppSpacing.l),
      backgroundColor: AppColors.navy,
      borderColor: AppColors.navy,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Más control, más tranquilidad.',
                    style: AppTextStyles.h2.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Próximamente nuevas funciones para ayudarte cada día.',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            CustomPaint(
              key: const ValueKey('home-banner-illustration'),
              size: const Size(88, 82),
              painter: _BannerIllustrationPainter(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerIllustrationPainter extends CustomPainter {
  const _BannerIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final phone = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 4, size.width * 0.42, size.height * 0.86),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      phone,
      Paint()..color = AppColors.surface.withValues(alpha: 0.16),
    );
    canvas.drawRRect(phone, stroke);
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.28),
      Offset(size.width * 0.38, size.height * 0.42),
      stroke..color = AppColors.blue,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.42),
      Offset(size.width * 0.3, size.height * 0.64),
      stroke,
    );
    final shield = Path()
      ..moveTo(size.width * 0.65, size.height * 0.12)
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.2,
        size.width * 0.88,
        size.height * 0.2,
      )
      ..lineTo(size.width * 0.84, size.height * 0.56)
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.76,
        size.width * 0.64,
        size.height * 0.86,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.76,
        size.width * 0.45,
        size.height * 0.56,
      )
      ..lineTo(size.width * 0.42, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.18,
        size.width * 0.65,
        size.height * 0.12,
      );
    canvas.drawPath(
      shield,
      Paint()..color = AppColors.teal.withValues(alpha: 0.92),
    );
    canvas.drawPath(shield, stroke..color = Colors.white);
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.48),
      Offset(size.width * 0.62, size.height * 0.58),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, size.height * 0.58),
      Offset(size.width * 0.75, size.height * 0.38),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BannerIllustrationPainter oldDelegate) => false;
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

class _NotificationSheet extends ConsumerWidget {
  const _NotificationSheet({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            key: const ValueKey('home-notification-sheet'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Alertas', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.s),
              const Text('Recordatorios locales, sin cuenta ni servidor.'),
              const SizedBox(height: AppSpacing.l),
              if (!alertPreferences.permissionRequested)
                PrimaryButton(
                  key: const ValueKey('home-enable-notifications'),
                  label: 'Activar notificaciones',
                  icon: Icons.notifications_active_outlined,
                  onPressed: () => _requestPermission(context, ref),
                )
              else if (!alertPreferences.permissionGranted)
                const Text(
                  'Permiso de notificaciones desactivado. Puedes habilitarlo desde los ajustes del sistema.',
                )
              else ...[
                SwitchListTile(
                  key: const ValueKey('pico-alerts-enabled'),
                  value: alertPreferences.enabled,
                  onChanged: (value) =>
                      _save(ref, alertPreferences.copyWith(enabled: value)),
                  title: const Text('Recordatorios habilitados'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  key: const ValueKey('pico-day-before-enabled'),
                  value: alertPreferences.dayBeforeEnabled,
                  onChanged: alertPreferences.enabled
                      ? (value) => _save(
                          ref,
                          alertPreferences.copyWith(dayBeforeEnabled: value),
                        )
                      : null,
                  title: const Text('Día anterior'),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  key: const ValueKey('pico-day-before-time'),
                  enabled:
                      alertPreferences.enabled &&
                      alertPreferences.dayBeforeEnabled,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Hora día anterior'),
                  trailing: Text(
                    _formatMinute(alertPreferences.dayBeforeMinute),
                  ),
                  onTap: () => _pickTime(
                    context,
                    ref,
                    initialMinute: alertPreferences.dayBeforeMinute,
                    onSelected: (minute) =>
                        alertPreferences.copyWith(dayBeforeMinute: minute),
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('pico-same-day-enabled'),
                  value: alertPreferences.sameDayEnabled,
                  onChanged: alertPreferences.enabled
                      ? (value) => _save(
                          ref,
                          alertPreferences.copyWith(sameDayEnabled: value),
                        )
                      : null,
                  title: const Text('Mismo día'),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  key: const ValueKey('pico-same-day-time'),
                  enabled:
                      alertPreferences.enabled &&
                      alertPreferences.sameDayEnabled,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm),
                  title: const Text('Hora mismo día'),
                  trailing: Text(_formatMinute(alertPreferences.sameDayMinute)),
                  onTap: () => _pickTime(
                    context,
                    ref,
                    initialMinute: alertPreferences.sameDayMinute,
                    onSelected: (minute) =>
                        alertPreferences.copyWith(sameDayMinute: minute),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermission(BuildContext context, WidgetRef ref) async {
    var granted = false;
    try {
      final scheduler = ref.read(picoNotificationSchedulerProvider);
      await scheduler.initialize();
      granted = await scheduler.requestPermission();
    } on MissingPluginException {
      granted = true;
    }
    await _save(
      ref,
      alertPreferences.copyWith(
        permissionRequested: true,
        permissionGranted: granted,
      ),
    );
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de notificaciones denegado.')),
      );
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required int initialMinute,
    required PicoAlertPreferences Function(int minute) onSelected,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialMinute ~/ 60,
        minute: initialMinute % 60,
      ),
    );
    if (selected == null) {
      return;
    }
    await _save(ref, onSelected((selected.hour * 60) + selected.minute));
  }

  Future<void> _save(WidgetRef ref, PicoAlertPreferences value) async {
    await savePicoAlertPreferences(ref.read(appPreferencesProvider), value);
    ref.invalidate(picoAlertPreferencesProvider);
    ref.invalidate(picoNotificationSyncProvider);
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
    return 'Sin fecha guardada';
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
