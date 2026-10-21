import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_clock.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';

import '../../../performance_test_harness.dart';
import '../../home/presentation/v01b_test_font.dart';

void main() {
  setUpAll(loadV01bTestFont);
  for (final personal in [true, false]) {
    testWidgets(
      'PERF Pico same-day expiry reloads once and reverses personal $personal',
      (tester) async {
        final harness = PerformanceTestHarness([
          performanceVehicle('personal'),
        ]);
        harness.nowUtc = DateTime.utc(2026, 9, 10, 15, 1);
        harness.store.staleAfter = DateTime.utc(2026, 9, 10, 15, 2);
        await harness.pump(
          tester,
          PicoDetailScreen(vehicleId: personal ? 'personal' : null),
        );
        final day = harness.container.read(bogotaDateProvider);
        final batchSize = personal ? 1 : 3;
        expect(harness.store.calls, hasLength(batchSize));
        expect(harness.store.loadedStaleStates, everyElement(isFalse));
        if (personal) {
          await _reveal(
            tester,
            find.byKey(const ValueKey('pico-summary-today')),
          );
          expect(_verdict(tester), 'Datos vencidos');
        } else {
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('pico-city-freshness')),
              matching: find.textContaining('Verificado'),
            ),
            findsOneWidget,
          );
        }
        await harness.tick(tester, const Duration(minutes: 1));
        expect(harness.container.read(bogotaDateProvider), day);
        expect(harness.store.calls, hasLength(batchSize * 2));
        expect(
          harness.store.loadedStaleStates.skip(batchSize),
          everyElement(isTrue),
        );
        if (personal) {
          expect(_verdict(tester), 'Datos vencidos');
        } else {
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('pico-city-freshness')),
              matching: find.textContaining('Por revisar'),
            ),
            findsOneWidget,
          );
        }
        final reads = harness.store.ruleReads;
        await harness.tick(tester, const Duration(minutes: 1));
        expect(harness.store.calls, hasLength(batchSize * 2));
        expect(harness.store.ruleReads, reads);
        harness.nowUtc = DateTime.utc(2026, 9, 10, 15, 1);
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(harness.store.calls, hasLength(batchSize * 3));
        expect(
          harness.store.loadedStaleStates.skip(batchSize * 2),
          everyElement(isFalse),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final showMonth in [false, true]) {
    testWidgets(
      'PERF personal Pico minute reuses daily work month $showMonth',
      (tester) async {
        final harness = PerformanceTestHarness([
          performanceVehicle('personal'),
        ]);
        await harness.pump(
          tester,
          const PicoDetailScreen(vehicleId: 'personal'),
        );
        if (showMonth) {
          await _reveal(
            tester,
            find.byKey(const ValueKey('pico-personal-month-calendar')),
          );
          expect(find.text('Septiembre 2026'), findsOneWidget);
        }
        await _reveal(tester, find.byKey(const ValueKey('pico-summary-today')));
        expect(
          _verdict(tester),
          '5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.',
        );
        expect(find.text('Empieza en 1 min'), findsOneWidget);
        final reads = harness.store.ruleReads;
        final calls = harness.store.calls.length;
        expect(reads, greaterThan(0));
        expect(harness.container.exists(appClockProvider), isTrue);
        await harness.tick(tester, const Duration(minutes: 1));
        expect(
          _verdict(tester),
          '5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.',
        );
        expect(find.text('Este tramo termina en 4 h'), findsOneWidget);
        expect(harness.store.calls.length, calls);
        expect(harness.store.ruleReads, reads);
        await harness.tick(tester, const Duration(minutes: 1));
        expect(harness.store.ruleReads, reads);
        if (showMonth) expect(find.text('Septiembre 2026'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('PERF city Pico minute reuses its daily summaries', (
    tester,
  ) async {
    final harness = PerformanceTestHarness([]);
    await harness.pump(tester, const PicoDetailScreen());
    final reads = harness.store.ruleReads;
    final calls = harness.store.calls.length;
    expect(reads, greaterThan(0));
    expect(find.text('Pico y placa hoy'), findsOneWidget);
    await harness.tick(tester, const Duration(minutes: 1));
    expect(find.text('Pico y placa hoy'), findsOneWidget);
    expect(harness.store.calls.length, calls);
    expect(harness.store.ruleReads, reads);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'PERF city summaries and vehicle shortcuts share three coverages',
    (tester) async {
      final harness = PerformanceTestHarness([
        performanceVehicle('restricted'),
        performanceVehicle('allowed', plate: 'BOG125'),
      ]);
      await harness.pump(tester, const PicoDetailScreen());
      expect(harness.store.calls.length, 3);
      expect(harness.store.calls.toSet(), hasLength(3));
      harness.container.invalidate(bundledRestrictionsProvider);
      await tester.pumpAndSettle();
      expect(harness.store.calls.length, 6);
      expect(find.text('Pico y placa hoy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PERF daily cache invalidates on real clock rollover and dataset',
    (tester) async {
      final harness = PerformanceTestHarness([performanceVehicle('personal')]);
      harness.nowUtc = DateTime.utc(2026, 9, 11, 4, 59);
      await harness.pump(tester, const PicoDetailScreen(vehicleId: 'personal'));
      await _reveal(tester, find.byKey(const ValueKey('pico-summary-today')));
      expect(_verdict(tester), 'Restricción finalizada');
      final before = harness.store.calls.length;
      harness.store.pending = Completer<void>();
      await harness.tick(tester, const Duration(minutes: 1));
      expect(harness.container.read(bogotaNowProvider), DateTime(2026, 9, 11));
      expect(_verdict(tester), 'Por verificar');
      harness.store.pending!.complete();
      harness.store.pending = null;
      await tester.pumpAndSettle();
      expect(harness.store.calls.length, before + 1);
      expect(_verdict(tester), 'Puede circular');
      for (final status in [
        RestrictionDayStatus.unknown,
        RestrictionDayStatus.stale,
      ]) {
        harness.store.status = status;
        harness.container.invalidate(bundledRestrictionsProvider);
        await tester.pumpAndSettle();
        expect(
          _verdict(tester),
          status == RestrictionDayStatus.unknown
              ? 'Por verificar'
              : 'Datos vencidos',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('PERF personal cache key includes vehicle and consulted city', (
    tester,
  ) async {
    final harness = PerformanceTestHarness([
      performanceVehicle('restricted'),
      performanceVehicle('allowed', plate: 'BOG125'),
    ]);
    final screen = ValueNotifier<Widget>(
      const PicoDetailScreen(vehicleId: 'restricted'),
    );
    addTearDown(screen.dispose);
    await harness.pump(
      tester,
      ValueListenableBuilder<Widget>(
        valueListenable: screen,
        builder: (_, value, _) => value,
      ),
    );
    await _reveal(tester, find.byKey(const ValueKey('pico-summary-today')));
    expect(
      _verdict(tester),
      '5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.',
    );
    screen.value = const PicoDetailScreen(vehicleId: 'allowed');
    await tester.pumpAndSettle();
    expect(_verdict(tester), 'Puede circular');
    screen.value = const PicoDetailScreen(
      vehicleId: 'allowed',
      jurisdictionId: 'co-dc-bogota',
    );
    await tester.pumpAndSettle();
    expect(
      _verdict(tester),
      '5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.',
    );
    expect(
      await harness.container.read(selectedPicoJurisdictionIdProvider.future),
      'co-ant-medellin',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PERF month memo keeps only the current requested month', (
    tester,
  ) async {
    final harness = PerformanceTestHarness([performanceVehicle('personal')]);
    await harness.pump(tester, const PicoDetailScreen(vehicleId: 'personal'));
    await _reveal(
      tester,
      find.byKey(const ValueKey('pico-personal-month-calendar')),
    );
    final septemberReads = harness.store.ruleReads;
    final next = find.byKey(const ValueKey('pico-month-next'));
    await _reveal(tester, next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(harness.store.ruleReads, greaterThan(septemberReads));
    final octoberReads = harness.store.ruleReads;
    await tester.tap(find.byKey(const ValueKey('pico-month-previous')));
    await tester.pumpAndSettle();
    expect(find.text('Septiembre 2026'), findsOneWidget);
    expect(harness.store.ruleReads, greaterThan(octoberReads));
    expect(tester.takeException(), isNull);
  });
}

String? _verdict(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('pico-summary-main')))
    .data
    ?.replaceAll('\u00a0', ' ');

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 35,
  );
  await tester.pumpAndSettle();
}
