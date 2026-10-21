import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/documents/presentation/wallet_access_gate.dart';

const _documentsPath = '/apps/module/documentos';
const _otherPath = '/other';
const _privateKey = ValueKey('private-wallet-content');
const _unlockKey = ValueKey('wallet-unlock');

void main() {
  testWidgets('route exit revokes pending auth in a retained Gate', (
    tester,
  ) async {
    final harness = _GateHarness();
    final authentication = harness.authenticator.holdNext();
    await harness.mount(tester);
    await _until(tester, () => harness.authenticator.calls == 1);
    expect(harness.session.authenticating, isTrue);
    final gate = tester.element(find.byType(WalletAccessGate));
    final epoch = harness.session.epoch;

    harness.router.go(_otherPath);
    await _until(tester, () => find.text('Other route').evaluate().isNotEmpty);
    expect(gate.mounted, isTrue);
    expect(harness.session.epoch, greaterThan(epoch));
    expect(harness.session.accessAllowed, isFalse);

    authentication.complete(WalletAuthenticationResult.success);
    await _until(tester, () => !harness.session.busy);
    await _frames(tester);
    expect(harness.session.accessAllowed, isFalse);
    expect(harness.session.isAuthorizedEpoch(epoch), isFalse);
    expect(find.byKey(_privateKey, skipOffstage: false), findsNothing);
    expect(harness.platform.secure, isFalse);
    expect(harness.authenticator.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late secure acquisition cannot expose an exited Gate', (
    tester,
  ) async {
    final harness = _GateHarness();
    final native = harness.platform.hold();
    await harness.mount(tester);
    await _until(tester, () => harness.session.accessAllowed);
    expect(harness.platform.calls, contains(true));
    expect(find.byKey(_privateKey, skipOffstage: false), findsNothing);
    final epoch = harness.session.epoch;

    harness.router.go(_otherPath);
    await _frames(tester);
    expect(harness.session.isAuthorizedEpoch(epoch), isFalse);
    native.complete();
    await _until(tester, () => harness.platform.applied.contains(false));
    await _frames(tester);
    expect(harness.platform.secure, isFalse);
    expect(find.byKey(_privateKey, skipOffstage: false), findsNothing);
    expect(find.text('Other route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'off-route unlock stays masked and return waits for fresh auth and secure',
    (tester) async {
      final harness = _GateHarness();
      await harness.mount(tester);
      await _until(tester, () => find.byKey(_privateKey).evaluate().isNotEmpty);
      final privateElement = tester.element(find.byKey(_privateKey));
      harness.focus.requestFocus();
      await _frames(tester);
      expect(harness.focus.hasFocus, isTrue);

      harness.router.go(_otherPath);
      await _until(tester, () => !harness.platform.secure);
      expect(privateElement.mounted, isTrue);
      expect(harness.focus.hasFocus, isFalse);
      final callsBeforeExternalVisit = harness.platform.calls.length;

      // Another entry point (SOAT) shares this session, not this Gate's route.
      expect(await harness.session.unlock(), isTrue);
      await _frames(tester);
      expect(find.byKey(_privateKey), findsNothing);
      expect(privateElement.mounted, isTrue);
      _expectGateMasked(tester);
      expect(
        harness.platform.calls.skip(callsBeforeExternalVisit),
        everyElement(isFalse),
      );
      expect(harness.platform.secure, isFalse);

      // SOAT owns its visit and locks in finally when its sheet closes.
      harness.session.lock();
      await _frames(tester);
      final callsBeforeReturn = harness.authenticator.calls;
      final authentication = harness.authenticator.holdNext();
      final native = harness.platform.hold();
      harness.router.go(_documentsPath);
      await _until(
        tester,
        () => harness.authenticator.calls == callsBeforeReturn + 1,
      );
      expect(harness.session.authenticating, isTrue);
      expect(harness.authenticator.calls, callsBeforeReturn + 1);
      expect(find.byKey(_privateKey), findsNothing);
      _expectGateMasked(tester);

      authentication.complete(WalletAuthenticationResult.success);
      await _until(tester, () => harness.session.accessAllowed);
      expect(find.byKey(_privateKey), findsNothing);
      expect(harness.platform.secure, isFalse);
      native.complete();
      await _until(tester, () => find.byKey(_privateKey).evaluate().isNotEmpty);
      expect(harness.platform.secure, isTrue);
      expect(tester.element(find.byKey(_privateKey)), same(privateElement));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native acquire failure hides content and explicit retry recovers',
    (tester) async {
      final harness = _GateHarness();
      harness.platform.failEnable = true;
      await harness.mount(tester);
      await _until(
        tester,
        () => find.textContaining('No se pudo proteger').evaluate().isNotEmpty,
      );
      expect(find.byKey(_privateKey, skipOffstage: false), findsNothing);
      expect(harness.platform.secure, isFalse);
      expect(find.textContaining('native private detail'), findsNothing);

      harness.platform.failEnable = false;
      final native = harness.platform.hold();
      await tester.tap(find.byKey(_unlockKey));
      await _frames(tester);
      expect(find.byKey(_privateKey), findsNothing);
      native.complete();
      await _until(tester, () => find.byKey(_privateKey).evaluate().isNotEmpty);
      expect(harness.platform.secure, isTrue);
      expect(find.textContaining('No se pudo proteger'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed release stays secure and next visit restores screenshots',
    (tester) async {
      final harness = _GateHarness();
      await harness.mount(tester);
      await _until(tester, () => find.byKey(_privateKey).evaluate().isNotEmpty);
      harness.platform.failDisable = true;
      harness.router.go(_otherPath);
      await _until(tester, () => harness.platform.releaseFailures > 0);
      expect(harness.platform.secure, isTrue);
      expect(harness.session.accessAllowed, isFalse);
      expect(find.byKey(_privateKey), findsNothing);
      _expectGateMasked(tester);

      harness.platform.failDisable = false;
      harness.router.go(_documentsPath);
      await _until(tester, () => find.byKey(_privateKey).evaluate().isNotEmpty);
      expect(harness.platform.secure, isTrue);
      harness.router.go(_otherPath);
      await _until(tester, () => !harness.platform.secure);
      expect(find.byKey(_privateKey), findsNothing);
      expect(find.text('Other route'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('route release occurs after the private frame is masked', (
    tester,
  ) async {
    final harness = _GateHarness();
    await harness.mount(tester);
    await _until(tester, () => find.byKey(_privateKey).evaluate().isNotEmpty);
    final visibleAtRelease = <bool>[];
    harness.platform.onApplied = (enabled) {
      if (!enabled) {
        visibleAtRelease.add(find.byKey(_privateKey).evaluate().isNotEmpty);
      }
    };

    harness.router.go(_otherPath);
    await _until(tester, () => visibleAtRelease.isNotEmpty);
    expect(visibleAtRelease, everyElement(isFalse));
    expect(harness.platform.secure, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gate exit cannot release a viewer-owned secure window', (
    tester,
  ) async {
    final harness = _GateHarness();
    await harness.mount(tester);
    await _until(tester, () => find.byKey(_privateKey).evaluate().isNotEmpty);
    final viewerOwner = Object();
    await harness.security.acquire(viewerOwner);
    final appliedBeforeExit = harness.platform.applied.length;
    harness.router.go(_otherPath);
    await _frames(tester);
    expect(harness.session.accessAllowed, isFalse);
    expect(find.byKey(_privateKey), findsNothing);
    expect(harness.platform.secure, isTrue);
    expect(
      harness.platform.applied.skip(appliedBeforeExit),
      everyElement(isTrue),
    );

    await harness.security.release(viewerOwner);
    expect(harness.platform.secure, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing an opened Gate masks before restoring screenshots', (
    tester,
  ) async {
    final harness = _GateHarness();
    await harness.mount(tester);
    await _until(tester, () => find.byKey(_privateKey).evaluate().isNotEmpty);
    final epoch = harness.session.epoch;
    final visibleAtRelease = <bool>[];
    harness.platform.onApplied = (enabled) {
      if (!enabled) {
        visibleAtRelease.add(find.byKey(_privateKey).evaluate().isNotEmpty);
      }
    };

    await tester.pumpWidget(const SizedBox.shrink());
    await _until(tester, () => visibleAtRelease.isNotEmpty);
    expect(visibleAtRelease, everyElement(isFalse));
    expect(harness.session.isAuthorizedEpoch(epoch), isFalse);
    expect(harness.platform.secure, isFalse);
    expect(tester.takeException(), isNull);
  });
}

void _expectGateMasked(WidgetTester tester) {
  final gate = find.byType(WalletAccessGate, skipOffstage: false);
  final semantics = find.descendant(
    of: gate,
    matching: find.byType(ExcludeSemantics, skipOffstage: false),
    skipOffstage: false,
  );
  final focus = find.descendant(
    of: gate,
    matching: find.byType(ExcludeFocus, skipOffstage: false),
    skipOffstage: false,
  );
  expect(
    tester.widgetList<ExcludeSemantics>(semantics).any((w) => w.excluding),
    isTrue,
  );
  expect(
    tester.widgetList<ExcludeFocus>(focus).any((w) => w.excluding),
    isTrue,
  );
}

Future<void> _frames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 60 && !condition(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(condition(), isTrue, reason: 'Gate did not reach the expected state.');
}

class _GateHarness {
  final authenticator = _Authenticator();
  final platform = _Platform();
  final focus = FocusNode();
  late final session = WalletSession(
    authenticator: authenticator,
    preferences: _Preferences(),
  );
  late final security = WalletScreenSecurity(platform);
  late final router = GoRouter(
    initialLocation: _documentsPath,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: _documentsPath,
                builder: (context, state) => WalletAccessGate(
                  child: Scaffold(
                    body: Focus(
                      focusNode: focus,
                      child: Semantics(
                        label: 'Private wallet fixture',
                        child: const Text(
                          'Private wallet fixture',
                          key: _privateKey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: _otherPath,
                builder: (context, state) =>
                    const Scaffold(body: Text('Other route')),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Future<void> mount(WidgetTester tester) async {
    addTearDown(() async {
      authenticator.finishPending();
      platform.finishPending();
      platform.failEnable = false;
      platform.failDisable = false;
      platform.onApplied = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
      router.dispose();
      session.dispose();
      focus.dispose();
    });
    await session.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSessionProvider.overrideWithValue(session),
          walletScreenSecurityProvider.overrideWithValue(security),
          walletPlatformProvider.overrideWithValue(platform),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }
}

class _Preferences implements WalletSecurityPreferencesStore {
  WalletSecurityPreferences value = const WalletSecurityPreferences(
    protectionEnabled: true,
    offerSeen: true,
  );

  @override
  Future<WalletSecurityPreferences> read() async => value;

  @override
  Future<void> write(WalletSecurityPreferences preferences) async {
    value = preferences;
  }
}

class _Authenticator implements WalletDeviceAuthenticator {
  int calls = 0;
  Completer<WalletAuthenticationResult>? pending;

  Completer<WalletAuthenticationResult> holdNext() =>
      pending = Completer<WalletAuthenticationResult>();

  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<WalletAuthenticationResult> authenticate() async {
    calls++;
    final completion = pending;
    return completion == null
        ? WalletAuthenticationResult.success
        : await completion.future;
  }

  void finishPending() {
    final completion = pending;
    if (completion != null && !completion.isCompleted) {
      completion.complete(WalletAuthenticationResult.cancelled);
    }
  }
}

class _Platform extends WalletPlatform {
  final calls = <bool>[];
  final applied = <bool>[];
  bool secure = false;
  bool failEnable = false;
  bool failDisable = false;
  int releaseFailures = 0;
  Completer<void>? pending;
  void Function(bool)? onApplied;

  Completer<void> hold() => pending = Completer<void>();

  @override
  Future<void> setSecure(bool enabled) async {
    calls.add(enabled);
    final completion = pending;
    if (completion != null) await completion.future;
    if (enabled ? failEnable : failDisable) {
      if (!enabled) releaseFailures++;
      throw const WalletPlatformException('native private detail');
    }
    secure = enabled;
    applied.add(enabled);
    onApplied?.call(enabled);
  }

  void finishPending() {
    final completion = pending;
    if (completion != null && !completion.isCompleted) completion.complete();
  }
}
