import '../../garage/data/vehicle_profile.dart';
import 'restriction_rule.dart';

enum RestrictionStatus { allowed, restricted, unknown, stale }

enum RestrictionReasonCode {
  restrictedByRule,
  allowedNoRestriction,
  allowedByOverride,
  unknownCoverage,
  unknownRequiredPlateDigit,
  unknownRegistrationOrigin,
  unknownCondition,
  partialCoverage,
  conflictingRules,
  staleData,
}

class SpatialEvidence {
  const SpatialEvidence({
    required this.scopeId,
    required this.scopeVersion,
    required this.membership,
    required this.provenance,
  });

  final String scopeId;
  final String scopeVersion;
  final SpatialMembership membership;
  final SpatialEvidenceProvenance provenance;
}

class RestrictionFacts {
  const RestrictionFacts({
    this.pillionPresent,
    this.occupantsCount,
    this.grossVehicleWeightKg,
    this.axleCount,
    this.spatialEvidence,
  });

  final bool? pillionPresent;
  final int? occupantsCount;
  final int? grossVehicleWeightKg;
  final int? axleCount;
  final SpatialEvidence? spatialEvidence;
}

class RestrictionContext {
  const RestrictionContext({
    required this.jurisdictionId,
    required this.plate,
    required this.vehicleKind,
    required this.serviceType,
    required this.registrationOrigin,
    required this.localDateTime,
    required this.isHoliday,
    required this.coverageKnown,
    required this.dataIsStale,
    this.coverageCompleteness = CoverageCompleteness.legacy,
    this.consultationEnabled = true,
    this.jurisdictionConsultationEnabled = true,
    this.facts,
    this.isHolidayOnDate,
  });

  final String jurisdictionId;
  final String plate;
  final VehicleKind vehicleKind;
  final VehicleServiceType serviceType;
  final RegistrationOrigin registrationOrigin;
  final DateTime localDateTime;
  final bool isHoliday;
  final bool coverageKnown;
  final bool dataIsStale;
  final CoverageCompleteness coverageCompleteness;
  final bool consultationEnabled;
  final bool jurisdictionConsultationEnabled;
  final RestrictionFacts? facts;
  final bool Function(DateTime date)? isHolidayOnDate;
}

class RestrictionEvaluation {
  const RestrictionEvaluation({
    required this.status,
    required this.effectiveWindows,
    required this.reasonCode,
    this.matchedRuleId,
    this.sourceUrl,
    this.verifiedAt,
  });

  final RestrictionStatus status;
  final String? matchedRuleId;
  final List<RestrictionTimeWindow> effectiveWindows;
  final RestrictionReasonCode reasonCode;
  final String? sourceUrl;
  final DateTime? verifiedAt;
}

class RestrictionEngine {
  const RestrictionEngine();

  RestrictionEvaluation evaluate(
    RestrictionContext context,
    Iterable<RestrictionRule> rules,
  ) {
    if (!context.coverageKnown) {
      return const RestrictionEvaluation(
        status: RestrictionStatus.unknown,
        effectiveWindows: [],
        reasonCode: RestrictionReasonCode.unknownCoverage,
      );
    }
    if (!context.consultationEnabled ||
        !context.jurisdictionConsultationEnabled) {
      return const RestrictionEvaluation(
        status: RestrictionStatus.unknown,
        effectiveWindows: [],
        reasonCode: RestrictionReasonCode.unknownCoverage,
      );
    }
    if (context.dataIsStale) {
      return const RestrictionEvaluation(
        status: RestrictionStatus.stale,
        effectiveWindows: [],
        reasonCode: RestrictionReasonCode.staleData,
      );
    }

    final applicableRules = <RestrictionRule>[];
    final uncertainRules = <_UncertainRule>[];
    for (final rule in rules) {
      final match = _matchRule(context, rule);
      if (match == _RuleMatch.applies) {
        applicableRules.add(rule);
      } else if (match == _RuleMatch.unknownRequiredPlateDigit) {
        uncertainRules.add((
          rule: rule,
          reasonCode: RestrictionReasonCode.unknownRequiredPlateDigit,
        ));
      } else if (match == _RuleMatch.unknownRegistrationOrigin) {
        uncertainRules.add((
          rule: rule,
          reasonCode: RestrictionReasonCode.unknownRegistrationOrigin,
        ));
      } else if (match == _RuleMatch.unknownCondition) {
        uncertainRules.add((
          rule: rule,
          reasonCode: RestrictionReasonCode.unknownCondition,
        ));
      }
    }

    if (applicableRules.isEmpty) {
      if (uncertainRules.isNotEmpty) {
        uncertainRules.sort(
          (a, b) => b.rule.priority.compareTo(a.rule.priority),
        );
        return RestrictionEvaluation(
          status: RestrictionStatus.unknown,
          effectiveWindows: _windowsFor(
            _uncertainAtPriority(
              uncertainRules,
              uncertainRules.first.rule.priority,
            ).map((match) => match.rule).toList(growable: false),
          ),
          reasonCode: uncertainRules.first.reasonCode,
        );
      }
      if (context.coverageCompleteness == CoverageCompleteness.partial) {
        return const RestrictionEvaluation(
          status: RestrictionStatus.unknown,
          effectiveWindows: [],
          reasonCode: RestrictionReasonCode.partialCoverage,
        );
      }
      if (rules.isEmpty &&
          context.coverageCompleteness != CoverageCompleteness.complete) {
        return const RestrictionEvaluation(
          status: RestrictionStatus.unknown,
          effectiveWindows: [],
          reasonCode: RestrictionReasonCode.unknownCoverage,
        );
      }
      return const RestrictionEvaluation(
        status: RestrictionStatus.allowed,
        effectiveWindows: [],
        reasonCode: RestrictionReasonCode.allowedNoRestriction,
      );
    }

    final knownMaxPriority = applicableRules
        .map((rule) => rule.priority)
        .reduce((a, b) => a > b ? a : b);
    final uncertainMaxPriority = uncertainRules.isEmpty
        ? null
        : uncertainRules
              .map((match) => match.rule.priority)
              .reduce((a, b) => a > b ? a : b);
    if (uncertainMaxPriority != null &&
        uncertainMaxPriority >= knownMaxPriority) {
      final topUncertain = _uncertainAtPriority(
        uncertainRules,
        uncertainMaxPriority,
      );
      return RestrictionEvaluation(
        status: RestrictionStatus.unknown,
        effectiveWindows: _windowsFor(
          topUncertain.map((match) => match.rule).toList(growable: false),
        ),
        reasonCode: topUncertain.first.reasonCode,
      );
    }

    applicableRules.sort((a, b) => b.priority.compareTo(a.priority));
    final topPriority = applicableRules.first.priority;
    final topRules = applicableRules
        .where((rule) => rule.priority == topPriority)
        .toList(growable: false);
    final hasAllow = topRules.any(
      (rule) => rule.effect == RestrictionEffect.allow,
    );
    final hasRestrict = topRules.any(
      (rule) => rule.effect == RestrictionEffect.restrict,
    );

    if (hasAllow && hasRestrict) {
      return RestrictionEvaluation(
        status: RestrictionStatus.unknown,
        effectiveWindows: _windowsFor(topRules),
        reasonCode: RestrictionReasonCode.conflictingRules,
      );
    }

    final matchedRule = topRules.first;
    if (matchedRule.effect == RestrictionEffect.allow) {
      if (context.coverageCompleteness == CoverageCompleteness.partial) {
        return const RestrictionEvaluation(
          status: RestrictionStatus.unknown,
          effectiveWindows: [],
          reasonCode: RestrictionReasonCode.partialCoverage,
        );
      }
      return _fromRule(
        matchedRule,
        status: RestrictionStatus.allowed,
        reasonCode: RestrictionReasonCode.allowedByOverride,
      );
    }
    return _fromRule(
      matchedRule,
      status: RestrictionStatus.restricted,
      reasonCode: RestrictionReasonCode.restrictedByRule,
    );
  }

  _RuleMatch _matchRule(RestrictionContext context, RestrictionRule rule) {
    if (rule.jurisdictionId != context.jurisdictionId) {
      return _RuleMatch.no;
    }
    if (!rule.vehicleKinds.contains(context.vehicleKind)) {
      return _RuleMatch.no;
    }
    if (!rule.serviceTypes.contains(context.serviceType)) {
      return _RuleMatch.no;
    }
    final scheduleMatch = _matchesScheduleDate(context, rule);
    if (scheduleMatch != _RuleMatch.applies) {
      return scheduleMatch;
    }
    final origins = rule.registrationOrigins;
    if (origins != null && origins.isNotEmpty) {
      if (context.registrationOrigin == RegistrationOrigin.unknown) {
        final originDoesNotChangeRule =
            origins.contains(RegistrationOrigin.local) &&
            origins.contains(RegistrationOrigin.foreign);
        if (!originDoesNotChangeRule &&
            !origins.contains(RegistrationOrigin.unknown)) {
          return _RuleMatch.unknownRegistrationOrigin;
        }
      } else if (!origins.contains(context.registrationOrigin)) {
        return _RuleMatch.no;
      }
    }

    final digits = rule.digits;
    if (digits == null || digits.isEmpty) {
      return _matchConditions(context, rule);
    }
    final digit = _plateDigit(context.plate, rule.digitPosition);
    if (digit == null) {
      return _RuleMatch.unknownRequiredPlateDigit;
    }
    return digits.contains(digit)
        ? _matchConditions(context, rule)
        : _RuleMatch.no;
  }

  _RuleMatch _matchConditions(
    RestrictionContext context,
    RestrictionRule rule,
  ) {
    final types = <Type>{};
    for (final condition in rule.conditions) {
      if (!types.add(condition.runtimeType) || !_validCondition(condition)) {
        return _RuleMatch.unknownCondition;
      }
    }
    final atLeast = rule.conditions
        .whereType<OccupantsAtLeastCondition>()
        .toList();
    final below = rule.conditions.whereType<OccupantsBelowCondition>().toList();
    if (atLeast.length > 1 ||
        below.length > 1 ||
        (atLeast.isNotEmpty &&
            below.isNotEmpty &&
            atLeast.single.value >= below.single.value)) {
      return _RuleMatch.unknownCondition;
    }
    var hasUnknown = false;
    for (final condition in rule.conditions) {
      final match = _matchCondition(context.facts, condition);
      if (match == _RuleMatch.no) return _RuleMatch.no;
      if (match == _RuleMatch.unknownCondition) hasUnknown = true;
    }
    return hasUnknown ? _RuleMatch.unknownCondition : _RuleMatch.applies;
  }

  bool _validCondition(RestrictionCondition condition) => switch (condition) {
    PillionPresentCondition() => true,
    OccupantsAtLeastCondition(:final value) ||
    OccupantsBelowCondition(:final value) => value >= 1 && value <= 99,
    GrossWeightKgGreaterThanCondition(:final value) =>
      value >= 0 && value <= 100000,
    AxlesAtLeastCondition(:final value) => value >= 1 && value <= 20,
    InsideScopeRefCondition(:final value) => _validScopeReference(value),
  };

  bool _validScopeReference(String value) {
    final separator = value.lastIndexOf('@');
    return separator > 0 &&
        separator < value.length - 1 &&
        !value.substring(0, separator).contains('@');
  }

  _RuleMatch _matchCondition(
    RestrictionFacts? facts,
    RestrictionCondition condition,
  ) {
    return switch (condition) {
      PillionPresentCondition(:final value) =>
        facts?.pillionPresent == null
            ? _RuleMatch.unknownCondition
            : (facts!.pillionPresent == value
                  ? _RuleMatch.applies
                  : _RuleMatch.no),
      OccupantsAtLeastCondition(:final value) => _compareFact(
        facts?.occupantsCount,
        min: 1,
        max: 99,
        predicate: (fact) => fact >= value,
      ),
      OccupantsBelowCondition(:final value) => _compareFact(
        facts?.occupantsCount,
        min: 1,
        max: 99,
        predicate: (fact) => fact < value,
      ),
      GrossWeightKgGreaterThanCondition(:final value) => _compareFact(
        facts?.grossVehicleWeightKg,
        min: 0,
        max: 100000,
        predicate: (fact) => fact > value,
      ),
      AxlesAtLeastCondition(:final value) => _compareFact(
        facts?.axleCount,
        min: 1,
        max: 20,
        predicate: (fact) => fact >= value,
      ),
      InsideScopeRefCondition(:final value) => _matchScope(facts, value),
    };
  }

  _RuleMatch _compareFact(
    int? fact, {
    required int min,
    required int max,
    required bool Function(int) predicate,
  }) {
    if (fact == null || fact < min || fact > max) {
      return _RuleMatch.unknownCondition;
    }
    return predicate(fact) ? _RuleMatch.applies : _RuleMatch.no;
  }

  _RuleMatch _matchScope(RestrictionFacts? facts, String reference) {
    final separator = reference.lastIndexOf('@');
    if (separator <= 0 || separator == reference.length - 1) {
      return _RuleMatch.unknownCondition;
    }
    final scopeId = reference.substring(0, separator);
    final version = reference.substring(separator + 1);
    if (scopeId.contains('@')) return _RuleMatch.unknownCondition;
    final evidence = facts?.spatialEvidence;
    if (evidence == null ||
        evidence.scopeId != scopeId ||
        evidence.scopeVersion != version ||
        evidence.provenance == SpatialEvidenceProvenance.untrusted) {
      return _RuleMatch.unknownCondition;
    }
    return switch (evidence.membership) {
      SpatialMembership.inside => _RuleMatch.applies,
      SpatialMembership.outside => _RuleMatch.no,
      SpatialMembership.unknown => _RuleMatch.unknownCondition,
    };
  }

  _RuleMatch _matchesScheduleDate(
    RestrictionContext context,
    RestrictionRule rule,
  ) {
    if (rule.timeWindows.isEmpty) {
      return _matchesRegularSchedule(context, rule, context.localDateTime);
    }
    var hasUnknownAnchor = false;
    for (final window in rule.timeWindows) {
      if (!window.contains(context.localDateTime)) {
        continue;
      }
      final match = window.fullDay
          ? _matchesFullDayWindow(context, rule, window)
          : _matchesRegularWindow(context, rule, window);
      if (match == _RuleMatch.applies) {
        return _RuleMatch.applies;
      }
      if (match == _RuleMatch.unknownCondition) hasUnknownAnchor = true;
    }
    return hasUnknownAnchor ? _RuleMatch.unknownCondition : _RuleMatch.no;
  }

  _RuleMatch _matchesRegularSchedule(
    RestrictionContext context,
    RestrictionRule rule,
    DateTime effectiveDateTime,
  ) {
    if (context.localDateTime.isBefore(rule.validFrom)) {
      return _RuleMatch.no;
    }
    final validUntil = rule.validUntil;
    if (validUntil != null && context.localDateTime.isAfter(validUntil)) {
      return _RuleMatch.no;
    }
    if (context.isHoliday && !rule.appliesOnHolidays) {
      return _RuleMatch.no;
    }
    return _matchesDateFilters(effectiveDateTime, rule)
        ? _RuleMatch.applies
        : _RuleMatch.no;
  }

  _RuleMatch _matchesRegularWindow(
    RestrictionContext context,
    RestrictionRule rule,
    RestrictionTimeWindow window,
  ) => _matchesRegularSchedule(
    context,
    rule,
    _effectiveDateTimeForWindow(context.localDateTime, window),
  );

  _RuleMatch _matchesFullDayWindow(
    RestrictionContext context,
    RestrictionRule rule,
    RestrictionTimeWindow window,
  ) {
    final anchorStart = window.anchorStart(context.localDateTime);
    if (anchorStart.isBefore(rule.validFrom) ||
        (rule.validUntil != null && anchorStart.isAfter(rule.validUntil!)) ||
        !_matchesDateFilters(anchorStart, rule)) {
      return _RuleMatch.no;
    }
    if (rule.appliesOnHolidays) return _RuleMatch.applies;

    final queryDay = context.localDateTime;
    final anchorDay = DateTime(
      anchorStart.year,
      anchorStart.month,
      anchorStart.day,
    );
    final queryCalendarDay = DateTime(
      queryDay.year,
      queryDay.month,
      queryDay.day,
    );
    final bool? isAnchorHoliday = anchorDay == queryCalendarDay
        ? context.isHoliday
        : context.isHolidayOnDate?.call(anchorDay);
    if (isAnchorHoliday == null) return _RuleMatch.unknownCondition;
    return isAnchorHoliday ? _RuleMatch.no : _RuleMatch.applies;
  }

  DateTime _effectiveDateTimeForWindow(
    DateTime localDateTime,
    RestrictionTimeWindow window,
  ) {
    final minute = (localDateTime.hour * 60) + localDateTime.minute;
    final isAfterMidnightTail =
        window.startMinute > window.endMinute && minute < window.endMinute;
    if (!isAfterMidnightTail) {
      return localDateTime;
    }
    return localDateTime.subtract(const Duration(days: 1));
  }

  bool _matchesDateFilters(DateTime effectiveDateTime, RestrictionRule rule) {
    final weekdays = rule.weekdays;
    if (weekdays != null &&
        weekdays.isNotEmpty &&
        !weekdays.contains(effectiveDateTime.weekday)) {
      return false;
    }
    final dateParity = rule.dateParity;
    if (dateParity == null) {
      return true;
    }
    final isEven = effectiveDateTime.day.isEven;
    return switch (dateParity) {
      RestrictionDateParity.even => isEven,
      RestrictionDateParity.odd => !isEven,
    };
  }

  int? _plateDigit(String plate, RestrictionDigitPosition? position) {
    final digits = RegExp(r'\d')
        .allMatches(plate)
        .map((match) {
          return int.parse(match.group(0)!);
        })
        .toList(growable: false);
    if (digits.isEmpty || position == null) {
      return null;
    }
    return switch (position) {
      RestrictionDigitPosition.firstNumeric => digits.first,
      RestrictionDigitPosition.lastNumeric => digits.last,
    };
  }

  RestrictionEvaluation _fromRule(
    RestrictionRule rule, {
    required RestrictionStatus status,
    required RestrictionReasonCode reasonCode,
  }) {
    return RestrictionEvaluation(
      status: status,
      matchedRuleId: rule.id,
      effectiveWindows: List.unmodifiable(rule.timeWindows),
      reasonCode: reasonCode,
      sourceUrl: rule.sourceUrl,
      verifiedAt: rule.verifiedAt,
    );
  }

  List<RestrictionTimeWindow> _windowsFor(List<RestrictionRule> rules) {
    return List.unmodifiable(
      rules.expand((rule) => rule.timeWindows).toList(growable: false),
    );
  }

  List<_UncertainRule> _uncertainAtPriority(
    List<_UncertainRule> rules,
    int priority,
  ) {
    return rules
        .where((match) => match.rule.priority == priority)
        .toList(growable: false);
  }
}

typedef _UncertainRule = ({
  RestrictionRule rule,
  RestrictionReasonCode reasonCode,
});

enum _RuleMatch {
  no,
  applies,
  unknownRequiredPlateDigit,
  unknownRegistrationOrigin,
  unknownCondition,
}
