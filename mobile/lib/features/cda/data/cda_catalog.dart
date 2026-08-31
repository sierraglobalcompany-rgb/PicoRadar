import 'dart:convert';

import 'package:flutter/services.dart';

const cdaCatalogAssetPath = 'assets/catalogs/cda_catalog_v1.json';
const cdaCatalogSourceUrl =
    'https://www.datos.gov.co/Transporte/ACTORES-RUNT-POR-MUNICIPIO-Y-DEPARTAMENTO-RUNT2-0/epfm-5fhb';

class CdaCatalog {
  const CdaCatalog({
    required this.source,
    required this.metrics,
    required this.entries,
  });

  final CdaCatalogSource source;
  final CdaCatalogMetrics metrics;
  final List<CdaCatalogEntry> entries;

  factory CdaCatalog.fromJsonString(String source) {
    final decoded = jsonDecode(source) as Map<String, Object?>;
    return CdaCatalog.fromJson(decoded);
  }

  factory CdaCatalog.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != 1) {
      throw const FormatException('Unsupported CDA catalog schema.');
    }
    return CdaCatalog(
      source: CdaCatalogSource.fromJson(json['source'] as Map<String, Object?>),
      metrics: CdaCatalogMetrics.fromJson(
        json['metrics'] as Map<String, Object?>,
      ),
      entries: [
        for (final item in json['entries'] as List<Object?>)
          CdaCatalogEntry.fromJson(item as Map<String, Object?>),
      ],
    );
  }
}

class CdaCatalogSource {
  const CdaCatalogSource({
    required this.provider,
    required this.datasetId,
    required this.datasetName,
    required this.sourceUrl,
    required this.sourceVerifiedAt,
    required this.latestSourceYear,
    required this.latestSourceMonth,
    required this.latestSourceMonthName,
  });

  final String provider;
  final String datasetId;
  final String datasetName;
  final String sourceUrl;
  final DateTime sourceVerifiedAt;
  final int latestSourceYear;
  final int latestSourceMonth;
  final String latestSourceMonthName;

  factory CdaCatalogSource.fromJson(Map<String, Object?> json) {
    return CdaCatalogSource(
      provider: _requiredString(json, 'provider'),
      datasetId: _requiredString(json, 'datasetId'),
      datasetName: _requiredString(json, 'datasetName'),
      sourceUrl: _requiredString(json, 'sourceUrl'),
      sourceVerifiedAt: DateTime.parse(
        _requiredString(json, 'sourceVerifiedAt'),
      ),
      latestSourceYear: _requiredInt(json, 'latestSourceYear'),
      latestSourceMonth: _requiredInt(json, 'latestSourceMonth'),
      latestSourceMonthName: _requiredString(json, 'latestSourceMonthName'),
    );
  }
}

class CdaCatalogMetrics {
  const CdaCatalogMetrics({
    required this.sourceRows,
    required this.cdaSourceRows,
    required this.latestSourcePeriod,
    required this.globalLatestSourcePeriod,
    required this.futureSourcePeriodsIgnored,
    required this.latestPeriodCdaRows,
    required this.currentUniqueCdaCount,
    required this.staleHistoricalCdaExcludedCount,
    required this.certificoNotSiCount,
    required this.unsafeNoveltyCount,
    required this.ambiguousCurrentDuplicateCount,
    required this.uniqueCdaCount,
    required this.excludedCurrentStatusCount,
    required this.municipalityCount,
    required this.departmentCount,
    required this.sponsoredCdaCount,
  });

  final int sourceRows;
  final int cdaSourceRows;
  final String latestSourcePeriod;
  final String globalLatestSourcePeriod;
  final bool futureSourcePeriodsIgnored;
  final int latestPeriodCdaRows;
  final int currentUniqueCdaCount;
  final int staleHistoricalCdaExcludedCount;
  final int certificoNotSiCount;
  final int unsafeNoveltyCount;
  final int ambiguousCurrentDuplicateCount;
  final int uniqueCdaCount;
  final int excludedCurrentStatusCount;
  final int municipalityCount;
  final int departmentCount;
  final int sponsoredCdaCount;

  factory CdaCatalogMetrics.fromJson(Map<String, Object?> json) {
    return CdaCatalogMetrics(
      sourceRows: _requiredInt(json, 'sourceRows'),
      cdaSourceRows: _requiredInt(json, 'cdaSourceRows'),
      latestSourcePeriod: _requiredString(json, 'latestSourcePeriod'),
      globalLatestSourcePeriod: _requiredString(
        json,
        'globalLatestSourcePeriod',
      ),
      futureSourcePeriodsIgnored: _requiredBool(
        json,
        'futureSourcePeriodsIgnored',
      ),
      latestPeriodCdaRows: _requiredInt(json, 'latestPeriodCdaRows'),
      currentUniqueCdaCount: _requiredInt(json, 'currentUniqueCdaCount'),
      staleHistoricalCdaExcludedCount: _requiredInt(
        json,
        'staleHistoricalCdaExcludedCount',
      ),
      certificoNotSiCount: _requiredInt(json, 'certificoNotSiCount'),
      unsafeNoveltyCount: _requiredInt(json, 'unsafeNoveltyCount'),
      ambiguousCurrentDuplicateCount: _requiredInt(
        json,
        'ambiguousCurrentDuplicateCount',
      ),
      uniqueCdaCount: _requiredInt(json, 'uniqueCdaCount'),
      excludedCurrentStatusCount: _requiredInt(
        json,
        'excludedCurrentStatusCount',
      ),
      municipalityCount: _requiredInt(json, 'municipalityCount'),
      departmentCount: _requiredInt(json, 'departmentCount'),
      sponsoredCdaCount: _requiredInt(json, 'sponsoredCdaCount'),
    );
  }
}

class CdaCatalogEntry {
  const CdaCatalogEntry({
    required this.id,
    required this.name,
    required this.nit,
    required this.municipality,
    required this.department,
    required this.departmentCode,
    required this.sourceYear,
    required this.sourceMonth,
    required this.sourceMonthName,
    required this.certified,
    required this.novelty,
    required this.sourceVerifiedAt,
    required this.generatedAt,
  });

  final String id;
  final String name;
  final String? nit;
  final String municipality;
  final String department;
  final String departmentCode;
  final int sourceYear;
  final int sourceMonth;
  final String sourceMonthName;
  final bool certified;
  final String novelty;
  final DateTime sourceVerifiedAt;
  final DateTime generatedAt;

  factory CdaCatalogEntry.fromJson(Map<String, Object?> json) {
    return CdaCatalogEntry(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      nit: _optionalString(json, 'nit'),
      municipality: _requiredString(json, 'municipality'),
      department: _requiredString(json, 'department'),
      departmentCode: _requiredString(json, 'departmentCode'),
      sourceYear: _requiredInt(json, 'sourceYear'),
      sourceMonth: _requiredInt(json, 'sourceMonth'),
      sourceMonthName: _requiredString(json, 'sourceMonthName'),
      certified: _requiredBool(json, 'certified'),
      novelty: _requiredString(json, 'novelty'),
      sourceVerifiedAt: DateTime.parse(
        _requiredString(json, 'sourceVerifiedAt'),
      ),
      generatedAt: DateTime.parse(_requiredString(json, 'generatedAt')),
    );
  }
}

class CdaSourceRow {
  const CdaSourceRow({
    required this.id,
    required this.name,
    this.nit,
    required this.municipality,
    required this.department,
    required this.departmentCode,
    required this.actorType,
    required this.sourceYear,
    required this.sourceMonth,
    required this.sourceMonthName,
    required this.certified,
    required this.novelty,
  });

  final String id;
  final String name;
  final String? nit;
  final String municipality;
  final String department;
  final String departmentCode;
  final String actorType;
  final int sourceYear;
  final int sourceMonth;
  final String sourceMonthName;
  final String certified;
  final String novelty;
}

Future<CdaCatalog> loadCdaCatalog(AssetBundle bundle) async {
  return CdaCatalog.fromJsonString(
    await bundle.loadString(cdaCatalogAssetPath),
  );
}

List<CdaCatalogEntry> searchCdaCatalog(
  Iterable<CdaCatalogEntry> entries,
  String query,
) {
  final terms = _normalize(query).split(' ').where((term) => term.isNotEmpty);
  final result = entries.where((entry) {
    final haystack = _normalize(
      '${entry.name} ${entry.municipality} ${entry.department}',
    );
    return terms.every(haystack.contains);
  }).toList();
  result.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
  return result;
}

List<CdaCatalogEntry> currentOfficialCdaEntries(
  Iterable<CdaSourceRow> rows, {
  required DateTime timestamp,
  SourcePeriod? latestAcceptedPeriod,
}) {
  final rowList = rows.toList(growable: false);
  final acceptedPeriod =
      latestAcceptedPeriod ?? latestNonFutureSourcePeriod(rowList, timestamp);
  final rowsById = <String, List<CdaSourceRow>>{};
  for (final row in rowList) {
    if (row.id.trim().isEmpty || row.actorType.trim().toUpperCase() != 'CDA') {
      continue;
    }
    if (SourcePeriod.fromRow(row) == acceptedPeriod) {
      rowsById.putIfAbsent(row.id.trim(), () => []).add(row);
    }
  }
  final entries = <CdaCatalogEntry>[];
  for (final rowsForId in rowsById.values) {
    if (_hasAmbiguousCurrentRows(rowsForId)) {
      continue;
    }
    final row = rowsForId.first;
    if (!_isSafeCurrentCda(row) ||
        row.name.trim().isEmpty ||
        row.municipality.trim().isEmpty ||
        row.department.trim().isEmpty ||
        row.departmentCode.trim().isEmpty) {
      continue;
    }
    entries.add(
      CdaCatalogEntry(
        id: row.id.trim(),
        name: row.name.trim(),
        nit: row.nit?.trim().isEmpty ?? true ? null : row.nit!.trim(),
        municipality: row.municipality.trim(),
        department: row.department.trim(),
        departmentCode: row.departmentCode.trim(),
        sourceYear: row.sourceYear,
        sourceMonth: row.sourceMonth,
        sourceMonthName: row.sourceMonthName.trim(),
        certified: true,
        novelty: row.novelty.trim().toUpperCase(),
        sourceVerifiedAt: timestamp,
        generatedAt: timestamp,
      ),
    );
  }
  entries.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
  return entries;
}

SourcePeriod latestNonFutureSourcePeriod(
  Iterable<CdaSourceRow> rows,
  DateTime timestamp,
) {
  final currentPeriod = SourcePeriod(timestamp.year, timestamp.month);
  final periods = rows
      .where((row) => row.actorType.trim().toUpperCase() == 'CDA')
      .map(SourcePeriod.fromRow)
      .where((period) => period.compareTo(currentPeriod) <= 0)
      .toList();
  if (periods.isEmpty) {
    throw const FormatException('No non-future CDA source period.');
  }
  periods.sort();
  return periods.last;
}

class SourcePeriod implements Comparable<SourcePeriod> {
  const SourcePeriod(this.year, this.month);

  factory SourcePeriod.fromRow(CdaSourceRow row) {
    return SourcePeriod(row.sourceYear, row.sourceMonth);
  }

  final int year;
  final int month;

  @override
  int compareTo(SourcePeriod other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) {
      return yearComparison;
    }
    return month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) {
    return other is SourcePeriod && other.year == year && other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}

String cdaCatalogUpdateLabel(CdaCatalog catalog) {
  return 'Directorio RUNT · Actualizado '
      '${_monthName(catalog.source.latestSourceMonth)} '
      '${catalog.source.latestSourceYear}';
}

bool isCdaCatalogStale(CdaCatalog catalog, DateTime now) {
  final latest = DateTime(
    catalog.source.latestSourceYear,
    catalog.source.latestSourceMonth,
  );
  return DateTime(now.year, now.month).difference(latest).inDays > 62;
}

String _sortKey(CdaCatalogEntry entry) {
  return _normalize('${entry.department} ${entry.municipality} ${entry.name}');
}

bool _isSafeCurrentCda(CdaSourceRow row) {
  return row.actorType.trim().toUpperCase() == 'CDA' &&
      row.certified.trim().toUpperCase() == 'SI' &&
      row.novelty.trim().toUpperCase() == 'NO';
}

bool _hasAmbiguousCurrentRows(List<CdaSourceRow> rows) {
  final signatures = {
    for (final row in rows)
      (
        row.name.trim(),
        row.nit?.trim(),
        row.municipality.trim(),
        row.department.trim(),
        row.departmentCode.trim(),
        row.certified.trim().toUpperCase(),
        row.novelty.trim().toUpperCase(),
      ),
  };
  return signatures.length > 1;
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
}

String _monthName(int month) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return months[month - 1];
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Missing CDA string field: $key');
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  throw FormatException('Invalid CDA string field: $key');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('Missing CDA integer field: $key');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Missing CDA boolean field: $key');
}
