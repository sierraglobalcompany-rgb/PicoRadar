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
  conflictingRules,
  staleData,
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
    if (context.localDateTime.isBefore(rule.validFrom)) {
      return _RuleMatch.no;
    }
    final validUntil = rule.validUntil;
    if (validUntil != null && context.localDateTime.isAfter(validUntil)) {
      return _RuleMatch.no;
    }
    if (!rule.vehicleKinds.contains(context.vehicleKind)) {
      return _RuleMatch.no;
    }
    if (!rule.serviceTypes.contains(context.serviceType)) {
      return _RuleMatch.no;
    }
    if (context.isHoliday && !rule.appliesOnHolidays) {
      return _RuleMatch.no;
    }
    if (!_matchesScheduleDate(context, rule)) {
      return _RuleMatch.no;
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
      return _RuleMatch.applies;
    }
    final digit = _plateDigit(context.plate, rule.digitPosition);
    if (digit == null) {
      return _RuleMatch.unknownRequiredPlateDigit;
    }
    return digits.contains(digit) ? _RuleMatch.applies : _RuleMatch.no;
  }

  bool _matchesScheduleDate(RestrictionContext context, RestrictionRule rule) {
    if (rule.timeWindows.isEmpty) {
      return _matchesDateFilters(context.localDateTime, rule);
    }
    for (final window in rule.timeWindows) {
      if (!window.contains(context.localDateTime)) {
        continue;
      }
      final effectiveDateTime = _effectiveDateTimeForWindow(
        context.localDateTime,
        window,
      );
      if (_matchesDateFilters(effectiveDateTime, rule)) {
        return true;
      }
    }
    return false;
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
}
