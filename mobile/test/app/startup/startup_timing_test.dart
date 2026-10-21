import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/startup/startup_timing.dart';

void main() {
  late List<String> messages;

  setUp(() {
    messages = [];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previous);
  });

  test('phase duration waits for work and preserves its result', () async {
    final gate = Completer<int>();
    final result = measureStartupPhase('TEST_PHASE', () => gate.future);
    expect(messages.single, contains('TEST_PHASE_BEGIN'));
    gate.complete(42);
    expect(await result, 42);
    expect(messages.last, contains('TEST_PHASE_END'));
    expect(messages.last, contains(' outcome=ok duration_us='));
  });

  test('failed phase preserves error without logging its contents', () async {
    final error = StateError('private-document-name');
    await expectLater(
      measureStartupPhase<void>('TEST_PHASE', () => Future.error(error)),
      throwsA(same(error)),
    );
    expect(messages.last, contains(' outcome=error duration_us='));
    expect(messages.join(), isNot(contains('private-document-name')));
  });

  test('frame marker records engine timestamps not callback arrival', () {
    logStartupFrame(
      'TEST_FRAME',
      FrameTiming(
        vsyncStart: 1000,
        buildStart: 1200,
        buildFinish: 1700,
        rasterStart: 1800,
        rasterFinish: 2500,
        rasterFinishWallTime: 100000,
      ),
    );
    expect(messages.single, contains(' build_start_us=1200'));
    expect(messages.single, contains(' raster_finish_us=2500'));
    expect(messages.single, contains(' build_us=500 raster_us=700'));
  });
}
