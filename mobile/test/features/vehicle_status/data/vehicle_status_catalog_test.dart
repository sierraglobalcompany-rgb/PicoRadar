import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_status_catalog.dart';

void main() {
  group('vehicle status catalog', () {
    test('official links are HTTPS and host-validated', () {
      final links = [runtVehicleByPlateLink, fasecoldaAutomovilesLink];

      for (final link in links) {
        final uri = Uri.parse(link.uri);
        expect(uri.scheme, 'https');
        expect(uri.host, link.allowedHost);
      }
    });

    test('RUNT link is shared by SOAT and RTM checks', () {
      expect(runtVehicleByPlateLink.id, 'runt-vehicle-by-plate');
      expect(runtVehicleByPlateLink.sourceName, 'RUNT');
      expect(
        runtVehicleByPlateLink.uri,
        contains('/consulta-de-vehiculos-por-placa'),
      );
    });

    test('insurance providers come from Fasecolda list with other option', () {
      expect(insuranceProviderOptions, contains('Allianz Colombia'));
      expect(
        insuranceProviderOptions,
        contains('Seguros Generales Suramericana S.A.'),
      );
      expect(insuranceProviderOptions.last, 'Otra / no aparece');
    });

    test('tax authority hint preserves existing clear pilot cities', () {
      expect(suggestTaxAuthorityId('Bogota'), 'bogota');
      expect(suggestTaxAuthorityId('Bogotá'), 'bogota');
      expect(suggestTaxAuthorityId('Bogotá D.C.'), 'bogota');
      expect(suggestTaxAuthorityId('Bogota DC'), 'bogota');
      expect(suggestTaxAuthorityId('Bogotá - Bogotá D.C.'), 'bogota');
      expect(suggestTaxAuthorityId('Medellin'), 'antioquia');
      expect(suggestTaxAuthorityId('Medellín'), 'antioquia');
      expect(suggestTaxAuthorityId('Medellín, Antioquia'), 'antioquia');
      expect(suggestTaxAuthorityId('Medellin Antioquia'), 'antioquia');
      expect(suggestTaxAuthorityId('Bello'), isNull);
      expect(suggestTaxAuthorityId('Cali'), isNull);
    });
  });
}
