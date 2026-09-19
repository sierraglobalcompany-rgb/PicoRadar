import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AlarmCapabilities {
  const AlarmCapabilities({
    this.supported = false,
    this.notifications = false,
    this.exact = false,
    this.fullScreen = false,
  });
  final bool supported, notifications, exact, fullScreen;
  bool get canSchedule => supported && notifications && exact;
}

enum AlarmTestState {
  idle,
  starting,
  ringing,
  snoozed,
  missed,
  stopped,
  failed,
}

class AlarmStatus {
  const AlarmStatus({required this.testState, this.failureCode});

  final AlarmTestState testState;
  final String? failureCode;

  factory AlarmStatus.fromMap(Map<String, dynamic>? value) {
    final state = AlarmTestState.values
        .where((state) => state.name == value?['testState'])
        .firstOrNull;
    if (state == null) throw const FormatException('Invalid alarm status.');
    final code = value?['failureCode'];
    return AlarmStatus(
      testState: state,
      failureCode: code == null
          ? null
          : _failureCodes.contains(code)
          ? code as String
          : 'ALARM_OPERATION_FAILED',
    );
  }

  String? get failureMessage =>
      failureCode == null ? null : alarmFailureMessage(failureCode);
}

const _failureCodes = {
  'NOTIFICATIONS_REQUIRED',
  'EXACT_ACCESS_REQUIRED',
  'ACCESS_REVOKED',
  'PERMISSION_CHECK_FAILED',
  'AUDIO_FOCUS_DENIED',
  'AUDIO_FOCUS_LOST',
  'PLAYBACK_FAILED',
  'RING_FAILED',
  'TONE_UNAVAILABLE',
  'FOREGROUND_START_FAILED',
  'FOREGROUND_TIMEOUT',
  'ALARM_INTERRUPTED',
  'EVENT_EXPIRED',
  'ALARM_BUSY',
  'STORAGE_FAILED',
  'PROJECTION_CORRUPT',
  'TOO_MANY_EVENTS',
  'SCHEDULE_FAILED',
  'CANCEL_FAILED',
  'RESTORE_FAILED',
  'ALARM_OPERATION_FAILED',
};

String alarmFailureMessage(String? code) => switch (code) {
  'NOTIFICATIONS_REQUIRED' ||
  'EXACT_ACCESS_REQUIRED' ||
  'ACCESS_REVOKED' ||
  'PERMISSION_CHECK_FAILED' =>
    'La alarma necesita permisos. Revísalos en los ajustes del teléfono.',
  'AUDIO_FOCUS_DENIED' ||
  'AUDIO_FOCUS_LOST' ||
  'PLAYBACK_FAILED' ||
  'RING_FAILED' ||
  'TONE_UNAVAILABLE' =>
    'No se pudo reproducir la alarma. Revisa el sonido y vuelve a probar.',
  _ => 'No se pudo iniciar la alarma. Revisa los permisos y vuelve a probar.',
};

class AlertAlarmGateway {
  const AlertAlarmGateway();
  static const channel = MethodChannel('co.picoradar.app/alerts');

  Future<AlarmCapabilities> capabilities() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const AlarmCapabilities();
    }
    try {
      final value = await channel.invokeMapMethod<String, dynamic>(
        'capabilities',
      );
      return AlarmCapabilities(
        supported: value?['supported'] == true,
        notifications: value?['notifications'] == true,
        exact: value?['exact'] == true,
        fullScreen: value?['fullScreen'] == true,
      );
    } on MissingPluginException {
      return const AlarmCapabilities();
    }
  }

  Future<void> requestPermissions() =>
      channel.invokeMethod('requestPermissions');

  Future<void> requestFullScreen() => channel.invokeMethod('requestFullScreen');
  Future<void> openNotificationSettings() =>
      channel.invokeMethod('openNotificationSettings');

  Future<Set<int>> reschedule(
    String scope,
    List<Map<String, Object>> events,
  ) async {
    final result = await channel.invokeListMethod<int>('reschedule', {
      'scope': scope,
      'events': events,
    });
    return result?.toSet() ?? {};
  }

  Future<void> cancel(String scope) async {
    try {
      await channel.invokeMethod<void>('cancel', {'scope': scope});
    } on MissingPluginException {
      // Older/iOS builds cannot have events created by this Android bridge.
    }
  }

  Future<Set<int>> pending() async {
    try {
      return (await channel.invokeListMethod<int>('pending'))?.toSet() ?? {};
    } on MissingPluginException {
      return {};
    }
  }

  Future<void> test() => channel.invokeMethod('test');

  // Explicit observation acknowledges the native failure latch. Scheduling and
  // pending-ID queries must never do this implicitly.
  Future<AlarmStatus> status() async {
    try {
      return AlarmStatus.fromMap(
        await channel.invokeMapMethod<String, dynamic>('status'),
      );
    } on MissingPluginException {
      return const AlarmStatus(testState: AlarmTestState.idle);
    }
  }
}
