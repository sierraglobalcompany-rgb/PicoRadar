import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_tokens.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';

import '../../../test_app_harness.dart';
import '../../home/presentation/v01b_test_font.dart';

const _longCity = 'Área metropolitana de Bucaramanga';
const _sourceHost = 'www.alcaldiabogota.gov.co';
const _windows = [
  RestrictionTimeWindow(startMinute: 300, endMinute: 540),
  RestrictionTimeWindow(startMinute: 960, endMinute: 1200),
];
const _windowLabels = ['5:00 a. m. – 9:00 a. m.', '4:00 p. m. – 8:00 p. m.'];
const _jurisdictions = [
  RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogotá'),
  RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellín'),
  RestrictionJurisdiction(id: 'co-san-bucaramanga', name: _longCity),
];
late PicoJurisdictionCatalog _catalog;

void main() {
  setUpAll(() async {
    await loadV01bTestFont();
    // Complete asset I/O outside the widget tests' fake clock.
    final raw = await rootBundle.loadString(picoJurisdictionCatalogAssetPath);
    _catalog = PicoJurisdictionCatalog.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
  });
  late TestAppHarness harness;

  setUp(() async {
    harness = TestAppHarness();
    await harness.preferences.setString(
      picoJurisdictionPreferenceKey,
      'co-dc-bogota',
    );
  });

  tearDown(() async => harness.dispose());

  testWidgets('A1 city restriction is collective while BOG126 is allowed', (
    tester,
  ) async {
    final vehicle = await harness.repository.createVehicle(
      plate: 'BOG126',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: 'Bogotá',
    );
    await harness.repository.setActiveVehicle(vehicle.id);
    final screen = ValueNotifier<Widget>(
      PicoDetailScreen(vehicleId: vehicle.id, jurisdictionId: 'co-dc-bogota'),
    );
    addTearDown(screen.dispose);
    await _pumpAudit(
      tester,
      harness,
      vehicle: vehicle,
      child: ValueListenableBuilder<Widget>(
        valueListenable: screen,
        builder: (_, value, _) => value,
      ),
    );
    await _reveal(tester, find.byKey(const ValueKey('pico-summary-today')));
    expect(find.text('Sin pico y placa hoy'), findsWidgets);
    expect(find.text('No puede circular'), findsNothing);

    screen.value = const PicoDetailScreen(jurisdictionId: 'co-dc-bogota');
    await tester.pumpAndSettle();
    final hero = find.byKey(const ValueKey('pico-city-hero'));
    await _reveal(tester, hero);
    expect(_surfaceText(hero), contains('1 · 2 · 3 · 4 · 5'));
    expect(_surfaceText(hero), contains('Pico y placa hoy'));
    expect(_surfaceText(hero), isNot(contains('No puedes circular')));
    expect(_surfaceText(hero), isNot(contains('No circula')));
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-dc-bogota',
    );
    expect((await harness.repository.getActiveVehicle())?.id, vehicle.id);
    expect(tester.takeException(), isNull);
  });

  for (final status in [
    RestrictionDayStatus.allowed,
    RestrictionDayStatus.unknown,
    RestrictionDayStatus.stale,
  ]) {
    testWidgets('A1 city ${status.name} never grants personal permission', (
      tester,
    ) async {
      await _pumpAudit(tester, harness, status: status);
      final hero = find.byKey(const ValueKey('pico-city-hero'));
      await _reveal(tester, hero);
      final copy = _surfaceText(hero);
      expect(copy, isNot(contains('Puedes circular')));
      expect(copy, isNot(contains('Puede circular')));
      expect(copy, isNot(contains('No puedes circular')));
      if (status == RestrictionDayStatus.allowed) {
        expect(copy, contains('Sin restricción hoy'));
      } else {
        expect(copy, isNot(contains('Sin restricción hoy')));
        expect(
          copy,
          contains(
            status == RestrictionDayStatus.stale
                ? 'Datos vencidos'
                : 'Por verificar',
          ),
        );
        final paragraphs = find.descendant(
          of: hero,
          matching: find.byType(RichText),
        );
        expect(
          tester
              .widgetList<RichText>(paragraphs)
              .any((text) => text.text.style?.color == AppColors.green),
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    testWidgets('A2 Bucaramanga selector keeps whole word at $width scale 1', (
      tester,
    ) async {
      await _pumpAudit(
        tester,
        harness,
        cityId: 'co-san-bucaramanga',
        width: width,
        jurisdictions: const [
          RestrictionJurisdiction(
            id: 'co-san-bucaramanga',
            name: 'Bucaramanga',
          ),
        ],
      );
      final selector = find.byKey(const ValueKey('pico-city-change'));
      final city = find.descendant(
        of: selector,
        matching: find.text('Bucaramanga'),
      );
      expect(city, findsOneWidget);
      final problems = [
        ..._readabilityProblems(tester, selector),
        ..._wordLineProblems(tester, city),
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'A2 next restriction separates date and complete windows $width scale $scale',
        (tester) async {
          final vehicle = await harness.repository.createVehicle(
            plate: 'BOG126',
            kind: VehicleKind.car,
            serviceType: VehicleServiceType.private,
            registrationCity: 'Bogotá',
          );
          await _pumpAudit(
            tester,
            harness,
            vehicle: vehicle,
            cityId: 'co-ant-medellin',
            width: width,
            scale: scale,
            child: PicoDetailScreen(
              vehicleId: vehicle.id,
              jurisdictionId: 'co-ant-medellin',
            ),
          );
          final date = find.byKey(const ValueKey('pico-next-restriction'));
          final schedule = find.byKey(
            const ValueKey('pico-next-restriction-windows'),
          );
          await _reveal(tester, date);
          expect(tester.widget<Text>(date).data, 'Lun 14/09/2026');
          expect(schedule, findsOneWidget);
          expect(
            _normalized(tester.widget<Text>(schedule).data!),
            _windowLabels.join('\n'),
          );
          expect(
            tester.getRect(date).bottom,
            lessThanOrEqualTo(tester.getRect(schedule).top),
          );
          final problems = [
            ..._readabilityProblems(tester, date),
            ..._readabilityProblems(tester, schedule),
          ];
          final paragraph = tester.renderObject<RenderParagraph>(schedule);
          for (final time in RegExp(
            r'\d+:\d+ [ap]\. m\.',
          ).allMatches(_normalized(paragraph.text.toPlainText()))) {
            final lines = paragraph
                .getBoxesForSelection(
                  TextSelection(baseOffset: time.start, extentOffset: time.end),
                )
                .map((box) => box.top)
                .toSet();
            expect(lines, hasLength(1), reason: 'Split time: ${time.group(0)}');
          }
          expect(problems, isEmpty, reason: problems.join('\n'));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('A2 city picker readable geometry $width scale $scale', (
        tester,
      ) async {
        await _pumpAudit(tester, harness, width: width, scale: scale);
        await tester.tap(find.byKey(const ValueKey('pico-city-change')));
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('pico-city-search'));
        await tester.enterText(search, 'medellin');
        await tester.pumpAndSettle();
        final medellin = find.byKey(
          const ValueKey('pico-city-option-co-ant-medellin'),
        );
        await tester.ensureVisible(medellin);
        await tester.pumpAndSettle();
        expect(_surfaceText(medellin), contains('Medellín / Valle de Aburrá'));
        expect(
          _surfaceText(medellin),
          contains('Carros, Motos, Taxis · Cobertura vigente'),
        );
        expect(_surfaceText(medellin), contains('Disponible'));
        final problems = _readabilityProblems(tester, medellin);
        expect(tester.widget<ListTile>(medellin).onTap, isNotNull);

        await tester.enterText(search, 'cucuta');
        await tester.pumpAndSettle();
        final cucuta = find.byKey(
          const ValueKey('pico-city-option-co-nds-cucuta'),
        );
        await tester.ensureVisible(cucuta);
        await tester.pumpAndSettle();
        expect(_surfaceText(cucuta), contains('Cúcuta / área metropolitana'));
        expect(
          _surfaceText(cucuta),
          contains('Norte de Santander · Cobertura en preparación'),
        );
        expect(_surfaceText(cucuta), contains('Próximamente'));
        problems.addAll(_readabilityProblems(tester, cucuta));
        expect(tester.widget<ListTile>(cucuta).enabled, isFalse);
        expect(tester.widget<ListTile>(cucuta).onTap, isNull);
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('A2 city readable geometry $width scale $scale', (
        tester,
      ) async {
        await _pumpAudit(
          tester,
          harness,
          cityId: 'co-san-bucaramanga',
          width: width,
          scale: scale,
        );
        final problems = <String>[];
        final selector = find.byKey(const ValueKey('pico-city-change'));
        expect(_surfaceText(selector), contains('Bucaramanga'));
        expect(_surfaceText(selector), isNot(contains(_longCity)));
        problems.addAll(_readabilityProblems(tester, selector));
        problems.addAll(
          _wordLineProblems(
            tester,
            find.descendant(of: selector, matching: find.text('Bucaramanga')),
          ),
        );

        final hero = find.byKey(const ValueKey('pico-city-hero'));
        await _reveal(tester, hero);
        problems.addAll(_readabilityProblems(tester, hero));
        expect(_surfaceText(hero), contains('1 · 2 · 3 · 4 · 5'));

        final week = find.byKey(const ValueKey('pico-city-week-card'));
        await _reveal(tester, week);
        problems.addAll(_readabilityProblems(tester, week));
        final thursday = find.byKey(const ValueKey('pico-city-week-day-3'));
        await tester.ensureVisible(thursday);
        await tester.pumpAndSettle();
        expect(_surfaceText(thursday), contains('Jue'));
        problems.addAll(_readabilityProblems(tester, thursday));
        await tester.tap(thursday);
        await tester.pumpAndSettle();
        for (final window in _windowLabels) {
          expect(find.textContaining(window), findsWidgets);
        }
        Navigator.of(tester.element(find.textContaining(_windowLabels.first).first)).pop();
        await tester.pumpAndSettle();
        final schedule = find.byKey(const ValueKey('pico-city-schedule'));
        await _reveal(tester, schedule);
        problems.addAll(_readabilityProblems(tester, schedule));
        problems.addAll(_windowProblems(schedule));

        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
      });

      for (final stale in [false, true]) {
        testWidgets(
          'A2 personal source readable $width scale $scale stale $stale',
          (tester) async {
            final vehicle = await harness.repository.createVehicle(
              plate: 'BOG126',
              kind: VehicleKind.car,
              serviceType: VehicleServiceType.private,
              registrationCity: 'Bogotá',
            );
            await _pumpAudit(
              tester,
              harness,
              cityId: 'co-san-bucaramanga',
              vehicle: vehicle,
              status: stale
                  ? RestrictionDayStatus.stale
                  : RestrictionDayStatus.restricted,
              width: width,
              scale: scale,
              child: PicoDetailScreen(
                vehicleId: vehicle.id,
                jurisdictionId: 'co-san-bucaramanga',
              ),
            );
            final city = find.byKey(const ValueKey('pico-personal-change-city'));
            expect(_surfaceText(city), contains('Bucaramanga'));
            final source = find.byKey(const ValueKey('pico-personal-source-row'));
            await _reveal(tester, source);
            final problems = _readabilityProblems(tester, source);
            await tester.tap(source);
            await tester.pumpAndSettle();
            final sheet = find.byKey(const ValueKey('pico-personal-source-sheet'));
            expect(_surfaceText(sheet), contains(_sourceHost));
            expect(_surfaceText(sheet), contains(stale ? 'Por actualizar' : 'Vigentes'));
            problems.addAll(_readabilityProblems(tester, sheet));
            Navigator.of(tester.element(sheet)).pop();
            await tester.pumpAndSettle();
            expect(problems, isEmpty, reason: problems.join('\n'));
            if (stale) {
              await _reveal(
                tester,
                find.byKey(const ValueKey('pico-summary-today')),
              );
              expect(find.text('Datos vencidos'), findsWidgets);
              expect(find.text('Sin pico y placa hoy'), findsNothing);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

String _normalized(String text) => text.replaceAll('\u00a0', ' ');

List<String> _wordLineProblems(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final problems = <String>[];
  for (final word in RegExp(r'\S+').allMatches(paragraph.text.toPlainText())) {
    final lines = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: word.start, extentOffset: word.end),
        )
        .map((box) => box.top)
        .toSet();
    if (lines.length != 1) {
      problems.add('Split or hidden word: ${word.group(0)}');
    }
  }
  return problems;
}

String _surfaceText(Finder surface) => find
    .descendant(of: surface, matching: find.byType(RichText))
    .evaluate()
    .map(
      (element) => _normalized((element.widget as RichText).text.toPlainText()),
    )
    .join('\n');

List<String> _readabilityProblems(WidgetTester tester, Finder surface) {
  final problems = <String>[];
  final bounds = tester.getRect(surface).inflate(0.5);
  for (final element
      in find
          .descendant(of: surface, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    if (paragraph.didExceedMaxLines) problems.add('Truncated: $text');
    for (final box in paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    )) {
      final rect = Rect.fromPoints(
        paragraph.localToGlobal(Offset(box.left, box.top)),
        paragraph.localToGlobal(Offset(box.right, box.bottom)),
      );
      if (!bounds.contains(rect.topLeft) ||
          !bounds.contains(rect.bottomRight)) {
        problems.add('Outside ${surface.describeMatch(Plurality.one)}: $text');
      }
    }
  }
  if (find
      .descendant(of: surface, matching: find.byType(FittedBox))
      .evaluate()
      .isNotEmpty) {
    problems.add(
      'Text must reflow, not shrink: ${surface.describeMatch(Plurality.one)}',
    );
  }
  return problems;
}

List<String> _windowProblems(Finder surface) {
  final text = _surfaceText(surface);
  return [
    for (final window in _windowLabels)
      if (!text.contains(window))
        'Missing full 12-hour window in ${surface.describeMatch(Plurality.one)}: $window',
  ];
}

Future<void> _pumpAudit(
  WidgetTester tester,
  TestAppHarness harness, {
  String cityId = 'co-dc-bogota',
  VehicleProfile? vehicle,
  Widget? child,
  RestrictionDayStatus status = RestrictionDayStatus.restricted,
  double width = 360,
  double scale = 1,
  List<RestrictionJurisdiction> jurisdictions = _jurisdictions,
}) async {
  tester.view.physicalSize = Size(width, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        picoJurisdictionCatalogProvider.overrideWith((ref) async => _catalog),
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async => jurisdictions,
        ),
        vehicleListProvider.overrideWith(
          (ref) async => vehicle == null ? [] : [vehicle],
        ),
        activeVehicleProvider.overrideWith((ref) async => vehicle),
        restrictionStoreProvider.overrideWithValue(
          _AuditStore(harness.database, status),
        ),
        bogotaNowProvider.overrideWith((ref) => DateTime(2026, 9, 10, 13)),
        currentInstantProvider.overrideWith(
          (ref) => DateTime.utc(2026, 9, 10, 18),
        ),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        home: child ?? PicoDetailScreen(jurisdictionId: cityId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _AuditStore extends RestrictionStore {
  const _AuditStore(super.database, this.status);

  final RestrictionDayStatus status;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async => RestrictionRuleSet(
    coverageKnown: status != RestrictionDayStatus.unknown,
    dataIsStale: status == RestrictionDayStatus.stale,
    staleAfter: DateTime.utc(2026, 10),
    verifiedAt: DateTime.utc(2026, 9, 10),
    sourceUrls: const ['https://$_sourceHost/sisjur/fuente-oficial'],
    rules: [
      if (status == RestrictionDayStatus.restricted)
        RestrictionRule(
          id: 'audit-even-date',
          jurisdictionId: jurisdictionId,
          priority: 100,
          effect: RestrictionEffect.restrict,
          validFrom: DateTime(2026, 9),
          validUntil: DateTime(2026, 9, 30, 23, 59, 59),
          vehicleKinds: {vehicleKind},
          serviceTypes: {serviceType},
          weekdays: const {1, 2, 3, 4, 5},
          dateParity: RestrictionDateParity.even,
          digitPosition: RestrictionDigitPosition.lastNumeric,
          digits: jurisdictionId == 'co-ant-medellin'
              ? {3, 6}
              : {1, 2, 3, 4, 5},
          timeWindows: _windows,
          appliesOnHolidays: false,
        ),
    ],
  );
}
