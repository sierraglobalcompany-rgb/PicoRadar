import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';

import '../../../test_app_harness.dart';

void main() {
  test('defaults to auto visualization and 90 degree camera cone', () async {
    final preferences = MemoryPreferences();

    final loaded = await loadDrivingPreferences(preferences);

    expect(loaded.cameraVisualizationMode, CameraVisualizationMode.auto);
    expect(loaded.cameraTargetingConeDegrees, 90);
    expect(loaded.alertOutput, DrivingAlertOutput.automatic);
    expect(loaded.musicBehavior, DrivingMusicBehavior.duck);
    expect(loaded.alertVolume, 0.8);
  });

  test('persists camera visualization mode and preserves saved cone', () async {
    final preferences = MemoryPreferences();
    final value = defaultDrivingPreferences.copyWith(
      cameraVisualizationMode: CameraVisualizationMode.radar,
      cameraTargetingConeDegrees: 180,
    );

    await saveDrivingPreferences(preferences, value);
    final loaded = await loadDrivingPreferences(preferences);

    expect(loaded.cameraVisualizationMode, CameraVisualizationMode.radar);
    expect(loaded.cameraTargetingConeDegrees, 180);
  });

  test('persists driving audio routing, focus behavior, and gain', () async {
    final preferences = MemoryPreferences();
    final value = defaultDrivingPreferences.copyWith(
      alertOutput: DrivingAlertOutput.phoneSpeaker,
      musicBehavior: DrivingMusicBehavior.pause,
      alertVolume: 0.35,
    );

    await saveDrivingPreferences(preferences, value);
    final loaded = await loadDrivingPreferences(preferences);

    expect(loaded.alertOutput, DrivingAlertOutput.phoneSpeaker);
    expect(loaded.musicBehavior, DrivingMusicBehavior.pause);
    expect(loaded.alertVolume, 0.35);
  });
}
