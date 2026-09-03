class OfficialVehicleLink {
  const OfficialVehicleLink({
    required this.id,
    required this.title,
    required this.uri,
    required this.verifiedAt,
    required this.sourceName,
    required this.allowedHost,
  });

  final String id;
  final String title;
  final String uri;
  final DateTime verifiedAt;
  final String sourceName;
  final String allowedHost;

  bool get isValid {
    final parsed = Uri.tryParse(uri);
    return parsed != null &&
        parsed.scheme == 'https' &&
        parsed.host == allowedHost;
  }
}

class ImportantDate {
  const ImportantDate({
    required this.date,
    required this.label,
    required this.kind,
  });

  final DateTime date;
  final String label;
  final String kind;
}

class VehicleTaxCalendar {
  const VehicleTaxCalendar({
    required this.authorityId,
    required this.authorityName,
    required this.year,
    required this.verifiedAt,
    required this.staleAfter,
    required this.portalLink,
    required this.importantDates,
  });

  final String authorityId;
  final String authorityName;
  final int year;
  final DateTime verifiedAt;
  final DateTime staleAfter;
  final OfficialVehicleLink portalLink;
  final List<ImportantDate> importantDates;

  bool isCurrent(DateTime nowBogota) {
    if (nowBogota.year != year) {
      return false;
    }
    return nowBogota.toUtc().isBefore(staleAfter.toUtc());
  }
}

final runtVehicleByPlateLink = OfficialVehicleLink(
  id: 'runt-vehicle-by-plate',
  title: 'Verificar en RUNT',
  uri: 'https://www.runt.gov.co/actores/ciudadano/consulta-de-vehiculos-por-placa',
  verifiedAt: DateTime.utc(2026, 8, 27),
  sourceName: 'RUNT',
  allowedHost: 'www.runt.gov.co',
);

final fasecoldaAutomovilesLink = OfficialVehicleLink(
  id: 'fasecolda-automoviles',
  title: 'Aseguradoras autorizadas',
  uri: 'https://www.fasecolda.com/ramos/automoviles/companias-autorizadas/',
  verifiedAt: DateTime.utc(2026, 8, 27),
  sourceName: 'Fasecolda',
  allowedHost: 'www.fasecolda.com',
);

final bogotaTaxPortalLink = OfficialVehicleLink(
  id: 'bogota-tax-vehicles',
  title: 'Portal impuesto vehicular Bogotá',
  uri: 'https://www.haciendabogota.gov.co/es/impuestos/impuesto-sobre-vehiculos-automotores',
  verifiedAt: DateTime.utc(2026, 9, 3),
  sourceName: 'Secretaría Distrital de Hacienda',
  allowedHost: 'www.haciendabogota.gov.co',
);

final antioquiaTaxPortalLink = OfficialVehicleLink(
  id: 'antioquia-tax-vehicles',
  title: 'Portal impuesto vehicular Antioquia',
  uri: 'https://www.vehiculosantioquia.com.co/impuestosweb/',
  verifiedAt: DateTime.utc(2026, 9, 3),
  sourceName: 'Gobernación de Antioquia',
  allowedHost: 'www.vehiculosantioquia.com.co',
);

const insuranceProviderOptions = [
  'Allianz Colombia',
  'Aseguradora Solidaria de Colombia Entidad Cooperativa',
  'Axa Colpatria Seguros S.A.',
  'BBVA Seguros Colombia S.A.',
  'La Equidad Seguros Generales Organismo Cooperativo',
  'HDI Seguros Colombia S.A.',
  'Mapfre Seguros Generales de Colombia S.A.',
  'Quálitas Compañía de Seguros Colombia S.A.',
  'La Previsora S.A. Compañía de Seguros',
  'SBS Seguros Colombia S.A',
  'Seguros Alfa',
  'Seguros Mundial',
  'Seguros Bolívar S.A.',
  'Seguros del Estado',
  'Seguros Generales Suramericana S.A.',
  'Zurich Colombia Seguros S.A.',
  'Otra / no aparece',
];

final vehicleTaxCalendars = [
  VehicleTaxCalendar(
    authorityId: 'bogota',
    authorityName: 'Bogotá - Secretaría Distrital de Hacienda',
    year: 2026,
    verifiedAt: DateTime.utc(2026, 9, 3),
    staleAfter: DateTime.utc(2027),
    portalLink: bogotaTaxPortalLink,
    importantDates: [
      ImportantDate(
        date: DateTime(2026, 5, 15),
        label: 'Pronto pago 10%',
        kind: 'discountDeadline',
      ),
      ImportantDate(
        date: DateTime(2026, 6, 12),
        label: 'SPAC: declaración inicial, solo si elige pago por cuotas',
        kind: 'installmentInfo',
      ),
      ImportantDate(
        date: DateTime(2026, 7, 3),
        label: 'SPAC: cuota 1, si se acogió',
        kind: 'installmentInfo',
      ),
      ImportantDate(
        date: DateTime(2026, 7, 24),
        label: 'Fecha límite ordinaria',
        kind: 'ordinaryDeadline',
      ),
      ImportantDate(
        date: DateTime(2026, 9, 4),
        label: 'SPAC: cuota 2, si se acogió',
        kind: 'installmentInfo',
      ),
    ],
  ),
  VehicleTaxCalendar(
    authorityId: 'antioquia',
    authorityName: 'Antioquia - Gobernación de Antioquia',
    year: 2026,
    verifiedAt: DateTime.utc(2026, 9, 3),
    staleAfter: DateTime.utc(2027),
    portalLink: antioquiaTaxPortalLink,
    importantDates: [
      ImportantDate(
        date: DateTime(2026, 4, 30),
        label: 'Pronto pago; descuento según tipo de vehículo',
        kind: 'discountDeadline',
      ),
      ImportantDate(
        date: DateTime(2026, 7, 31),
        label: 'Fecha límite ordinaria',
        kind: 'ordinaryDeadline',
      ),
    ],
  ),
];

VehicleTaxCalendar? taxCalendarByAuthority(String? authorityId) {
  if (authorityId == null) {
    return null;
  }
  for (final calendar in vehicleTaxCalendars) {
    if (calendar.authorityId == authorityId) {
      return calendar;
    }
  }
  return null;
}

VehicleTaxCalendar? suggestTaxCalendar(String? registrationCity) {
  final normalized = _normalizeTaxAuthorityHint(registrationCity);
  return switch (normalized) {
    'bogota' ||
    'bogota dc' ||
    'bogota bogota dc' => taxCalendarByAuthority('bogota'),
    'medellin' || 'medellin antioquia' => taxCalendarByAuthority('antioquia'),
    _ => null,
  };
}

String _normalizeTaxAuthorityHint(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) {
    return '';
  }
  final withoutMarks = trimmed
      .replaceAll(RegExp('[áàäâã]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöôõ]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n');
  return withoutMarks
      .replaceAll('-', ' ')
      .replaceAll('.', '')
      .replaceAll(',', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
