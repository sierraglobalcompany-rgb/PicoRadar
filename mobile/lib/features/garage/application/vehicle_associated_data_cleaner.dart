import 'dart:async';

import '../../../core/storage/app_preferences.dart';
import '../../defense/data/defense_case_store.dart';
import '../../peritajes/data/peritajes_draft_store.dart';
import '../../vehicle_status/data/private_vehicle_document_store.dart';

class VehicleAssociatedDataCleaner {
  VehicleAssociatedDataCleaner({
    required this.documentStore,
    required this.defenseCaseStore,
    required this.peritajesDraftStore,
    required this.preferences,
  });

  final PrivateVehicleDocumentStore documentStore;
  final DefenseCaseStore defenseCaseStore;
  final PeritajesDraftStore peritajesDraftStore;
  final AppPreferences preferences;
  Future<void> _mutationTail = Future<void>.value();

  Future<void> deleteForVehicle(String vehicleId) {
    final requestedVehicleId = vehicleId.trim();
    if (requestedVehicleId.isEmpty) {
      return Future<void>.value();
    }

    return _runMutation(() async {
      await documentStore.deleteForVehicle(requestedVehicleId);
      await defenseCaseStore.deleteForVehicle(requestedVehicleId);
      await peritajesDraftStore.deleteDraft(requestedVehicleId);
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
