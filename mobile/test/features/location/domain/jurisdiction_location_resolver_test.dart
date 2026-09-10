import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/location/domain/jurisdiction_location_resolver.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';

void main() {
  const jurisdictions = [
    RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogota'),
    RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellin'),
    RestrictionJurisdiction(id: 'co-atl-barranquilla', name: 'Barranquilla'),
    RestrictionJurisdiction(id: 'co-cal-manizales', name: 'Manizales'),
    RestrictionJurisdiction(id: 'co-san-bucaramanga', name: 'Bucaramanga'),
    RestrictionJurisdiction(id: 'co-cau-popayan', name: 'Popayan'),
    RestrictionJurisdiction(id: 'co-met-villavicencio', name: 'Villavicencio'),
  ];

  test('resolves a supported jurisdiction near Bogota', () {
    final result = resolveJurisdictionForPosition(
      latitude: 4.7110,
      longitude: -74.0721,
      supportedJurisdictions: jurisdictions,
    );

    expect(result, 'co-dc-bogota');
  });

  test('resolves a supported jurisdiction near Medellin', () {
    final result = resolveJurisdictionForPosition(
      latitude: 6.2442,
      longitude: -75.5812,
      supportedJurisdictions: jurisdictions,
    );

    expect(result, 'co-ant-medellin');
  });

  test(
    'resolves every supported current city with active restriction data',
    () {
      const samples = <String, ({double lat, double lon})>{
        'co-dc-bogota': (lat: 4.7110, lon: -74.0721),
        'co-ant-medellin': (lat: 6.2442, lon: -75.5812),
        'co-atl-barranquilla': (lat: 10.9685, lon: -74.7813),
        'co-cal-manizales': (lat: 5.0703, lon: -75.5138),
        'co-san-bucaramanga': (lat: 7.1193, lon: -73.1227),
        'co-cau-popayan': (lat: 2.4448, lon: -76.6147),
        'co-met-villavicencio': (lat: 4.1420, lon: -73.6266),
      };

      for (final entry in samples.entries) {
        final result = resolveJurisdictionForPosition(
          latitude: entry.value.lat,
          longitude: entry.value.lon,
          supportedJurisdictions: jurisdictions,
        );

        expect(result, entry.key);
      }
    },
  );

  test('fails closed outside supported coverage', () {
    final result = resolveJurisdictionForPosition(
      latitude: 3.4516,
      longitude: -76.5320,
      supportedJurisdictions: jurisdictions,
    );

    expect(result, isNull);
  });

  test('fails closed when detection is ambiguous', () {
    final result = resolveJurisdictionForPosition(
      latitude: 4.0,
      longitude: -74.0,
      supportedJurisdictions: jurisdictions,
      hints: const [
        JurisdictionLocationHint(
          jurisdictionId: 'co-dc-bogota',
          centerLat: 4.0,
          centerLon: -74.0,
          maxDetectionRadiusKm: 100,
        ),
        JurisdictionLocationHint(
          jurisdictionId: 'co-ant-medellin',
          centerLat: 4.1,
          centerLon: -74.1,
          maxDetectionRadiusKm: 100,
        ),
      ],
    );

    expect(result, isNull);
  });

  test('ignores hints for unsupported jurisdictions', () {
    final result = resolveJurisdictionForPosition(
      latitude: 4.7110,
      longitude: -74.0721,
      supportedJurisdictions: const [
        RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellin'),
      ],
    );

    expect(result, isNull);
  });

  test('ignores conditioned cities without automatic coverage', () {
    final result = resolveJurisdictionForPosition(
      latitude: 10.3910,
      longitude: -75.4794,
      supportedJurisdictions: jurisdictions,
    );

    expect(result, isNull);
  });
}
