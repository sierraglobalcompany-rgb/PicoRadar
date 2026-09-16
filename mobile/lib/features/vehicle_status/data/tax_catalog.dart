import 'dart:convert';
import 'dart:io';

import '../../../core/sync/dataset_sync_service.dart';

const taxCalendarsDatasetKey = 'tax_calendars';
const bundledTaxCatalogAsset = 'assets/catalogs/tax_calendars_v1.json';

class TaxCatalog {
  TaxCatalog._({
    required this.version,
    required this.generatedAt,
    required List<TaxAuthority> authorities,
    required List<TaxCalendar> calendars,
  }) : authorities = List.unmodifiable(authorities),
       calendars = List.unmodifiable(calendars),
       _authoritiesById = {
         for (final authority in authorities) authority.id: authority,
       },
       _calendarsByKey = {
         for (final calendar in calendars)
           (calendar.authorityId, calendar.year, calendar.obligationKind):
               calendar,
       };

  factory TaxCatalog.fromJsonString(String source) {
    try {
      return TaxCatalog.fromJson(_object(jsonDecode(source), 'catalog'));
    } on FormatException {
      throw const DatasetSyncException('Invalid tax catalog JSON.');
    }
  }

  factory TaxCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] is! int ||
        json['schemaVersion'] != 1 ||
        json['datasetKey'] != taxCalendarsDatasetKey) {
      throw const DatasetSyncException('Unsupported tax catalog envelope.');
    }
    final version = _text(json, 'version');
    final generatedAt = _instant(_text(json, 'generatedAt'), 'generatedAt');
    final authorities = [
      for (final value in _list(json, 'authorities'))
        TaxAuthority.fromJson(_object(value, 'authority')),
    ];
    if (authorities.isEmpty) {
      throw const DatasetSyncException('Tax authorities are required.');
    }
    _unique(authorities.map((a) => a.id), 'authority id');
    _unique(authorities.map((a) => a.territoryCode), 'territoryCode');
    final calendars = [
      for (final value in _list(json, 'calendars'))
        TaxCalendar.fromJson(_object(value, 'calendar')),
    ];
    _unique(calendars.map((c) => c.id), 'calendar id');
    _unique(
      calendars.map((c) => (c.authorityId, c.year, c.obligationKind)),
      'calendar authority/year/obligation',
    );
    final authorityIds = authorities.map((a) => a.id).toSet();
    if (calendars.any((c) => !authorityIds.contains(c.authorityId))) {
      throw const DatasetSyncException('Unknown calendar authorityId.');
    }
    return TaxCatalog._(
      version: version,
      generatedAt: generatedAt,
      authorities: authorities,
      calendars: calendars,
    );
  }

  final String version;
  final DateTime generatedAt;
  final List<TaxAuthority> authorities;
  final List<TaxCalendar> calendars;
  final Map<String, TaxAuthority> _authoritiesById;
  final Map<(String, int, String), TaxCalendar> _calendarsByKey;

  TaxAuthority? authorityById(String? id) => _authoritiesById[id];

  TaxCalendar? calendarFor(
    String authorityId,
    int year, {
    String obligationKind = 'vehicle_tax',
  }) => _calendarsByKey[(authorityId, year, obligationKind)];
}

class TaxAuthority {
  const TaxAuthority._({
    required this.id,
    required this.territoryCode,
    required this.territoryName,
    required this.name,
    required this.institutionalUrl,
    required this.portalUrl,
    required this.sourceUrls,
    required this.reviewedAt,
  });

  factory TaxAuthority.fromJson(Map<String, dynamic> json) {
    final code = _text(json, 'territoryCode');
    if (!RegExp(r'^[0-9]{2}$').hasMatch(code)) {
      throw const DatasetSyncException(
        'territoryCode must be two DANE digits.',
      );
    }
    return TaxAuthority._(
      id: _text(json, 'id'),
      territoryCode: code,
      territoryName: _text(json, 'territoryName'),
      name: _text(json, 'name'),
      institutionalUrl: _nullableUrl(json, 'institutionalUrl'),
      portalUrl: _nullableUrl(json, 'portalUrl'),
      sourceUrls: _sources(json, required: true),
      reviewedAt: _nullableInstant(json, 'reviewedAt'),
    );
  }

  final String id;
  final String territoryCode;
  final String territoryName;
  final String name;
  final String? institutionalUrl;
  final String? portalUrl;
  final List<String> sourceUrls;
  final DateTime? reviewedAt;
}

class TaxCalendar {
  const TaxCalendar._({
    required this.id,
    required this.authorityId,
    required this.year,
    required this.obligationKind,
    required this.status,
    required this.reviewedAt,
    required this.reviewAfter,
    required this.sourceUrls,
    required this.events,
    required this.activeEvents,
  });

  factory TaxCalendar.fromJson(Map<String, dynamic> json) {
    final year = json['year'];
    if (year is! int || year < 1 || year > 9999) {
      throw const DatasetSyncException(
        'Tax year must be an integer from 1 to 9999.',
      );
    }
    final status = _enum(json, 'status', {
      'verified',
      'partial',
      'pending',
      'withdrawn',
    });
    final reviewedAt = _nullableInstant(json, 'reviewedAt');
    final sourceUrls = _sources(json);
    final events = [
      for (final value in _list(json, 'events'))
        TaxCalendarEvent.fromJson(_object(value, 'event')),
    ];
    _unique(events.map((e) => e.id), 'event id');
    if ((status == 'verified' || status == 'partial') &&
        events.isNotEmpty &&
        (reviewedAt == null || sourceUrls.isEmpty)) {
      throw const DatasetSyncException(
        'Dated calendars require review and sources.',
      );
    }
    for (final event in events) {
      if (event.date.year != year &&
          !(event.date.year == year + 1 && event.condition != null)) {
        throw const DatasetSyncException(
          'Event date is outside its conditioned tax year.',
        );
      }
      if ((status == 'pending' || status == 'withdrawn') &&
          event.status == 'active') {
        throw const DatasetSyncException(
          'Unconfirmed calendar cannot have active events.',
        );
      }
    }
    _validateSupersession(events);
    final active = events.where((event) => event.status == 'active').toList()
      ..sort((a, b) {
        final dateOrder = a.date.compareTo(b.date);
        return dateOrder == 0 ? a.id.compareTo(b.id) : dateOrder;
      });
    return TaxCalendar._(
      id: _text(json, 'id'),
      authorityId: _text(json, 'authorityId'),
      year: year,
      obligationKind: _enum(json, 'obligationKind', {
        'vehicle_tax',
        'semaforizacion',
        'sistematizacion',
      }),
      status: status,
      reviewedAt: reviewedAt,
      reviewAfter: _nullableInstant(json, 'reviewAfter'),
      sourceUrls: sourceUrls,
      events: List.unmodifiable(events),
      activeEvents: List.unmodifiable(active),
    );
  }

  final String id;
  final String authorityId;
  final int year;
  final String obligationKind;
  final String status;
  final DateTime? reviewedAt;
  final DateTime? reviewAfter;
  final List<String> sourceUrls;
  final List<TaxCalendarEvent> events;
  final List<TaxCalendarEvent> activeEvents;
}

class TaxCalendarEvent {
  const TaxCalendarEvent._({
    required this.id,
    required this.date,
    required this.label,
    required this.kind,
    required this.condition,
    required this.status,
    required this.supersededBy,
    required this.sourceUrls,
  });

  factory TaxCalendarEvent.fromJson(Map<String, dynamic> json) {
    final kind = _enum(json, 'kind', {
      'discount',
      'ordinary',
      'installmentEnrollment',
      'installment',
    });
    final condition = _nullableText(json, 'condition');
    if ((kind == 'installment' || kind == 'installmentEnrollment') &&
        condition == null) {
      throw const DatasetSyncException(
        'Installment events require a condition.',
      );
    }
    final status = _enum(json, 'status', {'active', 'superseded', 'withdrawn'});
    final supersededBy = _nullableText(json, 'supersededBy');
    if ((status == 'superseded') != (supersededBy != null)) {
      throw const DatasetSyncException(
        'Only superseded events require supersededBy.',
      );
    }
    return TaxCalendarEvent._(
      id: _text(json, 'id'),
      date: _civilDate(_text(json, 'date')),
      label: _text(json, 'label'),
      kind: kind,
      condition: condition,
      status: status,
      supersededBy: supersededBy,
      sourceUrls: _sources(json, required: true),
    );
  }

  final String id;
  // UTC midnight represents civil components, never a localized deadline instant.
  final DateTime date;
  final String label;
  final String kind;
  final String? condition;
  final String status;
  final String? supersededBy;
  final List<String> sourceUrls;
}

void _validateSupersession(List<TaxCalendarEvent> events) {
  final byId = {for (final event in events) event.id: event};
  final complete = <String>{};
  for (final event in events) {
    final path = <String>{};
    String? id = event.id;
    while (id != null && !complete.contains(id)) {
      if (!path.add(id)) {
        throw const DatasetSyncException('Tax event supersession cycle.');
      }
      final current = byId[id];
      if (current == null) {
        throw const DatasetSyncException(
          'Unknown supersededBy event reference.',
        );
      }
      id = current.supersededBy;
    }
    complete.addAll(path);
  }
}

void _unique<T>(Iterable<T> values, String field) {
  final seen = <T>{};
  if (values.any((value) => !seen.add(value))) {
    throw DatasetSyncException('Duplicate tax $field.');
  }
}

Map<String, dynamic> _object(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  throw DatasetSyncException('$field must be a JSON object.');
}

List<dynamic> _list(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List) return value;
  throw DatasetSyncException('$field must be a list.');
}

String _text(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty && value == value.trim()) {
    return value;
  }
  throw DatasetSyncException(
    '$field must be a nonempty string without outer whitespace.',
  );
}

String? _nullableText(Map<String, dynamic> json, String field) =>
    json[field] == null ? null : _text(json, field);

String _enum(Map<String, dynamic> json, String field, Set<String> allowed) {
  final value = _text(json, field);
  if (!allowed.contains(value)) {
    throw DatasetSyncException('Unknown tax $field.');
  }
  return value;
}

DateTime _civilDate(String value) {
  if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) {
    throw const DatasetSyncException('Tax date must be YYYY-MM-DD.');
  }
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parts[0] < 1 ||
      date.year != parts[0] ||
      date.month != parts[1] ||
      date.day != parts[2]) {
    throw const DatasetSyncException('Tax date is not a real civil date.');
  }
  return date;
}

DateTime? _nullableInstant(Map<String, dynamic> json, String field) =>
    json[field] == null ? null : _instant(_text(json, field), field);

DateTime _instant(String value, String field) {
  final match = RegExp(
    r'^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.[0-9]+)?(Z|[+-]([0-9]{2}):([0-9]{2}))$',
  ).firstMatch(value);
  if (match == null ||
      int.parse(match[2]!) > 23 ||
      int.parse(match[3]!) > 59 ||
      int.parse(match[4]!) > 59 ||
      (match[6] != null &&
          (int.parse(match[6]!) > 23 || int.parse(match[7]!) > 59))) {
    throw DatasetSyncException(
      '$field must be an ISO instant with a valid offset.',
    );
  }
  _civilDate(match[1]!);
  final result = DateTime.tryParse(value);
  if (result == null) throw DatasetSyncException('Invalid $field.');
  return result.toUtc();
}

List<String> _sources(Map<String, dynamic> json, {bool required = false}) {
  final sources = [
    for (final value in _list(json, 'sourceUrls'))
      _url(_text({'url': value}, 'url')),
  ];
  if (required && sources.isEmpty) {
    throw const DatasetSyncException('Tax sourceUrls must not be empty.');
  }
  return List.unmodifiable(sources);
}

String? _nullableUrl(Map<String, dynamic> json, String field) {
  final value = _nullableText(json, field);
  return value == null ? null : _url(value);
}

String _url(String value) {
  final uri = Uri.tryParse(value);
  final host = uri?.host.toLowerCase() ?? '';
  final labels = host.split('.');
  const privateSuffixes = {
    'localhost',
    'local',
    'internal',
    'lan',
    'home',
    'test',
    'invalid',
    'example',
  };
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != 443) ||
      InternetAddress.tryParse(host) != null ||
      labels.length < 2 ||
      !RegExp(r'^[a-z]{2,63}$').hasMatch(labels.last) ||
      privateSuffixes.contains(labels.last) ||
      labels.any(
        (label) =>
            !RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(label),
      ) ||
      RegExp(r'[\s\\]').hasMatch(value)) {
    throw const DatasetSyncException(
      'Tax URL must use a public HTTPS host without credentials.',
    );
  }
  // Public document parameters remain extensible; personal lookups do not.
  final sensitiveParameter = RegExp(
    r'placa|plate|cedula|documento|identifica|email|correo|phone|telefono|'
    r'celular|password|passwd|token|secret|auth|session|usuario|user|nombre|'
    r'apellido|redirect|callback|returnurl',
    caseSensitive: false,
  );
  for (final entry in uri.queryParametersAll.entries) {
    if (sensitiveParameter.hasMatch(entry.key) ||
        entry.value.any(
          (value) =>
              value.contains('@') ||
              value.contains('://') ||
              RegExp(r'[\r\n]').hasMatch(value),
        )) {
      throw const DatasetSyncException(
        'Tax URL query must not contain personal data or redirects.',
      );
    }
  }
  return value;
}
