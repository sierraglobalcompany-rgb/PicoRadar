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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PicoRadarBrandMark(size: markSize),
          const SizedBox(width: AppSpacing.s),
          Text(
            'PicoRadar',
            style: (textStyle ?? AppTextStyles.h2).copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ColombianPlateBadge extends StatelessWidget {
  const ColombianPlateBadge({
    required this.plate,
    this.compact = false,
    super.key,
  });

  final String plate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final showCountry = !compact && textScale <= 1.6;

    return Semantics(
      label: 'Placa ${plate.toUpperCase()}',
      child: Container(
        key: const ValueKey('colombian-plate-badge'),
        constraints: BoxConstraints(
          minWidth: compact ? 82 : 104,
          minHeight: compact ? 32 : 40,
          maxWidth: compact ? 116 : 148,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.s : AppSpacing.m,
          vertical: compact ? AppSpacing.xs : AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: AppColors.plateYellow,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.navy, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                plate.toUpperCase(),
                maxLines: 1,
                style: AppTextStyles.h2.copyWith(
                  color: const Color(0xFF101820),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ),
            if (showCountry) ...[
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
        ),
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
