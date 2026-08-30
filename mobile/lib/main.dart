import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/startup/startup_timing.dart';

void _logFirstFrame(List<FrameTiming> timings) {
  logStartupMarker('FLUTTER_FIRST_FRAME');
  WidgetsBinding.instance.removeTimingsCallback(_logFirstFrame);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logStartupMarker('FLUTTER_MAIN_READY');
  WidgetsBinding.instance.addTimingsCallback(_logFirstFrame);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: PicoRadarApp()));
}
