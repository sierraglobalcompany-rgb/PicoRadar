import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';

final appStartupStopwatch = Stopwatch()..start();

void logStartupMarker(String marker, {String extra = ''}) {
  final message =
      '$marker elapsed_ms=${appStartupStopwatch.elapsedMilliseconds}'
      ' epoch_us=${DateTime.now().microsecondsSinceEpoch}$extra';
  developer.log(message, name: 'P01_STARTUP');
  debugPrint('P01_STARTUP $message');
}

Future<T> measureStartupPhase<T>(
  String phase,
  Future<T> Function() action,
) async {
  final timer = Stopwatch()..start();
  logStartupMarker('${phase}_BEGIN');
  var outcome = 'error';
  try {
    final result = await action();
    outcome = 'ok';
    return result;
  } finally {
    timer.stop();
    logStartupMarker(
      '${phase}_END',
      extra: ' outcome=$outcome duration_us=${timer.elapsedMicroseconds}',
    );
  }
}

void logStartupFrame(String marker, FrameTiming timing) {
  logStartupMarker(
    marker,
    extra:
        ' frame_number=${timing.frameNumber}'
        ' vsync_start_us=${timing.timestampInMicroseconds(FramePhase.vsyncStart)}'
        ' build_start_us=${timing.timestampInMicroseconds(FramePhase.buildStart)}'
        ' build_finish_us=${timing.timestampInMicroseconds(FramePhase.buildFinish)}'
        ' raster_finish_us=${timing.timestampInMicroseconds(FramePhase.rasterFinish)}'
        ' raster_epoch_us=${timing.timestampInMicroseconds(FramePhase.rasterFinishWallTime)}'
        ' build_us=${timing.buildDuration.inMicroseconds}'
        ' raster_us=${timing.rasterDuration.inMicroseconds}',
  );
}
