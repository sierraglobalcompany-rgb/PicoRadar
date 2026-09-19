import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const picoJurisdictionCatalogAssetPath =
    'assets/catalogs/pico_jurisdiction_catalog_v1.json';

final picoJurisdictionCatalogProvider = FutureProvider<PicoJurisdictionCatalog>(
  (ref) async {
    final raw = await rootBundle.loadString(picoJurisdictionCatalogAssetPath);
    return PicoJurisdictionCatalog.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
  },
);

enum PicoOperationalStatus { verified, conditional, expired, pending }

class PicoJurisdictionCatalogEntry {
  const PicoJurisdictionCatalogEntry({
    required this.id,
    required this.name,
    required this.department,
    required this.classification,
    required this.sourceDate,
    this.selectorDisplayName,
    this.municipalityCode = '',
    this.status = PicoOperationalStatus.pending,
    this.engineEnabled = false,
    this.engineJurisdictionId,
    this.evidenceSummary = '',
    this.evidenceRecordIds = const [],
    this.sourceIds = const [],
    this.sourceUrls = const [],
  });

  final String id;
  final String name;
  final String department;
  final String classification;
  final String sourceDate;
  final String? selectorDisplayName;
  final String municipalityCode;
  final PicoOperationalStatus status;
  final bool engineEnabled;
  final String? engineJurisdictionId;
  final String evidenceSummary;
  final List<String> evidenceRecordIds;
  final List<String> sourceIds;
  final List<String> sourceUrls;

  String get displayName => '$name, Colombia';
  String get selectorName => selectorDisplayName ?? name;

  factory PicoJurisdictionCatalogEntry.fromJson(Map<String, Object?> json) {
    final statusName = _string(json, 'operationalStatus');
    final status = PicoOperationalStatus.values
        .where((value) => value.name == statusName)
        .firstOrNull;
    if (status == null) {
      throw const FormatException('Unsupported Pico operational status');
    }
    final engineEnabled = _bool(json, 'engineEnabled');
    final engineJurisdictionId = _optionalString(json, 'engineJurisdictionId');
    final sourceUrls = _strings(json, 'sourceUrls');
    if (sourceUrls.any((url) {
      final uri = Uri.tryParse(url);
      return uri == null || uri.scheme != 'https' || uri.host.isEmpty;
    })) {
      throw const FormatException('Invalid Pico source URL');
    }
    if (engineEnabled &&
        (status != PicoOperationalStatus.verified ||
            engineJurisdictionId == null)) {
      throw const FormatException('Unverified Pico engine eligibility');
    }
    if (!engineEnabled && engineJurisdictionId != null) {
      throw const FormatException('Disabled Pico entry has engine ID');
    }
    final municipalityCode = _string(json, 'municipalityCode');
    if (!RegExp(r'^\d{5}$').hasMatch(municipalityCode)) {
      throw const FormatException('Invalid Pico municipality code');
    }
    return PicoJurisdictionCatalogEntry(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      department: _string(json, 'department'),
      classification: _string(json, 'classification'),
      sourceDate: _date(json, 'sourceDate'),
      selectorDisplayName: _optionalString(json, 'displayName'),
      municipalityCode: municipalityCode,
      status: status,
      engineEnabled: engineEnabled,
      engineJurisdictionId: engineJurisdictionId,
      evidenceSummary: _string(json, 'evidenceSummary'),
      evidenceRecordIds: _strings(json, 'evidenceRecordIds', allowEmpty: false),
      sourceIds: _strings(json, 'sourceIds'),
      sourceUrls: sourceUrls,
    );
  }
}

class PicoJurisdictionCatalog {
  const PicoJurisdictionCatalog({
    required this.records,
    this.version = '',
    this.sourceCutoff = '',
    this.asOfDate = '',
    this.sourceWorkbookSha256 = '',
  });

  final List<PicoJurisdictionCatalogEntry> records;
  final String version;
  final String sourceCutoff;
  final String asOfDate;
  final String sourceWorkbookSha256;

  factory PicoJurisdictionCatalog.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 2 ||
        json['catalogKey'] != 'pico_jurisdictions') {
      throw const FormatException('Unsupported Pico catalog schema');
    }
    final source = _map(json, 'source');
    if (_string(source, 'sheet') != 'Estado_al_corte' ||
        source['categoryRows'] != 219) {
      throw const FormatException('Unexpected Pico source scope');
    }
    final sourceSha = _string(source, 'sha256');
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceSha)) {
      throw const FormatException('Invalid Pico source hash');
    }
    final rows = json['records'];
    if (rows is! List || rows.any((row) => row is! Map<String, Object?>)) {
      throw const FormatException('Invalid Pico records');
    }
    final records = rows
        .cast<Map<String, Object?>>()
        .map(PicoJurisdictionCatalogEntry.fromJson)
        .toList(growable: false);
    final ids = records.map((entry) => entry.id).toSet();
    final codes = records.map((entry) => entry.municipalityCode).toSet();
    if (records.length != 73 ||
        ids.length != records.length ||
        codes.length != records.length) {
      throw const FormatException('Incomplete or duplicate Pico coverage');
    }
    final summary = _map(json, 'summary');
    for (final status in PicoOperationalStatus.values) {
      final actual = records.where((entry) => entry.status == status).length;
      if (summary[status.name] != actual) {
        throw const FormatException('Pico status summary mismatch');
      }
    }
    final engineEnabled = records.where((entry) => entry.engineEnabled).length;
    if (summary['engineEnabled'] != engineEnabled ||
        summary['municipalities'] != records.length ||
        engineEnabled != 5) {
      throw const FormatException('Pico engine summary mismatch');
    }
    return PicoJurisdictionCatalog(
      records: List.unmodifiable(records),
      version: _string(json, 'version'),
      sourceCutoff: _date(json, 'sourceCutoff'),
      asOfDate: _date(json, 'asOfDate'),
      sourceWorkbookSha256: sourceSha,
    );
  }

  List<PicoJurisdictionCatalogEntry> search(String query) {
    final terms = normalizePicoJurisdictionText(query).split(' ');
    return List.unmodifiable(
      records.where((entry) {
        final text = normalizePicoJurisdictionText(
          '${entry.name} ${entry.selectorName} ${entry.department}',
        );
        return terms.every(text.contains);
      }),
    );
  }
}

String normalizePicoJurisdictionText(String value) {
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final unit in lower.runes) {
    final char = String.fromCharCode(unit);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw FormatException('Invalid Pico field: $key');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) =>
    json[key] == null ? null : _string(json, key);

String _date(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      DateTime.tryParse(value) == null) {
    throw FormatException('Invalid Pico date: $key');
  }
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid Pico boolean: $key');
  return value;
}

List<String> _strings(
  Map<String, Object?> json,
  String key, {
  bool allowEmpty = true,
}) {
  final value = json[key];
  if (value is! List ||
      value.any((item) => item is! String || item.trim().isEmpty) ||
      value.toSet().length != value.length ||
      (!allowEmpty && value.isEmpty)) {
    throw FormatException('Invalid Pico list: $key');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

Map<String, Object?> _map(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('Invalid Pico object: $key');
  }
  return value;
}
