import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../vehicle_status/platform/obligation_notifications.dart';
import '../data/pico_preferences.dart';
import '../data/restriction_store.dart';
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
  static const picoPayload = '/pico';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  void Function(String route)? _onRoute;
  String? _lastPlanSignature;
  String? _lastObligationPlanSignature;
  Future<void> _picoQueue = Future<void>.value();
  Future<void> _obligationQueue = Future<void>.value();

  Future<void> initialize({void Function(String route)? onRoute}) async {
    if (onRoute != null) {
      _onRoute = onRoute;
    }
    if (_initialized) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = notificationRouteFromPayload(response.payload);
        if (route != null) {
          _onRoute?.call(route);
        }
      },
    );
    _initialized = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.didNotificationLaunchApp == true
        ? launchDetails?.notificationResponse?.payload
        : null;
    final route = notificationRouteFromPayload(launchPayload);
    if (route != null) {
      _onRoute?.call(route);
    }
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

  Future<bool?> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidEnabled = await android?.areNotificationsEnabled();
    if (androidEnabled != null) {
      return androidEnabled;
    }
    return null;
  }

  // Serialize native writes, including cancellation, so the latest request wins.
  // Failures still reach their caller; they do not block subsequent requests.
  Future<void> _enqueuePico(Future<void> Function() action) {
    return _picoQueue = _picoQueue.then(
      (_) => action(),
      onError: (Object error, StackTrace stack) => action(),
    );
  }

  Future<void> _enqueueObligations(Future<void> Function() action) {
    return _obligationQueue = _obligationQueue.then(
      (_) => action(),
      onError: (Object error, StackTrace stack) => action(),
    );
  }

  Future<void> reschedule(List<PicoNotificationPlan> plans) {
    final snapshot = List<PicoNotificationPlan>.of(plans);
    return _enqueuePico(() => _reschedulePico(snapshot));
  }

  Future<void> _reschedulePico(List<PicoNotificationPlan> plans) async {
    final signature = _planSignature(plans);
    if (_lastPlanSignature == signature) {
      return;
    }
    await _cancelPicoNotifications();
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
    _lastPlanSignature = signature;
  }

  Future<void> cancelPicoNotifications() =>
      _enqueuePico(_cancelPicoNotifications);

  Future<void> _cancelPicoNotifications() async {
    _lastPlanSignature = null;
    final pending = await _plugin.pendingNotificationRequests();
    final ids = picoPendingNotificationIdsToCancel(pending);
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
    _lastPlanSignature = null;
  }

  Future<void> rescheduleObligationNotifications(
    List<ObligationNotificationPlan> plans,
  ) {
    final snapshot = List<ObligationNotificationPlan>.of(plans);
    return _enqueueObligations(() => _rescheduleObligations(snapshot));
  }

  Future<void> _rescheduleObligations(
    List<ObligationNotificationPlan> plans,
  ) async {
    final signature = _obligationPlanSignature(plans);
    if (_lastObligationPlanSignature == signature) {
      return;
    }
    await _cancelObligationNotifications();
    for (final plan in plans) {
      await _plugin.zonedSchedule(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        scheduledDate: plan.scheduledAt,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'vehicle_obligation_reminders',
            'Vencimientos del vehículo',
            channelDescription:
                'Recordatorios locales de SOAT, tecnomecánica y seguro.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: plan.payload,
      );
    }
    _lastObligationPlanSignature = signature;
  }

  Future<void> cancelObligationNotifications() =>
      _enqueueObligations(_cancelObligationNotifications);

  Future<void> _cancelObligationNotifications() async {
    _lastObligationPlanSignature = null;
    final pending = await _plugin.pendingNotificationRequests();
    final ids = obligationPendingNotificationIdsToCancel(pending);
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
    _lastObligationPlanSignature = null;
  }
}

String? notificationRouteFromPayload(String? payload) {
  if (payload == PicoNotificationScheduler.picoPayload) {
    return payload;
  }
  return obligationRouteFromPayload(payload);
}

String? picoRouteFromNotificationPayload(String? payload) {
  return payload == PicoNotificationScheduler.picoPayload ? payload : null;
}

List<int> picoPendingNotificationIdsToCancel(
  Iterable<PendingNotificationRequest> pending,
) {
  return pending
      .where(
        (request) => request.payload == PicoNotificationScheduler.picoPayload,
      )
      .map((request) => request.id)
      .toList(growable: false);
}

Future<List<PicoNotificationPlan>> buildPicoNotificationPlans({
  required RestrictionStore store,
  required DateTime currentInstant,
  required DateTime nowBogota,
  required List<VehicleProfile> vehicles,
  required RestrictionJurisdiction jurisdiction,
  required PicoAlertPreferences alertPreferences,
}) async {
  final days = <PicoVehicleRestrictionDay>[];
  for (final vehicle in vehicles) {
    final ruleSet = await store.loadCoverage(
      jurisdiction.id,
      vehicle.kind,
      vehicle.serviceType,
      currentInstant,
    );
    for (var offset = 0; offset < 14; offset += 1) {
      final date = DateTime(
        nowBogota.year,
        nowBogota.month,
        nowBogota.day + offset,
      );
      days.add(
        PicoVehicleRestrictionDay(
          vehicle: vehicle,
          jurisdictionName: jurisdiction.name,
          date: date,
          evaluation: evaluateRestrictionDay(
            ruleSet: ruleSet,
            jurisdictionId: jurisdiction.id,
            plate: vehicle.plate,
            vehicleKind: vehicle.kind,
            serviceType: vehicle.serviceType,
            date: date,
          ),
        ),
      );
    }
  }
  return planPicoNotifications(
    days: days,
    settings: PicoNotificationSettings(
      enabled: alertPreferences.enabled,
      dayBeforeEnabled: alertPreferences.dayBeforeEnabled,
      sameDayEnabled: alertPreferences.sameDayEnabled,
      dayBeforeMinute: alertPreferences.dayBeforeMinute,
      sameDayMinute: alertPreferences.sameDayMinute,
    ),
    nowBogota: nowBogota,
  );
}

String _planSignature(List<PicoNotificationPlan> plans) {
  return jsonEncode([
    for (final plan in plans)
      [
        plan.id,
        plan.scheduledAt.toIso8601String(),
        plan.title,
        plan.body,
        plan.payload,
      ],
  ]);
}

String _obligationPlanSignature(List<ObligationNotificationPlan> plans) {
  return jsonEncode([
    for (final plan in plans)
      [
        plan.id,
        plan.scheduledAt.toIso8601String(),
        plan.title,
        plan.body,
        plan.payload,
      ],
  ]);
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
      payload: PicoNotificationScheduler.picoPayload,
    ),
  );
}
