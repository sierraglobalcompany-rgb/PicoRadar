import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cryptography/cryptography.dart';

import '../../../app/app_providers.dart';
import '../../../core/storage/app_secure_storage.dart';
import '../data/wallet_store.dart';
import '../platform/wallet_platform.dart';
import 'wallet_session.dart';

final walletPlatformProvider = Provider<WalletPlatform>(
  (ref) => const WalletPlatform(),
);
final walletFileKeyProvider = Provider<Future<SecretKey> Function()>(
  (ref) => AppSecureStorage().getOrCreateFileMasterKey,
);

final walletStoreProvider = Provider<WalletStore>((ref) {
  final platform = ref.watch(walletPlatformProvider);
  return WalletStore(
    db: ref.watch(appDatabaseProvider),
    legacyStore: ref.watch(privateVehicleDocumentStoreProvider),
    rootDirectory: () async => Directory(await platform.noBackupDirectory()),
    cacheDirectory: getTemporaryDirectory,
    masterKey: ref.watch(walletFileKeyProvider),
  );
});

final walletSessionProvider = Provider<WalletSession>((ref) {
  final session = WalletSession(
    authenticator: LocalAuthWalletAuthenticator(),
    preferences: SecureWalletSecurityPreferencesStore(),
  );
  ref.onDispose(session.dispose);
  return session;
});

final walletDriversProvider = FutureProvider.autoDispose<List<WalletDriver>>((
  ref,
) async {
  final session = ref.watch(walletSessionProvider);
  session.addListener(ref.invalidateSelf);
  ref.onDispose(() => session.removeListener(ref.invalidateSelf));
  if (!session.accessAllowed) throw StateError('Wallet is locked.');
  final store = ref.watch(walletStoreProvider);
  await store.initialize();
  return store.listDrivers();
});

final walletDocumentsProvider = FutureProvider.autoDispose
    .family<List<WalletDocument>, WalletOwner>((ref, owner) async {
      final session = ref.watch(walletSessionProvider);
      session.addListener(ref.invalidateSelf);
      ref.onDispose(() => session.removeListener(ref.invalidateSelf));
      if (!session.accessAllowed) throw StateError('Wallet is locked.');
      final store = ref.watch(walletStoreProvider);
      await store.initialize();
      return store.listDocuments(owner: owner);
    });

final walletOperationProvider = Provider<WalletOperation>(
  (ref) => WalletOperation(),
);

class WalletOperation {
  bool busy = false;
}

final walletScreenSecurityProvider = Provider<WalletScreenSecurity>(
  (ref) => WalletScreenSecurity(ref.watch(walletPlatformProvider)),
);

// Secure windows are shared by the wallet, modal preview and full-screen viewer.
// Releasing an underlying page must not unprotect a viewer still above it.
class WalletScreenSecurity {
  WalletScreenSecurity(this._platform);
  final WalletPlatform _platform;
  final Set<Object> _owners = {};
  Future<void> _tail = Future<void>.value();

  Future<void> acquire(Object owner) {
    _owners.add(owner);
    return _update();
  }

  Future<void> release(Object owner) {
    _owners.remove(owner);
    return _update();
  }

  Future<void> _update() {
    final operation = _tail.then(
      (_) => _platform.setSecure(_owners.isNotEmpty),
    );
    _tail = operation.catchError((Object _) {});
    return operation;
  }
}
