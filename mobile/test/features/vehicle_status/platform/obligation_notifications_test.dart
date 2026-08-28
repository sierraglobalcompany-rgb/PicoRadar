import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
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
