import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/core/time/wall_clock.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_premiums.dart';

typedef _Interval = ({DateTime start, DateTime end});

void main() {
  group('segmentation, fixed offset', () {
    test('an 8-hour day shift has one plain segment', () {
      final segments = _segment([
        _local('2026-09-15 08:00', '2026-09-15 16:00'),
      ], _agreement());

      expect(segments, hasLength(1));
      expect(segments.single.seconds, 8 * 3600);
      expect(_flags(segments.single), (false, false, false));
    });

    test('a 12-hour night shift ends with 4 hours of night overtime', () {
      final segments = _segment([
        _local('2026-09-15 18:00', '2026-09-16 06:00'),
      ], _agreement());

      expect(segments.map(_describe), [
        '18:00 4:00 ---',
        '22:00 2:00 N--',
        '00:00 2:00 N--',
        '02:00 4:00 N-O',
      ]);
      final pay = _pay(segments, _agreement());
      expect(pay.totalPaidSeconds, 12 * 3600);
      expect(pay.nightPaidSeconds, 8 * 3600);
      expect(pay.overtimePaidSeconds, 4 * 3600);
      expect(pay.holidayPaidSeconds, 0);
      expect(pay.regularPaidSeconds, 4 * 3600);
      // 4h × 20 + 4h × 20 × 1.5 (night) + 4h × 20 × 1.5 (highest of both).
      expect(pay.amount.minorUnits, 32000);
    });

    test('a shift into 24 December turns holiday at local midnight', () {
      final segments = _segment([
        _local('2026-12-23 20:00', '2026-12-24 04:00'),
      ], _agreement(nightEnabled: false));

      expect(segments.map(_describe), ['20:00 4:00 ---', '00:00 4:00 -H-']);
      expect(_pay(segments, _agreement()).holidayPaidSeconds, 4 * 3600);
    });

    test('breaks are not paid and are not night time', () {
      final segments = _segment([
        _local('2026-09-15 20:00', '2026-09-15 22:30'),
        _local('2026-09-15 23:00', '2026-09-16 02:00'),
      ], _agreement());
      final pay = _pay(segments, _agreement());

      expect(pay.totalPaidSeconds, 5 * 3600 + 30 * 60);
      expect(pay.nightPaidSeconds, 3 * 3600 + 30 * 60);
    });

    test('overtime counts paid time, so it starts after a break', () {
      final agreement = _agreement(thresholdMinutes: 150, nightEnabled: false);
      final segments = _segment([
        _local('2026-09-15 08:00', '2026-09-15 10:30'),
        _local('2026-09-15 11:00', '2026-09-15 14:00'),
      ], agreement);

      expect(segments.map(_describe), ['08:00 2:30 ---', '11:00 3:00 --O']);
    });

    test('overtime can start inside a paid interval', () {
      final segments = _segment([
        _local('2026-09-15 08:00', '2026-09-15 12:00'),
        _local('2026-09-15 12:30', '2026-09-15 17:30'),
      ], _agreement(nightEnabled: false));

      expect(segments.map(_describe), [
        '08:00 4:00 ---',
        '12:30 4:00 ---',
        '16:30 1:00 --O',
      ]);
    });

    test('night pay off and no holiday calendar leave plain time', () {
      final agreement = _agreement(
        nightEnabled: false,
        calendar: HolidayCalendar.none,
      );
      final segments = _segment([
        _local('2026-12-24 22:00', '2026-12-25 02:00'),
      ], agreement);
      final pay = _pay(segments, agreement);

      expect(pay.nightPaidSeconds, 0);
      expect(pay.holidayPaidSeconds, 0);
      expect(pay.regularPaidSeconds, pay.totalPaidSeconds);
    });

    test('a night window that does not cross midnight', () {
      final segments = _segment([
        _local('2026-09-15 00:00', '2026-09-15 08:00'),
      ], _agreement(nightStart: 60, nightEnd: 5 * 60));

      expect(segments.map(_describe), [
        '00:00 1:00 ---',
        '01:00 4:00 N--',
        '05:00 3:00 ---',
      ]);
    });

    test('sub-second instants are truncated to whole seconds', () {
      final start = _utc('2026-09-15 08:00')
          .add(const Duration(milliseconds: 900));
      final segments = _segment([
        (start: start, end: _utc('2026-09-15 09:00')),
      ], _agreement());
      expect(segments.single.seconds, 3600);
      expect(segments.single.startUtc, _utc('2026-09-15 08:00'));
    });
  });

  group('segmentation, Europe/Vilnius daylight saving', () {
    final clock = ZoneWallClock(IanaTimezoneService(), 'Europe/Vilnius');
    List<PaySegment> vilnius(List<_Interval> intervals, PayAgreement a) =>
        segmentPaidTime(
          paidIntervals: intervals,
          agreement: a,
          toLocal: clock.toLocal,
          toInstants: clock.toInstants,
        );

    test('a night shift across spring-forward counts 7 hours once', () {
      // 22:00 EET to 06:00 EEST: the clock skips 03:00 to 04:00.
      final segments = vilnius([
        (
          start: DateTime.utc(2026, 3, 28, 20),
          end: DateTime.utc(2026, 3, 29, 3),
        ),
      ], _agreement());
      final pay = _pay(segments, _agreement());

      expect(pay.totalPaidSeconds, 7 * 3600);
      expect(pay.nightPaidSeconds, 7 * 3600);
      expect(segments.map((item) => item.startUtc), [
        DateTime.utc(2026, 3, 28, 20),
        DateTime.utc(2026, 3, 28, 22), // local midnight
        DateTime.utc(2026, 3, 29, 1), // the clock change
      ]);
    });

    test('a night shift across fall-back counts 9 hours once', () {
      // 22:00 EEST to 06:00 EET: the clock repeats 03:00 to 04:00.
      final segments = vilnius([
        (
          start: DateTime.utc(2026, 10, 24, 19),
          end: DateTime.utc(2026, 10, 25, 4),
        ),
      ], _agreement());
      final pay = _pay(segments, _agreement());

      expect(pay.totalPaidSeconds, 9 * 3600);
      expect(pay.nightPaidSeconds, 9 * 3600);
      expect(pay.overtimePaidSeconds, 3600);
      expect(segments.fold(0, (total, item) => total + item.seconds), 9 * 3600);
    });

    test('a window end inside the repeated hour applies on both passes', () {
      // 02:00 EEST to 05:00 EET with night until 03:30: 03:30 happens twice.
      final segments = vilnius([
        (
          start: DateTime.utc(2026, 10, 24, 23),
          end: DateTime.utc(2026, 10, 25, 3),
        ),
      ], _agreement(nightEnd: 3 * 60 + 30));
      final pay = _pay(segments, _agreement());

      expect(pay.totalPaidSeconds, 4 * 3600);
      expect(pay.nightPaidSeconds, 2 * 3600);
    });

    test('a window end inside the skipped hour ends at the jump', () {
      // 01:00 EET to 05:00 EEST with night until 03:30, which never happens.
      final segments = vilnius([
        (
          start: DateTime.utc(2026, 3, 28, 23),
          end: DateTime.utc(2026, 3, 29, 2),
        ),
      ], _agreement(nightEnd: 3 * 60 + 30));
      final pay = _pay(segments, _agreement());

      expect(pay.totalPaidSeconds, 3 * 3600);
      expect(pay.nightPaidSeconds, 2 * 3600);
    });
  });

  group('segment multiplier', () {
    PaySegment segment({
      bool night = false,
      bool holiday = false,
      bool ot = false,
    }) => PaySegment(
      startUtc: DateTime.utc(2026),
      seconds: 3600,
      night: night,
      holiday: holiday,
      overtime: ot,
    );
    RationalMultiplier r(int n, int d) =>
        RationalMultiplier(numerator: n, denominator: d);

    test('no active premium is ×1', () {
      for (final stacking in PremiumStacking.values) {
        expect(
          segmentMultiplier(segment(), _agreement(stacking: stacking)),
          r(1, 1),
        );
      }
    });

    test(
      'night on a holiday: highest ×2, additive ×2.5, multiplicative ×3',
      () {
        final item = segment(night: true, holiday: true);
        expect(
          segmentMultiplier(
            item,
            _agreement(stacking: PremiumStacking.highest),
          ),
          r(2, 1),
        );
        expect(
          segmentMultiplier(
            item,
            _agreement(stacking: PremiumStacking.additive),
          ),
          r(5, 2),
        );
        expect(
          segmentMultiplier(
            item,
            _agreement(stacking: PremiumStacking.multiplicative),
          ),
          r(3, 1),
        );
      },
    );

    test('night, holiday and overtime together', () {
      final item = segment(night: true, holiday: true, ot: true);
      expect(
        segmentMultiplier(item, _agreement(stacking: PremiumStacking.highest)),
        r(2, 1),
      );
      expect(
        segmentMultiplier(item, _agreement(stacking: PremiumStacking.additive)),
        r(3, 1),
      );
      expect(
        segmentMultiplier(
          item,
          _agreement(stacking: PremiumStacking.multiplicative),
        ),
        r(9, 2),
      );
    });

    test('a single premium is its own multiplier', () {
      for (final stacking in PremiumStacking.values) {
        expect(
          segmentMultiplier(segment(ot: true), _agreement(stacking: stacking)),
          r(3, 2),
        );
      }
    });
  });

  group('expected pay amount', () {
    test('rounds half-up once, over the whole shift', () {
      // EUR 1/h: each 18-second segment is half a cent; the shift is 1 cent.
      final segments = [
        PaySegment(
          startUtc: DateTime.utc(2026, 9, 15, 8),
          seconds: 18,
          night: false,
          holiday: false,
          overtime: false,
        ),
        PaySegment(
          startUtc: DateTime.utc(2026, 9, 15, 9),
          seconds: 18,
          night: false,
          holiday: false,
          overtime: false,
        ),
      ];
      final pay = calculateExpectedPay(
        segments: segments,
        hourlyRateMicroEur: 1000000,
        agreement: _agreement(),
        currency: const CurrencyCode.eur(),
      );
      expect(pay.amount.minorUnits, 1);
    });

    test('combines exact rational multipliers before rounding', () {
      // 54s × EUR 1/h × 1.5 = 2.25 cents.
      final pay = calculateExpectedPay(
        segments: [
          PaySegment(
            startUtc: DateTime.utc(2026, 9, 15, 8),
            seconds: 54,
            night: true,
            holiday: false,
            overtime: false,
          ),
        ],
        hourlyRateMicroEur: 1000000,
        agreement: _agreement(),
        currency: const CurrencyCode.eur(),
      );
      expect(pay.amount.minorUnits, 2);
    });

    test('rejects no paid time and a rate that is not positive', () {
      expect(
        () => calculateExpectedPay(
          segments: const [],
          hourlyRateMicroEur: 1000000,
          agreement: _agreement(),
          currency: const CurrencyCode.eur(),
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateExpectedPay(
          segments: [
            PaySegment(
              startUtc: DateTime.utc(2026),
              seconds: 60,
              night: false,
              holiday: false,
              overtime: false,
            ),
          ],
          hourlyRateMicroEur: 0,
          agreement: _agreement(),
          currency: const CurrencyCode.eur(),
        ),
        throwsArgumentError,
      );
    });
  });
}

/// Fixed UTC+2, enough for cases without a daylight-saving change.
const _offset = Duration(hours: 2);

WallTime _toLocal(DateTime utc) {
  final local = utc.add(_offset);
  return (
    date: LocalDate(local.year, local.month, local.day),
    minuteOfDay: local.hour * 60 + local.minute,
  );
}

List<DateTime> _toInstants(LocalDate date, int minuteOfDay) => [
  DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).add(Duration(minutes: minuteOfDay)).subtract(_offset),
];

DateTime _utc(String local) =>
    DateTime.parse('${local.replaceFirst(' ', 'T')}:00Z').subtract(_offset);

_Interval _local(String start, String end) =>
    (start: _utc(start), end: _utc(end));

List<PaySegment> _segment(List<_Interval> intervals, PayAgreement agreement) =>
    segmentPaidTime(
      paidIntervals: intervals,
      agreement: agreement,
      toLocal: _toLocal,
      toInstants: _toInstants,
    );

ExpectedPay _pay(List<PaySegment> segments, PayAgreement agreement) =>
    calculateExpectedPay(
      segments: segments,
      hourlyRateMicroEur: agreement.hourlyRateMicroEur,
      agreement: agreement,
      currency: const CurrencyCode.eur(),
    );

(bool, bool, bool) _flags(PaySegment item) =>
    (item.night, item.holiday, item.overtime);

String _describe(PaySegment item) {
  final local = _toLocal(item.startUtc);
  String two(int value) => value.toString().padLeft(2, '0');
  final clock =
      '${two(local.minuteOfDay ~/ 60)}:${two(local.minuteOfDay % 60)}';
  final length = '${item.seconds ~/ 3600}:${two(item.seconds % 3600 ~/ 60)}';
  final flags =
      '${item.night ? 'N' : '-'}${item.holiday ? 'H' : '-'}'
      '${item.overtime ? 'O' : '-'}';
  return '$clock $length $flags';
}

PayAgreement _agreement({
  int thresholdMinutes = 480,
  bool nightEnabled = true,
  int nightStart = 22 * 60,
  int nightEnd = 6 * 60,
  HolidayCalendar calendar = HolidayCalendar.lithuania,
  PremiumStacking stacking = PremiumStacking.highest,
}) {
  return PayAgreement(
    id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
    employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
    version: 1,
    effectiveStart: LocalDate.parse('2026-01-01'),
    effectiveEnd: null,
    hourlyRateMicroEur: 20000000,
    basis: const GrossBasis(),
    overtimeThresholdMinutes: thresholdMinutes,
    overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
    label: null,
    note: null,
    createdAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
    usedByFinalizedShift: false,
    nightEnabled: nightEnabled,
    nightStartMinute: nightStart,
    nightEndMinute: nightEnd,
    holidayCalendar: calendar,
    premiumStacking: stacking,
  );
}
