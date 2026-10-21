import 'package:flutter/services.dart';

abstract class DrivingFeedbackGateway {
  Future<bool> isSpeechAvailable();

  Future<void> speak(String message);

  Future<void> playSound();

  Future<void> vibrate();

  Future<void> setKeepScreenOn(bool enabled);

  Future<void> stopOngoingFeedback();
}

class PlatformDrivingFeedbackGateway implements DrivingFeedbackGateway {
  const PlatformDrivingFeedbackGateway();

  static const _channel = MethodChannel('co.picoradar.app/driving');

  @override
  Future<bool> isSpeechAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isDrivingSpeechAvailable') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> playSound() {
    return SystemSound.play(SystemSoundType.alert);
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
  Future<void> speak(String message) async {
    try {
      await _channel.invokeMethod<void>('speakDrivingAlert', {
        'message': message,
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
