import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/dataset_sync_service.dart';
import '../../garage/data/vehicle_profile.dart';
import '../domain/restriction_rule.dart';

const restrictionsDatasetKey = 'restrictions';

Future<void> importRestrictionsDataset(
  AppDatabase db,
  Map<String, dynamic> json,
) async {
  final rows = _parseRestrictionCoverages(json);

  await db.delete(db.restrictionCoverages).go();
  await db.batch((batch) {
    batch.insertAll(db.restrictionCoverages, rows);
  });
}

List<RestrictionRule> restrictionRulesFromJson(
  String rulesJson, {
  required String jurisdictionId,
  required VehicleKind vehicleKind,
  required VehicleServiceType serviceType,
}) {
  final decoded = jsonDecode(rulesJson);
  if (decoded is! List) {
    throw const DatasetSyncException('Restriction rules must be a list.');
  }
  return decoded
      .map(
        (rule) => _parseRule(
          _mapValue(rule, 'rules[]'),
          jurisdictionId: jurisdictionId,
          vehicleKind: vehicleKind,
          serviceType: serviceType,
        ),
      )
      .toList(growable: false);
}

List<String> restrictionSourceUrlsFromJson(String sourceUrlsJson) {
  final decoded = jsonDecode(sourceUrlsJson);
  if (decoded is! List) {
    throw const DatasetSyncException('sourceUrls must be a list.');
  }
  return decoded.map((value) => _sourceUrl(value, 'sourceUrls[]')).toList();
}

List<RestrictionCoveragesCompanion> _parseRestrictionCoverages(
  Map<String, dynamic> json,
) {
  final schemaVersion = _int(json, 'schemaVersion');
  if (schemaVersion != 1) {
    throw DatasetSyncException(
      'Unsupported restrictions schemaVersion: $schemaVersion.',
    );
  }
  if (_string(json, 'datasetKey') != restrictionsDatasetKey) {
    throw const DatasetSyncException('Restriction datasetKey is invalid.');
  }
  _string(json, 'version');
  DateTime.parse(_string(json, 'generatedAt'));

  final coverageIds = <String>{};
  final ruleIds = <String>{};
  final rows = <RestrictionCoveragesCompanion>[];
  for (final jurisdictionEntry in _list(json, 'jurisdictions')) {
    final jurisdiction = _mapValue(jurisdictionEntry, 'jurisdictions[]');
    final jurisdictionId = _string(jurisdiction, 'id');
    final jurisdictionName = _string(jurisdiction, 'name');
    for (final coverageEntry in _list(jurisdiction, 'coverages')) {
      final coverage = _mapValue(coverageEntry, 'coverages[]');
      final vehicleKind = _vehicleKind(_string(coverage, 'vehicleKind'));
      final serviceType = _serviceType(_string(coverage, 'serviceType'));
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
        final ruleId = _string(rule, 'id');
        if (!ruleIds.add('$jurisdictionId/$ruleId')) {
          throw DatasetSyncException('Duplicate restriction rule id: $ruleId.');
        }
        _parseRule(
          rule,
          jurisdictionId: jurisdictionId,
          vehicleKind: vehicleKind,
          serviceType: serviceType,
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
          rulesJson: jsonEncode(normalizedRules),
          verifiedAt: verifiedAt,
          staleAfter: staleAfter,
          sourceUrlsJson: jsonEncode(sourceUrls),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }
  return rows;
}

RestrictionRule _parseRule(
  Map<String, dynamic> json, {
  required String jurisdictionId,
  required VehicleKind vehicleKind,
  required VehicleServiceType serviceType,
}) {
  final timeWindows = _list(json, 'timeWindows')
      .map((value) => _timeWindow(_mapValue(value, 'timeWindows[]')))
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
    timeWindows: timeWindows,
    appliesOnHolidays: _bool(json, 'appliesOnHolidays'),
    sourceUrl: _sourceUrl(json['sourceUrl'], 'sourceUrl'),
    verifiedAt: DateTime.parse(_string(json, 'verifiedAt')),
  );
}

RestrictionTimeWindow _timeWindow(Map<String, dynamic> json) {
  final startMinute = _int(json, 'startMinute');
  final endMinute = _int(json, 'endMinute');
  if (startMinute < 0 ||
      startMinute >= 1440 ||
      endMinute < 0 ||
      endMinute >= 1440 ||
      startMinute == endMinute) {
    throw const DatasetSyncException('Invalid restriction timeWindow.');
  }
  return RestrictionTimeWindow(startMinute: startMinute, endMinute: endMinute);
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
