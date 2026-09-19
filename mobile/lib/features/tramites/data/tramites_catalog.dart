import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../comparendos/data/territorial_catalog.dart';

enum TramitesAuthorityStatus { verifiedDirect, pending }

enum TramitesFallbackKind { institution, runtDirectory }

class TramitesProcedure {
  const TramitesProcedure({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.preparationItems,
  });

  final String id;
  final String title;
  final String description;
  final String url;
  final List<String> preparationItems;
}

class TramitesAuthority {
  const TramitesAuthority({
    required this.id,
    required this.name,
    required this.municipality,
    required this.department,
    required this.status,
    required this.procedures,
    required this.fallbackKind,
    required this.fallbackUrl,
    required this.sourceNames,
  });

  final String id;
  final String name;
  final String municipality;
  final String department;
  final TramitesAuthorityStatus status;
  final List<TramitesProcedure> procedures;
  final TramitesFallbackKind? fallbackKind;
  final String? fallbackUrl;
  final List<String> sourceNames;

  bool get hasDirectProcedures => procedures.isNotEmpty;

  String get statusLabel => switch (status) {
    TramitesAuthorityStatus.verifiedDirect => 'Enlaces revisados',
    TramitesAuthorityStatus.pending => 'Por confirmar',
  };
}

class TramitesCatalog {
  const TramitesCatalog({
    required this.version,
    required this.reviewedAt,
    required this.procedureReviewedAt,
    required this.sourceRowCount,
    required this.sources,
    required this.authorities,
  });

  final String version;
  final String reviewedAt;
  final String procedureReviewedAt;
  final int sourceRowCount;
  final List<TerritorialCatalogSource> sources;
  final List<TramitesAuthority> authorities;

  int get directAuthorityCount =>
      authorities.where((entry) => entry.hasDirectProcedures).length;

  int get institutionFallbackCount => authorities
      .where((entry) => entry.fallbackKind == TramitesFallbackKind.institution)
      .length;

  int get runtFallbackCount => authorities
      .where(
        (entry) => entry.fallbackKind == TramitesFallbackKind.runtDirectory,
      )
      .length;

  List<TramitesAuthority> search(String query) {
    final terms = normalizeTerritorialText(query).split(' ');
    return List.unmodifiable(
      authorities.where((authority) {
        final text = normalizeTerritorialText(
          '${authority.name} ${authority.municipality} '
          '${authority.department} ${authority.sourceNames.join(' ')}',
        );
        return terms.every(text.contains);
      }),
    );
  }

  factory TramitesCatalog.fromTerritorial(TerritorialCatalog source) {
    if (source.summary.inventoryEntries != source.authorities.length ||
        source.summary.sourceRows !=
            source.sources.fold<int>(
              0,
              (total, item) => total + item.observedRowCount,
            )) {
      throw const FormatException('Incomplete Tramites source metadata');
    }

    final authorities = source.authorities
        .map((authority) {
          final procedures =
              _directProcedures[authority.id] ?? const <TramitesProcedure>[];
          if (procedures.isNotEmpty &&
              !authority.supportsRegistrationProcedures) {
            throw const FormatException(
              'Direct procedure lacks territorial evidence',
            );
          }
          final hasDirect = procedures.isNotEmpty;
          final institutionalFallback =
              !hasDirect && authority.verificationStatus == 'verified';
          return TramitesAuthority(
            id: authority.id,
            name: authority.name,
            municipality: authority.officeMunicipality,
            department: authority.department,
            status: hasDirect
                ? TramitesAuthorityStatus.verifiedDirect
                : TramitesAuthorityStatus.pending,
            procedures: List.unmodifiable(procedures),
            fallbackKind: hasDirect
                ? null
                : institutionalFallback
                ? TramitesFallbackKind.institution
                : TramitesFallbackKind.runtDirectory,
            fallbackUrl: hasDirect
                ? null
                : institutionalFallback
                ? authority.institutionalUrl
                : source.registrationFallbackUrl,
            sourceNames: authority.sourceNames,
          );
        })
        .toList(growable: false);

    final catalog = TramitesCatalog(
      version: source.version,
      reviewedAt: source.reviewedAt,
      procedureReviewedAt: source.procedureReviewedAt,
      sourceRowCount: source.summary.sourceRows,
      sources: source.sources,
      authorities: List.unmodifiable(authorities),
    );
    if (catalog.directAuthorityCount != 2 ||
        catalog.institutionFallbackCount != 5 ||
        catalog.runtFallbackCount != 762) {
      throw const FormatException('Unexpected Tramites coverage distribution');
    }
    return catalog;
  }
}

final tramitesCatalogProvider = FutureProvider<TramitesCatalog>((ref) async {
  final territorial = await ref.watch(territorialCatalogProvider.future);
  return TramitesCatalog.fromTerritorial(territorial);
});

const _transferItems = [
  'Verificar inscripción RUNT de las partes.',
  'Confirmar SOAT vigente.',
  'Confirmar RTM cuando aplique.',
  'Revisar multas, impuestos y documentos de transferencia en el portal.',
];

const _duplicateItems = [
  'Verificar inscripción RUNT.',
  'Confirmar SOAT vigente.',
  'Revisar multas y obligaciones aplicables.',
  'Preparar identificación y autorización si actúa un tercero.',
];

const _registrationItems = [
  'Verificar inscripción RUNT.',
  'Tener factura y documentos de origen del vehículo.',
  'Confirmar SOAT y obligaciones tributarias aplicables.',
  'Revisar requisitos específicos del tipo de vehículo.',
];

const _certificateItems = [
  'Confirmar que el vehículo esté matriculado en la ciudad seleccionada.',
  'Tener placa y datos del solicitante.',
  'Revisar si el trámite es virtual o presencial.',
  'Confirmar tarifa y forma de entrega en el portal.',
];

const _directProcedures = {
  'co-medellin': [
    TramitesProcedure(
      id: 'traspaso',
      title: 'Traspaso de propiedad',
      description: 'Cambio de propiedad del vehículo ante la autoridad.',
      url: 'https://www.medellin.gov.co/es/tramites-y-servicios/traspaso-de-propiedad-de-un-vehiculo-automotor/',
      preparationItems: _transferItems,
    ),
    TramitesProcedure(
      id: 'duplicado',
      title: 'Duplicado de licencia de tránsito',
      description: 'Reposición del documento de tránsito del vehículo.',
      url: 'https://www.medellin.gov.co/es/tramites-y-servicios/como-sacar-el-duplicado-de-la-licencia-de-transito-de-un-vehiculo-automotor/',
      preparationItems: _duplicateItems,
    ),
    TramitesProcedure(
      id: 'matricula',
      title: 'Matrícula de vehículo',
      description: 'Registro inicial del vehículo ante la autoridad.',
      url: 'https://www.medellin.gov.co/es/tramites-y-servicios/matricula-de-vehiculos-automotores/',
      preparationItems: _registrationItems,
    ),
    TramitesProcedure(
      id: 'certificado',
      title: 'Certificado de libertad y tradición',
      description: 'Consulta oficial de estado registral del vehículo.',
      url: 'https://www.medellin.gov.co/es/tramites-y-servicios/certificado-de-libertad-y-tradicion-de-un-vehiculo-automotor/',
      preparationItems: _certificateItems,
    ),
  ],
  'co-bogota': [
    TramitesProcedure(
      id: 'traspaso',
      title: 'Traspaso de propiedad',
      description: 'Cambio de propiedad del vehículo ante la autoridad.',
      url: 'https://www.ventanillamovilidad.com.co/tramites/traspaso-propiedad',
      preparationItems: _transferItems,
    ),
    TramitesProcedure(
      id: 'duplicado',
      title: 'Duplicado de licencia de tránsito',
      description: 'Reposición del documento de tránsito del vehículo.',
      url: 'https://www.ventanillamovilidad.com.co/tramites/duplicado-de-licencia-de-transito',
      preparationItems: _duplicateItems,
    ),
    TramitesProcedure(
      id: 'matricula',
      title: 'Matrícula de vehículo',
      description: 'Registro inicial del vehículo ante la autoridad.',
      url: 'https://www.ventanillamovilidad.com.co/tramites/matricula',
      preparationItems: _registrationItems,
    ),
    TramitesProcedure(
      id: 'certificado',
      title: 'Certificado de libertad y tradición',
      description: 'Consulta oficial de estado registral del vehículo.',
      url: 'https://www.ventanillamovilidad.com.co/tramites/certificado-de-libertad-y-tradicion',
      preparationItems: _certificateItems,
    ),
  ],
};
