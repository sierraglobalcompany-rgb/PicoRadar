import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

bool _initialized = false;
late timezone.Location _bogota;

DateTime bogotaWallClock(DateTime instant) {
  _ensureInitialized();
  final local = timezone.TZDateTime.from(instant.toUtc(), _bogota);
  return DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
    local.microsecond,
  );
}

timezone.TZDateTime bogotaScheduledTime({
  required DateTime date,
  required int minuteOfDay,
}) {
  _ensureInitialized();
  return timezone.TZDateTime(
    _bogota,
    date.year,
    date.month,
    date.day,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );
}

bool staleAfterCoversBogotaDate(DateTime staleAfter, DateTime date) {
  final nextDayStart = bogotaScheduledTime(
    date: DateTime(date.year, date.month, date.day + 1),
    minuteOfDay: 0,
  );
  return !staleAfter.toUtc().isBefore(nextDayStart.toUtc());
}

void _ensureInitialized() {
  if (_initialized) {
    return;
  }
  timezone_data.initializeTimeZones();
  _bogota = timezone.getLocation('America/Bogota');
  _initialized = true;
}
