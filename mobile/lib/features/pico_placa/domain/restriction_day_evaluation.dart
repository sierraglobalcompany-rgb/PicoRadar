import '../../garage/data/vehicle_profile.dart';
import '../data/restriction_store.dart';
import 'colombia_holiday_calendar.dart';
import 'bogota_time.dart';
import 'restriction_engine.dart';
import 'restriction_rule.dart';

enum RestrictionDayStatus { allowed, restricted, unknown, stale }

enum RestrictionDayPhase {
  unrestricted,
  before,
  active,
  between,
  finished,
  unknown,
  stale,
}

// Daily windows remain authoritative; the phase only describes this local minute.
RestrictionDayPhase restrictionPhaseAt(
  RestrictionDayEvaluation evaluation,
  DateTime now,
) {
  switch (evaluation.status) {
    case RestrictionDayStatus.unknown:
      final minute = now.hour * 60 + now.minute;
      return evaluation.effectiveWindows.any(
            (window) =>
                minute >= window.startMinute && minute < window.endMinute,
          )
          ? RestrictionDayPhase.active
          : RestrictionDayPhase.unknown;
    case RestrictionDayStatus.stale:
      return RestrictionDayPhase.stale;
    case RestrictionDayStatus.allowed:
      return RestrictionDayPhase.unrestricted;
    case RestrictionDayStatus.restricted:
      break;
  }
  final windows = evaluation.effectiveWindows;
  if (windows.isEmpty) return RestrictionDayPhase.unknown;
  final minute = now.hour * 60 + now.minute;
  if (windows.any((w) => minute >= w.startMinute && minute < w.endMinute)) {
    return RestrictionDayPhase.active;
  }
  final first = windows
      .map((w) => w.startMinute)
      .reduce((a, b) => a < b ? a : b);
  final last = windows.map((w) => w.endMinute).reduce((a, b) => a > b ? a : b);
  if (minute < first) return RestrictionDayPhase.before;
  if (minute >= last) return RestrictionDayPhase.finished;
  return RestrictionDayPhase.between;
}

int? nextRestrictionStartMinute(
  RestrictionDayEvaluation evaluation,
  DateTime now,
) {
  if (evaluation.status != RestrictionDayStatus.restricted) return null;
  final minute = now.hour * 60 + now.minute;
  int? next;
  for (final window in evaluation.effectiveWindows) {
    if (window.startMinute > minute &&
        (next == null || window.startMinute < next)) {
      next = window.startMinute;
    }
  }
  return next;
}

String formatRestrictionTime12(int minuteOfDay) {
  assert(minuteOfDay >= 0 && minuteOfDay <= 1440);
  final hour = (minuteOfDay ~/ 60) % 24;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$displayHour:$minute ${hour < 12 ? 'a. m.' : 'p. m.'}';
}

String formatRestrictionWindows12(List<RestrictionDayWindow> windows) => windows
    .map(
      (w) =>
          '${formatRestrictionTime12(w.startMinute)} – ${formatRestrictionTime12(w.endMinute)}',
    )
    .join('\n');

class RestrictionDayEvaluation {
  const RestrictionDayEvaluation({
    required this.status,
    required this.effectiveWindows,
    this.sourceUrl,
    this.verifiedAt,
    this.fullDayPeriods = const [],
    this.fullDayProjectionHold = false,
  });

  final RestrictionDayStatus status;
  final List<RestrictionDayWindow> effectiveWindows;
  final List<RestrictionDayFullDayPeriod> fullDayPeriods;
  final bool fullDayProjectionHold;
  final String? sourceUrl;
  final DateTime? verifiedAt;
}

class RestrictionDayFullDayPeriod {
  const RestrictionDayFullDayPeriod({required this.anchorStart});

  final DateTime anchorStart;
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
  RestrictionFacts? facts,
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

  if (ruleSet.coverageCompleteness == CoverageCompleteness.partial &&
      ruleSet.rules.isEmpty) {
    return const RestrictionDayEvaluation(
      status: RestrictionDayStatus.unknown,
      effectiveWindows: [],
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
      if (!window.fullDay) boundaries.add(window.endMinute);
    }
  }
  final ordered = boundaries.toList()..sort();

  var sawUnknown = false;
  String? sourceUrl;
  DateTime? verifiedAt;
  final restrictedWindows = <RestrictionDayWindow>[];
  final fullDayPeriods = <RestrictionDayFullDayPeriod>[];
  var fullDayProjectionHold = false;
  for (var index = 0; index < ordered.length - 1; index += 1) {
    final start = ordered[index];
    final end = ordered[index + 1];
    if (start == end) {
      continue;
    }
    final localDateTime = DateTime(
      day.year,
      day.month,
      day.day,
      start ~/ 60,
      start % 60,
    );
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
        coverageCompleteness: ruleSet.coverageCompleteness,
        facts: facts,
        isHolidayOnDate: holidays.isHoliday,
      ),
      ruleSet.rules,
    );
    sourceUrl ??= evaluation.sourceUrl ?? _firstOrNull(ruleSet.sourceUrls);
    verifiedAt ??= evaluation.verifiedAt ?? ruleSet.verifiedAt;
    if (evaluation.status == RestrictionStatus.unknown) {
      sawUnknown = true;
    } else if (evaluation.status == RestrictionStatus.restricted) {
      _addWindow(restrictedWindows, start, end);
      final matchedRule = evaluation.matchedRuleId == null
          ? null
          : _firstOrNull(
              ruleSet.rules
                  .where((rule) => rule.id == evaluation.matchedRuleId)
                  .toList(growable: false),
            );
      if (matchedRule != null &&
          matchedRule.timeWindows.any((window) => window.fullDay)) {
        if (!matchedRule.timeWindows.every((window) => window.fullDay)) {
          fullDayProjectionHold = true;
        } else {
          for (final window in matchedRule.timeWindows) {
            final anchorStart = window.anchorStart(localDateTime);
            if (!fullDayPeriods.any(
              (period) => period.anchorStart == anchorStart,
            )) {
              fullDayPeriods.add(
                RestrictionDayFullDayPeriod(anchorStart: anchorStart),
              );
            }
          }
        }
      }
    }
  }

  if (sawUnknown &&
      ruleSet.coverageCompleteness != CoverageCompleteness.legacy) {
    return RestrictionDayEvaluation(
      status: RestrictionDayStatus.unknown,
      effectiveWindows: restrictedWindows,
      sourceUrl: sourceUrl,
      verifiedAt: verifiedAt,
    );
  }
  if (restrictedWindows.isNotEmpty) {
    return RestrictionDayEvaluation(
      status: RestrictionDayStatus.restricted,
      effectiveWindows: restrictedWindows,
      sourceUrl: sourceUrl,
      verifiedAt: verifiedAt,
      fullDayPeriods: List.unmodifiable(fullDayPeriods),
      fullDayProjectionHold: fullDayProjectionHold,
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
