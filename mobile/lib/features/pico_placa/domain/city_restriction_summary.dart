import '../../garage/data/vehicle_profile.dart';
import '../data/restriction_store.dart';
import 'colombia_holiday_calendar.dart';
import 'restriction_day_evaluation.dart';
import 'restriction_rule.dart';

enum PicoVehicleCategory {
  cars('Carros', VehicleKind.car, VehicleServiceType.private),
  motorcycles('Motos', VehicleKind.motorcycle, VehicleServiceType.private),
  taxis('Taxis', VehicleKind.car, VehicleServiceType.taxi);

  const PicoVehicleCategory(this.label, this.kind, this.serviceType);

  final String label;
  final VehicleKind kind;
  final VehicleServiceType serviceType;
}

class CityRestrictionDaySummary {
  const CityRestrictionDaySummary({
    required this.date,
    required this.status,
    required this.ruleLabel,
    required this.effectiveWindows,
    required this.coverageKnown,
    required this.dataIsStale,
    this.sourceUrl,
    this.verifiedAt,
  });

  final DateTime date;
  final RestrictionDayStatus status;
  final String ruleLabel;
  final List<RestrictionDayWindow> effectiveWindows;
  final bool coverageKnown;
  final bool dataIsStale;
  final String? sourceUrl;
  final DateTime? verifiedAt;
}

CityRestrictionDaySummary summarizeCityRestrictionDay({
  ColombiaHolidayCalendar holidays = const ColombiaHolidayCalendar(),
  required RestrictionRuleSet ruleSet,
  required String jurisdictionId,
  required PicoVehicleCategory category,
  required DateTime date,
}) {
  if (!ruleSet.coverageKnown) {
    return CityRestrictionDaySummary(
      date: _day(date),
      status: RestrictionDayStatus.unknown,
      ruleLabel: 'Sin cobertura verificada',
      effectiveWindows: const [],
      coverageKnown: false,
      dataIsStale: false,
      sourceUrl: _httpsSource(ruleSet),
      verifiedAt: ruleSet.verifiedAt,
    );
  }
  if (ruleSet.dataIsStale) {
    return CityRestrictionDaySummary(
      date: _day(date),
      status: RestrictionDayStatus.stale,
      ruleLabel: 'Datos por actualizar',
      effectiveWindows: const [],
      coverageKnown: true,
      dataIsStale: true,
      sourceUrl: _httpsSource(ruleSet),
      verifiedAt: ruleSet.verifiedAt,
    );
  }

  final matching = ruleSet.rules
      .where((rule) {
        return _ruleMatchesDay(
          rule,
          jurisdictionId: jurisdictionId,
          category: category,
          date: date,
          isHoliday: holidays.isHoliday(date),
        );
      })
      .toList(growable: false);
  if (matching.isEmpty) {
    return CityRestrictionDaySummary(
      date: _day(date),
      status: RestrictionDayStatus.allowed,
      ruleLabel: holidays.isHoliday(date)
          ? 'Festivo sin restricción'
          : 'Sin restricción',
      effectiveWindows: const [],
      coverageKnown: true,
      dataIsStale: false,
      sourceUrl: _httpsSource(ruleSet),
      verifiedAt: ruleSet.verifiedAt,
    );
  }

  final topPriority = matching
      .map((rule) => rule.priority)
      .reduce((a, b) => a > b ? a : b);
  final topRules = matching
      .where((rule) => rule.priority == topPriority)
      .toList(growable: false);
  final restrictRules = topRules
      .where((rule) => rule.effect == RestrictionEffect.restrict)
      .toList(growable: false);
  final hasAllow = topRules.any(
    (rule) => rule.effect == RestrictionEffect.allow,
  );
  if (restrictRules.isEmpty && hasAllow) {
    return CityRestrictionDaySummary(
      date: _day(date),
      status: RestrictionDayStatus.allowed,
      ruleLabel: 'Excepción vigente',
      effectiveWindows: const [],
      coverageKnown: true,
      dataIsStale: false,
      sourceUrl: _httpsSource(ruleSet),
      verifiedAt: ruleSet.verifiedAt,
    );
  }
  if (restrictRules.isNotEmpty && hasAllow) {
    return CityRestrictionDaySummary(
      date: _day(date),
      status: RestrictionDayStatus.unknown,
      ruleLabel: 'Reglas por confirmar',
      effectiveWindows: _windowsFrom(restrictRules),
      coverageKnown: true,
      dataIsStale: false,
      sourceUrl: _httpsSource(ruleSet),
      verifiedAt: ruleSet.verifiedAt,
    );
  }

  return CityRestrictionDaySummary(
    date: _day(date),
    status: RestrictionDayStatus.restricted,
    ruleLabel: _ruleLabel(restrictRules),
    effectiveWindows: _windowsFrom(restrictRules),
    coverageKnown: true,
    dataIsStale: false,
    sourceUrl: _httpsSource(ruleSet),
    verifiedAt: ruleSet.verifiedAt,
  );
}

String plateBasisLabel(RestrictionRuleSet ruleSet, VehicleProfile vehicle) {
  for (final rule in ruleSet.rules) {
    if (!rule.vehicleKinds.contains(vehicle.kind) ||
        !rule.serviceTypes.contains(vehicle.serviceType) ||
        rule.digits == null ||
        rule.digits!.isEmpty) {
      continue;
    }
    final digit = plateDigit(vehicle.plate, rule.digitPosition);
    if (digit == null) {
      continue;
    }
    return switch (rule.digitPosition) {
      RestrictionDigitPosition.firstNumeric => 'Primer número $digit',
      RestrictionDigitPosition.lastNumeric => 'Último dígito $digit',
      null => 'Consulta el calendario',
    };
  }
  return 'Consulta el calendario';
}

int? plateDigit(String plate, RestrictionDigitPosition? position) {
  final digits = RegExp(r'\d')
      .allMatches(plate)
      .map((match) => int.parse(match.group(0)!))
      .toList(growable: false);
  if (digits.isEmpty || position == null) {
    return null;
  }
  return switch (position) {
    RestrictionDigitPosition.firstNumeric => digits.first,
    RestrictionDigitPosition.lastNumeric => digits.last,
  };
}

bool _ruleMatchesDay(
  RestrictionRule rule, {
  required String jurisdictionId,
  required PicoVehicleCategory category,
  required DateTime date,
  required bool isHoliday,
}) {
  final day = _day(date);
  if (rule.jurisdictionId != jurisdictionId ||
      !rule.vehicleKinds.contains(category.kind) ||
      !rule.serviceTypes.contains(category.serviceType) ||
      day.isBefore(_day(rule.validFrom))) {
    return false;
  }
  final validUntil = rule.validUntil;
  if (validUntil != null && day.isAfter(_day(validUntil))) {
    return false;
  }
  if (isHoliday && !rule.appliesOnHolidays) {
    return false;
  }
  final weekdays = rule.weekdays;
  if (weekdays != null &&
      weekdays.isNotEmpty &&
      !weekdays.contains(day.weekday)) {
    return false;
  }
  final parity = rule.dateParity;
  if (parity == null) {
    return true;
  }
  return switch (parity) {
    RestrictionDateParity.even => day.day.isEven,
    RestrictionDateParity.odd => day.day.isOdd,
  };
}

String _ruleLabel(List<RestrictionRule> rules) {
  if (rules.isEmpty) {
    return 'Sin restricción';
  }
  final digits =
      rules.expand((rule) => rule.digits ?? const <int>{}).toSet().toList()
        ..sort();
  if (digits.isEmpty) {
    return 'Todas las placas';
  }
  final positions = rules
      .where((rule) => rule.digits != null && rule.digits!.isNotEmpty)
      .map((rule) => rule.digitPosition)
      .toSet();
  final prefix = positions.length == 1
      ? switch (positions.single) {
          RestrictionDigitPosition.firstNumeric => 'Primer número',
          RestrictionDigitPosition.lastNumeric => 'Último dígito',
          null => 'Dígitos',
        }
      : 'Dígitos';
  return '$prefix ${_joinDigits(digits)}';
}

String _joinDigits(List<int> digits) {
  if (digits.length == 1) {
    return digits.single.toString();
  }
  if (digits.length == 2) {
    return '${digits.first} y ${digits.last}';
  }
  return '${digits.take(digits.length - 1).join(', ')} y ${digits.last}';
}

List<RestrictionDayWindow> _windowsFrom(List<RestrictionRule> rules) {
  final windows =
      rules.expand((rule) => rule.timeWindows).toList(growable: false)
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  final merged = <RestrictionDayWindow>[];
  for (final window in windows) {
    if (merged.isNotEmpty && merged.last.endMinute >= window.startMinute) {
      final last = merged.removeLast();
      merged.add(
        RestrictionDayWindow(
          startMinute: last.startMinute,
          endMinute: last.endMinute > window.endMinute
              ? last.endMinute
              : window.endMinute,
        ),
      );
    } else {
      merged.add(
        RestrictionDayWindow(
          startMinute: window.startMinute,
          endMinute: window.endMinute,
        ),
      );
    }
  }
  return List.unmodifiable(merged);
}

String? _httpsSource(RestrictionRuleSet ruleSet) {
  for (final source in ruleSet.sourceUrls) {
    final uri = Uri.tryParse(source);
    if (uri != null && uri.scheme == 'https') {
      return source;
    }
  }
  return null;
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
