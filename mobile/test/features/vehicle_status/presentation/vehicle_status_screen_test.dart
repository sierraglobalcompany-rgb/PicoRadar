import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/home/data/home_banner_config.dart';
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
      expect(find.text('ACTUALIZAR DATOS DEL SOAT'), findsOneWidget);
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
      expect(find.text('ACTUALIZAR DATOS DEL SOAT'), findsOneWidget);
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

  testWidgets('SOAT official RUNT exception is visible', (tester) async {
    await _createVehicle(harness, plate: 'AAA111');
    final launcher = _CapturingLauncher(throwOnOpen: true);

    await _openModule(tester, harness, 'soat', externalLauncher: launcher);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('owner-runt-soat')),
      280,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('owner-runt-soat')));
    await tester.pump();

    expect(find.text('No pudimos abrir RUNT.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('SOAT attach clears picker plaintext cache after local import', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'TMP123');
    final source = File('picked-soat.pdf');
    final gateway = _CapturingDocumentGateway(
      openResult: true,
      pickedDocument: PickedVehicleDocument(
        file: source,
        originalName: 'picked-soat.pdf',
        mimeType: 'application/pdf',
      ),
    );
    final store = _CapturingDocumentStore();

    await _openModule(
      tester,
      harness,
      'soat',
      documentGateway: gateway,
      documentStoreOverride: store,
    );
    await tester.tap(find.byKey(const ValueKey('owner-document-action-soat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(store.importedMetadata?.vehicleId, vehicle.id);
    expect(store.importedMetadata?.originalName, 'picked-soat.pdf');
    expect(gateway.clearTemporaryFileCalls, 1);
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

  testWidgets(
    'vehicle selector uses plate data without hardcoded Bogota text',
    (tester) async {
      await _createVehicle(harness, plate: 'MED123', city: 'Medellin');

      await _openModule(tester, harness, 'soat');

      expect(find.text('MED123'), findsWidgets);
      expect(find.text('BOGOTÁ D.C.'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('owner-vehicle-selector')));
      await _pumpNavigation(tester);

      expect(find.text('MED123'), findsWidgets);
      expect(find.text('BOGOTÁ D.C.'), findsNothing);
    },
  );

  testWidgets(
    'document view keeps plaintext only for viewer handoff and purges on failed open',
    (tester) async {
      final vehicle = await _createVehicle(harness, plate: 'DOC123');
      await VehicleObligationStore(harness.database).upsert(
        vehicleId: vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 12, 31),
      );
      final metadata = _documentMetadata(
        vehicleId: vehicle.id,
        documentType: PrivateVehicleDocumentType.soat,
        name: 'soat.pdf',
      );
      final store = _CapturingDocumentStore(metadata: metadata);
      final gateway = _CapturingDocumentGateway(openResult: false);

      await _openModule(
        tester,
        harness,
        'soat',
        documentGateway: gateway,
        documentStoreOverride: store,
        documentMetadataOverride: metadata,
      );
      await tester.tap(find.byKey(const ValueKey('owner-primary-soat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(gateway.openedFiles, hasLength(1));
      expect(store.decryptCalls, 1);
      expect(store.purgedMetadata, metadata);
      expect(find.text('No se pudo abrir el documento.'), findsOneWidget);
    },
  );

  testWidgets('document plaintext cache purges when the app resumes', (
    tester,
  ) async {
    final store = _CapturingDocumentStore();

    await harness.pump(tester, documentStoreOverride: store);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(store.purgeAllCalls, 1);
  });

  testWidgets(
    'owner banners avoid fake sponsored labels and require safe URLs',
    (tester) async {
      await _createVehicle(harness, plate: 'BAN123');

      await _openModule(
        tester,
        harness,
        'soat',
        overrideHomeBannerCampaign: true,
        homeBannerCampaignOverride: null,
      );
      expect(find.text('Patrocinado'), findsNothing);

      await _openModule(
        tester,
        harness,
        'soat',
        overrideHomeBannerCampaign: true,
        homeBannerCampaignOverride: _bannerCampaign(
          kind: HomeBannerKind.house,
          targetUrl: null,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('owner-house-soat')),
        280,
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('owner-house-soat')), findsOneWidget);
      expect(find.text('PicoRadar'), findsOneWidget);
      expect(find.text('Patrocinado'), findsNothing);

      await _openModule(
        tester,
        harness,
        'soat',
        overrideHomeBannerCampaign: true,
        homeBannerCampaignOverride: _bannerCampaign(
          kind: HomeBannerKind.sponsored,
          targetUrl: 'http://unsafe.example',
        ),
      );
      expect(find.text('Patrocinado'), findsNothing);

      final launcher = _CapturingLauncher();
      await _openModule(
        tester,
        harness,
        'soat',
        externalLauncher: launcher,
        overrideHomeBannerCampaign: true,
        homeBannerCampaignOverride: _bannerCampaign(
          kind: HomeBannerKind.sponsored,
          targetUrl: 'https://sponsor.example/soat',
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('owner-sponsored-soat')),
        280,
      );
      await tester.pump();
      expect(find.text('Patrocinado'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('owner-sponsored-soat')));
      await tester.pump();
      expect(launcher.openedUris, ['https://sponsor.example/soat']);
    },
  );

  testWidgets('owner sponsored banner launcher exception is visible', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'BAN123');
    final launcher = _CapturingLauncher(throwOnOpen: true);

    await _openModule(
      tester,
      harness,
      'soat',
      externalLauncher: launcher,
      overrideHomeBannerCampaign: true,
      homeBannerCampaignOverride: _bannerCampaign(
        kind: HomeBannerKind.sponsored,
        targetUrl: 'https://sponsor.example/soat',
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('owner-sponsored-soat')),
      280,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('owner-sponsored-soat')));
    await tester.pump();

    expect(find.text('No pudimos abrir el enlace.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('insurance assistance phone failure is visible', (tester) async {
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
    final launcher = _CapturingLauncher(callResult: false);

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

    expect(find.text('No pudimos iniciar la llamada.'), findsOneWidget);
  });

  testWidgets('insurance assistance phone exception is visible', (
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
    final launcher = _CapturingLauncher(throwOnCall: true);

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

    expect(find.text('No pudimos iniciar la llamada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tax screen suggests only verified authority without estimates', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'MED123', city: 'Medellín, Antioquia');

    await _openModule(tester, harness, 'impuestos');

    expect(
      find.text(
        'PicoRadar no calcula el impuesto, no consulta deuda y no confirma si está pagado.',
      ),
      findsOneWidget,
    );
    expect(find.text('Antioquia - Gobernación de Antioquia'), findsWidgets);
    expect(find.text('Fuente: Gobernación de Antioquia'), findsOneWidget);
    expect(find.text('Calendario: 2026'), findsOneWidget);
    expect(find.text('Revisado: 3 sep 2026'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('official-link-antioquia-tax-vehicles')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('official-link-bogota-tax-vehicles')),
      findsNothing,
    );
    expect(find.textContaining('avaluo'), findsNothing);
    expect(find.textContaining('tarifa'), findsNothing);
    expect(find.textContaining('debes \$'), findsNothing);
    expect(find.textContaining('saldo'), findsNothing);
    expect(find.textContaining('deuda consultada'), findsNothing);
    expect(find.textContaining('paz y salvo'), findsNothing);
    expect(find.textContaining('liquidación calculada'), findsNothing);
  });

  testWidgets(
    'tax screen keeps unsupported city manual until authority selected',
    (tester) async {
      await _createVehicle(harness, plate: 'BEL123', city: 'Bello');

      await _openModule(tester, harness, 'impuestos');

      expect(
        find.text(
          'Selecciona la entidad tributaria correspondiente a la matrícula.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('official-link-bogota-tax-vehicles')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('official-link-antioquia-tax-vehicles')),
        findsNothing,
      );
    },
  );

  testWidgets('tax authority selection persists without replacing saved data', (
    tester,
  ) async {
    final vehicle = await _createVehicle(
      harness,
      plate: 'TAX123',
      city: 'Cali',
    );
    await VehicleObligationStore(harness.database).upsert(
      vehicleId: vehicle.id,
      type: VehicleObligationType.tax,
      startDate: DateTime(2026, 1, 2),
      dueDate: DateTime(2026, 7, 24),
      details: const {'source': 'manual-note'},
      reminderEnabled: true,
    );

    await _openModule(tester, harness, 'impuestos');
    await tester.tap(find.byKey(const ValueKey('tax-authority-field')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Bogotá - Secretaría Distrital de Hacienda').last,
    );
    await _pumpNavigation(tester);

    final saved = await VehicleObligationStore(harness.database)
        .get(vehicle.id, VehicleObligationType.tax);
    expect(saved?.startDate, DateTime(2026, 1, 2));
    expect(saved?.dueDate, DateTime(2026, 7, 24));
    expect(saved?.reminderEnabled, isTrue);
    expect(saved?.details['source'], 'manual-note');
    expect(saved?.details['authorityId'], 'bogota');
  });

  testWidgets('tax authority selection tolerates dispose during async write', (
    tester,
  ) async {
    final vehicle = await _createVehicle(
      harness,
      plate: 'ASY123',
      city: 'Cali',
    );
    final release = Completer<void>();
    final store = _DelayingObligationStore(harness.database, release);

    await _openModule(
      tester,
      harness,
      'impuestos',
      wrap: (child) => ProviderScope(
        overrides: [vehicleObligationStoreProvider.overrideWithValue(store)],
        child: child,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tax-authority-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antioquia - Gobernación de Antioquia').last);
    await tester.pump();
    expect(store.upsertStarted, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    release.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
    final saved = await VehicleObligationStore(harness.database)
        .get(vehicle.id, VehicleObligationType.tax);
    expect(saved?.details['authorityId'], 'antioquia');
  });

  testWidgets('tax portal failure is visible to the user', (tester) async {
    await _createVehicle(harness, plate: 'BOG123', city: 'Bogotá D.C.');
    final launcher = _CapturingLauncher(openResult: false);

    await _openModule(tester, harness, 'impuestos', externalLauncher: launcher);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('official-link-bogota-tax-vehicles')),
      280,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('official-link-bogota-tax-vehicles')),
    );
    await tester.pump();

    expect(launcher.openedUris, [
      'https://www.haciendabogota.gov.co/es/impuestos/impuesto-sobre-vehiculos-automotores',
    ]);
    expect(find.text('No pudimos abrir el portal oficial.'), findsOneWidget);
  });

  testWidgets('tax portal exception is visible to the user', (tester) async {
    await _createVehicle(harness, plate: 'BOG123', city: 'Bogotá D.C.');
    final launcher = _CapturingLauncher(throwOnOpen: true);

    await _openModule(tester, harness, 'impuestos', externalLauncher: launcher);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('official-link-bogota-tax-vehicles')),
      280,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('official-link-bogota-tax-vehicles')),
    );
    await tester.pump();

    expect(find.text('No pudimos abrir el portal oficial.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tax dates show past today and upcoming states without semaforizacion',
    (tester) async {
      harness.now = DateTime(2026, 7, 24, 10);
      await _createVehicle(harness, plate: 'BOG123', city: 'Bogota DC');

      await _openModule(tester, harness, 'impuestos');

      expect(find.text('Ya pasó · Pronto pago 10%'), findsOneWidget);
      expect(find.text('Hoy · Fecha límite ordinaria'), findsOneWidget);
      expect(
        find.text('Próxima · SPAC: cuota 2, si se acogió'),
        findsOneWidget,
      );
      expect(find.textContaining('semaforización'), findsNothing);
    },
  );

  testWidgets('tax screen tolerates K2D responsive text scales', (
    tester,
  ) async {
    for (final viewport in [
      (name: '360x800', size: const Size(360, 800), scale: 1.0),
      (name: '360x800 textScale 2.0', size: const Size(360, 800), scale: 2.0),
      (name: '390x844 textScale 1.5', size: const Size(390, 844), scale: 1.5),
      (name: '412x915 textScale 2.0', size: const Size(412, 915), scale: 2.0),
    ]) {
      await _createVehicle(
        harness,
        plate: _plateForViewport(viewport.name),
        city: 'Bogotá D.C.',
      );
      await _openModule(
        tester,
        harness,
        'impuestos',
        size: viewport.size,
        textScaleFactor: viewport.scale,
      );
      expect(
        find.byKey(const ValueKey('tax-authority-field')),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(
        find.byKey(const ValueKey('official-link-bogota-tax-vehicles')),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(tester.takeException(), isNull, reason: viewport.name);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
      harness = TestAppHarness();
    }
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
  PrivateVehicleDocumentStore? documentStoreOverride,
  PrivateVehicleDocumentMetadata? documentMetadataOverride,
  bool overrideHomeBannerCampaign = false,
  HomeBannerCampaign? homeBannerCampaignOverride,
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
  Widget Function(Widget child)? wrap,
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
    documentStoreOverride: documentStoreOverride,
    vehicleListOverride: vehicles,
    activeVehicleOverride: activeVehicle,
    documentVehicleIdOverride: documentMetadataOverride?.vehicleId,
    documentTypeOverride: documentMetadataOverride?.documentType,
    documentMetadataOverride: documentMetadataOverride,
    overrideHomeBannerCampaign: overrideHomeBannerCampaign,
    homeBannerCampaignOverride: homeBannerCampaignOverride,
    childOverride: MaterialApp(
      home: VehicleStatusScreen(moduleId: moduleId, vehicleId: null),
    ),
    wrap: wrap,
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
  _CapturingLauncher({
    this.openResult = true,
    this.callResult = true,
    this.throwOnOpen = false,
    this.throwOnCall = false,
  });

  final bool openResult;
  final bool callResult;
  final bool throwOnOpen;
  final bool throwOnCall;
  final calledPhones = <String>[];
  final openedUris = <String>[];

  @override
  Future<bool> callPhone(String phone) async {
    if (throwOnCall) {
      throw StateError('launcher failed');
    }
    calledPhones.add(phone);
    return callResult;
  }

  @override
  Future<bool> openExternal(String uri) async {
    if (throwOnOpen) {
      throw StateError('launcher failed');
    }
    openedUris.add(uri);
    return openResult;
  }
}

class _DelayingObligationStore extends VehicleObligationStore {
  _DelayingObligationStore(super.database, this.release);

  final Completer<void> release;
  bool upsertStarted = false;

  @override
  Future<VehicleObligation> upsert({
    required String vehicleId,
    required VehicleObligationType type,
    DateTime? startDate,
    DateTime? dueDate,
    Map<String, String> details = const {},
    bool reminderEnabled = true,
  }) async {
    upsertStarted = true;
    await release.future;
    return super.upsert(
      vehicleId: vehicleId,
      type: type,
      startDate: startDate,
      dueDate: dueDate,
      details: details,
      reminderEnabled: reminderEnabled,
    );
  }
}

class _CapturingDocumentGateway implements VehicleDocumentGateway {
  _CapturingDocumentGateway({required this.openResult, this.pickedDocument});

  final bool openResult;
  final PickedVehicleDocument? pickedDocument;
  final openedFiles = <File>[];
  int clearTemporaryFileCalls = 0;

  @override
  Future<void> clearTemporaryFiles() async {
    clearTemporaryFileCalls += 1;
  }

  @override
  Future<bool> openDocument(File file) async {
    openedFiles.add(file);
    return openResult;
  }

  @override
  Future<PickedVehicleDocument?> pickDocument() async => pickedDocument;
}

class _CapturingDocumentStore extends PrivateVehicleDocumentStore {
  _CapturingDocumentStore({this.metadata});

  PrivateVehicleDocumentMetadata? metadata;
  PrivateVehicleDocumentMetadata? importedMetadata;
  int decryptCalls = 0;
  int purgeAllCalls = 0;
  PrivateVehicleDocumentMetadata? purgedMetadata;

  @override
  Future<PrivateVehicleDocumentMetadata?> get({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
  }) async {
    return metadata;
  }

  @override
  Future<PrivateVehicleDocumentMetadata> importDocument({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
    required File source,
    required String originalName,
    required String mimeType,
  }) async {
    importedMetadata = PrivateVehicleDocumentMetadata(
      documentId: 'imported-${documentType.value}',
      vehicleId: vehicleId,
      documentType: documentType,
      originalName: originalName,
      mimeType: mimeType,
      importedAt: DateTime.utc(2026, 8, 30, 12),
      encryptedRelativePath:
          'docs/${documentType.value}/$vehicleId/imported.prcf',
    );
    metadata = importedMetadata;
    return importedMetadata!;
  }

  @override
  Future<File> decryptForView(PrivateVehicleDocumentMetadata metadata) async {
    decryptCalls += 1;
    return File('viewer-${metadata.documentId}-${metadata.originalName}');
  }

  @override
  Future<void> purgeViewerCache({
    PrivateVehicleDocumentMetadata? metadata,
  }) async {
    if (metadata == null) {
      purgeAllCalls += 1;
    } else {
      purgedMetadata = metadata;
    }
  }
}

PrivateVehicleDocumentMetadata _documentMetadata({
  required String vehicleId,
  required PrivateVehicleDocumentType documentType,
  required String name,
}) {
  return PrivateVehicleDocumentMetadata(
    documentId: 'metadata-${documentType.value}',
    vehicleId: vehicleId,
    documentType: documentType,
    originalName: name,
    mimeType: name.endsWith('.pdf') ? 'application/pdf' : 'image/png',
    importedAt: DateTime.utc(2026, 8, 30, 12),
    encryptedRelativePath: 'docs/${documentType.value}/$vehicleId/test.prcf',
  );
}

HomeBannerCampaign _bannerCampaign({
  required HomeBannerKind kind,
  required String? targetUrl,
}) {
  return HomeBannerCampaign(
    id: 'test-${kind.name}',
    kind: kind,
    enabled: true,
    label: '',
    title: '',
    subtitle: '',
    ctaText: '',
    priority: 1,
    targetUrl: targetUrl,
  );
}
