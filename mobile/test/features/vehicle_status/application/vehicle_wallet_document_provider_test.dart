import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/data/wallet_models.dart';

void main() {
  late WalletSession session;
  setUp(
    () => session = WalletSession(
      authenticator: _Authenticator(),
      preferences: _Preferences(),
    ),
  );
  tearDown(() => session.dispose());

  test('locked projection does not request document metadata', () async {
    var requests = 0;
    final container = ProviderContainer(
      overrides: [
        walletSessionProvider.overrideWithValue(session),
        walletDocumentsProvider(const WalletOwner.vehicle('one'))
            .overrideWith((ref) async {
              requests++;
              return [_doc('one', WalletDocumentType.soat)];
            }),
      ],
    );
    addTearDown(container.dispose);
    final doc = await container.read(
      vehicleWalletDocumentProvider(('one', WalletDocumentType.soat)).future,
    );
    expect(doc, isNull);
    expect(requests, 0);
  });

  test(
    'projection shares list invalidation and selects exact owner and type',
    () async {
      await session.unlock();
      var rows = [
        _doc('one', WalletDocumentType.rtm),
        _doc('two', WalletDocumentType.soat),
        _doc('one', WalletDocumentType.soat),
      ];
      final list = walletDocumentsProvider(const WalletOwner.vehicle('one'));
      final container = ProviderContainer(
        overrides: [
          walletSessionProvider.overrideWithValue(session),
          list.overrideWith((ref) async => rows),
        ],
      );
      addTearDown(container.dispose);
      final projection = vehicleWalletDocumentProvider((
        'one',
        WalletDocumentType.soat,
      ));
      final subscription = container.listen(projection, (_, _) {});
      addTearDown(subscription.close);
      expect((await container.read(projection.future))?.id, 'one-soat');
      rows = [];
      container.invalidate(list);
      expect(await container.read(projection.future), isNull);
    },
  );

  test('late metadata after lock is discarded even when list provider is overridden', () async {
    await session.unlock();
    final pending = Completer<List<WalletDocument>>();
    final container = ProviderContainer(
      overrides: [
        walletSessionProvider.overrideWithValue(session),
        walletDocumentsProvider(const WalletOwner.vehicle('one'))
            .overrideWith((ref) => pending.future),
      ],
    );
    addTearDown(container.dispose);
    final projection = vehicleWalletDocumentProvider((
      'one',
      WalletDocumentType.soat,
    ));
    final subscription = container.listen(projection, (_, _) {});
    addTearDown(subscription.close);
    final request = container.read(projection.future);
    session.lock();
    pending.complete([_doc('one', WalletDocumentType.soat)]);
    expect(await request, isNull);
  });
}

WalletDocument _doc(String ownerId, WalletDocumentType type) => WalletDocument(
  id: '$ownerId-${type.value}',
  owner: WalletOwner.vehicle(ownerId),
  type: type,
  importedAt: DateTime.utc(2026, 9, 13),
  pdf: const WalletFileRef(
    encryptedRelativePath: 'private.prcf',
    originalName: 'private-name.pdf',
    mimeType: 'application/pdf',
  ),
);

class _Preferences implements WalletSecurityPreferencesStore {
  @override
  Future<WalletSecurityPreferences> read() async =>
      const WalletSecurityPreferences(offerSeen: true);
  @override
  Future<void> write(WalletSecurityPreferences preferences) async {}
}

class _Authenticator implements WalletDeviceAuthenticator {
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<WalletAuthenticationResult> authenticate() async =>
      WalletAuthenticationResult.success;
}
