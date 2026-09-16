import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/presentation/documents_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';

import '../../../test_app_harness.dart';
import '../../../plate_test_fonts.dart';

void main() {
  setUpAll(loadPlateTestFonts);
  late TestAppHarness harness;

  setUp(() => harness = TestAppHarness());
  tearDown(() => harness.dispose());

  Future<WalletDocument> save(
    WalletOwner owner,
    WalletDocumentType type,
  ) async {
    final file = File('${harness.documentRoot.path}/source.png');
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      ),
    );
    return harness.walletStore.saveDocument(
      owner: owner,
      type: type,
      front: WalletDocumentInput(
        source: file,
        originalName: 'source.png',
        mimeType: 'image/png',
      ),
    );
  }

  Future<void> seedVehicles() async {
    for (final vehicle in _vehicles) {
      await harness.database
          .into(harness.database.vehicles)
          .insert(
            VehiclesCompanion.insert(id: vehicle.id, plate: vehicle.plate),
          );
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    String? incoming,
    bool withVehicles = false,
  }) async {
    await harness.pump(
      tester,
      vehicleListOverride: withVehicles ? _vehicles : [],
      activeVehicleOverride: withVehicles ? _vehicles.first : null,
      childOverride: MaterialApp(
        theme: buildPicoRadarTheme(),
        home: DocumentsScreen(incoming),
      ),
    );
    await _until(
      tester,
      find.byKey(const ValueKey('documents-personal-identityCard')),
    );
  }

  Future<void> openVehicle(WidgetTester tester, String id) async {
    final tab = find.byKey(const ValueKey('documents-tab-1'));
    if (tab.evaluate().isNotEmpty) {
      await tester.tap(tab);
      await tester.pumpAndSettle();
    }
    final open = find.byKey(ValueKey('documents-vehicle-open-$id'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _until(tester, find.byKey(const ValueKey('documents-row-other')));
  }

  testWidgets('saved personal copy is available without creating a vehicle', (
    tester,
  ) async {
    await tester.runAsync(
      () => save(
        const WalletOwner.driver('principal'),
        WalletDocumentType.identityCard,
      ),
    );
    await pump(tester);

    expect(
      find.byKey(
        const ValueKey('documents-personal-open-identityCard-principal'),
      ),
      findsOneWidget,
    );
    expect(find.text('Solo frente'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('documents-personal-add-driverLicense-principal'),
      ),
      findsOneWidget,
    );
    expect(find.text('Privacidad y copias'), findsOneWidget);
    final vehicles = await tester.runAsync(
      () => harness.database.select(harness.database.vehicles).get(),
    );
    expect(vehicles, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both drivers show only their own document states', (
    tester,
  ) async {
    late WalletDriver second;
    await tester.runAsync(() async {
      second = await harness.walletStore.saveDriver(displayName: 'Ana');
      await save(
        const WalletOwner.driver('principal'),
        WalletDocumentType.identityCard,
      );
      await save(
        WalletOwner.driver(second.id),
        WalletDocumentType.driverLicense,
      );
    });
    await pump(tester);
    await _until(
      tester,
      find.byKey(
        ValueKey('documents-personal-open-driverLicense-${second.id}'),
      ),
    );
    expect(
      find.byKey(
        const ValueKey('documents-personal-open-identityCard-principal'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('documents-personal-add-driverLicense-principal'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('documents-personal-add-identityCard-${second.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('documents-personal-open-identityCard-${second.id}')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('documents-driver-selector')),
      findsNothing,
    );
  });

  testWidgets(
    'Principal reset requires confirmation and preserves other owners',
    (tester) async {
      late WalletDriver second;
      final preservedIds = <String>[];
      const principal = WalletOwner.driver('principal');
      await tester.runAsync(() async {
        await seedVehicles();
        await harness.walletStore.saveDriver(
          id: 'principal',
          displayName: 'Nombre anterior',
        );
        second = await harness.walletStore.saveDriver(displayName: 'Ana');
        await save(principal, WalletDocumentType.identityCard);
        await save(principal, WalletDocumentType.driverLicense);
        preservedIds.add(
          (await save(
            WalletOwner.driver(second.id),
            WalletDocumentType.identityCard,
          )).id,
        );
        preservedIds.add(
          (await save(
            const WalletOwner.vehicle('first'),
            WalletDocumentType.soat,
          )).id,
        );
      });
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('documents-manage-drivers')));
      await _until(
        tester,
        find.byKey(const ValueKey('documents-driver-delete-principal')),
      );

      Future<void> openReset() async {
        await tester.tap(
          find.byKey(const ValueKey('documents-driver-delete-principal')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Eliminar copias del conductor'), findsOneWidget);
        expect(find.text('Eliminar conductor'), findsNothing);
        expect(
          find.textContaining(
            'El perfil se conserva y vuelve a llamarse Principal',
          ),
          findsOneWidget,
        );
      }

      await openReset();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(
          await harness.walletStore.listDocuments(owner: principal),
          hasLength(2),
        );
        final drivers = await harness.walletStore.listDrivers();
        expect(
          drivers.singleWhere((driver) => driver.isPrincipal).displayName,
          'Nombre anterior',
        );
      });

      await openReset();
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-delete-confirm')),
      );
      await _until(tester, find.text('Principal'));
      await tester.tap(find.byTooltip('Cerrar conductores'));
      await _until(
        tester,
        find.byKey(
          const ValueKey('documents-personal-add-identityCard-principal'),
        ),
      );
      expect(
        find.byKey(
          const ValueKey('documents-personal-add-driverLicense-principal'),
        ),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        final drivers = await harness.walletStore.listDrivers();
        expect(drivers, hasLength(2));
        final reset = drivers.singleWhere((driver) => driver.isPrincipal);
        expect(reset.id, 'principal');
        expect(reset.displayName, 'Principal');
        expect(
          drivers.singleWhere((driver) => driver.id == second.id).displayName,
          'Ana',
        );
        expect(
          await harness.walletStore.listDocuments(owner: principal),
          isEmpty,
        );
        final documents = await harness.walletStore.listDocuments();
        expect(
          documents.map((document) => document.id),
          unorderedEquals(preservedIds),
        );
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vehicle sheet never reuses another vehicles saved copy', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedVehicles();
      await save(const WalletOwner.vehicle('first'), WalletDocumentType.soat);
    });
    await pump(tester, incoming: 'first', withVehicles: true);
    await openVehicle(tester, 'first');
    expect(
      find.byKey(const ValueKey('documents-vehicle-open-soat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('documents-vehicle-menu-soat')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Cerrar documentos del vehículo'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await openVehicle(tester, 'second');
    expect(
      find.byKey(const ValueKey('documents-vehicle-add-soat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('documents-vehicle-open-soat')),
      findsNothing,
    );
  });

  testWidgets('cancel then confirm deletes only the selected owners copy', (
    tester,
  ) async {
    late WalletDocument selected;
    await tester.runAsync(() async {
      await seedVehicles();
      selected = await save(
        const WalletOwner.vehicle('first'),
        WalletDocumentType.soat,
      );
      await save(const WalletOwner.vehicle('second'), WalletDocumentType.soat);
      await save(
        const WalletOwner.driver('principal'),
        WalletDocumentType.identityCard,
      );
    });
    await pump(tester, incoming: 'first', withVehicles: true);
    await openVehicle(tester, 'first');

    Future<void> deleteMenu() async {
      await tester.tap(
        find.byKey(const ValueKey('documents-vehicle-menu-soat')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar copia'));
      await tester.pumpAndSettle();
    }

    await deleteMenu();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('documents-vehicle-open-soat')),
      findsOneWidget,
    );
    await deleteMenu();
    await tester.tap(find.text('Eliminar'));
    await _until(
      tester,
      find.byKey(const ValueKey('documents-vehicle-add-soat')),
    );
    final remaining = await tester.runAsync(
      () => harness.walletStore.listDocuments(),
    );
    expect(
      remaining!.map((document) => document.id),
      isNot(contains(selected.id)),
    );
    expect(
      remaining.map((document) => document.owner),
      containsAll([
        const WalletOwner.vehicle('second'),
        const WalletOwner.driver('principal'),
      ]),
    );
    expect(remaining, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed document read offers retry without claiming no copies', (
    tester,
  ) async {
    var failRead = true;
    const owner = WalletOwner.driver('principal');
    await tester.runAsync(
      () => save(
        const WalletOwner.driver('principal'),
        WalletDocumentType.identityCard,
      ),
    );
    await harness.pump(
      tester,
      vehicleListOverride: [],
      childOverride: ProviderScope(
        overrides: [
          walletDocumentsProvider(owner).overrideWith((ref) async {
            if (failRead) throw StateError('Private read failed');
            return harness.walletStore.listDocuments(owner: owner);
          }),
        ],
        child: MaterialApp(
          theme: buildPicoRadarTheme(),
          home: const DocumentsScreen(null),
        ),
      ),
    );
    await _until(
      tester,
      find.byKey(
        const ValueKey('documents-personal-error-identityCard-principal'),
      ),
    );
    expect(
      find.byKey(
        const ValueKey('documents-personal-add-identityCard-principal'),
      ),
      findsNothing,
    );
    failRead = false;
    await tester.tap(
      find.byKey(
        const ValueKey('documents-personal-error-identityCard-principal'),
      ),
    );
    await _until(
      tester,
      find.byKey(
        const ValueKey('documents-personal-open-identityCard-principal'),
      ),
    );
    expect(find.text('Solo frente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _until(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 100 && target.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(target, findsWidgets);
  await tester.pump(const Duration(milliseconds: 300));
}

final _vehicles = [
  for (final (id, plate) in [('first', 'AAA123'), ('second', 'BBB234')])
    VehicleProfile(
      id: id,
      plate: plate,
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
    ),
];
