import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/services/data/google_maps_service_search.dart';

void main() {
  test('builds the official Google Maps search URL with Uri', () {
    final uri = googleMapsServiceSearchUri(
      category: 'grúa 24 horas',
      city: 'Bogotá D. C.',
    );

    expect(uri.scheme, 'https');
    expect(uri.host, googleMapsSearchHost);
    expect(uri.path, googleMapsSearchPath);
    expect(uri.queryParameters, {
      'api': '1',
      'query': 'grúa 24 horas Bogotá D. C.',
    });
    expect(
      uri.toString(),
      startsWith('https://www.google.com/maps/search/?api=1&query='),
    );
  });
}
