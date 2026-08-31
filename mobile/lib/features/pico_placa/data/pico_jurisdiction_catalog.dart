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

class PicoJurisdictionCatalogEntry {
  const PicoJurisdictionCatalogEntry({
    required this.id,
    required this.name,
    required this.department,
    required this.classification,
    required this.sourceDate,
  });

  final String id;
  final String name;
  final String department;
  final String classification;
  final String sourceDate;

  String get displayName => '$name, Colombia';

  factory PicoJurisdictionCatalogEntry.fromJson(Map<String, Object?> json) {
    return PicoJurisdictionCatalogEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      department: json['department'] as String,
      classification: json['classification'] as String,
      sourceDate: json['sourceDate'] as String,
    );
  }
}

class PicoJurisdictionCatalog {
  const PicoJurisdictionCatalog({required this.records});

  final List<PicoJurisdictionCatalogEntry> records;

  factory PicoJurisdictionCatalog.fromJson(Map<String, Object?> json) {
    final rows = json['records'];
    if (rows is! List) {
      return const PicoJurisdictionCatalog(records: []);
    }
    return PicoJurisdictionCatalog(
      records: [
        for (final row in rows)
          if (row is Map<String, Object?>)
            PicoJurisdictionCatalogEntry.fromJson(row),
      ],
    );
  }

  List<PicoJurisdictionCatalogEntry> search(String query) {
    final normalizedQuery = normalizePicoJurisdictionText(query);
    final source = normalizedQuery.isEmpty
        ? records
        : records.where((entry) {
            return normalizePicoJurisdictionText(
              '${entry.name} ${entry.department}',
            ).contains(normalizedQuery);
          });
    return source.toList(growable: false);
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
