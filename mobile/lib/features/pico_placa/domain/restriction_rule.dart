import '../../garage/data/vehicle_profile.dart';

enum RegistrationOrigin { local, foreign, unknown }

enum RestrictionEffect { restrict, allow }

enum RestrictionDateParity { odd, even }

enum RestrictionDigitPosition { firstNumeric, lastNumeric }

enum CoverageCompleteness { legacy, complete, partial }

enum SpatialMembership { inside, outside, unknown }

enum SpatialEvidenceProvenance { certified, syntheticContext, untrusted }

sealed class RestrictionCondition {
  const RestrictionCondition();
}

final class PillionPresentCondition extends RestrictionCondition {
  const PillionPresentCondition(this.value);
  final bool value;
}

final class OccupantsAtLeastCondition extends RestrictionCondition {
  const OccupantsAtLeastCondition(this.value);
  final int value;
}

final class OccupantsBelowCondition extends RestrictionCondition {
  const OccupantsBelowCondition(this.value);
  final int value;
}

final class GrossWeightKgGreaterThanCondition extends RestrictionCondition {
  const GrossWeightKgGreaterThanCondition(this.value);
  final int value;
}

final class AxlesAtLeastCondition extends RestrictionCondition {
  const AxlesAtLeastCondition(this.value);
  final int value;
}

final class InsideScopeRefCondition extends RestrictionCondition {
  const InsideScopeRefCondition(this.value);
  final String value;
}

class RestrictionTimeWindow {
  const RestrictionTimeWindow({
    required this.startMinute,
    required this.endMinute,
    this.fullDay = false,
  }) : assert(startMinute >= 0 && startMinute < 1440),
       assert(endMinute >= 0 && endMinute < 1440),
       assert(fullDay ? startMinute == endMinute : startMinute != endMinute);

  final int startMinute;
  final int endMinute;
  final bool fullDay;

  bool contains(DateTime localDateTime) {
    if (fullDay) return true;
    final minute = (localDateTime.hour * 60) + localDateTime.minute;
    if (startMinute < endMinute) {
      return minute >= startMinute && minute < endMinute;
    }
    return minute >= startMinute || minute < endMinute;
  }

  DateTime anchorStart(DateTime localDateTime) {
    final day = DateTime(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
    );
    final minute = (localDateTime.hour * 60) + localDateTime.minute;
    final previousAnchor = fullDay
        ? minute < startMinute
        : startMinute > endMinute && minute < endMinute;
    final anchorDay = previousAnchor
        ? DateTime(day.year, day.month, day.day - 1)
        : day;
    return DateTime(
      anchorDay.year,
      anchorDay.month,
      anchorDay.day,
      startMinute ~/ 60,
      startMinute % 60,
    );
  }
}

class RestrictionRule {
  const RestrictionRule({
    required this.id,
    required this.jurisdictionId,
    required this.priority,
    required this.effect,
    required this.validFrom,
    required this.vehicleKinds,
    required this.serviceTypes,
    required this.timeWindows,
    required this.appliesOnHolidays,
    this.validUntil,
    this.registrationOrigins,
    this.weekdays,
    this.dateParity,
    this.digitPosition,
    this.digits,
    this.conditions = const [],
    this.sourceUrl,
    this.verifiedAt,
  });

  final String id;
  final String jurisdictionId;
  final int priority;
  final RestrictionEffect effect;
  final DateTime validFrom;
  final DateTime? validUntil;
  final Set<VehicleKind> vehicleKinds;
  final Set<VehicleServiceType> serviceTypes;
  final Set<RegistrationOrigin>? registrationOrigins;
  final Set<int>? weekdays;
  final RestrictionDateParity? dateParity;
  final RestrictionDigitPosition? digitPosition;
  final Set<int>? digits;
  final List<RestrictionCondition> conditions;
  final List<RestrictionTimeWindow> timeWindows;
  final bool appliesOnHolidays;
  final String? sourceUrl;
  final DateTime? verifiedAt;
}
