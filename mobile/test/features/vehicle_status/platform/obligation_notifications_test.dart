import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';

void main() {
  final vehicle = VehicleProfile(
    id: 'vehicle-1',
    plate: 'ABC123',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('obligation notifications', () {
    test('original obligation alarm identity survives calendar rollover only until expiry', () {
      for (final due in [
        DateTime(2026, 9, 30),
        DateTime(2026, 12, 31),
        DateTime(2028, 2, 29),
      ]) {
        List<ObligationNotificationPlan> at(
          DateTime now,
        ) => planObligationNotifications(
          obligations: [_obligation(VehicleObligationType.soat, dueDate: due)],
          vehiclesById: {vehicle.id: vehicle},
          nowBogota: now,
          permissionGranted: true,
          deliverySettings: [
            VehicleAlertSettings(
              vehicle.id,
              AlertCategory.soat,
              const AlertSettings(alarm: true, minute: 1439, offsetDays: [0]),
            ),
          ],
          retainRecentAlarms: true,
        );
        final before = at(DateTime(due.year, due.month, due.day, 23, 58))
            .single;
        final after = at(DateTime(due.year, due.month, due.day + 1, 0, 2))
            .single;
        expect(after.id, before.id);
        expect(after.scheduledAt, before.scheduledAt);
        expect(at(DateTime(due.year, due.month, due.day + 1, 0, 14)), isEmpty);
      }
    });
    test(
      'only scheduler opt-in retains recent alarm identity, including midnight',
      () {
        for (final minute in [2, 15]) {
          for (final retain in [false, true]) {
            for (final alarm in [false, true]) {
              final plans = planObligationNotifications(
                obligations: [
                  _obligation(
                    VehicleObligationType.soat,
                    dueDate: DateTime(2026, 9, 15),
                  ),
                ],
                vehiclesById: {vehicle.id: vehicle},
                nowBogota: DateTime(2026, 9, 15, 9, minute),
                permissionGranted: true,
                deliverySettings: [
                  VehicleAlertSettings(
                    vehicle.id,
                    AlertCategory.soat,
                    AlertSettings(
                      alarm: alarm,
                      minute: 540,
                      offsetDays: const [0],
                    ),
                  ),
                ],
                retainRecentAlarms: retain,
              );
              expect(plans.isNotEmpty, retain && alarm && minute < 15);
            }
          }
        }
        final plans = planObligationNotifications(
          obligations: [
            _obligation(
              VehicleObligationType.soat,
              dueDate: DateTime(2026, 9, 15),
            ),
          ],
          vehiclesById: {vehicle.id: vehicle},
          nowBogota: DateTime(2026, 9, 16, 0, 2),
          permissionGranted: true,
          deliverySettings: [
            VehicleAlertSettings(
              vehicle.id,
              AlertCategory.soat,
              const AlertSettings(alarm: true, minute: 1439, offsetDays: [0]),
            ),
          ],
          retainRecentAlarms: true,
        );
        expect(plans.single.dueDate, DateTime(2026, 9, 15));
      },
    );

    test(
      'recent alarm identity absent after delete disable or date change',
      () {
        for (final scenario in ['deleted', 'disabled', 'date']) {
          final plans = planObligationNotifications(
            obligations: [
              _obligation(
                VehicleObligationType.soat,
                reminderEnabled: scenario != 'disabled',
                dueDate: scenario == 'date'
                    ? DateTime(2026, 9, 16)
                    : DateTime(2026, 9, 15),
              ),
            ],
            vehiclesById: scenario == 'deleted' ? {} : {vehicle.id: vehicle},
            nowBogota: DateTime(2026, 9, 15, 9, 2),
            permissionGranted: true,
            deliverySettings: [
              VehicleAlertSettings(
                vehicle.id,
                AlertCategory.soat,
                const AlertSettings(alarm: true, offsetDays: [0]),
              ),
            ],
            retainRecentAlarms: true,
          );
          expect(
            plans.any((p) => p.dueDate == DateTime(2026, 9, 15)),
            isFalse,
            reason: scenario,
          );
        }
      },
    );
    test('custom delivery affects only its vehicle and category', () {
      final plans = planObligationNotifications(
        obligations: [
          _obligation(VehicleObligationType.soat),
          _obligation(VehicleObligationType.rtm),
        ],
        vehiclesById: {vehicle.id: vehicle},
        nowBogota: DateTime(2026, 7, 1),
        permissionGranted: true,
        deliverySettings: [
          VehicleAlertSettings(
            vehicle.id,
            AlertCategory.soat,
            const AlertSettings(
              alarm: true,
              enriched: true,
              minute: 615,
              offsetDays: [15, 0],
            ),
          ),
          const VehicleAlertSettings(
            'other',
            AlertCategory.rtm,
            AlertSettings(minute: 700, offsetDays: [2]),
          ),
        ],
      );
      final soat = plans
          .where((p) => p.type == VehicleObligationType.soat)
          .toList();
      final rtm = plans
          .where((p) => p.type == VehicleObligationType.rtm)
          .toList();
      expect(soat.map((p) => p.offsetDays), [15, 0]);
      expect(
        soat.every(
          (p) => p.scheduledAt.hour == 10 && p.scheduledAt.minute == 15,
        ),
        isTrue,
      );
      expect(
        soat.every(
          (p) =>
              p.delivery!.alarm &&
              p.delivery!.enriched &&
              p.plate == vehicle.plate,
        ),
        isTrue,
      );
      expect(rtm.map((p) => p.offsetDays), [30, 7, 1]);
      expect(
        rtm.every((p) => p.delivery == null && p.scheduledAt.hour == 9),
        isTrue,
      );
    });

    test(
      'module reminder switch remains authoritative after a delivery override',
      () {
        final plans = planObligationNotifications(
          obligations: [
            _obligation(VehicleObligationType.soat, reminderEnabled: false),
          ],
          vehiclesById: {vehicle.id: vehicle},
          nowBogota: DateTime(2026, 7, 1),
          permissionGranted: true,
          deliverySettings: [
            VehicleAlertSettings(
              vehicle.id,
              AlertCategory.soat,
              const AlertSettings(enabled: true, alarm: true),
            ),
          ],
        );
        expect(plans, isEmpty);
      },
    );

    test('schedules SOAT, RTM and insurance at 30, 7 and 1 days', () {
      final plans = planObligationNotifications(
        obligations: [
          _obligation(VehicleObligationType.soat),
          _obligation(VehicleObligationType.rtm),
          _obligation(VehicleObligationType.insurance),
        ],
        vehiclesById: {vehicle.id: vehicle},
        nowBogota: DateTime(2026, 7, 1, 8),
        permissionGranted: true,
      );

      expect(plans, hasLength(9));
      expect(plans.map((plan) => plan.offsetDays).toSet(), {30, 7, 1});
      expect(plans.every((plan) => plan.scheduledAt.hour == 9), isTrue);
      expect(
        plans.map((plan) => plan.payload),
        contains(
          '/apps/module/soat?vehicleId=vehicle-1&source=obligation_reminder',
        ),
      );
    });

    test('skips permission denied, disabled, tax, past and orphan plans', () {
      expect(
        planObligationNotifications(
          obligations: [_obligation(VehicleObligationType.soat)],
          vehiclesById: {vehicle.id: vehicle},
          nowBogota: DateTime(2026, 7, 1),
          permissionGranted: false,
        ),
        isEmpty,
      );

      final plans = planObligationNotifications(
        obligations: [
          _obligation(VehicleObligationType.soat, reminderEnabled: false),
          _obligation(VehicleObligationType.tax),
          _obligation(
            VehicleObligationType.rtm,
            dueDate: DateTime(2026, 6, 30),
          ),
          _obligation(VehicleObligationType.insurance, vehicleId: 'missing'),
        ],
        vehiclesById: {vehicle.id: vehicle},
        nowBogota: DateTime(2026, 7, 1),
        permissionGranted: true,
      );

      expect(plans, isEmpty);
    });

    test('ids are stable and in a distinct namespace', () {
      final first = stableObligationNotificationId(
        vehicleId: vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 9, 15),
        offsetDays: 30,
      );
      final second = stableObligationNotificationId(
        vehicleId: vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 9, 15),
        offsetDays: 30,
      );

      expect(first, second);
      expect(first & 0x40000000, 0x40000000);
    });

    test('cancel scope selects only obligation reminder payloads', () {
      const pending = [
        PendingNotificationRequest(1, 'Pico', 'Body', '/pico'),
        PendingNotificationRequest(
          2,
          'SOAT',
          'Body',
          '/apps/module/soat?vehicleId=vehicle-1&source=obligation_reminder',
        ),
        PendingNotificationRequest(
          3,
          'Other',
          'Body',
          '/apps/module/comparendos?source=obligation_reminder',
        ),
      ];

      expect(obligationPendingNotificationIdsToCancel(pending), [2]);
      expect(picoPendingNotificationIdsToCancel(pending), [1]);
    });

    test(
      'notification routes are whitelisted for foreground and cold start',
      () {
        expect(notificationRouteFromPayload('/pico'), '/pico');
        expect(
          notificationRouteFromPayload(
            '/apps/module/soat?vehicleId=vehicle-1&source=obligation_reminder',
          ),
          '/apps/module/soat?vehicleId=vehicle-1&source=obligation_reminder',
        );
        expect(
          notificationRouteFromPayload(
            '/apps/module/comparendos?source=obligation_reminder',
          ),
          isNull,
        );
        expect(
          notificationRouteFromPayload('https://www.runt.gov.co/'),
          isNull,
        );
        expect(
          notificationRouteFromPayload(
            '/apps/module/soat?vehicleId=vehicle-1&next=/garage',
          ),
          isNull,
        );
      },
    );
  });
}

VehicleObligation _obligation(
  VehicleObligationType type, {
  String vehicleId = 'vehicle-1',
  DateTime? dueDate,
  bool reminderEnabled = true,
}) {
  return VehicleObligation(
    id: vehicleObligationId(vehicleId, type),
    vehicleId: vehicleId,
    type: type,
    dueDate: dueDate ?? DateTime(2026, 9, 15),
    reminderEnabled: reminderEnabled,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}
