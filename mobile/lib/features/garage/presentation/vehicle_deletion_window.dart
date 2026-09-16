import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// No data changes are allowed until the pending snackbar expires naturally.
class VehicleDeletionWindow {
  VehicleDeletionWindow(BuildContext context)
    : _context = context,
      _router = GoRouter.of(context),
      _route = ModalRoute.of(context),
      _messenger = ScaffoldMessenger.of(context) {
    _location = _router.routeInformationProvider.value.uri;
    _router.routeInformationProvider.addListener(_onNavigation);
    _messenger.removeCurrentSnackBar();
    _controller = _messenger.showSnackBar(
      SnackBar(
        content: const Text('Eliminación pendiente'),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(label: 'Deshacer', onPressed: cancel),
      ),
    );
  }

  final BuildContext _context;
  final GoRouter _router;
  final ModalRoute<dynamic>? _route;
  final ScaffoldMessengerState _messenger;
  late final Uri _location;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  _controller;
  bool _cancelled = false;
  bool _closed = false;

  void _onNavigation() {
    if (_router.routeInformationProvider.value.uri != _location) cancel();
  }

  void cancel() {
    if (_cancelled || _closed) return;
    _cancelled = true;
    _router.routeInformationProvider.removeListener(_onNavigation);
    // Disposal can happen during a route build; close outside that build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_closed && _messenger.mounted) _controller.close();
    });
  }

  Future<bool> wait() async {
    final reason = await _controller.closed;
    _closed = true;
    _router.routeInformationProvider.removeListener(_onNavigation);
    return !_cancelled &&
        reason == SnackBarClosedReason.timeout &&
        _context.mounted &&
        _route?.isCurrent == true &&
        _router.routeInformationProvider.value.uri == _location;
  }
}
