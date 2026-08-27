import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_status_catalog.dart';

void main() {
  group('vehicle status catalog', () {
    test('official links are HTTPS and host-validated', () {
      final links = [
        runtVehicleByPlateLink,
        fasecoldaAutomovilesLink,
        for (final calendar in vehicleTaxCalendars) calendar.portalLink,
      ];

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

    test('tax calendar only auto-suggests clear pilot cities', () {
      expect(suggestTaxCalendar('Bogota')?.authorityId, 'bogota');
      expect(suggestTaxCalendar('Bogotá')?.authorityId, 'bogota');
      expect(suggestTaxCalendar('Medellin')?.authorityId, 'antioquia');
      expect(suggestTaxCalendar('Medellín')?.authorityId, 'antioquia');
      expect(suggestTaxCalendar('Cali'), isNull);
    });

    test(
      'Bogota calendar includes verified 2026 dates and semaforizacion note',
      () {
        final calendar = taxCalendarByAuthority('bogota')!;

        expect(calendar.year, 2026);
        expect(
          calendar.portalLink.sourceName,
          'Secretaría Distrital de Hacienda',
        );
        expect(
          calendar.importantDates.map((date) => date.date),
          contains(DateTime(2026, 5, 15)),
        );
        expect(
          calendar.importantDates.map((date) => date.label),
          contains('Derechos de semaforización: consulta el portal oficial'),
        );
      },
    );

    test('Antioquia calendar is present without Bogota-only notes', () {
      final calendar = taxCalendarByAuthority('antioquia')!;

      expect(calendar.year, 2026);
      expect(
        calendar.importantDates.map((date) => date.date),
        contains(DateTime(2026, 7, 31)),
      );
      expect(
        calendar.importantDates.map((date) => date.label),
        isNot(
          contains('Derechos de semaforización: consulta el portal oficial'),
        ),
      );
    });
  });
}
