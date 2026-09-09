import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_feedback_gateway.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

import '../../../test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disabled simulation requests never fall back to real GPS', () async {
    if (canUseDebugDrivingSimulation) return;
    final gateway = _FakeDrivingLocationGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(
          _FakeDrivingFeedbackGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(drivingControllerProvider.future);
    final controller = container.read(drivingControllerProvider.notifier);
    await controller.start(simulated: true);
    expect(gateway.requestPermissionCalls, 0);
    expect(gateway.listenCalls, 0);
    expect(container.read(drivingControllerProvider).value!.isActive, isFalse);
    await controller.start(
      simulationScenario: DrivingSimulationScenario.knownSpeed,
    );
    expect(gateway.requestPermissionCalls, 0);
    expect(gateway.listenCalls, 0);
  });

  test(
    'requests location only when the driver starts a foreground session',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.future);
      expect(gateway.requestPermissionCalls, 0);

      await container.read(drivingControllerProvider.notifier).start();
      expect(gateway.requestPermissionCalls, 1);
      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.active,
      );
      expect(feedback.keepScreenOnStates, [true]);

      gateway.add(
        DrivingPoint(
          latitude: 6.239,
          longitude: -75.57,
          accuracyMeters: 14,
          speedKmh: 42,
          headingDegrees: 0,
          recordedAt: DateTime.utc(2026, 8, 31, 12),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      gateway.add(
        DrivingPoint(
          latitude: 6.241,
          longitude: -75.57,
          accuracyMeters: 14,
          speedKmh: 42,
          headingDegrees: 0,
          recordedAt: DateTime.utc(2026, 8, 31, 12, 1),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(drivingControllerProvider).value!;
      expect(state.nearestCamera, isNotNull);
      expect(state.speedKmh, 42);
      expect(state.speedState, DrivingSpeedState.unknownReportedSpeed);
      expect(feedback.spokenMessages.single, contains('500 metros'));
      expect(
        feedback.spokenMessages.single,
        'Cámara a 500 metros. Respeta la señalización de la vía.',
      );
      expect(feedback.soundCalls, 1);
      expect(feedback.vibrationCalls, 1);

      await container.read(drivingControllerProvider.notifier).stop();
      expect(gateway.cancelled, isTrue);
      expect(feedback.keepScreenOnStates, [true, false]);
      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.idle,
      );
    },
  );

  test('first movement sample does not emit a camera alert', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(
      DrivingPoint(
        latitude: 6.2434,
        longitude: -75.57,
        accuracyMeters: 14,
        speedKmh: 42,
        headingDegrees: 0,
        recordedAt: DateTime.utc(2026, 8, 31, 12),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(drivingControllerProvider).value!;
    expect(state.nearestCamera, isNull);
    expect(state.lastAlert, isNull);
    expect(feedback.spokenMessages, isEmpty);
  });

  test(
    'visual camera pulse fires once per crossed threshold without audio',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(drivingControllerProvider.notifier);
      await container.read(drivingControllerProvider.future);
      await controller.savePreferences(
        defaultDrivingPreferences.copyWith(
          visualAlertsEnabled: true,
          voiceEnabled: false,
          soundEnabled: false,
          vibrationEnabled: false,
        ),
      );
      await controller.start();

      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await _flushController();
      gateway.add(_point(latitude: 6.241, speedKmh: 50, seconds: 20));
      await _flushController();
      final firstPulse = container
          .read(drivingControllerProvider)
          .value!
          .visualAlertPulseKey;
      expect(firstPulse, isNotNull);
      expect(feedback.spokenMessages, isEmpty);
      expect(feedback.soundCalls, 0);
      expect(feedback.vibrationCalls, 0);

      gateway.add(_point(latitude: 6.2411, speedKmh: 50, seconds: 21));
      await _flushController();
      expect(
        container.read(drivingControllerProvider).value!.visualAlertPulseKey,
        firstPulse,
      );

      gateway.add(_point(latitude: 6.242, speedKmh: 50, seconds: 40));
      await _flushController();
      expect(
        container.read(drivingControllerProvider).value!.visualAlertPulseKey,
        isNot(firstPulse),
      );

      gateway.add(_point(latitude: 6.252, speedKmh: 50, seconds: 70));
      await _flushController();
      expect(
        container.read(drivingControllerProvider).value!.visualAlertPulseKey,
        isNull,
      );
    },
  );

  test(
    'poor GPS accuracy keeps speed but blocks camera alert stages',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      for (final latitude in [6.241, 6.242]) {
        gateway.add(
          DrivingPoint(
            latitude: latitude,
            longitude: -75.57,
            accuracyMeters: 90,
            speedKmh: 42,
            headingDegrees: 0,
            recordedAt: DateTime.utc(
              2026,
              8,
              31,
              12,
              latitude == 6.241 ? 0 : 1,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      final state = container.read(drivingControllerProvider).value!;
      expect(state.speedKmh, 42);
      expect(state.gpsQuality, GpsQuality.weak);
      expect(state.nearestCamera, isNull);
      expect(state.lastAlert, isNull);
      expect(feedback.spokenMessages, isEmpty);
    },
  );

  test(
    'ANSV detail never produces numeric comparison or delta haptics',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.241, speedKmh: 50, seconds: 20));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.unknownReportedSpeed,
      );

      gateway.add(_point(latitude: 6.242, speedKmh: 70, seconds: 21));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.unknownReportedSpeed,
      );

      gateway.add(_point(latitude: 6.243, speedKmh: 54, seconds: 22));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.unknownReportedSpeed,
      );
      final current = container.read(drivingControllerProvider).value!;
      expect(current.reportedCameraSpeedKmh, 60);
      expect(current.speedDeltaKmh, 0);
      expect(current.isOverspeeding, isFalse);
      expect(feedback.vibrationCalls, 1);
    },
  );

  test('unknown reported speed keeps comparison fail-closed', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith(
          (ref) async => _pack(speedLimitKmh: null),
        ),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 100, seconds: 0));
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.241, speedKmh: 100, seconds: 20));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(drivingControllerProvider).value!;
    expect(state.speedState, DrivingSpeedState.unknownReportedSpeed);
    expect(state.isOverspeeding, isFalse);
    expect(
      feedback.spokenMessages.single,
      isNot(contains('Velocidad reportada')),
    );
  });

  test(
    '360 visual episode stays stable without speech and respects dismissal',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(drivingControllerProvider.notifier);
      await container.read(drivingControllerProvider.future);
      await controller.savePreferences(
        defaultDrivingPreferences.copyWith(cameraTargetingConeDegrees: 360),
      );
      await controller.start();
      gateway.add(_point(latitude: 6.2442, speedKmh: 50, seconds: 0));
      await _flushController();
      gateway.add(_point(latitude: 6.2444, speedKmh: 50, seconds: 1));
      await _flushController();
      final first = container.read(drivingControllerProvider).value!;
      expect(first.nearestCamera!.approaching, isFalse);
      expect(first.showCameraAlertPanel, isTrue);
      expect(first.cameraEpisodeKey, isNotNull);
      await controller.dismissCurrentCameraAlert();
      gateway.add(_point(latitude: 6.2446, speedKmh: 50, seconds: 2));
      await _flushController();
      final next = container.read(drivingControllerProvider).value!;
      expect(next.cameraEpisodeKey, first.cameraEpisodeKey);
      expect(next.showCameraAlertPanel, isFalse);
      expect(feedback.spokenMessages, isEmpty);
      expect(feedback.vibrationCalls, 0);
      await controller.stop();
    },
  );

  test('manual dismissal silences feedback through transient no-match and rearms later', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isTrue,
    );

    await container
        .read(drivingControllerProvider.notifier)
        .dismissCurrentCameraAlert();
    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isFalse,
    );
    expect(feedback.spokenMessages, hasLength(1));
    expect(feedback.soundCalls, 1);
    expect(feedback.vibrationCalls, 1);

    gateway.add(_point(latitude: 6.242, speedKmh: 68, seconds: 45));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isFalse,
    );
    expect(feedback.spokenMessages, hasLength(1));
    expect(feedback.soundCalls, 1);
    expect(feedback.vibrationCalls, 1);

    gateway.add(
      _point(latitude: 6.2422, speedKmh: 68, seconds: 50, accuracy: 95),
    );
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.2432, speedKmh: 68, seconds: 70));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isFalse,
    );
    expect(feedback.spokenMessages, hasLength(1));
    expect(feedback.soundCalls, 1);
    expect(feedback.vibrationCalls, 1);

    gateway.add(_point(latitude: 6.252, speedKmh: 54, seconds: 100));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(drivingControllerProvider).value!.nearestCamera,
      isNull,
    );

    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 90));
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 120));
    await Future<void>.delayed(Duration.zero);

    final rearmed = container.read(drivingControllerProvider).value!;
    expect(rearmed.nearestCamera, isNotNull);
    expect(rearmed.showCameraAlertPanel, isTrue);
    expect(feedback.spokenMessages, hasLength(2));
    expect(feedback.soundCalls, 2);
    expect(feedback.vibrationCalls, 2);
  });

  test('manual dismissal survives an accurate transient no-match in the same episode', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await _flushController();

    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isTrue,
    );
    await container
        .read(drivingControllerProvider.notifier)
        .dismissCurrentCameraAlert();
    final feedbackAfterDismiss = (
      feedback.spokenMessages.length,
      feedback.soundCalls,
      feedback.vibrationCalls,
    );

    gateway.add(
      _point(latitude: 6.2412, speedKmh: 72, seconds: 30, heading: 120),
    );
    await _flushController();
    expect(
      container.read(drivingControllerProvider).value!.nearestCamera,
      isNull,
    );
    expect((
      feedback.spokenMessages.length,
      feedback.soundCalls,
      feedback.vibrationCalls,
    ), feedbackAfterDismiss);

    gateway.add(_point(latitude: 6.2425, speedKmh: 72, seconds: 35));
    await _flushController();
    var current = container.read(drivingControllerProvider).value!;
    expect(current.nearestCamera?.camera.id, 'cam-1');
    expect(current.showCameraAlertPanel, isFalse);
    expect((
      feedback.spokenMessages.length,
      feedback.soundCalls,
      feedback.vibrationCalls,
    ), feedbackAfterDismiss);

    gateway.add(_point(latitude: 6.2435, speedKmh: 72, seconds: 45));
    await _flushController();
    current = container.read(drivingControllerProvider).value!;
    expect(current.showCameraAlertPanel, isFalse);
    expect((
      feedback.spokenMessages.length,
      feedback.soundCalls,
      feedback.vibrationCalls,
    ), feedbackAfterDismiss);

    gateway.add(
      _point(latitude: 6.2412, speedKmh: 72, seconds: 80, heading: 120),
    );
    await _flushController();
    current = container.read(drivingControllerProvider).value!;
    expect(current.dismissedCameraId, isNull);

    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 90));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 120));
    await _flushController();

    final rearmed = container.read(drivingControllerProvider).value!;
    expect(rearmed.nearestCamera?.camera.id, 'cam-1');
    expect(rearmed.showCameraAlertPanel, isTrue);
    expect(feedback.spokenMessages, hasLength(2));
    expect(feedback.soundCalls, 2);
    expect(feedback.vibrationCalls, 2);
  });

  test(
    'a different camera can alert after dismissing the current episode',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith(
            (ref) async => _pack(
              cameras: [
                _camera(id: 'cam-1', latitude: 6.244),
                _camera(id: 'cam-2', latitude: 6.246),
              ],
            ),
          ),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 20));
      await Future<void>.delayed(Duration.zero);

      expect(
        container
            .read(drivingControllerProvider)
            .value!
            .nearestCamera!
            .camera
            .id,
        'cam-1',
      );
      await container
          .read(drivingControllerProvider.notifier)
          .dismissCurrentCameraAlert();

      gateway.add(_point(latitude: 6.2446, speedKmh: 58, seconds: 45));
      await Future<void>.delayed(Duration.zero);

      final switched = container.read(drivingControllerProvider).value!;
      expect(switched.nearestCamera!.camera.id, 'cam-2');
      expect(switched.showCameraAlertPanel, isTrue);
      expect(feedback.spokenMessages, hasLength(2));
      expect(feedback.soundCalls, 2);
      expect(feedback.vibrationCalls, 2);
    },
  );

  test(
    'turning away closes the active camera target and alert panel',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.241, speedKmh: 55, seconds: 20));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(drivingControllerProvider).value!.showCameraAlertPanel,
        isTrue,
      );

      gateway.add(
        _point(latitude: 6.2412, speedKmh: 55, seconds: 40, heading: 120),
      );
      await Future<void>.delayed(Duration.zero);

      final turnedAway = container.read(drivingControllerProvider).value!;
      expect(turnedAway.nearestCamera, isNull);
      expect(turnedAway.showCameraAlertPanel, isFalse);
      expect(feedback.spokenMessages, hasLength(1));
    },
  );

  test(
    'passing a camera closes the panel while still inside 120 meters',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.2437, speedKmh: 58, seconds: 20));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(drivingControllerProvider).value!.showCameraAlertPanel,
        isTrue,
      );

      gateway.add(_point(latitude: 6.2446, speedKmh: 58, seconds: 40));
      await Future<void>.delayed(Duration.zero);

      final afterPassing = container.read(drivingControllerProvider).value!;
      expect(afterPassing.nearestCamera, isNull);
      expect(afterPassing.showCameraAlertPanel, isFalse);
      expect(feedback.spokenMessages, hasLength(1));
    },
  );

  test(
    'overspeed pulse gate fires only on transition and respects reduced motion',
    () {
      final gate = OverspeedPulseGate();

      expect(
        gate.shouldPulse(
          current: DrivingSpeedState.within,
          reducedMotion: false,
        ),
        isFalse,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: false),
        isTrue,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: false),
        isFalse,
      );
      expect(
        gate.shouldPulse(
          current: DrivingSpeedState.within,
          reducedMotion: false,
        ),
        isFalse,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: true),
        isFalse,
      );
    },
  );

  test(
    'processes stream points in order while feedback futures are pending',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _ControllableDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await _flushController();

      feedback.blockNextSpeak();
      gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
      await feedback.waitForBlockedSpeak();
      gateway.add(_point(latitude: 6.242, speedKmh: 72, seconds: 21));
      gateway.add(_point(latitude: 6.243, speedKmh: 74, seconds: 22));
      await _flushController();

      expect(container.read(drivingControllerProvider).value!.speedKmh, 74);
      feedback.releaseBlockedSpeak();
      await _flushController();

      final latest = container.read(drivingControllerProvider).value!;
      expect(latest.currentPoint!.recordedAt.second, 22);
      expect(latest.speedKmh, 74);
      expect(feedback.spokenMessages, hasLength(1));
      expect(feedback.soundCalls, 1);
      expect(feedback.vibrationCalls, 1);
    },
  );

  test(
    'stop invalidates pending point work before delayed feedback completes',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _ControllableDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await _flushController();

      feedback.blockNextSpeak();
      gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
      await feedback.waitForBlockedSpeak();
      await container.read(drivingControllerProvider.notifier).stop();

      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.idle,
      );
      feedback.releaseBlockedSpeak();
      await _flushController();

      final stopped = container.read(drivingControllerProvider).value!;
      expect(stopped.status, DrivingSessionStatus.idle);
      expect(stopped.nearestCamera, isNull);
      expect(stopped.lastAlert, isNull);
      expect(feedback.soundCalls, 0);
      expect(feedback.vibrationCalls, 0);
      expect(feedback.stopOngoingFeedbackCalls, greaterThanOrEqualTo(1));
    },
  );

  test('stop during camera pack load does not resurrect the session', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final packCompleter = Completer<CameraPack>();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) => packCompleter.future),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    final start = container.read(drivingControllerProvider.notifier).start();
    await _flushController();
    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.starting,
    );

    await container.read(drivingControllerProvider.notifier).stop();
    packCompleter.complete(_pack());
    await start;
    await _flushController();

    final stopped = container.read(drivingControllerProvider).value!;
    expect(stopped.status, DrivingSessionStatus.idle);
    expect(gateway.listenCalls, 0);
    expect(feedback.keepScreenOnStates, [false]);
    expect(feedback.stopOngoingFeedbackCalls, 1);
  });

  test(
    'stop during permission request cancels start before subscribing',
    () async {
      final gateway = _ControllableStartGateway(
        checkPermissionResult: DeviceLocationPermission.denied,
      );
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      final start = container.read(drivingControllerProvider.notifier).start();
      await gateway.waitForRequestPermission();
      await container.read(drivingControllerProvider.notifier).stop();
      gateway.completeRequestPermission(DeviceLocationPermission.granted);
      await start;
      await _flushController();

      final stopped = container.read(drivingControllerProvider).value!;
      expect(stopped.status, DrivingSessionStatus.idle);
      expect(gateway.listenCalls, 0);
      expect(gateway.requestPermissionCalls, 1);
      expect(feedback.keepScreenOnStates, [false]);
    },
  );

  test('stop during keep screen on prevents a location subscription', () async {
    final gateway = _ControllableStartGateway(
      checkPermissionResult: DeviceLocationPermission.granted,
    );
    final feedback = _ControllableDrivingFeedbackGateway()
      ..blockNextKeepScreenOnEnable();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    final start = container.read(drivingControllerProvider.notifier).start();
    await feedback.waitForBlockedKeepScreenOnEnable();
    await container.read(drivingControllerProvider.notifier).stop();
    feedback.releaseBlockedKeepScreenOnEnable();
    await start;
    await _flushController();

    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.idle,
    );
    expect(gateway.listenCalls, 0);
    expect(feedback.keepScreenOnStates.first, isTrue);
    expect(feedback.keepScreenOnStates.where((value) => !value), isNotEmpty);
    expect(feedback.stopOngoingFeedbackCalls, greaterThanOrEqualTo(1));
  });

  for (final restartBeforeCleanup in [false, true]) {
    test(
      'cancelled start cleanup cannot disable restart (starting before cleanup: $restartBeforeCleanup)',
      () async {
        final gateway = _ControllableStartGateway(
          checkPermissionResult: DeviceLocationPermission.denied,
        );
        final feedback = _ControllableDrivingFeedbackGateway()
          ..blockNextKeepScreenOnEnable();
        final container = ProviderContainer(
          overrides: [
            appPreferencesProvider.overrideWithValue(MemoryPreferences()),
            cameraPackProvider.overrideWith((ref) async => _pack()),
            drivingLocationGatewayProvider.overrideWithValue(gateway),
            drivingFeedbackGatewayProvider.overrideWithValue(feedback),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(feedback.releaseBlockedStopOngoingFeedback);
        await container.read(drivingControllerProvider.future);
        final controller = container.read(drivingControllerProvider.notifier);
        final firstStart = controller.start();
        await gateway.waitForRequestPermission();
        gateway.completeRequestPermission(DeviceLocationPermission.granted);
        await feedback.waitForBlockedKeepScreenOnEnable();
        await controller.stop();

        Future<void>? restart;
        if (restartBeforeCleanup) {
          restart = controller.start();
          await _flushController();
          expect(
            container.read(drivingControllerProvider).value!.status,
            DrivingSessionStatus.starting,
          );
        }
        feedback.blockNextStopOngoingFeedback();
        feedback.releaseBlockedKeepScreenOnEnable();
        await _flushController();
        final cleanupCalls = feedback.stopOngoingFeedbackCalls;
        restart ??= controller.start();
        await _flushController();
        gateway.completeRequestPermission(DeviceLocationPermission.granted);
        await restart;
        final screenBeforeRelease = [...feedback.keepScreenOnStates];
        expect(screenBeforeRelease, [true, false, true]);

        feedback.releaseBlockedStopOngoingFeedback();
        await firstStart;
        await _flushController();
        expect(
          container.read(drivingControllerProvider).value!.isActive,
          isTrue,
        );
        expect(gateway.listenCalls, 1);
        expect(feedback.keepScreenOnStates, screenBeforeRelease);
        expect(cleanupCalls, restartBeforeCleanup ? 1 : 2);
        await controller.stop();
        expect(feedback.keepScreenOnStates.last, isFalse);
      },
    );
  }

  test('double start while starting creates only one subscription', () async {
    final gateway = _ControllableStartGateway(
      checkPermissionResult: DeviceLocationPermission.denied,
    );
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    final firstStart = container
        .read(drivingControllerProvider.notifier)
        .start();
    await gateway.waitForRequestPermission();
    final secondStart = container
        .read(drivingControllerProvider.notifier)
        .start();
    gateway.completeRequestPermission(DeviceLocationPermission.granted);
    await Future.wait([firstStart, secondStart]);

    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.active,
    );
    expect(gateway.requestPermissionCalls, 1);
    expect(gateway.listenCalls, 1);
    expect(feedback.keepScreenOnStates, [true]);
  });

  test('old blocked feedback cannot continue in a new session', () async {
    final gateway = _RestartableDrivingLocationGateway();
    final feedback = _ControllableDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    feedback.blockNextSpeak();
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await feedback.waitForBlockedSpeak();
    await container.read(drivingControllerProvider.notifier).stop();
    await container.read(drivingControllerProvider.notifier).start();

    feedback.releaseBlockedSpeak();
    await _flushController();

    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.active,
    );
    expect(feedback.soundCalls, 0);
    expect(feedback.vibrationCalls, 0);
    expect(feedback.stopOngoingFeedbackCalls, greaterThanOrEqualTo(1));
  });

  test('direct gap after dismissal creates a new camera episode', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 20));
    await _flushController();
    await container
        .read(drivingControllerProvider.notifier)
        .dismissCurrentCameraAlert();
    final firstEpisodeKey = container
        .read(drivingControllerProvider)
        .value!
        .cameraEpisodeKey;

    gateway.add(_point(latitude: 6.2425, speedKmh: 58, seconds: 60));
    await _flushController();

    final rearmed = container.read(drivingControllerProvider).value!;
    expect(rearmed.dismissedCameraId, isNull);
    expect(rearmed.showCameraAlertPanel, isTrue);
    expect(rearmed.cameraEpisodeKey, isNot(firstEpisodeKey));
    expect(feedback.spokenMessages, hasLength(2));
  });

  test('out of order points do not update state or emit feedback', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await _flushController();
    final feedbackAfterFreshPoint = feedback.spokenMessages.length;

    gateway.add(_point(latitude: 6.242, speedKmh: 90, seconds: 10));
    await _flushController();

    final state = container.read(drivingControllerProvider).value!;
    expect(state.currentPoint!.recordedAt.second, 20);
    expect(state.speedKmh, 70);
    expect(feedback.spokenMessages, hasLength(feedbackAfterFreshPoint));
  });

  test('weak GPS resets movement baseline before matching resumes', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(
      _point(latitude: 6.240, speedKmh: 50, seconds: 10, accuracy: 95),
    );
    await _flushController();
    gateway.add(_point(latitude: 6.242, speedKmh: 58, seconds: 20));
    await _flushController();

    var state = container.read(drivingControllerProvider).value!;
    expect(state.nearestCamera, isNull);
    expect(feedback.spokenMessages, isEmpty);

    gateway.add(_point(latitude: 6.243, speedKmh: 58, seconds: 40));
    await _flushController();

    state = container.read(drivingControllerProvider).value!;
    expect(state.nearestCamera, isNotNull);
    expect(feedback.spokenMessages, hasLength(1));
  });

  test('visual preference changes do not rearm the current episode', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final preferences = MemoryPreferences();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 20));
    await _flushController();
    expect(feedback.spokenMessages, hasLength(1));

    await container
        .read(drivingControllerProvider.notifier)
        .savePreferences(
          defaultDrivingPreferences.copyWith(
            cameraVisualizationMode: CameraVisualizationMode.radar,
            hudMirrorEnabled: true,
            soundEnabled: false,
            vibrationEnabled: false,
          ),
        );
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 21));
    await _flushController();

    expect(feedback.spokenMessages, hasLength(1));
    expect(feedback.soundCalls, 1);
    expect(feedback.vibrationCalls, 1);
  });

  test('platform gateway emits stopDrivingFeedback', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('co.picoradar.app/driving'),
          (call) async {
            calls.add(call.method);
            return null;
          },
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('co.picoradar.app/driving'),
            null,
          );
    });

    await const PlatformDrivingFeedbackGateway().stopOngoingFeedback();

    expect(calls, ['stopDrivingFeedback']);
  });
}

CameraPack _pack({int? speedLimitKmh = 60, List<TrafficCamera>? cameras}) {
  return CameraPack(
    source: const CameraPackSource(
      name: 'ANSV',
      pageUrl: 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
      dataUrl: 'https://fotodeteccion.ansv.gov.co/map/data/sast.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras:
        cameras ??
        [_camera(id: 'cam-1', latitude: 6.244, speedLimitKmh: speedLimitKmh)],
  );
}

TrafficCamera _camera({
  required String id,
  required double latitude,
  int? speedLimitKmh = 60,
}) {
  return TrafficCamera(
    id: id,
    department: 'ANTIOQUIA',
    municipality: 'MEDELLIN',
    jurisdiction: 'Municipal',
    address: 'Avenida 80',
    latitude: latitude,
    longitude: -75.57,
    status: 'Aprobada',
    technology: 'Camara',
    kind: CameraKind.mixed,
    speedLimitKmh: speedLimitKmh,
  );
}

DrivingPoint _point({
  required double latitude,
  required double speedKmh,
  required int seconds,
  double heading = 0,
  double accuracy = 14,
}) {
  return DrivingPoint(
    latitude: latitude,
    longitude: -75.57,
    accuracyMeters: accuracy,
    speedKmh: speedKmh,
    headingDegrees: heading,
    recordedAt: DateTime.utc(2026, 8, 31, 12, 0, seconds),
  );
}

class _FakeDrivingFeedbackGateway implements DrivingFeedbackGateway {
  final spokenMessages = <String>[];
  final keepScreenOnStates = <bool>[];
  var soundCalls = 0;
  var stopOngoingFeedbackCalls = 0;
  var vibrationCalls = 0;

  @override
  Future<void> playSound() async {
    soundCalls += 1;
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    keepScreenOnStates.add(enabled);
  }

  @override
  Future<void> speak(String message) async {
    spokenMessages.add(message);
  }

  @override
  Future<void> stopOngoingFeedback() async {
    stopOngoingFeedbackCalls += 1;
  }

  @override
  Future<void> vibrate() async {
    vibrationCalls += 1;
  }
}

class _ControllableDrivingFeedbackGateway extends _FakeDrivingFeedbackGateway {
  Completer<void>? _blockedStopOngoingFeedback;
  Completer<void>? _blockedSpeak;
  Completer<void>? _speakStarted;
  Completer<void>? _blockedKeepScreenOnEnable;
  Completer<void>? _keepScreenOnEnableStarted;

  void blockNextStopOngoingFeedback() {
    _blockedStopOngoingFeedback = Completer<void>();
  }

  void releaseBlockedStopOngoingFeedback() {
    final blocked = _blockedStopOngoingFeedback;
    if (blocked != null && !blocked.isCompleted) blocked.complete();
  }

  @override
  Future<void> stopOngoingFeedback() async {
    stopOngoingFeedbackCalls += 1;
    final blocked = _blockedStopOngoingFeedback;
    if (blocked != null) {
      await blocked.future;
      if (identical(_blockedStopOngoingFeedback, blocked)) {
        _blockedStopOngoingFeedback = null;
      }
    }
  }

  void blockNextSpeak() {
    _blockedSpeak = Completer<void>();
    _speakStarted = Completer<void>();
  }

  Future<void> waitForBlockedSpeak() async {
    await _speakStarted!.future;
  }

  void releaseBlockedSpeak() {
    final blockedSpeak = _blockedSpeak;
    if (blockedSpeak != null && !blockedSpeak.isCompleted) {
      blockedSpeak.complete();
    }
  }

  void blockNextKeepScreenOnEnable() {
    _blockedKeepScreenOnEnable = Completer<void>();
    _keepScreenOnEnableStarted = Completer<void>();
  }

  Future<void> waitForBlockedKeepScreenOnEnable() async {
    await _keepScreenOnEnableStarted!.future;
  }

  void releaseBlockedKeepScreenOnEnable() {
    final blocked = _blockedKeepScreenOnEnable;
    if (blocked != null && !blocked.isCompleted) {
      blocked.complete();
    }
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    keepScreenOnStates.add(enabled);
    if (enabled && _blockedKeepScreenOnEnable != null) {
      _keepScreenOnEnableStarted?.complete();
      await _blockedKeepScreenOnEnable!.future;
      _blockedKeepScreenOnEnable = null;
    }
  }

  @override
  Future<void> speak(String message) async {
    spokenMessages.add(message);
    _speakStarted?.complete();
    final blockedSpeak = _blockedSpeak;
    if (blockedSpeak != null) {
      await blockedSpeak.future;
      _blockedSpeak = null;
    }
  }
}

class _FakeDrivingLocationGateway implements DrivingLocationGateway {
  final _controller = StreamController<DrivingPoint>();
  var requestPermissionCalls = 0;
  var cancelled = false;
  var listenCalls = 0;

  void add(DrivingPoint point) {
    _controller.add(point);
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() {
    return _controller.stream
        .map((point) => point)
        .doOnListenAndCancel(
          onListen: () {
            listenCalls += 1;
          },
          onCancel: () {
            cancelled = true;
          },
        );
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.granted;
  }
}

class _ControllableStartGateway extends _FakeDrivingLocationGateway {
  _ControllableStartGateway({required this.checkPermissionResult});

  final DeviceLocationPermission checkPermissionResult;
  Completer<DeviceLocationPermission>? _requestPermissionCompleter;
  Completer<void>? _requestPermissionStarted;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return checkPermissionResult;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    _requestPermissionCompleter = Completer<DeviceLocationPermission>();
    _requestPermissionStarted = Completer<void>()..complete();
    return _requestPermissionCompleter!.future;
  }

  Future<void> waitForRequestPermission() async {
    while (_requestPermissionStarted == null) {
      await Future<void>.delayed(Duration.zero);
    }
    await _requestPermissionStarted!.future;
  }

  void completeRequestPermission(DeviceLocationPermission permission) {
    final completer = _requestPermissionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(permission);
    }
  }
}

class _RestartableDrivingLocationGateway implements DrivingLocationGateway {
  StreamController<DrivingPoint>? _controller;
  var requestPermissionCalls = 0;
  var listenCalls = 0;
  var cancelled = false;

  void add(DrivingPoint point) {
    _controller?.add(point);
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() {
    final controller = StreamController<DrivingPoint>();
    _controller = controller;
    return controller.stream.doOnListenAndCancel(
      onListen: () {
        listenCalls += 1;
      },
      onCancel: () {
        cancelled = true;
      },
    );
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.granted;
  }
}

extension _CancelAwareStream<T> on Stream<T> {
  Stream<T> doOnListenAndCancel({
    required void Function() onListen,
    required void Function() onCancel,
  }) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    controller = StreamController<T>(
      onListen: () {
        onListen();
        subscription = listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        onCancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}

Future<void> _flushController() async {
  for (var i = 0; i < 6; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
