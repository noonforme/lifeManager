import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';

const employment = EmploymentId('0190f5d2-6a00-7000-8000-000000000001');
const record = LeaveRecordId('0190f5d2-6a00-7000-8000-000000000002');
const month = LocalDate(2026, 10, 1);
WorkLocation parse(String route) =>
    WorkLocation.parse(Uri.parse(route), today: month);
void main() {
  for (final status in [
    ShiftsStatusFilter.all,
    ShiftsStatusFilter.effective,
    ShiftsStatusFilter.voided,
  ]) {
    test('Leave round-trips with $status and its Working tab', () {
      final place = WorkLocation.leave(
        employment,
        month: month,
        leave: record,
        sub: 'working',
        filter: ShiftsFilter(status: status, type: 'Sick'),
      );
      expect(parse('${place.toUri()}'), place);
      expect(place.withSub('breaks').sub, isNull);
      expect(place.withSub('history').sub, 'history');
      expect(place.withLeave(null).sub, isNull);
      expect(place.rowId, 'leave:${record.value}');
    });
  }
  test('old Leave links open Leave; defaults and filters normalize', () {
    final place = parse(
      '/work?employment=${employment.value}&record=leave:${record.value}',
    );
    expect(place.sheet, WorkSheetKind.leave);
    expect(place.leave, record);
    expect(place.month, month);
    expect(place.filter.status, ShiftsStatusFilter.effective);
    expect(
      parse(
        '/work?employment=${employment.value}&sheet=leave&status=draft&type=Manual&off=1&sub=working',
      ).filter,
      const ShiftsFilter(status: ShiftsStatusFilter.effective),
    );
    expect(
      parse(
        '/work?employment=${employment.value}&sheet=leave&record=shift:${record.value}',
      ).leave,
      isNull,
    );
  });
  test(
    'Leave ranges swap, cap and retain filters and selection for resolution',
    () {
      final place = WorkLocation.leave(
        employment,
        month: month,
        leave: record,
        sub: 'history',
      );
      final range = place.withScope(
        const LocalDate(2026, 10, 20),
        const LocalDate(2026, 10, 5),
      );
      expect(range.from, const LocalDate(2026, 10, 5));
      expect(range.to, const LocalDate(2026, 10, 20));
      expect(range.leave, isNull);
      expect(
        place.withScope(month, month.lastOfMonth, keepLeave: true).leave,
        record,
      );
      final capped = place.withScope(month, month.addDays(400));
      expect(capped.to!.daysSince(capped.from!), 365);
      expect(parse('${range.toUri()}'), range);
      expect(
        place
            .withFilter(const ShiftsFilter(status: ShiftsStatusFilter.voided))
            .sheet,
        WorkSheetKind.leave,
      );
    },
  );
}
