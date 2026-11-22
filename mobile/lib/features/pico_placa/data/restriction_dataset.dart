import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/dataset_sync_service.dart';
import '../../garage/data/vehicle_profile.dart';
import '../domain/restriction_rule.dart';

const restrictionsDatasetKey = 'restrictions';

Future<void> importRestrictionsDataset(
  AppDatabase db,
  Map<String, dynamic> json, {
  DateTime Function()? now,
}) async {
  final parsed = _parseRestrictionDataset(json, now: now ?? DateTime.now);

  await db.transaction(() async {
    await db.delete(db.restrictionCoverages).go();
    await db.delete(db.restrictionJurisdictionAvailability).go();
    await db.batch((batch) {
      batch.insertAll(db.restrictionCoverages, parsed.coverages);
      batch.insertAll(
        db.restrictionJurisdictionAvailability,
        parsed.availability,
      );
    });
  });
}

List<RestrictionRule> restrictionRulesFromJson(
  String rulesJson, {
  required String jurisdictionId,
  required VehicleKind vehicleKind,
  required VehicleServiceType serviceType,
  int schemaVersion = 1,
}) {
  final decoded = _decodeRestrictionRulesPayload(rulesJson);
  return decoded.rules
      .map(
        (rule) => _parseRule(
          _mapValue(rule, 'rules[]'),
          jurisdictionId: jurisdictionId,
          vehicleKind: vehicleKind,
          serviceType: serviceType,
          schemaVersion: schemaVersion,
        ),
      )
      .toList(growable: false);
}

bool restrictionConsultationEnabledFromJson(String rulesJson) =>
    _decodeRestrictionRulesPayload(rulesJson).consultationEnabled;

({List<dynamic> rules, bool consultationEnabled})
_decodeRestrictionRulesPayload(String rulesJson) {
  final decoded = jsonDecode(rulesJson);
  if (decoded is List) {
    // Historical local rows stored only the rules list and meant ON.
    return (rules: decoded, consultationEnabled: true);
  }
  if (decoded is! Map) {
    throw const DatasetSyncException('Restriction rules payload is invalid.');
  }
  final payload = Map<String, dynamic>.from(decoded);
  _knownKeys(payload, const {'consultationEnabled', 'rules'}, 'coverage rules');
  final consultationEnabled = payload['consultationEnabled'];
  final rules = payload['rules'];
  if (consultationEnabled is! bool || rules is! List) {
    throw const DatasetSyncException('Restriction rules payload is invalid.');
  }
  return (rules: rules, consultationEnabled: consultationEnabled);
}

List<String> restrictionSourceUrlsFromJson(String sourceUrlsJson) {
  final decoded = jsonDecode(sourceUrlsJson);
  if (decoded is! List) {
    throw const DatasetSyncException('sourceUrls must be a list.');
  }
  return decoded.map((value) => _sourceUrl(value, 'sourceUrls[]')).toList();
}

_ParsedRestrictionDataset _parseRestrictionDataset(
  Map<String, dynamic> json, {
  required DateTime Function() now,
}) {
  final schemaVersion = _int(json, 'schemaVersion');
  if (schemaVersion != 1 && schemaVersion != 2) {
    throw DatasetSyncException(
      'Unsupported restrictions schemaVersion: $schemaVersion.',
    );
  }
  _knownKeys(json, const {
    'schemaVersion',
    'datasetKey',
    'version',
    'generatedAt',
    'jurisdictions',
    'expiresAt',
  }, 'restrictions envelope');
  if (_string(json, 'datasetKey') != restrictionsDatasetKey) {
    throw const DatasetSyncException('Restriction datasetKey is invalid.');
  }
  _string(json, 'version');
  DateTime.parse(_string(json, 'generatedAt'));
  if (json.containsKey('expiresAt')) {
    final expiresAt = _envelopeDate(json['expiresAt']);
    if (!now().toUtc().isBefore(expiresAt.toUtc())) {
      throw const DatasetSyncException('Restrictions envelope expired.');
    }
  }

  final coverageIds = <String>{};
  final ruleIds = <String>{};
  final rows = <RestrictionCoveragesCompanion>[];
  final availabilityRows = <RestrictionJurisdictionAvailabilityCompanion>[];
  for (final jurisdictionEntry in _list(json, 'jurisdictions')) {
    final jurisdiction = _mapValue(jurisdictionEntry, 'jurisdictions[]');
    final jurisdictionSchemaVersion = jurisdiction.containsKey('schemaVersion')
        ? _int(jurisdiction, 'schemaVersion')
        : 1;
    if (jurisdictionSchemaVersion != 1 && jurisdictionSchemaVersion != 2) {
      throw const DatasetSyncException(
        'Unsupported jurisdiction schemaVersion.',
      );
    }
    if (schemaVersion == 1 && jurisdictionSchemaVersion != 1) {
      throw const DatasetSyncException(
        'Schema1 cannot contain a schema2 jurisdiction.',
      );
    }
    final hasMunicipalityCodes = jurisdiction.containsKey('municipalityCodes');
    final hasConsultationEnabled = jurisdiction.containsKey(
      'consultationEnabled',
    );
    if (schemaVersion == 1 &&
        (hasMunicipalityCodes || hasConsultationEnabled)) {
      throw const DatasetSyncException(
        'Restrictions root schema1 cannot contain jurisdiction availability metadata.',
      );
    }
    final jurisdictionKeys = <String>{
      'schemaVersion',
      'id',
      'name',
      'coverages',
      if (schemaVersion == 2) 'municipalityCodes',
      if (schemaVersion == 2) 'consultationEnabled',
    };
    _knownKeys(jurisdiction, jurisdictionKeys, 'jurisdictions[]');
    final jurisdictionId = _string(jurisdiction, 'id');
    final jurisdictionName = _string(jurisdiction, 'name');
    if (hasMunicipalityCodes != hasConsultationEnabled) {
      throw const DatasetSyncException(
        'municipalityCodes and consultationEnabled must be supplied together.',
      );
    }
    if (hasMunicipalityCodes) {
      final rawCodes = _list(jurisdiction, 'municipalityCodes');
      if (rawCodes.isEmpty) {
        throw const DatasetSyncException(
          'municipalityCodes must not be empty.',
        );
      }
      final codes = <String>[];
      for (final value in rawCodes) {
        if (value is! String || !RegExp(r'^\d{5}$').hasMatch(value)) {
          throw const DatasetSyncException(
            'municipalityCodes must contain five-digit DIVIPOLA strings.',
          );
        }
        codes.add(value);
      }
      final sortedCodes = [...codes]..sort();
      if (codes.toSet().length != codes.length) {
        throw const DatasetSyncException(
          'municipalityCodes must not contain duplicates.',
        );
      }
      if (!_sameStrings(codes, sortedCodes)) {
        throw const DatasetSyncException(
          'municipalityCodes must be sorted canonically.',
        );
      }
      final consultationEnabled = jurisdiction['consultationEnabled'];
      if (consultationEnabled is! bool) {
        throw const DatasetSyncException(
          'consultationEnabled must be a boolean.',
        );
      }
      availabilityRows.add(
        RestrictionJurisdictionAvailabilityCompanion.insert(
          jurisdictionId: jurisdictionId,
          municipalityCodesJson: jsonEncode(codes),
          consultationEnabled: consultationEnabled,
        ),
      );
    }
    for (final coverageEntry in _list(jurisdiction, 'coverages')) {
      final coverage = _mapValue(coverageEntry, 'coverages[]');
      _knownKeys(
        coverage,
        jurisdictionSchemaVersion == 1
            ? const {
                'vehicleKind',
                'serviceType',
                'verifiedAt',
                'staleAfter',
                'sourceUrls',
                'rules',
              }
            : const {
                'vehicleKind',
                'serviceType',
                'coverageCompleteness',
                'consultationEnabled',
                'verifiedAt',
                'staleAfter',
                'sourceUrls',
                'rules',
              },
        'coverages[]',
      );
      final vehicleKind = _vehicleKind(_string(coverage, 'vehicleKind'));
      final serviceType = _serviceType(_string(coverage, 'serviceType'));
      if (jurisdictionSchemaVersion == 1 &&
          !_isLegacyPair(vehicleKind, serviceType)) {
        throw const DatasetSyncException(
          'Schema1 does not support V2 vehicle/service categories.',
        );
      }
      if (jurisdictionSchemaVersion == 2 &&
          !_isV2Pair(vehicleKind, serviceType)) {
        throw const DatasetSyncException(
          'Unsupported schema2 vehicle/service pair.',
        );
      }
      final completeness = jurisdictionSchemaVersion == 1
          ? CoverageCompleteness.legacy
          : _coverageCompleteness(_string(coverage, 'coverageCompleteness'));
      var consultationEnabled = true;
      if (jurisdictionSchemaVersion == 2 &&
          coverage.containsKey('consultationEnabled')) {
        final value = coverage['consultationEnabled'];
        if (value is! bool) {
          throw const DatasetSyncException(
            'coverage consultationEnabled must be a boolean.',
          );
        }
        consultationEnabled = value;
      }
      final id = _coverageId(jurisdictionId, vehicleKind, serviceType);
      if (!coverageIds.add(id)) {
        throw DatasetSyncException('Duplicate restriction coverage id: $id.');
      }

      final verifiedAt = DateTime.parse(_string(coverage, 'verifiedAt'));
      final staleAfter = DateTime.parse(_string(coverage, 'staleAfter'));
      final sourceUrls = _list(coverage, 'sourceUrls')
          .map((value) => _sourceUrl(value, 'sourceUrls[]'))
          .toList(growable: false);
      if (sourceUrls.isEmpty) {
        throw DatasetSyncException('sourceUrls is required for $id.');
      }

      final normalizedRules = <Map<String, Object?>>[];
      for (final ruleEntry in _list(coverage, 'rules')) {
        final rule = _mapValue(ruleEntry, 'rules[]');
        _knownKeys(
          rule,
          jurisdictionSchemaVersion == 1
              ? const {
                  'id',
                  'priority',
                  'effect',
                  'validFrom',
                  'validUntil',
                  'weekdays',
                  'dateParity',
                  'digitPosition',
                  'digits',
                  'registrationOrigins',
                  'timeWindows',
                  'appliesOnHolidays',
                  'sourceUrl',
                  'verifiedAt',
                }
              : const {
                  'id',
                  'priority',
                  'effect',
                  'validFrom',
                  'validUntil',
                  'weekdays',
                  'dateParity',
                  'digitPosition',
                  'digits',
                  'registrationOrigins',
                  'timeWindows',
                  'appliesOnHolidays',
                  'sourceUrl',
                  'verifiedAt',
                  'conditions',
                },
          'rules[]',
        );
        final ruleId = _string(rule, 'id');
        if (!ruleIds.add('$jurisdictionId/$ruleId')) {
          throw DatasetSyncException('Duplicate restriction rule id: $ruleId.');
        }
        _parseRule(
          rule,
          jurisdictionId: jurisdictionId,
          vehicleKind: vehicleKind,
          serviceType: serviceType,
          schemaVersion: jurisdictionSchemaVersion,
        );
        normalizedRules.add(Map<String, Object?>.from(rule));
      }

      rows.add(
        RestrictionCoveragesCompanion.insert(
          id: id,
          jurisdictionId: jurisdictionId,
          jurisdictionName: jurisdictionName,
          vehicleKind: vehicleKind.value,
          serviceType: serviceType.value,
          rulesJson: jsonEncode(
            jurisdictionSchemaVersion == 2
                ? {
                    'consultationEnabled': consultationEnabled,
                    'rules': normalizedRules,
                  }
                : normalizedRules,
          ),
          verifiedAt: verifiedAt,
          staleAfter: staleAfter,
          sourceUrlsJson: jsonEncode(sourceUrls),
          coverageCompleteness: Value(completeness.name),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }
  return _ParsedRestrictionDataset(
    coverages: rows,
    availability: availabilityRows,
  );
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class _ParsedRestrictionDataset {
  const _ParsedRestrictionDataset({
    required this.coverages,
    required this.availability,
  });

  final List<RestrictionCoveragesCompanion> coverages;
  final List<RestrictionJurisdictionAvailabilityCompanion> availability;
}

DateTime _envelopeDate(Object? value) {
  const pattern =
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?$';
  if (value is! String || !RegExp(pattern).hasMatch(value.trim())) {
    throw const DatasetSyncException(
      'Restrictions expiresAt must be an ISO-8601 date.',
    );
  }
  try {
    final normalizedValue = value.trim();
    if (!RegExp(
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
    ).hasMatch(normalizedValue)) {
      throw const FormatException('Invalid ISO-8601 time zone.');
    }
    final offset = RegExp(r'[+-](\d{2}):(\d{2})$').firstMatch(normalizedValue);
    if (offset != null &&
        (int.parse(offset.group(1)!) > 23 ||
            int.parse(offset.group(2)!) > 59)) {
      throw const FormatException('Invalid ISO-8601 time zone.');
    }
    final components = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(normalizedValue)!;
    final year = int.parse(components.group(1)!);
    final month = int.parse(components.group(2)!);
    final day = int.parse(components.group(3)!);
    final hour = int.parse(components.group(4)!);
    final minute = int.parse(components.group(5)!);
    final second = int.parse(components.group(6)!);
    final calendarDate = DateTime.utc(year, month, day, hour, minute, second);
    if (calendarDate.year != year ||
        calendarDate.month != month ||
        calendarDate.day != day ||
        calendarDate.hour != hour ||
        calendarDate.minute != minute ||
        calendarDate.second != second) {
      throw const FormatException('Invalid calendar date.');
    }
    return DateTime.parse(normalizedValue);
  } on FormatException {
    throw const DatasetSyncException(
      'Restrictions expiresAt must be a valid date.',
    );
  }
}

RestrictionRule _parseRule(
  Map<String, dynamic> json, {
  required String jurisdictionId,
  required VehicleKind vehicleKind,
  required VehicleServiceType serviceType,
  int schemaVersion = 1,
}) {
  _knownKeys(
    json,
    schemaVersion == 1
        ? const {
            'id',
            'priority',
            'effect',
            'validFrom',
            'validUntil',
            'weekdays',
            'dateParity',
            'digitPosition',
            'digits',
            'registrationOrigins',
            'timeWindows',
            'appliesOnHolidays',
            'sourceUrl',
            'verifiedAt',
          }
        : const {
            'id',
            'priority',
            'effect',
            'validFrom',
            'validUntil',
            'weekdays',
            'dateParity',
            'digitPosition',
            'digits',
            'registrationOrigins',
            'timeWindows',
            'appliesOnHolidays',
            'sourceUrl',
            'verifiedAt',
            'conditions',
          },
    'rules[]',
  );
  final timeWindows = _list(json, 'timeWindows')
      .map(
        (value) => _timeWindow(
          _mapValue(value, 'timeWindows[]'),
          schemaVersion: schemaVersion,
        ),
      )
      .toList(growable: false);
  final digits = _optionalIntSet(json['digits'], 'digits', min: 0, max: 9);
  final digitPosition = _optionalEnum(
    json['digitPosition'],
    'digitPosition',
    _digitPosition,
  );
  if (digits != null && digitPosition == null) {
    throw const DatasetSyncException('digitPosition is required with digits.');
  }

  return RestrictionRule(
    id: _string(json, 'id'),
    jurisdictionId: jurisdictionId,
    priority: _int(json, 'priority'),
    effect: _enum(_string(json, 'effect'), 'effect', _effect),
    validFrom: DateTime.parse(_string(json, 'validFrom')),
    validUntil: _optionalDate(json['validUntil']),
    vehicleKinds: {vehicleKind},
    serviceTypes: {serviceType},
    registrationOrigins: _optionalEnumSet(
      json['registrationOrigins'],
      'registrationOrigins',
      _registrationOrigin,
    ),
    weekdays: _optionalIntSet(json['weekdays'], 'weekdays', min: 1, max: 7),
    dateParity: _optionalEnum(json['dateParity'], 'dateParity', _dateParity),
    digitPosition: digitPosition,
    digits: digits,
    conditions: schemaVersion == 2 && json.containsKey('conditions')
        ? _conditions(json['conditions'])
        : const [],
    timeWindows: timeWindows,
    appliesOnHolidays: _bool(json, 'appliesOnHolidays'),
    sourceUrl: _sourceUrl(json['sourceUrl'], 'sourceUrl'),
    verifiedAt: DateTime.parse(_string(json, 'verifiedAt')),
  );
}

List<RestrictionCondition> _conditions(Object? value) {
  if (value is! List) {
    throw const DatasetSyncException('conditions must be a list.');
  }
  final result = <RestrictionCondition>[];
  final types = <String>{};
  for (final entry in value) {
    final condition = _mapValue(entry, 'conditions[]');
    _knownKeys(condition, const {'type', 'value'}, 'conditions[]');
    final type = _string(condition, 'type');
    if (!types.add(type)) {
      throw DatasetSyncException('Duplicate condition type: $type.');
    }
    final raw = condition['value'];
    result.add(switch (type) {
      'pillion_present' =>
        raw is bool
            ? PillionPresentCondition(raw)
            : throw const DatasetSyncException(
                'pillion_present value must be boolean.',
              ),
      'occupants_at_least' => OccupantsAtLeastCondition(
        _boundedInt(raw, 'occupants_at_least', 1, 99),
      ),
      'occupants_below' => OccupantsBelowCondition(
        _boundedInt(raw, 'occupants_below', 1, 99),
      ),
      'gross_weight_kg_gt' => GrossWeightKgGreaterThanCondition(
        _boundedInt(raw, 'gross_weight_kg_gt', 0, 100000),
      ),
      'axles_at_least' => AxlesAtLeastCondition(
        _boundedInt(raw, 'axles_at_least', 1, 20),
      ),
      'inside_scope_ref' => InsideScopeRefCondition(_scopeReference(raw)),
      _ => throw DatasetSyncException('Unknown restriction condition: $type.'),
    });
  }
  final atLeastConditions = result
      .whereType<OccupantsAtLeastCondition>()
      .toList();
  final belowConditions = result.whereType<OccupantsBelowCondition>().toList();
  final atLeast = atLeastConditions.isEmpty ? null : atLeastConditions.single;
  final below = belowConditions.isEmpty ? null : belowConditions.single;
  if (atLeast != null && below != null && atLeast.value >= below.value) {
    throw const DatasetSyncException(
      'Occupancy condition interval is impossible.',
    );
  }
  return List.unmodifiable(result);
}

int _boundedInt(Object? value, String key, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw DatasetSyncException('$key value is outside its allowed range.');
  }
  return value;
}

String _scopeReference(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const DatasetSyncException(
      'inside_scope_ref value must be a string.',
    );
  }
  final reference = value.trim();
  final separator = reference.lastIndexOf('@');
  if (reference != value ||
      separator <= 0 ||
      separator == reference.length - 1 ||
      reference.substring(0, separator).contains('@')) {
    throw const DatasetSyncException(
      'inside_scope_ref must be scopeId@scopeVersion.',
    );
  }
  return reference;
}

CoverageCompleteness _coverageCompleteness(String value) => switch (value) {
  'complete' => CoverageCompleteness.complete,
  'partial' => CoverageCompleteness.partial,
  _ => throw const DatasetSyncException(
    'coverageCompleteness must be complete or partial.',
  ),
};

bool _isLegacyPair(VehicleKind kind, VehicleServiceType service) =>
    (kind == VehicleKind.car &&
        (service == VehicleServiceType.private ||
            service == VehicleServiceType.taxi)) ||
    (kind == VehicleKind.motorcycle && service == VehicleServiceType.private);

bool _isV2Pair(VehicleKind kind, VehicleServiceType service) =>
    _isLegacyPair(kind, service) ||
    (kind == VehicleKind.truck &&
        (service == VehicleServiceType.private ||
            service == VehicleServiceType.publicCargo)) ||
    (kind == VehicleKind.bus &&
        (service == VehicleServiceType.publicPassenger ||
            service == VehicleServiceType.special)) ||
    (kind == VehicleKind.car && service == VehicleServiceType.special) ||
    (kind == VehicleKind.motocarro && service == VehicleServiceType.private);

void _knownKeys(Map<String, dynamic> json, Set<String> allowed, String label) {
  final extra = json.keys.where((key) => !allowed.contains(key));
  if (extra.isNotEmpty) {
    throw DatasetSyncException(
      '$label contains unsupported key: ${extra.first}.',
    );
  }
}

RestrictionTimeWindow _timeWindow(
  Map<String, dynamic> json, {
  required int schemaVersion,
}) {
  _knownKeys(
    json,
    schemaVersion == 1
        ? const {'startMinute', 'endMinute'}
        : const {'startMinute', 'endMinute', 'fullDay'},
    'timeWindows[]',
  );
  final startMinute = _int(json, 'startMinute');
  final endMinute = _int(json, 'endMinute');
  final hasFullDay = json.containsKey('fullDay');
  final fullDayValue = json['fullDay'];
  if (startMinute < 0 ||
      startMinute >= 1440 ||
      endMinute < 0 ||
      endMinute >= 1440 ||
      (startMinute == endMinute &&
          (schemaVersion != 2 || !hasFullDay || fullDayValue != true)) ||
      (startMinute != endMinute && hasFullDay)) {
    throw const DatasetSyncException('Invalid restriction timeWindow.');
  }
  return RestrictionTimeWindow(
    startMinute: startMinute,
    endMinute: endMinute,
    fullDay: hasFullDay && fullDayValue == true,
  );
}

String _coverageId(
  String jurisdictionId,
  VehicleKind vehicleKind,
  VehicleServiceType serviceType,
) {
  return '$jurisdictionId:${vehicleKind.value}:${serviceType.value}';
}

RestrictionEffect _effect(String value) {
  return switch (value) {
    'restrict' => RestrictionEffect.restrict,
    'allow' => RestrictionEffect.allow,
    _ => throw DatasetSyncException('Invalid restriction effect: $value.'),
  };
}

RegistrationOrigin _registrationOrigin(String value) {
  return switch (value) {
    'local' => RegistrationOrigin.local,
    'foreign' => RegistrationOrigin.foreign,
    'unknown' => RegistrationOrigin.unknown,
    _ => throw DatasetSyncException('Invalid registrationOrigin: $value.'),
  };
}

RestrictionDateParity _dateParity(String value) {
  return switch (value) {
    'odd' => RestrictionDateParity.odd,
    'even' => RestrictionDateParity.even,
    _ => throw DatasetSyncException('Invalid dateParity: $value.'),
  };
}

RestrictionDigitPosition _digitPosition(String value) {
  return switch (value) {
    'firstNumeric' => RestrictionDigitPosition.firstNumeric,
    'lastNumeric' => RestrictionDigitPosition.lastNumeric,
    _ => throw DatasetSyncException('Invalid digitPosition: $value.'),
  };
}

VehicleKind _vehicleKind(String value) {
  try {
    return VehicleKind.fromValue(value);
  } catch (_) {
    throw DatasetSyncException('Invalid vehicleKind: $value.');
  }
}

VehicleServiceType _serviceType(String value) {
  try {
    return VehicleServiceType.fromValue(value);
  } catch (_) {
    throw DatasetSyncException('Invalid serviceType: $value.');
  }
}

T _enum<T>(String value, String key, T Function(String value) parse) {
  try {
    return parse(value);
  } on DatasetSyncException {
    rethrow;
  } catch (_) {
    throw DatasetSyncException('Invalid $key: $value.');
  }
}

T? _optionalEnum<T>(Object? value, String key, T Function(String value) parse) {
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw DatasetSyncException('$key must be a non-empty string.');
  }
  return _enum(value.trim(), key, parse);
}

Set<T>? _optionalEnumSet<T>(
  Object? value,
  String key,
  T Function(String value) parse,
) {
  if (value == null) {
    return null;
  }
  if (value is! List) {
    throw DatasetSyncException('$key must be a list.');
  }
  return value
      .map((entry) => _optionalEnum(entry, key, parse))
      .whereType<T>()
      .toSet();
}

Set<int>? _optionalIntSet(
  Object? value,
  String key, {
  required int min,
  required int max,
}) {
  if (value == null) {
    return null;
  }
  if (value is! List) {
    throw DatasetSyncException('$key must be a list.');
  }
  final result = <int>{};
  for (final entry in value) {
    if (entry is! int || entry < min || entry > max) {
      throw DatasetSyncException('$key contains an invalid value.');
    }
    result.add(entry);
  }
  return result;
}

DateTime? _optionalDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw const DatasetSyncException('validUntil must be a non-empty string.');
  }
  return DateTime.parse(value.trim());
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw DatasetSyncException('$key must be an integer.');
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw DatasetSyncException('$key must be a boolean.');
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw DatasetSyncException('$key must be a non-empty string.');
}

List<Object?> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) {
    return List<Object?>.from(value);
  }
  throw DatasetSyncException('$key must be a list.');
}

Map<String, dynamic> _mapValue(Object? value, String key) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw DatasetSyncException('$key must be an object.');
}

String _sourceUrl(Object? value, String key) {
  if (value is! String || value.trim().isEmpty) {
    throw DatasetSyncException('$key must be a non-empty string.');
  }
  final sourceUrl = value.trim();
  final uri = Uri.parse(sourceUrl);
  if (uri.scheme != 'https' || uri.host.isEmpty) {
    throw DatasetSyncException('$key must be an HTTPS URL.');
  }
  return sourceUrl;
}
