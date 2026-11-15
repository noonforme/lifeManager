import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';

void main() {
  test('Effective admits all but Void and Cancelled', () {
    for (final status in ShiftsStatus.values) {
      expect(
        ShiftsStatusFilter.effective.admits(status),
        status != ShiftsStatus.voided && status != ShiftsStatus.cancelled,
        reason: '$status',
      );
    }
  });

  test('Planned admits planned, changed, extra and leave days', () {
    expect(
      [
        for (final status in ShiftsStatus.values)
          if (ShiftsStatusFilter.planned.admits(status)) status,
      ],
      [
        ShiftsStatus.planned,
        ShiftsStatus.changed,
        ShiftsStatus.extra,
        ShiftsStatus.leave,
      ],
    );
  });

  test('a filter compares by value and knows when it is none', () {
    expect(ShiftsFilter.none.isNone, isTrue);
    const set = ShiftsFilter(
      status: ShiftsStatusFilter.draft,
      type: 'Night',
      offDays: true,
    );
    expect(set.isNone, isFalse);
    expect(
      set,
      const ShiftsFilter(
        status: ShiftsStatusFilter.draft,
        type: 'Night',
        offDays: true,
      ),
    );
    expect(set.copyWith(type: () => null).type, isNull);
  });
}
