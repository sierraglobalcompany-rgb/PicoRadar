import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/pico_placa/domain/colombia_holiday_calendar.dart';

void main() {
  const calendar = ColombiaHolidayCalendar();

  test('detects Colombian national holidays in 2026', () {
    expect(calendar.isHoliday(DateTime(2026)), isTrue);
    expect(calendar.isHoliday(DateTime(2026, 1, 12)), isTrue);
    expect(calendar.isHoliday(DateTime(2026, 3, 23)), isTrue);
    expect(calendar.isHoliday(DateTime(2026, 4, 2)), isTrue);
    expect(calendar.isHoliday(DateTime(2026, 4, 3)), isTrue);
    expect(calendar.isHoliday(DateTime(2026, 7, 20)), isTrue);
    expect(calendar.isHoliday(DateTime(2026, 8, 7)), isTrue);
    expect(calendar.isHoliday(DateTime(2026, 8, 17)), isTrue);
    expect(calendar.isHoliday(DateTime(2026, 8, 18)), isFalse);
  });
}
