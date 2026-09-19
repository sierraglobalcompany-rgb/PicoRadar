import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../alerts/data/alert_settings.dart';
import '../../alerts/platform/alert_alarm_gateway.dart';
import '../../alerts/platform/notification_plate.dart';
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
    this.delivery,
    this.plate,
  });

  final int id;
  final PicoAlertType type;
  final String vehicleId;
  final DateTime targetDate;
  final timezone.TZDateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
  final AlertSettings? delivery;
  final String? plate;
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
  bool retainRecentAlarms = false,
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
        retainRecentAlarms,
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
        retainRecentAlarms,
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
  // Obligation reminders occupy 0x40000000..0x7fffffff.
  final id = hash & 0x3fffffff;
  return id == 0 ? 1 : id;
}

class PicoNotificationScheduler {
  PicoNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.settingsLoader,
    AlertAlarmGateway alarmGateway = const AlertAlarmGateway(),
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _alarms = alarmGateway;

  final Future<List<VehicleAlertSettings>> Function()? settingsLoader;
  final AlertAlarmGateway _alarms;
  Future<List<VehicleAlertSettings>> loadDeliverySettings() async =>
      await settingsLoader?.call() ?? const [];

  Future<Set<int>> pendingIds() async => {
    for (final request in await _plugin.pendingNotificationRequests())
      request.id,
    ...await _alarms.pending(),
  };

  static const _channelId = 'pico_restriction_alerts';
  static const picoPayload = '/pico';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  Future<void>? _initialization;
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
    final pending = _initialization ??= _initialize();
    try {
      await pending;
    } finally {
      if (identical(_initialization, pending)) _initialization = null;
    }
  }

  Future<void> _initialize() async {
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
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.didNotificationLaunchApp == true
        ? launchDetails?.notificationResponse?.payload
        : null;
    final route = notificationRouteFromPayload(launchPayload);
    _initialized = true;
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

  Future<void> showPreview() async {
    await initialize();
    await _plugin.show(
      id: 2147483000,
      title: 'Recordatorio de ejemplo',
      body: 'DEM123 - Vehiculo ficticio',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Pico y Placa',
          visibility: NotificationVisibility.secret,
          styleInformation: await notificationPlate('DEM123'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
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
    if (plans.isEmpty) {
      return _cancelPicoNotifications();
    }
    final signature = _planSignature(plans);
    final hasAlarms = plans.any((p) => p.delivery?.alarm == true);
    if (await areNotificationsEnabled() == false) {
      await _cancelPicoNotifications();
      throw StateError('Los permisos de aviso no estan disponibles.');
    }
    final alarmsAvailable =
        !hasAlarms || (await _alarms.capabilities()).canSchedule;
    if (alarmsAvailable &&
        _lastPlanSignature == signature &&
        await _plansStillPending({
          for (final p in plans)
            if (p.scheduledAt.isAfter(DateTime.now()))
              p.id: p.delivery?.alarm == true,
        })) {
      return;
    }
    _lastPlanSignature = null;
    await _cancelPluginPicoNotifications();
    final alarms = <Map<String, Object>>[];
    for (final plan in plans) {
      if (plan.delivery?.alarm == true) {
        alarms.add(_alarmEvent(plan.id, plan.scheduledAt, plan.payload));
        continue;
      }
      await _plugin.zonedSchedule(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        scheduledDate: plan.scheduledAt,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Pico y Placa',
            channelDescription: 'Recordatorios locales de pico y placa.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            visibility: NotificationVisibility.secret,
            styleInformation:
                plan.delivery?.enriched == true && plan.plate != null
                ? await notificationPlate(plan.plate!)
                : null,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: plan.payload,
      );
    }
    if (!alarmsAvailable) {
      await _alarms.cancel('pico');
      throw StateError(
        'Alarma no disponible. Las notificaciones normales se conservan.',
      );
    }
    if (alarms.isNotEmpty) {
      final accepted = await _alarms.reschedule('pico', alarms);
      if (!_acceptedAll(accepted, alarms)) {
        await _alarms.cancel('pico');
        throw StateError('No se programaron todas las alarmas.');
      }
    } else {
      await _alarms.cancel('pico');
    }
    _lastPlanSignature = signature;
  }

  Future<void> cancelPicoNotifications() =>
      _enqueuePico(_cancelPicoNotifications);

  Future<void> _cancelPicoNotifications() async {
    _lastPlanSignature = null;
    await _alarms.cancel('pico');
    await _cancelPluginPicoNotifications();
  }

  Future<void> _cancelPluginPicoNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    final ids = picoPendingNotificationIdsToCancel(pending);
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
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
    if (plans.isEmpty) {
      return _cancelObligationNotifications();
    }
    final signature = _obligationPlanSignature(plans);
    final hasAlarms = plans.any((p) => p.delivery?.alarm == true);
    if (await areNotificationsEnabled() == false) {
      await _cancelObligationNotifications();
      throw StateError('Los permisos de aviso no estan disponibles.');
    }
    final alarmsAvailable =
        !hasAlarms || (await _alarms.capabilities()).canSchedule;
    if (alarmsAvailable &&
        _lastObligationPlanSignature == signature &&
        await _plansStillPending({
          for (final p in plans)
            if (p.scheduledAt.isAfter(DateTime.now()))
              p.id: p.delivery?.alarm == true,
        })) {
      return;
    }
    _lastObligationPlanSignature = null;
    await _cancelPluginObligationNotifications();
    final alarms = <Map<String, Object>>[];
    for (final plan in plans) {
      if (plan.delivery?.alarm == true) {
        alarms.add(_alarmEvent(plan.id, plan.scheduledAt, plan.payload));
        continue;
      }
      await _plugin.zonedSchedule(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        scheduledDate: plan.scheduledAt,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'vehicle_obligation_reminders',
            'Vencimientos del vehículo',
            channelDescription:
                'Recordatorios locales de SOAT, tecnomecánica y seguro.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            visibility: NotificationVisibility.secret,
            styleInformation:
                plan.delivery?.enriched == true && plan.plate != null
                ? await notificationPlate(plan.plate!)
                : null,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: plan.payload,
      );
    }
    if (!alarmsAvailable) {
      await _alarms.cancel('obligations');
      throw StateError(
        'Alarma no disponible. Las notificaciones normales se conservan.',
      );
    }
    if (alarms.isNotEmpty) {
      final accepted = await _alarms.reschedule('obligations', alarms);
      if (!_acceptedAll(accepted, alarms)) {
        await _alarms.cancel('obligations');
        throw StateError('No se programaron todas las alarmas.');
      }
    } else {
      await _alarms.cancel('obligations');
    }
    _lastObligationPlanSignature = signature;
  }

  Future<void> cancelObligationNotifications() =>
      _enqueueObligations(_cancelObligationNotifications);

  Future<void> _cancelObligationNotifications() async {
    _lastObligationPlanSignature = null;
    await _alarms.cancel('obligations');
    await _cancelPluginObligationNotifications();
  }

  Future<void> _cancelPluginObligationNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    final ids = obligationPendingNotificationIdsToCancel(pending);
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  Future<bool> _plansStillPending(Map<int, bool> expected) async {
    try {
      final notifications = {
        for (final p in await _plugin.pendingNotificationRequests()) p.id,
      };
      final alarms = await _alarms.pending();
      return expected.entries.every(
        (p) => (p.value ? alarms : notifications).contains(p.key),
      );
    } on PlatformException {
      // A recorded native failure must trigger reconciliation, not lock retries.
      return false;
    }
  }

  bool _acceptedAll(Set<int> accepted, List<Map<String, Object>> events) {
    final expected = {for (final event in events) event['id'] as int};
    final now = DateTime.now().millisecondsSinceEpoch;
    final future = {
      for (final event in events)
        if ((event['at'] as int) > now) event['id'] as int,
    };
    return expected.length == events.length &&
        expected.containsAll(accepted) &&
        accepted.containsAll(future);
  }
}

String? notificationRouteFromPayload(String? payload) {
  return picoRouteFromNotificationPayload(payload) ??
      obligationRouteFromPayload(payload);
}

String? picoRouteFromNotificationPayload(String? payload) {
  if (payload == PicoNotificationScheduler.picoPayload) {
    return payload;
  }
  if (payload == null) {
    return null;
  }
  final uri = Uri.tryParse(payload);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasFragment ||
      uri.path != '/pico') {
    return null;
  }
  final Map<String, List<String>> query;
  try {
    query = uri.queryParametersAll;
  } on FormatException {
    return null;
  }
  final ids = query['vehicleId'];
  if (query.length != 1 ||
      ids == null ||
      ids.length != 1 ||
      ids.single.trim().isEmpty ||
      ids.single.length > 200 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(ids.single)) {
    return null;
  }
  return uri.toString();
}

String picoVehicleNotificationPayload(String vehicleId) =>
    Uri(path: '/pico', queryParameters: {'vehicleId': vehicleId}).toString();

List<int> picoPendingNotificationIdsToCancel(
  Iterable<PendingNotificationRequest> pending,
) {
  return pending
      .where(
        (request) => picoRouteFromNotificationPayload(request.payload) != null,
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
  List<VehicleAlertSettings> deliverySettings = const [],
  // Scheduler-only: these past identities may retain native state, never replay it.
  bool retainRecentAlarms = false,
}) async {
  final days = <PicoVehicleRestrictionDay>[];
  for (final vehicle in vehicles) {
    final ruleSet = await store.loadCoverage(
      jurisdiction.id,
      vehicle.kind,
      vehicle.serviceType,
      currentInstant,
    );
    final retain =
        retainRecentAlarms &&
        deliverySettings.any(
          (s) =>
              s.vehicleId == vehicle.id &&
              s.category == AlertCategory.pico &&
              s.settings.alarm,
        );
    for (var offset = retain ? -1 : 0; offset < 14; offset += 1) {
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
  final result = <PicoNotificationPlan>[];
  for (final vehicle in vehicles) {
    final selected = deliverySettings
        .where(
          (s) => s.vehicleId == vehicle.id && s.category == AlertCategory.pico,
        )
        .firstOrNull
        ?.settings;
    final plans = planPicoNotifications(
      days: days.where((d) => d.vehicle.id == vehicle.id),
      settings: PicoNotificationSettings(
        enabled: selected?.enabled ?? alertPreferences.enabled,
        dayBeforeEnabled:
            selected?.dayBefore ?? alertPreferences.dayBeforeEnabled,
        sameDayEnabled: selected?.sameDay ?? alertPreferences.sameDayEnabled,
        dayBeforeMinute:
            selected?.dayBeforeMinute ?? alertPreferences.dayBeforeMinute,
        sameDayMinute:
            selected?.sameDayMinute ?? alertPreferences.sameDayMinute,
      ),
      nowBogota: nowBogota,
      retainRecentAlarms: retainRecentAlarms && selected?.alarm == true,
    );
    result.addAll(
      plans.map(
        (p) => PicoNotificationPlan(
          id: p.id,
          type: p.type,
          vehicleId: p.vehicleId,
          targetDate: p.targetDate,
          scheduledAt: p.scheduledAt,
          title: p.title,
          body: p.body,
          payload: p.payload,
          delivery: selected,
          plate: vehicle.plate,
        ),
      ),
    );
  }
  return result;
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
        plan.delivery?.toJson(),
        plan.plate,
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
        plan.delivery?.toJson(),
        plan.plate,
      ],
  ]);
}

Map<String, Object> _alarmEvent(int id, DateTime time, String route) => {
  'id': id,
  'at': time.millisecondsSinceEpoch,
  'expiresAt': time.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
  'route': route,
};

void _addPlan(
  List<PicoNotificationPlan> plans,
  PicoVehicleRestrictionDay day,
  PicoAlertType type,
  DateTime scheduleDate,
  int minuteOfDay,
  DateTime nowBogota,
  bool retainRecentAlarms,
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
  if (!scheduledAt.isAfter(now) &&
      (!retainRecentAlarms ||
          !scheduledAt.add(const Duration(minutes: 15)).isAfter(now))) {
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
      payload: picoVehicleNotificationPayload(day.vehicle.id),
    ),
  );
}
