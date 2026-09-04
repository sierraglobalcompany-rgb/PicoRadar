import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/defense_case.dart';
import '../data/defense_case_store.dart';

final defenseCaseStoreProvider = Provider<DefenseCaseStore>((ref) {
  return DefenseCaseStore();
});

final defenseCasesProvider = FutureProvider.family<List<DefenseCase>, String>((
  ref,
  vehicleId,
) {
  return ref.watch(defenseCaseStoreProvider).listForVehicle(vehicleId);
});
