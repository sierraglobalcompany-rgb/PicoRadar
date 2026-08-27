import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/platform/pico_widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('co.picoradar.app/widget');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends configured payload', () async {
    await const PicoWidgetBridge().updateConfigured(
      vehicle: _vehicle(),
      jurisdictionName: 'Bogotá',
    );

    expect(calls.single.method, 'updatePicoWidget');
    expect(calls.single.arguments['configured'], isTrue);
    expect(calls.single.arguments['plate'], 'ABC123');
    expect(calls.single.arguments['jurisdictionName'], 'Bogotá');
  });

  test('sends no vehicle payload', () async {
    await const PicoWidgetBridge().updateNoVehicle();

    expect(calls.single.arguments['configured'], isFalse);
    expect(calls.single.arguments['hasVehicle'], isFalse);
  });

  test('sends jurisdiction missing payload', () async {
    await const PicoWidgetBridge().updateMissingJurisdiction(_vehicle());

    expect(calls.single.arguments['configured'], isFalse);
    expect(calls.single.arguments['hasVehicle'], isTrue);
    expect(calls.single.arguments['plate'], 'ABC123');
  });
}

VehicleProfile _vehicle() {
  return VehicleProfile(
    id: 'vehicle-1',
    plate: 'ABC123',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
