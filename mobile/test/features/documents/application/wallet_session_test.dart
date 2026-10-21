import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:picoradar/core/storage/app_secure_storage.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';

void main() {
  late _Preferences preferences;
  late _Authenticator authenticator;
  late WalletSession session;

  setUp(() {
    preferences = _Preferences();
    authenticator = _Authenticator();
    session = WalletSession(
      authenticator: authenticator,
      preferences: preferences,
    );
  });

  tearDown(() => session.dispose());

  Future<void> protectedVisit() async {
    preferences.value = const WalletSecurityPreferences(
      protectionEnabled: true,
      offerSeen: true,
    );
    expect(await session.initialize(), isTrue);
  }

  test('unknown settings never authorize a visit', () {
    expect(session.initialized, isFalse);
    expect(session.unlocked, isFalse);
    expect(session.accessAllowed, isFalse);
    expect(session.isAuthorizedEpoch(session.epoch), isFalse);
  });

  test(
    'first visit offers optional protection without starting auth',
    () async {
      expect(await session.initialize(), isTrue);
      expect(session.offerSeen, isFalse);
      expect(session.protectionEnabled, isFalse);
      expect(session.unlocked, isFalse);
      expect(await session.unlock(), isTrue);
      expect(session.accessAllowed, isTrue);
      expect(authenticator.calls, 0);
      expect(preferences.writes, 0);
    },
  );

  test(
    'lock invalidates unprotected visit and previously captured epoch',
    () async {
      await session.unlock();
      final epoch = session.epoch;
      expect(session.isAuthorizedEpoch(epoch), isTrue);
      session.lock();
      expect(session.epoch, greaterThan(epoch));
      expect(session.accessAllowed, isFalse);
      expect(session.isAuthorizedEpoch(epoch), isFalse);
      expect(await session.unlock(), isTrue);
      expect(session.isAuthorizedEpoch(epoch), isFalse);
      expect(session.isAuthorizedEpoch(session.epoch), isTrue);
    },
  );

  test('protected wallet authenticates once per visit', () async {
    await protectedVisit();
    expect(session.accessAllowed, isFalse);
    expect(await session.unlock(), isTrue);
    expect(await session.unlock(), isTrue);
    expect(authenticator.calls, 1);
    session.lock();
    expect(await session.initialize(), isTrue);
    expect(session.accessAllowed, isFalse);
    expect(await session.unlock(), isTrue);
    expect(authenticator.calls, 2);
  });

  test('read error stays unknown through unlock and can be retried', () async {
    preferences.readError = StateError('secure storage unavailable');
    expect(await session.initialize(), isFalse);
    expect(await session.unlock(), isFalse);
    expect(await session.enableProtection(), isFalse);
    expect(await session.disableProtection(), isFalse);
    expect(await session.dismissOffer(), isFalse);
    expect(session.initialized, isFalse);
    expect(session.accessAllowed, isFalse);
    expect(session.failure, WalletSessionFailure.storageRead);
    expect(session.failureMessage, isNotEmpty);
    expect(preferences.writes, 0);
    expect(authenticator.calls, 0);
    preferences.readError = null;
    await protectedVisit();
    expect(session.accessAllowed, isFalse);
    expect(await session.unlock(), isTrue);
  });

  for (final result in <WalletAuthenticationResult>[
    WalletAuthenticationResult.cancelled,
    WalletAuthenticationResult.failed,
    WalletAuthenticationResult.noSecureDevice,
    WalletAuthenticationResult.unavailable,
  ]) {
    test('$result never unlocks or enables protection', () async {
      authenticator.result = result;
      await protectedVisit();
      expect(await session.unlock(), isFalse);
      expect(session.accessAllowed, isFalse);
      expect(session.failureMessage, isNotEmpty);
      expect(preferences.writes, 0);
      preferences.value = const WalletSecurityPreferences();
      final firstVisit = WalletSession(
        authenticator: authenticator,
        preferences: preferences,
      );
      addTearDown(firstVisit.dispose);
      expect(await firstVisit.enableProtection(), isFalse);
      expect(firstVisit.protectionEnabled, isFalse);
      expect(firstVisit.offerSeen, isFalse);
      expect(firstVisit.accessAllowed, isFalse);
      expect(preferences.writes, 0);
    });
  }

  test(
    'unsupported secure device has an actionable failure, no bypass',
    () async {
      authenticator.supported = false;
      await protectedVisit();
      expect(await session.unlock(), isFalse);
      expect(session.failure, WalletSessionFailure.noSecureDevice);
      expect(session.failureMessage, isNotEmpty);
      expect(session.protectionEnabled, isTrue);
      expect(session.accessAllowed, isFalse);
      expect(authenticator.calls, 0);
    },
  );

  for (final duringSupport in <bool>[true, false]) {
    test('auth exception during support=$duringSupport fails closed', () async {
      await protectedVisit();
      if (duringSupport) {
        authenticator.supportError = StateError('platform error');
      } else {
        authenticator.authError = StateError('platform error');
      }
      expect(await session.unlock(), isFalse);
      expect(session.accessAllowed, isFalse);
      expect(session.failure, WalletSessionFailure.authenticationUnavailable);
      expect(session.authenticating, isFalse);
      expect(session.busy, isFalse);
    });
  }

  test('enable waits for authentication then durable settings', () async {
    await session.unlock();
    final oldEpoch = session.epoch;
    authenticator.pending = Completer<WalletAuthenticationResult>();
    preferences.pendingWrite = Completer<void>();
    final enabling = session.enableProtection();
    await _flush();
    expect(session.authenticating, isTrue);
    expect(session.protectionEnabled, isFalse);
    expect(session.accessAllowed, isFalse);
    expect(preferences.writes, 0);
    authenticator.pending!.complete(WalletAuthenticationResult.success);
    await _flush();
    expect(session.busy, isTrue);
    expect(session.authenticating, isFalse);
    expect(session.protectionEnabled, isFalse);
    expect(session.accessAllowed, isFalse);
    preferences.pendingWrite!.complete();
    expect(await enabling, isTrue);
    expect(session.protectionEnabled, isTrue);
    expect(session.offerSeen, isTrue);
    expect(session.accessAllowed, isTrue);
    expect(session.isAuthorizedEpoch(oldEpoch), isFalse);
    expect(preferences.value.protectionEnabled, isTrue);
  });

  test('disable requires fresh auth even when already unlocked', () async {
    await protectedVisit();
    await session.unlock();
    final oldEpoch = session.epoch;
    authenticator.result = WalletAuthenticationResult.cancelled;
    expect(await session.disableProtection(), isFalse);
    expect(authenticator.calls, 2);
    expect(session.protectionEnabled, isTrue);
    expect(session.accessAllowed, isFalse);
    expect(session.isAuthorizedEpoch(oldEpoch), isFalse);
    expect(preferences.writes, 0);
    authenticator.result = WalletAuthenticationResult.success;
    expect(await session.disableProtection(), isTrue);
    expect(authenticator.calls, 3);
    expect(session.protectionEnabled, isFalse);
    expect(session.offerSeen, isTrue);
    expect(session.accessAllowed, isTrue);
  });

  test('dismiss persists offer without enabling or authenticating', () async {
    await session.unlock();
    expect(await session.dismissOffer(), isTrue);
    expect(session.offerSeen, isTrue);
    expect(session.protectionEnabled, isFalse);
    expect(session.accessAllowed, isTrue);
    expect(authenticator.calls, 0);
    final restart = WalletSession(
      authenticator: authenticator,
      preferences: preferences,
    );
    addTearDown(restart.dispose);
    await restart.initialize();
    expect(restart.offerSeen, isTrue);
    expect(restart.accessAllowed, isFalse);
  });

  for (final operation in <String>['enable', 'disable', 'dismiss']) {
    for (final commitThenThrow in <bool>[false, true]) {
      test(
        '$operation write failure (committed=$commitThenThrow) closes access',
        () async {
          if (operation == 'disable') await protectedVisit();
          await session.unlock();
          final oldEpoch = session.epoch;
          preferences.writeError = StateError('write did not acknowledge');
          preferences.commitThenThrow = commitThenThrow;
          expect(await _operation(session, operation), isFalse);
          expect(session.initialized, isFalse);
          expect(session.accessAllowed, isFalse);
          expect(session.isAuthorizedEpoch(oldEpoch), isFalse);
          expect(session.failure, WalletSessionFailure.storageWrite);
          expect(session.busy, isFalse);
          expect(session.authenticating, isFalse);
          preferences.writeError = null;
          expect(await session.initialize(), isTrue);
          expect(
            session.protectionEnabled,
            preferences.value.protectionEnabled,
          );
          expect(session.offerSeen, preferences.value.offerSeen);
          expect(session.accessAllowed, isFalse);
        },
      );
    }
  }

  test(
    'late settings read after lock cannot authorize or start auth',
    () async {
      preferences.pendingRead = Completer<WalletSecurityPreferences>();
      final unlocking = session.unlock();
      await _flush();
      expect(session.busy, isTrue);
      expect(session.authenticating, isFalse);
      session.lock();
      preferences.pendingRead!.complete(const WalletSecurityPreferences());
      expect(await unlocking, isFalse);
      expect(session.accessAllowed, isFalse);
      expect(authenticator.calls, 0);
    },
  );

  test('lock during support check prevents opening a native prompt', () async {
    await protectedVisit();
    authenticator.pendingSupport = Completer<bool>();
    final unlocking = session.unlock();
    await _flush();
    expect(session.authenticating, isTrue);
    session.lock();
    authenticator.pendingSupport!.complete(true);
    expect(await unlocking, isFalse);
    expect(authenticator.calls, 0);
    expect(session.accessAllowed, isFalse);
  });

  for (final operation in <String>['unlock', 'enable', 'disable']) {
    test('late $operation auth after lock cannot unlock or write', () async {
      if (operation != 'enable') await protectedVisit();
      authenticator.pending = Completer<WalletAuthenticationResult>();
      final pending = _operation(session, operation);
      await _flush();
      expect(session.authenticating, isTrue);
      final epoch = session.epoch;
      session.lock();
      session.lock();
      expect(session.epoch, greaterThan(epoch));
      expect(session.busy, isTrue);
      expect(session.authenticating, isTrue);
      expect(await session.unlock(), isFalse);
      expect(await session.enableProtection(), isFalse);
      expect(await session.disableProtection(), isFalse);
      expect(await session.dismissOffer(), isFalse);
      authenticator.pending!.complete(WalletAuthenticationResult.success);
      expect(await pending, isFalse);
      expect(session.accessAllowed, isFalse);
      expect(session.busy, isFalse);
      expect(session.authenticating, isFalse);
      expect(preferences.writes, 0);
      expect(authenticator.calls, 1);
    });
  }

  for (final operation in <String>['enable', 'disable', 'dismiss']) {
    test(
      'late $operation write after lock updates settings but never visit',
      () async {
        if (operation == 'disable') await protectedVisit();
        await session.unlock();
        preferences.pendingWrite = Completer<void>();
        final pending = _operation(session, operation);
        await _flush();
        expect(session.busy, isTrue);
        expect(session.authenticating, isFalse);
        session.lock();
        preferences.pendingWrite!.complete();
        expect(await pending, isFalse);
        expect(session.accessAllowed, isFalse);
        expect(session.protectionEnabled, preferences.value.protectionEnabled);
        expect(session.offerSeen, preferences.value.offerSeen);
        expect(session.busy, isFalse);
      },
    );
  }

  test('concurrent unlocks never open multiple native prompts', () async {
    await protectedVisit();
    authenticator.pending = Completer<WalletAuthenticationResult>();
    final first = session.unlock();
    expect(await session.unlock(), isFalse);
    await _flush();
    expect(authenticator.calls, 1);
    authenticator.pending!.complete(WalletAuthenticationResult.success);
    expect(await first, isTrue);
  });

  test(
    'reentrant listener lock cannot be bypassed by synchronous off unlock',
    () async {
      await session.initialize();
      session.addListener(() {
        if (session.busy) session.lock();
      });
      expect(await session.unlock(), isFalse);
      expect(session.accessAllowed, isFalse);
    },
  );

  test('dispose invalidates pending auth without late notifications', () async {
    final other = WalletSession(
      authenticator: authenticator,
      preferences: preferences,
    );
    preferences.value = const WalletSecurityPreferences(
      protectionEnabled: true,
      offerSeen: true,
    );
    authenticator.pending = Completer<WalletAuthenticationResult>();
    var notifications = 0;
    other.addListener(() => notifications++);
    final unlocking = other.unlock();
    await _flush();
    final epoch = other.epoch;
    other.dispose();
    final before = notifications;
    authenticator.pending!.complete(WalletAuthenticationResult.success);
    expect(await unlocking, isFalse);
    expect(other.isAuthorizedEpoch(epoch), isFalse);
    expect(other.accessAllowed, isFalse);
    expect(notifications, before);
    expect(await other.unlock(), isFalse);
    expect(await other.initialize(), isFalse);
  });

  group('secure preferences adapter', () {
    test(
      'stores both flags as one versioned AppSecureStorage record',
      () async {
        final storage = _SecureStorage();
        final store = SecureWalletSecurityPreferencesStore(storage: storage);
        final first = await store.read();
        expect(first.protectionEnabled, isFalse);
        expect(first.offerSeen, isFalse);
        await store.write(
          const WalletSecurityPreferences(
            protectionEnabled: true,
            offerSeen: true,
          ),
        );
        expect(storage.values, hasLength(1));
        expect(jsonDecode(storage.values.values.single), <String, Object>{
          'version': 1,
          'protectionEnabled': true,
          'offerSeen': true,
        });
        final restored = await store.read();
        expect(restored.protectionEnabled, isTrue);
        expect(restored.offerSeen, isTrue);
      },
    );

    for (final corrupt in <String>[
      '',
      'null',
      '[]',
      '{}',
      'not json',
      '{"version":2,"protectionEnabled":false,"offerSeen":false}',
      '{"version":1,"protectionEnabled":"false","offerSeen":false}',
      '{"version":1,"protectionEnabled":false}',
      '{"version":1,"protectionEnabled":false,"offerSeen":0}',
    ]) {
      test('malformed secure record fails closed: $corrupt', () async {
        final storage = _SecureStorage()..readValue = corrupt;
        final other = WalletSession(
          authenticator: authenticator,
          preferences: SecureWalletSecurityPreferencesStore(storage: storage),
        );
        addTearDown(other.dispose);
        expect(await other.unlock(), isFalse);
        expect(other.initialized, isFalse);
        expect(other.accessAllowed, isFalse);
        expect(other.failure, WalletSessionFailure.storageRead);
        expect(storage.values, isEmpty);
      });
    }
  });

  group('official local_auth 3.0.2 adapter', () {
    test('uses device support and allows OS credential fallback', () async {
      final native = _LocalAuthentication();
      final adapter = LocalAuthWalletAuthenticator(authentication: native);
      expect(await adapter.canAuthenticate(), isTrue);
      expect(native.supportChecks, 1);
      expect(await adapter.authenticate(), WalletAuthenticationResult.success);
      expect(native.reason, isNotEmpty);
      expect(native.biometricOnly, isFalse);
      expect(native.sensitiveTransaction, isTrue);
      expect(native.persistAcrossBackgrounding, isFalse);
    });

    test('false native result is failed, never success', () async {
      final native = _LocalAuthentication()..result = false;
      expect(
        await LocalAuthWalletAuthenticator(authentication: native)
            .authenticate(),
        WalletAuthenticationResult.failed,
      );
    });

    for (final entry in <LocalAuthExceptionCode, WalletAuthenticationResult>{
      LocalAuthExceptionCode.userCanceled: WalletAuthenticationResult.cancelled,
      LocalAuthExceptionCode.systemCanceled:
          WalletAuthenticationResult.cancelled,
      LocalAuthExceptionCode.timeout: WalletAuthenticationResult.cancelled,
      LocalAuthExceptionCode.noCredentialsSet:
          WalletAuthenticationResult.noSecureDevice,
      LocalAuthExceptionCode.temporaryLockout:
          WalletAuthenticationResult.unavailable,
      LocalAuthExceptionCode.biometricLockout:
          WalletAuthenticationResult.unavailable,
      LocalAuthExceptionCode.uiUnavailable:
          WalletAuthenticationResult.unavailable,
      LocalAuthExceptionCode.unknownError:
          WalletAuthenticationResult.unavailable,
    }.entries) {
      test('maps ${entry.key} without exposing native details', () async {
        final native = _LocalAuthentication()
          ..error = LocalAuthException(
            code: entry.key,
            description: 'private detail',
          );
        expect(
          await LocalAuthWalletAuthenticator(authentication: native)
              .authenticate(),
          entry.value,
        );
      });
    }
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

Future<bool> _operation(WalletSession session, String operation) =>
    switch (operation) {
      'unlock' => session.unlock(),
      'enable' => session.enableProtection(),
      'disable' => session.disableProtection(),
      'dismiss' => session.dismissOffer(),
      _ => throw ArgumentError.value(operation),
    };

class _Preferences implements WalletSecurityPreferencesStore {
  WalletSecurityPreferences value = const WalletSecurityPreferences();
  Object? readError;
  Object? writeError;
  bool commitThenThrow = false;
  Completer<WalletSecurityPreferences>? pendingRead;
  Completer<void>? pendingWrite;
  int writes = 0;

  @override
  Future<WalletSecurityPreferences> read() async {
    if (readError != null) throw readError!;
    return pendingRead == null ? value : await pendingRead!.future;
  }

  @override
  Future<void> write(WalletSecurityPreferences settings) async {
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
    if (writeError != null && !commitThenThrow) throw writeError!;
    value = settings;
    if (writeError != null) throw writeError!;
  }
}

class _Authenticator implements WalletDeviceAuthenticator {
  bool supported = true;
  WalletAuthenticationResult result = WalletAuthenticationResult.success;
  Object? supportError;
  Object? authError;
  Completer<bool>? pendingSupport;
  Completer<WalletAuthenticationResult>? pending;
  int calls = 0;

  @override
  Future<bool> canAuthenticate() async {
    if (supportError != null) throw supportError!;
    return pendingSupport == null ? supported : await pendingSupport!.future;
  }

  @override
  Future<WalletAuthenticationResult> authenticate() async {
    calls++;
    if (authError != null) throw authError!;
    return pending == null ? result : await pending!.future;
  }
}

class _SecureStorage extends AppSecureStorage {
  final values = <String, String>{};
  String? readValue;

  @override
  Future<String?> readSecret(String key) async => readValue ?? values[key];

  @override
  Future<void> writeSecret(String key, String value) async =>
      values[key] = value;
}

class _LocalAuthentication extends LocalAuthentication {
  int supportChecks = 0;
  bool result = true;
  Object? error;
  String? reason;
  bool? biometricOnly;
  bool? sensitiveTransaction;
  bool? persistAcrossBackgrounding;

  @override
  Future<bool> isDeviceSupported() async {
    supportChecks++;
    return true;
  }

  @override
  Future<bool> get canCheckBiometrics =>
      throw StateError('biometrics are optional');

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    reason = localizedReason;
    this.biometricOnly = biometricOnly;
    this.sensitiveTransaction = sensitiveTransaction;
    this.persistAcrossBackgrounding = persistAcrossBackgrounding;
    if (error != null) throw error!;
    return result;
  }
}
