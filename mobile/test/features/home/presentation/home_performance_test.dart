import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/visual_assets/presentation/visual_asset_widgets.dart';

import '../../../performance_test_harness.dart';
import '../../../plate_test_fonts.dart';

void main() {
  setUpAll(loadPlateTestFonts);
  for (final count in [0, 3, 20]) {
    testWidgets(
      'PERF Home $count profiles deduplicate and invalidate without retaining old requests',
      (tester) async {
        final harness = PerformanceTestHarness([]);
        await harness.pump(tester, const SizedBox.shrink());
        final vehicles = [
          for (var index = 0; index < count; index++)
            performanceVehicle(
              'fleet-$index',
              plate: 'ABC${100 + index * 10 + (index.isEven ? 6 : 5)}',
              registrationCity: 'Cali',
            ),
        ];
        final edited = [
          for (var index = 0; index < count; index++)
            performanceVehicle(
              'fleet-$index',
              plate: 'XYZ${100 + index * 10 + (index.isEven ? 5 : 6)}',
              registrationCity: 'Cali',
              revision: 1,
            ),
        ];
        final batches = [
          (vehicles, performanceJurisdictions.first),
          (edited, performanceJurisdictions.first),
          (edited, performanceJurisdictions.last),
        ];
        final providers = [
          for (final (profiles, city) in batches)
            homeVehicleSnapshotsProvider(
              HomeVehicleSnapshotsRequest(
                vehicles: profiles,
                selectedJurisdiction: city,
              ),
            ),
        ];
        int retainedRequests() => providers
            .toSet()
            .where((provider) => harness.container.exists(provider))
            .length;
        final queryCount = count == 0 ? 0 : 1;
        for (var batch = 0; batch < batches.length; batch++) {
          final (profiles, city) = batches[batch];
          final provider = providers[batch];
          expect(retainedRequests(), 0);
          final subscription = harness.container.listen(provider, (_, _) {});
          try {
            final snapshots = await harness.container.read(provider.future);
            expect(snapshots, hasLength(count));
            expect(harness.store.calls, hasLength(queryCount * (batch + 1)));
            expect(retainedRequests(), 1);
            expect(
              harness.store.calls.skip(queryCount * batch),
              everyElement((
                city.id,
                VehicleKind.car,
                VehicleServiceType.private,
              )),
            );
            for (var index = 0; index < count; index++) {
              expect(
                identical(snapshots[index].vehicle, profiles[index]),
                isTrue,
              );
              expect(snapshots[index].vehicle.registrationCity, 'Cali');
              final restricted = batch == 1 ? index.isOdd : index.isEven;
              expect(
                snapshots[index].today.status,
                restricted
                    ? RestrictionDayStatus.restricted
                    : RestrictionDayStatus.allowed,
              );
            }
            if (batch == batches.length - 1) {
              harness.store.status = RestrictionDayStatus.stale;
              harness.container.invalidate(bundledRestrictionsProvider);
              final stale = await harness.container.read(provider.future);
              expect(harness.store.calls, hasLength(queryCount * 4));
              expect(stale, hasLength(count));
              expect(
                stale.map((item) => item.today.status),
                everyElement(RestrictionDayStatus.stale),
              );
            }
          } finally {
            subscription.close();
          }
          await tester.pump();
          await harness.container.pump();
          expect(
            harness.container.exists(provider),
            isFalse,
            reason: '$count profiles from batch $batch remain cached',
          );
          expect(retainedRequests(), 0);
        }
      },
    );
  }

  testWidgets(
    'PERF Home 20 vehicles keep swipe focus and bounded mounted cards',
    (tester) async {
      final harness = PerformanceTestHarness([
        for (var index = 0; index < 20; index++)
          performanceVehicle(
            'fleet-$index',
            plate: 'ABC${106 + index * 10}',
            registrationCity: 'Cali',
          ),
      ]);
      await harness.pump(tester, const HomeScreen());
      final pager = find.byKey(const ValueKey('home-vehicle-page-view'));
      final indicator = find.byKey(const ValueKey('home-carousel-indicator'));
      final dots = find.descendant(
        of: indicator,
        matching: find.byType(AnimatedContainer),
      );
      final counter = find.byKey(const ValueKey('home-carousel-counter'));
      final bounds = tester.getRect(pager);
      final pageWidth =
          bounds.width *
          tester.widget<PageView>(pager).controller!.viewportFraction;
      expect(harness.container.read(homeFocusedVehicleIdProvider), 'fleet-0');
      expect(dots, findsNWidgets(7));
      expect(tester.widget<Text>(counter).data, '1 de 20');
      expect(
        tester.widget<PageView>(pager).childrenDelegate.estimatedChildCount,
        20,
      );
      for (var index = 1; index <= 19; index++) {
        await tester.drag(pager, Offset(-pageWidth, 0));
        await tester.pumpAndSettle();
        expect(
          harness.container.read(homeFocusedVehicleIdProvider),
          'fleet-$index',
        );
        expect(tester.getRect(pager), bounds);
        expect(dots, findsNWidgets(7));
        expect(
          find.byKey(ValueKey('home-carousel-dot-$index')),
          findsOneWidget,
        );
        expect(tester.widget<Text>(counter).data, '${index + 1} de 20');
        expect(
          find.byType(VehicleVisualImage).evaluate().length,
          lessThanOrEqualTo(3),
        );
      }
      expect(tester.widget<Text>(counter).data, '20 de 20');
      expect(
        find.byKey(const ValueKey('home-carousel-dot-13')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-carousel-dot-12')), findsNothing);
      await tester.drag(pager, Offset(pageWidth, 0));
      await tester.pumpAndSettle();
      expect(harness.container.read(homeFocusedVehicleIdProvider), 'fleet-18');
      expect(tester.widget<Text>(counter).data, '19 de 20');
      expect(
        (await harness.container.read(activeVehicleProvider.future))?.id,
        'fleet-0',
      );
      expect(harness.store.calls, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PERF Home reloads once at same-day coverage expiry and clock reversal',
    (tester) async {
      final harness = PerformanceTestHarness([performanceVehicle('first')]);
      harness.nowUtc = DateTime.utc(2026, 9, 10, 15, 1);
      harness.store.staleAfter = DateTime.utc(2026, 9, 10, 15, 2);
      await harness.pump(tester, const HomeScreen());
      final day = harness.container.read(bogotaDateProvider);
      final summary = find.byKey(const ValueKey('home-summary-main'));
      // Partial-day coverage is already conservative; exact store expiry still reloads.
      expect(tester.widget<Text>(summary).data, 'Datos vencidos');
      expect(harness.store.loadedStaleStates, [false]);
      await harness.tick(tester, const Duration(minutes: 1));
      expect(harness.container.read(bogotaDateProvider), day);
      expect(harness.store.calls, hasLength(2));
      expect(harness.store.loadedStaleStates, [false, true]);
      expect(tester.widget<Text>(summary).data, 'Datos vencidos');
      final reads = harness.store.ruleReads;
      await harness.tick(tester, const Duration(minutes: 1));
      expect(harness.store.calls, hasLength(2));
      expect(harness.store.ruleReads, reads);
      harness.nowUtc = DateTime.utc(2026, 9, 10, 15, 1);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(harness.store.loadedStaleStates, [false, true, false]);
      expect(harness.store.calls, hasLength(3));
      expect(harness.container.read(homeFocusedVehicleIdProvider), 'first');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('PERF Home transforms reuse painted static vehicle content', (
    tester,
  ) async {
    final harness = PerformanceTestHarness([
      performanceVehicle('first'),
      performanceVehicle('second', plate: 'BOG125'),
    ]);
    await harness.pump(tester, const HomeScreen());
    final visual = tester.renderObject<RenderCustomPaint>(
      find.byKey(const ValueKey('home-generic-vehicle-first')),
    );
    final painter = _CountingPainter(visual.painter!);
    visual.painter = painter;
    await tester.pump();
    expect(painter.paints, greaterThan(0));
    final before = painter.paints;
    final pager = find.byKey(const ValueKey('home-vehicle-page-view'));
    final bounds = tester.getRect(pager);
    final gesture = await tester.startGesture(tester.getCenter(pager));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-16, 0));
    await tester.pump();
    final during = painter.paints;
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      during - before,
      0,
      reason: 'static content repainted during transforms',
    );
    expect(tester.getRect(pager), bounds);
    expect(harness.container.read(homeFocusedVehicleIdProvider), 'first');
  });

  testWidgets('PERF Home drag transforms a stable vehicle subtree', (
    tester,
  ) async {
    final harness = PerformanceTestHarness([
      performanceVehicle('first'),
      performanceVehicle('second', plate: 'BOG125'),
    ]);
    await harness.pump(tester, const HomeScreen());
    final pager = find.byKey(const ValueKey('home-vehicle-page-view'));
    final visual = find.byWidgetPredicate(
      (widget) => widget is VehicleVisualImage && widget.vehicle.id == 'first',
    );
    final before = tester.widget<VehicleVisualImage>(visual);
    final beforeBounds = tester.getRect(visual);
    final gesture = await tester.startGesture(tester.getCenter(pager));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-16, 0));
    await tester.pump();
    final afterBounds = tester.getRect(visual);
    final after = tester.widget<VehicleVisualImage>(visual);
    final focus = harness.container.read(homeFocusedVehicleIdProvider);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(afterBounds, isNot(beforeBounds));
    expect(identical(after, before), isTrue);
    expect(focus, 'first');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'PERF Home shares coverage by category only within an operation',
    (tester) async {
      final vehicles = [
        performanceVehicle('restricted'),
        performanceVehicle('allowed', plate: 'BOG125'),
        performanceVehicle('taxi', service: VehicleServiceType.taxi),
        performanceVehicle('moto', kind: VehicleKind.motorcycle),
      ];
      final harness = PerformanceTestHarness(vehicles);
      await harness.pump(tester, const SizedBox.shrink());
      final provider = homeVehicleSnapshotsProvider(
        HomeVehicleSnapshotsRequest(
          vehicles: vehicles,
          selectedJurisdiction: performanceJurisdictions.first,
        ),
      );
      final subscription = harness.container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final first = await harness.container.read(provider.future);
      expect(harness.store.calls.length, 3);
      expect(first[0].today.status, RestrictionDayStatus.restricted);
      expect(first[1].today.status, RestrictionDayStatus.allowed);
      expect(first.map((snapshot) => snapshot.vehicle.id), [
        'restricted',
        'allowed',
        'taxi',
        'moto',
      ]);
      harness.store.status = RestrictionDayStatus.stale;
      harness.container.invalidate(bundledRestrictionsProvider);
      final second = await harness.container.read(provider.future);
      expect(harness.store.calls.length, 6);
      expect(
        second.every(
          (snapshot) => snapshot.today.status == RestrictionDayStatus.stale,
        ),
        isTrue,
      );
    },
  );

  testWidgets('PERF Home releases obsolete profile snapshot requests', (
    tester,
  ) async {
    final harness = PerformanceTestHarness([]);
    await harness.pump(tester, const SizedBox.shrink());
    for (var revision = 0; revision < 12; revision++) {
      final provider = homeVehicleSnapshotsProvider(
        HomeVehicleSnapshotsRequest(
          vehicles: [performanceVehicle('edited', revision: revision)],
          selectedJurisdiction: performanceJurisdictions.first,
        ),
      );
      final listener = harness.container.listen(provider, (_, _) {});
      final snapshots = await harness.container.read(provider.future);
      expect(
        snapshots.single.vehicle.nickname,
        'Vehicle edited revision $revision',
      );
      listener.close();
      await tester.pump();
      await harness.container.pump();
      expect(
        harness.container.exists(provider),
        isFalse,
        reason: 'revision $revision retained',
      );
    }
  });
}

class _CountingPainter extends CustomPainter {
  _CountingPainter(this.delegate);

  final CustomPainter delegate;
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    delegate.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _CountingPainter oldDelegate) => true;
}
