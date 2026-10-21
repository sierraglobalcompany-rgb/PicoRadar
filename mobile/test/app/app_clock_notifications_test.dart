import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_clock.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';

void main() {
  testWidgets('empty garage cancels only restriction reminders', (
    tester,
  ) async {
    final scheduler = _RecordingScheduler();
    final container = ProviderContainer(
      overrides: [
        currentInstantProvider.overrideWithValue(DateTime.utc(2026, 9, 19)),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        vehicleListProvider.overrideWith((ref) async => []),
        picoNotificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(container.dispose);
    await container.read(picoNotificationSyncProvider.future);
    expect(scheduler.picoCancellations, 1);
    expect(scheduler.obligationCalls, 0);
  });
  for (final pico in [true, false]) {
    for (final dispose in [false, true]) {
      testWidgets(
        'obsolete notification sync cannot publish: pico=$pico dispose=$dispose',
        (tester) async {
          final gate = Completer<void>();
          final started = Completer<void>();
          final restrictions = _RestrictionStore();
          final obligations = _ObligationStore();
          if (pico) {
            restrictions.gate = gate;
            restrictions.started = started;
          } else {
            obligations.gate = gate;
            obligations.started = started;
          }
          final scheduler = _RecordingScheduler();
          final container = ProviderContainer(
            overrides: [
              currentInstantProvider.overrideWithValue(
                DateTime.utc(2026, 9, 10, 5),
              ),
              bundledRestrictionsProvider.overrideWith((ref) async {}),
              vehicleListProvider.overrideWith((ref) async => [_vehicle]),
              picoAlertPreferencesProvider.overrideWith((ref) async => _alerts),
              selectedPicoJurisdictionIdProvider.overrideWith(
                (ref) async => 'test-city',
              ),
              restrictionJurisdictionsProvider.overrideWith(
                (ref) async => const [
                  RestrictionJurisdiction(id: 'test-city', name: 'Test city'),
                ],
              ),
              restrictionStoreProvider.overrideWithValue(restrictions),
              vehicleObligationStoreProvider.overrideWithValue(obligations),
              picoNotificationSchedulerProvider.overrideWithValue(scheduler),
            ],
          );
          addTearDown(container.dispose);
          final provider = pico
              ? picoNotificationSyncProvider
              : obligationNotificationSyncProvider;
          container.listen(provider, (_, _) {});
          await tester.pump();
          await started.future;
          restrictions.gate = null;
          obligations.gate = null;
          if (dispose) {
            container.dispose();
          } else {
            container.invalidate(provider);
            await tester.pump();
            await container.read(provider.future);
          }
          gate.complete();
          await tester.pump();
          expect(
            pico ? scheduler.picoCalls : scheduler.obligationCalls,
            dispose ? 0 : 1,
          );
          expect(tester.takeException(), isNull);
          container.dispose();
        },
      );
    }
  }

  testWidgets(
    'notification sync ignores minute ticks but responds to date and data',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var now = DateTime.utc(2026, 9, 10, 4, 58);
      final scheduler = _RecordingScheduler();
      final restrictions = _RestrictionStore();
      final obligations = _ObligationStore();
      final container = ProviderContainer(
        overrides: [
          appClockNowProvider.overrideWithValue(() => now),
          bundledRestrictionsProvider.overrideWith((ref) async {}),
          vehicleListProvider.overrideWith((ref) async => [_vehicle]),
          picoAlertPreferencesProvider.overrideWith((ref) async => _alerts),
          selectedPicoJurisdictionIdProvider.overrideWith(
            (ref) async => 'test-city',
          ),
          restrictionJurisdictionsProvider.overrideWith(
            (ref) async => const [
              RestrictionJurisdiction(id: 'test-city', name: 'Test city'),
            ],
          ),
          restrictionStoreProvider.overrideWithValue(restrictions),
          vehicleObligationStoreProvider.overrideWithValue(obligations),
          picoNotificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);
      final observer = AppClockLifecycleObserver(
        clock: container.read(appClockProvider.notifier),
        onResume: () {
          container.invalidate(picoNotificationSyncProvider);
          container.invalidate(obligationNotificationSyncProvider);
        },
      );
      tester.binding.addObserver(observer);
      addTearDown(() => tester.binding.removeObserver(observer));
      container.listen(picoNotificationSyncProvider, (_, _) {});
      container.listen(obligationNotificationSyncProvider, (_, _) {});

      Future<void> settle() async {
        await tester.pump();
        await container.read(picoNotificationSyncProvider.future);
        await container.read(obligationNotificationSyncProvider.future);
      }

      await settle();
      expect(scheduler.picoCalls, 1);
      expect(scheduler.obligationCalls, 1);
      expect(restrictions.instants, [now]);
      expect(scheduler.picoPlans, isNotEmpty);
      expect(scheduler.obligationPlans, isNotEmpty);

      now = DateTime.utc(2026, 9, 10, 4, 59);
      await tester.pump(const Duration(minutes: 1));
      await settle();
      expect(scheduler.picoCalls, 1);
      expect(scheduler.obligationCalls, 1);
      expect(restrictions.instants, hasLength(1));
      expect(obligations.reads, 1);

      now = DateTime.utc(2026, 9, 10, 5);
      await tester.pump(const Duration(minutes: 1));
      await settle();
      expect(scheduler.picoCalls, 2);
      expect(scheduler.obligationCalls, 2);
      expect(restrictions.instants.last, now);
      expect(scheduler.picoPlans.first.targetDate, DateTime(2026, 9, 10));

      now = DateTime.utc(2026, 9, 10, 5, 1);
      await tester.pump(const Duration(minutes: 1));
      await settle();
      expect(scheduler.picoCalls, 2);
      expect(scheduler.obligationCalls, 2);

      container.invalidate(vehicleListProvider);
      await settle();
      expect(scheduler.picoCalls, 3);
      expect(scheduler.obligationCalls, 3);
      expect(restrictions.instants.last, now);

      container.invalidate(picoAlertPreferencesProvider);
      await settle();
      expect(scheduler.picoCalls, 4);
      expect(scheduler.obligationCalls, 4);

      container.invalidate(bundledRestrictionsProvider);
      await settle();
      expect(scheduler.picoCalls, 5);
      expect(scheduler.obligationCalls, 4);

      container.invalidate(selectedPicoJurisdictionIdProvider);
      await settle();
      expect(scheduler.picoCalls, 6);
      expect(scheduler.obligationCalls, 4);

      container.invalidate(obligationNotificationSyncProvider);
      await settle();
      expect(scheduler.picoCalls, 6);
      expect(scheduler.obligationCalls, 5);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.utc(2026, 9, 10, 16, 15, 30);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle();
      expect(scheduler.picoCalls, 7);
      expect(scheduler.obligationCalls, 6);
      expect(restrictions.instants.last, now);
      expect(
        scheduler.picoPlans.every((plan) => plan.scheduledAt.isAfter(now)),
        isTrue,
      );
      expect(
        scheduler.obligationPlans.every(
          (plan) => plan.scheduledAt.isAfter(now),
        ),
        isTrue,
      );

      now = DateTime.utc(2026, 9, 10, 16, 16);
      await tester.pump(const Duration(seconds: 30));
      await settle();
      expect(scheduler.picoCalls, 7);
      expect(scheduler.obligationCalls, 6);
      tester.binding.removeObserver(observer);
      container.dispose();
    },
  );
}

final _vehicle = VehicleProfile(
  id: 'test-car',
  plate: 'ABC123',
  kind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _alerts = PicoAlertPreferences(
  enabled: true,
  dayBeforeEnabled: true,
  sameDayEnabled: true,
  dayBeforeMinute: 19 * 60,
  sameDayMinute: 5 * 60,
  permissionRequested: true,
  permissionGranted: true,
);

class _RestrictionStore implements RestrictionStore {
  final instants = <DateTime>[];
  Completer<void>? gate;
  Completer<void>? started;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    instants.add(now);
    final pending = gate;
    if (pending != null) {
      started?.complete();
      await pending.future;
    }
    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: false,
      rules: [
        RestrictionRule(
          id: 'test-rule',
          jurisdictionId: jurisdictionId,
          priority: 100,
          effect: RestrictionEffect.restrict,
          validFrom: DateTime(2026),
          validUntil: DateTime(2026, 12, 31),
          vehicleKinds: const {VehicleKind.car},
          serviceTypes: const {VehicleServiceType.private},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 300, endMinute: 1200),
          ],
          appliesOnHolidays: true,
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObligationStore implements VehicleObligationStore {
  var reads = 0;
  Completer<void>? gate;
  Completer<void>? started;

  @override
  Future<List<VehicleObligation>> listAll() async {
    reads += 1;
    final pending = gate;
    if (pending != null) {
      started?.complete();
      await pending.future;
    }
    return [
      VehicleObligation(
        id: 'test-soat',
        vehicleId: _vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 9, 17),
        reminderEnabled: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingScheduler extends PicoNotificationScheduler {
  int picoCancellations = 0;
  @override
  Future<void> cancelPicoNotifications() async {
    picoCancellations++;
  }

  var picoCalls = 0;
  var obligationCalls = 0;
  List<PicoNotificationPlan> picoPlans = [];
  List<ObligationNotificationPlan> obligationPlans = [];

  @override
  Future<void> initialize({void Function(String route)? onRoute}) async {}

  @override
  Future<void> reschedule(List<PicoNotificationPlan> plans) async {
    picoCalls += 1;
    picoPlans = plans;
  }

  @override
  Future<void> rescheduleObligationNotifications(
    List<ObligationNotificationPlan> plans,
  ) async {
    obligationCalls += 1;
    obligationPlans = plans;
  }
}
