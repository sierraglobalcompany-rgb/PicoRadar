import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:picoradar/app/app_clock.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  timezone_data.initializeTimeZones();
  for (final zone in ['America/Bogota', 'UTC']) {
    testWidgets('year rollover uses Bogota with a $zone clock source', (
      tester,
    ) async {
      final location = zone == 'UTC'
          ? timezone.UTC
          : timezone.getLocation(zone);
      var source = timezone.TZDateTime.from(
        DateTime.utc(2027, 1, 1, 4, 59),
        location,
      );
      final container = ProviderContainer(
        overrides: [appClockNowProvider.overrideWithValue(() => source)],
      );
      addTearDown(container.dispose);
      expect(container.read(bogotaNowProvider), DateTime(2026, 12, 31, 23, 59));
      source = timezone.TZDateTime.from(DateTime.utc(2027, 1, 1, 5), location);
      await tester.pump(const Duration(minutes: 1));
      expect(container.read(bogotaNowProvider), DateTime(2027, 1, 1));
      expect(
        container.read(currentInstantProvider),
        DateTime.utc(2027, 1, 1, 5),
      );
      container.dispose();
    });
  }

  testWidgets('same container rolls Bogota from September 9 to 10', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var now = DateTime.utc(2026, 9, 10, 4, 59, 45, 250);
    final container = ProviderContainer(
      overrides: [appClockNowProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);
    final observed = <DateTime>[];
    final stopObserving = _observeClock(tester, container);
    container.listen(bogotaNowProvider, (_, next) => observed.add(next));

    expect(container.read(currentInstantProvider), now);
    expect(
      container.read(bogotaNowProvider),
      DateTime(2026, 9, 9, 23, 59, 45, 250),
    );

    now = DateTime.utc(2026, 9, 10, 5);
    await tester.pump(const Duration(milliseconds: 14749));
    expect(container.read(bogotaNowProvider).day, 9);
    await tester.pump(const Duration(milliseconds: 1));

    expect(container.read(currentInstantProvider), now);
    expect(container.read(bogotaNowProvider), DateTime(2026, 9, 10));
    expect(observed, [DateTime(2026, 9, 10)]);
    stopObserving();
    container.dispose();
  });

  testWidgets('04:59 to 05:00 updates a restriction in the same container', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var now = DateTime.utc(2026, 9, 10, 9, 59);
    final container = ProviderContainer(
      overrides: [appClockNowProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);
    final restriction = Provider<RestrictionStatus>((ref) {
      return const RestrictionEngine().evaluate(
        RestrictionContext(
          jurisdictionId: 'test-city',
          plate: 'ABC123',
          vehicleKind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          registrationOrigin: RegistrationOrigin.local,
          localDateTime: ref.watch(bogotaNowProvider),
          isHoliday: false,
          coverageKnown: true,
          dataIsStale: false,
        ),
        [
          RestrictionRule(
            id: 'test-window',
            jurisdictionId: 'test-city',
            priority: 100,
            effect: RestrictionEffect.restrict,
            validFrom: DateTime(2026),
            vehicleKinds: const {VehicleKind.car},
            serviceTypes: const {VehicleServiceType.private},
            timeWindows: const [
              RestrictionTimeWindow(startMinute: 300, endMinute: 1200),
            ],
            appliesOnHolidays: true,
          ),
        ],
      ).status;
    });
    final stopObserving = _observeClock(tester, container);
    final observed = <RestrictionStatus>[];
    container.listen(restriction, (_, next) => observed.add(next));
    expect(container.read(restriction), RestrictionStatus.allowed);

    now = DateTime.utc(2026, 9, 10, 10);
    await tester.pump(const Duration(minutes: 1));

    expect(container.read(restriction), RestrictionStatus.restricted);
    expect(observed, [RestrictionStatus.restricted]);
    stopObserving();
    container.dispose();
  });

  for (final lifecycle in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    testWidgets('$lifecycle stops ticks; resume immediately refreshes', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var now = DateTime.utc(2026, 9, 9, 16, 20, 30);
      var reads = 0;
      final container = ProviderContainer(
        overrides: [
          appClockNowProvider.overrideWithValue(() {
            reads += 1;
            return now;
          }),
        ],
      );
      addTearDown(container.dispose);
      final initial = container.read(currentInstantProvider);
      final stopObserving = _observeClock(tester, container);
      tester.binding.handleAppLifecycleStateChanged(lifecycle);
      now = DateTime.utc(2026, 9, 10, 10, 12, 15);
      await tester.pump(const Duration(hours: 12));
      expect(reads, 1);
      expect(container.read(currentInstantProvider), initial);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(container.read(currentInstantProvider), now);
      expect(
        container.read(bogotaNowProvider),
        DateTime(2026, 9, 10, 5, 12, 15),
      );
      now = DateTime.utc(2026, 9, 10, 10, 13);
      await tester.pump(const Duration(seconds: 45));
      expect(container.read(currentInstantProvider), now);
      expect(reads, 3);
      stopObserving();
      container.dispose();
    });
  }

  testWidgets('background initialization reads once and waits for resume', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    var now = DateTime.utc(2026, 9, 9, 16);
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        appClockNowProvider.overrideWithValue(() {
          reads += 1;
          return now;
        }),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(currentInstantProvider), now);
    final stopObserving = _observeClock(tester, container);
    await tester.pump(const Duration(minutes: 2));
    expect(reads, 1);
    now = DateTime.utc(2026, 9, 10, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(container.read(bogotaNowProvider), DateTime(2026, 9, 10));
    expect(reads, 2);
    stopObserving();
    container.dispose();
  });

  testWidgets(
    'forward and backward adjustments re-read and realign wall time',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var now = DateTime.utc(2026, 9, 10, 10, 0, 20);
      var reads = 0;
      final container = ProviderContainer(
        overrides: [
          appClockNowProvider.overrideWithValue(() {
            reads += 1;
            return now;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(currentInstantProvider);

      now = DateTime.utc(2026, 9, 12, 12, 30, 7, 500);
      await tester.pump(const Duration(seconds: 40));
      expect(container.read(currentInstantProvider), now);
      expect(
        container.read(bogotaNowProvider),
        DateTime(2026, 9, 12, 7, 30, 7, 500),
      );
      await tester.pump(const Duration(milliseconds: 52499));
      expect(reads, 2);

      now = DateTime.utc(2026, 9, 9, 9, 59, 10);
      await tester.pump(const Duration(milliseconds: 1));
      expect(container.read(currentInstantProvider), now);
      expect(
        container.read(bogotaNowProvider),
        DateTime(2026, 9, 9, 4, 59, 10),
      );
      now = DateTime.utc(2026, 9, 9, 10);
      await tester.pump(const Duration(seconds: 50));
      expect(container.read(currentInstantProvider), now);
      expect(reads, 4);
      container.dispose();
    },
  );

  testWidgets('dispose cancels the timer', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        appClockNowProvider.overrideWithValue(() {
          reads += 1;
          return DateTime.utc(2026, 9, 10, 10);
        }),
      ],
    );
    container.read(currentInstantProvider);
    container.dispose();
    await tester.pump(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(reads, 1);
  });

  test('legacy instant and Bogota overrides remain available', () {
    final container = ProviderContainer(
      overrides: [
        currentInstantProvider.overrideWithValue(DateTime.utc(2026, 9, 10, 5)),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(bogotaNowProvider), DateTime(2026, 9, 10));

    final other = ProviderContainer(
      overrides: [
        bogotaNowProvider.overrideWithValue(DateTime(2026, 9, 9, 23)),
      ],
    );
    addTearDown(other.dispose);
    expect(other.read(bogotaNowProvider), DateTime(2026, 9, 9, 23));
  });
}

VoidCallback _observeClock(WidgetTester tester, ProviderContainer container) {
  final clock = container.read(appClockProvider.notifier);
  final observer = AppClockLifecycleObserver(clock: clock);
  tester.binding.addObserver(observer);
  final lifecycle = tester.binding.lifecycleState;
  if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
    clock.setForeground(false);
  }
  addTearDown(() => tester.binding.removeObserver(observer));
  return () => tester.binding.removeObserver(observer);
}
