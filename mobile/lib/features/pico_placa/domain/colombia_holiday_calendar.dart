class ColombiaHolidayCalendar {
  const ColombiaHolidayCalendar();

  bool isHoliday(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _fixedHolidays(day.year).contains(day) ||
        _mondayMovedHolidays(day.year).contains(day) ||
        _easterHolidays(day.year).contains(day);
  }

  Set<DateTime> _fixedHolidays(int year) {
    return {
      DateTime(year),
      DateTime(year, 5),
      DateTime(year, 7, 20),
      DateTime(year, 8, 7),
      DateTime(year, 12, 8),
      DateTime(year, 12, 25),
    };
  }

  Set<DateTime> _mondayMovedHolidays(int year) {
    return {
      _nextMonday(DateTime(year, 1, 6)),
      _nextMonday(DateTime(year, 3, 19)),
      _nextMonday(DateTime(year, 6, 29)),
      _nextMonday(DateTime(year, 8, 15)),
      _nextMonday(DateTime(year, 10, 12)),
      _nextMonday(DateTime(year, 11)),
      _nextMonday(DateTime(year, 11, 11)),
    };
  }

  Set<DateTime> _easterHolidays(int year) {
    final easter = _easterSunday(year);
    return {
      easter.subtract(const Duration(days: 3)),
      easter.subtract(const Duration(days: 2)),
      _nextMonday(easter.add(const Duration(days: 39))),
      _nextMonday(easter.add(const Duration(days: 60))),
      _nextMonday(easter.add(const Duration(days: 68))),
    };
  }

  DateTime _nextMonday(DateTime date) {
    final delta = (DateTime.monday - date.weekday) % DateTime.daysPerWeek;
    return DateTime(date.year, date.month, date.day + delta);
  }

  DateTime _easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}
