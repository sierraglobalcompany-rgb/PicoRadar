import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/data/driving_regional_demo.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_feedback_gateway.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/driving/presentation/driving_screen.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

import '../../../test_app_harness.dart';

void main() {
  final routes = parseDrivingRegionalDemo(
    File(drivingRegionalDemoAsset).readAsStringSync(),
  );
  final pack = CameraPack.fromJson(
    jsonDecode(File(cameraPackAssetPath).readAsStringSync())
        as Map<String, Object?>,
  );
  late ProviderContainer container;
  late _NoGps gateway;
  late _Feedback feedback;
  late DrivingController controller;

  Future<void> setup({
    Future<DrivingDemoRoute> Function(String)? loader,
  }) async {
    gateway = _NoGps();
    feedback = _Feedback();
    container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => pack),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        if (loader != null)
          drivingRegionalDemoLoaderProvider.overrideWithValue(loader),
      ],
    );
    addTearDown(container.dispose);
    await container.read(drivingControllerProvider.future);
    controller = container.read(drivingControllerProvider.notifier);
  }

  Future<void> stop(WidgetTester tester) async {
    await tester.runAsync(controller.stop);
  }

  testWidgets('regional controls respect compile-time debug gate', (
    tester,
  ) async {
    await setup();
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DrivingScreen())),
      ),
    );
    final control = find.byKey(
      const ValueKey('debug-driving-niquiaToEstrella'),
    );
    if (!canUseDebugDrivingSimulation) {
      expect(control, findsNothing);
      for (final scenario in DrivingSimulationScenario.values) {
        await controller.start(simulationScenario: scenario);
      }
      await controller.start(simulated: true);
      expect(gateway.calls, 0);
      expect(
        container.read(drivingControllerProvider).value!.isActive,
        isFalse,
      );
      return;
    }
    await tester.scrollUntilVisible(control, 350);
    await tester.tap(control);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(
      container.read(drivingControllerProvider).value!.simulationName,
      DrivingSimulationScenario.niquiaToEstrella.label,
    );
    expect(
      find.text(
        'SIMULACION · ${DrivingSimulationScenario.niquiaToEstrella.label}',
      ),
      findsOneWidget,
    );
    expect(gateway.calls, 0);
    await tester.tap(find.byTooltip('HUD'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('driving-simulation-label')),
      findsOneWidget,
    );
    await stop(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('hud-speed')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    DrivingSimulationScenario.niquiaToEstrella,
    DrivingSimulationScenario.estrellaToNiquia,
  ]) {
    testWidgets('${scenario.name} label fits 360 px at double text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await setup(loader: (id) async => routes.singleWhere((r) => r.id == id));
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
      await controller.start(simulationScenario: scenario);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(body: DrivingScreen()),
          ),
        ),
      );
      await tester.pump();
      final label = find.byKey(const ValueKey('driving-simulation-label'));
      final rect = tester.getRect(label);
      final brand = find.byKey(const ValueKey('driving-brand'));
      final brandRect = tester.getRect(brand);
      expect(brandRect.left, greaterThanOrEqualTo(0));
      expect(brandRect.right, lessThanOrEqualTo(360));
      expect(
        tester.renderObject<RenderParagraph>(brand).didExceedMaxLines,
        isFalse,
      );
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThanOrEqualTo(844));
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await stop(tester);
      await tester.pump();
    }, skip: !canUseDebugDrivingSimulation);

    testWidgets(
      '${scenario.name} finishes all fixture points and releases feedback',
      (tester) async {
        await setup(
          loader: (id) async => routes.singleWhere((r) => r.id == id),
        );
        final seen = <DrivingPoint>[];
        container.listen(drivingControllerProvider, (_, next) {
          final point = next.asData?.value.currentPoint;
          if (point != null && (seen.isEmpty || !identical(seen.last, point))) {
            seen.add(point);
          }
        });
        await controller.start(simulated: true, simulationScenario: scenario);
        await tester.pump();
        final expected = routes
            .singleWhere((r) => r.id == scenario.name)
            .samples(DateTime.utc(2026));
        for (var i = 1; i < expected.length; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump();
        expect(seen.length, expected.length);
        expect(seen.last.latitude, expected.last.latitude);
        expect(seen.last.longitude, expected.last.longitude);
        expect(
          container.read(drivingControllerProvider).value!.status,
          DrivingSessionStatus.idle,
        );
        expect(
          container.read(drivingControllerProvider).value!.currentPoint,
          isNull,
        );
        expect(
          container.read(drivingControllerProvider).value!.simulationName,
          isNull,
        );
        expect(feedback.screen, [true, false]);
        expect(feedback.stops, greaterThanOrEqualTo(1));
        expect(gateway.calls, 0);
      },
      skip: !canUseDebugDrivingSimulation,
    );
  }

  for (final lateError in [false, true]) {
    testWidgets(
      'cancel loading then restart ignores stale ${lateError ? "failure" : "success"}',
      (tester) async {
        final pending = Completer<DrivingDemoRoute>();
        await setup(
          loader: (id) => id == 'niquiaToEstrella'
              ? pending.future
              : Future.value(routes.last),
        );
        final first = controller.start(
          simulationScenario: DrivingSimulationScenario.niquiaToEstrella,
        );
        await tester.pump();
        await stop(tester);
        await controller.start(
          simulationScenario: DrivingSimulationScenario.estrellaToNiquia,
        );
        await tester.pump();
        if (lateError) {
          pending.completeError(const FormatException('fixture unavailable'));
        } else {
          pending.complete(routes.first);
        }
        await first;
        await tester.pump(const Duration(seconds: 1));
        final current = container.read(drivingControllerProvider).value!;
        expect(current.isActive, isTrue);
        expect(
          current.simulationName,
          DrivingSimulationScenario.estrellaToNiquia.label,
        );
        expect(current.speedKmh, 80);
        expect(feedback.screen.last, isTrue);
        expect(gateway.calls, 0);
        await stop(tester);
      },
      skip: !canUseDebugDrivingSimulation,
    );
  }

  testWidgets(
    'cancel active replay then restart has no old ticks or timestamps',
    (tester) async {
      await setup(loader: (id) async => routes.singleWhere((r) => r.id == id));
      await controller.start(
        simulationScenario: DrivingSimulationScenario.niquiaToEstrella,
      );
      await tester.pump(const Duration(seconds: 3));
      await stop(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(
        container.read(drivingControllerProvider).value!.currentPoint,
        isNull,
      );
      await controller.start(
        simulationScenario: DrivingSimulationScenario.estrellaToNiquia,
      );
      await tester.pump();
      final expected = routes.last.samples(DateTime.utc(2026)).first;
      expect(
        container.read(drivingControllerProvider).value!.currentPoint!.latitude,
        expected.latitude,
      );
      expect(feedback.screen, [true, false, true]);
      await stop(tester);
    },
    skip: !canUseDebugDrivingSimulation,
  );

  testWidgets('failed fixture and disposed pending load never start GPS', (
    tester,
  ) async {
    final pending = Completer<DrivingDemoRoute>();
    var calls = 0;
    await setup(
      loader: (_) => calls++ == 0
          ? Future.error(const FormatException('bad fixture'))
          : pending.future,
    );
    await controller.start(
      simulationScenario: DrivingSimulationScenario.niquiaToEstrella,
    );
    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.locationUnavailable,
    );
    final starting = controller.start(
      simulationScenario: DrivingSimulationScenario.estrellaToNiquia,
    );
    await tester.pump();
    container.dispose();
    pending.complete(routes.last);
    await starting;
    await tester.pump();
    expect(feedback.screen, isNot(contains(true)));
    expect(gateway.calls, 0);
  }, skip: !canUseDebugDrivingSimulation);

  testWidgets('legacy demo retains last inspection frame', (tester) async {
    await setup();
    await controller.start(
      simulationScenario: DrivingSimulationScenario.knownSpeed,
    );
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(container.read(drivingControllerProvider).value!.isActive, isTrue);
    expect(
      container.read(drivingControllerProvider).value!.currentPoint,
      isNotNull,
    );
    expect(feedback.screen, [true]);
    await stop(tester);
  }, skip: !canUseDebugDrivingSimulation);

  testWidgets(
    'queued final points ignore blocked feedback and old completion cannot stop restart',
    (tester) async {
      await setup(loader: (id) async => routes.singleWhere((r) => r.id == id));
      final blocked = Completer<void>();
      feedback.blockSpeakAt = 11;
      feedback.blockedSpeak = blocked.future;
      await controller.start(
        simulationScenario: DrivingSimulationScenario.niquiaToEstrella,
      );
      final count = routes.first.samples(DateTime.utc(2026)).length;
      await tester.pump();
      for (var i = 1; i < count; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(feedback.speaks, 11);
      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.idle,
      );
      await controller.start(
        simulationScenario: DrivingSimulationScenario.estrellaToNiquia,
      );
      await tester.pump();
      blocked.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(drivingControllerProvider).value!.isActive, isTrue);
      expect(
        container.read(drivingControllerProvider).value!.simulationName,
        DrivingSimulationScenario.estrellaToNiquia.label,
      );
      expect(feedback.screen, [true, false, true]);
      await stop(tester);
    },
    skip: !canUseDebugDrivingSimulation,
  );
}

class _NoGps implements DrivingLocationGateway {
  int calls = 0;
  Never _unexpected() {
    calls++;
    throw StateError('Real GPS used by simulation');
  }

  @override
  Future<bool> isLocationServiceEnabled() async => _unexpected();
  @override
  Future<DeviceLocationPermission> checkPermission() async => _unexpected();
  @override
  Future<DeviceLocationPermission> requestPermission() async => _unexpected();
  @override
  Stream<DrivingPoint> positionStream() => _unexpected();
}

class _Feedback implements DrivingFeedbackGateway {
  final screen = <bool>[];
  int stops = 0;
  int speaks = 0;
  int? blockSpeakAt;
  Future<void>? blockedSpeak;
  @override
  Future<bool> isSpeechAvailable() async => true;
  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    screen.add(enabled);
  }

  @override
  Future<void> stopOngoingFeedback() async {
    stops++;
  }

  @override
  Future<void> speak(String message) async {
    speaks++;
    if (speaks == blockSpeakAt) await blockedSpeak;
  }

  @override
  Future<void> playSound() async {}
  @override
  Future<void> vibrate() async {}
}
