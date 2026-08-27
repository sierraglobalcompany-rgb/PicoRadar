import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';

void main() {
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

  test('tap payload opens pico detail', () {
    final plans = planPicoNotifications(
      days: [_day(car, RestrictionDayStatus.restricted)],
      settings: settings,
      nowBogota: DateTime(2026, 8, 26, 12),
    );

    expect(plans.every((plan) => plan.payload == '/pico'), isTrue);
  });
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
