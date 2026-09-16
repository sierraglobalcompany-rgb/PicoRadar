import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';
import 'package:picoradar/features/cda/data/cda_geography.dart';
import 'package:picoradar/features/cda/domain/cda_spatial_query.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14);
  final entries = [
    fictionalEntry('a', name: 'CDA Alameda', city: 'Villa Clara'),
    fictionalEntry('b', name: 'CDA Norte', city: 'Villa Clara'),
    fictionalEntry('c', name: 'CDA Alameda', city: 'Puerto Azul'),
  ];
  final catalog = fictionalCatalog(entries);
  final geography = fictionalGeography(
    entries,
    coordinates: const [LatLng(4, -74), LatLng(4.05, -74), LatLng(5, -74)],
  );

  test('AND tokens and territory and evidenced types intersect', () {
    final results = queryCdaSites(
      catalog: catalog,
      geography: geography,
      now: now,
      query: 'alameda VILLA',
      municipality: 'Villa Clara',
      departmentCode: '99',
      vehicleTypes: {'car'},
    );
    expect(results.map((r) => r.entry.id), ['a']);
    expect(
      queryCdaSites(
        catalog: catalog,
        geography: geography,
        now: now,
        query: 'alameda nonexistent',
      ),
      isEmpty,
    );
    expect(
      queryCdaSites(
        catalog: catalog,
        geography: geography,
        now: now,
        vehicleTypes: {'motorcycle'},
      ),
      isEmpty,
    );
  });

  test('radius is local, distance ordered and viewport reveals more IDs', () {
    final nearby = queryCdaSites(
      catalog: catalog,
      geography: geography,
      now: now,
      origin: const LatLng(4.049, -74),
      radiusMeters: 15000,
    );
    expect(nearby.map((r) => r.entry.id), ['b', 'a']);
    expect(nearby.first.distanceMeters, closeTo(111, 2));
    final expanded = queryCdaSites(
      catalog: catalog,
      geography: geography,
      now: now,
      bounds: CdaSpatialBounds.national,
    );
    expect(expanded.map((r) => r.entry.id).toSet(), {'a', 'b', 'c'});
  });

  test(
    'inclusive viewport preserves true coordinates and catalogue identity',
    () {
      final results = queryCdaSites(
        catalog: catalog,
        geography: geography,
        now: now,
        bounds: const CdaSpatialBounds(
          south: 4,
          west: -74,
          north: 4.05,
          east: -73,
        ),
      );
      expect(results.map((r) => r.entry.id).toSet(), {'a', 'b'});
      expect(identical(results.first.entry, entries.first), isTrue);
      expect(results.first.site.latitude, 4);
      expect(CdaSpatialBounds.national.contains(12.58, -81.7), isTrue);
    },
  );

  test('unverified or mismatched site never acquires another identity', () {
    final invalid = CdaGeography(
      version: 'fictional',
      catalogPeriod: '2026-07',
      approved: true,
      sites: [
        CdaSite(
          cdaId: 'a',
          catalogName: 'Wrong name',
          municipality: 'Villa Clara',
          departmentCode: '99',
          status: 'verified',
          latitude: 4,
          longitude: -74,
          address: 'Fictional address',
          locationSources: [
            CdaEvidence(url: 'https://example.org/fixture', reviewedAt: now),
          ],
        ),
      ],
    );
    expect(
      queryCdaSites(catalog: catalog, geography: invalid, now: now),
      isEmpty,
    );
    final pending = CdaGeography(
      version: 'fictional',
      catalogPeriod: '2026-07',
      approved: false,
      sites: [
        CdaSite(
          cdaId: 'a',
          catalogName: entries[0].name,
          municipality: entries[0].municipality,
          departmentCode: '99',
          status: 'pending',
        ),
      ],
    );
    expect(
      queryCdaSites(catalog: catalog, geography: pending, now: now),
      isEmpty,
    );
  });

  test(
    '64 dp groups are deterministic, complete, and anchored at a real site',
    () {
      final matches = queryCdaSites(
        catalog: catalog,
        geography: geography,
        now: now,
      );
      ({double x, double y}) project(double lat, double lon) => (x: 5, y: 5);
      final groups = groupCdaSites(matches, project: project);
      final reversed = groupCdaSites(matches.reversed, project: project);
      expect(groups.single.members.map((r) => r.entry.id), ['a', 'b', 'c']);
      expect(reversed.single.members.map((r) => r.entry.id), ['a', 'b', 'c']);
      expect(groups.single.anchor.entry.id, 'a');
      expect(groups.single.anchor.site.latitude, 4);
      final split = groupCdaSites(
        matches,
        project: (lat, lon) => (x: lat == 4 ? 63.9 : 64, y: 0),
      );
      expect(split, hasLength(2));
      expect(split.expand((g) => g.members).map((r) => r.entry.id).toSet(), {
        'a',
        'b',
        'c',
      });
    },
  );

  test('no first-40 cap on dense or coincident results', () {
    final many = List.generate(90, (i) => fictionalEntry('fixture-$i'));
    final results = queryCdaSites(
      catalog: fictionalCatalog(many),
      geography: fictionalGeography(many),
      now: now,
    );
    expect(results, hasLength(90));
    expect(
      groupCdaSites(
        results,
        project: (lat, lon) => (x: 0, y: 0),
      ).single.members,
      hasLength(90),
    );
  });
}

// Entirely fictional inventory, never loaded from the shipping catalogue.
CdaCatalogEntry fictionalEntry(
  String id, {
  String? name,
  String city = 'Villa Clara',
}) => CdaCatalogEntry(
  id: id,
  name: name ?? 'CDA ficticio $id',
  nit: null,
  municipality: city,
  department: 'Departamento ficticio',
  departmentCode: '99',
  sourceYear: 2026,
  sourceMonth: 7,
  sourceMonthName: 'julio',
  certified: true,
  novelty: 'NO',
  sourceVerifiedAt: DateTime.utc(2026, 7, 1),
  generatedAt: DateTime.utc(2026, 7, 1),
);

CdaCatalog fictionalCatalog(List<CdaCatalogEntry> entries) => CdaCatalog(
  source: CdaCatalogSource(
    provider: 'Fictional fixture',
    datasetId: 'fictional',
    datasetName: 'Fictional CDA',
    sourceUrl: 'https://example.org/fixture',
    sourceVerifiedAt: DateTime.utc(2026, 7, 1),
    latestSourceYear: 2026,
    latestSourceMonth: 7,
    latestSourceMonthName: 'julio',
  ),
  metrics: CdaCatalogMetrics(
    sourceRows: entries.length,
    cdaSourceRows: entries.length,
    latestSourcePeriod: '2026-07',
    globalLatestSourcePeriod: '2026-07',
    futureSourcePeriodsIgnored: false,
    latestPeriodCdaRows: entries.length,
    currentUniqueCdaCount: entries.length,
    staleHistoricalCdaExcludedCount: 0,
    certificoNotSiCount: 0,
    unsafeNoveltyCount: 0,
    ambiguousCurrentDuplicateCount: 0,
    uniqueCdaCount: entries.length,
    excludedCurrentStatusCount: 0,
    municipalityCount: 1,
    departmentCount: 1,
    sponsoredCdaCount: 0,
  ),
  entries: entries,
);

CdaGeography fictionalGeography(
  List<CdaCatalogEntry> entries, {
  List<LatLng>? coordinates,
}) => CdaGeography(
  version: 'fictional',
  catalogPeriod: '2026-07',
  approved: true,
  sites: [
    for (var i = 0; i < entries.length; i++)
      CdaSite(
        cdaId: entries[i].id,
        catalogName: entries[i].name,
        municipality: entries[i].municipality,
        departmentCode: entries[i].departmentCode,
        status: 'verified',
        latitude: coordinates?[i].latitude ?? 4,
        longitude: coordinates?[i].longitude ?? -74,
        address: 'Fictional address $i',
        vehicleTypes: {'car'},
        locationSources: [
          CdaEvidence(
            url: 'https://example.org/fixture',
            reviewedAt: DateTime.utc(2026, 7, 1),
          ),
        ],
        compatibilitySources: [
          CdaEvidence(
            url: 'https://example.org/fixture',
            reviewedAt: DateTime.utc(2026, 7, 1),
          ),
        ],
      ),
  ],
);
