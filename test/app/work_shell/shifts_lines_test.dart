import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';

ShiftsLine _line(
  String id,
  ShiftsStatus status, {
  String? type,
  int day = 5,
  String note = '',
}) => ShiftsLine(
  id: id,
  status: status,
  date: LocalDate(2026, 10, day),
  start: status == ShiftsStatus.off ? null : const LocalTime(7, 0),
  end: status == ShiftsStatus.off ? null : const LocalTime(19, 0),
  breakSeconds: null,
  paidSeconds: null,
  pay: null,
  note: note,
  type: type,
);

final _lines = [
  _line('day:2026-10-05', ShiftsStatus.planned, type: 'Day'),
  _line('off:2026-10-08', ShiftsStatus.off, day: 8),
  _line('day:2026-10-11', ShiftsStatus.planned, type: 'Night', day: 11),
  _line('shift:a', ShiftsStatus.finalized, type: 'Manual', day: 20),
  _line('shift:b', ShiftsStatus.voided, type: 'Manual', day: 21, note: 'Wrong'),
];

List<String> _ids(List<ShiftsLine> lines) => [for (final l in lines) l.id];

void main() {
  test('Status keeps only what it admits', () {
    expect(
      _ids(
        filterShiftsLines(
          _lines,
          filter: const ShiftsFilter(status: ShiftsStatusFilter.finalized),
        ),
      ),
      ['shift:a'],
    );
    expect(
      _ids(
        filterShiftsLines(
          _lines,
          filter: const ShiftsFilter(status: ShiftsStatusFilter.effective),
        ),
      ),
      ['day:2026-10-05', 'day:2026-10-11', 'shift:a'],
    );
  });

  test('Type keeps its rows; Off rows show only with Off days', () {
    expect(
      _ids(
        filterShiftsLines(_lines, filter: const ShiftsFilter(type: 'Night')),
      ),
      ['day:2026-10-11'],
    );
    expect(_ids(filterShiftsLines(_lines, filter: ShiftsFilter.none)), [
      'day:2026-10-05',
      'day:2026-10-11',
      'shift:a',
      'shift:b',
    ]);
    expect(
      _ids(
        filterShiftsLines(_lines, filter: const ShiftsFilter(offDays: true)),
      ),
      contains('off:2026-10-08'),
    );
  });

  test('a filter never hides the selected or new row', () {
    final withNew = [..._lines, _line(newRowId, ShiftsStatus.fresh, day: 22)];
    final kept = filterShiftsLines(
      withNew,
      filter: const ShiftsFilter(status: ShiftsStatusFilter.finalized),
      find: 'zzz',
      keep: 'day:2026-10-05',
    );
    expect(_ids(kept), ['day:2026-10-05', newRowId]);
  });

  test('Find matches shown text, ignoring case', () {
    expect(
      _ids(filterShiftsLines(_lines, filter: ShiftsFilter.none, find: 'night')),
      ['day:2026-10-11'],
    );
    expect(
      _ids(filterShiftsLines(_lines, filter: ShiftsFilter.none, find: 'wrong')),
      ['shift:b'],
    );
    expect(
      _ids(
        filterShiftsLines(
          _lines,
          filter: ShiftsFilter.none,
          find: '2026-10-20',
        ),
      ),
      ['shift:a'],
    );
  });
  test('To confirm keeps the days waiting; Cancelled shows under All only', () {
    final lines = [
      ShiftsLine(
        id: 'day:2026-10-06',
        status: ShiftsStatus.planned,
        date: const LocalDate(2026, 10, 6),
        start: const LocalTime(7, 0),
        end: const LocalTime(19, 0),
        breakSeconds: null,
        paidSeconds: null,
        pay: null,
        note: '',
        toConfirm: true,
      ),
      ShiftsLine(
        id: 'day:2026-10-23',
        status: ShiftsStatus.planned,
        date: const LocalDate(2026, 10, 23),
        start: const LocalTime(7, 0),
        end: const LocalTime(19, 0),
        breakSeconds: null,
        paidSeconds: null,
        pay: null,
        note: '',
      ),
      const ShiftsLine(
        id: 'day:2026-10-12',
        status: ShiftsStatus.leave,
        date: LocalDate(2026, 10, 12),
        start: null,
        end: null,
        breakSeconds: null,
        paidSeconds: 41400,
        pay: null,
        note: '',
        toConfirm: true,
      ),
      const ShiftsLine(
        id: 'day:2026-10-13',
        status: ShiftsStatus.cancelled,
        date: LocalDate(2026, 10, 13),
        start: null,
        end: null,
        breakSeconds: null,
        paidSeconds: null,
        pay: null,
        note: '',
      ),
    ];
    List<String> kept(ShiftsStatusFilter status) =>
        _ids(filterShiftsLines(lines, filter: ShiftsFilter(status: status)));
    expect(kept(ShiftsStatusFilter.toConfirm), [
      'day:2026-10-06',
      'day:2026-10-12',
    ]);
    expect(kept(ShiftsStatusFilter.planned), [
      'day:2026-10-06',
      'day:2026-10-23',
      'day:2026-10-12',
    ]);
    expect(
      kept(ShiftsStatusFilter.effective),
      isNot(contains('day:2026-10-13')),
    );
    expect(kept(ShiftsStatusFilter.all), contains('day:2026-10-13'));
    expect(
      ShiftsStatusFilter.fromRoute('toconfirm'),
      ShiftsStatusFilter.toConfirm,
    );
  });
}
