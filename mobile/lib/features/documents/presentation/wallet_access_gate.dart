import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../application/wallet_providers.dart';
import '../application/wallet_session.dart';
import 'wallet_actions.dart';

class WalletAccessGate extends ConsumerStatefulWidget {
  const WalletAccessGate({required this.child, this.visitRouteName, super.key});
  final Widget child;

  /// An explicitly named Navigator visit, independent of the wallet GoRoute.
  /// The caller must push a route with this exact name. It always uses
  /// FLAG_SECURE, including when optional device authentication is disabled.
  final String? visitRouteName;
  @override
  ConsumerState<WalletAccessGate> createState() => _WalletAccessGateState();
}

class _WalletAccessGateState extends ConsumerState<WalletAccessGate>
    with WidgetsBindingObserver {
  late final WalletSession _session;
  late final WalletScreenSecurity _security;
  final _secureOwner = Object();
  GoRouter? _router;
  ModalRoute<dynamic>? _visitRoute;
  Uri? _visitOrigin;
  bool _secureReady = false;
  String? _error;
  int _request = 0;
  bool _offered = false;
  bool _opened = false;
  bool _activeRoute = true;

  @override
  void initState() {
    super.initState();
    _session = ref.read(walletSessionProvider);
    _security = ref.read(walletScreenSecurityProvider);
    _session.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = GoRouter.maybeOf(context);
    if (widget.visitRouteName != null && _visitRoute == null) {
      _visitRoute = ModalRoute.of(context);
      _visitOrigin = next?.routeInformationProvider.value.uri;
      _activeRoute = _namedVisitActive(next);
    }
    if (next == _router) return;
    _router?.routeInformationProvider.removeListener(_routeChanged);
    _router = next;
    _router?.routeInformationProvider.addListener(_routeChanged);
  }

  bool _namedVisitActive(GoRouter? router) =>
      _visitRoute != null &&
      _visitRoute!.isActive &&
      _visitRoute!.settings.name == widget.visitRouteName &&
      router?.routeInformationProvider.value.uri == _visitOrigin;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.visitRouteName != null &&
        state != AppLifecycleState.resumed &&
        (state != AppLifecycleState.inactive || !_session.authenticating)) {
      _session.lock();
    }
  }

  void _routeChanged() {
    final path = _router?.routeInformationProvider.value.uri.path ?? '';
    final active = widget.visitRouteName == null
        ? path.endsWith('/module/documentos')
        : _namedVisitActive(_router);
    if (active == _activeRoute) return;
    setState(() => _activeRoute = active);
    if (!active) {
      _session.lock();
    } else {
      unawaited(_enter());
    }
  }

  Future<void> _enter() async {
    if (!mounted || !_activeRoute) return;
    if (!await _session.initialize() || !mounted) return;
    if (!_activeRoute) return;
    await _session.unlock();
    if (!mounted) return;
    if (!_activeRoute ||
        (widget.visitRouteName != null && !_namedVisitActive(_router))) {
      _session.lock();
      return;
    }
    await _syncSecurity();
    if (!_offered &&
        !_session.offerSeen &&
        mounted &&
        _activeRoute &&
        _secureReady &&
        _session.accessAllowed) {
      _offered = true;
      await WalletActions(
        context,
        ref,
        visitRouteName: widget.visitRouteName,
      ).protection(firstOffer: true);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      _secureReady = false;
    });
    unawaited(_syncSecurity());
  }

  Future<void> _syncSecurity() async {
    final request = ++_request;
    try {
      if (_activeRoute &&
          (_session.protectionEnabled || widget.visitRouteName != null)) {
        await _security.acquire(_secureOwner);
      } else {
        if (_opened) await WidgetsBinding.instance.endOfFrame;
        if (!mounted || request != _request) return;
        await _security.release(_secureOwner);
      }
      if (mounted && request == _request) {
        setState(() {
          _secureReady = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _secureReady = false;
          _error = 'No se pudo proteger esta pantalla. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    _router?.routeInformationProvider.removeListener(_routeChanged);
    _session.removeListener(_changed);
    _session.lock();
    // A failed release leaves FLAG_SECURE on, never exposes private content.
    unawaited(
      WidgetsBinding.instance.endOfFrame
          .then((_) => _security.release(_secureOwner))
          .catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed =
        _activeRoute &&
        _session.accessAllowed &&
        _secureReady &&
        _error == null;
    if (allowed) _opened = true;
    final locked = Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Documentos'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.visitRouteName != null) {
              Navigator.of(context).maybePop();
              return;
            }
            if (_router?.canPop() ?? false) {
              _router!.pop();
            } else {
              _router?.go('/apps');
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40, color: AppColors.teal),
              const SizedBox(height: 16),
              Text(
                _error ?? _session.failureMessage ?? 'Documentos protegidos',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              if (_session.busy)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  key: const ValueKey('wallet-unlock'),
                  onPressed: _enter,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Desbloquear'),
                ),
            ],
          ),
        ),
      ),
    );
    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (_opened && (widget.visitRouteName == null || _activeRoute))
          Offstage(
            offstage: !allowed,
            child: TickerMode(
              enabled: allowed,
              child: ExcludeFocus(
                excluding: !allowed,
                child: ExcludeSemantics(
                  excluding: !allowed,
                  child: widget.child,
                ),
              ),
            ),
          ),
        if (!allowed) locked,
      ],
    );
    if (widget.visitRouteName == null) return content;
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _activeRoute = false;
        _session.lock();
      },
      child: content,
    );
  }
}
