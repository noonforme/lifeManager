import 'dart:io';

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

typedef ReadLink = String? Function(String path);
typedef ReadFile = String? Function(String path);

/// Names the operating system's current IANA zone, or null when it cannot be
/// determined from a known zone name. Never guesses from offsets.
final class SystemTimezoneSource {
  SystemTimezoneSource({
    required this.environment,
    required this.readLink,
    required this.readFile,
  });

  factory SystemTimezoneSource.platform() => SystemTimezoneSource(
    environment: Platform.environment,
    readLink: (path) {
      try {
        return Link(path).resolveSymbolicLinksSync();
      } on FileSystemException {
        return null;
      }
    },
    readFile: (path) {
      try {
        return File(path).readAsStringSync();
      } on FileSystemException {
        return null;
      }
    },
  );

  final Map<String, String> environment;
  final ReadLink readLink;
  final ReadFile readFile;

  static const _marker = '/zoneinfo/';

  String? currentZoneId() {
    tz_data.initializeTimeZones();
    final candidates = <String?>[
      environment['TZ']?.trim(),
      _fromPath(readLink('/etc/localtime')),
      readFile('/etc/timezone')?.trim(),
    ];
    for (final candidate in candidates) {
      if (candidate != null && _isKnown(candidate)) return candidate;
    }
    return null;
  }

  String? _fromPath(String? path) {
    if (path == null) return null;
    final index = path.indexOf(_marker);
    return index < 0 ? null : path.substring(index + _marker.length);
  }

  bool _isKnown(String zoneId) {
    if (zoneId.isEmpty || zoneId.startsWith(':')) return false;
    try {
      tz.getLocation(zoneId);
      return true;
    } on tz.LocationNotFoundException {
      return false;
    }
  }
}
