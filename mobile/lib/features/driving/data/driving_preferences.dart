import '../../../core/storage/app_preferences.dart';
import '../domain/driving_alert_engine.dart';

const _profileKey = 'driving.alert.profile';
const _voiceKey = 'driving.alert.voice';
const _soundKey = 'driving.alert.sound';
const _vibrationKey = 'driving.alert.vibration';
const _customThresholdsKey = 'driving.alert.customThresholds';

class DrivingPreferences {
  const DrivingPreferences({
    required this.profile,
    required this.voiceEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.customThresholdsMeters,
  });

  final DrivingAlertProfile profile;
  final bool voiceEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final List<int> customThresholdsMeters;

  List<int> get activeThresholdsMeters {
    return profile == DrivingAlertProfile.custom
        ? customThresholdsMeters
        : profile.defaultThresholdsMeters;
  }

  DrivingPreferences copyWith({
    DrivingAlertProfile? profile,
    bool? voiceEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    List<int>? customThresholdsMeters,
  }) {
    return DrivingPreferences(
      profile: profile ?? this.profile,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      customThresholdsMeters:
          customThresholdsMeters ?? this.customThresholdsMeters,
    );
  }
}

const defaultDrivingPreferences = DrivingPreferences(
  profile: DrivingAlertProfile.normal,
  voiceEnabled: true,
  soundEnabled: true,
  vibrationEnabled: true,
  customThresholdsMeters: [500, 300, 100],
);

Future<DrivingPreferences> loadDrivingPreferences(
  AppPreferences preferences,
) async {
  final profileName = await preferences.getString(_profileKey);
  final customThresholds = _parseCustomThresholds(
    await preferences.getString(_customThresholdsKey),
  );
  return DrivingPreferences(
    profile: DrivingAlertProfile.values.firstWhere(
      (profile) => profile.name == profileName,
      orElse: () => DrivingAlertProfile.normal,
    ),
    voiceEnabled: await preferences.getBool(_voiceKey) ?? true,
    soundEnabled: await preferences.getBool(_soundKey) ?? true,
    vibrationEnabled: await preferences.getBool(_vibrationKey) ?? true,
    customThresholdsMeters: customThresholds,
  );
}

Future<void> saveDrivingPreferences(
  AppPreferences preferences,
  DrivingPreferences value,
) async {
  await preferences.setString(_profileKey, value.profile.name);
  await preferences.setBool(_voiceKey, value.voiceEnabled);
  await preferences.setBool(_soundKey, value.soundEnabled);
  await preferences.setBool(_vibrationKey, value.vibrationEnabled);
  await preferences.setString(
    _customThresholdsKey,
    value.customThresholdsMeters.join(','),
  );
}

List<int> _parseCustomThresholds(String? value) {
  final selected =
      (value ?? '')
          .split(',')
          .map(int.tryParse)
          .nonNulls
          .where(allowedCustomAlertThresholdsMeters.contains)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
  return selected.isEmpty
      ? defaultDrivingPreferences.customThresholdsMeters
      : selected;
}
