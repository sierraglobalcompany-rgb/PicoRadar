import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

import '../../garage/data/vehicle_profile.dart';
import '../../alerts/data/alert_settings.dart';
import '../domain/vehicle_obligation.dart';
import '../../pico_placa/domain/bogota_time.dart';

const obligationReminderSource = 'obligation_reminder';
const obligationReminderOffsets = [30, 7, 1];
const obligationReminderMinuteOfDay = 9 * 60;

const obligationNotificationRoutes = {
  '/apps/module/soat',
  '/apps/module/tecnomecanica',
  '/apps/module/seguro_asistencia',
  '/apps/module/impuestos',
};

class ObligationNotificationPlan {
  const ObligationNotificationPlan({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.dueDate,
    required this.offsetDays,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
    this.delivery,
    this.plate,
  });

  final int id;
  final String vehicleId;
  final VehicleObligationType type;
  final DateTime dueDate;
  final int offsetDays;
  final timezone.TZDateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
  final AlertSettings? delivery;
  final String? plate;
}

List<ObligationNotificationPlan> planObligationNotifications({
  required Iterable<VehicleObligation> obligations,
  required Map<String, VehicleProfile> vehiclesById,
  required DateTime nowBogota,
  required bool permissionGranted,
  List<VehicleAlertSettings> deliverySettings = const [],
  // UI keeps the future-only default; reconciliation may retain an active alarm.
  bool retainRecentAlarms = false,
}) {
  if (!permissionGranted) {
    return const [];
  }

  final plans = <ObligationNotificationPlan>[];
  for (final obligation in obligations) {
    final selected = deliverySettings
        .where(
          (s) =>
              s.vehicleId == obligation.vehicleId &&
              s.category.name == obligation.type.value,
        )
        .firstOrNull
        ?.settings;
    if (!obligation.reminderEnabled ||
        obligation.dueDate == null ||
        obligation.type == VehicleObligationType.tax) {
      continue;
    }
    final dueDate = DateTime(
      obligation.dueDate!.year,
      obligation.dueDate!.month,
      obligation.dueDate!.day,
    );
    final retain = retainRecentAlarms && selected?.alarm == true;
    if (!retain &&
        dueDate.isBefore(
          DateTime(nowBogota.year, nowBogota.month, nowBogota.day),
        )) {
      continue;
    }
    final vehicle = vehiclesById[obligation.vehicleId];
    if (vehicle == null) {
      continue;
    }
    for (final offsetDays
        in selected?.offsetDays ?? obligationReminderOffsets) {
      final scheduledDate = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day - offsetDays,
      );
      final scheduledAt = bogotaScheduledTime(
        date: scheduledDate,
        minuteOfDay: selected?.minute ?? obligationReminderMinuteOfDay,
      );
      final now = timezone.TZDateTime(
        scheduledAt.location,
        nowBogota.year,
        nowBogota.month,
        nowBogota.day,
        nowBogota.hour,
        nowBogota.minute,
        nowBogota.second,
      );
      if (!scheduledAt.isAfter(now) &&
          (!retain ||
              !scheduledAt.add(const Duration(minutes: 15)).isAfter(now))) {
        continue;
      }
      plans.add(
        ObligationNotificationPlan(
          id: stableObligationNotificationId(
            vehicleId: obligation.vehicleId,
            type: obligation.type,
            dueDate: dueDate,
            offsetDays: offsetDays,
          ),
          vehicleId: obligation.vehicleId,
          type: obligation.type,
          dueDate: dueDate,
          offsetDays: offsetDays,
          scheduledAt: scheduledAt,
          title: _notificationTitle(obligation.type),
          body: '${vehicle.plate} · vence el ${formatShortDate(dueDate)}',
          delivery: selected,
          plate: vehicle.plate,
          payload: obligationReminderPayload(
            type: obligation.type,
            vehicleId: obligation.vehicleId,
          ),
        ),
      );
    }
  }
  return plans;
}

int stableObligationNotificationId({
  required String vehicleId,
  required VehicleObligationType type,
  required DateTime dueDate,
  required int offsetDays,
}) {
  var hash = 2166136261;
  final input =
      'vehicle_obligation|$vehicleId|${type.value}|'
      '${dueDate.year.toString().padLeft(4, '0')}-'
      '${dueDate.month.toString().padLeft(2, '0')}-'
      '${dueDate.day.toString().padLeft(2, '0')}|$offsetDays';
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 16777619) & 0x3fffffff;
  }
  return 0x40000000 | hash;
}

String obligationReminderPayload({
  required VehicleObligationType type,
  required String vehicleId,
}) {
  final path = obligationRouteForType(type);
  return Uri(
    path: path,
    queryParameters: {
      'vehicleId': vehicleId,
      'source': obligationReminderSource,
    },
  ).toString();
}

String obligationRouteForType(VehicleObligationType type) {
  return switch (type) {
    VehicleObligationType.soat => '/apps/module/soat',
    VehicleObligationType.rtm => '/apps/module/tecnomecanica',
    VehicleObligationType.insurance => '/apps/module/seguro_asistencia',
    VehicleObligationType.tax => '/apps/module/impuestos',
  };
}

bool isObligationReminderPayload(String? payload) {
  final route = obligationRouteFromPayload(payload);
  if (route == null) {
    return false;
  }
  final uri = Uri.parse(route);
  return uri.queryParameters['source'] == obligationReminderSource;
}

String? obligationRouteFromPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(payload);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
    return null;
  }
  if (!obligationNotificationRoutes.contains(uri.path)) {
    return null;
  }
  final keys = uri.queryParameters.keys.toSet();
  if (keys.difference({'vehicleId', 'source'}).isNotEmpty) {
    return null;
  }
  return uri.toString();
}

List<int> obligationPendingNotificationIdsToCancel(
  Iterable<PendingNotificationRequest> pending,
) {
  return pending
      .where((request) => isObligationReminderPayload(request.payload))
      .map((request) => request.id)
      .toList(growable: false);
}

String formatShortDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _notificationTitle(VehicleObligationType type) {
  return switch (type) {
    VehicleObligationType.soat => 'Tu SOAT vence pronto',
    VehicleObligationType.rtm => 'Tu tecnomecánica vence pronto',
    VehicleObligationType.insurance => 'Tu seguro vence pronto',
    VehicleObligationType.tax => 'Tu impuesto requiere revisión',
  };
}
