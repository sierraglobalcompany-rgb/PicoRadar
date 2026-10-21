import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';

void main() {
  final noon = DateTime(2026, 9, 11, 12);
  HomeVehicleSnapshot item(
    String id, {
    RestrictionDayStatus status = RestrictionDayStatus.allowed,
    List<RestrictionDayWindow> windows = const [],
    DateTime? next,
  }) => HomeVehicleSnapshot(
    vehicle: VehicleProfile(
      id: id,
      plate: id.padRight(6, '1'),
      nickname: id,
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      createdAt: noon,
      updatedAt: noon,
    ),
    today: RestrictionDayEvaluation(status: status, effectiveWindows: windows),
    nextRestrictionDate: next,
  );
  HomeVehicleSnapshot restricted(String id, int start, int end) => item(
    id,
    status: RestrictionDayStatus.restricted,
    windows: [RestrictionDayWindow(startMinute: start, endMinute: end)],
  );
  int pick(List<HomeVehicleSnapshot> values) =>
      pickInitialHomeVehicleIndex(snapshots: values, now: noon);

  test(
    'active precedes pending and finished today regardless of list order',
    () {
      expect(
        pick([
          restricted('a', 300, 600),
          restricted('b', 900, 1000),
          restricted('z', 300, 1200),
        ]),
        2,
      );
    },
  );
  test(
    'nearest pending precedes finished and alphabetical ties are stable',
    () {
      expect(
        pick([
          restricted('a', 300, 600),
          restricted('b', 900, 1000),
          restricted('z', 800, 1000),
        ]),
        2,
      );
      expect(pick([restricted('z', 300, 1200), restricted('a', 300, 1200)]), 1);
    },
  );
  test('next verified restriction wins through day seven but not eight', () {
    expect(pick([item('a'), item('z', next: DateTime(2026, 9, 18))]), 1);
    expect(pick([item('a'), item('z', next: DateTime(2026, 9, 19))]), 0);
    expect(
      pick([
        item('a', next: DateTime(2026, 9, 18)),
        item('z', next: DateTime(2026, 9, 12)),
      ]),
      1,
    );
  });
  test('unverified precedes allowed only without a verified restriction', () {
    expect(pick([item('a'), item('z', status: RestrictionDayStatus.stale)]), 1);
    expect(
      pick([
        item('a', status: RestrictionDayStatus.unknown),
        item('z', next: DateTime(2026, 9, 12)),
      ]),
      1,
    );
    expect(pick([item('z'), item('a')]), 1);
  });
  test('split pause is pending and exact final boundary is finished', () {
    final split = item(
      'z',
      status: RestrictionDayStatus.restricted,
      windows: const [
        RestrictionDayWindow(startMinute: 300, endMinute: 600),
        RestrictionDayWindow(startMinute: 780, endMinute: 900),
      ],
    );
    expect(pick([restricted('a', 300, 720), split]), 1);
  });
}
