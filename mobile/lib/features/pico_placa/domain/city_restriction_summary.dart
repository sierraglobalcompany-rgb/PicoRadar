import '../../garage/data/vehicle_profile.dart';
import '../data/restriction_store.dart';
import 'bogota_time.dart';
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

enum CityRestrictionDigitBasis {
  firstNumeric('primer número'),
  lastNumeric('último dígito'),
  dateParity('paridad de fecha'),
  custom('regla especial'),
  varies('varía por regla'),
  none('sin base publicada');

  const CityRestrictionDigitBasis(this.label);

  final String label;
}

class CityRestrictionDaySummary {
  const CityRestrictionDaySummary({
    required this.date,
    required this.status,
    required this.ruleLabel,
    required this.effectiveWindows,
    required this.coverageKnown,
    required this.dataIsStale,
    this.restrictedDigits = const [],
    this.digitBasis = CityRestrictionDigitBasis.none,
    this.sourceUrl,
    this.verifiedAt,
  });

  final DateTime date;
  final RestrictionDayStatus status;
  final String ruleLabel;
  final List<RestrictionDayWindow> effectiveWindows;
  final bool coverageKnown;
  final bool dataIsStale;
  final List<int> restrictedDigits;
  final CityRestrictionDigitBasis digitBasis;
  final String? sourceUrl;
  final DateTime? verifiedAt;
}

class CityRestrictionRuleSummary {
  const CityRestrictionRuleSummary({
    required this.category,
    required this.digitBasis,
    required this.generalWindows,
    required this.validFrom,
    required this.validUntil,
    required this.hasUniformSchedule,
    required this.coverageKnown,
    required this.dataIsStale,
  });

  final PicoVehicleCategory category;
  final CityRestrictionDigitBasis digitBasis;
  final List<RestrictionDayWindow> generalWindows;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool hasUniformSchedule;
  final bool coverageKnown;
  final bool dataIsStale;
}

class CityRestrictionRotationSummary {
  const CityRestrictionRotationSummary({
    required this.title,
    required this.isWeekly,
    required this.rows,
  });

  final String title;
  final bool isWeekly;
  final List<CityRestrictionRotationRow> rows;
}

class CityRestrictionRotationRow {
  const CityRestrictionRotationRow({
    required this.label,
    required this.status,
    required this.digits,
    required this.windows,
    this.date,
  });

  final String label;
  final RestrictionDayStatus status;
  final List<int> digits;
  final List<RestrictionDayWindow> windows;
  final DateTime? date;
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
  if (_coverageStaleOnDay(ruleSet, date)) {
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
    restrictedDigits: _digitsFrom(restrictRules),
    digitBasis: _digitBasisFrom(restrictRules),
    coverageKnown: true,
    dataIsStale: false,
    sourceUrl: _httpsSource(ruleSet),
    verifiedAt: ruleSet.verifiedAt,
  );
}

CityRestrictionRuleSummary summarizeCityRestrictionRules({
  required RestrictionRuleSet ruleSet,
  required String jurisdictionId,
  required PicoVehicleCategory category,
  required DateTime date,
}) {
  final rules = _currentRestrictRules(
    ruleSet,
    jurisdictionId: jurisdictionId,
    category: category,
    date: date,
  );
  return CityRestrictionRuleSummary(
    category: category,
    digitBasis: _digitBasisFrom(rules),
    generalWindows: _windowsFrom(rules),
    validFrom: _minValidFrom(rules),
    validUntil: _maxValidUntil(rules),
    hasUniformSchedule: _hasUniformWeeklySchedule(rules),
    coverageKnown: ruleSet.coverageKnown,
    dataIsStale: _coverageStaleOnDay(ruleSet, date),
  );
}

CityRestrictionRotationSummary summarizeCityRestrictionRotation({
  ColombiaHolidayCalendar holidays = const ColombiaHolidayCalendar(),
  required RestrictionRuleSet ruleSet,
  required String jurisdictionId,
  required PicoVehicleCategory category,
  required DateTime date,
}) {
  final rules = _currentRestrictRules(
    ruleSet,
    jurisdictionId: jurisdictionId,
    category: category,
    date: date,
  );
  if (_hasUniformWeeklySchedule(rules) &&
      !_coverageStaleOnDay(
        ruleSet,
        DateTime(date.year, date.month, date.day + 6),
      )) {
    return CityRestrictionRotationSummary(
      title: 'Rotación vigente',
      isWeekly: true,
      rows: [
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday += 1
        )
          _weeklyRotationRow(rules, weekday),
      ],
    );
  }
  final start = _day(date);
  return CityRestrictionRotationSummary(
    title: 'Próximos 7 días',
    isWeekly: false,
    rows: [
      for (var offset = 0; offset < 7; offset += 1)
        _datedRotationRow(
          summarizeCityRestrictionDay(
            holidays: holidays,
            ruleSet: ruleSet,
            jurisdictionId: jurisdictionId,
            category: category,
            date: DateTime(start.year, start.month, start.day + offset),
          ),
        ),
    ],
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

List<RestrictionRule> _currentRestrictRules(
  RestrictionRuleSet ruleSet, {
  required String jurisdictionId,
  required PicoVehicleCategory category,
  required DateTime date,
}) {
  if (!ruleSet.coverageKnown || _coverageStaleOnDay(ruleSet, date)) {
    return const [];
  }
  final day = _day(date);
  return ruleSet.rules
      .where(
        (rule) =>
            rule.jurisdictionId == jurisdictionId &&
            rule.effect == RestrictionEffect.restrict &&
            rule.vehicleKinds.contains(category.kind) &&
            rule.serviceTypes.contains(category.serviceType) &&
            !day.isBefore(_day(rule.validFrom)) &&
            (rule.validUntil == null || !day.isAfter(_day(rule.validUntil!))),
      )
      .toList(growable: false);
}

CityRestrictionRotationRow _weeklyRotationRow(
  List<RestrictionRule> rules,
  int weekday,
) {
  final dayRules = rules
      .where((rule) => rule.weekdays?.contains(weekday) ?? false)
      .toList(growable: false);
  if (dayRules.isEmpty) {
    return CityRestrictionRotationRow(
      label: _weekdayName(weekday),
      status: RestrictionDayStatus.allowed,
      digits: const [],
      windows: const [],
    );
  }
  return CityRestrictionRotationRow(
    label: _weekdayName(weekday),
    status: RestrictionDayStatus.restricted,
    digits: _digitsFrom(dayRules),
    windows: _windowsFrom(dayRules),
  );
}

CityRestrictionRotationRow _datedRotationRow(
  CityRestrictionDaySummary summary,
) {
  return CityRestrictionRotationRow(
    label:
        '${_weekdayName(summary.date.weekday).substring(0, 3)} ${summary.date.day}',
    date: summary.date,
    status: summary.status,
    digits: summary.restrictedDigits,
    windows: summary.effectiveWindows,
  );
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

List<int> _digitsFrom(List<RestrictionRule> rules) {
  final digits =
      rules.expand((rule) => rule.digits ?? const <int>{}).toSet().toList()
        ..sort();
  return List.unmodifiable(digits);
}

CityRestrictionDigitBasis _digitBasisFrom(List<RestrictionRule> rules) {
  if (rules.isEmpty) {
    return CityRestrictionDigitBasis.none;
  }
  if (rules.any((rule) => rule.dateParity != null)) {
    return CityRestrictionDigitBasis.dateParity;
  }
  final positions = rules
      .where((rule) => rule.digits != null && rule.digits!.isNotEmpty)
      .map((rule) => rule.digitPosition)
      .toSet();
  if (positions.length > 1) {
    return CityRestrictionDigitBasis.varies;
  }
  if (positions.length == 1) {
    return switch (positions.single) {
      RestrictionDigitPosition.firstNumeric =>
        CityRestrictionDigitBasis.firstNumeric,
      RestrictionDigitPosition.lastNumeric =>
        CityRestrictionDigitBasis.lastNumeric,
      null => CityRestrictionDigitBasis.custom,
    };
  }
  return CityRestrictionDigitBasis.custom;
}

DateTime? _minValidFrom(List<RestrictionRule> rules) {
  if (rules.isEmpty) {
    return null;
  }
  return rules
      .map((rule) => _day(rule.validFrom))
      .reduce((a, b) => a.isBefore(b) ? a : b);
}

DateTime? _maxValidUntil(List<RestrictionRule> rules) {
  final dates = rules
      .map((rule) => rule.validUntil == null ? null : _day(rule.validUntil!))
      .whereType<DateTime>()
      .toList(growable: false);
  if (dates.length != rules.length || dates.isEmpty) {
    return null;
  }
  return dates.reduce((a, b) => a.isAfter(b) ? a : b);
}

bool _hasUniformWeeklySchedule(List<RestrictionRule> rules) {
  if (rules.isEmpty) {
    return false;
  }
  if (rules.any(
    (rule) =>
        rule.dateParity != null ||
        rule.weekdays == null ||
        rule.weekdays!.isEmpty ||
        rule.digitPosition == null ||
        rule.digits == null ||
        rule.digits!.isEmpty,
  )) {
    return false;
  }
  return _digitBasisFrom(rules) != CityRestrictionDigitBasis.varies;
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

String _weekdayName(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Lunes',
    DateTime.tuesday => 'Martes',
    DateTime.wednesday => 'Miércoles',
    DateTime.thursday => 'Jueves',
    DateTime.friday => 'Viernes',
    DateTime.saturday => 'Sábado',
    _ => 'Domingo',
  };
}

bool _coverageStaleOnDay(RestrictionRuleSet ruleSet, DateTime date) {
  final staleAfter = ruleSet.staleAfter;
  return ruleSet.dataIsStale ||
      (staleAfter != null && !staleAfterCoversBogotaDate(staleAfter, date));
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
