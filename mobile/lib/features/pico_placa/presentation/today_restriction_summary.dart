import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../domain/restriction_day_evaluation.dart';

class TodayRestrictionSummary extends ConsumerWidget {
  const TodayRestrictionSummary({
    required this.evaluation,
    required this.vehicleKind,
    required this.cityLabel,
    this.onTap,
    this.keyPrefix = 'home',
    super.key,
  });

  final RestrictionDayEvaluation evaluation;
  final VehicleKind vehicleKind;
  final String cityLabel;
  final VoidCallback? onTap;
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(bogotaNowProvider);
    final phase = restrictionPhaseAt(evaluation, now);
    final restrictedDay =
        evaluation.status == RestrictionDayStatus.restricted &&
        phase != RestrictionDayPhase.unknown;
    final unrestrictedDay = phase == RestrictionDayPhase.unrestricted;
    final countdown = _restrictionCountdown(evaluation, now);
    final main = switch (phase) {
      RestrictionDayPhase.unrestricted => 'Puede circular',
      RestrictionDayPhase.before ||
      RestrictionDayPhase.active ||
      RestrictionDayPhase.between => formatRestrictionWindows12(
        evaluation.effectiveWindows,
      ),
      RestrictionDayPhase.finished => 'Restricción finalizada',
      RestrictionDayPhase.unknown => 'Por verificar',
      RestrictionDayPhase.stale => 'Datos vencidos',
    };
    final supporting = switch (phase) {
      RestrictionDayPhase.unknown => 'Verifica ciudad y datos',
      RestrictionDayPhase.stale => 'Actualiza datos locales',
      RestrictionDayPhase.between => 'Sin restricción ahora',
      _ => null,
    };
    final accessiblePhase = switch (phase) {
      RestrictionDayPhase.active => 'Restricción activa: no puede circular',
      RestrictionDayPhase.before => 'Restricción pendiente de comenzar',
      _ => null,
    };
    final color = _summaryStatusColor(
      phase == RestrictionDayPhase.unknown
          ? RestrictionDayStatus.unknown
          : evaluation.status,
    );
    const iconSize = 56.0;
    return Semantics(
      button: onTap != null,
      onTap: onTap,
      label: onTap == null ? 'Pico y placa de hoy' : 'Ver pico y placa',
      value: [
        if (restrictedDay) 'Tiene pico y placa hoy',
        ?accessiblePhase,
        main,
        ?supporting,
        ?countdown,
        cityLabel,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('$keyPrefix-status-pico-action'),
          onTap: onTap,
          child: Container(
            key: ValueKey(
              keyPrefix == 'home'
                  ? 'home-status-today'
                  : '$keyPrefix-summary-today',
            ),
            color: Colors.transparent,
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  key: ValueKey('$keyPrefix-summary-status-icon'),
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Color.lerp(Colors.white, color, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: unrestrictedDay
                        ? Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.green,
                            size: iconSize * 0.82,
                          )
                        : SizedBox.square(
                            dimension: iconSize * 0.76,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  vehicleKind == VehicleKind.motorcycle
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
                              : unrestrictedDay
                              ? Color.lerp(Colors.white, AppColors.green, 0.12)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(
                          restrictedDay
                              ? 'Tiene pico y placa hoy'
                              : unrestrictedDay
                              ? 'Sin pico y placa hoy'
                              : 'Pico y placa',
                          key: ValueKey('$keyPrefix-summary-label'),
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: unrestrictedDay ? 13 : 14,
                            height: 1,
                            color: restrictedDay
                                ? AppColors.red
                                : unrestrictedDay
                                ? AppColors.green
                                : const Color(0xFFCDDBE6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _keepRestrictionTimesTogether(main),
                        key: ValueKey('$keyPrefix-summary-main'),
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 18,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (supporting != null && supporting.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _keepRestrictionTimesTogether(supporting),
                          key: ValueKey('$keyPrefix-summary-supporting'),
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 14,
                            height: 1.15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      if (countdown != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CountdownClockIcon(keyPrefix: keyPrefix),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                countdown,
                                key: ValueKey('$keyPrefix-summary-countdown'),
                                style: AppTextStyles.bodyStrong.copyWith(
                                  fontSize: 14,
                                  height: 1.15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
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
                              key: ValueKey('$keyPrefix-summary-city'),
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

class _CountdownClockIcon extends StatefulWidget {
  const _CountdownClockIcon({required this.keyPrefix});

  final String keyPrefix;

  @override
  State<_CountdownClockIcon> createState() => _CountdownClockIconState();
}

class _CountdownClockIconState extends State<_CountdownClockIcon>
    with WidgetsBindingObserver {
  final _step = ValueNotifier<int>(0);
  Timer? _timer;
  bool _visible = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    _syncTick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTick();
  }

  void _syncTick() {
    if (!_visible || !_foreground) {
      _timer?.cancel();
      _timer = null;
    } else {
      // Decorative seconds repaint only this icon, never the restriction clock.
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _step.value = (_step.value + 1) % 60;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: ValueKey('${widget.keyPrefix}-countdown-clock'),
    child: SizedBox.square(
      dimension: 16,
      child: CustomPaint(painter: _CountdownClockPainter(_step)),
    ),
  );
}

class _CountdownClockPainter extends CustomPainter {
  _CountdownClockPainter(this.step) : super(repaint: step);

  final ValueListenable<int> step;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, 6.5, stroke);
    canvas.drawLine(center, center + const Offset(2.5, 1.6), stroke);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(step.value * math.pi / 30);
    canvas.drawLine(Offset.zero, const Offset(0, -4.5), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CountdownClockPainter oldDelegate) =>
      oldDelegate.step != step;
}

String? _restrictionCountdown(
  RestrictionDayEvaluation evaluation,
  DateTime now,
) {
  final phase = restrictionPhaseAt(evaluation, now);
  final minute = now.hour * 60 + now.minute;
  int? target;
  String prefix;
  switch (phase) {
    case RestrictionDayPhase.before:
    case RestrictionDayPhase.between:
      target = nextRestrictionStartMinute(evaluation, now);
      prefix = phase == RestrictionDayPhase.before
          ? 'Empieza en'
          : 'Próximo tramo en';
    case RestrictionDayPhase.active:
      for (final window in evaluation.effectiveWindows) {
        if (minute >= window.startMinute && minute < window.endMinute) {
          target = window.endMinute;
          break;
        }
      }
      prefix = evaluation.effectiveWindows.length > 1
          ? 'Este tramo termina en'
          : 'Termina en';
    default:
      return null;
  }
  if (target == null || target <= minute) return null;
  // Window boundaries are whole minutes: this also rounds partial minutes up.
  final remaining = target - minute;
  final hours = remaining ~/ 60;
  final minutes = remaining % 60;
  final duration = [
    if (hours > 0) '$hours h',
    if (minutes > 0) '$minutes min',
  ].join(' ');
  return '$prefix $duration';
}

String _keepRestrictionTimesTogether(String text) => text
    .replaceAll(' a. m.', '\u00a0a.\u00a0m.')
    .replaceAll(' p. m.', '\u00a0p.\u00a0m.');

Color _summaryStatusColor(RestrictionDayStatus status) => switch (status) {
  RestrictionDayStatus.restricted => AppColors.red,
  RestrictionDayStatus.allowed => AppColors.green,
  RestrictionDayStatus.unknown ||
  RestrictionDayStatus.stale => AppColors.orange,
};
