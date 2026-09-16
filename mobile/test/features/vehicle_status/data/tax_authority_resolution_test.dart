import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/tax_authority_resolution.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';

void main() {
  final catalog = TaxCatalog.fromJsonString(
    File(bundledTaxCatalogAsset).readAsStringSync(),
  );
  final cities = RegistrationCityCatalog.fromJson(
    jsonDecode(File(registrationCityCatalogAssetPath).readAsStringSync())
        as Map<String, Object?>,
  );

  test('resolves national registration entries and existing pilot aliases', () {
    expect(
      suggestTaxAuthority(catalog, cities, 'Zipaquirá - Cundinamarca'),
      'cundinamarca',
    );
    expect(
      suggestTaxAuthority(catalog, cities, 'Bucaramanga - Santander'),
      'santander',
    );
    expect(suggestTaxAuthority(catalog, null, 'Bogotá D.C.'), 'bogota');
    expect(
      suggestTaxAuthority(catalog, null, 'Medellín, Antioquia'),
      'antioquia',
    );
  });

  test('resolves island department alias by DANE territory code', () {
    final id = suggestTaxAuthority(
      catalog,
      cities,
      'San Andrés - Archipielago De San Andres, Providencia',
    );
    expect(catalog.authorityById(id)?.territoryCode, '88');
  });

  test('unknown, unloaded and ambiguous registration remains unassigned', () {
    expect(suggestTaxAuthority(catalog, cities, null), isNull);
    expect(suggestTaxAuthority(catalog, cities, '   '), isNull);
    expect(
      suggestTaxAuthority(catalog, cities, 'Municipio inexistente'),
      isNull,
    );
    expect(suggestTaxAuthority(catalog, null, 'Zipaquira'), isNull);
    const ambiguous = RegistrationCityCatalog(
      records: [
        RegistrationCity(
          municipality: 'Compartido',
          department: 'Cundinamarca',
          displayName: 'Compartido - Cundinamarca',
          source: 'test',
        ),
        RegistrationCity(
          municipality: 'Compartido',
          department: 'Santander',
          displayName: 'Compartido - Santander',
          source: 'test',
        ),
      ],
    );
    expect(suggestTaxAuthority(catalog, ambiguous, 'Compartido'), isNull);
    expect(
      suggestTaxAuthority(catalog, ambiguous, 'Compartido - Santander'),
      'santander',
    );
  });
}
