part of 'home_screen.dart';

const _homeCarouselViewportFraction = 0.64;
const _homeCarouselBaseHeight = 300.0;

double _homeCarouselHeightForLayout(BuildContext context, double maxHeight) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  if (!maxHeight.isFinite) {
    return _homeCarouselBaseHeight;
  }
  if (scale >= 1.8) {
    return (maxHeight * 0.34).clamp(260.0, 336.0);
  }
  if (scale >= 1.4) {
    return (maxHeight * 0.36).clamp(248.0, 324.0);
  }
  const fixedHomeChrome = 362.0;
  final fitHeight = maxHeight - fixedHomeChrome;
  final proportionalHeight = maxHeight * 0.38;
  return math.min(proportionalHeight, fitHeight).clamp(236.0, 360.0);
}

class _VehicleCarousel extends StatelessWidget {
  const _VehicleCarousel({
    required this.controller,
    required this.snapshots,
    required this.focusedIndex,
    required this.onChanged,
    required this.height,
  });

  final PageController controller;
  final List<HomeVehicleSnapshot> snapshots;
  final int focusedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carrusel de vehículos',
      child: SizedBox(
        key: const ValueKey('home-vehicle-carousel'),
        height: height,
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
                        vertical: AppSpacing.xs,
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
          child: Column(
            children: [
              _TodayStatusBand(status: widget.snapshot.today.status),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s,
                    AppSpacing.s,
                    AppSpacing.s,
                    0,
                  ),
                  child: _GenericVehicleVisual(
                    vehicle: widget.snapshot.vehicle,
                    useProductionAsset: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  0,
                  AppSpacing.m,
                  AppSpacing.s,
                ),
                child: _VehicleIdentityRow(vehicle: widget.snapshot.vehicle),
              ),
              _RestrictionFooter(evaluation: widget.snapshot.today),
            ],
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

class _TodayStatusBand extends StatelessWidget {
  const _TodayStatusBand({required this.status});

  final RestrictionDayStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon(status), color: color, size: 25),
          const SizedBox(width: AppSpacing.s),
          Flexible(
            child: Text(
              todayStatusText(status),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: AppTextStyles.h2.copyWith(
                fontSize: 20,
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

class _VehicleIdentityRow extends StatelessWidget {
  const _VehicleIdentityRow({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final type = Text(
      shortVehicleTypeLabel(vehicle),
      key: ValueKey('home-vehicle-label-${vehicle.id}'),
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: AppTextStyles.h2.copyWith(fontSize: scale >= 1.6 ? 17 : 19),
    );
    final plate = ColombianPlateBadge(plate: vehicle.plate, compact: true);

    if (scale >= 1.6) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: type),
          const SizedBox(height: AppSpacing.xs),
          plate,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: FittedBox(fit: BoxFit.scaleDown, child: type),
        ),
        const SizedBox(width: AppSpacing.s),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: plate),
        ),
      ],
    );
  }
}

class _GenericVehicleVisual extends StatelessWidget {
  const _GenericVehicleVisual({
    required this.vehicle,
    this.useProductionAsset = false,
  });

  final VehicleProfile vehicle;
  final bool useProductionAsset;

  @override
  Widget build(BuildContext context) {
    if (useProductionAsset) {
      return VehicleVisualImage(
        vehicle: vehicle,
        cacheWidth: 360,
        fallbackBuilder: (_) => _GenericVehicleVisual(vehicle: vehicle),
      );
    }
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

class _RestrictionFooter extends StatelessWidget {
  const _RestrictionFooter({required this.evaluation});

  final RestrictionDayEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final status = evaluation.status;
    if (status == RestrictionDayStatus.allowed) {
      return const SizedBox.shrink();
    }
    final color = statusColor(status);
    final windows = _formatWindows(evaluation.effectiveWindows);
    final main = switch (status) {
      RestrictionDayStatus.restricted =>
        windows == null
            ? 'No puede circular hoy'
            : 'No puede circular de $windows',
      RestrictionDayStatus.unknown => 'Sin confirmar',
      RestrictionDayStatus.stale => 'Datos pendientes',
      RestrictionDayStatus.allowed => '',
    };
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon(status), color: color, size: 16),
          const SizedBox(width: AppSpacing.s),
          Flexible(
            child: Text(
              main,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontSize: 11.8,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
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
