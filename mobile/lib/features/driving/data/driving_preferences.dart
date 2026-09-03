import '../../../core/storage/app_preferences.dart';
import '../domain/driving_alert_engine.dart';

const _profileKey = 'driving.alert.profile';
const _voiceKey = 'driving.alert.voice';
const _soundKey = 'driving.alert.sound';
const _vibrationKey = 'driving.alert.vibration';
const _customThresholdsKey = 'driving.alert.customThresholds';
const _hudMirrorKey = 'driving.hud.mirror';
const _targetingConeKey = 'driving.alert.targetingConeDegrees';
const _cameraVisualizationModeKey = 'driving.camera.visualizationMode';

const allowedCameraTargetingConeDegrees = [45, 90, 180, 360];

enum CameraVisualizationMode {
  auto('Automático', 'Usa mapa si está disponible y radar sin conexión.'),
  radar('Radar', 'Siempre local, sin Internet ni tiles.'),
  map('Mapa', 'Prefiere mapa real y cae a radar si falla.');

  const CameraVisualizationMode(this.label, this.description);

  final String label;
  final String description;
}

class DrivingPreferences {
  const DrivingPreferences({
    required this.profile,
    required this.voiceEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.customThresholdsMeters,
    required this.hudMirrorEnabled,
    required this.cameraTargetingConeDegrees,
    required this.cameraVisualizationMode,
  });

  final DrivingAlertProfile profile;
  final bool voiceEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final List<int> customThresholdsMeters;
  final bool hudMirrorEnabled;
  final int cameraTargetingConeDegrees;
  final CameraVisualizationMode cameraVisualizationMode;

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
    bool? hudMirrorEnabled,
    int? cameraTargetingConeDegrees,
    CameraVisualizationMode? cameraVisualizationMode,
  }) {
    return DrivingPreferences(
      profile: profile ?? this.profile,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      customThresholdsMeters:
          customThresholdsMeters ?? this.customThresholdsMeters,
      hudMirrorEnabled: hudMirrorEnabled ?? this.hudMirrorEnabled,
      cameraTargetingConeDegrees:
          cameraTargetingConeDegrees ?? this.cameraTargetingConeDegrees,
      cameraVisualizationMode:
          cameraVisualizationMode ?? this.cameraVisualizationMode,
    );
  }
}

const defaultDrivingPreferences = DrivingPreferences(
  profile: DrivingAlertProfile.normal,
  voiceEnabled: true,
  soundEnabled: true,
  vibrationEnabled: true,
  customThresholdsMeters: [500, 300, 100],
  hudMirrorEnabled: false,
  cameraTargetingConeDegrees: 90,
  cameraVisualizationMode: CameraVisualizationMode.auto,
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
    hudMirrorEnabled: await preferences.getBool(_hudMirrorKey) ?? false,
    cameraTargetingConeDegrees: _parseTargetingConeDegrees(
      await preferences.getInt(_targetingConeKey),
    ),
    cameraVisualizationMode: _parseCameraVisualizationMode(
      await preferences.getString(_cameraVisualizationModeKey),
    ),
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
  await preferences.setBool(_hudMirrorKey, value.hudMirrorEnabled);
  await preferences.setInt(_targetingConeKey, value.cameraTargetingConeDegrees);
  await preferences.setString(
    _cameraVisualizationModeKey,
    value.cameraVisualizationMode.name,
  );
  await preferences.setString(
    _customThresholdsKey,
    value.customThresholdsMeters.join(','),
  );
}

CameraVisualizationMode _parseCameraVisualizationMode(String? value) {
  return CameraVisualizationMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => defaultDrivingPreferences.cameraVisualizationMode,
  );
}

int _parseTargetingConeDegrees(int? value) {
  return allowedCameraTargetingConeDegrees.contains(value)
      ? value!
      : defaultDrivingPreferences.cameraTargetingConeDegrees;
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
