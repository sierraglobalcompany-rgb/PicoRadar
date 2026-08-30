import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

final appStartupStopwatch = Stopwatch()..start();

void logStartupMarker(String marker, {String extra = ''}) {
  final message =
      '$marker elapsed_ms=${appStartupStopwatch.elapsedMilliseconds}$extra';
  developer.log(message, name: 'P01_STARTUP');
  debugPrint('P01_STARTUP $message');
}
