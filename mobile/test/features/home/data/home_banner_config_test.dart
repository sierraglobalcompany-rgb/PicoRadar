import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/home/data/home_banner_config.dart';

import '../../../test_app_harness.dart';

void main() {
  group('Home banner selection', () {
    test('disabled config collapses the slot', () async {
      final selected = await selectHomeBannerCampaign(
        config: _config(enabled: false),
        preferences: MemoryPreferences(),
      );

      expect(selected, isNull);
    });

    test('fixed policy selects the configured local campaign', () async {
      final selected = await selectHomeBannerCampaign(
        config: _config(
          fixedCampaignId: 'house',
          campaigns: [_campaign('affiliate'), _campaign('house')],
        ),
        preferences: MemoryPreferences(),
      );

      expect(selected?.id, 'house');
    });

    test(
      'fixed policy falls back when fixed campaign is unavailable',
      () async {
        final selected = await selectHomeBannerCampaign(
          config: _config(
            fixedCampaignId: 'missing',
            campaigns: [_campaign('affiliate'), _adNetworkCampaign()],
          ),
          preferences: MemoryPreferences(),
        );

        expect(selected?.id, 'affiliate');
      },
    );

    test('ad network and none campaigns do not render locally', () async {
      final selected = await selectHomeBannerCampaign(
        config: _config(campaigns: [_adNetworkCampaign(), _noneCampaign()]),
        preferences: MemoryPreferences(),
      );

      expect(selected, isNull);
    });

    test(
      'rotate policy advances once per cold launch provider container',
      () async {
        final preferences = MemoryPreferences();
        final config = _config(
          selectionPolicy: HomeBannerSelectionPolicy.rotateOnAppLaunch,
          campaigns: [_campaign('a'), _campaign('b')],
        );

        final firstLaunch = ProviderContainer(
          overrides: [
            appPreferencesProvider.overrideWithValue(preferences),
            homeBannerConfigProvider.overrideWith((ref) async => config),
          ],
        );
        addTearDown(firstLaunch.dispose);
        final firstRead = await firstLaunch.read(
          homeBannerCampaignProvider.future,
        );
        final secondRead = await firstLaunch.read(
          homeBannerCampaignProvider.future,
        );

        expect(firstRead?.id, 'a');
        expect(secondRead?.id, 'a');

        final secondLaunch = ProviderContainer(
          overrides: [
            appPreferencesProvider.overrideWithValue(preferences),
            homeBannerConfigProvider.overrideWith((ref) async => config),
          ],
        );
        addTearDown(secondLaunch.dispose);
        final nextRead = await secondLaunch.read(
          homeBannerCampaignProvider.future,
        );

        expect(nextRead?.id, 'b');
      },
    );

    test('rotate policy keeps a single eligible campaign stable', () async {
      final preferences = MemoryPreferences();
      final selected = await selectHomeBannerCampaign(
        config: _config(
          selectionPolicy: HomeBannerSelectionPolicy.rotateOnAppLaunch,
          campaigns: [_campaign('solo')],
        ),
        preferences: preferences,
      );

      expect(selected?.id, 'solo');
      expect(
        await preferences.getString(homeBannerLastCampaignPreferenceKey),
        isNull,
      );
    });
  });

  group('Home banner URL guard', () {
    test('accepts HTTPS targets without mutation', () {
      final campaign = _campaign(
        'safe',
        targetUrl: 'https://picoradar.co/demo/home-ally?utm=home',
      );

      final uri = safeHomeBannerUri(campaign);

      expect(uri?.scheme, 'https');
      expect(uri.toString(), campaign.targetUrl);
    });

    test('rejects non-HTTPS or empty targets', () {
      expect(
        safeHomeBannerUri(_campaign('http', targetUrl: 'http://x.test')),
        isNull,
      );
      expect(safeHomeBannerUri(_campaign('empty', targetUrl: null)), isNull);
    });

    test('does not append user or vehicle identifiers', () {
      final campaign = _campaign(
        'safe',
        targetUrl: 'https://picoradar.co/demo/home-ally',
      );

      final uri = safeHomeBannerUri(campaign);

      expect(uri?.query, isEmpty);
      expect(uri.toString(), isNot(contains('plate')));
      expect(uri.toString(), isNot(contains('vehicle')));
      expect(uri.toString(), isNot(contains('gps')));
      expect(uri.toString(), isNot(contains('avatar')));
    });
  });
}

HomeBannerConfig _config({
  bool enabled = true,
  HomeBannerSelectionPolicy selectionPolicy = HomeBannerSelectionPolicy.fixed,
  String? fixedCampaignId = 'affiliate',
  List<HomeBannerCampaign>? campaigns,
}) {
  return HomeBannerConfig(
    enabled: enabled,
    selectionPolicy: selectionPolicy,
    fixedCampaignId: fixedCampaignId,
    campaigns: campaigns ?? [_campaign('affiliate')],
  );
}

HomeBannerCampaign _campaign(
  String id, {
  HomeBannerKind kind = HomeBannerKind.affiliate,
  String? targetUrl = 'https://picoradar.co/demo/home-ally',
}) {
  return HomeBannerCampaign(
    id: id,
    kind: kind,
    enabled: true,
    label: 'ALIADO PREMIUM · DEMO',
    title: 'Protección que te acompaña',
    subtitle: 'Espacio preparado para campañas y aliados.',
    ctaText: 'Conocer más',
    priority: 10,
    targetUrl: targetUrl,
  );
}

HomeBannerCampaign _adNetworkCampaign() {
  return _campaign('ad', kind: HomeBannerKind.adNetwork, targetUrl: null);
}

HomeBannerCampaign _noneCampaign() {
  return _campaign('none', kind: HomeBannerKind.none, targetUrl: null);
}
