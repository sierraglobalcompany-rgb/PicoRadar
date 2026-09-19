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
}
