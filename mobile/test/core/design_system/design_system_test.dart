import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/app/theme/app_tokens.dart';
import 'package:picoradar/core/design_system/app_components.dart';

void main() {
  const evidenceDirectory = String.fromEnvironment('HOME_EVIDENCE');
  if (evidenceDirectory.isNotEmpty) {
    testWidgets('ColombianPlateBadge exports automated plate variants', (
      tester,
    ) async {
      const monoFontPath = String.fromEnvironment('HOME_EVIDENCE_MONO_FONT');
      await tester.runAsync(() async {
        final artifacts = File(Platform.resolvedExecutable)
            .parent
            .parent
            .parent;
        final regular = FontLoader('Roboto');
        for (final weight in ['Regular', 'Bold']) {
          final file = File(
            '${artifacts.path}/material_fonts/Roboto-$weight.ttf',
          );
          regular.addFont(file.readAsBytes().then(ByteData.sublistView));
        }
        await regular.load();
        expect(
          monoFontPath,
          isNotEmpty,
          reason: 'HOME_EVIDENCE_MONO_FONT must name a local monospace font.',
        );
        final mono = FontLoader(
          'monospace',
        )..addFont(File(monoFontPath).readAsBytes().then(ByteData.sublistView));
        await mono.load();
      });
      const surfaceKey = ValueKey('automated-plate-evidence');
      await _pumpComponent(
        tester,
        RepaintBoundary(
          key: surfaceKey,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PicoRadar | Placas', style: AppTextStyles.h1),
                  const SizedBox(height: 8),
                  const Text('AUTOMATED · Flutter widget test'),
                  const Text('Datos ficticios · No es evidencia física'),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final sample in [
                        (
                          title: 'Particular',
                          plate: 'ABC123',
                          city: 'Bogotá D.C.',
                          taxi: false,
                        ),
                        (
                          title: 'Taxi',
                          plate: 'WXY456',
                          city: 'Medellín',
                          taxi: true,
                        ),
                        (
                          title: 'Moto',
                          plate: 'ABC12D',
                          city: 'COLOMBIA',
                          taxi: false,
                        ),
                      ])
                        SizedBox(
                          width: 200,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(sample.title, style: AppTextStyles.body),
                              const SizedBox(height: 12),
                              ColombianPlateBadge(
                                plate: sample.plate,
                                registrationLabel: sample.city,
                                publicService: sample.taxi,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        size: const Size(760, 380),
      );
      expect(find.byType(ColombianPlateBadge), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(surfaceKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          expect(bytes, isNotNull);
          final directory = Directory(evidenceDirectory);
          await directory.create(recursive: true);
          final output = File(
            '${directory.path}/20-plate-variants-automated.png',
          );
          await output.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
          expect(await output.length(), greaterThan(0));
        } finally {
          image.dispose();
        }
      });
    });
  }

  test('R01 spacing includes approved 3XL token', () {
    expect(AppSpacing.xxxl, 48);
  });

  test('R01 radii stay inside approved product ranges', () {
    expect(AppRadius.card, inInclusiveRange(20, 24));
    expect(AppRadius.button, inInclusiveRange(20, 24));
    expect(AppRadius.modal, inInclusiveRange(24, 28));
    expect(AppRadius.input, inInclusiveRange(16, 20));
    expect(AppRadius.chip, greaterThan(100));
  });

  test('R01 typography follows the baseline scale', () {
    expect(AppTextStyles.display.fontSize, inInclusiveRange(32, 40));
    expect(AppTextStyles.display.fontWeight, FontWeight.w700);
    expect(AppTextStyles.h1.fontSize, inInclusiveRange(24, 28));
    expect(AppTextStyles.h2.fontSize, inInclusiveRange(18, 22));
    expect(AppTextStyles.body.fontSize, inInclusiveRange(15, 17));
    expect(AppTextStyles.caption.fontSize, inInclusiveRange(12, 14));
  });

  test('R01-FIX motion tokens match the approved baseline', () {
    expect(AppMotion.microPress, const Duration(milliseconds: 110));
    expect(AppMotion.fade, const Duration(milliseconds: 180));
    expect(AppMotion.navBounce, const Duration(milliseconds: 220));
    expect(AppMotion.carouselSnap, const Duration(milliseconds: 300));
    expect(AppMotion.restrictedPulse, const Duration(milliseconds: 1700));
    expect(AppMotion.standardCurve, Curves.easeOutCubic);
    expect(AppMotion.springCurve, Curves.easeOutBack);
  });

  test('R01 keeps the approved route order unchanged', () {
    expect(AppTab.values.map((tab) => tab.route.path), [
      '/home',
      '/garage',
      '/apps',
      '/trip',
      '/drive',
    ]);
  });

  test('R02C phone orientation is portrait-only', () {
    final main = File('lib/main.dart').readAsStringSync();
    final androidManifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final iosPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(main, contains('WidgetsFlutterBinding.ensureInitialized()'));
    expect(
      main,
      contains(
        'SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])',
      ),
    );
    expect(androidManifest, contains('android:screenOrientation="portrait"'));
    expect(iosPlist, contains('UIInterfaceOrientationPortrait'));
    expect(iosPlist, isNot(contains('UIInterfaceOrientationLandscapeLeft')));
    expect(iosPlist, isNot(contains('UIInterfaceOrientationLandscapeRight')));
  });

  test('R01-FIX2 keeps approved bottom nav icon semantics', () {
    expect(AppTab.trip.icon, Icons.location_on_outlined);
    expect(AppTab.trip.selectedIcon, Icons.location_on);
    expect(AppTab.drive.label, 'Conducir');
  });

  testWidgets('AppBottomNav has five tabs with Apps in the center', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
    );

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Garaje'), findsOneWidget);
    expect(find.text('Apps'), findsOneWidget);
    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Conducir'), findsOneWidget);
    expect(_destinations[2].label, 'Apps');
    expect(
      find.byKey(const ValueKey('app-bottom-nav-apps-center')),
      findsOneWidget,
    );
  });

  testWidgets('AppBottomNav Apps uses the elevated center affordance', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
    );

    final haloBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('app-bottom-nav-apps-halo')),
    );
    final center = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('app-bottom-nav-apps-center')),
    );
    final centerBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('app-bottom-nav-apps-center')),
    );
    final decoration = center.decoration! as BoxDecoration;

    expect(haloBox.size.width, greaterThanOrEqualTo(52));
    expect(haloBox.size.height, greaterThanOrEqualTo(52));
    expect(centerBox.size.width, inInclusiveRange(44, 48));
    expect(centerBox.size.height, inInclusiveRange(44, 48));
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, AppColors.teal);
    expect(
      find.byKey(const ValueKey('app-bottom-nav-drive-wheel')),
      findsOneWidget,
    );
  });

  testWidgets('AppBottomNav exposes selected and unselected semantics', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 0,
        onSelect: (_) {},
      ),
    );

    final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
    final selected = semantics.singleWhere(
      (widget) => widget.properties.label == 'Inicio',
    );
    final unselected = semantics.singleWhere(
      (widget) => widget.properties.label == 'Garaje',
    );

    expect(selected.properties.label, 'Inicio');
    expect(selected.properties.button, isTrue);
    expect(selected.properties.selected, isTrue);
    expect(unselected.properties.label, 'Garaje');
    expect(unselected.properties.button, isTrue);
    expect(unselected.properties.selected, isFalse);
  });

  testWidgets('AppBottomNav press calls onSelect and settles animation', (
    tester,
  ) async {
    var selectedIndex = 0;
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 0,
        onSelect: (index) => selectedIndex = index,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pump(AppMotion.navBounce);
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppBottomNav updates selected state after tab change', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPicoRadarTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AppBottomNav(
                destinations: _destinations,
                currentIndex: selectedIndex,
                onSelect: (index) => setState(() => selectedIndex = index),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tab-garage')));
    await tester.pumpAndSettle();

    final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
    final garage = semantics.singleWhere(
      (widget) => widget.properties.label == 'Garaje',
    );
    expect(garage.properties.selected, isTrue);
  });

  testWidgets('AppBottomNav disables bounce transforms for reduced motion', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
      disableAnimations: true,
    );

    expect(
      find.byKey(const ValueKey('app-bottom-nav-motion-transform')),
      findsNothing,
    );
  });

  testWidgets('AppBottomNav touch targets are at least 48 dp tall', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 0,
        onSelect: (_) {},
      ),
    );

    final itemBox = tester.renderObject<RenderBox>(find.text('Inicio'));
    final navBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('app-bottom-navigation')),
    );

    expect(itemBox.size.height, greaterThan(0));
    expect(navBox.size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('AppBottomNav remains stable at 360dp and text scale 2', (
    tester,
  ) async {
    final sizes = [
      const Size(360, 800),
      const Size(390, 844),
      const Size(412, 915),
    ];

    for (final size in sizes) {
      for (final textScale in [1.0, 1.5, 2.0]) {
        await _pumpComponent(
          tester,
          AppBottomNav(
            destinations: _destinations,
            currentIndex: 2,
            onSelect: (_) {},
          ),
          size: size,
          textScale: textScale,
        );

        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsOneWidget,
        );
        expect(find.text('Inicio'), findsOneWidget);
        expect(find.text('Garaje'), findsOneWidget);
        expect(find.text('Apps'), findsOneWidget);
        expect(find.text('Viaje'), findsOneWidget);
        expect(find.text('Conducir'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('PicoRadar brand lockup is local and keeps brand text', (
    tester,
  ) async {
    await _pumpComponent(tester, const PicoRadarBrandLockup());

    expect(find.text('PicoRadar'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      File('lib/app/app.dart').readAsStringSync(),
      contains("title: 'PicoRadar'"),
    );
  });

  testWidgets('ColombianPlateBadge renders common plate formats', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColombianPlateBadge(plate: 'ABC123'),
          ColombianPlateBadge(plate: 'XYZ789'),
          ColombianPlateBadge(plate: 'ABC12D'),
        ],
      ),
    );

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('XYZ789'), findsOneWidget);
    expect(find.text('ABC12D'), findsOneWidget);
  });

  testWidgets('ColombianPlateBadge handles larger text scales', (tester) async {
    for (final textScale in [1.5, 2.0]) {
      await _pumpComponent(
        tester,
        const ColombianPlateBadge(plate: 'ABC1234', compact: true),
        textScale: textScale,
      );
      expect(find.text('ABC1234'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'ColombianPlateBadge preserves legacy layout without registration',
    (tester) async {
      for (final compact in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          await _pumpComponent(
            tester,
            ColombianPlateBadge(plate: 'ABC123', compact: compact),
            textScale: scale,
          );
          final badgeFinder = find.byKey(
            const ValueKey('colombian-plate-badge'),
          );
          final originalSize = tester.getSize(badgeFinder);
          final badge = tester.widget<Container>(badgeFinder);
          expect(
            badge.constraints,
            BoxConstraints(
              minWidth: compact ? 82 : 104,
              minHeight: compact ? 32 : 40,
              maxWidth: compact ? 116 : 148,
            ),
          );
          expect(
            find.text('COLOMBIA'),
            !compact && scale <= 1.6 ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('colombian-plate-registration-label')),
            findsNothing,
          );
          await _pumpComponent(
            tester,
            ColombianPlateBadge(
              plate: 'ABC123',
              compact: compact,
              registrationLabel: '   ',
            ),
            textScale: scale,
          );
          expect(tester.getSize(badgeFinder), originalSize);
          expect(
            find.byKey(const ValueKey('colombian-plate-registration-label')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'ColombianPlateBadge puts registration inside yellow below full plate',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final compact in [false, true]) {
          await _pumpComponent(
            tester,
            ColombianPlateBadge(
              plate: 'ABC1234',
              compact: compact,
              registrationLabel: '  Medellín  ',
            ),
          );
          final badge = find.byKey(const ValueKey('colombian-plate-badge'));
          final registration = find.byKey(
            const ValueKey('colombian-plate-registration-label'),
          );
          expect(
            find.descendant(of: badge, matching: registration),
            findsOneWidget,
          );
          expect(find.text('ABC1234'), findsOneWidget);
          expect(find.text('Medellín'), findsOneWidget);
          expect(find.text('COLOMBIA'), findsNothing);
          expect(
            tester.getTopLeft(registration).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(find.text('ABC1234')).dy),
          );
          expect(tester.getSize(badge).width, inInclusiveRange(96, 180));
          expect(
            (tester.widget<Container>(badge).decoration! as BoxDecoration)
                .color,
            AppColors.plateYellow,
          );
          expect(
            find.bySemanticsLabel('Placa ABC1234, Medellín'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('ColombianPlateBadge motorcycle country appears only once', (
    tester,
  ) async {
    for (final compact in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        await _pumpComponent(
          tester,
          ColombianPlateBadge(
            plate: 'ABC12D',
            compact: compact,
            registrationLabel: 'COLOMBIA',
          ),
          textScale: scale,
        );
        expect(find.text('ABC'), findsOneWidget);
        expect(find.text('12D'), findsOneWidget);
        expect(find.text('COLOMBIA'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'ColombianPlateBadge wraps long registration without shrinking or clipping',
    (tester) async {
      const city = 'San Sebastián de Mariquita';
      for (final compact in [false, true]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          await _pumpComponent(
            tester,
            SizedBox(
              width: 116,
              child: ColombianPlateBadge(
                plate: 'ABC123',
                compact: compact,
                registrationLabel: city,
              ),
            ),
            textScale: scale,
          );
          final registration = find.byKey(
            const ValueKey('colombian-plate-registration-label'),
          );
          final text = tester.widget<Text>(registration);
          expect(text.data, city);
          expect(text.style!.fontSize, compact ? 10 : 11);
          expect(text.softWrap, isTrue);
          expect(text.maxLines, isNull);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
          expect(
            find.ancestor(of: registration, matching: find.byType(FittedBox)),
            findsNothing,
          );
          expect(
            tester.getSize(registration).height,
            greaterThan((compact ? 10 : 11) * scale),
          );
          final badgeRect = tester.getRect(
            find.byKey(const ValueKey('colombian-plate-badge')),
          );
          final textRect = tester.getRect(registration);
          expect(textRect.left, greaterThanOrEqualTo(badgeRect.left));
          expect(textRect.right, lessThanOrEqualTo(badgeRect.right));
          expect(textRect.bottom, lessThanOrEqualTo(badgeRect.bottom));
          expect(find.text('ABC'), findsOneWidget);
          expect(find.text('123'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'ColombianPlateBadge opt-in uses vehicle plate colors and inset border',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final sample in [
          (
            plate: 'ABC123',
            label: 'Bogotá D.C.',
            publicService: false,
            number: 'ABC 123',
          ),
          (
            plate: 'WXY456',
            label: 'Medellín',
            publicService: true,
            number: 'WXY 456',
          ),
          (
            plate: 'ABC12D',
            label: 'COLOMBIA',
            publicService: false,
            number: 'ABC 12D',
          ),
        ]) {
          await _pumpComponent(
            tester,
            ColombianPlateBadge(
              plate: sample.plate,
              compact: true,
              registrationLabel: sample.label,
              publicService: sample.publicService,
            ),
          );
          final badge = find.byKey(const ValueKey('colombian-plate-badge'));
          final inset = find.byKey(
            const ValueKey('colombian-plate-inner-border'),
          );
          final outerDecoration =
              tester.widget<Container>(badge).decoration! as BoxDecoration;
          final innerDecoration =
              tester.widget<Container>(inset).decoration! as BoxDecoration;
          expect(
            outerDecoration.color,
            sample.publicService ? Colors.white : AppColors.plateYellow,
          );
          expect(
            innerDecoration.border,
            Border.all(color: Colors.black, width: 1.2),
          );
          expect(innerDecoration.borderRadius, BorderRadius.circular(5));
          expect(outerDecoration.border, isNull);
          expect(
            tester.getRect(inset).left,
            greaterThan(tester.getRect(badge).left),
          );
          expect(
            tester.getRect(inset).right,
            lessThan(tester.getRect(badge).right),
          );
          expect(
            tester
                .widget<Text>(find.text(sample.plate.substring(0, 3)))
                .style!
                .color,
            Colors.black,
          );
          expect(find.text(sample.label), findsOneWidget);
          expect(
            find.bySemanticsLabel('Placa ${sample.plate}, ${sample.label}'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<ColombianPlateBadge>(find.byType(ColombianPlateBadge))
                .plate,
            sample.plate,
          );
          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('ColombianPlateBadge public style requires registration opt-in', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      const ColombianPlateBadge(plate: 'ABC123', publicService: true),
    );
    final decoration =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('colombian-plate-badge')),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.color, AppColors.plateYellow);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('COLOMBIA'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('colombian-plate-inner-border')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('colombian-plate-separator')),
      findsNothing,
    );
    for (final corner in [
      'top-left',
      'top-right',
      'bottom-left',
      'bottom-right',
    ]) {
      expect(
        find.byKey(ValueKey('colombian-plate-fixing-$corner')),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ColombianPlateBadge opt-in has four inset slots and an illustrated emblem',
    (tester) async {
      await _pumpComponent(
        tester,
        const ColombianPlateBadge(
          plate: 'ABC123',
          registrationLabel: 'Bogotá D.C.',
        ),
      );
      final inset = tester.getRect(
        find.byKey(const ValueKey('colombian-plate-inner-border')),
      );
      final number = tester
          .getRect(find.text('ABC'))
          .expandToInclude(tester.getRect(find.text('123')));
      final label = tester.getRect(find.text('Bogotá D.C.'));
      for (final corner in [
        'top-left',
        'top-right',
        'bottom-left',
        'bottom-right',
      ]) {
        final fixing = find.byKey(ValueKey('colombian-plate-fixing-$corner'));
        expect(fixing, findsOneWidget);
        final rect = tester.getRect(fixing);
        final decoration =
            tester.widget<Container>(fixing).decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.rectangle);
        expect(decoration.color, Colors.black);
        expect(rect.size, const Size(6, 3));
        expect(inset.contains(rect.topLeft), isTrue);
        expect(inset.contains(rect.bottomRight), isTrue);
        expect(rect.overlaps(number), isFalse);
        expect(rect.overlaps(label), isFalse);
        expect(rect.center.dx < inset.center.dx, corner.endsWith('left'));
        expect(rect.center.dy < inset.center.dy, corner.startsWith('top'));
      }
      final separator = find.byKey(const ValueKey('colombian-plate-separator'));
      expect(
        find.descendant(of: separator, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ColombianPlateBadge car motorcycle taxi stay legible in compact widths',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final sample in [
          (plate: 'ABC123', label: 'Bogotá D.C.', publicService: false),
          (
            plate: 'WXY456',
            label: 'San Sebastián de Mariquita',
            publicService: true,
          ),
          (plate: 'ABC12D', label: 'COLOMBIA', publicService: false),
        ]) {
          for (final compact in [true, false]) {
            for (final width in [116.0, 160.0]) {
              for (final scale in [1.0, 2.0]) {
                await _pumpComponent(
                  tester,
                  SizedBox(
                    width: width,
                    child: ColombianPlateBadge(
                      plate: sample.plate,
                      registrationLabel: sample.label,
                      publicService: sample.publicService,
                      compact: compact,
                    ),
                  ),
                  textScale: scale,
                );
                final number = find.text(sample.plate.substring(0, 3));
                final lastGroup = find.text(sample.plate.substring(3));
                expect(lastGroup, findsOneWidget);
                final numberText = tester.widget<Text>(number);
                expect(numberText.style!.fontSize, compact ? 20 : 32);
                expect(numberText.style!.fontFamily, 'sans-serif-condensed');
                final numberBox = tester.renderObject<RenderBox>(number);
                final numberRect = Rect.fromPoints(
                  numberBox.localToGlobal(Offset.zero),
                  numberBox.localToGlobal(
                    numberBox.size.bottomRight(Offset.zero),
                  ),
                ).expandToInclude(tester.getRect(lastGroup));
                final separatorBox = tester.renderObject<RenderBox>(
                  find.byKey(const ValueKey('colombian-plate-separator')),
                );
                final separatorRect = Rect.fromPoints(
                  separatorBox.localToGlobal(Offset.zero),
                  separatorBox.localToGlobal(
                    separatorBox.size.bottomRight(Offset.zero),
                  ),
                );
                expect(
                  separatorRect.center.dx,
                  closeTo(
                    tester
                        .getCenter(
                          find.byKey(const ValueKey('colombian-plate-badge')),
                        )
                        .dx,
                    0.01,
                  ),
                );
                expect(separatorRect.width, lessThan(numberRect.width / 7));
                expect(numberRect.height, greaterThanOrEqualTo(12));
                final label = find.text(sample.label);
                final labelText = tester.widget<Text>(label);
                expect(labelText.style!.fontSize, compact ? 10 : 11);
                expect(labelText.maxLines, isNull);
                expect(
                  find.ancestor(of: label, matching: find.byType(FittedBox)),
                  findsNothing,
                );
                final labelRect = tester.getRect(label);
                final badgeFinder = find.byKey(
                  const ValueKey('colombian-plate-badge'),
                );
                final badgeRect = tester.getRect(badgeFinder);
                expect(badgeRect.width, width);
                expect(numberRect.left, greaterThan(badgeRect.left));
                expect(numberRect.right, lessThan(badgeRect.right));
                expect(numberRect.bottom, lessThanOrEqualTo(labelRect.top));
                expect(labelRect.bottom, lessThan(badgeRect.bottom));
                expect(labelRect.left, greaterThan(badgeRect.left));
                expect(labelRect.right, lessThan(badgeRect.right));
                expect(
                  (tester.widget<Container>(badgeFinder).decoration
                          as BoxDecoration)
                      .color,
                  sample.publicService ? Colors.white : AppColors.plateYellow,
                );
                expect(
                  find.bySemanticsLabel(
                    'Placa ${sample.plate}, ${sample.label}',
                  ),
                  findsOneWidget,
                );
                expect(find.text(sample.label), findsOneWidget);
                expect(tester.takeException(), isNull);
              }
            }
          }
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  test('R01-FIX Android launcher resources exist', () {
    final expectedPaths = [
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png',
      'android/app/src/main/res/drawable/ic_launcher_foreground.png',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
      'android/app/src/main/res/values/colors.xml',
    ];

    for (final path in expectedPaths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }

    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
  });

  testWidgets(
    'StatusCard renders success, warning, danger and neutral states',
    (tester) async {
      await _pumpComponent(
        tester,
        const Column(
          children: [
            StatusCard(
              title: 'Al dia',
              message: 'Puedes conducir.',
              tone: StatusTone.success,
            ),
            StatusCard(
              title: 'Preventivo',
              message: 'Revisa tu horario.',
              tone: StatusTone.warning,
            ),
            StatusCard(
              title: 'Critico',
              message: 'No conduzcas ahora.',
              tone: StatusTone.danger,
            ),
            StatusCard(
              title: 'Informativo',
              message: 'Consulta local disponible.',
              tone: StatusTone.neutral,
            ),
          ],
        ),
      );

      expect(find.text('Al dia'), findsOneWidget);
      expect(find.text('Preventivo'), findsOneWidget);
      expect(find.text('Critico'), findsOneWidget);
      expect(find.text('Informativo'), findsOneWidget);
    },
  );

  testWidgets('VehicleCard renders active and inactive states', (tester) async {
    await _pumpComponent(
      tester,
      const Column(
        children: [
          VehicleCard(plate: 'ABC123', kindLabel: 'Carro', active: true),
          VehicleCard(plate: 'XYZ789', kindLabel: 'Moto', active: false),
        ],
      ),
    );

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('XYZ789'), findsOneWidget);
    expect(find.text('Inactivo'), findsOneWidget);
  });

  testWidgets('DocumentExpiryCard renders document state content', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      const DocumentExpiryCard(
        title: 'SOAT',
        expiryLabel: 'Vence en 20 dias',
        tone: StatusTone.warning,
      ),
    );

    expect(find.text('SOAT'), findsOneWidget);
    expect(find.text('Vence en 20 dias'), findsOneWidget);
  });

  testWidgets('AppLauncherTile accepts a two-line label', (tester) async {
    await _pumpComponent(
      tester,
      SizedBox(
        width: 112,
        child: AppLauncherTile(
          title: 'Seguro\ny asistencia',
          icon: Icons.health_and_safety_outlined,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Seguro\ny asistencia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppLauncherTile avoids overflow at high text scale', (
    tester,
  ) async {
    await _pumpShowcase(tester, size: const Size(360, 800), textScale: 2);

    expect(find.byKey(const ValueKey('launcher-grid-360')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmptyState CTA stays actionable', (tester) async {
    var tapped = false;
    await _pumpComponent(
      tester,
      EmptyState(
        title: 'Sin vehiculos',
        message: 'Agrega tu primer vehiculo.',
        actionLabel: 'Agregar',
        onActionPressed: () => tapped = true,
      ),
    );

    await tester.tap(find.text('Agregar'));

    expect(tapped, isTrue);
  });

  testWidgets('DrivingSurface provides the future dark driving surface', (
    tester,
  ) async {
    await _pumpComponent(tester, const DrivingSurface(child: Text('Conducir')));

    final box = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('driving-surface')),
    );
    expect(box.color, const Color(0xFF07131F));
  });

  testWidgets('R01 visual gate renders required viewport and scale variants', (
    tester,
  ) async {
    final variants = [
      (size: const Size(390, 844), textScale: 1.0),
      (size: const Size(360, 800), textScale: 1.0),
      (size: const Size(412, 915), textScale: 1.0),
      (size: const Size(390, 844), textScale: 1.5),
      (size: const Size(390, 844), textScale: 2.0),
    ];

    for (final variant in variants) {
      await _pumpShowcase(
        tester,
        size: variant.size,
        textScale: variant.textScale,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('R01 theme exposes PicoRadar light colors', (tester) async {
    await _pumpComponent(tester, const SizedBox.shrink());

    final theme = Theme.of(tester.element(find.byType(SizedBox)));
    expect(theme.colorScheme.primary, AppColors.teal);
    expect(theme.colorScheme.secondary, AppColors.blue);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  testWidgets('PrimaryButton minimum touch target is at least 48 dp', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      PrimaryButton(
        key: const ValueKey('primary-touch-target'),
        label: 'Continuar',
        onPressed: () {},
      ),
    );

    final buttonBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('primary-touch-target')),
    );

    expect(buttonBox.size.height, greaterThanOrEqualTo(48));
  });
}

Future<void> _pumpComponent(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildPicoRadarTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          accessibleNavigation: disableAnimations,
        ),
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpShowcase(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildPicoRadarTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const PicoSurface(child: _DesignSystemShowcase()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _destinations = [
  AppBottomNavDestination(
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    color: AppColors.teal,
    keyName: 'home',
  ),
  AppBottomNavDestination(
    label: 'Garaje',
    icon: Icons.directions_car_outlined,
    selectedIcon: Icons.directions_car,
    color: AppColors.blue,
    keyName: 'garage',
  ),
  AppBottomNavDestination(
    label: 'Apps',
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps,
    color: AppColors.navy,
    keyName: 'apps',
  ),
  AppBottomNavDestination(
    label: 'Viaje',
    icon: Icons.location_on_outlined,
    selectedIcon: Icons.location_on,
    color: AppColors.orange,
    keyName: 'trip',
  ),
  AppBottomNavDestination(
    label: 'Conducir',
    icon: Icons.speed_outlined,
    selectedIcon: Icons.speed,
    color: AppColors.red,
    keyName: 'drive',
  ),
];

class _DesignSystemShowcase extends StatelessWidget {
  const _DesignSystemShowcase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(
              title: 'PicoRadar',
              subtitle: 'Sistema visual base',
            ),
            const StatusCard(
              title: 'Listo para salir',
              message: 'Consulta local disponible sin cuenta.',
              tone: StatusTone.success,
            ),
            const SizedBox(height: AppSpacing.l),
            const VehicleCard(
              plate: 'ABC123',
              kindLabel: 'Carro particular',
              active: true,
            ),
            const SizedBox(height: AppSpacing.l),
            const DocumentExpiryCard(
              title: 'Tecnomecanica',
              expiryLabel: 'Vence en 30 dias',
              tone: StatusTone.warning,
            ),
            const SizedBox(height: AppSpacing.l),
            const Wrap(
              key: ValueKey('launcher-grid-360'),
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              children: [
                SizedBox(
                  width: 104,
                  child: AppLauncherTile(
                    title: 'Seguro y asistencia',
                    icon: Icons.health_and_safety_outlined,
                    onTap: null,
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: AppLauncherTile(
                    title: 'Comparendos',
                    icon: Icons.receipt_long_outlined,
                    onTap: null,
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: AppLauncherTile(
                    title: 'Parqueaderos',
                    icon: Icons.local_parking_outlined,
                    onTap: null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            EmptyState(
              title: 'Sin documentos',
              message: 'Agrega documentos cuando el lote lo habilite.',
              actionLabel: 'Entendido',
              onActionPressed: () {},
            ),
            const SizedBox(height: AppSpacing.l),
            const AppSkeleton(width: 180),
            const SizedBox(height: AppSpacing.l),
            const DrivingSurface(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.l),
                child: Text('Superficie Conducir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
