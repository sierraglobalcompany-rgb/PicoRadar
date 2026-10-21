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

String? suggestTaxAuthorityId(String? registrationCity) {
  final normalized = _normalizeTaxAuthorityHint(registrationCity);
  return switch (normalized) {
    'bogota' || 'bogota dc' || 'bogota bogota dc' => 'bogota',
    'medellin' || 'medellin antioquia' => 'antioquia',
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
