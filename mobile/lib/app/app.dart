import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/pico_placa/data/pico_preferences.dart';
import '../features/documents/application/wallet_providers.dart';
import '../features/documents/data/wallet_store.dart';
import 'app_clock.dart';
import 'app_providers.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'startup/startup_gate.dart';
import 'startup/startup_timing.dart';
import 'theme/app_theme.dart';

class PicoRadarApp extends ConsumerStatefulWidget {
  const PicoRadarApp({super.key});

  @override
  ConsumerState<PicoRadarApp> createState() => _PicoRadarAppState();
}

class _PicoRadarAppState extends ConsumerState<PicoRadarApp> {
  bool _notificationsStarted = false;
  bool _secondaryReady = false;
  Future<bool>? _notificationInitialization;
  Future<bool>? _permissionRefreshInitialization;
  int _permissionRefreshEpoch = 0;
  late final AppClockLifecycleObserver _clockObserver;
  late final _DocumentViewerCacheLifecycleObserver _documentCacheObserver;

  @override
  void initState() {
    super.initState();
    ref.read(currentInstantProvider);
    final clock = ref.exists(appClockProvider)
        ? ref.read(appClockProvider.notifier)
        : null;
    _clockObserver = AppClockLifecycleObserver(
      clock: clock,
      onResume: () {
        _permissionRefreshEpoch++;
        _permissionRefreshInitialization = null;
        _startNotifications(ref.read(appRouterProvider));
        _refreshNotificationPermission();
        ref.invalidate(picoNotificationSyncProvider);
        ref.invalidate(obligationNotificationSyncProvider);
      },
    );
    final binding = WidgetsBinding.instance;
    binding.addObserver(_clockObserver);
    final lifecycle = binding.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      clock?.setForeground(false);
    }
    _documentCacheObserver = _DocumentViewerCacheLifecycleObserver(ref);
    WidgetsBinding.instance.addObserver(_documentCacheObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_clockObserver);
    _clockObserver.clock?.setForeground(false);
    WidgetsBinding.instance.removeObserver(_documentCacheObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    if (_secondaryReady) {
      // These providers perform work; their results do not render the app root.
      ref.listen(
        picoWidgetSyncProvider,
        (previous, next) => _reportSecondaryFailure('widget', previous, next),
      );
      ref.listen(
        picoNotificationSyncProvider,
        (previous, next) =>
            _reportSecondaryFailure('pico_notifications', previous, next),
      );
      ref.listen(
        obligationNotificationSyncProvider,
        (previous, next) =>
            _reportSecondaryFailure('obligation_notifications', previous, next),
      );
      ref.listen(
        datasetSyncRunProvider,
        (previous, next) => _reportSecondaryFailure('dataset', previous, next),
      );
    }
    _startNotifications(router);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PicoRadar',
      theme: buildPicoRadarTheme(),
      routerConfig: router,
      builder: (context, child) {
        return StartupGate(
          onFirstContentFrame: _startSecondaryWork,
          isHomeRoute: () =>
              router.routeInformationProvider.value.uri.path ==
              AppRoute.home.path,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  void _startNotifications(GoRouter router) {
    if (_notificationsStarted) {
      return;
    }
    _notificationsStarted = true;
    final scheduler = ref.read(picoNotificationSchedulerProvider);
    // Launch routing must remain available before Home's first content frame.
    _notificationInitialization = Future<bool>.microtask(() async {
      if (!mounted) return false;
      try {
        await scheduler.initialize(
          onRoute: (route) {
            if (mounted) router.go(route);
          },
        );
        return true;
      } on MissingPluginException {
        _notificationsStarted = false;
        logStartupMarker('NOTIFICATION_INIT_UNAVAILABLE');
        return false;
      } catch (error, stack) {
        _notificationsStarted = false;
        logStartupMarker('NOTIFICATION_INIT_FAILED');
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError(
              'Notification initialization failed (${error.runtimeType}).',
            ),
            stack: stack,
            library: 'PicoRadar startup',
          ),
        );
        return false;
      }
    });
    _refreshNotificationPermission();
  }

  void _startSecondaryWork() {
    if (!mounted || _secondaryReady) return;
    setState(() => _secondaryReady = true);
    _startNotifications(ref.read(appRouterProvider));
    _refreshNotificationPermission();
  }

  void _refreshNotificationPermission() {
    final initialization = _notificationInitialization;
    if (!mounted ||
        !_secondaryReady ||
        initialization == null ||
        identical(initialization, _permissionRefreshInitialization)) {
      return;
    }
    // Reconcile again on each resume, ignoring late results from older visits.
    _permissionRefreshInitialization = initialization;
    final epoch = _permissionRefreshEpoch;
    final scheduler = ref.read(picoNotificationSchedulerProvider);
    final preferences = ref.read(appPreferencesProvider);
    Future<void>.microtask(() async {
      try {
        final initialized = await initialization;
        if (!mounted || initialized != true) return;
        final enabled = await scheduler.areNotificationsEnabled();
        if (!mounted || epoch != _permissionRefreshEpoch || enabled == null) {
          return;
        }
        final alerts = await loadPicoAlertPreferences(preferences);
        if (!mounted || epoch != _permissionRefreshEpoch) return;
        if (enabled != alerts.permissionGranted) {
          // Refresh only OS state; never overwrite edits to reminder settings.
          await preferences.setBool(
            picoNotificationPermissionGrantedKey,
            enabled,
          );
          if (!mounted || epoch != _permissionRefreshEpoch) return;
          ref.invalidate(picoAlertPreferencesProvider);
        }
        ref.invalidate(picoNotificationSyncProvider);
        ref.invalidate(obligationNotificationSyncProvider);
      } on MissingPluginException {
        return;
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError(
              'Notification permission refresh failed (${error.runtimeType}).',
            ),
            stack: stack,
            library: 'PicoRadar startup',
          ),
        );
      }
    });
  }
}

void _reportSecondaryFailure<T>(
  String source,
  AsyncValue<T>? previous,
  AsyncValue<T> next,
) {
  if (next.hasError && !identical(previous?.error, next.error)) {
    logStartupMarker(
      'SECONDARY_SYNC_FAILED',
      extra: ' source=$source error_type=${next.error.runtimeType}',
    );
  }
}

class _DocumentViewerCacheLifecycleObserver extends WidgetsBindingObserver {
  _DocumentViewerCacheLifecycleObserver(this.ref);

  final WidgetRef ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        ref.exists(walletSessionProvider)) {
      final session = ref.read(walletSessionProvider);
      if (state != AppLifecycleState.inactive || !session.authenticating) {
        session.lock();
        Future<void>.microtask(() async {
          try {
            await WalletStore.purgeTemporaryViewerFiles();
          } on MissingPluginException {
            return;
          } catch (_) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: FlutterError('Private viewer cleanup failed.'),
                library: 'PicoRadar privacy',
              ),
            );
          }
        });
      }
    }
    if (state != AppLifecycleState.resumed) {
      return;
    }
    final store = ref.read(privateVehicleDocumentStoreProvider);
    Future<void>.microtask(() async {
      try {
        await store.purgeViewerCache();
      } on MissingPluginException {
        return;
      }
    });
  }
}
