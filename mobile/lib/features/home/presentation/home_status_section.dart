part of 'home_screen.dart';

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
        final twoColumns = constraints.maxWidth >= 300 && textScale <= 1.25;
        final width = twoColumns
            ? (constraints.maxWidth - AppSpacing.s) / 2
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
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                height: twoColumns ? 88 : null,
                child: card,
              ),
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
        padding: const EdgeInsets.all(AppSpacing.s),
        backgroundColor: color.withValues(alpha: 0.06),
        borderColor: color.withValues(alpha: 0.2),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 15,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded, color: color, size: 22),
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
            padding: const EdgeInsets.all(AppSpacing.m),
            backgroundColor: AppColors.teal,
            borderColor: AppColors.teal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Iniciar conducción',
                          style: AppTextStyles.h2.copyWith(
                            color: Colors.white,
                            fontSize: 19,
                          ),
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
      padding: const EdgeInsets.all(AppSpacing.m),
      backgroundColor: AppColors.navy,
      borderColor: AppColors.navy,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 84),
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
              size: const Size(72, 70),
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
