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
    this.detailed = false,
    this.compactWidth = 96,
    this.micro = false,
    this.microNumberFontSize,
    super.key,
  });

  final String plate;
  final bool compact;
  final String? registrationLabel;
  final bool publicService;
  final bool detailed;
  final double compactWidth;
  final bool micro;
  final double? microNumberFontSize;

  static TextStyle numberStyle(bool compact, {bool micro = false}) => TextStyle(
    color: Colors.black,
    fontFamily: 'sans-serif-condensed',
    fontFamilyFallback: const ['Roboto'],
    fontSize: micro
        ? 15
        : compact
        ? 20
        : 32,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0,
  );

  static double detailedHeight({
    required String plate,
    required String registration,
    required double width,
    required TextScaler textScaler,
    bool compact = true,
    double compactWidth = 96,
  }) {
    final effectiveWidth = math.min(width, compact ? compactWidth : 180.0);
    final available = math.max(1.0, effectiveWidth - (compact ? 8 : 28));
    final number = plate.trim().toUpperCase();
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );
    Size measure(
      String value,
      TextStyle style, {
      double maxWidth = double.infinity,
    }) {
      painter.text = TextSpan(text: value, style: style);
      painter.layout(maxWidth: maxWidth);
      return painter.size;
    }

    final style = numberStyle(compact);
    double numberHeight;
    if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(number)) {
      final first = number.substring(0, 3);
      final last = number.substring(3);
      final a = measure(first, style);
      final b = measure(last, style);
      numberHeight = a.width + b.width + (compact ? 9 : 17) <= available
          ? math.max(a.height, b.height)
          : measure(first, style, maxWidth: available).height +
                measure(last, style, maxWidth: available).height +
                (compact ? 13 : 15);
    } else {
      numberHeight = measure(number, style, maxWidth: available).height;
    }
    final footer = measure(
      registration,
      TextStyle(
        fontSize: compact ? 10 : 11,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      maxWidth: math.max(1.0, available - (compact ? 20 : 0)),
    );
    painter.dispose();
    return math
        .max(
          compact ? 46 : effectiveWidth / 2.15,
          numberHeight + footer.height + (compact ? 13.4 : 24.4),
        )
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final registration = registrationLabel?.trim();
    if (detailed || (registration != null && registration.isNotEmpty)) {
      return _DetailedPlate(
        plate: plate,
        compact: compact,
        registration: registration == null || registration.isEmpty
            ? 'COLOMBIA'
            : registration,
        publicService: publicService,
        compactWidth: compactWidth,
        micro: micro,
        microNumberFontSize: microNumberFontSize,
      );
    }

    final showCountry =
        !compact && MediaQuery.textScalerOf(context).scale(1) <= 1.6;
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

class _DetailedPlate extends StatelessWidget {
  const _DetailedPlate({
    required this.plate,
    required this.compact,
    required this.registration,
    required this.publicService,
    required this.compactWidth,
    required this.micro,
    required this.microNumberFontSize,
  });

  final String plate;
  final bool compact;
  final String registration;
  final bool publicService;
  final double compactWidth;
  final bool micro;
  final double? microNumberFontSize;

  @override
  Widget build(BuildContext context) {
    final number = plate.trim().toUpperCase();
    // Presentation only: retain legacy six-character values without validation.
    final grouped = RegExp(r'^[A-Z0-9]{6}$').hasMatch(number);
    final style = ColombianPlateBadge.numberStyle(
      compact,
      micro: micro,
    ).copyWith(fontSize: micro ? microNumberFontSize : null);
    return Semantics(
      label: 'Placa $number, $registration',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? compactWidth : 180),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final numberWidth =
                width -
                (micro
                    ? 6
                    : compact
                    ? 8
                    : 28);
            final scaler = micro
                ? TextScaler.noScaling
                : MediaQuery.textScalerOf(context);
            double measure(String text) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
              )..layout();
              final measured = painter.width;
              painter.dispose();
              return measured;
            }

            final fitsRow =
                grouped &&
                measure(number.substring(0, 3)) +
                        measure(number.substring(3)) +
                        (micro
                            ? 7
                            : compact
                            ? 9
                            : 17) <=
                    numberWidth;
            final emblem = SizedBox.square(
              key: const ValueKey('colombian-plate-separator'),
              dimension: micro
                  ? 5.5
                  : compact
                  ? 7
                  : 9,
              child: const CustomPaint(painter: _PlateEmblemPainter()),
            );
            Widget group(String text, String key) => Text(
              text,
              key: ValueKey(key),
              textAlign: TextAlign.center,
              style: style,
            );

            Widget horizontalGroups() => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                group(number.substring(0, 3), 'colombian-plate-first-group'),
                SizedBox(
                  width: micro
                      ? 0.5
                      : compact
                      ? 1
                      : 4,
                ),
                emblem,
                SizedBox(
                  width: micro
                      ? 0.5
                      : compact
                      ? 1
                      : 4,
                ),
                group(number.substring(3), 'colombian-plate-last-group'),
              ],
            );
            final numberContent = micro && grouped
                ? SizedBox(
                    width: numberWidth,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: horizontalGroups(),
                    ),
                  )
                : fitsRow
                ? horizontalGroups()
                : grouped
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      group(
                        number.substring(0, 3),
                        'colombian-plate-first-group',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: emblem,
                      ),
                      group(number.substring(3), 'colombian-plate-last-group'),
                    ],
                  )
                : Text(number, textAlign: TextAlign.center, style: style);
            final footerText = Text(
              registration,
              key: const ValueKey('colombian-plate-registration-label'),
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                color: Colors.black,
                fontSize: micro
                    ? 7.5
                    : compact
                    ? 10
                    : 11,
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: 0,
              ),
            );
            Widget fixing(bool top, bool left) => Container(
              key: ValueKey(
                'colombian-plate-fixing-${top ? 'top' : 'bottom'}-${left ? 'left' : 'right'}',
              ),
              width: micro ? 4.5 : 6,
              height: micro ? 2 : 3,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(2),
              ),
            );

            final plate = Container(
              key: const ValueKey('colombian-plate-badge'),
              width: width,
              height: micro ? width / 2.15 : null,
              padding: EdgeInsets.all(
                micro
                    ? 2
                    : compact
                    ? 2.5
                    : 4,
              ),
              decoration: BoxDecoration(
                color: publicService ? Colors.white : AppColors.plateYellow,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Container(
                key: const ValueKey('colombian-plate-inner-border'),
                constraints: BoxConstraints(
                  minHeight: micro
                      ? width / 2.15 - 4
                      : compact
                      ? 41
                      : width / 2.15 - 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Colors.black,
                    width: compact ? 1.2 : 1.7,
                  ),
                ),
                child: micro && microNumberFontSize != null
                    ? Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                fixing(true, true),
                                fixing(true, false),
                              ],
                            ),
                          ),
                          // Preserve the number's available height; only unusual
                          // formats scale down, never the complete plate graphic.
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: grouped
                                  ? horizontalGroups()
                                  : Text(number, maxLines: 1, style: style),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Row(
                              children: [
                                fixing(false, true),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: SizedBox(
                                    height: 7.5 * 1.15,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: footerText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                fixing(false, false),
                              ],
                            ),
                          ),
                        ],
                      )
                    : compact
                    ? Padding(
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    2,
                                    1,
                                    2,
                                    0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      fixing(true, true),
                                      fixing(true, false),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                            ),
                            numberContent,
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Row(
                                children: [
                                  fixing(false, true),
                                  const SizedBox(width: 2),
                                  Expanded(child: footerText),
                                  const SizedBox(width: 2),
                                  fixing(false, false),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 4 : 8,
                              vertical: compact ? 4 : 5,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                numberContent,
                                const SizedBox(height: 3),
                                footerText,
                              ],
                            ),
                          ),
                          for (final top in [true, false])
                            for (final left in [true, false])
                              Positioned(
                                top: top ? (compact ? 1 : 3) : null,
                                bottom: top ? null : (compact ? 1 : 3),
                                left: left ? 8 : null,
                                right: left ? null : 8,
                                child: fixing(top, left),
                              ),
                        ],
                      ),
              ),
            );
            return micro
                ? MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.noScaling),
                    child: plate,
                  )
                : plate;
          },
        ),
      ),
    );
  }
}

class _PlateEmblemPainter extends CustomPainter {
  const _PlateEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final ink = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.square;
    canvas.drawCircle(const Offset(12, 12), 10, ink);
    // Original transit-inspired monogram, not an official authenticity seal.
    canvas.drawLine(const Offset(7, 7), const Offset(18, 7), ink);
    canvas.drawLine(const Offset(9, 10), const Offset(7, 17), ink);
    canvas.drawLine(const Offset(13, 10), const Offset(11, 17), ink);
    canvas.drawLine(const Offset(17, 10), const Offset(15, 17), ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlateEmblemPainter oldDelegate) => false;
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
