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
            if (_tomorrowAddsInformation(snapshot)) ...[
              _TomorrowStatusStrip(snapshot: snapshot),
              const SizedBox(height: AppSpacing.s),
            ],
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: width,
                    height: twoColumns ? 64 * textScale.clamp(1.0, 1.25) : null,
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

bool _tomorrowAddsInformation(HomeVehicleSnapshot snapshot) {
  return snapshot.tomorrow.status != RestrictionDayStatus.allowed ||
      snapshot.today.status != RestrictionDayStatus.allowed;
}

class _TomorrowStatusStrip extends StatelessWidget {
  const _TomorrowStatusStrip({required this.snapshot});

  final HomeVehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final evaluation = snapshot.tomorrow;
    final value = switch (evaluation.status) {
      RestrictionDayStatus.restricted =>
        evaluation.effectiveWindows.isEmpty
            ? 'Pico y placa'
            : formatRestrictionWindows12(evaluation.effectiveWindows),
      RestrictionDayStatus.allowed => 'Puede circular',
      RestrictionDayStatus.unknown => 'Sin confirmar',
      RestrictionDayStatus.stale => 'Datos pendientes',
    };
    final message = switch (evaluation.status) {
      RestrictionDayStatus.restricted => 'Pico y placa',
      RestrictionDayStatus.allowed => 'Sin restricción local',
      RestrictionDayStatus.unknown => 'Verifica ciudad y datos',
      RestrictionDayStatus.stale => 'Actualiza datos locales',
    };

    return Semantics(
      button: true,
      label: 'Ver pico y placa',
      value: '$value, $message',
      child: Material(
        key: const ValueKey('home-status-tomorrow'),
        color: AppColors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            picoShellLocation(
              origin: PicoRouteOrigin.home,
              vehicleId: snapshot.vehicle.id,
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.2),
              ),
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
                SizedBox(
                  width: 72,
                  child: _ScaleDownText(
                    'Pico y placa',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.orange,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.orange.withValues(alpha: 0.2),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ScaleDownText(
                        value,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 14.5,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'Mañana · $message',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.navy.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.orange,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayRestrictionSummary extends StatelessWidget {
  const _TodayRestrictionSummary({
    required this.snapshot,
    required this.selectedJurisdiction,
  });

  final HomeVehicleSnapshot snapshot;
  final RestrictionJurisdiction? selectedJurisdiction;

  @override
  Widget build(BuildContext context) => TodayRestrictionSummary(
    evaluation: snapshot.today,
    vehicleKind: snapshot.vehicle.kind,
    serviceType: snapshot.vehicle.serviceType,
    jurisdictionId: selectedJurisdiction?.id,
    cityLabel: selectedJurisdiction == null
        ? 'Seleccionar ciudad'
        : _displayJurisdictionName(selectedJurisdiction!),
    onTap: () => context.push(
      picoShellLocation(
        origin: PicoRouteOrigin.home,
        vehicleId: snapshot.vehicle.id,
      ),
    ),
  );
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
