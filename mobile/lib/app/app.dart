import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/pico_placa/data/pico_preferences.dart';
import 'app_providers.dart';
import 'router/app_router.dart';
import 'startup/startup_gate.dart';
import 'theme/app_theme.dart';

class PicoRadarApp extends ConsumerStatefulWidget {
  const PicoRadarApp({super.key});

  @override
  ConsumerState<PicoRadarApp> createState() => _PicoRadarAppState();
}

class _PicoRadarAppState extends ConsumerState<PicoRadarApp> {
  bool _notificationsStarted = false;
  late final _DocumentViewerCacheLifecycleObserver _documentCacheObserver;

  @override
  void initState() {
    super.initState();
    _documentCacheObserver = _DocumentViewerCacheLifecycleObserver(ref);
    WidgetsBinding.instance.addObserver(_documentCacheObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_documentCacheObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.watch(picoWidgetSyncProvider);
    ref.watch(picoNotificationSyncProvider);
    ref.watch(obligationNotificationSyncProvider);
    _startNotifications(router);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PicoRadar',
      theme: buildPicoRadarTheme(),
      routerConfig: router,
      builder: (context, child) {
        return StartupGate(child: child ?? const SizedBox.shrink());
      },
    );
  }

  void _startNotifications(GoRouter router) {
    if (_notificationsStarted) {
      return;
    }
    _notificationsStarted = true;
    Future<void>.microtask(() async {
      try {
        final scheduler = ref.read(picoNotificationSchedulerProvider);
        await scheduler.initialize(onRoute: router.go);
        final preferences = ref.read(appPreferencesProvider);
        final alerts = await loadPicoAlertPreferences(preferences);
        if (!alerts.permissionRequested) {
          return;
        }
        final enabled = await scheduler.areNotificationsEnabled();
        if (enabled == null || enabled == alerts.permissionGranted) {
          return;
        }
        await savePicoAlertPreferences(
          preferences,
          alerts.copyWith(permissionGranted: enabled),
        );
        ref.invalidate(picoAlertPreferencesProvider);
      } on MissingPluginException {
        return;
      }
    });
  }
}

class _DocumentViewerCacheLifecycleObserver extends WidgetsBindingObserver {
  _DocumentViewerCacheLifecycleObserver(this.ref);

  final WidgetRef ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    Future<void>.microtask(() async {
      try {
        await ref.read(privateVehicleDocumentStoreProvider).purgeViewerCache();
      } on MissingPluginException {
        return;
      }
    });
  }
}
