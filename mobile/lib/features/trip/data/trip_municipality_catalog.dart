import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pico_placa/data/pico_jurisdiction_catalog.dart';

const tripMunicipalityCatalogAssetPath =
    'assets/catalogs/colombia_trip_municipalities_v1.json';

final tripMunicipalityCatalogProvider = FutureProvider<TripMunicipalityCatalog>(
  (ref) async {
    final raw = await rootBundle.loadString(tripMunicipalityCatalogAssetPath);
    return TripMunicipalityCatalog.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
  },
);

class TripMunicipality {
  const TripMunicipality({
    required this.code,
    required this.municipality,
    required this.department,
    this.jurisdictionId,
  });

  final String code;
  final String municipality;
  final String department;
  final String? jurisdictionId;

  String get displayName => '$municipality · $department';

  factory TripMunicipality.fromJson(Map<String, Object?> json) {
    return TripMunicipality(
      code: json['code'] as String,
      municipality: json['municipality'] as String,
      department: json['department'] as String,
      jurisdictionId: json['jurisdictionId'] as String?,
    );
  }
}

class TripMunicipalityCatalog {
  const TripMunicipalityCatalog({required this.records});

  final List<TripMunicipality> records;

  factory TripMunicipalityCatalog.fromJson(Map<String, Object?> json) {
    final rows = json['records'];
    if (rows is! List) {
      return const TripMunicipalityCatalog(records: []);
    }
    return TripMunicipalityCatalog(
      records: [
        for (final row in rows)
          if (row is Map<String, Object?>) TripMunicipality.fromJson(row),
      ],
    );
  }

  List<TripMunicipality> search(String query, {int limit = 12}) {
    final normalizedQuery = normalizePicoJurisdictionText(query);
    final letterCount = RegExp(r'[a-z]').allMatches(normalizedQuery).length;
    if (letterCount < 3) {
      return const [];
    }
    return records
        .where(
          (entry) => normalizePicoJurisdictionText(
            '${entry.municipality} ${entry.department}',
          ).contains(normalizedQuery),
        )
        .take(limit)
        .toList(growable: false);
  }

  TripMunicipality? findExact(String value) {
    final normalizedValue = normalizePicoJurisdictionText(value);
    if (normalizedValue.isEmpty) {
      return null;
    }
    final displayMatches = records.where(
      (entry) =>
          normalizePicoJurisdictionText(entry.displayName) == normalizedValue,
    );
    if (displayMatches.length == 1) {
      return displayMatches.single;
    }
    final municipalityMatches = records.where((entry) {
      final municipality = normalizePicoJurisdictionText(entry.municipality);
      return municipality == normalizedValue ||
          municipality.startsWith('$normalizedValue,');
    });
    if (municipalityMatches.length == 1) {
      return municipalityMatches.single;
    }
    return null;
  }
}
