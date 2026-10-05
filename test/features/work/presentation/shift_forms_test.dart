import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/shift_forms.dart';
import 'package:lifeos/shared/workbench/era_form.dart';
import 'package:lifeos/shared/workbench/era_time_field.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

import '../../../support/era_pickers.dart';

const _today = LocalDate(2026, 10, 1);

Future<List<ManualShiftDraft>> _pumpShift(
  WidgetTester tester, {
  ShiftFormPrefill? prefill,
  MutationOutcome<WorkShift>? outcome,
}) async {
  final submitted = <ManualShiftDraft>[];
  await tester.pumpWidget(
    _TestApp(
      child: ShiftEditInspector(
        employmentId: employmentId,
        today: _today,
        initialTimezoneId: 'Europe/Vilnius',
        prefill: prefill,
        onSubmit: (draft) async {
          submitted.add(draft);
          return outcome ?? Committed(testShift);
        },
      ),
    ),
  );
  return submitted;
}

void main() {
  testWidgets("rows sit an era dialog's 7 px apart", (tester) async {
    await _pumpShift(tester);
    // Each label row carries its own 7 px; nothing else sits between rows.
    Rect row(String key) => tester.getRect(
      find.ancestor(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EraLabelled),
      ),
    );
    expect(row('shift-end-date').top - row('shift-start-time').bottom, 0);
  });

  testWidgets('manual overnight entry submits picked local facts', (
    tester,
  ) async {
    final submitted = await _pumpShift(tester);
    await setTime(tester, 'shift-start-time', const LocalTime(22, 30));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 10, 2));
    await setTime(tester, 'shift-end-time', const LocalTime(6, 15));
    await tester.enterText(
      find.byKey(const ValueKey('shift-timezone')),
      'Europe/Amsterdam',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-note')),
      'Night coverage',
    );
    await tester.tap(find.text('Add break'));
    await tester.pump();
    await pickDate(
      tester,
      'shift-break-start-date-0',
      const LocalDate(2026, 10, 2),
    );
    await setTime(tester, 'shift-break-start-0', const LocalTime(1, 0));
    await pickDate(
      tester,
      'shift-break-end-date-0',
      const LocalDate(2026, 10, 2),
    );
    await setTime(tester, 'shift-break-end-0', const LocalTime(1, 20));
    await _save(tester);

    final draft = submitted.single;
    expect(draft.localStartDate, _today);
    expect(draft.localStartTime, const LocalTime(22, 30));
    expect(draft.localEndDate, const LocalDate(2026, 10, 2));
    expect(draft.localEndTime, const LocalTime(6, 15));
    expect(draft.timezoneId, 'Europe/Amsterdam');
    expect(draft.note, 'Night coverage');
    final pause = draft.breaks.single;
    expect(pause.startDate, const LocalDate(2026, 10, 2));
    expect(pause.start, const LocalTime(1, 0));
    expect(pause.endDate, const LocalDate(2026, 10, 2));
    expect(pause.end, const LocalTime(1, 20));
  });

  testWidgets('validation preserves timezone note and manual draft fields', (
    tester,
  ) async {
    await _pumpShift(
      tester,
      outcome: const Invalid<WorkShift>({
        'localTime': [FieldIssue(FieldIssueCode.invalid)],
      }),
    );
    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 1));
    await setTime(tester, 'shift-start-time', const LocalTime(9, 0));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 10, 1));
    await setTime(tester, 'shift-end-time', const LocalTime(17, 0));
    await tester.enterText(
      find.byKey(const ValueKey('shift-timezone')),
      'Europe/Amsterdam',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-note')),
      'Owner note',
    );
    await _save(tester);

    expect(find.text('Europe/Amsterdam'), findsOneWidget);
    expect(find.text('Owner note'), findsOneWidget);
    expect(find.text('Check the local times and timezone.'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Timezone, Check the local times and timezone.'),
      findsOneWidget,
    );
  });

  testWidgets('a new shift starts today with empty times', (tester) async {
    final submitted = await _pumpShift(tester);
    expect(dateIn(tester, 'shift-start-date'), _today);
    expect(dateIn(tester, 'shift-end-date'), _today);
    expect(timeIn(tester, 'shift-start-time'), isNull);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('shift-start-time'))),
      isSemantics(label: 'Start time, not set'),
    );
    await _save(tester);
    expect(submitted, isEmpty);
    expect(find.text(shiftStartTimeMessage), findsOneWidget);
    expect(find.text(shiftEndTimeMessage), findsOneWidget);
  });

  testWidgets('the end date follows the start date until picked', (
    tester,
  ) async {
    await _pumpShift(tester);
    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 7));
    expect(dateIn(tester, 'shift-end-date'), const LocalDate(2026, 10, 7));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 10, 8));
    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 6));
    expect(dateIn(tester, 'shift-end-date'), const LocalDate(2026, 10, 8));
  });

  testWidgets(
    'an overnight prefill keeps its next-day end as the start moves',
    (tester) async {
      await _pumpShift(
        tester,
        prefill: const ShiftFormPrefill(
          startDate: LocalDate(2026, 10, 3),
          startTime: LocalTime(22, 0),
          endDate: LocalDate(2026, 10, 4),
          endTime: LocalTime(6, 0),
          timezoneId: 'Europe/Vilnius',
          breaks: [],
          note: null,
        ),
      );
      await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 10));
      expect(dateIn(tester, 'shift-end-date'), const LocalDate(2026, 10, 11));
    },
  );

  testWidgets(
    'a break starts on the shift date, its first step at the shift start',
    (tester) async {
      await _pumpShift(tester);
      await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 2));
      await setTime(tester, 'shift-start-time', const LocalTime(22, 30));
      await tester.tap(find.text('Add break'));
      await tester.pump();
      expect(
        dateIn(tester, 'shift-break-start-date-0'),
        const LocalDate(2026, 10, 2),
      );
      expect(timeIn(tester, 'shift-break-start-0'), isNull);
      final up = find.descendant(
        of: find.ancestor(
          of: find.byKey(const ValueKey('shift-break-start-0')),
          matching: find.byType(EraTimeField),
        ),
        matching: find.byKey(const ValueKey('era-time-up')),
      );
      await tester.ensureVisible(up);
      await tester.tap(up);
      await tester.pump();
      expect(timeIn(tester, 'shift-break-start-0'), const LocalTime(22, 30));
    },
  );

  testWidgets('an empty break is ignored; a half-set break is refused', (
    tester,
  ) async {
    final submitted = await _pumpShift(tester);
    await setTime(tester, 'shift-start-time', const LocalTime(9, 0));
    await setTime(tester, 'shift-end-time', const LocalTime(17, 0));
    await tester.tap(find.text('Add break'));
    await tester.pump();
    await _save(tester);
    expect(submitted.single.breaks, isEmpty);

    await setTime(tester, 'shift-break-start-0', const LocalTime(12, 0));
    await _save(tester);
    expect(submitted, hasLength(1));
    expect(find.text(breakTimesMessage), findsOneWidget);
  });

  testWidgets('a night shift with a break after midnight saves', (
    tester,
  ) async {
    final submitted = await _pumpShift(tester);
    await setTime(tester, 'shift-start-time', const LocalTime(22, 0));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 10, 2));
    await setTime(tester, 'shift-end-time', const LocalTime(6, 0));
    await tester.tap(find.text('Add break'));
    await tester.pump();
    await setTime(tester, 'shift-break-start-0', const LocalTime(2, 0));
    await setTime(tester, 'shift-break-end-0', const LocalTime(2, 30));
    await pickDate(
      tester,
      'shift-break-start-date-0',
      const LocalDate(2026, 10, 2),
    );
    expect(
      dateIn(tester, 'shift-break-end-date-0'),
      const LocalDate(2026, 10, 2),
      reason: 'the break end date follows its start date',
    );
    await pickDate(
      tester,
      'shift-break-end-date-0',
      const LocalDate(2026, 10, 2),
    );
    await _save(tester);

    final draft = submitted.single;
    expect(draft.localStartDate, _today);
    expect(draft.localEndDate, const LocalDate(2026, 10, 2));
    final pause = draft.breaks.single;
    expect(pause.startDate, const LocalDate(2026, 10, 2));
    expect(pause.start, const LocalTime(2, 0));
    expect(pause.endDate, const LocalDate(2026, 10, 2));
    expect(pause.end, const LocalTime(2, 30));
  });

  testWidgets('an end at or before the start is refused on the end time', (
    tester,
  ) async {
    final submitted = await _pumpShift(tester);
    await setTime(tester, 'shift-start-time', const LocalTime(22, 0));
    await setTime(tester, 'shift-end-time', const LocalTime(6, 0));
    await _save(tester);
    expect(submitted, isEmpty);
    expect(find.text(shiftEndAfterStartMessage), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('shift-end-time'))),
      isSemantics(label: 'End time, 06:00, $shiftEndAfterStartMessage'),
    );

    await setTime(tester, 'shift-end-time', const LocalTime(22, 0));
    await _save(tester);
    expect(submitted, isEmpty);
    expect(find.text(shiftEndAfterStartMessage), findsOneWidget);
  });

  testWidgets('a break outside the shift is refused on its start time', (
    tester,
  ) async {
    final submitted = await _pumpShift(tester);
    await setTime(tester, 'shift-start-time', const LocalTime(22, 0));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 10, 2));
    await setTime(tester, 'shift-end-time', const LocalTime(6, 0));
    await tester.tap(find.text('Add break'));
    await tester.pump();
    // Times after midnight on the shift's first date lie before its start.
    await setTime(tester, 'shift-break-start-0', const LocalTime(2, 0));
    await setTime(tester, 'shift-break-end-0', const LocalTime(2, 30));
    await _save(tester);
    expect(submitted, isEmpty);
    expect(find.text(breakInsideShiftMessage), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('shift-break-start-0'))),
      isSemantics(label: 'Break 1 start time, 02:00, $breakInsideShiftMessage'),
    );

    // A break that ends before it starts is outside the shift too.
    await pickDate(
      tester,
      'shift-break-start-date-0',
      const LocalDate(2026, 10, 2),
    );
    await setTime(tester, 'shift-break-end-0', const LocalTime(1, 30));
    await _save(tester);
    expect(submitted, isEmpty);
    expect(find.text(breakInsideShiftMessage), findsOneWidget);

    // Ending after the shift ends is refused as well.
    await setTime(tester, 'shift-break-end-0', const LocalTime(6, 30));
    await _save(tester);
    expect(submitted, isEmpty);
    expect(find.text(breakInsideShiftMessage), findsOneWidget);
  });

  testWidgets('break dates follow the shift start date until picked', (
    tester,
  ) async {
    await _pumpShift(
      tester,
      prefill: const ShiftFormPrefill(
        startDate: LocalDate(2026, 10, 3),
        startTime: LocalTime(22, 0),
        endDate: LocalDate(2026, 10, 4),
        endTime: LocalTime(6, 0),
        timezoneId: 'Europe/Vilnius',
        breaks: [
          ManualBreakDraft(
            startDate: LocalDate(2026, 10, 3),
            start: LocalTime(23, 45),
            endDate: LocalDate(2026, 10, 4),
            end: LocalTime(0, 15),
          ),
        ],
        note: null,
      ),
    );
    await tester.tap(find.text('Add break'));
    await tester.pump();
    await _pickStartDate(tester, const LocalDate(2026, 10, 10));
    expect(
      dateIn(tester, 'shift-break-start-date-0'),
      const LocalDate(2026, 10, 10),
    );
    expect(
      dateIn(tester, 'shift-break-end-date-0'),
      const LocalDate(2026, 10, 11),
    );
    expect(
      dateIn(tester, 'shift-break-start-date-1'),
      const LocalDate(2026, 10, 10),
    );
    expect(
      dateIn(tester, 'shift-break-end-date-1'),
      const LocalDate(2026, 10, 10),
    );

    // A picked break start date stays; its end date still follows it.
    await pickDate(
      tester,
      'shift-break-start-date-1',
      const LocalDate(2026, 10, 11),
    );
    expect(
      dateIn(tester, 'shift-break-end-date-1'),
      const LocalDate(2026, 10, 11),
    );
    await _pickStartDate(tester, const LocalDate(2026, 10, 12));
    expect(
      dateIn(tester, 'shift-break-start-date-1'),
      const LocalDate(2026, 10, 11),
    );
    expect(
      dateIn(tester, 'shift-break-start-date-0'),
      const LocalDate(2026, 10, 12),
    );

    // A picked break end date stays as its start date moves.
    await pickDate(
      tester,
      'shift-break-end-date-0',
      const LocalDate(2026, 10, 12),
    );
    await _pickStartDate(tester, const LocalDate(2026, 10, 14));
    expect(
      dateIn(tester, 'shift-break-start-date-0'),
      const LocalDate(2026, 10, 14),
    );
    expect(
      dateIn(tester, 'shift-break-end-date-0'),
      const LocalDate(2026, 10, 12),
    );
  });

  testWidgets('a revised draft saves untouched exactly as prefilled', (
    tester,
  ) async {
    const prefill = ShiftFormPrefill(
      startDate: LocalDate(2026, 10, 3),
      startTime: LocalTime(22, 0, 13),
      endDate: LocalDate(2026, 10, 4),
      endTime: LocalTime(6, 0),
      timezoneId: 'Europe/Vilnius',
      breaks: [
        ManualBreakDraft(
          startDate: LocalDate(2026, 10, 4),
          start: LocalTime(1, 0),
          endDate: LocalDate(2026, 10, 4),
          end: LocalTime(1, 30),
        ),
      ],
      note: 'Synthetic',
    );
    final submitted = await _pumpShift(tester, prefill: prefill);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.byKey(const ValueKey('shift-start-time')),
          matching: find.byType(EraTimeField),
        ),
        matching: find.byKey(const ValueKey('era-time-second')),
      ),
      findsOneWidget,
    );
    await _save(tester);
    final draft = submitted.single;
    expect(draft.localStartDate, prefill.startDate);
    expect(draft.localStartTime, const LocalTime(22, 0, 13));
    expect(draft.localEndDate, prefill.endDate);
    expect(draft.localEndTime, prefill.endTime);
    final pause = draft.breaks.single;
    expect(pause.startDate, const LocalDate(2026, 10, 4));
    expect(pause.start, const LocalTime(1, 0));
    expect(pause.endDate, const LocalDate(2026, 10, 4));
    expect(pause.end, const LocalTime(1, 30));
  });
}

/// Scrolls the form back to the top, where the start date box is, and
/// picks [date] there.
Future<void> _pickStartDate(WidgetTester tester, LocalDate date) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await pickDate(tester, 'shift-start-date', date);
}

Future<void> _save(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('save-manual-shift'));
  await tester.scrollUntilVisible(
    action,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  // Built is not on screen; bring it into view before tapping.
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

const employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const shiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
final testShift = WorkShift(
  id: shiftId,
  employmentId: employmentId,
  agreementId: agreementId,
  state: ShiftState.finalized,
  startUtc: DateTime.utc(2026, 10, 1, 8),
  endUtc: DateTime.utc(2026, 10, 1, 16),
  timezoneId: 'Europe/Amsterdam',
  localStartDate: const LocalDate(2026, 10, 1),
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 10, 1, 8),
  updatedAtUtc: DateTime.utc(2026, 10, 1, 16),
  revision: const Revision(1),
);

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildLifeOSTheme(),
    home: LifeOSSkinScope(
      child: Scaffold(body: SizedBox(width: 520, child: child)),
    ),
  );
}
