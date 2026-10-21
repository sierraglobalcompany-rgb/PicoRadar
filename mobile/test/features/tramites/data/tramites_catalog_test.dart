import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/comparendos/data/territorial_catalog.dart';
import 'package:picoradar/features/tramites/data/tramites_catalog.dart';

void main() {
  late TramitesCatalog catalog;

  setUp(() {
    final json = jsonDecode(
      File(territorialCatalogAssetPath).readAsStringSync(),
    ) as Map<String, Object?>;
    catalog = TramitesCatalog.fromTerritorial(
      TerritorialCatalog.fromJson(json),
    );
  });

  test('retains the versioned national inventory and source counts', () {
    expect(catalog.version, '2026-09-15.purchase-directory-v1');
    expect(catalog.reviewedAt, '2026-09-13');
    expect(catalog.procedureReviewedAt, '2026-09-15');
    expect(catalog.authorities, hasLength(769));
    expect(catalog.sourceRowCount, 1003);
    expect(catalog.sources.map((source) => source.observedRowCount), [
      398,
      308,
      297,
    ]);
  });

  test('only Bogota and Medellin expose reviewed direct procedures', () {
    final direct = catalog.authorities
        .where((entry) => entry.hasDirectProcedures)
        .toList();
    expect(direct.map((entry) => entry.id).toSet(), {
      'co-bogota',
      'co-medellin',
    });
    expect(direct, hasLength(2));
    for (final authority in direct) {
      expect(authority.status, TramitesAuthorityStatus.verifiedDirect);
      expect(authority.procedures, hasLength(4));
      expect(
        authority.procedures.every((item) => item.url.startsWith('https://')),
        isTrue,
      );
    }
  });

  test('keeps institution and RUNT fallbacks explicitly unconfirmed', () {
    final institution = catalog.authorities.where(
      (entry) => entry.fallbackKind == TramitesFallbackKind.institution,
    );
    final runt = catalog.authorities.where(
      (entry) => entry.fallbackKind == TramitesFallbackKind.runtDirectory,
    );

    expect(institution, hasLength(5));
    expect(runt, hasLength(762));
    expect(institution.map((entry) => entry.id).toSet(), {
      'co-barranquilla',
      'co-bucaramanga',
      'co-itagui',
      'co-pereira',
      'co-manizales',
    });
    for (final authority in [...institution, ...runt]) {
      expect(authority.status, TramitesAuthorityStatus.pending);
      expect(authority.statusLabel, 'Por confirmar');
      expect(authority.procedures, isEmpty);
      expect(authority.fallbackUrl, isNotNull);
    }
    expect(
      runt.every((entry) => entry.fallbackUrl == runtActorsDirectoryUrl),
      isTrue,
    );
  });

  test('search is national, accent-insensitive and matches all terms', () {
    expect(catalog.search(''), hasLength(769));
    expect(
      catalog.search('medellin antioquia').map((entry) => entry.id),
      contains('co-medellin'),
    );
    expect(catalog.search('NARIÑO tránsito'), isNotEmpty);
    expect(
      catalog
          .search('municipio envigado')
          .every(
            (entry) =>
                normalizeTerritorialText(entry.department) == 'antioquia',
          ),
      isTrue,
    );
    expect(catalog.search('consulta inexistente'), isEmpty);
  });
}
