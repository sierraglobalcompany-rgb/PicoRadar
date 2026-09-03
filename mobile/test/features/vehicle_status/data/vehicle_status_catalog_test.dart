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
      expect(suggestTaxCalendar('Bogotá D.C.')?.authorityId, 'bogota');
      expect(suggestTaxCalendar('Bogota DC')?.authorityId, 'bogota');
      expect(suggestTaxCalendar('Bogotá - Bogotá D.C.')?.authorityId, 'bogota');
      expect(suggestTaxCalendar('Medellin')?.authorityId, 'antioquia');
      expect(suggestTaxCalendar('Medellín')?.authorityId, 'antioquia');
      expect(
        suggestTaxCalendar('Medellín, Antioquia')?.authorityId,
        'antioquia',
      );
      expect(
        suggestTaxCalendar('Medellin Antioquia')?.authorityId,
        'antioquia',
      );
      expect(suggestTaxCalendar('Bello'), isNull);
      expect(suggestTaxCalendar('Cali'), isNull);
    });

    test(
      'tax calendars are current only for their own year before stale date',
      () {
        final bogota = taxCalendarByAuthority('bogota')!;

        expect(bogota.isCurrent(DateTime(2025, 12, 31)), isFalse);
        expect(bogota.isCurrent(DateTime(2026, 9, 3)), isTrue);
        expect(bogota.isCurrent(DateTime(2027, 1, 1)), isFalse);
      },
    );

    test('Bogota calendar includes exact verified 2026 dates only', () {
      final calendar = taxCalendarByAuthority('bogota')!;

      expect(calendar.year, 2026);
      expect(calendar.verifiedAt, DateTime.utc(2026, 9, 3));
      expect(calendar.portalLink.verifiedAt, DateTime.utc(2026, 9, 3));
      expect(
        calendar.portalLink.sourceName,
        'Secretaría Distrital de Hacienda',
      );
      expect(calendar.portalLink.uri, startsWith('https://'));
      expect(calendar.portalLink.allowedHost, 'www.haciendabogota.gov.co');
      expect(calendar.importantDates.map((date) => date.date), [
        DateTime(2026, 5, 15),
        DateTime(2026, 6, 12),
        DateTime(2026, 7, 3),
        DateTime(2026, 7, 24),
        DateTime(2026, 9, 4),
      ]);
      expect(
        calendar.importantDates.map((date) => date.label).join('\n'),
        isNot(contains('semaforización')),
      );
    });

    test('Antioquia calendar includes exact verified 2026 dates', () {
      final calendar = taxCalendarByAuthority('antioquia')!;

      expect(calendar.year, 2026);
      expect(calendar.verifiedAt, DateTime.utc(2026, 9, 3));
      expect(calendar.portalLink.verifiedAt, DateTime.utc(2026, 9, 3));
      expect(calendar.portalLink.sourceName, 'Gobernación de Antioquia');
      expect(calendar.portalLink.uri, startsWith('https://'));
      expect(calendar.portalLink.allowedHost, 'www.vehiculosantioquia.com.co');
      expect(calendar.importantDates.map((date) => date.date), [
        DateTime(2026, 4, 30),
        DateTime(2026, 7, 31),
      ]);
    });
  });
}
