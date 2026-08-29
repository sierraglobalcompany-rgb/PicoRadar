import 'dart:convert';

import '../../../core/storage/app_preferences.dart';

const homeBannerConfigAssetPath = 'assets/config/home_banner_config.json';
const homeBannerLastCampaignPreferenceKey = 'home_banner_last_campaign_id';

enum HomeBannerKind { affiliate, sponsored, house, adNetwork, none }

enum HomeBannerSelectionPolicy { fixed, rotateOnAppLaunch }

class HomeBannerConfig {
  const HomeBannerConfig({
    required this.enabled,
    required this.selectionPolicy,
    required this.campaigns,
    this.fixedCampaignId,
  });

  final bool enabled;
  final HomeBannerSelectionPolicy selectionPolicy;
  final String? fixedCampaignId;
  final List<HomeBannerCampaign> campaigns;

  factory HomeBannerConfig.fromJson(Map<String, Object?> json) {
    final rawCampaigns = json['campaigns'];
    return HomeBannerConfig(
      enabled: json['enabled'] == true,
      selectionPolicy: _policyFromString(json['selectionPolicy']?.toString()),
      fixedCampaignId: json['fixedCampaignId']?.toString(),
      campaigns: [
        if (rawCampaigns is List)
          for (final item in rawCampaigns)
            if (item is Map)
              HomeBannerCampaign.fromJson(Map<String, Object?>.from(item)),
      ],
    );
  }

  static HomeBannerConfig fromJsonString(String source) {
    return HomeBannerConfig.fromJson(
      jsonDecode(source) as Map<String, Object?>,
    );
  }
}

class HomeBannerCampaign {
  const HomeBannerCampaign({
    required this.id,
    required this.kind,
    required this.enabled,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.priority,
    this.targetUrl,
    this.asset,
  });

  final String id;
  final HomeBannerKind kind;
  final bool enabled;
  final String label;
  final String title;
  final String subtitle;
  final String ctaText;
  final String? targetUrl;
  final String? asset;
  final int priority;

  bool get canRenderLocally {
    return enabled &&
        kind != HomeBannerKind.adNetwork &&
        kind != HomeBannerKind.none;
  }

  factory HomeBannerCampaign.fromJson(Map<String, Object?> json) {
    return HomeBannerCampaign(
      id: json['id']?.toString() ?? '',
      kind: _kindFromString(json['kind']?.toString()),
      enabled: json['enabled'] == true,
      label: json['label']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      ctaText: json['ctaText']?.toString() ?? '',
      targetUrl: _nullableString(json['targetUrl']),
      asset: _nullableString(json['asset']),
      priority: int.tryParse(json['priority']?.toString() ?? '') ?? 0,
    );
  }
}

Future<HomeBannerCampaign?> selectHomeBannerCampaign({
  required HomeBannerConfig config,
  required AppPreferences preferences,
}) async {
  if (!config.enabled) {
    return null;
  }
  final eligible = _eligibleLocalCampaigns(config);
  if (eligible.isEmpty) {
    return null;
  }

  return switch (config.selectionPolicy) {
    HomeBannerSelectionPolicy.fixed => _selectFixed(config, eligible),
    HomeBannerSelectionPolicy.rotateOnAppLaunch => _selectRotating(
      preferences,
      eligible,
    ),
  };
}

Uri? safeHomeBannerUri(HomeBannerCampaign campaign) {
  final targetUrl = campaign.targetUrl;
  if (targetUrl == null || targetUrl.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(targetUrl.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return null;
  }
  return uri;
}

List<HomeBannerCampaign> _eligibleLocalCampaigns(HomeBannerConfig config) {
  final indexed = <({int index, HomeBannerCampaign campaign})>[
    for (var index = 0; index < config.campaigns.length; index += 1)
      if (config.campaigns[index].canRenderLocally)
        (index: index, campaign: config.campaigns[index]),
  ];
  indexed.sort((a, b) {
    final priority = a.campaign.priority.compareTo(b.campaign.priority);
    if (priority != 0) {
      return priority;
    }
    return a.index.compareTo(b.index);
  });
  return [for (final item in indexed) item.campaign];
}

HomeBannerCampaign _selectFixed(
  HomeBannerConfig config,
  List<HomeBannerCampaign> eligible,
) {
  for (final campaign in eligible) {
    if (campaign.id == config.fixedCampaignId) {
      return campaign;
    }
  }
  return eligible.first;
}

Future<HomeBannerCampaign> _selectRotating(
  AppPreferences preferences,
  List<HomeBannerCampaign> eligible,
) async {
  if (eligible.length == 1) {
    return eligible.first;
  }
  final previousId = await preferences.getString(
    homeBannerLastCampaignPreferenceKey,
  );
  final previousIndex = eligible.indexWhere(
    (campaign) => campaign.id == previousId,
  );
  final nextIndex = previousIndex < 0
      ? 0
      : (previousIndex + 1) % eligible.length;
  final selected = eligible[nextIndex];
  await preferences.setString(homeBannerLastCampaignPreferenceKey, selected.id);
  return selected;
}

HomeBannerKind _kindFromString(String? value) {
  return switch (value) {
    'affiliate' => HomeBannerKind.affiliate,
    'sponsored' => HomeBannerKind.sponsored,
    'house' => HomeBannerKind.house,
    'adNetwork' => HomeBannerKind.adNetwork,
    'none' => HomeBannerKind.none,
    _ => HomeBannerKind.none,
  };
}

HomeBannerSelectionPolicy _policyFromString(String? value) {
  return switch (value) {
    'rotateOnAppLaunch' => HomeBannerSelectionPolicy.rotateOnAppLaunch,
    _ => HomeBannerSelectionPolicy.fixed,
  };
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}
