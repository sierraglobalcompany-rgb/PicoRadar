import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const simitConsultationUrl = 'https://www.fcm.org.co/simit/';
const runtActorsDirectoryUrl = 'https://www.runt.gov.co/directorio-de-actores';
const territorialCatalogAssetPath =
    'assets/catalogs/comparendos_authorities_v1.json';

final territorialCatalogProvider = FutureProvider<TerritorialCatalog>((
  ref,
) async {
  final raw = await rootBundle.loadString(territorialCatalogAssetPath);
  return TerritorialCatalog.fromJson(jsonDecode(raw) as Map<String, Object?>);
});

String normalizeTerritorialText(String value) {
  const accented = 'áàäâãåéèëêíìïîóòöôõúùüûñç';
  const plain = 'aaaaaaeeeeiiiiooooouuuunc';
  var result = value.toLowerCase();
  for (var i = 0; i < accented.length; i++) {
    result = result.replaceAll(accented[i], plain[i]);
  }
  return result
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

/// Transport syntax only. Provenance is checked separately when loading data.
bool isSafeOfficialPortalUrl(String value) {
  if (value != value.trim() ||
      RegExp(r'[\s\\\x00-\x1f]').hasMatch(value) ||
      RegExp(r'^https://[^/?#]*@', caseSensitive: false).hasMatch(value)) {
    return false;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      uri.authority.contains('@') ||
      uri.authority.contains('%')) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final labels = host.split('.');
  if (host.length > 253 || labels.length < 2) return false;
  if (const {
    'localhost',
    'local',
    'internal',
    'lan',
    'home',
    'test',
    'invalid',
  }.contains(labels.last)) {
    return false;
  }
  // Numeric and IPv6 literals cannot establish a named public institution.
  if (!RegExp(r'^[a-z]{2,63}$').hasMatch(labels.last)) return false;
  return labels.every(
    (label) =>
        RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(label),
  );
}

class TerritorialAuthority {
  const TerritorialAuthority({
    required this.id,
    required this.name,
    required this.platformName,
    required this.municipalityCodes,
    this.consultationUrl,
    this.institutionalUrl,
    this.evidenceUrl,
    this.verifiedAt,
    this.officeMunicipality = '',
    this.department = '',
    this.officeMunicipalityCode,
    this.entryKind = 'authority_or_office',
    this.verificationStatus = 'pending',
    this.coverageStatus = 'pending',
    this.sourceRecordIds = const [],
    this.sourceNames = const [],
    this.supportsRegistrationProcedures = false,
    this.transferUrl,
    this.appointmentUrl,
    this.formsUrl,
    this.phone,
    this.address,
    this.procedureEvidenceUrl,
    this.procedureReviewedAt,
  });

  final String id;
  final String name;
  final String platformName;

  /// Verified issuer coverage, never an office-location or pico restriction map.
  final List<String> municipalityCodes;
  final String? consultationUrl;
  final String? institutionalUrl;
  final String? evidenceUrl;
  final String? verifiedAt;
  final String officeMunicipality;
  final String department;
  final String? officeMunicipalityCode;
  final String entryKind;
  final String verificationStatus;
  final String coverageStatus;
  final List<String> sourceRecordIds;
  final List<String> sourceNames;

  /// False means not confirmed, not that the authority cannot register vehicles.
  /// Historical inventory membership and fine-issuer coverage are not proof.
  final bool supportsRegistrationProcedures;
  final String? transferUrl;
  final String? appointmentUrl;
  final String? formsUrl;
  final String? phone;
  final String? address;
  final String? procedureEvidenceUrl;
  final String? procedureReviewedAt;

  factory TerritorialAuthority.fromJson(Map<String, Object?> json) {
    final authority = TerritorialAuthority(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      platformName: _string(json, 'platformName'),
      municipalityCodes: _strings(json, 'municipalityCodes'),
      consultationUrl: _optionalString(json, 'consultationUrl'),
      institutionalUrl: _optionalString(json, 'institutionalUrl'),
      evidenceUrl: _optionalString(json, 'evidenceUrl'),
      verifiedAt: _optionalString(json, 'verifiedAt'),
      officeMunicipality: _string(json, 'officeMunicipality'),
      department: _string(json, 'department'),
      officeMunicipalityCode: _optionalString(json, 'officeMunicipalityCode'),
      entryKind: _string(json, 'entryKind'),
      verificationStatus: _string(json, 'verificationStatus'),
      coverageStatus: _string(json, 'coverageStatus'),
      sourceRecordIds: _strings(json, 'sourceRecordIds'),
      sourceNames: _strings(json, 'sourceNames'),
      supportsRegistrationProcedures: _optionalBool(
        json,
        'supportsRegistrationProcedures',
      ),
      transferUrl: _optionalString(json, 'transferUrl'),
      appointmentUrl: _optionalString(json, 'appointmentUrl'),
      formsUrl: _optionalString(json, 'formsUrl'),
      phone: _optionalString(json, 'phone'),
      address: _optionalString(json, 'address'),
      procedureEvidenceUrl: _optionalString(json, 'procedureEvidenceUrl'),
      procedureReviewedAt: _optionalString(json, 'procedureReviewedAt'),
    );
    _validateAuthority(authority);
    return authority;
  }
}

class TerritorialCatalog {
  const TerritorialCatalog({
    required this.authorities,
    this.version = '',
    this.reviewedAt = '',
    this.procedureReviewedAt = '',
    this.registrationFallbackUrl = runtActorsDirectoryUrl,
    this.summary = const TerritorialCatalogSummary.empty(),
    this.sources = const [],
  });

  final List<TerritorialAuthority> authorities;
  final String version;
  final String reviewedAt;
  final String procedureReviewedAt;
  final String registrationFallbackUrl;
  final TerritorialCatalogSummary summary;
  final List<TerritorialCatalogSource> sources;

  /// Inventory search includes pending entries. Office matches are not coverage.
  /// An empty query lists the inventory; no implicit result cap hides authorities.
  List<TerritorialAuthority> search(String query, {int? limit}) {
    if (limit != null && limit < 0) {
      throw RangeError.value(limit, 'limit', 'Must not be negative');
    }
    final terms = normalizeTerritorialText(query).split(' ');
    final matches = authorities.where((authority) {
      final text = normalizeTerritorialText(
        '${authority.name} ${authority.platformName} '
        '${authority.department} ${authority.officeMunicipality} '
        '${authority.sourceNames.join(' ')}',
      );
      return terms.every(text.contains);
    });
    return List.unmodifiable(limit == null ? matches : matches.take(limit));
  }

  List<TerritorialAuthority> forMunicipality(String code) => List.unmodifiable(
    authorities.where(
      (authority) => authority.municipalityCodes.contains(code),
    ),
  );

  factory TerritorialCatalog.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported territorial catalog schema');
    }
    final version = _string(json, 'version');
    final reviewedAt = _string(json, 'reviewedAt');
    final procedureReviewedAt = _string(json, 'procedureReviewedAt');
    final registrationFallbackUrl = _string(json, 'registrationFallbackUrl');
    if (registrationFallbackUrl != runtActorsDirectoryUrl) {
      throw const FormatException('Unrecognized registration fallback');
    }
    final sources = <TerritorialCatalogSource>[];
    final sourceRowCounts = <String, int>{};
    for (final row in _maps(json, 'sources')) {
      final id = _string(row, 'id');
      if (_directorySources[id] != row['url'] ||
          sourceRowCounts.containsKey(id)) {
        throw const FormatException(
          'Unrecognized or duplicate directory source',
        );
      }
      final count = row['observedRowCount'];
      if (count is! int || count <= 0) {
        throw const FormatException('Invalid directory row count');
      }
      final source = TerritorialCatalogSource(
        id: id,
        url: _string(row, 'url'),
        observedRowCount: count,
        fileSha256: _string(row, 'fileSha256'),
        retrievedAt: _string(row, 'retrievedAt'),
        historical: row['historical'] == true,
      );
      if (!source.historical ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(source.fileSha256)) {
        throw const FormatException('Invalid directory source provenance');
      }
      sourceRowCounts[id] = count;
      sources.add(source);
    }
    if (sourceRowCounts.length != _directorySources.length) {
      throw const FormatException('Missing directory source');
    }
    final sourceRecords = <String, String>{};
    final sourceCounts = <String, int>{};
    for (final row in _maps(json, 'sourceRecords')) {
      final id = _string(row, 'id');
      final sourceId = _string(row, 'sourceId');
      if (!sourceRowCounts.containsKey(sourceId) ||
          sourceRecords.containsKey(id)) {
        throw const FormatException('Invalid source record reference');
      }
      for (final field in ['page', 'row']) {
        final value = row[field];
        if (value is! int || value <= 0) {
          throw const FormatException('Invalid source page or row');
        }
      }
      _string(row, 'name');
      sourceRecords[id] = _string(row, 'authorityId');
      sourceCounts.update(sourceId, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final source in sourceRowCounts.entries) {
      if (sourceCounts[source.key] != source.value) {
        throw const FormatException('Incomplete directory intake');
      }
    }
    final authorities = <TerritorialAuthority>[];
    final authorityIds = <String>{};
    final usedRecords = <String>{};
    final authorityRows = _maps(json, 'authorities');
    final hasRegistrationProcedureFields = authorityRows.any(
      (row) => row.containsKey('supportsRegistrationProcedures'),
    );
    for (final row in authorityRows) {
      final authority = TerritorialAuthority.fromJson(row);
      if (!authorityIds.add(authority.id) ||
          authority.sourceRecordIds.isEmpty) {
        throw const FormatException('Duplicate or unsourced authority');
      }
      for (final ref in authority.sourceRecordIds) {
        if (sourceRecords[ref] != authority.id || !usedRecords.add(ref)) {
          throw const FormatException('Unreconciled or reused source row');
        }
      }
      authorities.add(authority);
    }
    if (usedRecords.length != sourceRecords.length || authorities.isEmpty) {
      throw const FormatException('Orphaned directory source rows');
    }
    final declaredSummary = TerritorialCatalogSummary.fromJson(
      _map(json, 'summary'),
    );
    final summary = hasRegistrationProcedureFields
        ? declaredSummary
        : TerritorialCatalogSummary(
            sourceRows: declaredSummary.sourceRows,
            inventoryEntries: declaredSummary.inventoryEntries,
            verifiedEntries: declaredSummary.verifiedEntries,
            directConsultationEntries:
                declaredSummary.directConsultationEntries,
            institutionOnlyEntries: declaredSummary.institutionOnlyEntries,
            pendingEntries: declaredSummary.pendingEntries,
            confirmedRegistrationProcedureEntries: 0,
            unconfirmedRegistrationProcedureEntries: authorities.length,
          );
    if (summary.inventoryEntries != authorities.length ||
        summary.sourceRows != sourceRecords.length ||
        summary.verifiedEntries !=
            authorities
                .where((entry) => entry.verificationStatus == 'verified')
                .length ||
        summary.confirmedRegistrationProcedureEntries !=
            authorities
                .where((entry) => entry.supportsRegistrationProcedures)
                .length ||
        summary.unconfirmedRegistrationProcedureEntries +
                summary.confirmedRegistrationProcedureEntries !=
            authorities.length) {
      throw const FormatException('Territorial summary does not match records');
    }
    return TerritorialCatalog(
      authorities: List.unmodifiable(authorities),
      version: version,
      reviewedAt: reviewedAt,
      procedureReviewedAt: procedureReviewedAt,
      registrationFallbackUrl: registrationFallbackUrl,
      summary: summary,
      sources: List.unmodifiable(sources),
    );
  }
}

class TerritorialCatalogSource {
  const TerritorialCatalogSource({
    required this.id,
    required this.url,
    required this.observedRowCount,
    required this.fileSha256,
    required this.retrievedAt,
    required this.historical,
  });

  final String id;
  final String url;
  final int observedRowCount;
  final String fileSha256;
  final String retrievedAt;
  final bool historical;
}

class TerritorialCatalogSummary {
  const TerritorialCatalogSummary({
    required this.sourceRows,
    required this.inventoryEntries,
    required this.verifiedEntries,
    required this.directConsultationEntries,
    required this.institutionOnlyEntries,
    required this.pendingEntries,
    required this.confirmedRegistrationProcedureEntries,
    required this.unconfirmedRegistrationProcedureEntries,
  });

  const TerritorialCatalogSummary.empty()
    : sourceRows = 0,
      inventoryEntries = 0,
      verifiedEntries = 0,
      directConsultationEntries = 0,
      institutionOnlyEntries = 0,
      pendingEntries = 0,
      confirmedRegistrationProcedureEntries = 0,
      unconfirmedRegistrationProcedureEntries = 0;

  final int sourceRows;
  final int inventoryEntries;
  final int verifiedEntries;
  final int directConsultationEntries;
  final int institutionOnlyEntries;
  final int pendingEntries;
  final int confirmedRegistrationProcedureEntries;
  final int unconfirmedRegistrationProcedureEntries;

  factory TerritorialCatalogSummary.fromJson(Map<String, Object?> json) {
    return TerritorialCatalogSummary(
      sourceRows: _positiveInt(json, 'sourceRows'),
      inventoryEntries: _positiveInt(json, 'inventoryEntries'),
      verifiedEntries: _positiveInt(json, 'verifiedEntries'),
      directConsultationEntries: _positiveInt(
        json,
        'directConsultationEntries',
      ),
      institutionOnlyEntries: _positiveInt(json, 'institutionOnlyEntries'),
      pendingEntries: _positiveInt(json, 'pendingEntries'),
      confirmedRegistrationProcedureEntries: _positiveInt(
        json,
        'confirmedRegistrationProcedureEntries',
      ),
      unconfirmedRegistrationProcedureEntries: _positiveInt(
        json,
        'unconfirmedRegistrationProcedureEntries',
      ),
    );
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw FormatException('Invalid territorial field: $key');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) =>
    json[key] == null ? null : _string(json, key);

bool _optionalBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return false;
  if (value is bool) return value;
  throw FormatException('Invalid territorial boolean: $key');
}

List<String> _strings(Map<String, Object?> json, String key) {
  final values = json[key];
  if (values is! List ||
      values.any((v) => v is! String || v.isEmpty || v != v.trim()) ||
      values.toSet().length != values.length) {
    throw FormatException('Invalid territorial list: $key');
  }
  return List<String>.unmodifiable(values);
}

Iterable<Map<String, Object?>> _maps(Map<String, Object?> json, String key) {
  final values = json[key];
  if (values is! List || values.any((v) => v is! Map<String, Object?>)) {
    throw FormatException('Invalid territorial records: $key');
  }
  return values.cast<Map<String, Object?>>();
}

Map<String, Object?> _map(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('Invalid territorial object: $key');
  }
  return value;
}

int _positiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('Invalid territorial count: $key');
  }
  return value;
}

void _validateAuthority(TerritorialAuthority authority) {
  _validateRegistrationProcedures(authority);
  if (authority.officeMunicipalityCode case final code?) {
    if (!RegExp(r'^\d{5}$').hasMatch(code)) {
      throw const FormatException('Invalid office municipality code');
    }
  }
  final proof = _reviewedPortals[authority.id];
  if (authority.verificationStatus == 'pending') {
    if (authority.consultationUrl != null ||
        authority.institutionalUrl != null ||
        authority.evidenceUrl != null ||
        authority.verifiedAt != null ||
        authority.municipalityCodes.isNotEmpty ||
        authority.coverageStatus != 'pending') {
      throw const FormatException('Unverified portal or territorial coverage');
    }
    return;
  }
  // A gov.co suffix or a data-supplied "verified" flag is not provenance.
  // These reviewed issuer/destination/evidence pairs are the local trust anchor.
  if (authority.verificationStatus != 'verified' ||
      proof == null ||
      authority.name != proof.name ||
      authority.consultationUrl != proof.url ||
      authority.institutionalUrl != proof.evidence ||
      authority.evidenceUrl != proof.evidence ||
      authority.verifiedAt != proof.reviewedAt ||
      authority.coverageStatus != 'verified_municipal' ||
      authority.municipalityCodes.length != 1 ||
      authority.municipalityCodes.single != proof.code ||
      !isSafeOfficialPortalUrl(proof.url ?? proof.evidence) ||
      !isSafeOfficialPortalUrl(proof.evidence)) {
    throw const FormatException('Portal does not match reviewed provenance');
  }
}

void _validateRegistrationProcedures(TerritorialAuthority authority) {
  final fields = [
    authority.transferUrl,
    authority.appointmentUrl,
    authority.formsUrl,
    authority.phone,
    authority.address,
    authority.procedureEvidenceUrl,
    authority.procedureReviewedAt,
  ];
  if (!authority.supportsRegistrationProcedures) {
    if (fields.any((value) => value != null)) {
      throw const FormatException('Unconfirmed registration procedure details');
    }
    return;
  }
  final proof = _reviewedRegistrationProcedures[authority.id];
  if (proof == null ||
      authority.name != _reviewedPortals[authority.id]?.name ||
      authority.transferUrl != proof.transferUrl ||
      authority.procedureEvidenceUrl != proof.evidenceUrl ||
      authority.procedureReviewedAt != proof.reviewedAt ||
      (authority.appointmentUrl != null &&
          authority.appointmentUrl != proof.appointmentUrl) ||
      (authority.formsUrl != null && authority.formsUrl != proof.formsUrl) ||
      (authority.phone != null && authority.phone != proof.phone) ||
      (authority.address != null && authority.address != proof.address)) {
    throw const FormatException(
      'Registration procedure does not match reviewed provenance',
    );
  }
  for (final url in [
    authority.transferUrl,
    authority.appointmentUrl,
    authority.formsUrl,
    authority.procedureEvidenceUrl,
  ]) {
    if (url != null && !isSafeOfficialPortalUrl(url)) {
      throw const FormatException('Invalid registration procedure URL');
    }
  }
}

const _bogotaTransferUrl =
    'https://www.ventanillamovilidad.com.co/tramites/traspaso-propiedad';
const _medellinTransferUrl =
    'https://www.medellin.gov.co/es/tramites-y-servicios/traspaso-de-propiedad-de-un-vehiculo-automotor/';

// Exact referrals and contact evidence: PURCHASE_DIRECTORY_AUDIT_20260915.md.
// This separate review never promotes the historical inventory to registrars.
const _reviewedRegistrationProcedures = {
  'co-bogota': (
    transferUrl: _bogotaTransferUrl,
    appointmentUrl: 'https://vus.circulemosdigital.com.co/',
    formsUrl: 'https://www.ventanillamovilidad.com.co/formularios',
    phone: '6012916999',
    address: null,
    evidenceUrl: _bogotaTransferUrl,
    reviewedAt: '2026-09-15',
  ),
  'co-medellin': (
    transferUrl: _medellinTransferUrl,
    appointmentUrl: null,
    formsUrl: null,
    phone: '6044457777',
    address: 'Sede Caribe: Carrera 64 C # 72 - 58, Medellin',
    evidenceUrl: _medellinTransferUrl,
    reviewedAt: '2026-09-15',
  ),
};

const _directorySources = {
  'fcm_organismos': 'https://www.fcm.org.co/wp-content/uploads/2021/07/Directorio-Organismos-de-Transito.pdf',
  'fcm_autoridades': 'https://www.fcm.org.co/wp-content/uploads/2021/08/Base-de-Datos-Autoridades-de-Transito.pdf',
  'runt': 'https://www.runt.gov.co/sites/default/files/documentos/LISTADO%20EXTENSIONES%20IP%20ORGANISMOS%20DE%20TRANSITO.pdf',
};

const _manizalesEvidence =
    'https://centrodeinformacion.manizales.gov.co/fotodetecciones-en-manizales-asi-puede-consultar-gestionar-y-pagar-de-forma-segura/';

// Full findings and source aliases: tool/comparendos_verifications.json.
// Updating the asset alone cannot grant trust. Update each reviewed tuple and
// its own date after checking issuer, exact link, referral and coverage evidence.
const _reviewedPortals = {
  'co-medellin': (
    name: 'Secretaría de Movilidad de Medellín',
    code: '05001',
    url: 'https://www.medellin.gov.co/portal-movilidad/#/public',
    evidence: 'https://www.medellin.gov.co/es/pag-movilidad/',
    reviewedAt: '2026-09-13',
  ),
  'co-bogota': (
    name: 'Secretaría Distrital de Movilidad de Bogotá',
    code: '11001',
    url: null,
    evidence: 'https://www.movilidadbogota.gov.co/consulta-de-comparendos',
    reviewedAt: '2026-09-13',
  ),
  'co-barranquilla': (
    name: 'Secretaría Distrital de Tránsito y Seguridad Vial de Barranquilla',
    code: '08001',
    url: null,
    evidence: 'https://barranquilla.gov.co/transito/tus-multas',
    reviewedAt: '2026-09-13',
  ),
  'co-bucaramanga': (
    name: 'Dirección de Tránsito de Bucaramanga',
    code: '68001',
    url: null,
    evidence: 'https://transitobucaramanga.gov.co/dtb/',
    reviewedAt: '2026-09-13',
  ),
  'co-itagui': (
    name: 'Secretaría de Movilidad de Itagüí',
    code: '05360',
    url: null,
    evidence: 'https://www.transitoitagui.gov.co/',
    reviewedAt: '2026-09-13',
  ),
  'co-pereira': (
    name: 'Instituto de Movilidad de Pereira',
    code: '66001',
    url: null,
    evidence: 'https://movilidadpereira.gov.co/tramites',
    reviewedAt: '2026-09-13',
  ),
  'co-manizales': (
    name: 'Secretaría de Movilidad de Manizales',
    code: '17001',
    url: 'https://www.movilidadmanizales.com.co/portal-servicios/#/public',
    evidence: _manizalesEvidence,
    reviewedAt: '2026-09-13',
  ),
};
