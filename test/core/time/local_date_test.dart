import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';

void main() {
  test('strict date rejects malformed and impossible input', () {
    expect(LocalDate.tryParse('2026-09-29'), const LocalDate(2026, 9, 29));
    expect(LocalDate.tryParse('29/09/2026'), isNull);
    expect(LocalDate.tryParse('2026-9-29'), isNull);
    expect(LocalDate.tryParse('2026-09-31'), isNull);
    expect(
      () => LocalDate.parse('2026-02-29'),
      throwsA(isA<FormatException>()),
    );
  });

  test('dates compare and render without timezone conversion', () {
    const earlier = LocalDate(2026, 9, 29);
    const later = LocalDate(2026, 9, 30);

    expect(earlier.compareTo(later), lessThan(0));
    expect(earlier.toString(), '2026-09-29');
  });

  test('system clock returns a UTC instant', () {
    expect(SystemAppClock().nowUtc().isUtc, isTrue);
  });
}
