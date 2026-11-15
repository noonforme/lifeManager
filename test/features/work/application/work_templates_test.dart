import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/work_templates.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  final zones = IanaTimezoneService();

  test('the latest finalized shift becomes the template', () {
    final template = shiftTemplateFromLast([
      (shift: _shift(1, DateTime.utc(2026, 9, 7, 5), hours: 8), breaks: []),
      (
        // 22:00 to 06:00 in Vilnius with a break 01:00–01:30.
        shift: _shift(2, DateTime.utc(2026, 9, 8, 19), hours: 8),
        breaks: [
          _break(
            2,
            DateTime.utc(2026, 9, 8, 22),
            DateTime.utc(2026, 9, 8, 22, 30),
          ),
        ],
      ),
      (
        shift: _shift(
          3,
          DateTime.utc(2026, 9, 9, 5),
          hours: 8,
          state: ShiftState.draft,
        ),
        breaks: [],
      ),
    ], zones)!;

    expect(template.employmentId, _employment);
    expect(template.timezoneId, 'Europe/Vilnius');
    expect(template.start, const LocalTime(22, 0));
    expect(template.end, const LocalTime(6, 0));
    expect(template.endDayOffset, 1);
    expect(template.breaks.single.startDayOffset, 1);
    expect(template.breaks.single.start, const LocalTime(1, 0));
    expect(template.breaks.single.end, const LocalTime(1, 30));
  });

  test('with no finalized shift there is no template', () {
    expect(shiftTemplateFromLast(const [], zones), isNull);
    expect(
      shiftTemplateFromLast([
        (
          shift: _shift(
            1,
            DateTime.utc(2026, 9, 7, 5),
            hours: 8,
            state: ShiftState.voided,
          ),
          breaks: [],
        ),
      ], zones),
      isNull,
    );
  });

  test('day offsets carry a template onto another date', () {
    expect(
      ShiftTemplate.shift(const LocalDate(2026, 12, 31), 1),
      const LocalDate(2027, 1, 1),
    );
  });
}

const _employment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');

WorkShift _shift(
  int n,
  DateTime start, {
  required int hours,
  ShiftState state = ShiftState.finalized,
}) => WorkShift(
  id: ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c3$n'),
  employmentId: _employment,
  agreementId: state == ShiftState.draft
      ? null
      : const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  state: state,
  startUtc: start,
  endUtc: start.add(Duration(hours: hours)),
  timezoneId: 'Europe/Vilnius',
  localStartDate: LocalDate(start.year, start.month, start.day),
  note: 'Never copied',
  voidReason: state == ShiftState.voided ? 'Synthetic' : null,
  replacementShiftId: state == ShiftState.voided
      ? const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c39')
      : null,
  replacedShiftId: null,
  createdAtUtc: start,
  updatedAtUtc: start,
  revision: const Revision(1),
);

ShiftBreak _break(int n, DateTime start, DateTime end) => ShiftBreak(
  id: ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c4$n'),
  shiftId: ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c3$n'),
  startUtc: start,
  endUtc: end,
  createdAtUtc: start,
  updatedAtUtc: end,
  revision: const Revision(0),
);
