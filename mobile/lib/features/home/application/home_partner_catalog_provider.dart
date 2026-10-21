import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/home_partner_catalog.dart';

final campaignCatalogUriProvider = Provider<Uri?>((ref) {
  return resolveCampaignCatalogUri(
    campaignCatalogUrl: const String.fromEnvironment('CAMPAIGN_CATALOG_URL'),
    cdnBaseUrl: const String.fromEnvironment('CDN_BASE_URL'),
  );
});

final homePartnerCatalogRepositoryProvider =
    FutureProvider<HomePartnerCatalogRepository?>((ref) async {
      final manifestUri = ref.watch(campaignCatalogUriProvider);
      if (manifestUri == null) return null;

      final supportDirectory = await getApplicationSupportDirectory();
      final cache = FileCampaignCatalogCache(
        File(
          '${supportDirectory.path}${Platform.pathSeparator}campaigns'
          '${Platform.pathSeparator}home_partner_catalog.json',
        ),
      );
      final http = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      ref.onDispose(() => http.close(force: true));
      return HomePartnerCatalogRepository(
        manifestUri: manifestUri,
        http: http,
        cache: cache,
      );
    });

final homePartnerCampaignsProvider = FutureProvider.autoDispose
    .family<List<HomePartnerCampaign>, CampaignTerritoryContext>((
      ref,
      territory,
    ) async {
      final repository = await ref.watch(
        homePartnerCatalogRepositoryProvider.future,
      );
      if (repository == null) return fallbackHomePartnerCampaigns;
      return repository.load(territory);
    });

Uri? resolveCampaignCatalogUri({
  required String campaignCatalogUrl,
  required String cdnBaseUrl,
}) {
  final explicit = campaignCatalogUrl.trim();
  final base = cdnBaseUrl.trim();
  final uri = explicit.isNotEmpty
      ? Uri.tryParse(explicit)
      : base.isNotEmpty
      ? Uri.tryParse(base)?.resolve('/storage/campaigns/v1/catalog.json')
      : null;
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}
