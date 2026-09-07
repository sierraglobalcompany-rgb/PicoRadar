import 'package:flutter/services.dart';

import '../data/driving_preferences.dart';

abstract class DrivingFeedbackGateway {
  Future<void> playAlert({
    String? message,
    required bool playSound,
    required DrivingAlertOutput output,
    required DrivingMusicBehavior musicBehavior,
    required double volume,
  });

  Future<void> vibrate();

  Future<void> setKeepScreenOn(bool enabled);

  Future<void> stopOngoingFeedback();
}

class PlatformDrivingFeedbackGateway implements DrivingFeedbackGateway {
  const PlatformDrivingFeedbackGateway();

  static const _channel = MethodChannel('co.picoradar.app/driving');

  @override
  Future<void> playAlert({
    String? message,
    required bool playSound,
    required DrivingAlertOutput output,
    required DrivingMusicBehavior musicBehavior,
    required double volume,
  }) async {
    try {
      await _channel.invokeMethod<void>('playDrivingAlert', {
        'message': message,
        'playSound': playSound,
        'output': output.name,
        'musicBehavior': musicBehavior.name,
        'volume': volume.clamp(0, 1),
      });
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> stopOngoingFeedback() async {
    try {
      await _channel.invokeMethod<void>('stopDrivingFeedback');
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> vibrate() {
    return HapticFeedback.mediumImpact();
  }
}
