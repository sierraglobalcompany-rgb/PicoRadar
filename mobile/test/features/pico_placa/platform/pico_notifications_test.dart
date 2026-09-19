import 'dart:async';

import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';
import 'package:picoradar/features/alerts/platform/alert_alarm_gateway.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/bogota_time.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final pico in [true, false]) {
    group('real scheduler pico=$pico', () {
      late _NotificationChannel channel;
      late PicoNotificationScheduler scheduler;
      late DateTime futureDate;
      late _AlarmGateway alarms;

      setUp(() {
        // The real plugin rejects past dates before reaching the mocked channel.
        final now = DateTime.now().toUtc();
        futureDate = DateTime(now.year, now.month, now.day + 2);
        AndroidFlutterLocalNotificationsPlugin.registerWith();
        channel = _NotificationChannel();
        alarms = _AlarmGateway();
        scheduler = PicoNotificationScheduler(alarmGateway: alarms);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              _NotificationChannel.channel,
              channel.handle,
            );
      });
      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_NotificationChannel.channel, null);
      });

      Future<void> publish(
        String body, {
        String title = 'Reminder',
        bool alarm = false,
        bool enriched = false,
      }) {
        final time = bogotaScheduledTime(date: futureDate, minuteOfDay: 300);
        return pico
            ? scheduler.reschedule([
                PicoNotificationPlan(
                  id: 42,
                  type: PicoAlertType.sameDay,
                  vehicleId: 'car',
                  targetDate: futureDate,
                  scheduledAt: time,
                  title: title,
                  body: body,
                  payload: '/pico',
                  delivery: AlertSettings(alarm: alarm, enriched: enriched),
                  plate: 'DEM123',
                ),
              ])
            : scheduler.rescheduleObligationNotifications([
                ObligationNotificationPlan(
                  id: 42,
                  vehicleId: 'car',
                  type: VehicleObligationType.soat,
                  dueDate: futureDate.add(const Duration(days: 1)),
                  offsetDays: 1,
                  scheduledAt: time,
                  title: title,
                  body: body,
                  payload: obligationReminderPayload(
                    type: VehicleObligationType.soat,
                    vehicleId: 'car',
                  ),
                  delivery: AlertSettings(alarm: alarm, enriched: enriched),
                  plate: 'DEM123',
                ),
              ]);
      }

      Future<void> cancel() => pico
          ? scheduler.cancelPicoNotifications()
          : scheduler.cancelObligationNotifications();

      test('rebuilds identical plans removed by OS', () async {
        await publish('same');
        channel.pending.clear();
        await publish('same');
        expect(channel.schedules, 2);
        expect(channel.pending.keys, contains(42));
      });

      test('revocation cancels cache and grant retries same plan', () async {
        await publish('same');
        channel.enabled = false;
        await expectLater(publish('same'), throwsStateError);
        expect(channel.pending, isEmpty);
        channel.enabled = true;
        await publish('same');
        expect(channel.pending.keys, contains(42));
      });

      test('rejects wrong accepted alarm IDs and retries without notification fallback', () async {
        alarms.wrongIds = true;
        await expectLater(publish('same', alarm: true), throwsStateError);
        expect(channel.schedules, 0);
        expect(alarms.ids, isEmpty);
        alarms.wrongIds = false;
        await publish('same', alarm: true);
        expect(alarms.ids, {42});
        expect(alarms.writes, 2);
        expect(channel.schedules, 0);
        alarms.ids.clear();
        await publish('same', alarm: true);
        expect(alarms.writes, 3);
      });

      test(
        'alarm permission revoked invalidates otherwise present alarm',
        () async {
          await publish('same', alarm: true);
          alarms.available = false;
          await expectLater(publish('same', alarm: true), throwsStateError);
          expect(alarms.ids, isEmpty);
          alarms.available = true;
          await publish('same', alarm: true);
          expect(alarms.ids, {42});
        },
      );

      test(
        'native failure retries identical plan and does not poison queue',
        () async {
          alarms.failNext = true;
          await expectLater(
            publish('same', alarm: true),
            throwsA(isA<PlatformException>()),
          );
          await publish('same', alarm: true);
          expect(alarms.ids, {42});
          expect(channel.pending, isEmpty);
        },
      );

      test(
        'empty plan clears projection even after permission revoked',
        () async {
          await publish('same');
          channel.enabled = false;
          if (pico) {
            await scheduler.reschedule([]);
          } else {
            await scheduler.rescheduleObligationNotifications([]);
          }
          expect(channel.pending, isEmpty);
        },
      );

      test('failed cancellation clears signature before retry', () async {
        await publish('same', alarm: true);
        alarms.failCancellation = true;
        await expectLater(cancel(), throwsA(isA<PlatformException>()));
        await publish('same', alarm: true);
        expect(alarms.writes, 2);
      });

      testWidgets('enriched plate remains hidden on lock screen', (
        tester,
      ) async {
        await tester.runAsync(() => publish('same', enriched: true));
        final details = channel.lastArguments!['platformSpecifics'] as Map;
        expect(details['visibility'], NotificationVisibility.secret.index);
        expect(details['style'], isNot(0));
      });

      test(
        'same ids and dates refresh edited content and still deduplicate',
        () async {
          await publish('ABC123 | Bogota');
          await publish('XYZ999 | Medellin');
          expect(channel.pending[42]!['body'], 'XYZ999 | Medellin');
          await publish('XYZ999 | Medellin', title: 'Updated reminder');
          expect(channel.pending[42]!['title'], 'Updated reminder');
          final calls = channel.schedules;
          await publish('XYZ999 | Medellin', title: 'Updated reminder');
          expect(channel.schedules, calls);
        },
      );

      for (final cancelLatest in [false, true]) {
        test(
          'overlapping writes keep latest request: cancel=$cancelLatest',
          () async {
            final gate = Completer<void>();
            final started = Completer<void>();
            channel.gate = gate;
            channel.started = started;
            final old = publish('old');
            await started.future.timeout(const Duration(seconds: 2));
            channel.gate = null;
            final latest = cancelLatest ? cancel() : publish('latest');
            await Future<void>.delayed(Duration.zero);
            gate.complete();
            await Future.wait([old, latest]);
            if (cancelLatest) {
              expect(channel.pending, isEmpty);
            } else {
              expect(channel.pending[42]!['body'], 'latest');
            }
          },
        );
      }

      test(
        'failed write reaches caller and does not poison next request',
        () async {
          channel.failNext = true;
          await expectLater(
            publish('fails'),
            throwsA(isA<PlatformException>()),
          );
          await publish('retry');
          expect(channel.pending[42]!['body'], 'retry');
        },
      );
    });
  }

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  final car = _vehicle('car-1', 'ABC123');
  final taxi = _vehicle(
    'taxi-1',
    'TAX090',
    serviceType: VehicleServiceType.taxi,
  );
  const settings = PicoNotificationSettings(
    enabled: true,
    dayBeforeEnabled: true,
    sameDayEnabled: true,
    dayBeforeMinute: 19 * 60,
    sameDayMinute: 5 * 60,
  );

  test('restricted schedules day-before and same-day', () {
    final plans = planPicoNotifications(
      days: [_day(car, RestrictionDayStatus.restricted)],
      settings: settings,
      nowBogota: DateTime(2026, 8, 26, 12),
    );

    expect(plans, hasLength(2));
    expect(
      plans.map((plan) => plan.title),
      contains('Consulta tu Pico y Placa de hoy'),
    );
  });

  test('allowed does not schedule', () {
    expect(_plans(RestrictionDayStatus.allowed), isEmpty);
  });

  test('stale does not schedule', () {
    expect(_plans(RestrictionDayStatus.stale), isEmpty);
  });

  test('unknown does not schedule', () {
    expect(_plans(RestrictionDayStatus.unknown), isEmpty);
  });

  test('taxi and private car get separate ids and body labels', () {
    final plans = planPicoNotifications(
      days: [
        _day(car, RestrictionDayStatus.restricted),
        _day(taxi, RestrictionDayStatus.restricted),
      ],
      settings: settings,
      nowBogota: DateTime(2026, 8, 26, 12),
    );

    expect(plans.map((plan) => plan.id).toSet(), hasLength(4));
    expect(plans.map((plan) => plan.body), contains('TAX090 · Taxi · Bogotá'));
    expect(
      plans.map((plan) => plan.body),
      contains('ABC123 · Particular · Bogotá'),
    );
  });

  test('day-before can be disabled', () {
    final plans = planPicoNotifications(
      days: [_day(car, RestrictionDayStatus.restricted)],
      settings: const PicoNotificationSettings(
        enabled: true,
        dayBeforeEnabled: false,
        sameDayEnabled: true,
        dayBeforeMinute: 19 * 60,
        sameDayMinute: 5 * 60,
      ),
      nowBogota: DateTime(2026, 8, 26, 12),
    );

    expect(plans, hasLength(1));
    expect(plans.single.type, PicoAlertType.sameDay);
  });

  test('same-day can be disabled', () {
    final plans = planPicoNotifications(
      days: [_day(car, RestrictionDayStatus.restricted)],
      settings: const PicoNotificationSettings(
        enabled: true,
        dayBeforeEnabled: true,
        sameDayEnabled: false,
        dayBeforeMinute: 19 * 60,
        sameDayMinute: 5 * 60,
      ),
      nowBogota: DateTime(2026, 8, 26, 12),
    );

    expect(plans, hasLength(1));
    expect(plans.single.type, PicoAlertType.dayBefore);
  });

  test('ids are stable', () {
    final first = stablePicoNotificationId(
      vehicleId: 'vehicle',
      date: DateTime(2026, 8, 28),
      type: PicoAlertType.sameDay,
    );
    final second = stablePicoNotificationId(
      vehicleId: 'vehicle',
      date: DateTime(2026, 8, 28),
      type: PicoAlertType.sameDay,
    );

    expect(first, second);
  });

  test('pico IDs stay below obligation namespace and never use zero', () {
    for (var i = 0; i < 300; i++) {
      for (final type in PicoAlertType.values) {
        final id = stablePicoNotificationId(
          vehicleId: 'vehicle-$i',
          date: DateTime(2026, 9, 20),
          type: type,
        );
        expect(id, inInclusiveRange(1, 0x3fffffff));
      }
    }
    expect(
      picoPendingNotificationIdsToCancel(const [
        PendingNotificationRequest(0x70000000, 'Pico', '', '/pico'),
      ]),
      [0x70000000],
    );
  });

  test('past scheduled times are skipped', () {
    final plans = planPicoNotifications(
      days: [
        _day(car, RestrictionDayStatus.restricted, date: DateTime(2026, 8, 27)),
      ],
      settings: settings,
      nowBogota: DateTime(2026, 8, 27, 6),
    );

    expect(
      plans.map((plan) => plan.type),
      isNot(contains(PicoAlertType.sameDay)),
    );
  });

  test('pico route resolves from notification response payload', () {
    const response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: '/pico',
    );

    expect(picoRouteFromNotificationPayload(response.payload), '/pico');
    expect(picoRouteFromNotificationPayload('/soat'), isNull);
  });

  test('cold-start pico payload resolves to pico detail', () {
    const launch = NotificationAppLaunchDetails(
      true,
      notificationResponse: NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/pico',
      ),
    );

    expect(
      picoRouteFromNotificationPayload(launch.notificationResponse?.payload),
      '/pico',
    );
  });

  test('pico reschedule cancels only pico payloads', () {
    const pending = [
      PendingNotificationRequest(1, 'Pico', 'Body', '/pico'),
      PendingNotificationRequest(2, 'Pico', 'Body', '/pico'),
      PendingNotificationRequest(3, 'SOAT', 'Body', '/soat'),
    ];

    expect(picoPendingNotificationIdsToCancel(pending), [1, 2]);
  });

  test('tap payload remains scoped to pico detail', () {
    final plans = planPicoNotifications(
      days: [_day(car, RestrictionDayStatus.restricted)],
      settings: settings,
      nowBogota: DateTime(2026, 8, 26, 12),
    );

    expect(
      plans.every(
        (plan) =>
            Uri.parse(plan.payload).queryParameters['vehicleId'] == car.id,
      ),
      isTrue,
    );
  });

  test('per-vehicle payload is validated and recognized for cancellation', () {
    const route = '/pico?vehicleId=car-2';
    expect(notificationRouteFromPayload(route), route);
    expect(
      picoPendingNotificationIdsToCancel(const [
        PendingNotificationRequest(3, 'Pico', '', route),
      ]),
      [3],
    );
    for (final invalid in [
      '/pico?vehicleId=',
      '/pico?vehicleId=a&vehicleId=b',
      '/pico?other=x',
      '/pico#fragment',
      '/pico?vehicleId=%FF',
      '/pico?vehicleId=%00',
      'https://host/pico?vehicleId=a',
    ]) {
      expect(notificationRouteFromPayload(invalid), isNull, reason: invalid);
    }
  });

  test('planner does not schedule target dates after staleAfter', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final plans = await buildPicoNotificationPlans(
      store: _FakeRestrictionStore(db),
      currentInstant: DateTime.utc(2026, 8, 30, 12),
      nowBogota: DateTime(2026, 8, 30, 7),
      vehicles: [car],
      jurisdiction: const RestrictionJurisdiction(
        id: 'co-dc-bogota',
        name: 'Bogotá',
      ),
      alertPreferences: const PicoAlertPreferences(
        enabled: true,
        dayBeforeEnabled: true,
        sameDayEnabled: true,
        dayBeforeMinute: 19 * 60,
        sameDayMinute: 5 * 60,
        permissionRequested: true,
        permissionGranted: true,
      ),
    );

    expect(
      plans.every((plan) => plan.targetDate.isBefore(DateTime(2026, 9, 1))),
      isTrue,
    );
  });
}

class _NotificationChannel {
  static const channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final pending = <int, Map<String, dynamic>>{};
  int schedules = 0;
  bool failNext = false;
  bool enabled = true;
  Map<String, dynamic>? lastArguments;
  Completer<void>? gate;
  Completer<void>? started;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'areNotificationsEnabled':
        return enabled;
      case 'pendingNotificationRequests':
        return pending.values.toList();
      case 'cancel':
        pending.remove((call.arguments as Map)['id']);
        return null;
      case 'zonedSchedule':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        lastArguments = args;
        final delay = gate;
        if (delay != null) {
          started!.complete();
          await delay.future;
        }
        if (failNext) {
          failNext = false;
          throw PlatformException(code: 'test-schedule-failure');
        }
        schedules++;
        pending[args['id'] as int] = {
          'id': args['id'],
          'title': args['title'],
          'body': args['body'],
          'payload': args['payload'],
        };
        return null;
      default:
        throw StateError('Unexpected notification call: ${call.method}');
    }
  }
}

class _AlarmGateway extends AlertAlarmGateway {
  final ids = <int>{};
  bool wrongIds = false;
  bool available = true;
  bool failNext = false;
  bool failCancellation = false;
  int writes = 0;
  @override
  Future<AlarmCapabilities> capabilities() async =>
      AlarmCapabilities(supported: true, notifications: true, exact: available);
  @override
  Future<Set<int>> pending() async => {...ids};
  @override
  Future<void> cancel(String scope) async {
    if (failCancellation) {
      failCancellation = false;
      throw PlatformException(code: 'test-cancel-failed');
    }
    ids.clear();
  }

  @override
  Future<Set<int>> reschedule(
    String scope,
    List<Map<String, Object>> events,
  ) async {
    writes++;
    if (failNext) {
      failNext = false;
      throw PlatformException(code: 'test-alarm-failed');
    }
    ids.addAll(wrongIds ? {999} : events.map((e) => e['id'] as int));
    return {...ids};
  }
}

List<PicoNotificationPlan> _plans(RestrictionDayStatus status) {
  return planPicoNotifications(
    days: [_day(_vehicle('car-1', 'ABC123'), status)],
    settings: const PicoNotificationSettings(
      enabled: true,
      dayBeforeEnabled: true,
      sameDayEnabled: true,
      dayBeforeMinute: 19 * 60,
      sameDayMinute: 5 * 60,
    ),
    nowBogota: DateTime(2026, 8, 26, 12),
  );
}

class _FakeRestrictionStore extends RestrictionStore {
  _FakeRestrictionStore(super.database);

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: false,
      staleAfter: DateTime.utc(2026, 9, 1, 5),
      rules: [
        RestrictionRule(
          id: 'bogota-test',
          jurisdictionId: jurisdictionId,
          priority: 100,
          effect: RestrictionEffect.restrict,
          validFrom: DateTime(2026, 8),
          vehicleKinds: {vehicleKind},
          serviceTypes: {serviceType},
          weekdays: const {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
            DateTime.sunday,
          },
          digitPosition: RestrictionDigitPosition.lastNumeric,
          digits: const {3},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 360, endMinute: 1260),
          ],
          appliesOnHolidays: true,
        ),
      ],
    );
  }
}

PicoVehicleRestrictionDay _day(
  VehicleProfile vehicle,
  RestrictionDayStatus status, {
  DateTime? date,
}) {
  return PicoVehicleRestrictionDay(
    vehicle: vehicle,
    jurisdictionName: 'Bogotá',
    date: date ?? DateTime(2026, 8, 27),
    evaluation: RestrictionDayEvaluation(
      status: status,
      effectiveWindows: const [],
    ),
  );
}

VehicleProfile _vehicle(
  String id,
  String plate, {
  VehicleServiceType serviceType = VehicleServiceType.private,
}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: VehicleKind.car,
    serviceType: serviceType,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
