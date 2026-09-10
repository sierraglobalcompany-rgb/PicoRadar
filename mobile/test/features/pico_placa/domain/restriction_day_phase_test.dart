import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';

void main() {
  const day = RestrictionDayEvaluation(
    status: RestrictionDayStatus.restricted,
    effectiveWindows: [RestrictionDayWindow(startMinute: 300, endMinute: 1200)],
  );
  test('daily restriction remains while instant crosses its boundaries', () {
    for (final (minute, phase) in [
      (299, RestrictionDayPhase.before),
      (300, RestrictionDayPhase.active),
      (1199, RestrictionDayPhase.active),
      (1200, RestrictionDayPhase.finished),
    ]) {
      final now = DateTime(2026, 9, 10).add(Duration(minutes: minute));
      expect(restrictionPhaseAt(day, now), phase);
      expect(day.status, RestrictionDayStatus.restricted);
    }
  });
  test('split windows preserve the permitted gap and next start', () {
    const split = RestrictionDayEvaluation(
      status: RestrictionDayStatus.restricted,
      effectiveWindows: [
        RestrictionDayWindow(startMinute: 300, endMinute: 600),
        RestrictionDayWindow(startMinute: 900, endMinute: 1200),
      ],
    );
    expect(
      restrictionPhaseAt(split, DateTime(2026, 9, 10, 10)),
      RestrictionDayPhase.between,
    );
    expect(nextRestrictionStartMinute(split, DateTime(2026, 9, 10, 10)), 900);
    expect(
      nextRestrictionStartMinute(split, DateTime(2026, 9, 10, 20)),
      isNull,
    );
  });
  test('unknown and stale never become unrestricted', () {
    for (final (status, phase) in [
      (RestrictionDayStatus.unknown, RestrictionDayPhase.unknown),
      (RestrictionDayStatus.stale, RestrictionDayPhase.stale),
      (RestrictionDayStatus.allowed, RestrictionDayPhase.unrestricted),
      (RestrictionDayStatus.restricted, RestrictionDayPhase.unknown),
    ]) {
      expect(
        restrictionPhaseAt(
          RestrictionDayEvaluation(status: status, effectiveWindows: const []),
          DateTime(2026, 9, 10, 12),
        ),
        phase,
      );
    }
  });
  test('12 hour format retains minutes noon midnight and all windows', () {
    expect(formatRestrictionTime12(0), '12:00 a. m.');
    expect(formatRestrictionTime12(300), '5:00 a. m.');
    expect(formatRestrictionTime12(720), '12:00 p. m.');
    expect(formatRestrictionTime12(1200), '8:00 p. m.');
    expect(formatRestrictionTime12(1440), '12:00 a. m.');
    expect(
      formatRestrictionWindows12(day.effectiveWindows),
      '5:00 a. m. – 8:00 p. m.',
    );
    expect(
      formatRestrictionWindows12(const [
        RestrictionDayWindow(startMinute: 300, endMinute: 600),
        RestrictionDayWindow(startMinute: 900, endMinute: 1200),
      ]),
      '5:00 a. m. – 10:00 a. m.\n3:00 p. m. – 8:00 p. m.',
    );
  });
}
