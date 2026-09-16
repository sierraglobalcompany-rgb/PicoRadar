import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/design_system/branding.dart';
import 'package:picoradar/features/garage/presentation/vehicle_plate_badge.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';

import '../../plate_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPlateTestFonts);
  for (final number in ['BOG127', 'ZVV73D', 'GHGGH3453']) {
    testWidgets('insurance small plate prioritizes number $number', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ColombianPlateBadge(
                plate: number,
                compact: true,
                detailed: true,
                compactWidth: 80,
                micro: true,
                microNumberFontSize: 20,
                registrationLabel: 'BOGOTA',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final plate = tester.getRect(
        find.byKey(const ValueKey('colombian-plate-badge')),
      );
      expect(plate.width, 80);
      expect(plate.size.aspectRatio, closeTo(2.15, .01));
      final text = number.length == 6
          ? find.byKey(const ValueKey('colombian-plate-first-group'))
          : find.text(number);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final top = paragraph.localToGlobal(Offset.zero);
      final bottom = paragraph.localToGlobal(
        Offset(paragraph.size.width, paragraph.size.height),
      );
      expect(top.dx, greaterThan(plate.left));
      expect(bottom.dx, lessThan(plate.right));
      expect(top.dy, greaterThan(plate.top));
      expect(bottom.dy, lessThan(plate.bottom));
      if (number.length == 6) {
        expect(bottom.dy - top.dy, greaterThanOrEqualTo(17));
        expect(
          find.byKey(const ValueKey('colombian-plate-separator')),
          findsOneWidget,
        );
      }
    });
  }
  for (final aspect in ['size', 'emblem', 'characters', 'footer']) {
    testWidgets('owner correction independently verifies $aspect', (
      tester,
    ) async {
      for (final number in ['K7A123', 'MED124', 'WWW888']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ColombianPlateBadge(
                  plate: number,
                  compact: true,
                  detailed: true,
                  registrationLabel: 'MEDELLIN',
                ),
              ),
            ),
          ),
        );
        final badge = tester.getRect(
          find.byKey(const ValueKey('colombian-plate-badge')),
        );
        if (aspect == 'size') {
          expect(badge.width, 96);
          expect(badge.height, inInclusiveRange(45, 48));
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('colombian-plate-first-group')),
                )
                .style!
                .fontSize,
            20,
          );
        }
        final first = find.byKey(const ValueKey('colombian-plate-first-group'));
        final last = find.byKey(const ValueKey('colombian-plate-last-group'));
        final emblem = find.byKey(const ValueKey('colombian-plate-separator'));
        if (aspect == 'characters') {
          expect(first, findsOneWidget);
          expect(last, findsOneWidget);
          expect(
            tester.widget<Text>(first).data! + tester.widget<Text>(last).data!,
            number,
          );
        }
        if (aspect == 'emblem') {
          expect(
            tester.getRect(first).right,
            lessThan(tester.getRect(emblem).left),
          );
          expect(
            tester.getRect(emblem).right,
            lessThan(tester.getRect(last).left),
          );
          expect(tester.getSize(emblem).width, 7);
        }
        if (aspect == 'footer') {
          final footer = tester.getRect(
            find.byKey(const ValueKey('colombian-plate-registration-label')),
          );
          final bottomLeft = tester.getRect(
            find.byKey(const ValueKey('colombian-plate-fixing-bottom-left')),
          );
          final bottomRight = tester.getRect(
            find.byKey(const ValueKey('colombian-plate-fixing-bottom-right')),
          );
          expect(
            (footer.center.dy - bottomLeft.center.dy).abs(),
            lessThanOrEqualTo(1),
          );
          expect(
            (footer.center.dy - bottomRight.center.dy).abs(),
            lessThanOrEqualTo(1),
          );
          expect(bottomLeft.right, lessThan(footer.left));
          expect(footer.right, lessThan(bottomRight.left));
          expect(
            (footer.center.dy - badge.top) / badge.height,
            greaterThanOrEqualTo(0.77),
          );
          final groupRect = tester.getRect(first);
          expect(
            (groupRect.center.dy - badge.top) / badge.height,
            inInclusiveRange(0.38, 0.45),
          );
          expect(groupRect.bottom, lessThan(footer.top));
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets(
    'vehicle adapter uses registration only, and motorcycles use country',
    (tester) async {
      var loads = 0;
      const catalog = RegistrationCityCatalog(
        records: [
          RegistrationCity(
            municipality: 'Medellín',
            department: 'Antioquia',
            displayName: 'Medellín - Antioquia',
            source: 'fixture',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          registrationCityCatalogProvider.overrideWith((ref) async {
            loads++;
            return catalog;
          }),
        ],
      );
      addTearDown(container.dispose);
      for (final sample in [
        (
          VehicleKind.car,
          VehicleServiceType.private,
          'Medellín - Antioquia',
          'MEDELLÍN',
        ),
        (
          VehicleKind.car,
          VehicleServiceType.taxi,
          'Medellín - Antioquia',
          'MEDELLÍN',
        ),
        (
          VehicleKind.motorcycle,
          VehicleServiceType.private,
          'Medellín - Antioquia',
          'COLOMBIA',
        ),
        (VehicleKind.car, VehicleServiceType.private, '', 'COLOMBIA'),
        (
          VehicleKind.car,
          VehicleServiceType.private,
          'Ciudad antigua',
          'CIUDAD ANTIGUA',
        ),
      ]) {
        final vehicle = VehicleProfile(
          id: 'test',
          plate: 'ABC123',
          kind: sample.$1,
          serviceType: sample.$2,
          registrationCity: sample.$3,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Center(child: VehiclePlateBadge(vehicle: vehicle)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(sample.$4), findsOneWidget);
        expect(vehicle.registrationCity, sample.$3);
        expect(
          tester
              .widget<ColombianPlateBadge>(find.byType(ColombianPlateBadge))
              .publicService,
          sample.$2 == VehicleServiceType.taxi,
        );
      }
      expect(loads, 1);
    },
  );

  testWidgets(
    'plate variants fit phone widths and enlarged text without lost groups',
    (tester) async {
      for (final width in [360.0, 390.0, 412.0, 430.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final sample in [
            ('ABC123', 'MEDELLÍN', false),
            ('ABC12D', 'COLOMBIA', false),
            ('WXY456', 'SAN SEBASTIÁN DE MARIQUITA', true),
            ('ABC1234', 'REGISTRO ANTIGUO', false),
          ]) {
            await tester.binding.setSurfaceSize(Size(width, 932));
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 932),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 124,
                        child: ColombianPlateBadge(
                          plate: sample.$1,
                          compact: true,
                          detailed: true,
                          registrationLabel: sample.$2,
                          publicService: sample.$3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final badge = tester.getRect(
              find.byKey(const ValueKey('colombian-plate-badge')),
            );
            final label = tester.getRect(
              find.byKey(const ValueKey('colombian-plate-registration-label')),
            );
            expect(label.left, greaterThan(badge.left));
            expect(label.right, lessThan(badge.right));
            expect(label.bottom, lessThan(badge.bottom));
            expect(find.text(sample.$2), findsOneWidget);
            if (sample.$1.length == 6) {
              for (final key in [
                'colombian-plate-first-group',
                'colombian-plate-last-group',
              ]) {
                final rect = tester.getRect(find.byKey(ValueKey(key)));
                expect(rect.left, greaterThan(badge.left));
                expect(rect.right, lessThan(badge.right));
                expect(rect.bottom, lessThanOrEqualTo(label.top));
              }
            } else {
              expect(find.text(sample.$1), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          }
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  const evidence = String.fromEnvironment('PLATE_EVIDENCE');
  if (evidence.isNotEmpty) {
    testWidgets('export actual Flutter plate rendering for visual comparison', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(620, 240));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('plate-evidence'),
              child: ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final sample in [
                        ('AGH430', 'BOGOTÁ', false),
                        ('TAM650', 'BOGOTÁ', true),
                        ('IZN10F', 'COLOMBIA', false),
                      ])
                        ColombianPlateBadge(
                          plate: sample.$1,
                          compact: true,
                          registrationLabel: sample.$2,
                          publicService: sample.$3,
                          detailed: true,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('plate-evidence')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(evidence).create(recursive: true);
          await File('$evidence/plate-variants-automated.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
      await tester.binding.setSurfaceSize(null);
    });
  }
  testWidgets('plate has only an inset black border', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ColombianPlateBadge(
              plate: 'ABC123',
              registrationLabel: 'MEDELLIN',
            ),
          ),
        ),
      ),
    );
    final box = tester.widget<Container>(
      find.byKey(const ValueKey('colombian-plate-badge')),
    );
    expect((box.decoration! as BoxDecoration).border, isNull);
    final inner = find.byKey(const ValueKey('colombian-plate-inner-border'));
    expect(
      tester.getRect(inner).left,
      greaterThan(
        tester
            .getRect(find.byKey(const ValueKey('colombian-plate-badge')))
            .left,
      ),
    );
  });

  testWidgets('emblem has reserved space between character groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ColombianPlateBadge(
              plate: 'ABC123',
              registrationLabel: 'MEDELLIN',
            ),
          ),
        ),
      ),
    );
    final left = find.byKey(const ValueKey('colombian-plate-first-group'));
    final right = find.byKey(const ValueKey('colombian-plate-last-group'));
    final emblem = find.byKey(const ValueKey('colombian-plate-separator'));
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    expect(tester.getRect(left).right, lessThan(tester.getRect(emblem).left));
    expect(tester.getRect(emblem).right, lessThan(tester.getRect(right).left));
    expect(tester.getSize(emblem).width, inInclusiveRange(7, 9));
    expect(
      find.descendant(of: emblem, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    final paint = tester
        .widget<CustomPaint>(
          find.descendant(of: emblem, matching: find.byType(CustomPaint)),
        )
        .painter!;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
      paint.paint(canvas, const Size(24, 24));
      final picture = recorder.endRecording();
      final image = await picture.toImage(24, 24);
      try {
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        var internalInk = 0;
        for (var y = 6; y <= 18; y++) {
          for (var x = 7; x <= 17; x++) {
            if (bytes!.getUint8((y * 24 + x) * 4) < 100) internalInk++;
          }
        }
        expect(
          internalInk,
          greaterThan(30),
          reason: 'An empty ring must not pass as the emblem.',
        );
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
  });
}
