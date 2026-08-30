import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';

void main() {
  test('catalog parses official OT city records uniquely', () {
    final catalog = _loadCatalog();
    final keys = <String>{};

    for (final city in catalog.records) {
      expect(city.source, 'epfm-5fhb');
      expect(city.displayName, '${city.municipality} - ${city.department}');
      expect(
        keys.add(normalizeRegistrationCityText(city.displayName)),
        isTrue,
        reason: city.displayName,
      );
    }

    expect(catalog.records.length, greaterThan(250));
  });

  test('search matches municipality and department without accents', () {
    final catalog = _loadCatalog();

    expect(
      catalog.search('medellin').map((city) => city.displayName),
      contains('Medellín - Antioquia'),
    );
    expect(
      catalog.search('santander').map((city) => city.displayName),
      contains('Bucaramanga - Santander'),
    );
    expect(
      catalog.search('envigado antioquia').map((city) => city.displayName),
      contains('Envigado - Antioquia'),
    );
  });
}

RegistrationCityCatalog _loadCatalog() {
  final raw = File(
    registrationCityCatalogAssetPath.replaceFirst('assets/', 'assets/'),
  ).readAsStringSync();
  return RegistrationCityCatalog.fromJson(
    jsonDecode(raw) as Map<String, Object?>,
  );
}
