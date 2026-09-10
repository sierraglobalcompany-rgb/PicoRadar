part of 'home_screen.dart';

class _FocusedStatusGrid extends ConsumerWidget {
  const _FocusedStatusGrid({
    required this.snapshot,
    required this.selectedJurisdiction,
  });

  final HomeVehicleSnapshot snapshot;
  final RestrictionJurisdiction? selectedJurisdiction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligations = ref.watch(
      vehicleObligationsProvider(snapshot.vehicle.id),
    );
    return obligations.when(
      data: (items) => _StatusGrid(
        snapshot: snapshot,
        obligations: items,
        selectedJurisdiction: selectedJurisdiction,
      ),
      loading: () => _StatusGrid(
        snapshot: snapshot,
        obligations: null,
        obligationsFailed: obligations.hasError,
        selectedJurisdiction: selectedJurisdiction,
      ),
      error: (error, stackTrace) => _StatusGrid(
        snapshot: snapshot,
        obligations: null,
        obligationsFailed: true,
        selectedJurisdiction: selectedJurisdiction,
      ),
    );
  }
}

class _StatusGrid extends ConsumerWidget {
  const _StatusGrid({
    required this.snapshot,
    required this.obligations,
    required this.selectedJurisdiction,
    this.obligationsFailed = false,
  });

  final HomeVehicleSnapshot snapshot;
  final List<VehicleObligation>? obligations;
  final bool obligationsFailed;
  final RestrictionJurisdiction? selectedJurisdiction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (year, month, day) = ref.watch(
      bogotaNowProvider.select((now) => (now.year, now.month, now.day)),
    );
    final now = DateTime(year, month, day);
    final pendingValue = obligationsFailed ? 'Por verificar' : 'Consultando';
    final pendingMessage = obligationsFailed
        ? 'No disponible'
        : 'Por verificar';
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
            value: obligations == null
                ? pendingValue
                : _obligationValue(
                    obligations!,
                    VehicleObligationType.soat,
                    now,
                  ),
            message: obligations == null
                ? pendingMessage
                : _obligationMessage(
                    obligations!,
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
            value: obligations == null
                ? pendingValue
                : _obligationValue(
                    obligations!,
                    VehicleObligationType.rtm,
                    now,
                  ),
            message: obligations == null
                ? pendingMessage
                : _obligationMessage(
                    obligations!,
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
            _TodayRestrictionSummary(
              snapshot: snapshot,
              selectedJurisdiction: selectedJurisdiction,
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: width,
                    height: twoColumns ? 72 : null,
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

class _TodayRestrictionSummary extends ConsumerWidget {
  const _TodayRestrictionSummary({
    required this.snapshot,
    required this.selectedJurisdiction,
  });

  final HomeVehicleSnapshot snapshot;
  final RestrictionJurisdiction? selectedJurisdiction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(bogotaNowProvider);
    final evaluation = snapshot.today;
    final phase = restrictionPhaseAt(evaluation, now);
    final restrictedDay = evaluation.status == RestrictionDayStatus.restricted;
    final unrestrictedDay = phase == RestrictionDayPhase.unrestricted;
    final cityLabel = selectedJurisdiction == null
        ? 'Seleccionar ciudad'
        : _displayJurisdictionName(selectedJurisdiction!);
    final nextStart = nextRestrictionStartMinute(evaluation, now);
    final main = switch (phase) {
      RestrictionDayPhase.unrestricted => 'Puede circular',
      RestrictionDayPhase.before =>
        nextStart == null
            ? 'Horario por confirmar'
            : 'Empieza a las ${formatRestrictionTime12(nextStart)}',
      RestrictionDayPhase.active => 'No puede circular',
      RestrictionDayPhase.between => 'Sin restricción ahora',
      RestrictionDayPhase.finished => 'Restricción finalizada',
      RestrictionDayPhase.unknown => 'Por verificar',
      RestrictionDayPhase.stale => 'Datos vencidos',
    };
    final supporting = switch (phase) {
      RestrictionDayPhase.unknown => 'Verifica ciudad y datos',
      RestrictionDayPhase.stale => 'Actualiza datos locales',
      _ =>
        restrictedDay
            ? formatRestrictionWindows12(evaluation.effectiveWindows)
            : null,
    };
    final color = statusColor(evaluation.status);
    const iconSize = 56.0;
    void openPico() => context.push(
      picoShellLocation(
        origin: PicoRouteOrigin.home,
        vehicleId: snapshot.vehicle.id,
      ),
    );
    return Semantics(
      button: true,
      onTap: openPico,
      label: 'Ver pico y placa',
      value: '$main, ${supporting ?? ''}, $cityLabel',
      excludeSemantics: true,
      child: Material(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('home-status-pico-action'),
          onTap: openPico,
          child: Container(
            key: const ValueKey('home-status-today'),
            color: Colors.transparent,
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  key: const ValueKey('home-summary-status-icon'),
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Color.lerp(Colors.white, color, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox.square(
                      dimension: iconSize * 0.76,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            snapshot.vehicle.kind == VehicleKind.motorcycle
                                ? Icons.two_wheeler_rounded
                                : Icons.directions_car_rounded,
                            color: AppColors.navy,
                            size: iconSize * 0.43,
                          ),
                          if (restrictedDay)
                            Icon(
                              Icons.block_rounded,
                              color: color,
                              size: iconSize * 0.76,
                            )
                          else
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  unrestrictedDay
                                      ? Icons.check_rounded
                                      : Icons.priority_high_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: restrictedDay
                              ? Color.lerp(Colors.white, AppColors.red, 0.12)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(
                          restrictedDay ? 'Pico y placa hoy' : 'Pico y placa',
                          key: const ValueKey('home-summary-label'),
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 14,
                            height: 1,
                            color: restrictedDay
                                ? AppColors.red
                                : const Color(0xFFCDDBE6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: unrestrictedDay
                              ? Border(
                                  bottom: BorderSide(color: color, width: 2),
                                )
                              : null,
                        ),
                        child: Text(
                          _keepRestrictionTimesTogether(main),
                          key: const ValueKey('home-summary-main'),
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 18,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: unrestrictedDay
                                ? Color.lerp(
                                    Colors.white,
                                    AppColors.green,
                                    0.28,
                                  )
                                : Colors.white,
                          ),
                        ),
                      ),
                      if (supporting != null && supporting.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _keepRestrictionTimesTogether(supporting),
                          key: const ValueKey('home-summary-windows'),
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 14,
                            height: 1.15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFCDDBE6),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cityLabel,
                              key: const ValueKey('home-summary-city'),
                              style: AppTextStyles.body.copyWith(
                                fontSize: 14,
                                height: 1.15,
                                color: const Color(0xFFCDDBE6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _keepRestrictionTimesTogether(String text) => text
    .replaceAll(' a. m.', '\u00a0a.\u00a0m.')
    .replaceAll(' p. m.', '\u00a0p.\u00a0m.');

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
