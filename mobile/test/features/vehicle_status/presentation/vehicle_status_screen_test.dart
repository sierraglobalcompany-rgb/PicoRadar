import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/presentation/vehicle_status_screen.dart';

import '../../../test_app_harness.dart';

void main() {
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('SOAT can be saved locally and stays scoped to saved date', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'AAA111');
    await _openModule(tester, harness, 'soat');

    expect(find.text('Sin configurar'), findsOneWidget);
    expect(
      find.text(
        'Activa las notificaciones desde Inicio para recibir recordatorios.',
      ),
      findsOneWidget,
    );

    final editButton = find.byKey(const ValueKey('vehicle-status-edit'));
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await _enterText(tester, 'status-start-date-field', '2026-01-01');
    await _enterText(tester, 'status-due-date-field', '2026-12-31');
    await _enterText(tester, 'status-insurerName-field', 'Seguros Alfa');
    await _enterText(tester, 'status-policy-number-field', 'SOAT-123');
    await tester.tap(find.byKey(const ValueKey('status-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Vigente según la fecha guardada'), findsOneWidget);
    expect(find.text('Seguros Alfa'), findsOneWidget);
    expect(find.text('SOAT-123'), findsOneWidget);
  });

  testWidgets('insurance assistance phones can be launched by user action', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'AAA111');
    await VehicleObligationStore(harness.database).upsert(
      vehicleId: vehicle.id,
      type: VehicleObligationType.insurance,
      dueDate: DateTime(2026, 12, 31),
      details: const {
        'providerName': 'Allianz Colombia',
        'policyNumber': 'VOL-1',
        'assistancePhone': '601 111 1111',
      },
    );
    final launcher = _CapturingLauncher();

    await _openModule(
      tester,
      harness,
      'seguro_asistencia',
      externalLauncher: launcher,
    );
    final callButton = find.byKey(const ValueKey('call-assistancePhone'));
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(callButton);
    await tester.pump();

    expect(launcher.calledPhones, ['601 111 1111']);
    expect(normalizePhoneForTel(launcher.calledPhones.single), '6011111111');
  });

  testWidgets('tax screen suggests only verified authority without estimates', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'MED123', city: 'Medellin');

    await _openModule(tester, harness, 'impuestos');

    expect(
      find.text('No calculamos ni estimamos el impuesto.'),
      findsOneWidget,
    );
    expect(find.text('Antioquia - Gobernación de Antioquia'), findsWidgets);
    expect(find.textContaining('avaluo'), findsNothing);
    expect(find.textContaining('tarifa'), findsNothing);
  });
}

Future<VehicleProfile> _createVehicle(
  TestAppHarness harness, {
  required String plate,
  String city = 'Bogota',
}) {
  return harness.repository.createVehicle(
    plate: plate,
    kind: VehicleKind.car,
    registrationCity: city,
  );
}

Future<void> _openModule(
  WidgetTester tester,
  TestAppHarness harness,
  String moduleId, {
  ExternalLauncher? externalLauncher,
}) async {
  await harness.pump(tester, externalLauncher: externalLauncher);
  await tester.tap(find.byKey(const ValueKey('tab-apps')));
  await tester.pumpAndSettle();
  final module = find.byKey(ValueKey('app-module-$moduleId'));
  await tester.ensureVisible(module);
  await tester.tap(module);
  await tester.pumpAndSettle();
}

Future<void> _enterText(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

class _CapturingLauncher implements ExternalLauncher {
  final calledPhones = <String>[];
  final openedUris = <String>[];

  @override
  Future<bool> callPhone(String phone) async {
    calledPhones.add(phone);
    return true;
  }

  @override
  Future<bool> openExternal(String uri) async {
    openedUris.add(uri);
    return true;
  }
}
