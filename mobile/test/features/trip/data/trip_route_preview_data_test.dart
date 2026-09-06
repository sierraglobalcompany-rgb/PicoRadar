import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/trip/data/trip_route_preview_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the approved camera pack with its dataset version', () async {
    final snapshot = await loadTripCameraPackSnapshot(rootBundle);

    expect(snapshot.version, '2026.08.31-ansv');
    expect(snapshot.pack.cameras, hasLength(360));
    expect(snapshot.pack.source.name, contains('ANSV'));
  });
}
