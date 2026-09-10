import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';

import '../../../test_app_harness.dart';

void main() {
  test('defaults to auto visualization and 90 degree camera cone', () async {
    final preferences = MemoryPreferences();

    final loaded = await loadDrivingPreferences(preferences);

    expect(loaded.cameraVisualizationMode, CameraVisualizationMode.auto);
    expect(loaded.cameraTargetingConeDegrees, 90);
    expect(loaded.tollAlertsEnabled, isFalse);
    expect(loaded.visualAlertsEnabled, isFalse);
  });

  test('persists camera visualization mode and preserves saved cone', () async {
    final preferences = MemoryPreferences();
    final value = defaultDrivingPreferences.copyWith(
      cameraVisualizationMode: CameraVisualizationMode.radar,
      cameraTargetingConeDegrees: 180,
      tollAlertsEnabled: true,
      visualAlertsEnabled: true,
    );

    await saveDrivingPreferences(preferences, value);
    final loaded = await loadDrivingPreferences(preferences);

    expect(loaded.cameraVisualizationMode, CameraVisualizationMode.radar);
    expect(loaded.cameraTargetingConeDegrees, 180);
    expect(loaded.tollAlertsEnabled, isTrue);
    expect(loaded.visualAlertsEnabled, isTrue);
    await saveDrivingPreferences(
      preferences,
      loaded.copyWith(tollAlertsEnabled: false),
    );
    expect(
      (await loadDrivingPreferences(preferences)).tollAlertsEnabled,
      isFalse,
    );
    await saveDrivingPreferences(
      preferences,
      loaded.copyWith(visualAlertsEnabled: false),
    );
    expect(
      (await loadDrivingPreferences(preferences)).visualAlertsEnabled,
      isFalse,
    );
  });
}
