import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appClockNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final appClockProvider = NotifierProvider<AppClock, DateTime>(AppClock.new);

class AppClock extends Notifier<DateTime> {
  Timer? _timer;
  late DateTime Function() _now;
  bool _foreground = true;

  @override
  DateTime build() {
    _now = ref.watch(appClockNowProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    final instant = _now().toUtc();
    if (_foreground) {
      _schedule(instant);
    }
    return instant;
  }

  void setForeground(bool foreground) {
    _timer?.cancel();
    _timer = null;
    _foreground = foreground;
    if (_foreground) {
      _refresh();
    }
  }

  void _refresh() {
    final instant = _now().toUtc();
    state = instant;
    if (_foreground) {
      _schedule(instant);
    }
  }

  void _schedule(DateTime instant) {
    _timer?.cancel();
    // Re-read wall time on each tick and realign after device clock changes.
    final remaining =
        Duration.microsecondsPerMinute -
        instant.microsecondsSinceEpoch % Duration.microsecondsPerMinute;
    _timer = Timer(Duration(microseconds: remaining), _refresh);
  }
}

class AppClockLifecycleObserver extends WidgetsBindingObserver {
  AppClockLifecycleObserver({required this.clock, this.onResume});

  final AppClock? clock;
  final VoidCallback? onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    clock?.setForeground(resumed);
    if (resumed) {
      onResume?.call();
    }
  }
}
