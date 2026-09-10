import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class PicoRadarBrandMark extends StatelessWidget {
  const PicoRadarBrandMark({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PicoRadar',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PicoRadarMarkPainter()),
      ),
    );
  }
}

class PicoRadarBrandLockup extends StatelessWidget {
  const PicoRadarBrandLockup({this.markSize = 36, this.textStyle, super.key});

  final double markSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PicoRadar',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PicoRadarBrandMark(size: markSize),
            const SizedBox(width: AppSpacing.s),
            Flexible(
              child: Text(
                'PicoRadar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (textStyle ?? AppTextStyles.h2).copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ColombianPlateBadge extends StatelessWidget {
  const ColombianPlateBadge({
    required this.plate,
    this.compact = false,
    this.registrationLabel,
    this.publicService = false,
    super.key,
  });

  final String plate;
  final bool compact;
  final String? registrationLabel;
  final bool publicService;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final registration = registrationLabel?.trim();
    final hasRegistration = registration != null && registration.isNotEmpty;
    final showCountry = !hasRegistration && !compact && textScale <= 1.6;
    final plateNumber = plate.toUpperCase();
    final separatedNumber =
        hasRegistration &&
        RegExp(r'^[A-Z]{3}(?:[0-9]{3}|[0-9]{2}[A-Z])$').hasMatch(plateNumber);
    final displayNumber = separatedNumber
        ? '${plateNumber.substring(0, 3)} ${plateNumber.substring(3)}'
        : plateNumber;
    final number = Text(
      displayNumber,
      maxLines: 1,
      style: AppTextStyles.h2.copyWith(
        color: hasRegistration ? Colors.black : const Color(0xFF101820),
        fontFamily: hasRegistration ? 'monospace' : null,
        fontSize: hasRegistration ? (compact ? 22 : 24) : null,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1,
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          // Monospaced groups leave the middle space clear for decoration.
          child: separatedNumber
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    number,
                    Positioned(
                      width: compact ? 5 : 6,
                      height: compact ? 5 : 6,
                      child: DecoratedBox(
                        key: const ValueKey('colombian-plate-separator'),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                )
              : number,
        ),
        if (hasRegistration) ...[
          const SizedBox(height: 2),
          Text(
            registration,
            key: const ValueKey('colombian-plate-registration-label'),
            textAlign: TextAlign.center,
            softWrap: true,
            style: AppTextStyles.caption.copyWith(
              color: Colors.black,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
        ] else if (showCountry) ...[
          const SizedBox(height: 2),
          Text(
            'COLOMBIA',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.navy,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      label: hasRegistration
          ? 'Placa ${plate.toUpperCase()}, $registration'
          : 'Placa ${plate.toUpperCase()}',
      excludeSemantics: hasRegistration,
      child: Container(
        key: const ValueKey('colombian-plate-badge'),
        constraints: BoxConstraints(
          minWidth: hasRegistration ? 116 : (compact ? 82 : 104),
          minHeight: compact ? 32 : 40,
          maxWidth: hasRegistration ? 160 : (compact ? 116 : 148),
        ),
        padding: hasRegistration
            ? const EdgeInsets.all(4)
            : EdgeInsets.symmetric(
                horizontal: compact ? AppSpacing.s : AppSpacing.m,
                vertical: compact ? AppSpacing.xs : AppSpacing.s,
              ),
        decoration: BoxDecoration(
          color: hasRegistration && publicService
              ? Colors.white
              : AppColors.plateYellow,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasRegistration ? Colors.black : AppColors.navy,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: hasRegistration
            ? Container(
                key: const ValueKey('colombian-plate-inner-border'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: compact ? 4 : 7,
                      ),
                      child: content,
                    ),
                    for (final top in [true, false])
                      for (final left in [true, false])
                        Positioned(
                          top: top ? 2 : null,
                          bottom: top ? null : 2,
                          left: left ? 3 : null,
                          right: left ? null : 3,
                          child: SizedBox.square(
                            dimension: 3,
                            child: DecoratedBox(
                              key: ValueKey(
                                'colombian-plate-fixing-${top ? 'top' : 'bottom'}-${left ? 'left' : 'right'}',
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              )
            : content,
      ),
    );
  }
}

class _PicoRadarMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = shortest * 0.08;
    final radius = shortest * 0.34;

    final radarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.teal;
    final needlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.blue;
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.navy;

    canvas.drawCircle(center, radius, radarPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.68),
      -math.pi * 0.12,
      math.pi * 1.05,
      false,
      radarPaint,
    );
    canvas.drawLine(
      center,
      Offset(center.dx + radius * 0.72, center.dy - radius * 0.42),
      needlePaint,
    );
    canvas.drawCircle(center, stroke * 1.1, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PicoRadarMarkPainter oldDelegate) => false;
}
