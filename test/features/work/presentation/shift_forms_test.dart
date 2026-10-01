import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/shift_forms.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  testWidgets('manual overnight entry submits explicit local facts', (
    tester,
  ) async {
    ManualShiftDraft? submitted;
    await tester.pumpWidget(
      _TestApp(
        child: ShiftEditInspector(
          employmentId: employmentId,
          onSubmit: (draft) async {
            submitted = draft;
            return Committed(testShift);
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('shift-start-date')),
      '2026-10-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-start-time')),
      '22:30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-end-date')),
      '2026-10-02',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-end-time')),
      '06:15',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-timezone')),
      'Europe/Amsterdam',
    );
    await tester.enterText(find.byKey(const ValueKey('shift-overtime')), '30');
    await tester.enterText(
      find.byKey(const ValueKey('shift-note')),
      'Night coverage',
    );
    await tester.tap(find.text('Add break'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('shift-break-start-date-0')),
      '2026-10-02',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-break-start-0')),
      '01:00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-break-end-date-0')),
      '2026-10-02',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-break-end-0')),
      '01:20',
    );
    await _save(tester);

    expect(submitted?.localStartDate.toString(), '2026-10-01');
    expect(submitted?.localStartTime.toString(), '22:30:00');
    expect(submitted?.localEndDate.toString(), '2026-10-02');
    expect(submitted?.localEndTime.toString(), '06:15:00');
    expect(submitted?.timezoneId, 'Europe/Amsterdam');
    expect(submitted?.overtimeMinutes, 30);
    expect(submitted?.note, 'Night coverage');
    expect(submitted?.breaks.single.startDate.toString(), '2026-10-02');
    expect(submitted?.breaks.single.start.toString(), '01:00:00');
    expect(submitted?.breaks.single.endDate.toString(), '2026-10-02');
    expect(submitted?.breaks.single.end.toString(), '01:20:00');
  });

  testWidgets('validation preserves timezone note and manual draft fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: ShiftEditInspector(
          employmentId: employmentId,
          onSubmit: (_) async => const Invalid<WorkShift>({
            'localTime': [FieldIssue(FieldIssueCode.invalid)],
          }),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('shift-start-date')),
      '2026-10-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-start-time')),
      '09:00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-end-date')),
      '2026-10-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shift-end-time')),
      '17:00',
    );
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

  testWidgets('entered overtime remains distinct from threshold suggestion', (
    tester,
  ) async {
    var submitted = -1;
    await tester.pumpWidget(
      _TestApp(
        child: OvertimeConfirmationInspector(
          shift: testShift,
          suggestedOvertimeMinutes: 42,
          enteredOvertimeMinutes: 0,
          onFinalize: (minutes) async {
            submitted = minutes;
            return Committed(testShift);
          },
        ),
      ),
    );

    expect(
      find.text('Suggested from the agreement threshold: 42 minutes.'),
      findsOneWidget,
    );
    expect(find.text('0'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('shift-final-overtime')),
      '15',
    );
    expect(
      find.text('Suggested from the agreement threshold: 42 minutes.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm finalization'));
    await tester.pumpAndSettle();

    expect(submitted, 15);
  });
}

Future<void> _save(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('save-manual-shift'));
  await tester.scrollUntilVisible(
    action,
    240,
    scrollable: find.byType(Scrollable).first,
  );
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
  overtimeMinutes: 0,
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
    theme: buildLifeOSTheme(highContrast: false),
    home: Scaffold(body: SizedBox(width: 520, height: 760, child: child)),
  );
}
