import '../../garage/data/vehicle_profile.dart';
import '../../pico_placa/data/restriction_store.dart';
import '../../pico_placa/domain/bogota_time.dart';
import '../../pico_placa/domain/colombia_holiday_calendar.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../pico_placa/domain/restriction_engine.dart';
import '../../pico_placa/domain/restriction_rule.dart';
import '../data/trip_municipality_catalog.dart';

class TripEndpointRestriction {
  const TripEndpointRestriction({
    required this.status,
    this.instantStatus,
    this.windows = const [],
    this.sourceUrl,
    this.verifiedAt,
    this.reason,
    this.evaluatedAtUtc,
    this.engineReason,
  });

  final RestrictionDayStatus status;
  final RestrictionStatus? instantStatus;
  final List<RestrictionDayWindow> windows;
  final String? sourceUrl;
  final DateTime? verifiedAt;
  final String? reason;
  final DateTime? evaluatedAtUtc;
  final RestrictionReasonCode? engineReason;
}

TripEndpointRestriction evaluateTripRestriction({
  required RestrictionRuleSet ruleSet,
  required TripMunicipality? municipality,
  required VehicleProfile? vehicle,
  required DateTime instantUtc,
  required DateTime nowUtc,
}) {
  final instant = instantUtc.toUtc();
  final jurisdictionId = municipality?.jurisdictionId;
  final inputReason = vehicle == null
      ? 'missing_vehicle'
      : municipality == null
      ? 'ambiguous_municipality'
      : jurisdictionId == null || jurisdictionId.isEmpty
      ? 'unmapped_jurisdiction'
      : null;
  if (inputReason != null || vehicle == null || jurisdictionId == null) {
    return TripEndpointRestriction(
      status: RestrictionDayStatus.unknown,
      instantStatus: RestrictionStatus.unknown,
      reason: inputReason,
      evaluatedAtUtc: instant,
    );
  }

  final local = bogotaWallClock(instant);
  final today = bogotaWallClock(nowUtc.toUtc());
  final day = DateTime(local.year, local.month, local.day);
  final isFutureDay = day.isAfter(DateTime(today.year, today.month, today.day));
  final rules = ruleSet.rules.where((rule) {
    return rule.jurisdictionId == jurisdictionId &&
        rule.vehicleKinds.contains(vehicle.kind) &&
        rule.serviceTypes.contains(vehicle.serviceType);
  }).toList(growable: false);
  final coverageSource = ruleSet.sourceUrls.firstOrNull ??
      rules.map((rule) => rule.sourceUrl).whereType<String>().firstOrNull;
  final coverageVerifiedAt = ruleSet.verifiedAt ??
      rules.map((rule) => rule.verifiedAt).whereType<DateTime>().firstOrNull;
  final staleAfter = ruleSet.staleAfter;
  final String? coverageReason;
  if (!ruleSet.coverageKnown) {
    coverageReason = 'no_coverage';
  } else if (ruleSet.dataIsStale ||
      (staleAfter != null && !nowUtc.toUtc().isBefore(staleAfter.toUtc()))) {
    coverageReason = 'stale_data';
  } else if (staleAfter != null &&
      !staleAfterCoversBogotaDate(staleAfter, day)) {
    coverageReason = isFutureDay ? 'future_coverage' : 'stale_data';
  } else if (ruleSet.rules.isNotEmpty && rules.isEmpty) {
    coverageReason = 'no_coverage';
  } else {
    coverageReason = null;
  }
  if (coverageReason != null) {
    final stale = coverageReason == 'stale_data';
    return TripEndpointRestriction(
      status: stale ? RestrictionDayStatus.stale : RestrictionDayStatus.unknown,
      instantStatus: stale ? RestrictionStatus.stale : RestrictionStatus.unknown,
      sourceUrl: coverageSource,
      verifiedAt: coverageVerifiedAt,
      reason: coverageReason,
      evaluatedAtUtc: instant,
      engineReason: stale
          ? RestrictionReasonCode.staleData
          : RestrictionReasonCode.unknownCoverage,
    );
  }

  const engine = RestrictionEngine();
  const holidays = ColombiaHolidayCalendar();
  RestrictionEvaluation at(DateTime wallClock) {
    return engine.evaluate(
      RestrictionContext(
        jurisdictionId: jurisdictionId,
        plate: vehicle.plate,
        vehicleKind: vehicle.kind,
        serviceType: vehicle.serviceType,
        registrationOrigin: RegistrationOrigin.unknown,
        localDateTime: wallClock,
        isHoliday: holidays.isHoliday(wallClock),
        coverageKnown: true,
        dataIsStale: false,
      ),
      rules,
    );
  }

  final dayEvaluation = evaluateRestrictionDay(
    ruleSet: ruleSet,
    jurisdictionId: jurisdictionId,
    plate: vehicle.plate,
    vehicleKind: vehicle.kind,
    serviceType: vehicle.serviceType,
    date: day,
  );
  final instantEvaluation = at(local);
  // Schedule, digit and holiday mismatches mean allowed only within validity.
  // An explicitly empty, known coverage is the dataset's no-restriction case.
  final validAtInstant = rules.isEmpty || rules.any((rule) {
    return !local.isBefore(rule.validFrom) &&
        (rule.validUntil == null || !local.isAfter(rule.validUntil!));
  });
  final gapReason = !validAtInstant
      ? isFutureDay
          ? 'future_coverage'
          : rules.every((rule) =>
                rule.validUntil != null && local.isAfter(rule.validUntil!))
          ? 'stale_data'
          : 'no_coverage'
      : null;
  final instantStatus = gapReason == 'stale_data'
      ? RestrictionStatus.stale
      : gapReason != null
      ? RestrictionStatus.unknown
      : instantEvaluation.status;
  final reason = gapReason ?? switch (instantStatus) {
    RestrictionStatus.unknown => 'no_coverage',
    RestrictionStatus.stale => 'stale_data',
    _ => dayEvaluation.status == RestrictionDayStatus.unknown
        ? 'no_coverage'
        : null,
  };
  final status = gapReason != null &&
          dayEvaluation.status != RestrictionDayStatus.restricted
      ? gapReason == 'stale_data'
          ? RestrictionDayStatus.stale
          : RestrictionDayStatus.unknown
      : dayEvaluation.status;

  // The day evaluator may retain coverage metadata from its first interval.
  // Resolve a known restricted interval through the same engine for provenance.
  final firstWindow = dayEvaluation.effectiveWindows.firstOrNull;
  final dayRule = firstWindow == null
      ? null
      : at(bogotaWallClock(bogotaScheduledTime(
          date: day,
          minuteOfDay: firstWindow.startMinute,
        )));
  final source = instantEvaluation.sourceUrl ??
      dayRule?.sourceUrl ?? dayEvaluation.sourceUrl ?? coverageSource;
  final verifiedAt = instantEvaluation.verifiedAt ??
      dayRule?.verifiedAt ?? dayEvaluation.verifiedAt ?? coverageVerifiedAt;
  return TripEndpointRestriction(
    status: status,
    instantStatus: instantStatus,
    windows: List.unmodifiable(dayEvaluation.effectiveWindows),
    sourceUrl: source,
    verifiedAt: verifiedAt,
    reason: reason,
    evaluatedAtUtc: instant,
    engineReason: gapReason == 'stale_data'
        ? RestrictionReasonCode.staleData
        : gapReason != null
        ? RestrictionReasonCode.unknownCoverage
        : instantEvaluation.reasonCode,
  );
}
