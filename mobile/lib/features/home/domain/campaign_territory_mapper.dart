import '../data/home_partner_catalog.dart';
import '../../pico_placa/data/pico_jurisdiction_catalog.dart';
import '../../pico_placa/data/restriction_store.dart';

CampaignTerritoryContext mapCampaignTerritory(
  RestrictionJurisdiction? jurisdiction,
  Iterable<PicoJurisdictionCatalogEntry> historicalCatalog,
) {
  if (jurisdiction == null) return const CampaignTerritoryContext();

  final municipalityCodes = jurisdiction.municipalityCodes;
  if (municipalityCodes != null && municipalityCodes.isNotEmpty) {
    if (municipalityCodes.length != 1) {
      return _keyOnly(jurisdiction.id);
    }
    final code = municipalityCodes.single;
    return _isDivipolaCode(code)
        ? _withMunicipalityCode(jurisdiction.id, code)
        : _keyOnly(jurisdiction.id);
  }

  PicoJurisdictionCatalogEntry? legacyMatch;
  for (final entry in historicalCatalog) {
    if (entry.id != jurisdiction.id &&
        entry.engineJurisdictionId != jurisdiction.id) {
      continue;
    }
    if (legacyMatch != null) return _keyOnly(jurisdiction.id);
    legacyMatch = entry;
  }

  final code = legacyMatch?.municipalityCode;
  return code != null && _isDivipolaCode(code)
      ? _withMunicipalityCode(jurisdiction.id, code)
      : _keyOnly(jurisdiction.id);
}

bool _isDivipolaCode(String code) =>
    code.length == 5 && RegExp(r'^[0-9]{5}$').hasMatch(code);

CampaignTerritoryContext _withMunicipalityCode(String id, String code) =>
    CampaignTerritoryContext(
      departmentCode: code.substring(0, 2),
      municipalityCode: code,
      municipalityKey: id,
    );

CampaignTerritoryContext _keyOnly(String id) =>
    CampaignTerritoryContext(municipalityKey: id);
