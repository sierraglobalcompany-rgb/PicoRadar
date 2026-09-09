import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../domain/camera_matcher.dart';

const drivingRadarSweepDuration = Duration(milliseconds: 3000);
const drivingRadarTrailWidthDegrees = 24.0;

enum DrivingVisualTargetKind { camera, toll }

/// Presentation data only: selection and heading reliability belong to the caller.
class DrivingVisualTarget {
  const DrivingVisualTarget({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.relativeBearingDegrees,
    required this.kind,
  });

  factory DrivingVisualTarget.fromCameraMatch(CameraMatch match) =>
      DrivingVisualTarget(
        id: match.camera.id,
        latitude: match.camera.latitude,
        longitude: match.camera.longitude,
        distanceMeters: match.distanceMeters,
        relativeBearingDegrees: match.relativeBearingDegrees,
        kind: DrivingVisualTargetKind.camera,
      );

  final String id;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double? relativeBearingDegrees;
  final DrivingVisualTargetKind kind;
}

Offset drivingVehicleAnchor(Size size, int coneDegrees) =>
    Offset(size.width / 2, size.height * (coneDegrees >= 360 ? 0.5 : 0.72));

double drivingRadarRadius(Size size, int coneDegrees) {
  final anchor = drivingVehicleAnchor(size, coneDegrees);
  return math.max(
    0,
    math.min(
      size.width / 2 - 22,
      coneDegrees >= 360 ? size.height / 2 - 22 : anchor.dy - 22,
    ),
  );
}

class DrivingRadarSweepSnapshot {
  const DrivingRadarSweepSnapshot({
    required this.angleDegrees,
    required this.direction,
    required this.echoIntensity,
  });

  final double angleDegrees;
  final double direction;
  final double echoIntensity;
}

class DrivingRadarView extends StatefulWidget {
  const DrivingRadarView({
    this.match,
    this.target,
    required this.currentPoint,
    required this.targetingConeDegrees,
    required this.alertColor,
    this.testSweepProgress,
    this.forceReducedMotionForTesting = false,
    super.key,
  }) : assert(match != null || target != null);

  final CameraMatch? match;
  final DrivingVisualTarget? target;
  DrivingVisualTarget get visualTarget =>
      target ?? DrivingVisualTarget.fromCameraMatch(match!);
  final DrivingPoint currentPoint;
  final int targetingConeDegrees;
  final Color alertColor;
  final double? testSweepProgress;
  final bool forceReducedMotionForTesting;

  @override
  State<DrivingRadarView> createState() => _DrivingRadarViewState();
}

class _DrivingRadarViewState extends State<DrivingRadarView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  var _disableAnimations = false;
  var _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: drivingRadarSweepDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncController();
  }

  @override
  void didUpdateWidget(covariant DrivingRadarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _syncController() {
    final shouldAnimate = _canAnimate;
    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  bool get _canAnimate {
    return mounted &&
        !widget.forceReducedMotionForTesting &&
        !_disableAnimations &&
        _tickerEnabled &&
        widget.testSweepProgress == null &&
        _lifecycleState == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        widget.forceReducedMotionForTesting || _disableAnimations;
    final animation = _canAnimate ? _controller : null;
    final fallbackProgress = widget.testSweepProgress ?? _controller.value;
    return Semantics(
      label:
          'Radar de ${widget.visualTarget.kind == DrivingVisualTargetKind.camera ? 'cámara' : 'peaje'} a ${widget.visualTarget.distanceMeters.round()} metros',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          key: ValueKey('driving-radar-cone-${widget.targetingConeDegrees}'),
          painter: DrivingRadarPainter(
            target: widget.visualTarget,
            currentPoint: widget.currentPoint,
            targetingConeDegrees: widget.targetingConeDegrees,
            alertColor: widget.alertColor,
            sweepProgress: fallbackProgress,
            sweepAnimation: animation,
            reducedMotion: reducedMotion,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class DrivingRadarPainter extends CustomPainter {
  DrivingRadarPainter({
    this.match,
    DrivingVisualTarget? target,
    required this.currentPoint,
    required this.targetingConeDegrees,
    required this.alertColor,
    required this.sweepProgress,
    required this.reducedMotion,
    this.sweepAnimation,
    this.trailWidthDegrees = drivingRadarTrailWidthDegrees,
  }) : target = target ?? DrivingVisualTarget.fromCameraMatch(match!),
       super(repaint: sweepAnimation);

  final CameraMatch? match;
  final DrivingVisualTarget target;
  final DrivingPoint currentPoint;
  final int targetingConeDegrees;
  final Color alertColor;
  final double sweepProgress;
  final Animation<double>? sweepAnimation;
  final bool reducedMotion;
  final double trailWidthDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF07111B);
    canvas.drawRect(Offset.zero & size, background);

    final user = drivingVehicleAnchor(size, targetingConeDegrees);
    final radarRadius = drivingRadarRadius(size, targetingConeDegrees);
    final radarRangeMeters = radarRangeForCameraDistance(target.distanceMeters);
    final coneDegrees = targetingConeDegrees.clamp(45, 360);
    final progress = sweepAnimation?.value ?? sweepProgress;
    final sweep = drivingRadarSweepSnapshot(
      targetingConeDegrees: coneDegrees,
      progress: progress,
      relativeBearingDegrees: target.relativeBearingDegrees,
      reducedMotion: reducedMotion,
      trailWidthDegrees: trailWidthDegrees,
    );

    _drawGrid(canvas, size);
    _drawCone(canvas, user, radarRadius, coneDegrees);
    _drawRadarGeometry(canvas, user, radarRadius, coneDegrees);
    _drawSweep(canvas, user, radarRadius, coneDegrees, sweep);

    final cameraPoint = drivingRadarTargetPoint(
      user: user,
      target: target,
      radarRadius: radarRadius,
      radarRangeMeters: radarRangeMeters,
    );
    if (cameraPoint != null) {
      _drawCameraEcho(canvas, cameraPoint, sweep.echoIntensity);
      _drawCameraMarker(canvas, cameraPoint);
    }
    _drawUserMarker(canvas, user);
    _drawRadarRangeLabel(canvas, radarRangeMeters);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..strokeWidth = 0.8;
    for (var x = size.width / 4; x < size.width; x += size.width / 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = size.height / 4; y < size.height; y += size.height / 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawCone(Canvas canvas, Offset user, double radius, int coneDegrees) {
    final conePaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;
    if (coneDegrees >= 360) {
      canvas.drawCircle(user, radius, conePaint);
      return;
    }
    final halfCone = coneDegrees * math.pi / 360;
    final coneRect = Rect.fromCircle(center: user, radius: radius);
    final cone = Path()
      ..moveTo(user.dx, user.dy)
      ..arcTo(coneRect, -math.pi / 2 - halfCone, halfCone * 2, false)
      ..close();
    canvas.drawPath(cone, conePaint);
  }

  void _drawRadarGeometry(
    Canvas canvas,
    Offset user,
    double radius,
    int coneDegrees,
  ) {
    final outerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    final radialPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    canvas.drawCircle(user, radius, outerPaint);
    canvas.drawCircle(user, radius * 0.66, innerPaint);
    canvas.drawCircle(user, radius * 0.33, innerPaint);

    if (coneDegrees >= 360) {
      for (var angle = 0.0; angle < 360; angle += 30) {
        _drawRadial(canvas, user, radius, angle, radialPaint);
      }
      return;
    }

    final halfCone = coneDegrees / 2;
    _drawRadial(canvas, user, radius, -halfCone, radialPaint);
    _drawRadial(canvas, user, radius, halfCone, radialPaint);
    if (coneDegrees >= 90) {
      _drawRadial(canvas, user, radius, 0, radialPaint);
    }
  }

  void _drawSweep(
    Canvas canvas,
    Offset user,
    double radius,
    int coneDegrees,
    DrivingRadarSweepSnapshot sweep,
  ) {
    final clippedAngles = <double>[];
    const trailSteps = 12;
    for (var step = trailSteps; step >= 0; step--) {
      final t = step / trailSteps;
      final rawAngle =
          sweep.angleDegrees - sweep.direction * trailWidthDegrees * t;
      final angle = coneDegrees >= 360
          ? rawAngle
          : rawAngle.clamp(-coneDegrees / 2, coneDegrees / 2).toDouble();
      clippedAngles.add(angle);
      final alpha = 0.18 * math.pow(1 - t, 1.7);
      _drawRadial(
        canvas,
        user,
        radius,
        angle,
        Paint()
          ..color = AppColors.teal.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.0 + (1 - t) * 1.1,
      );
    }

    if (clippedAngles.length >= 2) {
      final trail = Path()..moveTo(user.dx, user.dy);
      for (final angle in clippedAngles) {
        final end = _radarOffset(user, radius, angle);
        trail.lineTo(end.dx, end.dy);
      }
      trail.close();
      canvas.drawPath(
        trail,
        Paint()
          ..color = AppColors.teal.withValues(alpha: 0.055)
          ..style = PaintingStyle.fill,
      );
    }

    _drawRadial(
      canvas,
      user,
      radius,
      sweep.angleDegrees,
      Paint()
        ..color = AppColors.teal.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.35,
    );
  }

  void _drawUserMarker(Canvas canvas, Offset user) {
    canvas.drawCircle(
      user,
      16,
      Paint()..color = AppColors.blue.withValues(alpha: 0.25),
    );
    canvas.drawCircle(user, 7.5, Paint()..color = AppColors.blue);
    final arrow = Path()
      ..moveTo(user.dx, user.dy - 16)
      ..lineTo(user.dx - 8, user.dy + 8)
      ..lineTo(user.dx, user.dy + 3.5)
      ..lineTo(user.dx + 8, user.dy + 8)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);
  }

  void _drawCameraEcho(Canvas canvas, Offset cameraPoint, double intensity) {
    if (intensity <= 0) {
      return;
    }
    canvas.drawCircle(
      cameraPoint,
      19 + 6 * intensity,
      Paint()
        ..color = alertColor.withValues(alpha: 0.30 * intensity)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      cameraPoint,
      16 + 6 * intensity,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawCameraMarker(Canvas canvas, Offset cameraPoint) {
    canvas.drawCircle(
      cameraPoint,
      16,
      Paint()..color = alertColor.withValues(alpha: 0.24),
    );
    canvas.drawCircle(cameraPoint, 10, Paint()..color = alertColor);
    canvas.drawCircle(cameraPoint, 4.5, Paint()..color = Colors.white);
    if (target.kind == DrivingVisualTargetKind.toll) {
      final bar = Paint()
        ..color = Colors.white
        ..strokeWidth = 2;
      canvas.drawLine(
        cameraPoint + const Offset(-7, -5),
        cameraPoint + const Offset(7, -5),
        bar,
      );
      canvas.drawLine(
        cameraPoint + const Offset(-6, -5),
        cameraPoint + const Offset(-6, 6),
        bar,
      );
      canvas.drawLine(
        cameraPoint + const Offset(6, -5),
        cameraPoint + const Offset(6, 6),
        bar,
      );
    }
  }

  void _drawRadial(
    Canvas canvas,
    Offset origin,
    double radius,
    double angleDegrees,
    Paint paint,
  ) {
    canvas.drawLine(origin, _radarOffset(origin, radius, angleDegrees), paint);
  }

  Offset _radarOffset(Offset origin, double radius, double angleDegrees) {
    final angle = angleDegrees * math.pi / 180;
    return Offset(
      origin.dx + math.sin(angle) * radius,
      origin.dy - math.cos(angle) * radius,
    );
  }

  void _drawRadarRangeLabel(Canvas canvas, double radarRangeMeters) {
    final painter = TextPainter(
      text: TextSpan(
        text: '${radarRangeMeters.round()} m',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.46),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, const Offset(8, 6));
  }

  @override
  bool shouldRepaint(covariant DrivingRadarPainter oldDelegate) {
    return oldDelegate.target.distanceMeters != target.distanceMeters ||
        oldDelegate.target.relativeBearingDegrees !=
            target.relativeBearingDegrees ||
        oldDelegate.target.kind != target.kind ||
        oldDelegate.currentPoint.latitude != currentPoint.latitude ||
        oldDelegate.currentPoint.longitude != currentPoint.longitude ||
        oldDelegate.targetingConeDegrees != targetingConeDegrees ||
        oldDelegate.alertColor != alertColor ||
        oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.reducedMotion != reducedMotion ||
        oldDelegate.trailWidthDegrees != trailWidthDegrees;
  }
}

DrivingRadarSweepSnapshot drivingRadarSweepSnapshot({
  required int targetingConeDegrees,
  required double progress,
  double? relativeBearingDegrees,
  bool reducedMotion = false,
  double trailWidthDegrees = drivingRadarTrailWidthDegrees,
}) {
  final coneDegrees = targetingConeDegrees.clamp(45, 360);
  final normalizedProgress = progress - progress.floorToDouble();
  if (reducedMotion) {
    final centeredAngle = relativeBearingDegrees ?? 0;
    return DrivingRadarSweepSnapshot(
      angleDegrees: _clampToCone(centeredAngle, coneDegrees),
      direction: 1,
      echoIntensity: 0,
    );
  }

  double angle;
  double direction;
  if (coneDegrees >= 360) {
    angle = normalizeRadarAngleDegrees(normalizedProgress * 360);
    direction = 1;
  } else {
    final outbound = normalizedProgress < 0.5;
    final travel = outbound
        ? normalizedProgress * 2
        : (1 - normalizedProgress) * 2;
    angle = -coneDegrees / 2 + coneDegrees * travel;
    direction = outbound ? 1 : -1;
  }

  var echoIntensity = 0.0;
  if (relativeBearingDegrees != null) {
    final bearing = _clampToCone(relativeBearingDegrees, coneDegrees);
    final distance = angularDistanceDegrees(angle, bearing);
    final echoWindow = trailWidthDegrees / 2;
    if (distance <= echoWindow) {
      echoIntensity = 1 - distance / echoWindow;
    }
  }
  return DrivingRadarSweepSnapshot(
    angleDegrees: angle,
    direction: direction,
    echoIntensity: echoIntensity.clamp(0.0, 1.0),
  );
}

double radarRangeForCameraDistance(double distanceMeters) {
  if (distanceMeters <= 80) {
    return 80;
  }
  if (distanceMeters <= 160) {
    return 160;
  }
  if (distanceMeters <= 320) {
    return 320;
  }
  return math.max(cameraAwarenessRadiusMeters, distanceMeters);
}

Offset? drivingRadarTargetPoint({
  required Offset user,
  required DrivingVisualTarget target,
  required double radarRadius,
  required double radarRangeMeters,
}) {
  final bearing = target.relativeBearingDegrees;
  if (bearing == null || !bearing.isFinite) return null;
  final radius =
      radarRadius * (target.distanceMeters / radarRangeMeters).clamp(0.0, 1.0);
  final angle = bearing * math.pi / 180;
  return user + Offset(math.sin(angle) * radius, -math.cos(angle) * radius);
}

Offset radarCameraPoint({
  required Size size,
  required Offset user,
  required CameraMatch match,
  required double radarRadius,
  required double radarRangeMeters,
}) {
  final relativeBearing = match.relativeBearingDegrees;
  if (relativeBearing == null) {
    return Offset(size.width / 2, math.max(22, user.dy - radarRadius * 0.64));
  }
  if (match.distanceMeters <= 5) {
    return user;
  }
  final distanceRatio = (match.distanceMeters / radarRangeMeters).clamp(
    0.0,
    1.0,
  );
  final radius = radarRadius * distanceRatio;
  final angle = relativeBearing * math.pi / 180;
  final point = Offset(
    user.dx + math.sin(angle) * radius,
    user.dy - math.cos(angle) * radius,
  );
  return Offset(
    point.dx.clamp(22.0, size.width - 22.0),
    point.dy.clamp(22.0, size.height - 22.0),
  );
}

double normalizeRadarAngleDegrees(double angleDegrees) {
  var angle = angleDegrees % 360;
  if (angle > 180) {
    angle -= 360;
  }
  if (angle <= -180) {
    angle += 360;
  }
  return angle;
}

double angularDistanceDegrees(double a, double b) {
  return normalizeRadarAngleDegrees(a - b).abs();
}

double _clampToCone(double angleDegrees, int coneDegrees) {
  final angle = normalizeRadarAngleDegrees(angleDegrees);
  if (coneDegrees >= 360) {
    return angle;
  }
  final halfCone = coneDegrees / 2;
  return angle.clamp(-halfCone, halfCone).toDouble();
}
