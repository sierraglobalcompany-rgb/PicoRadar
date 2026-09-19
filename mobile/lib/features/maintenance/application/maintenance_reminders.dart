import '../data/maintenance_record.dart';

enum MaintenanceReminderKind { date, odometer }

class MaintenanceReminder {
  const MaintenanceReminder({
    required this.id,
    required this.vehicleId,
    required this.recordId,
    required this.kind,
    required this.title,
    required this.due,
    this.scheduledAt,
    this.targetOdometer,
  });

  final int id;
  final String vehicleId;
  final String recordId;
  final MaintenanceReminderKind kind;
  final String title;
  final bool due;
  final DateTime? scheduledAt;
  final int? targetOdometer;
}

List<MaintenanceReminder> planMaintenanceReminders({
  required String vehicleId,
  required List<MaintenanceRecord> records,
  required DateTime now,
  required int? latestOdometer,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final reminders = <MaintenanceReminder>[];
  for (final record in records) {
    final date = record.nextServiceDate;
    if (date != null) {
      final scheduledAt = DateTime(date.year, date.month, date.day, 9);
      if (!scheduledAt.isBefore(now) &&
          !DateTime(date.year, date.month, date.day).isBefore(today)) {
        reminders.add(
          MaintenanceReminder(
            id: maintenanceReminderId(
              vehicleId: vehicleId,
              recordId: record.id,
              kind: MaintenanceReminderKind.date,
            ),
            vehicleId: vehicleId,
            recordId: record.id,
            kind: MaintenanceReminderKind.date,
            title: record.type,
            due: false,
            scheduledAt: scheduledAt,
          ),
        );
      }
    }
    final target = record.nextOdometer;
    if (target != null) {
      reminders.add(
        MaintenanceReminder(
          id: maintenanceReminderId(
            vehicleId: vehicleId,
            recordId: record.id,
            kind: MaintenanceReminderKind.odometer,
          ),
          vehicleId: vehicleId,
          recordId: record.id,
          kind: MaintenanceReminderKind.odometer,
          title: record.type,
          due: latestOdometer != null && latestOdometer >= target,
          targetOdometer: target,
        ),
      );
    }
  }
  reminders.sort((a, b) {
    final aDate = a.scheduledAt;
    final bDate = b.scheduledAt;
    if (aDate == null && bDate == null) return a.id.compareTo(b.id);
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return List.unmodifiable(reminders);
}

int maintenanceReminderId({
  required String vehicleId,
  required String recordId,
  required MaintenanceReminderKind kind,
}) {
  var hash = 2166136261;
  for (final unit in '$vehicleId|$recordId|${kind.name}'.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x1fffffff;
  }
  // Maintenance reminders occupy 0x20000000..0x3fffffff.
  return 0x20000000 | (hash == 0 ? 1 : hash);
}
