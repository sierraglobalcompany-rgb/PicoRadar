part of 'home_screen.dart';

const _homeCarouselViewportFraction = 0.64;
const _homeCarouselBaseHeight = 300.0;
const _homeCarouselMinimumHeight = 188.0;

double _homeCarouselHeightForLayout(
  BuildContext context,
  double availableHeight,
  double availableWidth,
  List<HomeVehicleSnapshot> snapshots,
) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  if (!availableHeight.isFinite) {
    return _homeCarouselBaseHeight;
  }
  var minimum = scale >= 1.8
      ? 320.0
      : scale >= 1.4
      ? 260.0
      : _homeCarouselMinimumHeight;
  if (scale > 1.25) {
    final cardWidth = availableWidth * _homeCarouselViewportFraction - 16;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    for (final snapshot in snapshots) {
      final vehicle = snapshot.vehicle;
      final nickname = vehicle.nickname?.trim() ?? '';
      final brand = vehicle.brand?.trim() ?? '';
      painter.text = TextSpan(
        text: nickname.isNotEmpty
            ? nickname
            : brand.isNotEmpty
            ? brand
            : 'Mi vehículo',
        style: AppTextStyles.bodyStrong.copyWith(fontSize: 16, height: 1.2),
      );
      painter.layout(maxWidth: cardWidth - 88);
      final plateHeight = VehiclePlateBadge.contentHeight(
        context,
        vehicle,
        cardWidth - 24,
      );
      final needed = plateHeight + painter.height + 168;
      if (needed > minimum) minimum = needed.ceilToDouble();
    }
    painter.dispose();
  }
  return availableHeight.floorToDouble().clamp(
    minimum,
    minimum > 360 ? minimum : 360.0,
  );
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
              child: RepaintBoundary(
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
                  child: Transform.scale(scale: scale, child: child),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HomeVehicleCard extends StatelessWidget {
  const _HomeVehicleCard({
    required this.snapshot,
    required this.focused,
    required this.onTap,
  });

  final HomeVehicleSnapshot snapshot;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.today.status;
    final color = statusColor(status);
    final vehicle = snapshot.vehicle;
    final nickname = vehicle.nickname?.trim();
    final brand = vehicle.brand?.trim();
    final name = nickname != null && nickname.isNotEmpty
        ? nickname
        : brand != null && brand.isNotEmpty
        ? brand
        : 'Mi vehículo';
    return Semantics(
      button: true,
      label: '${snapshot.vehicle.plate}, ${todayStatusText(status)}',
      child: Material(
        color: AppColors.surface,
        elevation: focused ? 4 : 2,
        shadowColor: color.withValues(alpha: 0.4),
        animationDuration: Duration.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: color.withValues(alpha: focused ? 0.8 : 0.45),
            width: 1.4,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('home-vehicle-card-${snapshot.vehicle.id}'),
          onTap: onTap,
          child: Column(
            children: [
              Container(
                key: ValueKey('home-vehicle-name-band-${vehicle.id}'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                color: color.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    Icon(
                      statusIcon(status),
                      key: ValueKey('home-vehicle-status-${vehicle.id}'),
                      semanticLabel: todayStatusText(status),
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        key: ValueKey('home-vehicle-name-${vehicle.id}'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                    ),
                    // Balance the status icon and its gap around the title.
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _GenericVehicleVisual(
                    vehicle: snapshot.vehicle,
                    useProductionAsset: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                child: Center(
                  child: VehiclePlateBadge(vehicle: vehicle, compact: true),
                ),
              ),
            ],
          ),
        ),
      ),
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

class _CarouselIndicator extends StatelessWidget {
  const _CarouselIndicator({required this.count, required this.index});

  static const _maximumVisibleDots = 7;
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox.shrink();
    }
    final visibleCount = count < _maximumVisibleDots
        ? count
        : _maximumVisibleDots;
    final firstVisible = (index - visibleCount ~/ 2)
        .clamp(0, count - visibleCount)
        .toInt();
    return Center(
      child: Semantics(
        label: 'Vehículo ${index + 1} de $count',
        child: Row(
          key: const ValueKey('home-carousel-indicator'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = firstVisible; i < firstVisible + visibleCount; i += 1)
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
