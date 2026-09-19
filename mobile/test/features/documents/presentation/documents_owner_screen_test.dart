import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/app/shell/app_shell.dart' show AppTab;
import 'package:picoradar/core/design_system/navigation.dart';
import 'package:picoradar/features/documents/presentation/documents_screen.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/documents/presentation/documents_widgets.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';

import '../../../plate_test_fonts.dart';

void main() {
  setUpAll(loadPlateTestFonts);
  _additionalOwnerTests();

  for (final (pages, label) in [
    (null, 'PDF guardado'),
    ('1', 'PDF · 1 página'),
    ('4', 'PDF · 4 páginas'),
  ]) {
    testWidgets(
      'PDF status describes known pages without inferring document faces: $label',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final document = WalletDocument(
            id: 'pdf',
            owner: const WalletOwner.driver('principal'),
            type: WalletDocumentType.identityCard,
            importedAt: DateTime(2026, 9, 13),
            pdf: const WalletFileRef(
              encryptedRelativePath: 'private/pdf',
              originalName: 'copy.pdf',
              mimeType: 'application/pdf',
            ),
            metadata: {'pdfPageCount': ?pages},
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DocumentsPersonalCards(
                  drivers: const [_principal],
                  copies: {
                    'principal': AsyncValue.data([document]),
                  },
                  onOpen: (_, _, _) {},
                  onRetry: (_) {},
                ),
              ),
            ),
          );
          if (pages == null) {
            expect(find.text('PDF guardado'), findsOneWidget);
          } else {
            final row = _personalRow(
              WalletDocumentType.identityCard,
              'principal',
            );
            expect(
              find.descendant(of: row, matching: find.textContaining('PDF')),
              findsOneWidget,
            );
            final count = find.descendant(
              of: row,
              matching: find.textContaining(
                RegExp('\\b${RegExp.escape(pages)}\\s+p[áa]g'),
              ),
            );
            expect(count, findsOneWidget);
            expect(count.hitTestable(), findsOneWidget);
          }
          expect(
            find.bySemanticsLabel(
              RegExp(RegExp.escape('$label, Ver documento')),
            ),
            findsOneWidget,
          );
          expect(find.text('Solo frente'), findsNothing);
          expect(find.text('Solo reverso'), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final report in const [
    WalletMigrationReport(orphanedCount: 1),
    WalletMigrationReport(pendingCleanupCount: 1),
    WalletMigrationReport(migrationFailed: true),
    WalletMigrationReport(unreadableRecordCount: 1),
  ]) {
    testWidgets(
      'recovery warning remains visible for ${report.orphanedCount}/${report.pendingCleanupCount}/${report.migrationFailed}',
      (tester) async {
        final store = _UiWalletStore()..recoveryReport = report;
        await _pumpOwner(tester, store: store);
        expect(
          find.byKey(const ValueKey('documents-recovery-warning')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('documents-recovery-warning')),
        );
        await tester.pumpAndSettle();
        final retry = find.byKey(const ValueKey('documents-recovery-retry'));
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('documents-recovery-warning')),
          findsNothing,
        );
        Navigator.of(tester.element(find.text('Copias por recuperar'))).pop();
        await tester.pumpAndSettle();
        expect(
          _personalRow(WalletDocumentType.identityCard, 'principal'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('front-only identity is not presented as a complete copy', (
    tester,
  ) async {
    final identity = WalletDocument(
      id: 'identity',
      owner: const WalletOwner.driver('principal'),
      type: WalletDocumentType.identityCard,
      importedAt: DateTime(2026, 9, 13),
      front: const WalletFileRef(
        encryptedRelativePath: 'private/front',
        originalName: 'front.png',
        mimeType: 'image/png',
      ),
    );
    WalletDocument? opened;
    WalletDocumentType? added;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPicoRadarTheme(),
        home: Scaffold(
          body: DocumentsPersonalCards(
            drivers: const [_principal],
            copies: {
              'principal': AsyncValue.data([identity]),
            },
            onOpen: (driver, type, document) {
              expect(driver.id, 'principal');
              if (document == null) {
                added = type;
              } else {
                opened = document;
              }
            },
            onRetry: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Solo frente'), findsOneWidget);
    await tester.tap(
      _personalRow(WalletDocumentType.identityCard, 'principal'),
    );
    expect(opened, same(identity));
    await tester.tap(
      _personalRow(WalletDocumentType.driverLicense, 'principal'),
    );
    expect(added, WalletDocumentType.driverLicense);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'real shell, two long driver names and vehicle sheet stay bounded at $size / $scale',
        (tester) async {
          final store = _UiWalletStore()
            ..drivers[0] = _longPrincipal
            ..drivers.add(_second);
          await _pumpOwner(
            tester,
            size: size,
            scale: scale,
            store: store,
            vehicles: [_vehicle('first', 'AAA123')],
          );
          _expectWholeHeader(tester);
          _expectCompactPage(tester);
          _expectPersonalRows(tester, const [_longPrincipal, _second]);
          await tester.tap(
            find.byKey(const ValueKey('documents-manage-drivers')),
          );
          await tester.pumpAndSettle();
          expect(find.text(_longPrincipal.displayName), findsOneWidget);
          expect(find.text(_second.displayName), findsOneWidget);
          await tester.tap(
            find.byKey(const ValueKey('documents-driver-delete-principal')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Eliminar copias del conductor'), findsOneWidget);
          final confirm = find.byKey(
            const ValueKey('documents-driver-delete-confirm'),
          );
          expect(confirm.hitTestable(), findsOneWidget);
          expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Cerrar conductores'));
          await tester.pumpAndSettle();
          await _showVehicleTab(tester);
          _expectCompactPage(tester);
          final open = find.byKey(
            const ValueKey('documents-vehicle-open-first'),
          );
          _expectBounded(tester, open);
          expect(tester.getSize(open).height, greaterThanOrEqualTo(48));
          expect(open.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(open);
          await tester.pumpAndSettle();
          final last = find.byKey(
            const ValueKey('documents-vehicle-add-other'),
          );
          await tester.ensureVisible(last);
          await tester.pumpAndSettle();
          expect(last.hitTestable(), findsOneWidget);
          expect(tester.getSize(last).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final driverCount in [1, 2]) {
    for (final size in const [Size(360, 780), Size(430, 932)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'real shell preview renders $driverCount drivers and real assets at $size / $scale',
          (tester) async {
            final store = _UiWalletStore()..drivers[0] = _longPrincipal;
            if (driverCount == 2) store.drivers.add(_second);
            for (final driver in store.drivers) {
              for (final type in [
                WalletDocumentType.identityCard,
                WalletDocumentType.driverLicense,
              ]) {
                const front = WalletFileRef(
                  encryptedRelativePath: 'private/front',
                  originalName: 'front.png',
                  mimeType: 'image/png',
                );
                store.documents.add(
                  WalletDocument(
                    id: '${driver.id}-${type.name}',
                    owner: WalletOwner.driver(driver.id),
                    type: type,
                    importedAt: DateTime(2026, 9, 13),
                    front: front,
                    back: front,
                  ),
                );
              }
            }
            await _pumpOwner(
              tester,
              size: size,
              scale: scale,
              store: store,
              vehicles: [
                _vehicle('first', 'AAA123'),
                _vehicle('second', 'BBB234'),
              ],
            );
            _expectWholeHeader(tester);
            _expectCompactPage(tester);
            expect(find.byType(AppBottomNav), findsOneWidget);
            _expectPersonalRows(tester, store.drivers);
            final initialArtwork = find.byKey(
              const ValueKey('vehicle-visual-image-first'),
              skipOffstage: false,
            );
            final initialImage = tester.widget<Image>(initialArtwork);
            await tester.runAsync(
              () => precacheImage(
                initialImage.image,
                tester.element(initialArtwork),
              ),
            );
            await tester.pumpAndSettle();
            final directory =
                Platform.environment['PICORADAR_DOCUMENTS_COMPACT_QA_DIR'];
            Future<void> capture(String name, {Rect? artworkRect}) async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('owner-preview')),
              );
              await tester.runAsync(() async {
                final snapshot = await boundary.toImage(pixelRatio: 1);
                if (artworkRect != null) {
                  final pixels = await snapshot.toByteData(
                    format: ui.ImageByteFormat.rawRgba,
                  );
                  var darkPixels = 0;
                  for (
                    var y = artworkRect.top.ceil();
                    y < artworkRect.bottom.floor();
                    y++
                  ) {
                    for (
                      var x = artworkRect.left.ceil();
                      x < artworkRect.right.floor();
                      x++
                    ) {
                      final offset = (y * snapshot.width + x) * 4;
                      if (pixels!.getUint8(offset) < 180 &&
                          pixels.getUint8(offset + 1) < 180 &&
                          pixels.getUint8(offset + 2) < 180) {
                        darkPixels++;
                      }
                    }
                  }
                  expect(
                    darkPixels,
                    greaterThan(500),
                    reason: 'The real vehicle must paint pixels inside its contained image area.',
                  );
                }
                if (directory != null) {
                  await Directory(directory).create(recursive: true);
                  final bytes = await snapshot.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final dimensions =
                      '${size.width.toInt()}x${size.height.toInt()}';
                  await File(
                    '$directory/$name-drivers$driverCount-$dimensions-text${scale.toInt()}.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                }
                snapshot.dispose();
              });
            }

            await capture('documents-overview');
            await _showVehicleTab(tester);
            final artwork = find.byKey(
              const ValueKey('vehicle-visual-image-first'),
            );
            expect(artwork, findsOneWidget);
            final image = tester.widget<Image>(artwork);
            expect(image.fit, BoxFit.contain);
            await tester.runAsync(
              () => precacheImage(image.image, tester.element(artwork)),
            );
            await tester.pumpAndSettle();
            _expectBounded(tester, artwork, interactive: false);
            final rectangle = tester.getRect(artwork);
            expect(rectangle.height, greaterThan(100));
            await capture('documents-vehicle', artworkRect: rectangle);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('personal cards reflow without clipping at $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildPicoRadarTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DocumentsPersonalCards(
                  drivers: const [_principal],
                  copies: const {'principal': AsyncValue.data([])},
                  onOpen: (_, _, _) {},
                  onRetry: (_) {},
                ),
              ),
            ),
          ),
        );
        final identity = find.byKey(
          const ValueKey('documents-personal-identityCard'),
        );
        final license = find.byKey(
          const ValueKey('documents-personal-driverLicense'),
        );
        if (tester.getTopLeft(identity).dy == tester.getTopLeft(license).dy) {
          expect(tester.getTopLeft(identity).dy, tester.getTopLeft(license).dy);
          expect(tester.getSize(identity), tester.getSize(license));
        } else {
          expect(
            tester.getTopLeft(license).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(identity).dy + 8),
          );
        }
        final add = _personalRow(WalletDocumentType.driverLicense, 'principal');
        expect(find.byType(Scrollable), findsNothing);
        expect(add.hitTestable(), findsOneWidget);
        expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('carousel preserves incoming focus while browsing locally', (
    tester,
  ) async {
    final vehicles = [
      _vehicle('first', 'AAA123'),
      _vehicle('second', 'BBB234'),
    ];
    VehicleProfile? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehicleVisualCatalogProvider.overrideWithValue(
            AsyncValue.data(_catalog),
          ),
          vehicleVisualOverrideProvider.overrideWith((ref, id) async => null),
        ],
        child: MaterialApp(
          theme: buildPicoRadarTheme(),
          home: Scaffold(
            body: DocumentsVehicleCarousel(
              vehicles: vehicles,
              initialVehicleId: 'second',
              onOpen: (vehicle) => opened = vehicle,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 de 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('documents-vehicle-open-second')),
    );
    expect(opened?.id, 'second');
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 de 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('documents-vehicle-open-first')),
    );
    expect(opened?.id, 'first');
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal documents remain usable without a vehicle', (
    tester,
  ) async {
    await _pumpOwner(tester);

    expect(
      find.textContaining(RegExp(r'Cédula de\s+ciudadanía')),
      findsOneWidget,
    );
    expect(find.text('Licencia de conducción'), findsOneWidget);
    expect(
      _personalRow(WalletDocumentType.identityCard, 'principal'),
      findsOneWidget,
    );
    expect(
      _personalRow(WalletDocumentType.driverLicense, 'principal'),
      findsOneWidget,
    );
  });

  testWidgets('no private providers load before authorization or after lock', (
    tester,
  ) async {
    final preferences = _SecurityPreferences();
    preferences.pending = Completer<WalletSecurityPreferences>();
    final session = WalletSession(
      authenticator: _Authenticator(),
      preferences: preferences,
    );
    final store = _UiWalletStore();
    await _pumpOwner(tester, session: session, store: store, settle: false);
    expect(store.driverReads, 0);
    expect(store.documentReads, isEmpty);
    expect(
      find.textContaining(RegExp(r'Cédula de\s+ciudadanía')),
      findsNothing,
    );
    preferences.pending!.complete(
      const WalletSecurityPreferences(offerSeen: true),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp(r'Cédula de\s+ciudadanía')),
      findsOneWidget,
    );
    expect(store.driverReads, 1);
    expect(store.documentReads, {'principal': 1});
    session.lock();
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp(r'Cédula de\s+ciudadanía')),
      findsNothing,
    );
    expect(find.text('Principal'), findsNothing);
    expect(store.driverReads, 1);
    expect(store.documentReads, {'principal': 1});
  });

  testWidgets(
    'incoming vehicle wins over favorite and sheet lists seven vehicle types',
    (tester) async {
      final vehicles = [
        _vehicle('first', 'AAA123'),
        _vehicle('second', 'BBB234'),
      ];
      await _pumpOwner(
        tester,
        vehicles: vehicles,
        incoming: 'second',
        favorite: vehicles.first,
      );
      await _showVehicleTab(tester);
      expect(find.text('2 de 2'), findsOneWidget);
      final open = find.byKey(const ValueKey('documents-vehicle-open-second'));
      _expectBounded(tester, open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('BBB234'), findsOneWidget);
      for (final name in [
        'trafficLicense',
        'soat',
        'rtm',
        'voluntaryInsurance',
        'salePurchase',
        'appraisal',
        'other',
      ]) {
        expect(
          find.byKey(ValueKey('documents-vehicle-add-$name')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('documents-vehicle-add-identityCard')),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Cerrar documentos del vehículo'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-unlock')), findsNothing);
    },
  );

  testWidgets(
    'unknown incoming vehicle fails closed without favorite fallback',
    (tester) async {
      final vehicles = [
        _vehicle('first', 'AAA123'),
        _vehicle('second', 'BBB234'),
      ];
      await _pumpOwner(
        tester,
        vehicles: vehicles,
        incoming: 'missing',
        favorite: vehicles.last,
      );
      expect(find.text('No encontramos ese vehículo.'), findsOneWidget);
      expect(
        find.text('Elige un vehículo vigente para abrir sus documentos.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('documents-go-garage')), findsOneWidget);
      expect(find.text('2 de 2'), findsNothing);
      expect(find.byKey(const ValueKey('wallet-unlock')), findsNothing);
    },
  );

  testWidgets(
    'vehicle sheet masks owner on lock while preserving its action ref',
    (tester) async {
      final session = await _pumpOwner(
        tester,
        vehicles: [_vehicle('first', 'AAA123')],
      );
      await _showVehicleTab(tester);
      final open = find.byKey(const ValueKey('documents-vehicle-open-first'));
      _expectBounded(tester, open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('documents-vehicle-add-soat'));
      final element = tester.element(action);
      session.lock();
      await tester.pumpAndSettle();
      expect(find.text('AAA123'), findsNothing);
      expect(action, findsNothing);
      expect(element.mounted, isTrue);
      expect(find.text('Documentos bloqueados'), findsOneWidget);
      await session.unlock();
      await tester.pumpAndSettle();
      expect(action, findsOneWidget);
      expect(tester.element(action), same(element));
    },
  );

  for (final confirmStage in [false, true]) {
    testWidgets(
      'management masks and rejects stale ${confirmStage ? 'driver reset' : 'copy menu'} consent',
      (tester) async {
        final store = _UiWalletStore()
          ..documents.add(_copy('principal', WalletDocumentType.identityCard));
        final session = await _pumpOwner(tester, store: store);
        await tester.tap(
          find.byKey(const ValueKey('documents-manage-drivers')),
        );
        await tester.pumpAndSettle();
        if (confirmStage) {
          await tester.tap(
            find.byKey(const ValueKey('documents-driver-delete-principal')),
          );
          await tester.pumpAndSettle();
        } else {
          await tester.tap(
            find.byKey(const ValueKey('documents-driver-manage-principal')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(
              const ValueKey('documents-driver-principal-menu-identityCard'),
            ),
          );
          await tester.pumpAndSettle();
        }
        final content = find.text(
          confirmStage ? 'Eliminar copias del conductor' : 'Eliminar copia',
        );
        final element = tester.element(content);
        session.lock();
        await tester.pumpAndSettle();
        expect(content, findsNothing);
        expect(find.text('Principal'), findsNothing);
        expect(element.mounted, isTrue);
        await session.unlock();
        await tester.pumpAndSettle();
        expect(tester.element(content), same(element));
        if (confirmStage) {
          await tester.tap(
            find.byKey(const ValueKey('documents-driver-delete-confirm')),
          );
        } else {
          await tester.tap(content);
        }
        await tester.pumpAndSettle();
        expect(store.deleteCalls, 0);
        expect(store.documentDeleteCalls, 0);
        expect(store.documents, hasLength(1));
        expect(store.drivers.single.isPrincipal, isTrue);
        expect(content, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'second driver can be added renamed and deleted without removing Principal',
    (tester) async {
      final store = _UiWalletStore();
      await _pumpOwner(tester, store: store);
      Future<void> management() async {
        await tester.tap(
          find.byKey(const ValueKey('documents-manage-drivers')),
        );
        await tester.pumpAndSettle();
      }

      await management();
      await tester.tap(find.byKey(const ValueKey('documents-driver-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('documents-driver-name')),
        'María',
      );
      await tester.tap(find.byKey(const ValueKey('documents-driver-save')));
      await tester.pumpAndSettle();
      expect(find.text('María'), findsOneWidget);
      expect(find.text('Gestionar conductores'), findsOneWidget);
      expect(find.byKey(const ValueKey('documents-driver-add')), findsNothing);
      expect(
        find.byKey(const ValueKey('documents-driver-delete-principal')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-rename-second')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('documents-driver-name')),
        'Ana',
      );
      await tester.tap(find.byKey(const ValueKey('documents-driver-save')));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-delete-second')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('documents-driver-manage-second')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-delete-second')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Principal'), findsOneWidget);
      expect(find.text('Ana'), findsNothing);
      expect(store.drivers.single.id, 'principal');
      expect(store.drivers.single.isPrincipal, isTrue);
      expect(
        find.byKey(const ValueKey('documents-driver-add')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void _additionalOwnerTests() {
  for (final driverId in ['principal', 'second']) {
    testWidgets(
      'completed $driverId deletion refreshes exact owner providers after dismissing the pending management sheet',
      (tester) async {
        final completion = Completer<void>();
        final store = _UiWalletStore()
          ..drivers.add(_second)
          ..documents.addAll([
            _copy('principal', WalletDocumentType.identityCard),
            _copy('second', WalletDocumentType.identityCard),
          ])
          ..driverDeleteCompletion = completion;
        await _pumpOwner(tester, store: store);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DocumentsScreen)),
        );
        final ownerProvider = walletDocumentsProvider(
          WalletOwner.driver(driverId),
        );
        final subscription = container.listen(ownerProvider, (_, _) {});
        addTearDown(subscription.close);
        await tester.tap(
          find.byKey(const ValueKey('documents-manage-drivers')),
        );
        await tester.pumpAndSettle();
        final managementElement = tester.element(
          find.text('Gestionar conductores'),
        );
        final driversBefore = store.driverReads;
        final copiesBefore = Map<String, int>.of(store.documentReads);
        await tester.tap(
          find.byKey(ValueKey('documents-driver-delete-$driverId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('documents-driver-delete-confirm')),
        );
        await tester.pumpAndSettle();
        expect(store.deleteCalls, 1);
        expect(container.read(ownerProvider).asData!.value, hasLength(1));
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton &&
                      widget.tooltip == 'Cerrar conductores',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(managementElement.mounted, isFalse);
        expect(store.driverReads, driversBefore);
        expect(store.documentReads, copiesBefore);
        completion.complete();
        await tester.pumpAndSettle();
        expect(store.driverReads, driversBefore + 1);
        expect(store.documentReads, {
          ...copiesBefore,
          driverId: copiesBefore[driverId]! + 1,
        });
        expect(container.read(ownerProvider).asData!.value, isEmpty);
        final profiles = container.read(walletDriversProvider).asData!.value;
        expect(
          profiles.any((driver) => driver.id == 'second'),
          driverId == 'principal',
        );
        expect(
          profiles.singleWhere((driver) => driver.isPrincipal).displayName,
          'Principal',
        );
        expect(
          store.documents.single.owner.id,
          driverId == 'principal' ? 'second' : 'principal',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final rename in [false, true]) {
    testWidgets(
      'completed driver ${rename ? 'rename' : 'creation'} refreshes providers after dismissing the pending dialog and sheet',
      (tester) async {
        final completion = Completer<void>();
        final store = _UiWalletStore()..driverSaveCompletion = completion;
        await _pumpOwner(tester, store: store);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DocumentsScreen)),
        );
        await tester.tap(
          find.byKey(const ValueKey('documents-manage-drivers')),
        );
        await tester.pumpAndSettle();
        final managementElement = tester.element(
          find.text('Gestionar conductores'),
        );
        final driversBefore = store.driverReads;
        final copiesBefore = Map<String, int>.of(store.documentReads);
        await tester.tap(
          find.byKey(
            ValueKey(
              rename
                  ? 'documents-driver-rename-principal'
                  : 'documents-driver-add',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final nameField = find.byKey(const ValueKey('documents-driver-name'));
        final dialogElement = tester.element(nameField);
        await tester.enterText(nameField, 'Nombre actualizado');
        await tester.tap(find.byKey(const ValueKey('documents-driver-save')));
        await tester.pumpAndSettle();
        expect(store.saveCalls, 1);
        expect(
          container
              .read(walletDriversProvider)
              .asData!
              .value
              .single
              .displayName,
          'Principal',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(dialogElement.mounted, isFalse);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(managementElement.mounted, isFalse);
        expect(store.driverReads, driversBefore);
        expect(store.documentReads, copiesBefore);
        completion.complete();
        await tester.pumpAndSettle();
        expect(store.driverReads, driversBefore + 1);
        expect(
          store.documentReads,
          rename ? copiesBefore : {...copiesBefore, 'second': 1},
        );
        final saved = container
            .read(walletDriversProvider)
            .asData!
            .value
            .singleWhere(
              (driver) => driver.id == (rename ? 'principal' : 'second'),
            );
        expect(saved.displayName, 'Nombre actualizado');
        expect(saved.isPrincipal, rename);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending deletion completion after lock never reads private data until reauthorization',
    (tester) async {
      final completion = Completer<void>();
      final store = _UiWalletStore()
        ..documents.add(_copy('principal', WalletDocumentType.identityCard))
        ..driverDeleteCompletion = completion;
      final session = await _pumpOwner(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('documents-manage-drivers')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-delete-principal')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(store.deleteCalls, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final driversBefore = store.driverReads;
      final copiesBefore = Map<String, int>.of(store.documentReads);
      session.lock();
      await tester.pumpAndSettle();
      completion.complete();
      await tester.pumpAndSettle();
      expect(store.driverReads, driversBefore);
      expect(store.documentReads, copiesBefore);
      expect(
        find.byKey(
          const ValueKey('documents-personal-open-identityCard-principal'),
        ),
        findsNothing,
      );
      await session.unlock();
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('documents-personal-add-identityCard-principal'),
        ),
        findsOneWidget,
      );
      expect(store.documents, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'front-page action context and carousel survive lock, provider error and unlock',
    (tester) async {
      final store = _UiWalletStore()..drivers.add(_second);
      final session = await _pumpOwner(
        tester,
        store: store,
        size: const Size(430, 932),
        vehicles: [_vehicle('first', 'AAA123'), _vehicle('second', 'BBB234')],
      );
      await _showVehicleTab(tester);
      await tester.tap(find.byTooltip('Vehículo siguiente'));
      await tester.pumpAndSettle();
      final personalTab = find.byKey(const ValueKey('documents-tab-0'));
      if (personalTab.evaluate().isNotEmpty) {
        await tester.tap(personalTab);
        await tester.pumpAndSettle();
      }
      final cards = find.byType(DocumentsPersonalCards, skipOffstage: false);
      final cardsElement = tester.element(cards);
      final carousel = find.byKey(
        const ValueKey('documents-vehicle-carousel'),
        skipOffstage: false,
      );
      final controller = tester.widget<PageView>(carousel).controller!;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DocumentsScreen)),
      );
      final driversBefore = store.driverReads;
      final copiesBefore = Map<String, int>.of(store.documentReads);
      session.lock();
      await tester.pumpAndSettle();
      expect(container.read(walletDriversProvider).hasError, isTrue);
      expect(cardsElement.mounted, isTrue);
      expect(tester.element(cards), same(cardsElement));
      expect(find.byType(DocumentsPersonalCards), findsNothing);
      expect(
        find.byKey(const ValueKey('documents-compact-page')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('documents-manage-drivers')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('documents-vehicle-counter')),
        findsNothing,
      );
      expect(find.text(_second.displayName), findsNothing);
      expect(tester.widget<PageView>(carousel).controller, same(controller));
      expect(store.driverReads, driversBefore);
      expect(store.documentReads, copiesBefore);
      await session.unlock();
      await tester.pumpAndSettle();
      expect(tester.element(cards), same(cardsElement));
      expect(tester.widget<PageView>(carousel).controller, same(controller));
      expect(controller.page, closeTo(1, .001));
      final add = find.byKey(
        const ValueKey('documents-personal-add-identityCard-second'),
      );
      expect(add.hitTestable(), findsOneWidget);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Escanear'), findsOneWidget);
      expect(find.text('Importar archivo'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-width shell growth 360x780 to 800 and 932 enlarges artwork only and retains the page controller',
    (tester) async {
      await _pumpOwner(
        tester,
        size: const Size(360, 780),
        vehicles: [_vehicle('first', 'AAA123'), _vehicle('second', 'BBB234')],
      );
      expect(find.byKey(const ValueKey('documents-local-tabs')), findsNothing);
      await tester.tap(find.byTooltip('Vehículo siguiente'));
      await tester.pumpAndSettle();
      final carousel = find.byKey(const ValueKey('documents-vehicle-carousel'));
      final controller = tester.widget<PageView>(carousel).controller!;
      final position = controller.position;
      final artwork = find.byKey(const ValueKey('vehicle-visual-image-second'));
      final imageArea = find.byKey(
        const ValueKey('documents-vehicle-image-second'),
      );
      final open = find.byKey(const ValueKey('documents-vehicle-open-second'));
      final originalArtwork = tester.getRect(artwork);
      final originalArea = tester.getRect(imageArea);
      Map<String, Size> controlSizes() => {
        for (final key in [
          'documents-manage-drivers',
          'documents-protection',
          'documents-privacy',
          'documents-vehicle-open-second',
        ])
          key: tester.getRect(find.byKey(ValueKey(key))).size,
        for (final tooltip in [
          'Volver',
          'Vehículo anterior',
          'Vehículo siguiente',
        ])
          tooltip: tester.getRect(find.byTooltip(tooltip)).size,
      };
      final originalControls = controlSizes();
      for (final height in [800.0, 932.0]) {
        tester.view.physicalSize = Size(360, height);
        await tester.pumpAndSettle();
        final delta = height - 780;
        expect(
          find.byKey(const ValueKey('documents-local-tabs')),
          findsNothing,
        );
        expect(
          tester.getRect(imageArea).height - originalArea.height,
          closeTo(delta, .01),
        );
        expect(
          tester.getRect(artwork).height - originalArtwork.height,
          closeTo(delta, .01),
        );
        expect(tester.getRect(imageArea).width, originalArea.width);
        expect(tester.getRect(artwork).width, originalArtwork.width);
        expect(controlSizes(), originalControls);
        expect(tester.widget<PageView>(carousel).controller, same(controller));
        expect(controller.position, same(position));
        expect(controller.page, closeTo(1, .001));
        expect(find.text('2 de 2'), findsOneWidget);
        _expectBounded(tester, artwork, interactive: false);
        _expectBounded(tester, open);
        _expectCompactPage(tester);
      }
    },
  );

  testWidgets(
    'adding a driver changes combined layout to tabs without recreating the focused vehicle carousel',
    (tester) async {
      final store = _UiWalletStore();
      final vehicles = [
        _vehicle('first', 'AAA123'),
        _vehicle('second', 'BBB234'),
      ];
      await _pumpOwner(
        tester,
        size: const Size(360, 932),
        store: store,
        vehicles: vehicles,
      );
      expect(find.byKey(const ValueKey('documents-local-tabs')), findsNothing);
      final personal = find.byType(DocumentsPersonalCards);
      final vehicle = find.byType(DocumentsVehicleCarousel);
      final personalContext = tester.element(personal);
      final width = tester.getSize(personal).width;
      final oneDriverHeight = tester.getSize(personal).height;
      final twoDriverHeight = DocumentsPersonalCards.measureHeight(
        personalContext,
        width,
        2,
      );
      final vehicleMinimum = DocumentsVehicleCarousel.minimumHeight(
        personalContext,
        width,
        vehicles,
      );
      final availableHeight =
          tester.getRect(vehicle).bottom - tester.getRect(personal).top;
      // Place the real shell between the one- and two-driver fit thresholds.
      final targetHeight =
          932 -
          availableHeight +
          (oneDriverHeight + twoDriverHeight) / 2 +
          8 +
          vehicleMinimum;
      expect(twoDriverHeight, greaterThan(oneDriverHeight));
      tester.view.physicalSize = Size(360, targetHeight);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('documents-local-tabs')), findsNothing);
      await tester.tap(find.byTooltip('Vehículo siguiente'));
      await tester.pumpAndSettle();
      final carouselElement = tester.element(vehicle);
      final carouselKey = tester.widget<DocumentsVehicleCarousel>(vehicle).key;
      expect(carouselKey, isA<GlobalKey>());
      final pages = find.byKey(const ValueKey('documents-vehicle-carousel'));
      final controller = tester.widget<PageView>(pages).controller!;
      expect(controller.page, closeTo(1, .001));
      await tester.tap(find.byKey(const ValueKey('documents-manage-drivers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('documents-driver-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('documents-driver-name')),
        _second.displayName,
      );
      await tester.tap(find.byKey(const ValueKey('documents-driver-save')));
      await tester.pumpAndSettle();
      expect(store.drivers, hasLength(2));
      expect(find.text(_second.displayName), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar conductores'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('documents-tab-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('documents-tab-1')), findsOneWidget);
      await _showVehicleTab(tester);
      expect(
        tester.widget<DocumentsVehicleCarousel>(vehicle).key,
        same(carouselKey),
      );
      expect(tester.element(vehicle), same(carouselElement));
      expect(tester.widget<PageView>(pages).controller, same(controller));
      expect(controller.page, closeTo(1, .001));
      expect(find.text('2 de 2'), findsOneWidget);
      final open = find.byKey(const ValueKey('documents-vehicle-open-second'));
      _expectBounded(tester, open);
      _expectCompactPage(tester);
      await tester.tap(open);
      await tester.pumpAndSettle();
      final sheet = find.byKey(
        const ValueKey('documents-vehicle-sheet-scroll'),
      );
      expect(
        find.descendant(of: sheet, matching: find.text('BBB234')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('two owner rows open only their own copy or add for their own ID', (
    tester,
  ) async {
    final principalIdentity = _copy(
      'principal',
      WalletDocumentType.identityCard,
    );
    final secondIdentity = _copy('second', WalletDocumentType.identityCard);
    final calls = <(String, WalletDocumentType, WalletDocument?)>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPicoRadarTheme(),
        home: Scaffold(
          body: DocumentsPersonalCards(
            drivers: const [_second, _principal],
            copies: {
              'second': AsyncValue.data([secondIdentity]),
              'principal': AsyncValue.data([principalIdentity]),
            },
            onOpen: (driver, type, doc) => calls.add((driver.id, type, doc)),
            onRetry: (_) => fail('No failed owner should be retried.'),
          ),
        ),
      ),
    );
    for (final type in [
      WalletDocumentType.identityCard,
      WalletDocumentType.driverLicense,
    ]) {
      final principalRow = _personalRow(type, 'principal');
      final secondRow = _personalRow(type, 'second');
      expect(
        tester.getRect(principalRow).bottom,
        lessThanOrEqualTo(tester.getRect(secondRow).top),
      );
      await tester.tap(principalRow);
      await tester.tap(secondRow);
      for (final driver in const [_principal, _second]) {
        expect(
          find.byKey(
            ValueKey(
              'documents-personal-${type == WalletDocumentType.identityCard ? 'open' : 'add'}-${type.name}-${driver.id}',
            ),
          ),
          findsOneWidget,
        );
      }
    }
    expect(calls, [
      ('principal', WalletDocumentType.identityCard, principalIdentity),
      ('second', WalletDocumentType.identityCard, secondIdentity),
      ('principal', WalletDocumentType.driverLicense, null),
      ('second', WalletDocumentType.driverLicense, null),
    ]);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading owner cannot open a copy and error retries only that owner',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final retried = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DocumentsPersonalCards(
                drivers: const [_principal, _second],
                copies: {
                  'principal': const AsyncValue.loading(),
                  'second': AsyncValue.error(
                    StateError('Unavailable'),
                    StackTrace.empty,
                  ),
                },
                onOpen: (_, _, _) =>
                    fail('Loading or failed copies must not be opened.'),
                onRetry: (driver) => retried.add(driver.id),
              ),
            ),
          ),
        );
        for (final type in [
          WalletDocumentType.identityCard,
          WalletDocumentType.driverLicense,
        ]) {
          expect(
            tester
                .widget<InkWell>(
                  find.byKey(
                    ValueKey(
                      'documents-personal-loading-${type.name}-principal',
                    ),
                  ),
                )
                .onTap,
            isNull,
          );
          await tester.tap(_personalRow(type, 'second'));
        }
        expect(retried, ['second', 'second']);
        expect(find.text('Cargando'), findsNWidgets(2));
        expect(find.text('Error'), findsNWidgets(2));
        expect(
          find.bySemanticsLabel(RegExp('Error al cargar, Reintentar')),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'copy update preserves owner geometry, tab and vehicle focus without extra reads at text $scale',
      (tester) async {
        final store = _UiWalletStore()..drivers.add(_second);
        final reads = _ProviderReads();
        await _pumpOwner(
          tester,
          store: store,
          scale: scale,
          reads: reads,
          vehicles: [_vehicle('first', 'AAA123'), _vehicle('second', 'BBB234')],
        );
        await _showVehicleTab(tester);
        await tester.tap(find.byTooltip('Vehículo siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('2 de 2'), findsOneWidget);
        final personalTab = find.byKey(const ValueKey('documents-tab-0'));
        final split = personalTab.evaluate().isNotEmpty;
        if (split) {
          await tester.tap(personalTab);
          await tester.pumpAndSettle();
        }
        _expectPersonalRows(tester, store.drivers);
        Map<String, Rect> positions() => {
          for (final driver in store.drivers)
            for (final type in [
              WalletDocumentType.identityCard,
              WalletDocumentType.driverLicense,
            ])
              '${driver.id}-${type.name}': tester.getRect(
                _personalRow(type, driver.id),
              ),
        };
        final before = positions();
        final vehicleReads = reads.vehicles;
        final favoriteReads = reads.favorite;
        final assetReads = Map<String, int>.of(reads.assets);
        final ownerReads = store.driverReads;
        final copyReads = Map<String, int>.of(store.documentReads);
        final pending = Completer<List<WalletDocument>>();
        store.pendingCopies['principal'] = pending;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DocumentsScreen)),
        );
        container.invalidate(
          walletDocumentsProvider(const WalletOwner.driver('principal')),
        );
        await tester.pump();
        await tester.pump();
        expect(positions(), before);
        expect(find.text('Cargando'), findsNWidgets(2));
        final identity = _copy('principal', WalletDocumentType.identityCard);
        store.documents.add(identity);
        pending.complete([identity]);
        await tester.pumpAndSettle();
        store.pendingCopies.remove('principal');
        expect(positions(), before);
        expect(find.text('Solo frente'), findsOneWidget);
        expect(find.text('Sin copia'), findsNWidgets(3));
        expect(
          find.byKey(const ValueKey('documents-tab-0')).evaluate().isNotEmpty,
          split,
        );
        expect(store.driverReads, ownerReads);
        expect(store.documentReads, {
          ...copyReads,
          'principal': copyReads['principal']! + 1,
        });
        expect(reads.vehicles, vehicleReads);
        expect(reads.favorite, favoriteReads);
        expect(reads.assets, assetReads);
        _expectCompactPage(tester);
        await _showVehicleTab(tester);
        expect(find.text('2 de 2'), findsOneWidget);
        _expectBounded(
          tester,
          find.byKey(const ValueKey('documents-vehicle-open-second')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'renaming Principal preserves slot 1 and reset clears only its copies',
    (tester) async {
      final principalCopy = _copy('principal', WalletDocumentType.identityCard);
      final secondCopy = _copy('second', WalletDocumentType.identityCard);
      final vehicleCopy = WalletDocument(
        id: 'vehicle-soat',
        owner: const WalletOwner.vehicle('first'),
        type: WalletDocumentType.soat,
        importedAt: DateTime(2026, 9, 13),
        front: principalCopy.front,
      );
      final store = _UiWalletStore()
        ..drivers.add(_second)
        ..documents.addAll([principalCopy, secondCopy, vehicleCopy]);
      await _pumpOwner(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('documents-manage-drivers')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-rename-principal')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('documents-driver-name')),
        _longPrincipal.displayName,
      );
      await tester.tap(find.byKey(const ValueKey('documents-driver-save')));
      await tester.pumpAndSettle();
      final principal = store.drivers.singleWhere(
        (driver) => driver.id == 'principal',
      );
      expect(principal.isPrincipal, isTrue);
      expect(principal.displayName, _longPrincipal.displayName);
      final row = find.byKey(
        const ValueKey('documents-driver-manage-principal'),
      );
      expect(
        find.descendant(of: row, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text(_longPrincipal.displayName),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-delete-principal')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('El perfil se conserva'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('documents-driver-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        store.drivers.where((driver) => driver.isPrincipal).single.displayName,
        'Principal',
      );
      expect(store.drivers, hasLength(2));
      expect(store.documents, [secondCopy, vehicleCopy]);
      expect(find.text('Gestionar conductores'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final driver in const [_principal, _second]) {
    testWidgets(
      '${driver.id} document management retains its owner and action ref across lock',
      (tester) async {
        final store = _UiWalletStore()
          ..drivers.add(_second)
          ..documents.add(_copy(driver.id, WalletDocumentType.identityCard));
        final session = await _pumpOwner(tester, store: store);
        await tester.tap(
          find.byKey(const ValueKey('documents-manage-drivers')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('documents-driver-manage-${driver.id}')),
        );
        await tester.pumpAndSettle();
        final saved = find.byKey(
          ValueKey('documents-driver-${driver.id}-open-identityCard'),
        );
        final missing = find.byKey(
          ValueKey('documents-driver-${driver.id}-add-driverLicense'),
        );
        expect(saved.hitTestable(), findsOneWidget);
        expect(missing.hitTestable(), findsOneWidget);
        final sheet = find.byKey(
          ValueKey('documents-driver-sheet-${driver.id}'),
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Solo frente')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Sin copia')),
          findsOneWidget,
        );
        final surfaceElement = tester.element(
          find.ancestor(of: sheet, matching: find.byType(BottomSheet)).first,
        );
        final surface = find.byElementPredicate(
          (element) => identical(element, surfaceElement),
        );
        expect(
          find.text('${driver.isPrincipal ? 1 : 2}. ${driver.displayName}'),
          findsOneWidget,
        );
        final element = tester.element(saved);
        session.lock();
        await tester.pumpAndSettle();
        expect(saved, findsNothing);
        expect(find.textContaining(driver.displayName), findsNothing);
        expect(element.mounted, isTrue);
        expect(
          find.descendant(
            of: surface,
            matching: find.text('Documentos bloqueados'),
          ),
          findsOneWidget,
        );
        await session.unlock();
        await tester.pumpAndSettle();
        expect(tester.element(saved), same(element));
        expect(missing, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _principal = WalletDriver(
  id: 'principal',
  displayName: 'Principal',
  isPrincipal: true,
);
const _longPrincipal = WalletDriver(
  id: 'principal',
  displayName: 'Alejandro José Fernández Restrepo',
  isPrincipal: true,
);
const _second = WalletDriver(
  id: 'second',
  displayName: 'María Fernanda Rodríguez Sánchez',
  isPrincipal: false,
);

Finder _personalRow(WalletDocumentType type, String driverId) =>
    find.byKey(ValueKey('documents-personal-row-${type.name}-$driverId'));

Future<void> _showVehicleTab(WidgetTester tester) async {
  final tab = find.byKey(const ValueKey('documents-tab-1'));
  if (tab.evaluate().isNotEmpty) {
    _expectBounded(tester, tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }
}

Rect _usableArea(WidgetTester tester) {
  final shell = tester.getRect(find.byKey(const ValueKey('owner-shell-body')));
  final media = MediaQuery.of(tester.element(find.byType(DocumentsScreen)));
  return Rect.fromLTRB(
    shell.left + media.padding.left,
    shell.top + media.padding.top,
    shell.right - media.padding.right,
    shell.bottom - media.padding.bottom,
  );
}

void _expectBounded(
  WidgetTester tester,
  Finder finder, {
  bool interactive = true,
}) {
  expect(finder, findsOneWidget);
  final bounds = tester.getRect(finder);
  final usable = _usableArea(tester);
  expect(bounds.left, greaterThanOrEqualTo(usable.left - .01));
  expect(bounds.top, greaterThanOrEqualTo(usable.top - .01));
  expect(bounds.right, lessThanOrEqualTo(usable.right + .01));
  expect(bounds.bottom, lessThanOrEqualTo(usable.bottom + .01));
  if (interactive) {
    expect(bounds.width, greaterThanOrEqualTo(48));
    expect(bounds.height, greaterThanOrEqualTo(48));
    expect(finder.hitTestable(), findsOneWidget);
  }
}

void _expectCompactPage(WidgetTester tester) {
  final page = find.byKey(const ValueKey('documents-compact-page'));
  expect(page, findsOneWidget);
  for (final scrollable in tester.widgetList<Scrollable>(
    find.descendant(of: page, matching: find.byType(Scrollable)),
  )) {
    expect(
      axisDirectionToAxis(scrollable.axisDirection),
      Axis.horizontal,
      reason: 'The front page must not introduce vertical scrolling.',
    );
  }
  for (final key in [
    'documents-manage-drivers',
    'documents-protection',
    'documents-privacy',
  ]) {
    _expectBounded(tester, find.byKey(ValueKey(key)));
  }
  _expectBounded(tester, find.byTooltip('Volver'));
  for (final element
      in find
          .descendant(
            of: page,
            matching: find.byWidgetPredicate(
              (widget) => widget is IconButton || widget is ButtonStyleButton,
            ),
          )
          .evaluate()) {
    final control = find.byElementPredicate(
      (candidate) => identical(candidate, element),
    );
    // Adjacent carousel pages remain mounted outside the viewport.
    // The focused vehicle action is checked explicitly after selecting its tab.
    if (find
        .ancestor(of: control, matching: find.byType(PageView))
        .evaluate()
        .isNotEmpty) {
      continue;
    }
    final widget = element.widget;
    final enabled = widget is IconButton
        ? widget.onPressed != null
        : (widget as ButtonStyleButton).onPressed != null;
    _expectBounded(tester, control, interactive: enabled);
    expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
  }
  expect(find.text('Principal'), findsNothing);
  expect(find.byIcon(Icons.more_vert), findsNothing);
  final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
  expect(nav.destinations.map((item) => item.label).toList(), [
    'Inicio',
    'Garaje',
    'Apps',
    'Viaje',
    'Conducir',
  ]);
  expect(
    tester.getRect(page).bottom,
    lessThanOrEqualTo(tester.getRect(find.byType(AppBottomNav)).top),
  );
  expect(tester.takeException(), isNull);
}

void _expectPersonalRows(WidgetTester tester, List<WalletDriver> drivers) {
  final rectangles = <Rect>[];
  for (final type in [
    WalletDocumentType.identityCard,
    WalletDocumentType.driverLicense,
  ]) {
    final card = find.byKey(ValueKey('documents-personal-${type.name}'));
    _expectBounded(tester, card, interactive: false);
    for (final driver in drivers) {
      final row = _personalRow(type, driver.id);
      expect(find.descendant(of: card, matching: row), findsOneWidget);
      _expectBounded(tester, row);
      final bounds = tester.getRect(row);
      for (final previous in rectangles) {
        expect(
          bounds.overlaps(previous),
          isFalse,
          reason: 'Each document/driver pair must have a distinct hit target.',
        );
      }
      rectangles.add(bounds);
      expect(find.text(driver.displayName), findsNothing);
    }
  }
  expect(rectangles, hasLength(drivers.length * 2));
}

WalletDocument _copy(String driverId, WalletDocumentType type) =>
    WalletDocument(
      id: '$driverId-${type.name}',
      owner: WalletOwner.driver(driverId),
      type: type,
      importedAt: DateTime(2026, 9, 13),
      front: const WalletFileRef(
        encryptedRelativePath: 'private/front',
        originalName: 'front.png',
        mimeType: 'image/png',
      ),
    );

final _catalog = VehicleVisualCatalog.fromJson(
  jsonDecode(File(vehicleCatalogAssetPath).readAsStringSync())
      as Map<String, Object?>,
);

void _expectWholeHeader(WidgetTester tester) {
  final text = find.descendant(
    of: find.text('Documentos'),
    matching: find.byType(RichText),
  );
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final boxes = paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 10),
  );
  expect(
    boxes.map((box) => box.top).toSet(),
    hasLength(1),
    reason: 'Documentos must remain a whole readable word.',
  );
}

Future<WalletSession> _pumpOwner(
  WidgetTester tester, {
  List<VehicleProfile> vehicles = const [],
  String? incoming,
  VehicleProfile? favorite,
  WalletSession? session,
  _UiWalletStore? store,
  _ProviderReads? reads,
  bool settle = true,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  final errorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    // Retain layout origin and constraints in redirected test logs.
    if (details.library == 'rendering library') debugPrint(details.toString());
    errorHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = errorHandler);
  final walletSession =
      session ??
      WalletSession(
        authenticator: _Authenticator(),
        preferences: _SecurityPreferences(),
      );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    walletSession.dispose();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletStoreProvider.overrideWithValue(store ?? _UiWalletStore()),
        walletSessionProvider.overrideWithValue(walletSession),
        walletPlatformProvider.overrideWithValue(_Platform()),
        vehicleListProvider.overrideWith((ref) async {
          if (reads != null) reads.vehicles++;
          return vehicles;
        }),
        activeVehicleProvider.overrideWith((ref) async {
          if (reads != null) reads.favorite++;
          return favorite;
        }),
        vehicleVisualCatalogProvider.overrideWithValue(
          AsyncValue.data(_catalog),
        ),
        vehicleVisualOverrideProvider.overrideWith((ref, id) async {
          reads?.assets.update(id, (count) => count + 1, ifAbsent: () => 1);
          return null;
        }),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('owner-preview'),
          child: Scaffold(
            body: SizedBox.expand(
              key: const ValueKey('owner-shell-body'),
              child: DocumentsScreen(incoming),
            ),
            bottomNavigationBar: AppBottomNav(
              destinations: [
                for (final tab in AppTab.values)
                  AppBottomNavDestination(
                    label: tab.label,
                    icon: tab.icon,
                    selectedIcon: tab.selectedIcon,
                    color: tab.color,
                    keyName: tab.name,
                  ),
              ],
              currentIndex: AppTab.apps.index,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return walletSession;
}

class _ProviderReads {
  int vehicles = 0;
  int favorite = 0;
  final assets = <String, int>{};
}

class _UiWalletStore extends Fake implements WalletStore {
  final documents = <WalletDocument>[];
  WalletMigrationReport recoveryReport = const WalletMigrationReport();
  @override
  WalletMigrationReport get migrationReport => recoveryReport;
  @override
  Future<WalletMigrationReport> retryPendingCleanup() async =>
      recoveryReport = const WalletMigrationReport();
  final drivers = [
    const WalletDriver(
      id: 'principal',
      displayName: 'Principal',
      isPrincipal: true,
    ),
  ];
  int driverReads = 0;

  @override
  Future<WalletMigrationReport> initialize() async =>
      const WalletMigrationReport();
  @override
  Future<List<WalletDriver>> listDrivers() async {
    driverReads++;
    return List.of(drivers);
  }

  @override
  Future<List<WalletDocument>> listDocuments({WalletOwner? owner}) async {
    documentReads.update(
      owner?.id ?? 'all',
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    final pending = pendingCopies[owner?.id];
    if (pending != null) return pending.future;
    return documents
        .where((document) => owner == null || document.owner == owner)
        .toList();
  }

  final documentReads = <String, int>{};
  final pendingCopies = <String, Completer<List<WalletDocument>>>{};
  Completer<void>? driverSaveCompletion;
  Completer<void>? driverDeleteCompletion;
  int saveCalls = 0;
  @override
  Future<WalletDriver> saveDriver({
    String? id,
    required String displayName,
    bool Function()? isAuthorized,
  }) async {
    if (isAuthorized?.call() == false) throw StateError('Locked');
    saveCalls++;
    final driver = WalletDriver(
      id: id ?? 'second',
      displayName: displayName,
      isPrincipal: (id ?? 'second') == 'principal',
    );
    drivers.removeWhere((entry) => entry.id == driver.id);
    drivers.add(driver);
    // The durable write has committed; delay completion like cleanup or I/O.
    await driverSaveCompletion?.future;
    return driver;
  }

  @override
  Future<void> deleteDriver(String id, {bool Function()? isAuthorized}) async {
    if (isAuthorized?.call() == false) throw StateError('Locked');
    deleteCalls++;
    documents.removeWhere(
      (document) => document.owner == WalletOwner.driver(id),
    );
    drivers.removeWhere((driver) => driver.id == id);
    if (id == 'principal') drivers.insert(0, _principal);
    await driverDeleteCompletion?.future;
  }

  int deleteCalls = 0;
  int documentDeleteCalls = 0;
  @override
  Future<void> deleteDocument(
    String id, {
    bool Function()? isAuthorized,
  }) async {
    if (isAuthorized?.call() == false) throw StateError('Locked');
    documentDeleteCalls++;
    documents.removeWhere((entry) => entry.id == id);
  }
}

class _Authenticator implements WalletDeviceAuthenticator {
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<WalletAuthenticationResult> authenticate() async =>
      WalletAuthenticationResult.success;
}

class _SecurityPreferences implements WalletSecurityPreferencesStore {
  Completer<WalletSecurityPreferences>? pending;
  WalletSecurityPreferences value = const WalletSecurityPreferences(
    offerSeen: true,
  );
  @override
  Future<WalletSecurityPreferences> read() async =>
      pending == null ? value : await pending!.future;
  @override
  Future<void> write(WalletSecurityPreferences preferences) async =>
      value = preferences;
}

class _Platform extends WalletPlatform {
  @override
  Future<void> setSecure(bool enabled) async {}
}

VehicleProfile _vehicle(String id, String plate) => VehicleProfile(
  id: id,
  plate: plate,
  kind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  createdAt: DateTime(2026, 9, 13),
  updatedAt: DateTime(2026, 9, 13),
);
