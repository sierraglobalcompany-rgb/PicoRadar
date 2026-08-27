import '../../garage/data/vehicle_profile.dart';
import '../data/restriction_store.dart';
import 'colombia_holiday_calendar.dart';
import 'bogota_time.dart';
import 'restriction_engine.dart';
import 'restriction_rule.dart';

enum RestrictionDayStatus { allowed, restricted, unknown, stale }

class RestrictionDayEvaluation {
  const RestrictionDayEvaluation({
    required this.status,
    required this.effectiveWindows,
    this.sourceUrl,
    this.verifiedAt,
  });

  final RestrictionDayStatus status;
  final List<RestrictionDayWindow> effectiveWindows;
  final String? sourceUrl;
  final DateTime? verifiedAt;
}

class RestrictionDayWindow {
  const RestrictionDayWindow({
    required this.startMinute,
    required this.endMinute,
  }) : assert(startMinute >= 0 && startMinute <= 1440),
       assert(endMinute >= 0 && endMinute <= 1440),
       assert(startMinute < endMinute);

  final int startMinute;
  final int endMinute;
}

RestrictionDayEvaluation evaluateRestrictionDay({
  RestrictionEngine engine = const RestrictionEngine(),
  ColombiaHolidayCalendar holidays = const ColombiaHolidayCalendar(),
  required RestrictionRuleSet ruleSet,
  required String jurisdictionId,
  required String plate,
  required VehicleKind vehicleKind,
  required VehicleServiceType serviceType,
  required DateTime date,
}) {
  if (!ruleSet.coverageKnown) {
    return const RestrictionDayEvaluation(
      status: RestrictionDayStatus.unknown,
      effectiveWindows: [],
    );
  }
  if (ruleSet.dataIsStale) {
    return const RestrictionDayEvaluation(
      status: RestrictionDayStatus.stale,
      effectiveWindows: [],
    );
  }

  final day = DateTime(date.year, date.month, date.day);
  final staleAfter = ruleSet.staleAfter;
  if (staleAfter != null && !staleAfterCoversBogotaDate(staleAfter, day)) {
    return RestrictionDayEvaluation(
      status: RestrictionDayStatus.stale,
      effectiveWindows: const [],
      sourceUrl: _firstOrNull(ruleSet.sourceUrls),
      verifiedAt: ruleSet.verifiedAt,
    );
  }

  final boundaries = <int>{0, 1440};
  for (final rule in ruleSet.rules) {
    if (rule.jurisdictionId != jurisdictionId ||
        !rule.vehicleKinds.contains(vehicleKind) ||
        !rule.serviceTypes.contains(serviceType)) {
      continue;
    }
    for (final window in rule.timeWindows) {
      boundaries.add(window.startMinute);
      boundaries.add(window.endMinute);
    }
  }
  final ordered = boundaries.toList()..sort();

  var sawUnknown = false;
  String? sourceUrl;
  DateTime? verifiedAt;
  final restrictedWindows = <RestrictionDayWindow>[];
  for (var index = 0; index < ordered.length - 1; index += 1) {
    final start = ordered[index];
    final end = ordered[index + 1];
    if (start == end) {
      continue;
    }
    final localDateTime = day.add(Duration(minutes: start));
    final evaluation = engine.evaluate(
      RestrictionContext(
        jurisdictionId: jurisdictionId,
        plate: plate,
        vehicleKind: vehicleKind,
        serviceType: serviceType,
        registrationOrigin: RegistrationOrigin.unknown,
        localDateTime: localDateTime,
        isHoliday: holidays.isHoliday(localDateTime),
        coverageKnown: ruleSet.coverageKnown,
        dataIsStale: ruleSet.dataIsStale,
      ),
      ruleSet.rules,
    );
    sourceUrl ??= evaluation.sourceUrl ?? _firstOrNull(ruleSet.sourceUrls);
    verifiedAt ??= evaluation.verifiedAt ?? ruleSet.verifiedAt;
    if (evaluation.status == RestrictionStatus.unknown) {
      sawUnknown = true;
    } else if (evaluation.status == RestrictionStatus.restricted) {
      _addWindow(restrictedWindows, start, end);
    }
  }

  if (restrictedWindows.isNotEmpty) {
    return RestrictionDayEvaluation(
      status: RestrictionDayStatus.restricted,
      effectiveWindows: restrictedWindows,
      sourceUrl: sourceUrl,
      verifiedAt: verifiedAt,
    );
  }
  if (sawUnknown) {
    return RestrictionDayEvaluation(
      status: RestrictionDayStatus.unknown,
      effectiveWindows: [],
      sourceUrl: sourceUrl,
      verifiedAt: verifiedAt,
    );
  }
  return RestrictionDayEvaluation(
    status: RestrictionDayStatus.allowed,
    effectiveWindows: [],
    sourceUrl: sourceUrl,
    verifiedAt: verifiedAt,
  );
}

void _addWindow(
  List<RestrictionDayWindow> windows,
  int startMinute,
  int endMinute,
) {
  if (windows.isNotEmpty && windows.last.endMinute == startMinute) {
    final last = windows.removeLast();
    windows.add(
      RestrictionDayWindow(startMinute: last.startMinute, endMinute: endMinute),
    );
    return;
  }
  windows.add(
    RestrictionDayWindow(startMinute: startMinute, endMinute: endMinute),
  );
}

T? _firstOrNull<T>(List<T> items) => items.isEmpty ? null : items.first;
