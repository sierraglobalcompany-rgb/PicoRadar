import '../../garage/data/vehicle_profile.dart';

enum RegistrationOrigin { local, foreign, unknown }

enum RestrictionEffect { restrict, allow }

enum RestrictionDateParity { odd, even }

enum RestrictionDigitPosition { firstNumeric, lastNumeric }

class RestrictionTimeWindow {
  const RestrictionTimeWindow({
    required this.startMinute,
    required this.endMinute,
  }) : assert(startMinute >= 0 && startMinute < 1440),
       assert(endMinute >= 0 && endMinute < 1440),
       assert(startMinute != endMinute);

  final int startMinute;
  final int endMinute;

  bool contains(DateTime localDateTime) {
    final minute = (localDateTime.hour * 60) + localDateTime.minute;
    if (startMinute < endMinute) {
      return minute >= startMinute && minute < endMinute;
    }
    return minute >= startMinute || minute < endMinute;
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
  final List<RestrictionTimeWindow> timeWindows;
  final bool appliesOnHolidays;
  final String? sourceUrl;
  final DateTime? verifiedAt;
}
