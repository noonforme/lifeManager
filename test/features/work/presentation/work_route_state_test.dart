import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';

void main() {
  const employment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');

  test('the sheet and void filter round-trip as structural parameters', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
      sheet: WorkSheet.payslips,
      showVoid: true,
    );
    final uri = workRouteUri(state);
    expect(
      uri.toString(),
      '/work?employment=${employment.value}&sheet=payslips&void=1'
      '&mode=inspect',
    );
    final parsed = (parseWorkRoute(uri) as ValidWorkRoute).state;
    expect(parsed.sheet, WorkSheet.payslips);
    expect(parsed.showVoid, isTrue);
  });

  test('no sheet is the default and stays implicit', () {
    final parsed = (parseWorkRoute(
      Uri.parse('/work?employment=${employment.value}'),
    ) as ValidWorkRoute).state;
    expect(parsed.sheet, isNull);
    expect(parsed.showVoid, isFalse);
    expect(workRouteUri(parsed).query, isNot(contains('sheet')));
  });

  test('an unknown sheet or void value is invalid', () {
    expect(
      parseWorkRoute(Uri.parse('/work?sheet=ledger')),
      isA<InvalidWorkRoute>(),
    );
    expect(
      parseWorkRoute(Uri.parse('/work?void=yes')),
      isA<InvalidWorkRoute>(),
    );
  });

  test('copyWith keeps the sheet when the record changes', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
      sheet: WorkSheet.agreements,
    );
    final next = state.copyWith(mode: WorkInspectorMode.create);
    expect(next.sheet, WorkSheet.agreements);
    expect(next.mode, WorkInspectorMode.create);
  });

  test('add and template round-trip without touching the date range', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.edit,
      adding: WorkAddKind.payslip,
      fromLast: true,
    );
    final uri = workRouteUri(state);
    expect(uri.query, contains('add=payslip'));
    expect(uri.query, contains('template=last'));
    final parsed = (parseWorkRoute(uri) as ValidWorkRoute).state;
    expect(parsed.adding, WorkAddKind.payslip);
    expect(parsed.fromLast, isTrue);
    expect(parsed.scope, isNull);

    expect(
      parseWorkRoute(Uri.parse('/work?add=invoice')),
      isA<InvalidWorkRoute>(),
    );
    expect(
      parseWorkRoute(Uri.parse('/work?template=first')),
      isA<InvalidWorkRoute>(),
    );
  });

  test('properties mode round-trips through the URL', () {
    const shift = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c22';
    final uri = Uri.parse(
      '/work?employment=${employment.value}&record=shift:$shift'
      '&mode=properties',
    );
    final parsed = parseWorkRoute(uri) as ValidWorkRoute;
    expect(parsed.state.mode, WorkInspectorMode.properties);
    expect(workRouteUri(parsed.state).queryParameters['mode'], 'properties');
  });

  test('an explicit Shifts sheet is kept in the address', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
      sheet: WorkSheet.shifts,
    );
    expect(workRouteUri(state).query, contains('sheet=shifts'));
  });

  test('the calendar, leave and schedules sheets round-trip', () {
    for (final sheet in [
      WorkSheet.calendar,
      WorkSheet.leave,
      WorkSheet.schedules,
    ]) {
      final state = WorkRouteState(
        employmentId: employment,
        scope: null,
        record: null,
        mode: WorkInspectorMode.inspect,
        sheet: sheet,
      );
      final parsed =
          (parseWorkRoute(workRouteUri(state)) as ValidWorkRoute).state;
      expect(parsed.sheet, sheet);
    }
  });

  test('a day opens as properties and round-trips', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.properties,
      sheet: WorkSheet.calendar,
      day: LocalDate(2026, 10, 7),
    );
    final uri = workRouteUri(state);
    expect(uri.query, contains('day=2026-10-07'));
    final parsed = (parseWorkRoute(uri) as ValidWorkRoute).state;
    expect(parsed.day, const LocalDate(2026, 10, 7));
    expect(parsed.mode, WorkInspectorMode.properties);
  });

  test('a malformed day is an invalid scope', () {
    final result = parseWorkRoute(Uri.parse('/work?day=2026-13-40'));
    expect(
      (result as InvalidWorkRoute).reason,
      WorkRouteProblem.malformedScope,
    );
  });

  test('confirm=1 opens the confirm dialog; any other value is invalid', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
      confirming: true,
    );
    final uri = workRouteUri(state);
    expect(uri.query, contains('confirm=1'));
    expect((parseWorkRoute(uri) as ValidWorkRoute).state.confirming, isTrue);
    expect(
      parseWorkRoute(Uri.parse('/work?confirm=yes')),
      isA<InvalidWorkRoute>(),
    );
  });

  test('schedule and leave records parse with their own ids', () {
    final schedule = WorkRecordRef.tryParse(
      'schedule:018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61',
    )!;
    expect(schedule.kind, WorkRecordKind.schedule);
    expect(schedule.id, isA<ScheduleId>());
    final leave = WorkRecordRef.tryParse(
      'leave:018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c71',
    )!;
    expect(leave.kind, WorkRecordKind.leave);
    expect(leave.id, isA<LeaveRecordId>());
  });

  test('the new add kinds round-trip', () {
    for (final adding in [
      WorkAddKind.schedule,
      WorkAddKind.extraShift,
      WorkAddKind.leave,
    ]) {
      final state = WorkRouteState(
        employmentId: employment,
        scope: null,
        record: null,
        mode: WorkInspectorMode.inspect,
        adding: adding,
      );
      expect(
        (parseWorkRoute(workRouteUri(state)) as ValidWorkRoute).state.adding,
        adding,
      );
    }
  });
}
