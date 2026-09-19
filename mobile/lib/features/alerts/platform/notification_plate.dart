import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A generated plate illustration, never a private wallet image or attachment.
Future<BigPictureStyleInformation> notificationPlate(String plate) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(480, 180);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
    Paint()..color = const Color(0xFFFFD531),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 8, 464, 164),
      const Radius.circular(12),
    ),
    Paint()
      ..color = const Color(0xFF122D48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );
  final painter = TextPainter(
    text: TextSpan(
      text: plate,
      style: const TextStyle(
        color: Color(0xFF122D48),
        fontSize: 70,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 444);
  painter.paint(
    canvas,
    Offset((480 - painter.width) / 2, (180 - painter.height) / 2),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 180);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  painter.dispose();
  if (bytes == null) throw StateError('No se pudo preparar la vista de placa.');
  return BigPictureStyleInformation(
    ByteArrayAndroidBitmap(bytes.buffer.asUint8List()),
    hideExpandedLargeIcon: true,
  );
}
