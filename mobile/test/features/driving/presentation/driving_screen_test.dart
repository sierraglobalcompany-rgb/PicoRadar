import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/driving/presentation/driving_screen.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

import '../../../test_app_harness.dart';

void main() {
  testWidgets('shows the driving start surface without requesting GPS', (
    tester,
  ) async {
    final gateway = _IdleGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _emptyPack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conducir'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-driving')), findsOneWidget);
    expect(find.textContaining('No se guarda recorrido'), findsOneWidget);
    expect(gateway.requestPermissionCalls, 0);
  });

  testWidgets('start button requests foreground GPS permission', (
    tester,
  ) async {
    final gateway = _IdleGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _emptyPack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();

    expect(gateway.requestPermissionCalls, 1);
  });
}

CameraPack _emptyPack() {
  return const CameraPack(
    source: CameraPackSource(
      name: 'ANSV',
      pageUrl: 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
      dataUrl: 'https://fotodeteccion.ansv.gov.co/map/data/sast.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras: [],
  );
}

class _IdleGateway implements DrivingLocationGateway {
  var requestPermissionCalls = 0;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() {
    throw UnimplementedError();
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.denied;
  }
}
