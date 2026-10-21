import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/wallet_providers.dart';

/// A modal belongs to one URI visit, even when go_router reuses its Page.
class WalletVisitScope extends ConsumerStatefulWidget {
  const WalletVisitScope({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<WalletVisitScope> createState() => _WalletVisitScopeState();
}

class _WalletVisitScopeState extends ConsumerState<WalletVisitScope> {
  GoRouter? _router;
  ModalRoute<dynamic>? _route;
  Uri? _origin;
  bool _captured = false;
  bool _expired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_captured) return;
    _captured = true;
    _route = ModalRoute.of(context);
    _router = GoRouter.maybeOf(context);
    _origin = _router?.routeInformationProvider.value.uri;
    _router?.routeInformationProvider.addListener(_changed);
  }

  void _changed() {
    if (_expired || _router?.routeInformationProvider.value.uri == _origin) {
      return;
    }
    setState(() => _expired = true);
    ref.read(walletSessionProvider).lock();
    final route = _route;
    final navigator = route?.navigator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          navigator != null &&
          navigator.mounted &&
          route!.isActive) {
        navigator.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    _router?.routeInformationProvider.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _expired ? const SizedBox.shrink() : widget.child;
}
