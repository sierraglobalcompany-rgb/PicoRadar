import '../../garage/data/vehicle_profile.dart';
import 'restriction_rule.dart';

enum RestrictionStatus { allowed, restricted, unknown, stale }

enum RestrictionReasonCode {
  restrictedByRule,
  allowedNoRestriction,
  allowedByOverride,
  unknownCoverage,
  unknownRequiredPlateDigit,
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

    var unknownDigitRequired = false;
    final applicableRules = <RestrictionRule>[];
    for (final rule in rules) {
      final match = _matchRule(context, rule);
      if (match == _RuleMatch.applies) {
        applicableRules.add(rule);
      } else if (match == _RuleMatch.unknownRequiredPlateDigit) {
        unknownDigitRequired = true;
      }
    }

    if (applicableRules.isEmpty) {
      if (unknownDigitRequired) {
        return const RestrictionEvaluation(
          status: RestrictionStatus.unknown,
          effectiveWindows: [],
          reasonCode: RestrictionReasonCode.unknownRequiredPlateDigit,
        );
      }
      return const RestrictionEvaluation(
        status: RestrictionStatus.allowed,
        effectiveWindows: [],
        reasonCode: RestrictionReasonCode.allowedNoRestriction,
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
    final origins = rule.registrationOrigins;
    if (origins != null &&
        origins.isNotEmpty &&
        !origins.contains(context.registrationOrigin)) {
      return _RuleMatch.no;
    }
    final weekdays = rule.weekdays;
    if (weekdays != null &&
        weekdays.isNotEmpty &&
        !weekdays.contains(context.localDateTime.weekday)) {
      return _RuleMatch.no;
    }
    final dateParity = rule.dateParity;
    if (dateParity != null && !_matchesDateParity(context, dateParity)) {
      return _RuleMatch.no;
    }
    if (rule.timeWindows.isNotEmpty &&
        !rule.timeWindows.any(
          (window) => window.contains(context.localDateTime),
        )) {
      return _RuleMatch.no;
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

  bool _matchesDateParity(
    RestrictionContext context,
    RestrictionDateParity dateParity,
  ) {
    final isEven = context.localDateTime.day.isEven;
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
}

enum _RuleMatch { no, applies, unknownRequiredPlateDigit }
