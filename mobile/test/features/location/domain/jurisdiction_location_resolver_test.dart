import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/location/domain/jurisdiction_location_resolver.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';

void main() {
  const jurisdictions = [
    RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogota'),
    RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellin'),
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

  test('fails closed outside supported coverage', () {
    final result = resolveJurisdictionForPosition(
      latitude: 10.3910,
      longitude: -75.4794,
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
}
