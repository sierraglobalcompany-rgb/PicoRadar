import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/documents/presentation/wallet_viewer.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/home/data/home_banner_config.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';
import 'package:picoradar/features/vehicle_status/presentation/vehicle_status_screen.dart';
import 'package:picoradar/features/vehicle_status/presentation/soat_rtm_owner_content.dart';

import '../../../test_app_harness.dart';
import 'v01b_obligations_test_font.dart';

void main() {
  setUpAll(loadV01bObligationsTestFont);
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('V01B tax authority text fits $size scale $scale', (
        tester,
      ) async {
        final vehicle = await _createVehicle(
          harness,
          plate: 'QA1234',
          city: 'Bogota DC',
        );
        await _openModule(
          tester,
          harness,
          'impuestos',
          size: size,
          textScaleFactor: scale,
          productionTheme: true,
        );
        final authority = find.byKey(const ValueKey('tax-authority-field'));
        await tester.ensureVisible(authority);
        await tester.pump();
        final text =
            [
              authority,
              find.byKey(const ValueKey('tax-authority-name')),
              find.text('Secretaría Distrital de Hacienda'),
            ].expand(
              (target) => find
                  .descendant(of: target, matching: find.byType(RichText))
                  .evaluate(),
            );
        for (final element in text) {
          final paragraph = element.renderObject! as RenderParagraph;
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: paragraph.text.toPlainText().length,
            ),
          );
          for (final box in boxes) {
            expect(
              box.bottom,
              lessThanOrEqualTo(paragraph.size.height + 0.1),
              reason: paragraph.text.toPlainText(),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
          }
        }
        expect(authority.hitTestable(), findsOneWidget);
        await _chooseTaxAuthority(tester, 'antioquia');
        expect(
          await VehicleObligationStore(harness.database)
              .get(vehicle.id, VehicleObligationType.tax),
          isNull,
        );
        expect(find.text('Consulta temporal'), findsOneWidget);
        await _saveTaxAuthority(tester);
        final saved = await VehicleObligationStore(harness.database)
            .get(vehicle.id, VehicleObligationType.tax);
        expect(saved?.details['authorityId'], 'antioquia');
        expect(tester.takeException(), isNull);
      });
      for (final type in [
        VehicleObligationType.soat,
        VehicleObligationType.rtm,
      ]) {
        testWidgets(
          'V01B ${type.value} facts are readable $size scale $scale',
          (tester) async {
            final vehicle = await _createVehicle(harness, plate: 'QA1234');
            await VehicleObligationStore(harness.database).upsert(
              vehicleId: vehicle.id,
              type: type,
              dueDate: DateTime(2026, 12, 31),
              details: type == VehicleObligationType.soat
                  ? const {
                      'insurerName': 'Seguros de prueba nombre completo',
                      'policyNumber': 'QA-12345678901234567890',
                    }
                  : const {
                      'cdaName': 'Centro de diagnostico de prueba completo',
                      'certificateNumber': 'QA-12345678901234567890',
                    },
            );
            await _openModule(
              tester,
              harness,
              type == VehicleObligationType.soat ? 'soat' : 'tecnomecanica',
              size: size,
              textScaleFactor: scale,
              productionTheme: true,
            );
            final hero = find.byKey(ValueKey('owner-hero-${type.value}'));
            final paragraphs = find.descendant(
              of: hero,
              matching: find.byType(RichText),
            );
            for (final element in paragraphs.evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '${type.value}: ${paragraph.text.toPlainText()}',
              );
              final bounds = tester.getRect(hero).inflate(0.1);
              for (final box in paragraph.getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: paragraph.text.toPlainText().length,
                ),
              )) {
                expect(
                  bounds.contains(
                    paragraph.localToGlobal(box.toRect().topLeft),
                  ),
                  isTrue,
                  reason: paragraph.text.toPlainText(),
                );
                expect(
                  bounds.contains(
                    paragraph.localToGlobal(box.toRect().bottomRight),
                  ),
                  isTrue,
                  reason: paragraph.text.toPlainText(),
                );
              }
            }
            expect(find.text('31 DIC 2026'), findsOneWidget);
            expect(find.text('QA-12345678901234567890'), findsOneWidget);
            await tester.ensureVisible(find.text('QA-12345678901234567890'));
            await tester.pumpAndSettle();
            expect(
              find.text('QA-12345678901234567890').hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'V01B ${type.value} saved document CTA fits $size scale $scale',
          (tester) async {
            final vehicle = await _createVehicle(harness, plate: 'QA1234');
            final isSoat = type == VehicleObligationType.soat;
            await _openModule(
              tester,
              harness,
              isSoat ? 'soat' : 'tecnomecanica',
              size: size,
              textScaleFactor: scale,
              productionTheme: true,
              documentMetadataOverride: PrivateVehicleDocumentMetadata(
                documentId: 'qa-saved-copy',
                vehicleId: vehicle.id,
                documentType: isSoat
                    ? PrivateVehicleDocumentType.soat
                    : PrivateVehicleDocumentType.rtm,
                originalName: 'qa.pdf',
                mimeType: 'application/pdf',
                importedAt: DateTime.utc(2026, 8, 30, 12),
                encryptedRelativePath: 'docs/qa-saved-copy.prcf',
              ),
            );
            final button = find.byKey(
              ValueKey('owner-document-action-${type.value}'),
            );
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            final label = find.descendant(
              of: button,
              matching: find.byType(Text),
            );
            expect(
              find.descendant(
                of: button,
                matching: find.text(isSoat ? 'Ver SOAT' : 'Ver certificado'),
              ),
              findsOneWidget,
            );
            final surface = tester.getRect(
              find.descendant(of: button, matching: find.byType(Material)),
            );
            final text = tester.getRect(label);
            expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
            expect(text.top - surface.top, greaterThanOrEqualTo(4));
            expect(surface.bottom - text.bottom, greaterThanOrEqualTo(4));
            expect(button.hitTestable(), findsOneWidget);
            final menu = find.byKey(
              ValueKey('owner-document-menu-${type.value}'),
            );
            await tester.ensureVisible(menu);
            await tester.pumpAndSettle();
            expect(menu.hitTestable(), findsOneWidget);
            await tester.tap(menu);
            await tester.pumpAndSettle();
            expect(find.text('Reemplazar').hitTestable(), findsOneWidget);
            expect(find.text('Eliminar copia').hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets('V01B ${type.value} document CTA fits $size scale $scale', (
          tester,
        ) async {
          await _createVehicle(harness, plate: 'QA1234');
          await _openModule(
            tester,
            harness,
            type == VehicleObligationType.soat ? 'soat' : 'tecnomecanica',
            size: size,
            textScaleFactor: scale,
            productionTheme: true,
          );
          final button = find.byKey(
            ValueKey('owner-document-action-${type.value}'),
          );
          await tester.ensureVisible(button);
          await tester.pump();
          final label = find.descendant(
            of: button,
            matching: find.byType(Text),
          );
          final material = find.descendant(
            of: button,
            matching: find.byType(Material),
          );
          final surface = tester.getRect(material);
          final text = tester.getRect(label);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
          expect(text.top - surface.top, greaterThanOrEqualTo(4));
          expect(surface.bottom - text.bottom, greaterThanOrEqualTo(4));
          expect(button.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final type in [VehicleObligationType.soat, VehicleObligationType.rtm]) {
    final module = type == VehicleObligationType.soat
        ? 'soat'
        : 'tecnomecanica';
    testWidgets(
      'F09 $module rejects invalid dates without replacing saved data',
      (tester) async {
        final vehicle = await _createVehicle(harness, plate: 'AAA111');
        final store = VehicleObligationStore(harness.database);
        final original = await store.upsert(
          vehicleId: vehicle.id,
          type: type,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 12, 31),
        );
        await _openModule(tester, harness, module);
        tester
            .widget<SoatRtmOwnerContent>(find.byType(SoatRtmOwnerContent))
            .onEdit();
        await _pumpNavigation(tester);
        for (final input in ['2026-02-31', '31/12/2026', '2025-12-31']) {
          await _enterText(tester, 'status-due-date-field', input);
          await tester.tap(find.byKey(const ValueKey('status-save-button')));
          await _pumpNavigation(tester);
          expect(find.byType(AlertDialog), findsOneWidget, reason: input);
          expect(
            find.byKey(const ValueKey('status-date-error')),
            findsOneWidget,
          );
          final saved = await store.get(vehicle.id, type);
          expect(saved?.dueDate, original.dueDate, reason: input);
          expect(saved?.updatedAt, original.updatedAt, reason: input);
          expect(tester.takeException(), isNull);
        }
        await _enterText(tester, 'status-due-date-field', '2028-02-29');
        await _enterText(tester, 'status-start-date-field', '2026-13-01');
        await tester.tap(find.byKey(const ValueKey('status-save-button')));
        await _pumpNavigation(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          (await store.get(vehicle.id, type))?.startDate,
          original.startDate,
        );
        await _enterText(tester, 'status-start-date-field', '2026-01-01');
        await tester.tap(find.byKey(const ValueKey('status-save-button')));
        await _pumpNavigation(tester);
        expect(
          (await store.get(vehicle.id, type))?.dueDate,
          DateTime(2028, 2, 29),
        );
        tester
            .widget<SoatRtmOwnerContent>(find.byType(SoatRtmOwnerContent))
            .onEdit();
        await _pumpNavigation(tester);
        await _enterText(tester, 'status-start-date-field', '');
        await _enterText(tester, 'status-due-date-field', '');
        await tester.tap(find.byKey(const ValueKey('status-save-button')));
        await _pumpNavigation(tester);
        final cleared = await store.get(vehicle.id, type);
        expect(cleared?.startDate, isNull);
        expect(cleared?.dueDate, isNull);
      },
    );

    testWidgets('F09 $module missing explicit vehicle never uses favorite', (
      tester,
    ) async {
      final vehicle = await _createVehicle(harness, plate: 'AAA111');
      await _openModule(tester, harness, module, vehicleId: 'deleted-vehicle');
      expect(find.text('Este vehículo ya no está disponible.'), findsOneWidget);
      expect(find.byKey(ValueKey('owner-primary-${type.value}')), findsNothing);
      expect(
        await VehicleObligationStore(harness.database).get(vehicle.id, type),
        isNull,
      );
    });
  }

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

  testWidgets(
    'locked SOAT keeps dates visible and closes sheet authorization',
    (tester) async {
      final vehicle = await _createVehicle(harness, plate: 'SEC123');
      await VehicleObligationStore(harness.database).upsert(
        vehicleId: vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 12, 31),
      );
      final session = WalletSession(
        authenticator: _OwnerAuthenticator(),
        preferences: _OwnerPreferences(),
      );
      addTearDown(session.dispose);
      await _openModule(
        tester,
        harness,
        'soat',
        walletSessionOverride: session,
        unlockWallet: false,
        documentMetadataOverride: _documentMetadata(
          vehicleId: vehicle.id,
          documentType: PrivateVehicleDocumentType.soat,
          name: 'sensitive-policy.pdf',
        ),
      );
      expect(find.text('31 DIC 2026'), findsOneWidget);
      expect(find.text('Póliza guardada'), findsNothing);
      expect(find.text('sensitive-policy.pdf'), findsNothing);
      expect(find.text('Adjuntar SOAT'), findsNothing);
      expect(find.text('Ver documentos'), findsWidgets);
      final action = find.byKey(const ValueKey('owner-document-action-soat'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('documents-vehicle-sheet-scroll')),
        findsOneWidget,
      );
      expect(session.accessAllowed, isTrue);
      await tester.tap(find.byTooltip('Cerrar documentos del vehículo'));
      await tester.pumpAndSettle();
      expect(session.accessAllowed, isFalse);
      expect(find.text('Póliza guardada'), findsNothing);
      expect(find.text('31 DIC 2026'), findsOneWidget);
    },
  );

  testWidgets('SOAT denied authentication never opens private sheet', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'DEN123');
    final session = WalletSession(
      authenticator: _OwnerAuthenticator(allow: false),
      preferences: _OwnerPreferences(protected: true),
    );
    addTearDown(session.dispose);
    await _openModule(
      tester,
      harness,
      'soat',
      walletSessionOverride: session,
      unlockWallet: false,
    );
    final action = find.byKey(const ValueKey('owner-document-action-soat'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('documents-vehicle-sheet-scroll')),
      findsNothing,
    );
    expect(session.accessAllowed, isFalse);
    expect(find.textContaining('Autenticación cancelada'), findsOneWidget);
  });

  testWidgets('SOAT lock masks previously loaded copy immediately', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'LCK123');
    final session = WalletSession(
      authenticator: _OwnerAuthenticator(),
      preferences: _OwnerPreferences(),
    );
    addTearDown(session.dispose);
    await _openModule(
      tester,
      harness,
      'soat',
      walletSessionOverride: session,
      documentMetadataOverride: _documentMetadata(
        vehicleId: vehicle.id,
        documentType: PrivateVehicleDocumentType.soat,
        name: 'private.pdf',
      ),
    );
    expect(find.text('Póliza guardada'), findsOneWidget);
    session.lock();
    await tester.pump();
    expect(find.text('Póliza guardada'), findsNothing);
    expect(
      find.byKey(const ValueKey('owner-document-menu-soat')),
      findsNothing,
    );
    expect(find.text('Ver documentos'), findsWidgets);
  });

  testWidgets('SOAT attach clears picker plaintext cache after local import', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'TMP123');
    final source = File('${harness.documentRoot.path}/picked-soat.pdf');
    source.writeAsStringSync('%PDF-1.7 fixture');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => harness.documentRoot.path,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      ),
    );
    final gateway = _CapturingDocumentGateway(
      openResult: true,
      pickedDocument: PickedVehicleDocument(
        file: source,
        originalName: 'picked-soat.pdf',
        mimeType: 'application/pdf',
      ),
      deletePickedFileOnClear: true,
    );
    final store = _CapturingWalletStore(harness.documentRoot);

    await _openModule(
      tester,
      harness,
      'soat',
      documentGateway: gateway,
      walletStoreOverride: store,
    );
    await tester.tap(find.byKey(const ValueKey('owner-document-action-soat')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('Importar archivo')));
    await _finishWalletIo(
      tester,
      until: () => tester
          .widgetList<FilledButton>(
            find.byKey(const ValueKey('wallet-viewer-save')),
          )
          .any((button) => button.onPressed != null),
    );
    expect(find.byType(WalletViewer), findsOneWidget);
    expect(store.saved, isNull);
    expect(source.existsSync(), isFalse);
    await tester.tap(find.byKey(const ValueKey('wallet-viewer-save')));
    await _finishWalletIo(tester);
    expect(store.saved?.owner, WalletOwner.vehicle(vehicle.id));
    expect(store.saved?.type, WalletDocumentType.soat);
    expect(store.saved?.pdf?.originalName, 'picked-soat.pdf');
    expect(gateway.clearTemporaryFileCalls, greaterThanOrEqualTo(1));
    expect(gateway.openedFiles, isEmpty);
    expect(
      Directory('${harness.documentRoot.path}/wallet_pending').listSync(),
      isEmpty,
    );
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
    'document view stays in wallet viewer and purges temporary copies on close',
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
      final store = _CapturingWalletStore(harness.documentRoot);
      final gateway = _CapturingDocumentGateway(openResult: false);

      await _openModule(
        tester,
        harness,
        'soat',
        documentGateway: gateway,
        walletStoreOverride: store,
        documentMetadataOverride: metadata,
      );
      await tester.tap(find.byKey(const ValueKey('owner-primary-soat')));
      await _finishWalletIo(
        tester,
        until: () =>
            find.byType(WalletViewer).evaluate().isNotEmpty &&
            store.viewerFile != null &&
            !store.viewerFile!.existsSync(),
      );
      expect(find.byType(WalletViewer), findsOneWidget);
      expect(gateway.openedFiles, isEmpty);
      expect(store.decryptCalls, 1);
      expect(store.viewerFile!.existsSync(), isFalse);
      await tester.tap(find.byTooltip('Volver').last);
      await _finishWalletIo(tester);
      expect(store.purgeAllCalls, greaterThanOrEqualTo(1));
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
    await tester.tap(find.byKey(const ValueKey('insurance-assistance')));
    await _pumpNavigation(tester);
    await tester.tap(callButton);
    await tester.pump();

    expect(launcher.calledPhones, ['6011111111']);
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
    await tester.tap(find.byKey(const ValueKey('insurance-assistance')));
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
    await tester.tap(find.byKey(const ValueKey('insurance-assistance')));
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
        'Calendario informativo. No calculamos deuda ni confirmamos pagos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Antioquia'), findsOneWidget);
    expect(find.text('Gobernación de Antioquia'), findsOneWidget);
    expect(find.text('Calendario 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('tax-open-portal')), findsOneWidget);
    expect(find.text('Bogotá D. C.'), findsNothing);
    expect(find.textContaining('avaluo'), findsNothing);
    expect(find.textContaining('tarifa'), findsNothing);
    expect(find.textContaining('debes \$'), findsNothing);
    expect(find.textContaining('saldo'), findsNothing);
    expect(find.textContaining('deuda consultada'), findsNothing);
    expect(find.textContaining('paz y salvo'), findsNothing);
    expect(find.textContaining('liquidación calculada'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('tax-source')));
    await tester.tap(find.byKey(const ValueKey('tax-source')));
    await tester.pumpAndSettle();
    expect(find.text('Calendario revisado: 3 sept 2026'), findsOneWidget);
    expect(
      find.text(
        'PicoRadar no calcula el impuesto, no consulta deuda y no confirma si está pagado.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tax screen keeps unsupported city manual until authority selected',
    (tester) async {
      final vehicle = await _createVehicle(
        harness,
        plate: 'BEL123',
        city: 'Municipio desconocido',
      );

      await _openModule(tester, harness, 'impuestos');

      expect(
        find.text(
          'Selecciona la entidad correspondiente a la matrícula del vehículo.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tax-open-portal')), findsNothing);
      await _chooseTaxAuthority(tester, 'antioquia');
      expect(find.text('Antioquia'), findsOneWidget);
      expect(find.byKey(const ValueKey('tax-open-portal')), findsOneWidget);
      expect(
        await VehicleObligationStore(harness.database)
            .get(vehicle.id, VehicleObligationType.tax),
        isNull,
      );
    },
  );

  testWidgets(
    'tax authority explicit save persists without replacing saved data',
    (tester) async {
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
        details: const {'source': 'manual-note', 'authorityId': 'antioquia'},
        reminderEnabled: true,
      );

      await _openModule(tester, harness, 'impuestos');
      await _chooseTaxAuthority(tester, 'bogota');
      final beforeSave = await VehicleObligationStore(harness.database)
          .get(vehicle.id, VehicleObligationType.tax);
      expect(beforeSave?.details['authorityId'], 'antioquia');
      expect(find.text('Consulta temporal'), findsOneWidget);
      await _saveTaxAuthority(tester);

      final saved = await VehicleObligationStore(harness.database)
          .get(vehicle.id, VehicleObligationType.tax);
      expect(saved?.startDate, DateTime(2026, 1, 2));
      expect(saved?.dueDate, DateTime(2026, 7, 24));
      expect(saved?.reminderEnabled, isTrue);
      expect(saved?.details['source'], 'manual-note');
      expect(saved?.details['authorityId'], 'bogota');
      expect(saved?.createdAt, beforeSave?.createdAt);
      expect(find.text('Consulta temporal'), findsNothing);
    },
  );

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
    await _chooseTaxAuthority(tester, 'antioquia');
    expect(store.upsertStarted, isFalse);
    final save = find.byKey(const ValueKey('tax-save-authority'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(store.upsertStarted, isTrue);
    expect(tester.widget<TextButton>(save).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    release.complete();
    await _pumpNavigation(tester);

    expect(tester.takeException(), isNull);
    final saved = await VehicleObligationStore(harness.database)
        .get(vehicle.id, VehicleObligationType.tax);
    expect(saved?.details['authorityId'], 'antioquia');
  });

  testWidgets('tax save failure keeps prior authority and permits retry', (
    tester,
  ) async {
    final vehicle = await _createVehicle(harness, plate: 'ERR123');
    final original = await VehicleObligationStore(harness.database).upsert(
      vehicleId: vehicle.id,
      type: VehicleObligationType.tax,
      details: const {'authorityId': 'bogota', 'source': 'manual-note'},
      dueDate: DateTime(2026, 7, 24),
      reminderEnabled: false,
    );
    final store = _RetryTaxObligationStore(harness.database);
    await _openModule(
      tester,
      harness,
      'impuestos',
      wrap: (child) => ProviderScope(
        overrides: [vehicleObligationStoreProvider.overrideWithValue(store)],
        child: child,
      ),
    );
    await _chooseTaxAuthority(tester, 'antioquia');
    await _saveTaxAuthority(tester);
    expect(
      find.text(
        'No pudimos guardar la entidad. Conservamos la anterior; vuelve a intentarlo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Consulta temporal'), findsOneWidget);
    final failed = await store.get(vehicle.id, VehicleObligationType.tax);
    expect(failed?.details, original.details);
    expect(failed?.updatedAt, original.updatedAt);
    await _saveTaxAuthority(tester);
    final saved = await store.get(vehicle.id, VehicleObligationType.tax);
    expect(saved?.details, {
      'authorityId': 'antioquia',
      'source': 'manual-note',
    });
    expect(saved?.dueDate, original.dueDate);
    expect(saved?.reminderEnabled, isFalse);
    expect(store.attempts, 2);
  });

  testWidgets(
    'tax catalog loading resolves without changing stored selection',
    (tester) async {
      final vehicle = await _createVehicle(harness, plate: 'LOD123');
      final pending = Completer<TaxCatalog>();
      await _openModule(
        tester,
        harness,
        'impuestos',
        taxCatalogLoader: () => pending.future,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('tax-authority-field')), findsNothing);
      pending.complete(_taxFixtureCatalog());
      await _pumpNavigation(tester);
      expect(find.text('Bogotá D. C.'), findsOneWidget);
      expect(
        await VehicleObligationStore(harness.database)
            .get(vehicle.id, VehicleObligationType.tax),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tax catalog load failure retries successfully', (tester) async {
    await _createVehicle(harness, plate: 'RET123');
    var attempts = 0;
    await _openModule(
      tester,
      harness,
      'impuestos',
      taxCatalogLoader: () async {
        if (++attempts == 1) throw StateError('fixture load failure');
        return _taxFixtureCatalog();
      },
    );
    expect(
      find.text('No pudimos cargar las entidades tributarias.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await _pumpNavigation(tester);
    expect(attempts, 2);
    expect(find.text('Bogotá D. C.'), findsOneWidget);
    expect(
      find.text('No pudimos cargar las entidades tributarias.'),
      findsNothing,
    );
  });

  testWidgets('tax portal failure is visible to the user', (tester) async {
    await _createVehicle(harness, plate: 'BOG123', city: 'Bogotá D.C.');
    final launcher = _CapturingLauncher(openResult: false);

    await _openModule(tester, harness, 'impuestos', externalLauncher: launcher);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tax-open-portal')),
      280,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tax-open-portal')));
    await tester.pump();

    expect(launcher.openedUris, [
      'https://www.haciendabogota.gov.co/es/impuestos/impuesto-sobre-vehiculos-automotores',
    ]);
    expect(find.text('No pudimos abrir el portal oficial.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Reintentar').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(launcher.openedUris, [_taxBogotaPortal, _taxBogotaPortal]);
  });

  testWidgets('tax portal exception is visible to the user', (tester) async {
    await _createVehicle(harness, plate: 'BOG123', city: 'Bogotá D.C.');
    final launcher = _CapturingLauncher(throwOnOpen: true);

    await _openModule(tester, harness, 'impuestos', externalLauncher: launcher);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tax-open-portal')),
      280,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tax-open-portal')));
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

      expect(find.text('Próximas fechas'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tax-event-bogota-ordinary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tax-event-bogota-installment')),
        findsOneWidget,
      );
      expect(find.text('Si se acogió al pago por cuotas'), findsOneWidget);
      expect(find.text('Pronto pago 10%'), findsNothing);
      final history = find.byKey(const ValueKey('tax-past-dates'));
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(find.text('Pronto pago 10%'), findsOneWidget);
      expect(find.textContaining('Ya pasó'), findsNothing);
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
        find.byKey(const ValueKey('tax-open-portal')),
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
  String? vehicleId,
  ExternalLauncher? externalLauncher,
  VehicleDocumentGateway? documentGateway,
  PrivateVehicleDocumentStore? documentStoreOverride,
  PrivateVehicleDocumentMetadata? documentMetadataOverride,
  WalletStore? walletStoreOverride,
  WalletSession? walletSessionOverride,
  bool unlockWallet = true,
  bool overrideHomeBannerCampaign = false,
  HomeBannerCampaign? homeBannerCampaignOverride,
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
  bool productionTheme = false,
  Future<TaxCatalog> Function()? taxCatalogLoader,
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
    childOverride: ProviderScope(
      overrides: [
        walletPlatformProvider.overrideWithValue(_OwnerWalletPlatform()),
        if (walletStoreOverride != null)
          walletStoreProvider.overrideWithValue(walletStoreOverride),
        if (walletSessionOverride != null)
          walletSessionProvider.overrideWithValue(walletSessionOverride),
        for (final vehicle in vehicles)
          walletDocumentsProvider(WalletOwner.vehicle(vehicle.id))
              .overrideWith((ref) async {
                if (documentMetadataOverride?.vehicleId == vehicle.id) {
                  return [_walletDocument(documentMetadataOverride!)];
                }
                return walletStoreOverride == null
                    ? []
                    : walletStoreOverride.listDocuments(
                        owner: WalletOwner.vehicle(vehicle.id),
                      );
              }),
      ],
      child: MaterialApp(
        theme: productionTheme ? buildPicoRadarTheme() : null,
        home: moduleId == 'impuestos'
            ? ProviderScope(
                overrides: [
                  taxCatalogProvider.overrideWith(
                    (ref) async => taxCatalogLoader == null
                        ? _taxFixtureCatalog()
                        : await taxCatalogLoader(),
                  ),
                  taxCatalogRefreshProvider.overrideWithValue(
                    (force) async => false,
                  ),
                ],
                child: VehicleStatusScreen(
                  moduleId: moduleId,
                  vehicleId: vehicleId,
                ),
              )
            : VehicleStatusScreen(moduleId: moduleId, vehicleId: vehicleId),
      ),
    ),
    wrap: wrap,
  );
  if (unlockWallet) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VehicleStatusScreen)),
    );
    await container.read(walletSessionProvider).unlock();
  }
  await _pumpNavigation(tester);
}

WalletDocument _walletDocument(PrivateVehicleDocumentMetadata metadata) =>
    WalletDocument(
      id: metadata.documentId,
      owner: WalletOwner.vehicle(metadata.vehicleId),
      type: WalletDocumentType.fromValue(metadata.documentType.value),
      importedAt: metadata.importedAt,
      pdf: WalletFileRef(
        encryptedRelativePath: metadata.encryptedRelativePath,
        originalName: metadata.originalName,
        mimeType: metadata.mimeType,
      ),
    );

Future<void> _finishWalletIo(
  WidgetTester tester, {
  bool Function()? until,
}) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(VehicleStatusScreen)),
  );
  await pumpUntilRealIo(
    tester,
    until ?? () => !container.read(walletOperationProvider).busy,
    reason: 'Wallet import/view/cleanup did not reach its required state',
  );
}

class _OwnerWalletPlatform extends WalletPlatform {
  final security = <bool>[];
  @override
  Future<void> setSecure(bool enabled) async => security.add(enabled);
  @override
  Future<WalletPdfDocument> openPdf(String path) async =>
      const WalletPdfDocument(id: 'owner-test', pageCount: 1);
  @override
  Future<Uint8List> renderPdfPage(String id, int page, int width) async =>
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
  @override
  Future<void> closePdf(String id) async {}
}

class _OwnerPreferences implements WalletSecurityPreferencesStore {
  _OwnerPreferences({this.protected = false});
  final bool protected;
  @override
  Future<WalletSecurityPreferences> read() async =>
      WalletSecurityPreferences(protectionEnabled: protected, offerSeen: true);
  @override
  Future<void> write(WalletSecurityPreferences preferences) async {}
}

class _OwnerAuthenticator implements WalletDeviceAuthenticator {
  _OwnerAuthenticator({this.allow = true});
  final bool allow;
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<WalletAuthenticationResult> authenticate() async => allow
      ? WalletAuthenticationResult.success
      : WalletAuthenticationResult.cancelled;
}

class _CapturingWalletStore implements WalletStore {
  _CapturingWalletStore(this.root);
  final Directory root;
  WalletDocument? saved;
  File? viewerFile;
  int decryptCalls = 0;
  int purgeAllCalls = 0;

  @override
  Future<List<WalletDocument>> listDocuments({WalletOwner? owner}) async => [
    if (saved != null && (owner == null || saved!.owner == owner)) saved!,
  ];

  @override
  Future<WalletDocument> saveDocument({
    required WalletOwner owner,
    required WalletDocumentType type,
    WalletDocumentInput? front,
    WalletDocumentInput? back,
    WalletDocumentInput? pdf,
    Map<String, String> metadata = const {},
    bool Function()? isAuthorized,
  }) async {
    if (!(isAuthorized?.call() ?? false)) {
      throw StateError('unauthorized test save');
    }
    saved = WalletDocument(
      id: 'saved',
      owner: owner,
      type: type,
      importedAt: DateTime.utc(2026, 9, 13),
      pdf: WalletFileRef(
        encryptedRelativePath: 'saved.prcf',
        originalName: pdf!.originalName,
        mimeType: pdf.mimeType,
      ),
    );
    return saved!;
  }

  @override
  Future<File> decryptForView(
    WalletDocument document,
    WalletDocumentSide side,
  ) async {
    decryptCalls++;
    final file = File('${root.path}/viewer-owned.pdf');
    await file.writeAsString('%PDF-1.7 fixture');
    viewerFile = file;
    return file;
  }

  @override
  Future<void> purgeViewerCache() async {
    purgeAllCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _chooseTaxAuthority(WidgetTester tester, String id) async {
  final chooser = find.byKey(const ValueKey('tax-authority-field'));
  await tester.ensureVisible(chooser);
  await tester.tap(chooser);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('tax-authority-search')),
    id,
  );
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('tax-authority-$id'));
  await tester.ensureVisible(tile);
  expect(tile.hitTestable(), findsOneWidget);
  await tester.tap(tile);
  await _pumpNavigation(tester);
}

Future<void> _saveTaxAuthority(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('tax-save-authority'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

const _taxBogotaPortal =
    'https://www.haciendabogota.gov.co/es/impuestos/impuesto-sobre-vehiculos-automotores';

TaxCatalog _taxFixtureCatalog() => TaxCatalog.fromJson({
  'schemaVersion': 1,
  'datasetKey': 'tax_calendars',
  'version': 'fixture-1',
  'generatedAt': '2026-09-03T00:00:00Z',
  'authorities': [
    for (final authority in [
      (
        'bogota',
        '11',
        'Bogotá D. C.',
        'Secretaría Distrital de Hacienda',
        _taxBogotaPortal,
      ),
      (
        'antioquia',
        '05',
        'Antioquia',
        'Gobernación de Antioquia',
        'https://www.antioquia.gov.co/',
      ),
    ])
      {
        'id': authority.$1,
        'territoryCode': authority.$2,
        'territoryName': authority.$3,
        'name': authority.$4,
        'institutionalUrl': authority.$5,
        'portalUrl': authority.$5,
        'sourceUrls': [authority.$5],
        'reviewedAt': '2026-09-03T00:00:00Z',
      },
  ],
  'calendars': [
    for (final id in ['bogota', 'antioquia'])
      {
        'id': '$id-2026',
        'authorityId': id,
        'year': 2026,
        'obligationKind': 'vehicle_tax',
        'status': 'verified',
        'reviewedAt': '2026-09-03T00:00:00Z',
        'reviewAfter': '2027-01-01T00:00:00Z',
        'sourceUrls': [_taxBogotaPortal],
        'events': [
          for (final event in [
            ('discount', '2026-05-15', 'Pronto pago 10%', 'discount'),
            ('ordinary', '2026-07-24', 'Fecha límite ordinaria', 'ordinary'),
            ('installment', '2026-09-04', 'SPAC: cuota 2', 'installment'),
          ])
            {
              'id': '$id-${event.$1}',
              'date': event.$2,
              'label': event.$3,
              'kind': event.$4,
              'condition': event.$1 == 'installment'
                  ? 'Si se acogió al pago por cuotas'
                  : null,
              'status': 'active',
              'sourceUrls': [_taxBogotaPortal],
            },
        ],
      },
  ],
});

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

class _RetryTaxObligationStore extends VehicleObligationStore {
  _RetryTaxObligationStore(super.database);

  int attempts = 0;

  @override
  Future<VehicleObligation> upsert({
    required String vehicleId,
    required VehicleObligationType type,
    DateTime? startDate,
    DateTime? dueDate,
    Map<String, String> details = const {},
    bool reminderEnabled = true,
  }) async {
    if (++attempts == 1) throw StateError('fixture save failure');
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
  _CapturingDocumentGateway({
    required this.openResult,
    this.pickedDocument,
    this.deletePickedFileOnClear = false,
  });

  final bool openResult;
  final PickedVehicleDocument? pickedDocument;
  final bool deletePickedFileOnClear;
  final openedFiles = <File>[];
  int clearTemporaryFileCalls = 0;

  @override
  Future<void> clearTemporaryFiles() async {
    clearTemporaryFileCalls += 1;
    final file = pickedDocument?.file;
    if (deletePickedFileOnClear && file != null && await file.exists()) {
      await file.delete();
    }
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
  _CapturingDocumentStore();

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
