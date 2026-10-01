import 'local_date.dart';
import 'local_time.dart';
import 'timezone_service.dart';

/// A local wall-clock reading: the date and the whole minute of the day.
typedef WallTime = ({LocalDate date, int minuteOfDay});

/// Wall-clock conversions for one IANA zone, built on [TimezoneService].
final class ZoneWallClock {
  const ZoneWallClock(this._zones, this.zoneId);

  final TimezoneService _zones;
  final String zoneId;

  /// The wall clock at [utc]. Seconds are dropped.
  WallTime toLocal(DateTime utc) {
    final time = _zones.localTimeAt(utc, zoneId);
    return (
      date: _zones.localDateAt(utc, zoneId),
      minuteOfDay: time.hour * 60 + time.minute,
    );
  }

  /// Every instant at which the wall clock reads [minuteOfDay] on [date]:
  /// one normally, two in a daylight-saving overlap, and in a gap the first
  /// valid instant after it.
  List<DateTime> toInstants(LocalDate date, int minuteOfDay) {
    RangeError.checkValueInInterval(minuteOfDay, 0, 1439, 'minuteOfDay');
    var day = date;
    var minute = minuteOfDay;
    // Gaps are at most a few hours; a day bounds the search.
    for (var step = 0; step <= 24 * 60; step++) {
      final time = LocalTime(minute ~/ 60, minute % 60);
      try {
        return [_zones.resolveLocal(day, time, zoneId).utc];
      } on AmbiguousLocalTime {
        return [
          _zones.resolveLocal(day, time, zoneId, fold: FoldChoice.earlier).utc,
          _zones.resolveLocal(day, time, zoneId, fold: FoldChoice.later).utc,
        ];
      } on NonexistentLocalTime {
        minute++;
        if (minute == 24 * 60) {
          minute = 0;
          final next = DateTime.utc(day.year, day.month, day.day + 1);
          day = LocalDate(next.year, next.month, next.day);
        }
      }
    }
    throw StateError('No valid local time near $date');
  }
}

/// Wall-clock conversions per zone id, in the shape pay calculation takes.
({
  WallTime Function(DateTime utc) toLocal,
  List<DateTime> Function(LocalDate date, int minuteOfDay) toInstants,
})
Function(String zoneId)
zoneClocksOf(TimezoneService zones) => (zoneId) {
  final clock = ZoneWallClock(zones, zoneId);
  return (toLocal: clock.toLocal, toInstants: clock.toInstants);
};
