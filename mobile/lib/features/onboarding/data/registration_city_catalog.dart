import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const registrationCityCatalogAssetPath =
    'assets/catalogs/colombia_registration_cities_v1.json';

final registrationCityCatalogProvider = FutureProvider<RegistrationCityCatalog>(
  (ref) async {
    final raw = await rootBundle.loadString(registrationCityCatalogAssetPath);
    return RegistrationCityCatalog.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
  },
);

class RegistrationCity {
  const RegistrationCity({
    required this.municipality,
    required this.department,
    required this.displayName,
    required this.source,
  });

  final String municipality;
  final String department;
  final String displayName;
  final String source;

  factory RegistrationCity.fromJson(Map<String, Object?> json) {
    return RegistrationCity(
      municipality: json['municipality'] as String,
      department: json['department'] as String,
      displayName: json['displayName'] as String,
      source: json['source'] as String,
    );
  }
}

class RegistrationCityCatalog {
  const RegistrationCityCatalog({required this.records});

  final List<RegistrationCity> records;

  factory RegistrationCityCatalog.fromJson(Map<String, Object?> json) {
    final rows = json['records'];
    if (rows is! List) {
      return const RegistrationCityCatalog(records: []);
    }
    return RegistrationCityCatalog(
      records: [
        for (final row in rows)
          if (row is Map<String, Object?>) RegistrationCity.fromJson(row),
      ],
    );
  }

  List<RegistrationCity> search(String query, {int limit = 24}) {
    final normalizedQuery = normalizeRegistrationCityText(query);
    final source = normalizedQuery.isEmpty
        ? records
        : records.where((city) {
            return normalizeRegistrationCityText(
              '${city.municipality} ${city.department} ${city.displayName}',
            ).contains(normalizedQuery);
          });
    return source.take(limit).toList(growable: false);
  }

  bool containsDisplayName(String value) {
    final normalized = normalizeRegistrationCityText(value);
    return normalized.isNotEmpty &&
        records.any(
          (city) =>
              normalizeRegistrationCityText(city.displayName) == normalized,
        );
  }
}

String normalizeRegistrationCityText(String value) {
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
