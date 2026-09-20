import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/home/application/home_partner_catalog_provider.dart';
import 'package:picoradar/features/home/data/home_partner_catalog.dart';

void main() {
  test(
    'catalog URI requires HTTPS and supports explicit or CDN configuration',
    () {
      expect(
        resolveCampaignCatalogUri(
          campaignCatalogUrl:
              'https://catalog.picoradar.test/custom/catalog.json',
          cdnBaseUrl: 'https://cdn.picoradar.test',
        ).toString(),
        'https://catalog.picoradar.test/custom/catalog.json',
      );
      expect(
        resolveCampaignCatalogUri(
          campaignCatalogUrl: '',
          cdnBaseUrl: 'https://cdn.picoradar.test/base',
        ).toString(),
        'https://cdn.picoradar.test/storage/campaigns/v1/catalog.json',
      );
      expect(
        resolveCampaignCatalogUri(
          campaignCatalogUrl: 'http://unsafe.example.test/catalog.json',
          cdnBaseUrl: '',
        ),
        isNull,
      );
    },
  );

  test(
    'provider returns the exact C11 fallback when remote is not configured',
    () async {
      final container = ProviderContainer(
        overrides: [campaignCatalogUriProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final campaigns = await container.read(
        homePartnerCampaignsProvider(const CampaignTerritoryContext()).future,
      );

      expect(campaigns, same(fallbackHomePartnerCampaigns));
    },
  );
}
