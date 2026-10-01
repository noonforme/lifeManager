import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/system_timezone.dart';

void main() {
  test('TZ environment names a known IANA zone', () {
    final source = SystemTimezoneSource(
      environment: const {'TZ': 'Europe/Amsterdam'},
      readLink: (_) => null,
      readFile: (_) => null,
    );

    expect(source.currentZoneId(), 'Europe/Amsterdam');
  });

  test('localtime symlink resolves through the zoneinfo path', () {
    final source = SystemTimezoneSource(
      environment: const {},
      readLink: (path) => path == '/etc/localtime'
          ? '/usr/share/zoneinfo/America/New_York'
          : null,
      readFile: (_) => null,
    );

    expect(source.currentZoneId(), 'America/New_York');
  });

  test('timezone file is used when no symlink is present', () {
    final source = SystemTimezoneSource(
      environment: const {'TZ': ':/etc/localtime'},
      readLink: (_) => null,
      readFile: (path) => path == '/etc/timezone' ? 'Europe/Berlin\n' : null,
    );

    expect(source.currentZoneId(), 'Europe/Berlin');
  });

  test('unknown or missing zones are unavailable instead of guessed', () {
    final source = SystemTimezoneSource(
      environment: const {'TZ': 'Mars/Olympus'},
      readLink: (_) => '/usr/share/zoneinfo/Not/AZone',
      readFile: (_) => null,
    );

    expect(source.currentZoneId(), isNull);
  });
}
