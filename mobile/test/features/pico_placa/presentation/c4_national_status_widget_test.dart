import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';

import '../../../plate_test_fonts.dart';
import '../../../test_app_harness.dart';

const _jurisdictionId = 'c4-test-jurisdiction';
const _cityName = 'Ciudad de prueba';
const _sourceUrl = 'https://movilidad.example.test/pico';
final _verifiedAt = DateTime(2026, 8, 30, 11);
final _evaluatedAt = DateTime(2026, 9, 2, 12);

enum _CoverageState { allowed, unknown, stale }

class _StatusFixture {
  const _StatusFixture({
    required this.name,
    required this.state,
    required this.visibleStatus,
  });

  final String name;
  final _CoverageState state;
  final String visibleStatus;
}

const _fixtures = [
  _StatusFixture(
    name: 'known-allowed',
    state: _CoverageState.allowed,
    visibleStatus: 'Sin restricción hoy',
  ),
  _StatusFixture(
    name: 'unknown',
    state: _CoverageState.unknown,
    visibleStatus: 'Por verificar',
  ),
  _StatusFixture(
    name: 'stale',
    state: _CoverageState.stale,
    visibleStatus: 'Datos vencidos',
  ),
];

void main() {
  setUpAll(loadPlateTestFonts);

  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  for (final fixture in _fixtures) {
    testWidgets('national city query ${fixture.name} announces scoped status', (
      tester,
    ) async {
      final previousHttpOverrides = HttpOverrides.current;
      final httpBlocker = _HttpCallBlocker();
      HttpOverrides.global = httpBlocker;
      addTearDown(() {
        HttpOverrides.global = previousHttpOverrides;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(harness.database),
            appPreferencesProvider.overrideWithValue(harness.preferences),
            bundledRestrictionsProvider.overrideWith((ref) async {}),
            restrictionJurisdictionsProvider.overrideWith(
              (ref) async => const [
                RestrictionJurisdiction(id: _jurisdictionId, name: _cityName),
              ],
            ),
            selectedPicoJurisdictionIdProvider.overrideWith(
              (ref) async => _jurisdictionId,
            ),
            restrictionStoreProvider.overrideWithValue(
              _SyntheticRestrictionStore(harness.database, fixture.state),
            ),
            currentInstantProvider.overrideWithValue(
              DateTime.utc(2026, 9, 2, 17),
            ),
            bogotaNowProvider.overrideWithValue(_evaluatedAt),
          ],
          child: MaterialApp(
            home: RepaintBoundary(
              key: const ValueKey('c4-national-status-render'),
              child: const PicoDetailScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hero = find.byKey(const ValueKey('pico-city-hero'));
      expect(
        find.descendant(of: hero, matching: find.text(fixture.visibleStatus)),
        findsOneWidget,
      );

      final announcement = tester
          .getSemantics(
            find.byKey(const ValueKey('pico-city-status-semantics')),
          )
          .label;
      expect(announcement, contains(fixture.visibleStatus));
      expect(announcement, contains('categoría Carros en $_cityName'));
      expect(
        announcement,
        contains('Fecha evaluada: Mié 2 de septiembre de 2026'),
      );

      if (fixture.state == _CoverageState.unknown ||
          fixture.state == _CoverageState.stale) {
        expect(
          announcement,
          contains('El estado de circulación no está confirmado'),
        );
        expect(announcement, isNot(contains('Sin restricción hoy')));
        expect(announcement, isNot(contains('Puede circular')));
      }

      if (fixture.state == _CoverageState.allowed ||
          fixture.state == _CoverageState.stale) {
        expect(announcement, contains('Fuente: movilidad.example.test'));
        expect(
          announcement,
          contains('Última verificación: Dom 30 de agosto de 2026'),
        );
      } else {
        expect(announcement, isNot(contains('Fuente:')));
        expect(announcement, isNot(contains('Última verificación:')));
      }

      expect(httpBlocker.requests, 0);
      expect(tester.takeException(), isNull);
      await _captureRender(tester, fixture.name);
    });
  }
}

class _SyntheticRestrictionStore extends RestrictionStore {
  _SyntheticRestrictionStore(super.database, this.state);

  final _CoverageState state;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    if (state == _CoverageState.unknown) {
      return const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      );
    }

    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: state == _CoverageState.stale,
      coverageCompleteness: CoverageCompleteness.complete,
      jurisdictionName: _cityName,
      verifiedAt: _verifiedAt,
      staleAfter: state == _CoverageState.stale
          ? DateTime(2026, 9, 1)
          : DateTime(2026, 9, 30),
      sourceUrls: const [_sourceUrl],
      rules: const [],
    );
  }
}

class _HttpCallBlocker extends HttpOverrides {
  int requests = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    requests++;
    throw StateError('HTTP is not allowed while rendering local coverage.');
  }
}

Future<void> _captureRender(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('c4-national-status-render')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}picoradar-c4-national-status',
      );
      await directory.create(recursive: true);
      final file = File('${directory.path}${Platform.pathSeparator}$name.png');
      await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
      debugPrint('C4_RENDER_CAPTURE=$name:${file.path}');
    } finally {
      image.dispose();
    }
  });
}
