import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/presentation/garage_screen.dart';

import '../../../performance_test_harness.dart';

void main() {
  testWidgets('PERF Garage page focus does not remeasure offscreen titles', (
    tester,
  ) async {
    final offscreen = _CountedTitleVehicle();
    final harness = PerformanceTestHarness([
      for (var i = 0; i < 7; i++) performanceVehicle('car-$i'),
      offscreen,
    ]);
    await harness.pump(tester, const GarageScreen());
    expect(
      find.byKey(const ValueKey('garage-vehicle-title-offscreen')),
      findsNothing,
    );
    final reads = offscreen.titleReads;
    expect(reads, greaterThan(0));
    final carousel = find.byKey(const ValueKey('garage-vehicle-carousel'));
    final beforeHeight = tester.getSize(carousel).height;
    final pager = tester.widget<PageView>(
      find.descendant(of: carousel, matching: find.byType(PageView)),
    );
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(pager.controller!.page, 1);
    expect(offscreen.titleReads, reads);
    expect(tester.getSize(carousel).height, beforeHeight);
    expect(
      harness.container.read(activeVehicleProvider).requireValue?.id,
      'car-0',
    );

    tester.view.physicalSize = const Size(360, 844);
    await tester.pumpAndSettle();
    expect(offscreen.titleReads, greaterThan(reads));
    final resizedReads = offscreen.titleReads;
    final normalHeight = tester.getSize(carousel).height;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    expect(offscreen.titleReads, greaterThan(resizedReads));
    expect(tester.getSize(carousel).height, greaterThan(normalHeight));
    expect(tester.takeException(), isNull);
  });
}

class _CountedTitleVehicle extends VehicleProfile {
  _CountedTitleVehicle()
    : super(
        id: 'offscreen',
        plate: 'OFF129',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  int titleReads = 0;

  @override
  String? get nickname {
    titleReads++;
    return 'A complete vehicle title that needs several lines';
  }
}
