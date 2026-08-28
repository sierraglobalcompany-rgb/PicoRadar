part of 'home_screen.dart';

const _homeCarouselViewportFraction = 0.64;
const _homeCarouselBaseHeight = 260.0;

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
                final scale = 1.0 - (distance * 0.1);
                final opacity = 1.0 - (distance * 0.12);
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
    return scale >= 1.8 ? 352 : (scale >= 1.4 ? 312 : _homeCarouselBaseHeight);
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
        ? AppColors.red.withValues(alpha: widget.focused ? 0.72 : 0.42)
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
            final redGlow = reduceMotion ? 0.18 : 0.14 + (pulse * 0.16);
            final blueGlow = reduceMotion ? 0.12 : 0.14 + ((1 - pulse) * 0.16);
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: restricted && widget.focused
                    ? [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: redGlow),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(-4, 0),
                        ),
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: blueGlow),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(4, 0),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: AppColors.surface,
                elevation: widget.focused ? 2 : 1,
                shadowColor: AppColors.navy.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: BorderSide(color: border, width: restricted ? 1.4 : 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TodayChip(status: widget.snapshot.today.status),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
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
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
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
                const SizedBox(height: AppSpacing.xs),
                ColombianPlateBadge(
                  plate: widget.snapshot.vehicle.plate,
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.xs),
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
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), color: color, size: 16),
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
    final w = size.width;
    final h = size.height;
    final centerY = h * 0.6;
    final shadow = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.88),
        width: w * 0.66,
        height: h * 0.12,
      ),
      shadow,
    );

    if (vehicle.kind == VehicleKind.motorcycle) {
      _paintMotorcycle(canvas, size);
      return;
    }

    _paintCar(canvas, size, centerY);
  }

  void _paintCar(Canvas canvas, Size size, double centerY) {
    final w = size.width;
    final h = size.height;
    final bodyTop = centerY - h * 0.11;
    final bodyBottom = centerY + h * 0.24;
    final body = Path()
      ..moveTo(w * 0.16, bodyBottom)
      ..quadraticBezierTo(w * 0.13, centerY, w * 0.25, bodyTop)
      ..lineTo(w * 0.36, h * 0.34)
      ..quadraticBezierTo(w * 0.5, h * 0.18, w * 0.67, h * 0.35)
      ..lineTo(w * 0.8, bodyTop)
      ..quadraticBezierTo(w * 0.9, centerY, w * 0.84, bodyBottom)
      ..quadraticBezierTo(w * 0.55, bodyBottom + 8, w * 0.16, bodyBottom)
      ..close();
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.94),
          Color.lerp(color, AppColors.navy, 0.34)!,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(body, bodyPaint);
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final windowPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEAF4F8), Color(0xFF6F8798)],
      ).createShader(Offset.zero & size);
    final leftWindow = Path()
      ..moveTo(w * 0.38, h * 0.37)
      ..quadraticBezierTo(w * 0.47, h * 0.25, w * 0.5, h * 0.35)
      ..lineTo(w * 0.49, h * 0.52)
      ..lineTo(w * 0.33, h * 0.52)
      ..close();
    final rightWindow = Path()
      ..moveTo(w * 0.53, h * 0.35)
      ..quadraticBezierTo(w * 0.6, h * 0.28, w * 0.66, h * 0.39)
      ..lineTo(w * 0.73, h * 0.52)
      ..lineTo(w * 0.53, h * 0.52)
      ..close();
    canvas.drawPath(leftWindow, windowPaint);
    canvas.drawPath(rightWindow, windowPaint);

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.51, h * 0.36),
      Offset(w * 0.51, h * 0.53),
      highlight,
    );
    canvas.drawLine(
      Offset(w * 0.23, centerY),
      Offset(w * 0.34, centerY - 8),
      highlight,
    );
    canvas.drawLine(
      Offset(w * 0.68, centerY - 6),
      Offset(w * 0.78, centerY),
      highlight,
    );

    _paintWheel(canvas, Offset(w * 0.31, bodyBottom), h * 0.13);
    _paintWheel(canvas, Offset(w * 0.7, bodyBottom), h * 0.13);

    if (vehicle.serviceType == VehicleServiceType.taxi) {
      final roof = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.2),
          width: w * 0.22,
          height: h * 0.13,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(roof, Paint()..color = AppColors.plateYellow);
      canvas.drawRRect(
        roof,
        Paint()
          ..color = AppColors.navy.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintMotorcycle(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final y = h * 0.7;
    final accent = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = Color.lerp(color, AppColors.navy, 0.18)!;
    _paintWheel(canvas, Offset(w * 0.28, y), h * 0.16);
    _paintWheel(canvas, Offset(w * 0.73, y), h * 0.16);
    final frame = Path()
      ..moveTo(w * 0.3, y - h * 0.03)
      ..lineTo(w * 0.45, h * 0.5)
      ..lineTo(w * 0.58, y - h * 0.04)
      ..lineTo(w * 0.4, y - h * 0.03)
      ..lineTo(w * 0.3, y - h * 0.03);
    canvas.drawPath(frame, accent);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.52, h * 0.46),
          width: w * 0.22,
          height: h * 0.13,
        ),
        const Radius.circular(10),
      ),
      fill,
    );
    canvas.drawLine(
      Offset(w * 0.57, h * 0.43),
      Offset(w * 0.72, h * 0.34),
      accent,
    );
    canvas.drawLine(
      Offset(w * 0.7, h * 0.34),
      Offset(w * 0.77, h * 0.36),
      accent,
    );
    canvas.drawLine(
      Offset(w * 0.43, h * 0.42),
      Offset(w * 0.33, h * 0.36),
      accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.46, h * 0.36),
          width: w * 0.18,
          height: h * 0.05,
        ),
        const Radius.circular(12),
      ),
      fill,
    );
  }

  void _paintWheel(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF17202A));
    canvas.drawCircle(
      center,
      radius * 0.64,
      Paint()..color = const Color(0xFFF2F6F8),
    );
    canvas.drawCircle(center, radius * 0.34, Paint()..color = color);
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
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Icon(statusIcon(status), color: color, size: 20),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
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
