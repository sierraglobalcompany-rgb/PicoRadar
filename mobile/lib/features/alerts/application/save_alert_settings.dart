import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../vehicle_status/domain/vehicle_obligation.dart';
import '../data/alert_settings.dart';
import 'alert_center.dart';

final _saveLifetimeProvider = Provider((ref) {
  final lifetime = _SaveLifetime();
  ref.onDispose(() => lifetime.active = false);
  return lifetime;
});

class _SaveLifetime {
  bool active = true;
}

Future<void> saveAlertSettings(
  ProviderContainer container, {
  required String vehicleId,
  required AlertCategory category,
  required AlertSettings settings,
}) async {
  final lifetime = container.read(_saveLifetimeProvider);
  final store = container.read(alertSettingsStoreProvider);
  await store.save(vehicleId, category, settings);
  // The originating widget may be gone, but the app still owns its schedules.
  if (!lifetime.active) return;
  final type = switch (category) {
    AlertCategory.pico => null,
    AlertCategory.soat => VehicleObligationType.soat,
    AlertCategory.rtm => VehicleObligationType.rtm,
    AlertCategory.insurance => VehicleObligationType.insurance,
  };
  if (type != null) {
    container.invalidate(vehicleObligationProvider((vehicleId, type)));
    container.invalidate(vehicleObligationsProvider(vehicleId));
  }
  container.invalidate(picoNotificationSyncProvider);
  container.invalidate(obligationNotificationSyncProvider);
  container.invalidate(alertCenterProvider);
}
