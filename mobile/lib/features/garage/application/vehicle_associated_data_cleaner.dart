import 'dart:async';

import '../../../core/storage/app_preferences.dart';
import '../../defense/data/defense_case_store.dart';
import '../../documents/data/wallet_store.dart';
import '../../peritajes/data/peritajes_draft_store.dart';
import '../../vehicle_status/data/private_vehicle_document_store.dart';

class VehicleAssociatedDataCleaner {
  VehicleAssociatedDataCleaner({
    this.walletStore,
    this.documentStore,
    required this.defenseCaseStore,
    required this.peritajesDraftStore,
    required this.preferences,
  }) : assert(walletStore != null || documentStore != null);

  final WalletStore? walletStore;
  // Compatibility for existing callers; the production provider uses walletStore.
  final PrivateVehicleDocumentStore? documentStore;
  final DefenseCaseStore defenseCaseStore;
  final PeritajesDraftStore peritajesDraftStore;
  final AppPreferences preferences;
  Future<void> _mutationTail = Future<void>.value();

  Future<void> deleteForVehicle(String vehicleId) =>
      _deleteForVehicle(vehicleId);

  Future<void> deletePrivateDataForVehicle(
    String vehicleId, {
    required bool Function() isAuthorized,
  }) => _deleteForVehicle(vehicleId, isAuthorized: isAuthorized);

  Future<void> _deleteForVehicle(
    String vehicleId, {
    bool Function()? isAuthorized,
  }) {
    final requestedVehicleId = vehicleId.trim();
    if (requestedVehicleId.isEmpty) {
      return Future<void>.value();
    }

    return _runMutation(() async {
      void requireAuthorization() {
        if (isAuthorized != null && !isAuthorized()) {
          throw StateError('Wallet authorization expired.');
        }
      }

      requireAuthorization();
      final wallet = walletStore;
      if (wallet != null) {
        // Migrate while the vehicle still exists, before removing any owned data.
        await wallet.initialize();
        requireAuthorization();
        await wallet.deleteForVehicle(
          requestedVehicleId,
          isAuthorized: isAuthorized,
        );
      } else {
        await documentStore!.deleteForVehicle(requestedVehicleId);
      }
      requireAuthorization();
      await defenseCaseStore.deleteForVehicle(requestedVehicleId);
      requireAuthorization();
      await peritajesDraftStore.deleteDraft(requestedVehicleId);
      requireAuthorization();
      await preferences.remove(_comparendosLastCheckedKey(requestedVehicleId));
    });
  }

  Future<T> _runMutation<T>(Future<T> Function() action) {
    final previous = _mutationTail;
    final gate = Completer<void>();
    _mutationTail = gate.future;
    return (() async {
      await previous;
      try {
        return await action();
      } finally {
        gate.complete();
      }
    })();
  }

  static String _comparendosLastCheckedKey(String vehicleId) {
    return 'comparendos.last_checked.$vehicleId';
  }
}
