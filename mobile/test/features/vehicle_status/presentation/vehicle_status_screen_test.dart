import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';
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

    expect(find.text('SOAT SIN CONFIGURAR'), findsOneWidget);
    expect(find.text('Configura tu SOAT'), findsOneWidget);
    expect(find.text('No has guardado tu póliza.'), findsOneWidget);

    final editButton = find.byKey(const ValueKey('owner-primary-soat'));
    await tester.tap(editButton);
    await _pumpNavigation(tester);
    await _enterText(tester, 'status-start-date-field', '2026-01-01');
    await _enterText(tester, 'status-due-date-field', '2026-12-31');
    await _enterText(tester, 'status-insurerName-field', 'Seguros Alfa');
    await _enterText(tester, 'status-policy-number-field', 'SOAT-123');
    await tester.tap(find.byKey(const ValueKey('status-save-button')));
    await _pumpNavigation(tester);

    expect(find.text('SOAT ACTIVO'), findsOneWidget);
    expect(find.text('¡Todo en regla!'), findsOneWidget);
    expect(find.text('Seguros Alfa'), findsOneWidget);
    expect(find.text('SOAT-123'), findsOneWidget);
  });

  testWidgets(
    'SOAT warning states use renewal hierarchy without fake history',
    (tester) async {
      final vehicle = await _createVehicle(harness, plate: 'AAA111');
      await VehicleObligationStore(harness.database).upsert(
        vehicleId: vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 8, 30),
      );

      await _openModule(tester, harness, 'soat');

      expect(find.text('SOAT POR VENCER'), findsOneWidget);
      expect(find.text('RENOVAR SOAT'), findsOneWidget);
      expect(find.text('Aún no hay registros anteriores.'), findsOneWidget);
    },
  );

  testWidgets('RTM owner screen shows Buscar CDA and certificate metadata', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'RTM123');
    await VehicleObligationStore(harness.database).upsert(
      vehicleId: vehicle.id,
      type: VehicleObligationType.rtm,
      startDate: DateTime(2026),
      dueDate: DateTime(2027),
      details: const {
        'cdaName': 'CDA AutoMás El Dorado',
        'certificateNumber': '56025678901',
      },
    );

    await _openModule(tester, harness, 'tecnomecanica');

    expect(find.text('RTM VIGENTE'), findsOneWidget);
    expect(find.text('BUSCAR CDA'), findsOneWidget);
    expect(find.text('CDA AutoMás El Dorado'), findsOneWidget);
    expect(find.text('56025678901'), findsOneWidget);
    expect(find.text('Aún no has cargado tu certificado.'), findsOneWidget);
  });

  testWidgets('RTM not configured is truthful and keeps Buscar CDA available', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'RTM000');

    await _openModule(tester, harness, 'tecnomecanica');

    expect(find.text('RTM SIN CONFIGURAR'), findsOneWidget);
    expect(find.text('Configura tu tecnomecánica'), findsOneWidget);
    expect(find.text('BUSCAR CDA'), findsOneWidget);
    expect(find.textContaining('CDA AutoMás'), findsNothing);
    expect(find.textContaining('560256'), findsNothing);
  });

  testWidgets(
    'expired SOAT shows expired state without official verification claim',
    (tester) async {
      final vehicle = await _createVehicle(harness, plate: 'OLD111');
      await VehicleObligationStore(harness.database).upsert(
        vehicleId: vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 1, 1),
      );

      await _openModule(tester, harness, 'soat');

      expect(find.text('SOAT VENCIDO'), findsOneWidget);
      expect(find.text('RENOVAR SOAT'), findsOneWidget);
      expect(find.textContaining('Verificado oficialmente'), findsNothing);
    },
  );

  testWidgets('SOAT and RTM expose official RUNT link only by user action', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'AAA111');
    final launcher = _CapturingLauncher();

    await _openModule(tester, harness, 'soat', externalLauncher: launcher);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('owner-runt-soat')),
      280,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('owner-runt-soat')));
    await tester.pump();

    await _openModule(
      tester,
      harness,
      'tecnomecanica',
      externalLauncher: launcher,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('owner-runt-rtm')),
      280,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('owner-runt-rtm')));
    await tester.pump();

    expect(launcher.openedUris, [
      'https://www.runt.gov.co/actores/ciudadano/consulta-de-vehiculos-por-placa',
      'https://www.runt.gov.co/actores/ciudadano/consulta-de-vehiculos-por-placa',
    ]);
  });

  testWidgets('vehicle selector changes only local screen context', (
    tester,
  ) async {
    final first = await _createVehicle(harness, plate: 'AAA111');
    final second = await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(first.id);

    await _openModule(tester, harness, 'soat');
    expect(find.text('AAA111'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('owner-vehicle-selector')));
    await _pumpNavigation(tester);
    await tester.tap(find.byKey(ValueKey('vehicle-selector-${second.id}')));
    await _pumpNavigation(tester);

    expect(find.text('BBB222'), findsWidgets);
    expect(
      await harness.preferences.getString(
        VehicleRepository.activeVehiclePreferenceKey,
      ),
      first.id,
    );
  });

  testWidgets('SOAT document state shows local copy without official claim', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'AAA111');
    await VehicleObligationStore(harness.database).upsert(
      vehicleId: vehicle.id,
      type: VehicleObligationType.soat,
      dueDate: DateTime(2026, 12, 31),
    );

    await _openModule(
      tester,
      harness,
      'soat',
      documentMetadataOverride: PrivateVehicleDocumentMetadata(
        documentId: 'existing-soat-document',
        vehicleId: vehicle.id,
        documentType: PrivateVehicleDocumentType.soat,
        originalName: 'soat.pdf',
        mimeType: 'application/pdf',
        importedAt: DateTime.utc(2026, 8, 30, 12),
        encryptedRelativePath:
            'docs/soat/${vehicle.id}/existing-soat-document.prcf',
      ),
    );

    expect(find.text('Póliza guardada'), findsOneWidget);
    expect(find.text('Ver SOAT'), findsWidgets);
    expect(find.textContaining('Verificado oficialmente'), findsNothing);
  });

  testWidgets('SOAT and RTM owner screens tolerate R03B viewports', (
    tester,
  ) async {
    for (final viewport in [
      (name: '360x800', size: const Size(360, 800), scale: 1.0),
      (name: '390x844', size: const Size(390, 844), scale: 1.0),
      (name: '412x915', size: const Size(412, 915), scale: 1.0),
      (name: '390x844 textScale 1.5', size: const Size(390, 844), scale: 1.5),
      (name: '390x844 textScale 2.0', size: const Size(390, 844), scale: 2.0),
    ]) {
      await _createVehicle(harness, plate: _plateForViewport(viewport.name));
      for (final moduleId in ['soat', 'tecnomecanica']) {
        await _openModule(
          tester,
          harness,
          moduleId,
          size: viewport.size,
          textScaleFactor: viewport.scale,
        );
        expect(
          find.byKey(
            ValueKey(
              moduleId == 'soat' ? 'owner-status-soat' : 'owner-status-rtm',
            ),
          ),
          findsOneWidget,
          reason: '${viewport.name} $moduleId',
        );
        expect(tester.takeException(), isNull, reason: viewport.name);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      await harness.dispose();
      harness = TestAppHarness();
    }
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
    await _pumpNavigation(tester);
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
  VehicleDocumentGateway? documentGateway,
  PrivateVehicleDocumentMetadata? documentMetadataOverride,
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final vehicles = await harness.repository.listVehicles();
  final activeVehicle = await harness.repository.getActiveVehicle();
  await harness.pump(
    tester,
    externalLauncher: externalLauncher,
    documentGateway: documentGateway,
    vehicleListOverride: vehicles,
    activeVehicleOverride: activeVehicle,
    documentVehicleIdOverride: documentMetadataOverride?.vehicleId,
    documentTypeOverride: documentMetadataOverride?.documentType,
    documentMetadataOverride: documentMetadataOverride,
    childOverride: MaterialApp(
      home: VehicleStatusScreen(moduleId: moduleId, vehicleId: null),
    ),
  );
  await _pumpNavigation(tester);
}

Future<void> _pumpNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 500));
  for (var i = 0; i < 5; i += 1) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _enterText(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

String _plateForViewport(String name) {
  return switch (name) {
    '360x800' => 'VP360A',
    '390x844' => 'VP390A',
    '412x915' => 'VP412A',
    '390x844 textScale 1.5' => 'VP151A',
    '390x844 textScale 2.0' => 'VP201A',
    _ => 'VP000A',
  };
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
