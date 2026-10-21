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

  for (final point in [
    (name: 'Rionegro', lat: 6.1536166, lon: -75.3741691),
    (name: 'Bello', lat: 6.33778, lon: -75.5444),
    (name: 'Envigado', lat: 6.1706, lon: -75.5877),
  ]) {
    test('does not assign Medellin to ${point.name}', () {
      expect(
        resolveJurisdictionForPosition(
          latitude: point.lat,
          longitude: point.lon,
          supportedJurisdictions: jurisdictions,
        ),
        isNull,
      );
    });
  }

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

  test('requires the accuracy circle to fit inside the detection core', () {
    String? resolve(double accuracy) => resolveJurisdictionForPosition(
      latitude: 6.2442,
      longitude: -75.5812,
      accuracyMeters: accuracy,
      supportedJurisdictions: jurisdictions,
      hints: const [
        JurisdictionLocationHint(
          jurisdictionId: 'co-ant-medellin',
          centerLat: 6.2442,
          centerLon: -75.5812,
          maxDetectionRadiusKm: 0.1,
        ),
      ],
    );
    expect(resolve(50), 'co-ant-medellin');
    expect(resolve(150), isNull);
    expect(resolve(double.nan), isNull);
    expect(resolve(-1), isNull);
    expect(resolve(5000), isNull);
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
