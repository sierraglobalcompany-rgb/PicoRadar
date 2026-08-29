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
          _ObligationStatusCard(
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
          _ObligationStatusCard(
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
        ];
        return Column(
          key: const ValueKey('home-status-grid'),
          children: [
            _TomorrowStatusStrip(snapshot: snapshot),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: width,
                    height: twoColumns ? 78 : null,
                    child: card,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TomorrowStatusStrip extends StatelessWidget {
  const _TomorrowStatusStrip({required this.snapshot});

  final HomeVehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'MAÑANA, ${_tomorrowValue(snapshot.tomorrow)}, ${_tomorrowMessage(snapshot.tomorrow)}',
      child: Container(
        key: const ValueKey('home-status-tomorrow'),
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              'MAÑANA',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.orange,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScaleDownText(
                    _tomorrowValue(snapshot.tomorrow),
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 14.5,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    _tomorrowMessage(snapshot.tomorrow),
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
          ],
        ),
      ),
    );
  }
}

class _ObligationStatusCard extends StatelessWidget {
  const _ObligationStatusCard({
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
        padding: const EdgeInsets.all(8),
        backgroundColor: color.withValues(alpha: 0.06),
        borderColor: color.withValues(alpha: 0.2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScaleDownText(
                    title,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  _ScaleDownText(
                    value,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 14,
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
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScaleDownText extends StatelessWidget {
  const _ScaleDownText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: style,
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: 10,
            ),
            backgroundColor: AppColors.teal,
            borderColor: AppColors.teal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
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
                            fontSize: 18,
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
