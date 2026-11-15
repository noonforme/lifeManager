import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';

const _today = LocalDate(2026, 10, 20);
const _employment = EmploymentId('0190f5d2-6a00-7000-8000-000000000001');
const _shift = ShiftId('0190f5d2-6a00-7000-8000-0000000000a1');
const _agreement = AgreementId('0190f5d2-6a00-7000-8000-0000000000b1');

WorkLocation _parse(String text) =>
    WorkLocation.parse(Uri.parse(text), today: _today);

const _schedule = ScheduleId('0190f5d2-6a00-7000-8000-0000000005c1');

void main() {
  test(
    'direct subform and row helpers reject malformed or rowless targets',
    () {
      const sheet = WorkLocation.shifts(
        _employment,
        month: LocalDate(2026, 10, 1),
      );
      expect(sheet.withSub('history').sub, isNull);
      final row = sheet.withRow('shift:${_shift.value}');
      expect(row.withSub('history').sub, 'history');
      expect(row.withSub('unknown').sub, isNull);
      for (final id in ['shift:garbage', 'day:xx']) {
        expect(row.withRow(id).rowId, isNull);
        expect(row.withRow(id).sub, isNull);
      }
    },
  );

  test('a Shifts location formats as the spec 4.5 route and parses back', () {
    const location = WorkLocation.shifts(
      _employment,
      month: LocalDate(2026, 10, 1),
      shift: _shift,
      sub: 'breaks',
    );
    final uri = location.toUri();
    expect(
      uri.toString(),
      '/work?employment=${_employment.value}&sheet=shifts'
      '&from=2026-10-01&to=2026-10-31&record=shift:${_shift.value}'
      '&sub=breaks',
    );
    expect(WorkLocation.parse(uri, today: _today), location);
  });

  test('day= and record= are exclusive: a record wins over a day', () {
    final location = _parse(
      '/work?employment=${_employment.value}&sheet=shifts'
      '&from=2026-10-01&to=2026-10-31&day=2026-10-07'
      '&record=shift:${_shift.value}',
    );
    expect(location.shift, _shift);
    expect(location.day, isNull);
    expect(location.rowId, 'shift:${_shift.value}');
  });

  test('a planned day is the day= parameter and the planned row', () {
    final location = _parse(
      '/work?employment=${_employment.value}&sheet=shifts'
      '&from=2026-10-01&to=2026-10-31&day=2026-10-07',
    );
    expect(location.day, const LocalDate(2026, 10, 7));
    expect(location.rowId, 'day:2026-10-07');
    expect(location.toUri().queryParameters['day'], '2026-10-07');
  });

  test('a range that is not one whole month stays that range (Phase 4)', () {
    final location = _parse(
      '/work?employment=${_employment.value}&sheet=shifts'
      '&from=2026-09-15&to=2026-10-14',
    );
    expect(location.month, const LocalDate(2026, 9, 1));
    expect(location.wholeMonth, isFalse);
    expect(location.toUri().queryParameters['to'], '2026-10-14');
  });

  test('Shifts without a range is the current month', () {
    final location = _parse(
      '/work?employment=${_employment.value}&sheet=shifts',
    );
    expect(location.month, const LocalDate(2026, 10, 1));
  });

  test('a day outside the range moves the month to that day', () {
    final location = _parse(
      '/work?employment=${_employment.value}&sheet=shifts'
      '&from=2026-10-01&to=2026-10-31&day=2026-11-03',
    );
    expect(location.month, const LocalDate(2026, 11, 1));
    expect(location.day, const LocalDate(2026, 11, 3));
  });

  test('old links drop mode= and add= and keep a valid target', () {
    final location = _parse(
      '/work?employment=${_employment.value}&sheet=shifts'
      '&from=2026-10-01&to=2026-10-31&record=shift:${_shift.value}'
      '&mode=edit&add=extraShift',
    );
    expect(location.shift, _shift);
    expect(location.toUri().queryParameters.keys, isNot(contains('mode')));
    expect(location.toUri().queryParameters.keys, isNot(contains('add')));
  });

  test('/today, /journal and unknown paths open the Work overview', () {
    for (final path in ['/today', '/journal?entry=1', '/elsewhere', '/']) {
      expect(_parse(path), const WorkLocation.overview(), reason: path);
    }
  });

  test('a malformed employment id is the overview', () {
    expect(
      _parse('/work?employment=nope&sheet=shifts'),
      const WorkLocation.overview(),
    );
  });

  test('a malformed percent sequence is the overview', () {
    expect(_parse('/work?employment=%E0%A4'), const WorkLocation.overview());
  });

  test('an unknown sheet falls back to its employment', () {
    for (final sheet in ['bogus']) {
      expect(
        _parse('/work?employment=${_employment.value}&sheet=$sheet'),
        const WorkLocation.employment(_employment),
        reason: sheet,
      );
    }
  });

  test('an old link with a shift or a day and no sheet opens Shifts', () {
    final shift = _parse(
      '/work?employment=${_employment.value}&record=shift:${_shift.value}',
    );
    expect(shift.sheet, WorkSheetKind.shifts);
    expect(shift.shift, _shift);
    final day = _parse(
      '/work?employment=${_employment.value}&day=2026-11-03&mode=edit',
    );
    expect(day.month, const LocalDate(2026, 11, 1));
    expect(day.day, const LocalDate(2026, 11, 3));
  });

  test('an employment record link names the employment', () {
    expect(
      _parse('/work?record=employment:${_employment.value}'),
      const WorkLocation.employment(_employment),
    );
  });

  test('the Agreements place round-trips', () {
    final text =
        '/work?employment=${_employment.value}&sheet=agreements'
        '&record=agreement:${_agreement.value}';
    final location = _parse(text);
    expect(
      location,
      const WorkLocation.agreements(_employment, agreement: _agreement),
    );
    expect(location.toUri().toString(), text);
    expect(
      _parse('/work?employment=${_employment.value}&sheet=agreements'),
      const WorkLocation.agreements(_employment),
    );
  });

  test('an old agreement link opens the Agreements sheet', () {
    expect(
      _parse(
        '/work?employment=${_employment.value}'
        '&record=agreement:${_agreement.value}',
      ),
      const WorkLocation.agreements(_employment, agreement: _agreement),
    );
  });

  test('a shift record on Agreements is dropped', () {
    expect(
      _parse(
        '/work?employment=${_employment.value}&sheet=agreements'
        '&record=shift:${_shift.value}',
      ),
      const WorkLocation.agreements(_employment),
    );
  });

  test('withAgreement selects a version on Agreements only', () {
    expect(
      const WorkLocation.agreements(_employment).withAgreement(_agreement),
      const WorkLocation.agreements(_employment, agreement: _agreement),
    );
    expect(
      const WorkLocation.agreements(
        _employment,
        agreement: _agreement,
      ).withAgreement(null),
      const WorkLocation.agreements(_employment),
    );
    expect(
      const WorkLocation.employment(_employment).withAgreement(_agreement),
      const WorkLocation.employment(_employment),
    );
  });

  test('sub= needs a selected row and a known tab', () {
    expect(
      _parse('/work?employment=${_employment.value}&sheet=shifts&sub=breaks')
          .sub,
      isNull,
    );
    expect(
      _parse(
        '/work?employment=${_employment.value}&sheet=shifts'
        '&day=2026-10-07&sub=bogus',
      ).sub,
      isNull,
    );
  });

  test('withRow keeps the sheet and replaces only the target', () {
    const base = WorkLocation.shifts(
      _employment,
      month: LocalDate(2026, 10, 1),
      day: LocalDate(2026, 10, 7),
      sub: 'history',
    );
    expect(base.withRow('shift:${_shift.value}').shift, _shift);
    expect(base.withRow('shift:${_shift.value}').day, isNull);
    expect(base.withRow('shift:${_shift.value}').sub, 'history');
    expect(base.withRow('day:2026-10-09').day, const LocalDate(2026, 10, 9));
    expect(base.withRow(null).rowId, isNull);
    expect(base.withRow(null).sub, isNull);
    // The new row has no id to put in a route (spec 4.5).
    expect(base.withRow('new').rowId, isNull);
  });

  test('the overview and an employment format without a sheet', () {
    expect(const WorkLocation.overview().toUri().toString(), '/work');
    expect(
      const WorkLocation.employment(_employment).toUri().toString(),
      '/work?employment=${_employment.value}',
    );
  });

  test('licences round-trips as a route', () {
    final parsed = WorkLocation.parse(
      Uri.parse('/work?page=licences&employment=x'),
      today: const LocalDate(2026, 10, 20),
    );
    expect(parsed, const WorkLocation.licences());
    expect(parsed.isLicences, isTrue);
    expect('${parsed.toUri()}', '/work?page=licences');
    expect(const WorkLocation.overview().isLicences, isFalse);
  });

  group('scopes and filters', () {
    const employment = EmploymentId('0190f5d2-6a00-7000-8000-000000000001');
    const from = LocalDate(2026, 10, 20);
    const to = LocalDate(2026, 11, 10);
    const filter = ShiftsFilter(
      status: ShiftsStatusFilter.draft,
      type: 'Night',
      offDays: true,
    );

    test('a range round-trips', () {
      const place = WorkLocation.shifts(
        employment,
        from: from,
        to: to,
        filter: filter,
      );
      final uri = place.toUri();
      expect(
        '$uri',
        '/work?employment=${employment.value}&sheet=shifts&from=2026-10-20'
            '&to=2026-11-10&status=draft&type=Night&off=1',
      );
      expect(_parse('$uri'), place);
      expect(place.wholeMonth, isFalse);
      expect(place.month, const LocalDate(2026, 10, 1));
    });

    test('a whole month is still a month', () {
      const place = WorkLocation.shifts(
        employment,
        month: LocalDate(2026, 10, 5),
      );
      expect(place.from, const LocalDate(2026, 10, 1));
      expect(place.to, const LocalDate(2026, 10, 31));
      expect(place.wholeMonth, isTrue);
      expect(
        place,
        const WorkLocation.shifts(
          employment,
          from: LocalDate(2026, 10, 1),
          to: LocalDate(2026, 10, 31),
        ),
      );
    });

    test('hand-edited routes normalise', () {
      final base = '/work?employment=${employment.value}&sheet=shifts';
      final swapped = _parse('$base&from=2026-11-10&to=2026-10-20');
      expect((swapped.from, swapped.to), (from, to));
      final long = _parse('$base&from=2026-01-01&to=2029-01-01');
      expect(long.to, const LocalDate(2027, 1, 1));
      expect(
        _parse('$base&from=2026-10-01&to=2026-10-31&status=bogus').filter,
        ShiftsFilter.none,
      );
      const spaced = WorkLocation.shifts(
        employment,
        month: LocalDate(2026, 10, 1),
        filter: ShiftsFilter(type: 'Long day'),
      );
      expect(_parse('${spaced.toUri()}'), spaced);
    });

    test('withScope swaps a backward range and cuts a long one', () {
      const place = WorkLocation.shifts(
        employment,
        month: LocalDate(2026, 10, 1),
      );
      final long = place.withScope(
        const LocalDate(2020, 1, 1),
        const LocalDate(2026, 10, 31),
      );
      expect(
        (long.from, long.to),
        (const LocalDate(2020, 1, 1), const LocalDate(2020, 12, 31)),
      );
      final backward = place.withScope(to, from);
      expect((backward.from, backward.to), (from, to));
    });

    test('withScope keeps a row inside and drops one outside', () {
      const place = WorkLocation.shifts(
        employment,
        month: LocalDate(2026, 10, 1),
        day: LocalDate(2026, 10, 25),
        filter: filter,
      );
      final inside = place.withScope(from, to);
      expect(inside.day, const LocalDate(2026, 10, 25));
      expect(inside.filter, filter);
      final outside = place.withScope(
        const LocalDate(2026, 11, 1),
        const LocalDate(2026, 11, 30),
      );
      expect(outside.day, isNull);
      expect(place.withFilter(ShiftsFilter.none).filter, ShiftsFilter.none);
      expect(place.withFilter(ShiftsFilter.none).day, place.day);
    });
  });

  test('the Schedules place round-trips', () {
    final text =
        '/work?employment=${_employment.value}&sheet=schedules'
        '&record=schedule:${_schedule.value}&version=2';
    final location = _parse(text);
    expect(
      location,
      const WorkLocation.schedules(
        _employment,
        schedule: _schedule,
        version: 2,
      ),
    );
    expect(location.toUri().toString(), text);
    expect(
      _parse('/work?employment=${_employment.value}&sheet=schedules'),
      const WorkLocation.schedules(_employment),
    );
  });

  test('a schedule link without a version selects its latest', () {
    final location = _parse(
      '/work?employment=${_employment.value}'
      '&record=schedule:${_schedule.value}',
    );
    expect(
      location,
      const WorkLocation.schedules(_employment, schedule: _schedule),
    );
    expect(location.version, isNull);
  });

  test('a shift record on Schedules is dropped', () {
    expect(
      _parse(
        '/work?employment=${_employment.value}&sheet=schedules'
        '&record=shift:${_shift.value}&version=3',
      ),
      const WorkLocation.schedules(_employment),
    );
  });

  test('withSchedule selects a version on Schedules only', () {
    expect(
      const WorkLocation.schedules(_employment)
          .withSchedule(_schedule, version: 1),
      const WorkLocation.schedules(
        _employment,
        schedule: _schedule,
        version: 1,
      ),
    );
    expect(
      const WorkLocation.agreements(_employment).withSchedule(_schedule),
      const WorkLocation.agreements(_employment),
    );
  });

  group('Calendar and To confirm (plan 4d-2, call 1)', () {
    const october = LocalDate(2026, 10, 1);
    final e = _employment.value;

    test('a Calendar route round-trips', () {
      const place = WorkLocation.calendar(
        _employment,
        month: october,
        day: LocalDate(2026, 10, 6),
        sub: 'history',
        filter: ShiftsFilter(type: 'Night'),
      );
      expect(
        place.toUri().toString(),
        '/work?employment=$e&sheet=calendar&from=2026-10-01&to=2026-10-31'
        '&day=2026-10-06&sub=history&type=Night',
      );
      expect(WorkLocation.parse(place.toUri(), today: _today), place);
      expect(place.sheet, WorkSheetKind.calendar);
      expect(place.daySelects, isTrue);
    });

    test('a Calendar route is a whole month', () {
      expect(
        _parse(
          '/work?employment=$e&sheet=calendar&from=2026-10-09&to=2026-10-12',
        ),
        const WorkLocation.calendar(_employment, month: october),
      );
      expect(
        _parse('/work?employment=$e&sheet=calendar'),
        const WorkLocation.calendar(_employment, month: october),
      );
      expect(
        _parse(
          '/work?employment=$e&sheet=calendar&from=2026-10-01&to=2026-10-31'
          '&day=2026-11-03',
        ),
        const WorkLocation.calendar(
          _employment,
          month: LocalDate(2026, 11, 1),
          day: LocalDate(2026, 11, 3),
        ),
      );
      expect(
        _parse('/work?employment=$e&sheet=calendar&status=draft&off=1').filter,
        ShiftsFilter.none,
      );
    });

    test('an old calendar link opens Calendar', () {
      expect(
        _parse('/work?employment=$e&sheet=calendar').sheet,
        WorkSheetKind.calendar,
      );
    });

    test('To confirm is All past days unless a month is named', () {
      final all = _parse('/work?employment=$e&sheet=toConfirm');
      expect(all, const WorkLocation.toConfirm(_employment));
      expect(all.allPastDays, isTrue);
      expect(all.toUri().toString(), '/work?employment=$e&sheet=toConfirm');
      final september = _parse(
        '/work?employment=$e&sheet=toConfirm&from=2026-09-01&to=2026-09-30',
      );
      expect(september.from, const LocalDate(2026, 9, 1));
      expect(september.to, const LocalDate(2026, 9, 30));
      expect(september.allPastDays, isFalse);
      expect(
        _parse(
          '/work?employment=$e&sheet=toConfirm&from=2026-09-03&to=2026-09-10',
        ).allPastDays,
        isTrue,
      );
      final filtered = _parse(
        '/work?employment=$e&sheet=toConfirm&off=1&status=toconfirm',
      );
      expect(filtered.filter.offDays, isFalse);
      expect(filtered.filter.status, ShiftsStatusFilter.toConfirm);
      expect(WorkLocation.parse(september.toUri(), today: _today), september);
    });

    test('To confirm on a month after this one shows this month', () {
      final december = _parse(
        '/work?employment=$e&sheet=toConfirm&from=2026-12-01&to=2026-12-31'
        '&day=2026-12-04',
      );
      expect(december.from, const LocalDate(2026, 10, 1));
      expect(december.to, const LocalDate(2026, 10, 31));
      expect(december.day, isNull);
    });

    test('selection on a day sheet is the date', () {
      const place = WorkLocation.calendar(
        _employment,
        month: october,
        sub: 'history',
      );
      final picked = place.withRow(
        'shift:${_shift.value}',
        date: const LocalDate(2026, 10, 6),
      );
      expect(picked.day, const LocalDate(2026, 10, 6));
      expect(picked.shift, isNull);
      expect(picked.withSub('history').sub, 'history');
      final none = picked.withRow(null);
      expect(none.day, isNull);
      expect(none.sub, isNull);
      expect(place.withRow('new').day, isNull);
      expect(
        const WorkLocation.toConfirm(_employment)
            .withRow('day:2026-10-06', date: const LocalDate(2026, 10, 6))
            .day,
        const LocalDate(2026, 10, 6),
      );
    });

    test('the scope of a day sheet', () {
      const filter = ShiftsFilter(type: 'Night');
      const calendar = WorkLocation.calendar(
        _employment,
        month: october,
        day: LocalDate(2026, 10, 6),
        filter: filter,
      );
      final november = calendar.withScope(
        const LocalDate(2026, 11, 1),
        const LocalDate(2026, 11, 30),
      );
      expect(
        november,
        const WorkLocation.calendar(
          _employment,
          month: LocalDate(2026, 11, 1),
          filter: filter,
        ),
      );
      const all = WorkLocation.toConfirm(_employment);
      final september = all.withScope(
        const LocalDate(2026, 9, 1),
        const LocalDate(2026, 9, 30),
      );
      expect(september.from, const LocalDate(2026, 9, 1));
      expect(september.sheet, WorkSheetKind.toConfirm);
      expect(september.withAllPastDays().allPastDays, isTrue);
      expect(
        const WorkLocation.toConfirm(_employment, day: LocalDate(2026, 10, 6))
            .withScope(
              const LocalDate(2026, 9, 1),
              const LocalDate(2026, 9, 30),
            )
            .day,
        isNull,
      );
      expect(
        calendar.withFilter(ShiftsFilter.none).sheet,
        WorkSheetKind.calendar,
      );
    });
  });
}
