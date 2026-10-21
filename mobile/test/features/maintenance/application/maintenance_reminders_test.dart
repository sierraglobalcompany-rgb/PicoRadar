import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/maintenance/application/maintenance_reminders.dart';
import 'package:picoradar/features/maintenance/data/maintenance_record.dart';

void main() {
  test(
    'plans date reminders and reports kilometre reminders as local checks',
    () {
      final reminders = planMaintenanceReminders(
        vehicleId: 'vehicle-1',
        records: [
          _record(
            id: 'oil',
            nextDate: DateTime(2026, 10, 20),
            nextOdometer: 50000,
          ),
        ],
        now: DateTime(2026, 9, 19, 12),
        latestOdometer: 49000,
      );

      expect(reminders, hasLength(2));
      expect(reminders.first.kind, MaintenanceReminderKind.date);
      expect(reminders.first.scheduledAt, DateTime(2026, 10, 20, 9));
      expect(reminders.last.kind, MaintenanceReminderKind.odometer);
      expect(reminders.last.scheduledAt, isNull);
      expect(reminders.last.due, isFalse);
    },
  );

  test(
    'does not schedule stale dates and marks reached kilometre reminders',
    () {
      final reminders = planMaintenanceReminders(
        vehicleId: 'vehicle-1',
        records: [
          _record(
            id: 'brakes',
            nextDate: DateTime(2026, 9, 18),
            nextOdometer: 52000,
          ),
        ],
        now: DateTime(2026, 9, 19, 12),
        latestOdometer: 52010,
      );

      expect(reminders, hasLength(1));
      expect(reminders.single.kind, MaintenanceReminderKind.odometer);
      expect(reminders.single.due, isTrue);
    },
  );
}

MaintenanceRecord _record({
  required String id,
  DateTime? nextDate,
  int? nextOdometer,
}) {
  final created = DateTime(2026, 9, 1);
  return MaintenanceRecord(
    id: id,
    vehicleId: 'vehicle-1',
    serviceDate: created,
    type: 'Servicio',
    description: 'Mantenimiento programado',
    nextServiceDate: nextDate,
    nextOdometer: nextOdometer,
    createdAt: created,
    updatedAt: created,
  );
}
