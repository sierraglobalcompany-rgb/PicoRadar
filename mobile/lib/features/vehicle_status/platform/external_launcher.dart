import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final externalLauncherProvider = Provider<ExternalLauncher>((ref) {
  return const UrlExternalLauncher();
});

abstract interface class ExternalLauncher {
  Future<bool> openExternal(String uri);

  Future<bool> callPhone(String phone);
}

class UrlExternalLauncher implements ExternalLauncher {
  const UrlExternalLauncher();

  @override
  Future<bool> openExternal(String uri) {
    return launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
  }

  @override
  Future<bool> callPhone(String phone) {
    final normalized = normalizePhoneForTel(phone);
    if (normalized.isEmpty) {
      return Future.value(false);
    }
    return launchUrl(Uri(scheme: 'tel', path: normalized));
  }
}

String normalizePhoneForTel(String phone) {
  return phone.trim().replaceAll(RegExp(r'[\s-]+'), '');
}
