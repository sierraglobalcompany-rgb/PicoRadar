import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/trip/application/trip_tile_config.dart';

void main() {
  test('tile access requires approval and every explicit provider field', () {
    const validUrl = 'https://tiles.example.test/{z}/{x}/{y}.png';
    const validAgent = 'co.picoradar.app';
    const validAttribution = 'Example Maps contributors';

    for (final config in [
      resolveTripTileConfig(
        approved: false,
        urlTemplate: validUrl,
        userAgent: validAgent,
        attribution: validAttribution,
      ),
      resolveTripTileConfig(
        approved: true,
        urlTemplate: 'http://tiles.example.test/{z}/{x}/{y}.png',
        userAgent: validAgent,
        attribution: validAttribution,
      ),
      resolveTripTileConfig(
        approved: true,
        urlTemplate: 'https://tiles.example.test/static.png',
        userAgent: validAgent,
        attribution: validAttribution,
      ),
      resolveTripTileConfig(
        approved: true,
        urlTemplate: validUrl,
        userAgent: '   ',
        attribution: validAttribution,
      ),
      resolveTripTileConfig(
        approved: true,
        urlTemplate: validUrl,
        userAgent: validAgent,
        attribution: '   ',
      ),
    ]) {
      expect(config.enabled, isFalse);
    }
  });

  test('approved alternate provider keeps its explicit attribution', () {
    final config = resolveTripTileConfig(
      approved: true,
      urlTemplate: 'https://tiles.alt.test/{z}/{x}/{y}.webp',
      userAgent: 'co.picoradar.alt',
      attribution: 'Alt Cartography 2026',
    );

    expect(config.enabled, isTrue);
    expect(config.urlTemplate, 'https://tiles.alt.test/{z}/{x}/{y}.webp');
    expect(config.userAgent, 'co.picoradar.alt');
    expect(config.attribution, 'Alt Cartography 2026');
  });
}
