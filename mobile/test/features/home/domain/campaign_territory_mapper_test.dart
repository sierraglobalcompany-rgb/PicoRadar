import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/home/data/home_partner_catalog.dart';
import 'package:picoradar/features/home/domain/campaign_territory_mapper.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';

void main() {
  test(
    'maps one valid OTA DIVIPOLA to municipality and department codes',
    () {
      final context = mapCampaignTerritory(
        const RestrictionJurisdiction(
          id: 'new-city-id',
          name: 'New City',
          municipalityCodes: ['05001'],
        ),
        [
          _catalogEntry(id: 'new-city-id', municipalityCode: '11001'),
        ],
      );

      expect(
        context,
        const CampaignTerritoryContext(
          departmentCode: '05',
          municipalityCode: '05001',
          municipalityKey: 'new-city-id',
        ),
      );
    },
  );

  test(
    'uses the historical catalog only when OTA has no municipality codes',
    () {
      const entry = PicoJurisdictionCatalogEntry(
        id: 'legacy-city-id',
        name: 'Legacy City',
        department: 'Legacy Department',
        classification: 'SUPPORTED_CURRENT',
        sourceDate: '2026-09-10',
        municipalityCode: '11001',
      );

      for (final codes in <List<String>?>[null, const <String>[]]) {
        expect(
          mapCampaignTerritory(
            RestrictionJurisdiction(
              id: 'legacy-city-id',
              name: 'Legacy City',
              municipalityCodes: codes,
            ),
            const [entry],
          ),
          const CampaignTerritoryContext(
            departmentCode: '11',
            municipalityCode: '11001',
            municipalityKey: 'legacy-city-id',
          ),
        );
      }
    },
  );

  test('keeps only the jurisdiction key when OTA has multiple codes', () {
    final context = mapCampaignTerritory(
      const RestrictionJurisdiction(
        id: 'multi-city-id',
        name: 'Multi City',
        municipalityCodes: ['05001', '05360'],
      ),
      [_catalogEntry(id: 'multi-city-id', municipalityCode: '11001')],
    );

    expect(
      context,
      const CampaignTerritoryContext(municipalityKey: 'multi-city-id'),
    );
  });

  test(
    'keeps only the key for invalid OTA codes and does not use legacy data',
    () {
      for (final code in ['1100X', '110011', '1100']) {
        final context = mapCampaignTerritory(
          RestrictionJurisdiction(
            id: 'invalid-city-id',
            name: 'Invalid City',
            municipalityCodes: [code],
          ),
          [_catalogEntry(id: 'invalid-city-id', municipalityCode: '11001')],
        );

        expect(
          context,
          const CampaignTerritoryContext(
            municipalityKey: 'invalid-city-id',
          ),
        );
      }
    },
  );

  test('keeps only the key when historical ID matches are ambiguous', () {
    final context = mapCampaignTerritory(
      const RestrictionJurisdiction(
        id: 'ambiguous-city-id',
        name: 'Ambiguous City',
      ),
      [
        _catalogEntry(
          id: 'legacy-entry-a',
          municipalityCode: '11001',
          engineJurisdictionId: 'ambiguous-city-id',
        ),
        _catalogEntry(
          id: 'ambiguous-city-id',
          municipalityCode: '25001',
        ),
      ],
    );

    expect(
      context,
      const CampaignTerritoryContext(municipalityKey: 'ambiguous-city-id'),
    );
  });

  test('does not infer historical territory from a matching name', () {
    final context = mapCampaignTerritory(
      const RestrictionJurisdiction(id: 'new-bogota-id', name: 'Bogotá'),
      [_catalogEntry(id: 'co-dc-bogota', municipalityCode: '11001')],
    );

    expect(
      context,
      const CampaignTerritoryContext(municipalityKey: 'new-bogota-id'),
    );
  });

  test('returns an empty context without a selected jurisdiction', () {
    expect(
      mapCampaignTerritory(
        null,
        [_catalogEntry(id: 'co-dc-bogota', municipalityCode: '11001')],
      ),
      const CampaignTerritoryContext(),
    );
  });
}

PicoJurisdictionCatalogEntry _catalogEntry({
  required String id,
  required String municipalityCode,
  String? engineJurisdictionId,
}) => PicoJurisdictionCatalogEntry(
  id: id,
  name: 'Historical City',
  department: 'Historical Department',
  classification: 'SUPPORTED_CURRENT',
  sourceDate: '2026-09-10',
  municipalityCode: municipalityCode,
  engineJurisdictionId: engineJurisdictionId,
);
