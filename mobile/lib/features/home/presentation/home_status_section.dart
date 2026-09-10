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
      loading: () => const _StatusGridSkeleton(),
      error: (error, stackTrace) => _LoadError(message: error.toString()),
    );
  }
}

class _StatusGrid extends ConsumerWidget {
  const _StatusGrid({
    required this.snapshot,
    required this.obligations,
    required this.selectedJurisdiction,
  });

  final HomeVehicleSnapshot snapshot;
  final List<VehicleObligation> obligations;
  final RestrictionJurisdiction? selectedJurisdiction;

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
            _TomorrowStatusStrip(
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

class _TomorrowStatusStrip extends StatelessWidget {
  const _TomorrowStatusStrip({
    required this.snapshot,
    required this.selectedJurisdiction,
  });

  final HomeVehicleSnapshot snapshot;
  final RestrictionJurisdiction? selectedJurisdiction;

  @override
  Widget build(BuildContext context) {
    final cityLabel = selectedJurisdiction == null
        ? 'Seleccionar ciudad'
        : _displayJurisdictionName(selectedJurisdiction!);
    void openPico() => context.push(
      picoShellLocation(
        origin: PicoRouteOrigin.home,
        vehicleId: snapshot.vehicle.id,
      ),
    );

    return Semantics(
      button: true,
      label: 'Ver pico y placa',
      value:
          '${_tomorrowValue(snapshot.tomorrow)}, ${_tomorrowMessage(snapshot.tomorrow)}',
      child: Material(
        color: AppColors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('home-status-tomorrow'),
          onTap: openPico,
          child: Container(
            constraints: const BoxConstraints(minHeight: 66),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.m,
                    AppSpacing.s,
                    AppSpacing.s,
                    AppSpacing.s,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.orange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 116),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ScaleDownText(
                              'Pico y placa',
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: AppColors.orange,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cityLabel,
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.navy.withValues(alpha: 0.72),
                                fontSize: 13,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: AppColors.orange.withValues(alpha: 0.2),
                ),
                Expanded(
                  key: const ValueKey('home-status-pico-action'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.m,
                      AppSpacing.s,
                      AppSpacing.m,
                      AppSpacing.s,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ScaleDownText(
                                _tomorrowValue(snapshot.tomorrow),
                                style: AppTextStyles.bodyStrong.copyWith(
                                  fontSize: 18,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _ScaleDownText(
                                'Mañana · ${_tomorrowMessage(snapshot.tomorrow)}',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 13,
                                  height: 1.05,
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
                          size: 22,
                        ),
                      ],
                    ),
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
