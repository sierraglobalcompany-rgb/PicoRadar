import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/storage/app_secure_storage.dart';

enum WalletAuthenticationResult {
  success,
  cancelled,
  failed,
  noSecureDevice,
  unavailable,
}

abstract interface class WalletDeviceAuthenticator {
  Future<bool> canAuthenticate();
  Future<WalletAuthenticationResult> authenticate();
}

/// Delegates credentials entirely to the OS; the app never receives a PIN.
class LocalAuthWalletAuthenticator implements WalletDeviceAuthenticator {
  LocalAuthWalletAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> canAuthenticate() async {
    try {
      return await _authentication.isDeviceSupported();
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.noCredentialsSet) return false;
      rethrow;
    }
  }

  @override
  Future<WalletAuthenticationResult> authenticate() async {
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: 'Confirma tu identidad para acceder a tu billetera.',
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: false,
      );
      return authenticated
          ? WalletAuthenticationResult.success
          : WalletAuthenticationResult.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => WalletAuthenticationResult.cancelled,
        LocalAuthExceptionCode.noCredentialsSet =>
          WalletAuthenticationResult.noSecureDevice,
        _ => WalletAuthenticationResult.unavailable,
      };
    } catch (_) {
      // Expose a bounded failure, never native details or sensitive logs.
      return WalletAuthenticationResult.unavailable;
    }
  }
}

@immutable
class WalletSecurityPreferences {
  const WalletSecurityPreferences({
    this.protectionEnabled = false,
    this.offerSeen = false,
  });

  final bool protectionEnabled;
  final bool offerSeen;
}

abstract interface class WalletSecurityPreferencesStore {
  Future<WalletSecurityPreferences> read();
  Future<void> write(WalletSecurityPreferences preferences);
}

/// One secure record prevents partially updated protection/offer flags.
class SecureWalletSecurityPreferencesStore
    implements WalletSecurityPreferencesStore {
  SecureWalletSecurityPreferencesStore({AppSecureStorage? storage})
    : _storage = storage ?? AppSecureStorage();

  static const _key = 'wallet_security_preferences_v1';
  final AppSecureStorage _storage;

  @override
  Future<WalletSecurityPreferences> read() async {
    final encoded = await _storage.readSecret(_key);
    if (encoded == null) return const WalletSecurityPreferences();
    final record = jsonDecode(encoded);
    if (record is! Map<String, dynamic> ||
        record['version'] != 1 ||
        record['protectionEnabled'] is! bool ||
        record['offerSeen'] is! bool) {
      throw const FormatException('Invalid wallet security preferences.');
    }
    return WalletSecurityPreferences(
      protectionEnabled: record['protectionEnabled'] as bool,
      offerSeen: record['offerSeen'] as bool,
    );
  }

  @override
  Future<void> write(WalletSecurityPreferences preferences) =>
      _storage.writeSecret(
        _key,
        jsonEncode(<String, Object>{
          'version': 1,
          'protectionEnabled': preferences.protectionEnabled,
          'offerSeen': preferences.offerSeen,
        }),
      );
}

enum WalletSessionFailure {
  storageRead,
  storageWrite,
  noSecureDevice,
  authenticationCancelled,
  authenticationFailed,
  authenticationUnavailable,
}

/// Own one instance across wallet/list/viewer/scanner routes.
///
/// initialize() reads settings only. unlock() authorizes a visit, including
/// when protection is off. Gate documents with accessAllowed, never with
/// !protectionEnabled. Capture epoch before async document work and check
/// isAuthorizedEpoch before exposing results or committing data.
///
/// The parent calls lock() on wallet route exit or real background. This class
/// does not observe inactive: a native authentication prompt also causes it.
/// Scanner return/background policy belongs to the parent. lock() invalidates
/// pending auth without repeatedly cancelling or restarting the native prompt.
class WalletSession extends ChangeNotifier {
  WalletSession({required this._authenticator, required this._preferences});

  final WalletDeviceAuthenticator _authenticator;
  final WalletSecurityPreferencesStore _preferences;

  bool _initialized = false;
  bool _protectionEnabled = false;
  bool _unlocked = false;
  bool _offerSeen = false;
  bool _busy = false;
  bool _authenticating = false;
  bool _disposed = false;
  int _epoch = 0;
  WalletSessionFailure? _failure;

  bool get initialized => _initialized;
  bool get protectionEnabled => _protectionEnabled;
  bool get unlocked => _unlocked;
  bool get offerSeen => _offerSeen;
  bool get busy => _busy;

  /// Includes the support check and native prompt, but not secure storage I/O.
  bool get authenticating => _authenticating;

  int get epoch => _epoch;
  bool get accessAllowed => !_disposed && _initialized && _unlocked;
  WalletSessionFailure? get failure => _failure;

  String? get failureMessage => switch (_failure) {
    null => null,
    WalletSessionFailure.storageRead =>
      'No se pudo leer la protecci\u00f3n de tu billetera. Intenta de nuevo.',
    WalletSessionFailure.storageWrite =>
      'No se pudo confirmar el cambio de protecci\u00f3n. Intenta de nuevo.',
    WalletSessionFailure.noSecureDevice =>
      'Configura un PIN, patr\u00f3n o contrase\u00f1a en los ajustes de '
          'seguridad del dispositivo para proteger tu billetera.',
    WalletSessionFailure.authenticationCancelled =>
      'Autenticaci\u00f3n cancelada. La billetera sigue bloqueada.',
    WalletSessionFailure.authenticationFailed =>
      'No se pudo confirmar tu identidad. Intenta de nuevo.',
    WalletSessionFailure.authenticationUnavailable =>
      'La autenticaci\u00f3n del dispositivo no est\u00e1 disponible. '
          'Intenta de nuevo.',
  };

  bool isAuthorizedEpoch(int capturedEpoch) =>
      accessAllowed && capturedEpoch == _epoch;

  Future<bool> initialize() => _run((epoch) async {
    return await _loadPreferences() && _isCurrent(epoch);
  });

  Future<bool> unlock() => _run((epoch) async {
    if (!await _loadPreferences() || !_isCurrent(epoch)) return false;
    if (_unlocked) return true;
    if (_protectionEnabled && !await _authenticate(epoch)) return false;
    if (!_isCurrent(epoch)) return false;
    _unlocked = true;
    return true;
  });

  Future<bool> enableProtection() => _changeProtection(true);

  /// A previous visit unlock is never reused to disable protection.
  Future<bool> disableProtection() => _changeProtection(false);

  Future<bool> _changeProtection(bool enabled) => _run((epoch) async {
    if (!await _loadPreferences() || !_isCurrent(epoch)) return false;
    if (!await _authenticate(epoch) || !_isCurrent(epoch)) return false;
    final stored = await _writePreferences(
      WalletSecurityPreferences(protectionEnabled: enabled, offerSeen: true),
    );
    if (!stored || !_isCurrent(epoch)) return false;
    _unlocked = true;
    return true;
  }, revoke: true);

  Future<bool> dismissOffer() => _run((epoch) async {
    if (!await _loadPreferences() || !_isCurrent(epoch)) return false;
    if (_offerSeen) return true;
    return await _writePreferences(
          WalletSecurityPreferences(
            protectionEnabled: _protectionEnabled,
            offerSeen: true,
          ),
        ) &&
        _isCurrent(epoch);
  });

  /// Revokes immediately; busy stays true until outstanding work settles.
  void lock() {
    if (_disposed) return;
    final changed = _unlocked || _failure != null;
    _epoch++;
    _unlocked = false;
    _failure = null;
    if (changed) notifyListeners();
  }

  bool _isCurrent(int epoch) => !_disposed && epoch == _epoch;

  Future<bool> _run(
    Future<bool> Function(int epoch) action, {
    bool revoke = false,
  }) async {
    if (_disposed || _busy) return false;
    if (revoke) {
      _epoch++;
      _unlocked = false;
    }
    final epoch = _epoch;
    _busy = true;
    _failure = null;
    var result = false;
    try {
      notifyListeners();
      if (_isCurrent(epoch)) result = await action(epoch);
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
    // A listener may lock while receiving the final state notification.
    return result && _isCurrent(epoch);
  }

  Future<bool> _loadPreferences() async {
    if (_initialized) return true;
    try {
      final settings = await _preferences.read();
      if (_disposed) return false;
      _acceptPreferences(settings);
      return true;
    } catch (_) {
      if (!_disposed) _fail(WalletSessionFailure.storageRead, unknown: true);
      return false;
    }
  }

  Future<bool> _writePreferences(WalletSecurityPreferences settings) async {
    try {
      await _preferences.write(settings);
      if (_disposed) return false;
      // A completed durable write still matters after lock, but grants no visit.
      _acceptPreferences(settings);
      return true;
    } catch (_) {
      // Storage may have committed before throwing; reread before any access.
      if (!_disposed) _fail(WalletSessionFailure.storageWrite, unknown: true);
      return false;
    }
  }

  void _acceptPreferences(WalletSecurityPreferences settings) {
    _protectionEnabled = settings.protectionEnabled;
    _offerSeen = settings.offerSeen;
    _initialized = true;
  }

  Future<bool> _authenticate(int epoch) async {
    if (!_isCurrent(epoch)) return false;
    _authenticating = true;
    var authenticated = false;
    try {
      notifyListeners();
      if (!_isCurrent(epoch)) return false;
      final supported = await _authenticator.canAuthenticate();
      if (!_isCurrent(epoch)) return false;
      if (!supported) {
        _fail(WalletSessionFailure.noSecureDevice);
        return false;
      }
      final result = await _authenticator.authenticate();
      if (!_isCurrent(epoch)) return false;
      if (result == WalletAuthenticationResult.success) {
        authenticated = true;
      } else {
        _fail(switch (result) {
          WalletAuthenticationResult.cancelled =>
            WalletSessionFailure.authenticationCancelled,
          WalletAuthenticationResult.failed =>
            WalletSessionFailure.authenticationFailed,
          WalletAuthenticationResult.noSecureDevice =>
            WalletSessionFailure.noSecureDevice,
          _ => WalletSessionFailure.authenticationUnavailable,
        });
      }
    } catch (_) {
      if (_isCurrent(epoch)) {
        _fail(WalletSessionFailure.authenticationUnavailable);
      }
    } finally {
      _authenticating = false;
      if (!_disposed) notifyListeners();
    }
    return authenticated && _isCurrent(epoch);
  }

  void _fail(WalletSessionFailure failure, {bool unknown = false}) {
    _epoch++;
    _unlocked = false;
    _failure = failure;
    if (unknown) _initialized = false;
  }

  @override
  void dispose() {
    _epoch++;
    _unlocked = false;
    _disposed = true;
    super.dispose();
  }
}
