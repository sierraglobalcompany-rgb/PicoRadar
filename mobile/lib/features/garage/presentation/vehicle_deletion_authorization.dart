import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../documents/application/wallet_session.dart';

Future<bool> authorizeVehicleDeletion(
  BuildContext context,
  WalletSession session,
  Future<void> Function(bool Function() isAuthorized) action,
) async {
  final route = ModalRoute.of(context);
  final router = GoRouter.maybeOf(context);
  final origin = router?.routeInformationProvider.value.uri;
  var exited = false;
  session.lock();
  final epoch = session.epoch;
  void routeChanged() {
    if (router?.routeInformationProvider.value.uri != origin) {
      exited = true;
      session.lock();
    }
  }

  bool authorized() =>
      context.mounted &&
      !exited &&
      (route?.isCurrent ?? true) &&
      session.isAuthorizedEpoch(epoch);
  final lifecycle = _DeletionLifecycle(session);
  WidgetsBinding.instance.addObserver(lifecycle);
  router?.routeInformationProvider.addListener(routeChanged);
  try {
    if (!await session.initialize() || !context.mounted || exited) return false;
    if (!await session.unlock() || !authorized()) return false;
    await action(authorized);
    return true;
  } finally {
    router?.routeInformationProvider.removeListener(routeChanged);
    WidgetsBinding.instance.removeObserver(lifecycle);
    if (session.epoch == epoch) session.lock();
  }
}

class _DeletionLifecycle extends WidgetsBindingObserver {
  _DeletionLifecycle(this.session);
  final WalletSession session;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (state != AppLifecycleState.inactive || !session.authenticating)) {
      session.lock();
    }
  }
}
