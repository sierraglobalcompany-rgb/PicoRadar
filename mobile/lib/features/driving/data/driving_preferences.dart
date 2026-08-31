import '../../../core/storage/app_preferences.dart';
import '../domain/driving_alert_engine.dart';

const _profileKey = 'driving.alert.profile';
const _voiceKey = 'driving.alert.voice';
const _soundKey = 'driving.alert.sound';
const _vibrationKey = 'driving.alert.vibration';

class DrivingPreferences {
  const DrivingPreferences({
    required this.profile,
    required this.voiceEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  final DrivingAlertProfile profile;
  final bool voiceEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  DrivingPreferences copyWith({
    DrivingAlertProfile? profile,
    bool? voiceEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return DrivingPreferences(
      profile: profile ?? this.profile,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

const defaultDrivingPreferences = DrivingPreferences(
  profile: DrivingAlertProfile.normal,
  voiceEnabled: true,
  soundEnabled: true,
  vibrationEnabled: true,
);

Future<DrivingPreferences> loadDrivingPreferences(
  AppPreferences preferences,
) async {
  final profileName = await preferences.getString(_profileKey);
  return DrivingPreferences(
    profile: DrivingAlertProfile.values.firstWhere(
      (profile) => profile.name == profileName,
      orElse: () => DrivingAlertProfile.normal,
    ),
    voiceEnabled: await preferences.getBool(_voiceKey) ?? true,
    soundEnabled: await preferences.getBool(_soundKey) ?? true,
    vibrationEnabled: await preferences.getBool(_vibrationKey) ?? true,
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
}
