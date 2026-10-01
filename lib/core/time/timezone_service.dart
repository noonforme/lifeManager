import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'local_date.dart';
import 'local_time.dart';

enum FoldChoice { earlier, later }

final class ZonedInstant {
  const ZonedInstant({
    required this.utc,
    required this.zoneId,
    required this.localDate,
    required this.localTime,
    required this.offset,
  });

  final DateTime utc;
  final String zoneId;
  final LocalDate localDate;
  final LocalTime localTime;
  final Duration offset;
}

abstract interface class TimezoneService {
  ZonedInstant resolveLocal(
    LocalDate date,
    LocalTime time,
    String zoneId, {
    FoldChoice? fold,
  });

  LocalDate localDateAt(DateTime utc, String zoneId);
}

final class IanaTimezoneService implements TimezoneService {
  IanaTimezoneService() {
    _ensureInitialized();
  }

  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  @override
  ZonedInstant resolveLocal(
    LocalDate date,
    LocalTime time,
    String zoneId, {
    FoldChoice? fold,
  }) {
    final location = _location(zoneId);
    final localEpoch = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
    );
    final offsets = location.zones.map((zone) => zone.offset).toSet();
    final candidates = <DateTime>[];

    for (final offset in offsets) {
      final utc = localEpoch.subtract(offset);
      final local = tz.TZDateTime.from(utc, location);
      if (local.year == date.year &&
          local.month == date.month &&
          local.day == date.day &&
          local.hour == time.hour &&
          local.minute == time.minute &&
          local.second == time.second) {
        candidates.add(utc);
      }
    }

    candidates.sort();
    if (candidates.isEmpty) {
      throw const NonexistentLocalTime();
    }
    if (candidates.length > 1 && fold == null) {
      throw const AmbiguousLocalTime();
    }

    final selected = candidates.length == 1 || fold == FoldChoice.earlier
        ? candidates.first
        : candidates.last;
    final local = tz.TZDateTime.from(selected, location);
    return ZonedInstant(
      utc: selected,
      zoneId: zoneId,
      localDate: LocalDate(local.year, local.month, local.day),
      localTime: LocalTime(local.hour, local.minute, local.second),
      offset: local.timeZoneOffset,
    );
  }

  @override
  LocalDate localDateAt(DateTime utc, String zoneId) {
    final local = tz.TZDateTime.from(utc.toUtc(), _location(zoneId));
    return LocalDate(local.year, local.month, local.day);
  }

  tz.Location _location(String zoneId) {
    try {
      return tz.getLocation(zoneId);
    } on tz.LocationNotFoundException {
      throw const UnknownTimezone();
    }
  }
}

final class AmbiguousLocalTime implements Exception {
  const AmbiguousLocalTime();
}

final class NonexistentLocalTime implements Exception {
  const NonexistentLocalTime();
}

final class UnknownTimezone implements Exception {
  const UnknownTimezone();
}
