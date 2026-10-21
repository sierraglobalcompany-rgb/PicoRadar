import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/app/theme/app_tokens.dart';
import 'package:picoradar/features/documents/data/wallet_models.dart';
import 'package:picoradar/features/documents/presentation/documents_widgets.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/presentation/vehicle_plate_badge.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';
import 'package:picoradar/features/visual_assets/presentation/visual_asset_widgets.dart';

import '../../../plate_test_fonts.dart';

const _principal = WalletDriver(
  id: 'principal',
  displayName: 'Nombre principal completo de prueba',
  isPrincipal: true,
);
const _other = WalletDriver(
  id: 'other',
  displayName: 'Nombre completo del segundo conductor',
  isPrincipal: false,
);
const _file = WalletFileRef(
  encryptedRelativePath: 'fixture.enc',
  originalName: 'fixture.png',
  mimeType: 'image/png',
);

WalletDocument _copy({
  WalletOwner owner = const WalletOwner.driver('principal'),
  WalletDocumentType type = WalletDocumentType.identityCard,
  WalletFileRef? front,
  WalletFileRef? back,
  WalletFileRef? pdf,
}) => WalletDocument(
  id: 'fixture-${type.name}',
  owner: owner,
  type: type,
  importedAt: DateTime(2026),
  front: front,
  back: back,
  pdf: pdf,
  metadata: const {'pdfPageCount': '2147483647'},
);

VehicleProfile _vehicle(
  String id, {
  String? nickname,
  String plate = 'ABC123',
}) => VehicleProfile(
  id: id,
  plate: plate,
  kind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  nickname: nickname,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(
  WidgetTester tester,
  WidgetBuilder builder, {
  double width = 328,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vehicleVisualCatalogProvider.overrideWith(
          (ref) async => const VehicleVisualCatalog(items: []),
        ),
        vehicleVisualOverrideProvider.overrideWith((ref, id) async => null),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectTextFits(WidgetTester tester, Finder root) {
  for (final element
      in find
          .descendant(of: root, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse);
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
      textHeightBehavior: paragraph.textHeightBehavior,
    )..layout(maxWidth: paragraph.size.width);
    expect(painter.height, lessThanOrEqualTo(paragraph.size.height + .01));
    painter.dispose();
  }
}

void main() {
  setUpAll(loadPlateTestFonts);

  for (final width in [288.0, 328.0, 358.0, 380.0, 398.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final count in [1, 2]) {
        testWidgets('personal measured bounds $width/$scale/$count', (
          tester,
        ) async {
          final drivers = [_principal, if (count == 2) _other];
          double? stableHeight;
          final states = <AsyncValue<List<WalletDocument>>>[
            const AsyncLoading(),
            AsyncError(StateError('fixture'), StackTrace.empty),
            const AsyncData([]),
            AsyncData([_copy(front: _file)]),
            AsyncData([_copy(back: _file)]),
            AsyncData([_copy(front: _file, back: _file)]),
            AsyncData([_copy(pdf: _file)]),
          ];
          for (final bounded in [false, true]) {
            for (final state in states) {
              late double measured;
              await _pump(
                tester,
                (context) {
                  measured = DocumentsPersonalCards.measureHeight(
                    context,
                    width,
                    count,
                  );
                  final cards = DocumentsPersonalCards(
                    drivers: drivers,
                    copies: {
                      for (final driver in drivers)
                        driver.id: state.whenData(
                          (documents) => [
                            for (final document in documents)
                              _copy(
                                owner: WalletOwner.driver(driver.id),
                                type: document.type,
                                front: document.front,
                                back: document.back,
                                pdf: document.pdf,
                              ),
                          ],
                        ),
                    },
                    onOpen: (_, _, _) {},
                    onRetry: (_) {},
                  );
                  return SizedBox(
                    height: bounded ? measured : null,
                    child: cards,
                  );
                },
                width: width,
                scale: scale,
              );
              stableHeight ??= measured;
              expect(measured, stableHeight);
              final root = find.byType(DocumentsPersonalCards);
              expect(tester.getSize(root).height, closeTo(measured, .01));
              for (final driver in drivers) {
                final row = find.byKey(
                  ValueKey('documents-personal-row-identityCard-${driver.id}'),
                );
                expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
              }
              _expectTextFits(tester, root);
              expect(tester.takeException(), isNull);
              if (width >= 328 && scale == 1) {
                expect(
                  measured,
                  inInclusiveRange(
                    count == 1 ? 120 : 168,
                    count == 1 ? 136 : 184,
                  ),
                );
              }
              if (width == 328 && scale == 2 && count == 2) {
                expect(measured, lessThanOrEqualTo(420));
              }
            }
          }
        });
      }
    }
  }

  testWidgets('360 dp phone reserves only actual rows at text scale two', (
    tester,
  ) async {
    late double oneDriver;
    late double twoDrivers;
    await _pump(tester, (context) {
      oneDriver = DocumentsPersonalCards.measureHeight(context, 328, 1);
      twoDrivers = DocumentsPersonalCards.measureHeight(context, 328, 2);
      return SizedBox(
        height: twoDrivers,
        child: DocumentsPersonalCards(
          drivers: const [_principal, _other],
          copies: {
            for (final driver in [_principal, _other])
              driver.id: AsyncData([
                _copy(
                  owner: WalletOwner.driver(driver.id),
                  type: WalletDocumentType.identityCard,
                  pdf: _file,
                ),
                _copy(
                  owner: WalletOwner.driver(driver.id),
                  type: WalletDocumentType.driverLicense,
                  pdf: _file,
                ),
              ]),
          },
          onOpen: (_, _, _) {},
          onRetry: (_) {},
        ),
      );
    }, scale: 2);
    final row = find.byKey(
      const ValueKey('documents-personal-row-identityCard-principal'),
    );
    final rowHeight = tester.getSize(row).height;
    debugPrint(
      'compact personal: one=$oneDriver two=$twoDrivers row=$rowHeight',
    );
    expect(rowHeight, greaterThanOrEqualTo(48));
    expect(twoDrivers - oneDriver, closeTo(rowHeight * 2, .01));
    expect(twoDrivers, lessThanOrEqualTo(420));
    expect(find.text('2147483647 pág.'), findsNWidgets(4));
    final identity = tester.getRect(
      find.byKey(const ValueKey('documents-personal-identityCard')),
    );
    final license = tester.getRect(
      find.byKey(const ValueKey('documents-personal-driverLicense')),
    );
    expect(license.top - identity.bottom, closeTo(8, .01));
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(DocumentsPersonalCards),
        matching: find.byType(Text),
      ),
    )) {
      expect(text.style!.fontSize, 14);
    }
    _expectTextFits(tester, find.byType(DocumentsPersonalCards));
    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicle accessible footer shares one band with the 96 dp plate', (
    tester,
  ) async {
    final vehicles = [_vehicle('a', nickname: 'Familiar')];
    late double minimum;
    VehicleProfile? opened;
    await _pump(tester, (context) {
      minimum = DocumentsVehicleCarousel.minimumHeight(context, 328, vehicles);
      return SizedBox(
        height: minimum,
        child: DocumentsVehicleCarousel(
          vehicles: vehicles,
          initialVehicleId: 'a',
          onOpen: (vehicle) => opened = vehicle,
        ),
      );
    }, scale: 2);
    final plate = tester.getRect(find.byType(VehiclePlateBadge));
    final action = find.byKey(const ValueKey('documents-vehicle-open-a'));
    final actionRect = tester.getRect(action);
    debugPrint(
      'compact vehicle: minimum=$minimum plate=${plate.size} heading=${tester.getSize(find.byKey(const ValueKey('documents-vehicle-heading')))} name=${tester.getSize(find.text('Familiar'))}',
    );
    expect(actionRect.size, const Size(48, 48));
    final footer = tester.getRect(
      find.byKey(const ValueKey('documents-vehicle-footer-a')),
    );
    expect(actionRect.top, greaterThanOrEqualTo(footer.top));
    expect(actionRect.bottom, lessThanOrEqualTo(footer.bottom));
    expect(plate.top, greaterThanOrEqualTo(footer.top));
    expect(plate.bottom, lessThanOrEqualTo(footer.bottom));
    expect(find.byTooltip('Ver documentos de Familiar'), findsOneWidget);
    expect(minimum, lessThanOrEqualTo(420));
    await tester.tap(action);
    expect(opened, same(vehicles.first));
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal two-driver cards and vehicle fit together within 490 dp', (
    tester,
  ) async {
    await _pump(tester, (context) {
      final vehicles = [_vehicle('a')];
      final personal = DocumentsPersonalCards.measureHeight(context, 328, 2);
      final vehicle = DocumentsVehicleCarousel.minimumHeight(
        context,
        328,
        vehicles,
      );
      final combined = personal + 8 + vehicle;
      debugPrint(
        'compact normal: personal=$personal vehicle=$vehicle combined=$combined',
      );
      expect(combined, lessThanOrEqualTo(490));
      return SizedBox(
        height: combined,
        child: Column(
          children: [
            DocumentsPersonalCards(
              drivers: const [_principal, _other],
              copies: const {
                'principal': AsyncData([]),
                'other': AsyncData([]),
              },
              onOpen: (_, _, _) {},
              onRetry: (_) {},
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: vehicle,
              child: DocumentsVehicleCarousel(
                vehicles: vehicles,
                initialVehicleId: 'a',
                onOpen: (_) {},
              ),
            ),
          ],
        ),
      );
    });
    expect(tester.takeException(), isNull);
  });

  for (final plate in ['AAA123', 'BOG127', 'ZVV73D']) {
    testWidgets(
      'standard 96 dp plate stays horizontal and adds scalable number: $plate',
      (tester) async {
        Size? standardSize;
        for (final scale in [1.0, 1.5, 2.0]) {
          final vehicles = [_vehicle('a', nickname: 'Familiar', plate: plate)];
          late double minimum;
          await _pump(tester, (context) {
            minimum = DocumentsVehicleCarousel.minimumHeight(
              context,
              328,
              vehicles,
            );
            return SizedBox(
              height: minimum,
              child: DocumentsVehicleCarousel(
                vehicles: vehicles,
                initialVehicleId: 'a',
                onOpen: (_) {},
              ),
            );
          }, scale: scale);
          final badge = find.byType(VehiclePlateBadge);
          final renderer = tester.widget<VehiclePlateBadge>(badge);
          expect(renderer.micro, isFalse);
          expect(renderer.compact, isTrue);
          expect(renderer.compactWidth, 96);
          final artwork = find.descendant(
            of: badge,
            matching: find.byKey(const ValueKey('colombian-plate-badge')),
          );
          final size = tester.getSize(artwork);
          standardSize ??= size;
          expect(size, standardSize);
          expect(size.width, 96);
          expect(size.height, lessThan(size.width));
          expect(MediaQuery.textScalerOf(tester.element(badge)).scale(20), 20);
          final first = find.descendant(
            of: badge,
            matching: find.byKey(const ValueKey('colombian-plate-first-group')),
          );
          final last = find.descendant(
            of: badge,
            matching: find.byKey(const ValueKey('colombian-plate-last-group')),
          );
          expect(
            tester.getCenter(first).dy,
            closeTo(tester.getCenter(last).dy, .01),
          );
          expect(tester.widget<Text>(first).style!.fontSize, 20);
          expect(tester.widget<Text>(last).style!.fontSize, 20);
          final emblem = find.descendant(
            of: badge,
            matching: find.byKey(const ValueKey('colombian-plate-separator')),
          );
          expect(tester.getSize(emblem), const Size(7, 7));
          for (final vertical in ['top', 'bottom']) {
            for (final horizontal in ['left', 'right']) {
              expect(
                find.descendant(
                  of: badge,
                  matching: find.byKey(
                    ValueKey('colombian-plate-fixing-$vertical-$horizontal'),
                  ),
                ),
                findsOneWidget,
              );
            }
          }
          expect(
            find.descendant(
              of: badge,
              matching: find.byKey(
                const ValueKey('colombian-plate-inner-border'),
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: badge, matching: find.byType(FittedBox)),
            findsNothing,
          );
          final readable = find.byKey(
            const ValueKey('documents-vehicle-readable-plate-a'),
          );
          if (scale == 1) {
            expect(readable, findsNothing);
          } else {
            expect(readable, findsOneWidget);
            final text = tester.widget<Text>(readable);
            expect(text.data, plate);
            expect(text.semanticsLabel, 'Placa $plate');
            expect(text.style!.fontSize, 14);
            expect(
              MediaQuery.textScalerOf(tester.element(readable)).scale(14),
              14 * scale,
            );
            expect(tester.getSize(readable).height, greaterThan(20));
          }
          expect(
            tester.getSize(find.byType(DocumentsVehicleCarousel)).height,
            closeTo(minimum, .01),
          );
          _expectTextFits(tester, find.byType(DocumentsVehicleCarousel));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('side-by-side identity heading uses its reserved two lines', (
    tester,
  ) async {
    await _pump(
      tester,
      (_) => DocumentsPersonalCards(
        drivers: const [_principal],
        copies: const {'principal': AsyncData([])},
        onOpen: (_, _, _) {},
        onRetry: (_) {},
      ),
    );
    expect(find.text('Cédula de\nciudadanía'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Cédula de\nciudadanía')).semanticsLabel,
      'Cédula de ciudadanía',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal rows ignore copies of another driver or a vehicle', (
    tester,
  ) async {
    final own = _copy(front: _file);
    final opened = <WalletDocument?>[];
    await _pump(
      tester,
      (_) => DocumentsPersonalCards(
        drivers: const [_principal],
        copies: {
          'principal': AsyncData([
            _copy(owner: const WalletOwner.driver('other'), pdf: _file),
            _copy(owner: const WalletOwner.vehicle('principal'), pdf: _file),
            _copy(
              owner: const WalletOwner.driver('other'),
              type: WalletDocumentType.driverLicense,
              pdf: _file,
            ),
            own,
          ]),
        },
        onOpen: (_, _, document) => opened.add(document),
        onRetry: (_) {},
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('documents-personal-open-identityCard-principal'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('documents-personal-add-driverLicense-principal'),
      ),
    );
    expect(opened, [own, null]);
    expect(find.text('PDF ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('known PDF count stays visible and license retains light teal', (
    tester,
  ) async {
    final pdf = _copy(type: WalletDocumentType.driverLicense, pdf: _file);
    await _pump(
      tester,
      (_) => DocumentsPersonalCards(
        drivers: const [_principal],
        copies: {
          'principal': AsyncData([pdf]),
        },
        onOpen: (_, _, _) {},
        onRetry: (_) {},
      ),
    );
    final card = find.byKey(const ValueKey('documents-personal-driverLicense'));
    final material = tester.widget<Material>(
      find.descendant(of: card, matching: find.byType(Material)),
    );
    expect(material.color, const Color(0xFFE8F5F3));
    final title = tester.widget<Text>(find.text('Licencia de conducción'));
    expect(title.style!.color, AppColors.navy);
    expect(find.text('2147483647 pág.'), findsOneWidget);
    expect(find.text('PDF ·'), findsOneWidget);
    expect(find.text('PDF guardado'), findsNothing);
    expect(
      find.byTooltip(
        'Conductor 1, ${_principal.displayName}, Licencia de conducción, PDF · 2147483647 páginas, Ver documento',
      ),
      findsOneWidget,
    );
    expect(walletDocumentStatus(pdf), 'PDF · 2147483647 páginas');
  });

  testWidgets(
    'driver identity, full semantics and callbacks remain local to each row',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final document = _copy(front: _file);
        final opened = <(WalletDriver, WalletDocumentType, WalletDocument?)>[];
        final retried = <WalletDriver>[];
        var failed = false;
        var loading = false;
        Future<void> pump() => _pump(
          tester,
          (_) => DocumentsPersonalCards(
            drivers: const [_other, _principal],
            copies: {
              'principal': AsyncData([document]),
              if (!loading)
                'other': failed
                    ? AsyncError(StateError('fixture'), StackTrace.empty)
                    : const AsyncData([]),
            },
            onOpen: (driver, type, document) =>
                opened.add((driver, type, document)),
            onRetry: retried.add,
          ),
        );
        await pump();
        final principal = find.byKey(
          const ValueKey('documents-personal-row-identityCard-principal'),
        );
        final other = find.byKey(
          const ValueKey('documents-personal-row-identityCard-other'),
        );
        expect(
          tester.getTopLeft(principal).dy,
          lessThan(tester.getTopLeft(other).dy),
        );
        final label =
            'Conductor 1, ${_principal.displayName}, Cédula de ciudadanía, Solo frente, Ver documento';
        expect(find.byTooltip(label), findsOneWidget);
        expect(find.bySemanticsLabel(label), findsOneWidget);
        await tester.tap(principal);
        await tester.tap(other);
        expect(opened, [
          (_principal, WalletDocumentType.identityCard, document),
          (_other, WalletDocumentType.identityCard, null),
        ]);
        failed = true;
        await pump();
        expect(find.text('Error'), findsNWidgets(2));
        await tester.tap(other);
        expect(retried, [_other]);
        loading = true;
        await pump();
        expect(find.text('Cargando'), findsNWidgets(2));
        expect(
          tester
              .widget<InkWell>(
                find.byKey(
                  const ValueKey(
                    'documents-personal-loading-identityCard-other',
                  ),
                ),
              )
              .onTap,
          isNull,
        );
        expect(find.byIcon(Icons.more_vert), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final width in [288.0, 328.0, 398.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('vehicle minimum and spare image bounds $width/$scale', (
        tester,
      ) async {
        final vehicles = [
          _vehicle(
            'a',
            nickname: 'Nombre largo completo del vehiculo familiar',
          ),
          _vehicle('b'),
        ];
        for (final extra in [0.0, 180.0]) {
          late double height;
          await _pump(
            tester,
            (context) {
              height =
                  DocumentsVehicleCarousel.minimumHeight(
                    context,
                    width,
                    vehicles,
                  ) +
                  extra;
              return SizedBox(
                height: height,
                child: DocumentsVehicleCarousel(
                  vehicles: vehicles,
                  initialVehicleId: 'a',
                  onOpen: (_) {},
                ),
              );
            },
            width: width,
            scale: scale,
          );
          expect(
            tester.getSize(find.byType(DocumentsVehicleCarousel)).height,
            closeTo(height, .01),
          );
          final image = find.byKey(const ValueKey('documents-vehicle-image-a'));
          expect(tester.getSize(image).height, closeTo(120 + extra, .01));
          expect(
            tester
                .getSize(
                  find.descendant(
                    of: image,
                    matching: find.byType(VehicleVisualImage),
                  ),
                )
                .height,
            closeTo(112 + extra, .01),
          );
          for (final badge in tester.widgetList<VehiclePlateBadge>(
            find.byType(VehiclePlateBadge),
          )) {
            expect(badge.compactWidth, 96);
          }
          for (final tooltip in ['Vehículo anterior', 'Vehículo siguiente']) {
            expect(tester.getSize(find.byTooltip(tooltip)), const Size(48, 48));
          }
          _expectTextFits(tester, find.byType(DocumentsVehicleCarousel));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
    'vehicle controller and focused id survive resize, reorder and empty list',
    (tester) async {
      final a = _vehicle('a');
      final b = _vehicle('b');
      var vehicles = [a, b];
      Future<void> pump({double scale = 1}) => _pump(
        tester,
        (_) => DocumentsVehicleCarousel(
          vehicles: vehicles,
          initialVehicleId: 'b',
          onOpen: (_) {},
        ),
        scale: scale,
      );
      await pump();
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller;
      expect(find.text('2 de 2'), findsOneWidget);
      await pump(scale: 2);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller,
        same(controller),
      );
      vehicles = [b, a];
      await pump();
      await tester.pump();
      expect(find.text('1 de 2'), findsOneWidget);
      expect(controller!.page, 0);
      vehicles = [];
      await pump();
      expect(find.byType(PageView), findsNothing);
      vehicles = [a, b];
      await pump();
      await tester.pump();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller,
        same(controller),
      );
      expect(find.text('2 de 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
