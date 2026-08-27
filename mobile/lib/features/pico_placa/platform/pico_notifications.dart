import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../domain/bogota_time.dart';
import '../domain/restriction_day_evaluation.dart';

enum PicoAlertType { dayBefore, sameDay }

class PicoNotificationPlan {
  const PicoNotificationPlan({
    required this.id,
    required this.type,
    required this.vehicleId,
    required this.targetDate,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final PicoAlertType type;
  final String vehicleId;
  final DateTime targetDate;
  final timezone.TZDateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
}

class PicoNotificationSettings {
  const PicoNotificationSettings({
    required this.enabled,
    required this.dayBeforeEnabled,
    required this.sameDayEnabled,
    required this.dayBeforeMinute,
    required this.sameDayMinute,
  });

  final bool enabled;
  final bool dayBeforeEnabled;
  final bool sameDayEnabled;
  final int dayBeforeMinute;
  final int sameDayMinute;
}

class PicoVehicleRestrictionDay {
  const PicoVehicleRestrictionDay({
    required this.vehicle,
    required this.jurisdictionName,
    required this.date,
    required this.evaluation,
  });

  final VehicleProfile vehicle;
  final String jurisdictionName;
  final DateTime date;
  final RestrictionDayEvaluation evaluation;
}

List<PicoNotificationPlan> planPicoNotifications({
  required Iterable<PicoVehicleRestrictionDay> days,
  required PicoNotificationSettings settings,
  required DateTime nowBogota,
}) {
  if (!settings.enabled) {
    return const [];
  }

  final plans = <PicoNotificationPlan>[];
  for (final day in days) {
    if (day.evaluation.status != RestrictionDayStatus.restricted) {
      continue;
    }
    if (settings.dayBeforeEnabled) {
      _addPlan(
        plans,
        day,
        PicoAlertType.dayBefore,
        DateTime(day.date.year, day.date.month, day.date.day - 1),
        settings.dayBeforeMinute,
        nowBogota,
      );
    }
    if (settings.sameDayEnabled) {
      _addPlan(
        plans,
        day,
        PicoAlertType.sameDay,
        day.date,
        settings.sameDayMinute,
        nowBogota,
      );
    }
  }
  return plans;
}

int stablePicoNotificationId({
  required String vehicleId,
  required DateTime date,
  required PicoAlertType type,
}) {
  var hash = 2166136261;
  final input =
      '$vehicleId|${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}|${type.name}';
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

class PicoNotificationScheduler {
  PicoNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'pico_restriction_alerts';

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(alert: true, badge: true);
    return androidGranted ?? iosGranted ?? true;
  }

  Future<void> reschedule(List<PicoNotificationPlan> plans) async {
    await _plugin.cancelAll();
    for (final plan in plans) {
      await _plugin.zonedSchedule(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        scheduledDate: plan.scheduledAt,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Pico y Placa',
            channelDescription: 'Recordatorios locales de pico y placa.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: plan.payload,
      );
    }
  }
}

void _addPlan(
  List<PicoNotificationPlan> plans,
  PicoVehicleRestrictionDay day,
  PicoAlertType type,
  DateTime scheduleDate,
  int minuteOfDay,
  DateTime nowBogota,
) {
  final scheduledAt = bogotaScheduledTime(
    date: scheduleDate,
    minuteOfDay: minuteOfDay,
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
  if (!scheduledAt.isAfter(now)) {
    return;
  }
  final title = type == PicoAlertType.dayBefore
      ? 'Revisa tu Pico y Placa de mañana'
      : 'Consulta tu Pico y Placa de hoy';
  plans.add(
    PicoNotificationPlan(
      id: stablePicoNotificationId(
        vehicleId: day.vehicle.id,
        date: day.date,
        type: type,
      ),
      type: type,
      vehicleId: day.vehicle.id,
      targetDate: day.date,
      scheduledAt: scheduledAt,
      title: title,
      body:
          '${day.vehicle.plate} · ${shortVehicleTypeLabel(day.vehicle)} · '
          '${day.jurisdictionName}',
      payload: '/pico',
    ),
  );
}
