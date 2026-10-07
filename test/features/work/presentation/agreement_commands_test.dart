import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart'
    show AgreementUse;
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/agreement_dialogs.dart';
import 'package:lifeos/features/work/presentation/employment_agreement_forms.dart'
    show agreementUsersPaid;
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart'
    show CaptionBar, EraDialog;
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../../../support/era_pickers.dart';
import '../../../support/synthetic_shell.dart';
import '../../../support/work_dialogs.dart';
import '../../../support/work_sheets.dart';

Finder _link(String label) => find.widgetWithText(TaskLink, label);
Finder _key(String label) => find.widgetWithText(KeyButton, label);

TextField _rateField(WidgetTester tester) => tester.widget<TextField>(
  find.byKey(const ValueKey('agreement-hourly-rate')),
);

/// Types into the field and lets the sheet notice the change.
Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String tab) async {
  await tester.tap(
    find.descendant(
      of: find.byType(PropertySheetTabs),
      matching: find.text(tab),
    ),
  );
  await tester.pumpAndSettle();
}

/// What correcting v1 to EUR 20.00 reprices: its three finished shifts,
/// EUR 542.80 at 18.40 an hour, as the register estimates them.
const _repriced =
    '3 finished shifts are repriced: EUR 542.80 → EUR 590.00 (difference '
    'EUR +47.20).';

/// A key on the era dialog above the Properties, which has its own.
Finder _inDialog(String label) =>
    find.descendant(of: find.byType(EraDialog), matching: _key(label));

/// The open dialog, by the title on its caption bar.
Finder _caption(String title) => find.widgetWithText(CaptionBar, title);

/// The synthetic employment's agreement, v1 "Standard" from 2026-09-01,
/// is used by three finalized shifts, the last on 2026-09-09.
Future<void> _selectAgreement(WidgetTester tester, [String version = 'v1']) =>
    _tapRow(tester, version);

Future<void> _openAgreements(WidgetTester tester) async {
  await pumpSyntheticShell(
    tester,
    size: const Size(1280, 800),
    screen: syntheticScreens['shell']!,
  );
  await chooseSheet(tester, 'Agreements');
}

Future<void> _tapRow(WidgetTester tester, String version) async {
  await tester.tap(find.text(version).first);
  await tester.pumpAndSettle();
}

/// "Change terms from…" on v1, starting the new terms on [from].
Future<void> _changeTerms(WidgetTester tester, LocalDate from) async {
  await tester.tap(_link('Change terms from…'));
  await tester.pumpAndSettle();
  await pickDate(tester, 'agreement-change-from', from);
  await tester.enterText(
    find.byKey(const ValueKey('agreement-hourly-rate')),
    '20',
  );
  await tapInDialog(tester, _key('Change terms'));
}

void main() {
  testWidgets('an agreement in use offers Change terms and End, not Remove', (
    tester,
  ) async {
    await _openAgreements(tester);
    await _selectAgreement(tester);

    expect(_link('Change terms from…'), findsOneWidget);
    expect(_link('End agreement…'), findsOneWidget);
    expect(_link('Remove agreement…'), findsNothing);
    expect(_link('Properties'), findsOneWidget);
  });

  testWidgets('Change terms from… starts the next version on its date, after '
      'the last finished shift', (tester) async {
    await _openAgreements(tester);
    await _selectAgreement(tester);
    await tester.tap(_link('Change terms from…'));
    await tester.pumpAndSettle();
    expect(_caption('Change terms'), findsOneWidget);
    // The current terms are the starting point; From is today.
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('agreement-hourly-rate')),
          )
          .controller!
          .text,
      '18.40',
    );
    expect(
      dateIn(tester, 'agreement-change-from'),
      const LocalDate(2026, 10, 3),
    );

    await pickDate(
      tester,
      'agreement-change-from',
      const LocalDate(2026, 9, 9),
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-hourly-rate')),
      '20',
    );
    await tapInDialog(tester, _key('Change terms'));
    expect(
      find.text(
        'Finished shifts are paid under these terms on or after this day. '
        'Pick a later day.',
      ),
      findsOneWidget,
    );
    expect(find.text('Agreement changed.'), findsNothing);

    await pickDate(
      tester,
      'agreement-change-from',
      const LocalDate(2026, 10, 1),
    );
    await tapInDialog(tester, _key('Change terms'));

    expect(_caption('Change terms'), findsNothing);
    expect(find.text('Agreement changed.'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
    expect(find.text('2026-09-30'), findsOneWidget);
    expect(find.text('2026-10-01'), findsOneWidget);

    // The new version is unused: it is removed, not changed from a date.
    await _tapRow(tester, 'v2');
    expect(_link('Remove agreement…'), findsOneWidget);
    expect(_link('Change terms from…'), findsNothing);
    expect(_link('End agreement…'), findsOneWidget);

    // v1 has ended now: its end moves on its Properties, not by ending it
    // again.
    await _tapRow(tester, 'v1');
    expect(_link('End agreement…'), findsNothing);
    expect(_link('Change terms from…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_key('End agreement…'), findsNothing);
    expect(_key('Change terms from…'), findsOneWidget);
  });

  testWidgets('Remove agreement… asks, then removes an unused version', (
    tester,
  ) async {
    await _openAgreements(tester);
    await _selectAgreement(tester);
    await _changeTerms(tester, const LocalDate(2026, 10, 1));
    await _tapRow(tester, 'v2');

    await tester.tap(_link('Remove agreement…'));
    await tester.pumpAndSettle();
    expect(_caption('Remove agreement'), findsOneWidget);
    expect(find.text('Remove pay agreement v2?'), findsOneWidget);
    // The affirmative key comes first, then Cancel.
    expect(
      tester.getTopLeft(_key('Remove')).dx,
      lessThan(tester.getTopLeft(_key('Cancel')).dx),
    );

    await tester.tap(_key('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('v2'), findsOneWidget);

    await tester.tap(_link('Remove agreement…'));
    await tester.pumpAndSettle();
    await tester.tap(_key('Remove'));
    await tester.pumpAndSettle();

    expect(_caption('Remove agreement'), findsNothing);
    expect(find.text('Agreement removed.'), findsOneWidget);
    expect(find.text('v2'), findsNothing);
    expect(_link('Remove agreement…'), findsNothing);
  });

  testWidgets('End agreement… sets its last day, never before a used day', (
    tester,
  ) async {
    await _openAgreements(tester);
    await _selectAgreement(tester);
    await tester.tap(_link('End agreement…'));
    await tester.pumpAndSettle();
    expect(_caption('End agreement'), findsOneWidget);

    await pickDate(
      tester,
      'end-agreement-last-day',
      const LocalDate(2026, 9, 8),
    );
    await tester.tap(_key('End agreement'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Finished shifts are paid under this agreement after this day. '
        'Pick a later day.',
      ),
      findsOneWidget,
    );

    await pickDate(
      tester,
      'end-agreement-last-day',
      const LocalDate(2026, 8, 31),
    );
    await tester.tap(_key('End agreement'));
    await tester.pumpAndSettle();
    expect(
      find.text('The last day must be on or after its start, 2026-09-01.'),
      findsOneWidget,
    );

    await pickDate(
      tester,
      'end-agreement-last-day',
      const LocalDate(2026, 9, 30),
    );
    await tester.tap(_key('End agreement'));
    await tester.pumpAndSettle();
    expect(_caption('End agreement'), findsNothing);
    expect(find.text('Agreement ended.'), findsOneWidget);
    expect(find.text('2026-09-30'), findsOneWidget);
  });

  testWidgets('an agreement in use is corrected on its Properties: a typo '
      'saves, a change to pay asks first', (tester) async {
    await _openAgreements(tester);
    await _selectAgreement(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Used by 3 finished shifts. Corrections reprice them; for new terms '
        'from a date use Change terms from…',
      ),
      findsOneWidget,
    );
    expect(_rateField(tester).enabled, isTrue);
    expect(_key('Change terms from…'), findsOneWidget);
    expect(_key('End agreement…'), findsOneWidget);
    expect(_key('Remove agreement…'), findsNothing);

    // The label pays nothing: it saves without asking.
    await _openTab(tester, 'Notes');
    await _type(tester, 'agreement-label', 'Standard depot');
    await tester.tap(_key('Apply'));
    await tester.pumpAndSettle();
    expect(_caption('Correct agreement'), findsNothing);
    expect(find.text('Pay agreement saved.'), findsOneWidget);

    await _openTab(tester, 'Rate');
    await _type(tester, 'agreement-hourly-rate', '20');
    await tester.tap(_key('Apply'));
    await tester.pumpAndSettle();
    expect(_caption('Correct agreement'), findsOneWidget);
    expect(find.text('Correct pay agreement v1?'), findsOneWidget);
    expect(find.text(_repriced), findsOneWidget);
    // Its September period is open and has no payslip.
    expect(find.textContaining('reviewed pay period'), findsNothing);

    await tester.tap(_inDialog('Cancel'));
    await tester.pumpAndSettle();
    expect(_caption('Correct agreement'), findsNothing);
    expect(find.text('Agreement corrected.'), findsNothing);
    await tester.tap(_key('Cancel'));
    await tester.pumpAndSettle();
    // Nothing was saved: the Properties open on the stored rate.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_rateField(tester).controller!.text, '18.40');

    await _type(tester, 'agreement-hourly-rate', '20');
    await tester.tap(_key('Apply'));
    await tester.pumpAndSettle();
    await tester.tap(_inDialog('Correct'));
    await tester.pumpAndSettle();
    expect(_caption('Correct agreement'), findsNothing);
    expect(find.text('Agreement corrected.'), findsOneWidget);
    expect(_rateField(tester).controller!.text, '20.00');

    // Starting after a day it paid would drop it; the field says which.
    await pickDate(
      tester,
      'agreement-effective-start',
      const LocalDate(2026, 9, 8),
    );
    await tester.tap(_key('Apply'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Used by finished shifts on 2026-09-07, so it must start on or '
        'before that day.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Change terms from… still sets new terms on a corrected '
      'agreement', (tester) async {
    await _openAgreements(tester);
    await _selectAgreement(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await _openTab(tester, 'Notes');
    await _type(tester, 'agreement-label', 'Standard depot');
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();

    await _changeTerms(tester, const LocalDate(2026, 10, 1));

    expect(find.text('Agreement changed.'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
  });

  testWidgets('Change terms from… opens from the Properties, and Cancel goes '
      'back to them', (tester) async {
    await _openAgreements(tester);
    await _selectAgreement(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tapInDialog(tester, _key('Change terms from…'));
    expect(_caption('Change terms'), findsOneWidget);

    await tapInDialog(tester, _key('Cancel'));
    expect(_caption('Change terms'), findsNothing);
    expect(_caption('Pay agreement Properties'), findsOneWidget);
  });

  testWidgets('a removal the state overtook says why and stays open', (
    tester,
  ) async {
    final outcomes = <MutationOutcome<PayAgreement>>[
      const Invalid<PayAgreement>({
        'agreement.inUse': [FieldIssue(FieldIssueCode.conflict)],
      }),
      const Missing<PayAgreement>(),
    ];
    await _openDialog(
      tester,
      (context) => askRemoveAgreement(
        context,
        agreement: _agreement,
        onRemove: () async => outcomes.removeAt(0),
      ),
    );

    await tester.tap(_key('Remove'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Finished shifts or confirmed leave now use this agreement, so it '
        "can't be removed.",
      ),
      findsOneWidget,
    );
    expect(_caption('Remove agreement'), findsOneWidget);

    await tester.tap(_key('Remove'));
    await tester.pumpAndSettle();
    expect(
      find.text('This agreement is no longer available. Reload the register.'),
      findsOneWidget,
    );
  });

  testWidgets('End agreement… names confirmed leave when only leave uses it', (
    tester,
  ) async {
    await _openDialog(
      tester,
      (context) => askEndAgreement(
        context,
        agreement: _agreement,
        today: const LocalDate(2026, 10, 3),
        usedBy: AgreementUse.leave,
        onEnd: (_) async => const Invalid<PayAgreement>({
          'effectiveEnd': [FieldIssue(FieldIssueCode.conflict)],
        }),
      ),
    );

    await tester.tap(_key('End agreement'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Confirmed leave is paid under this agreement after this day. Pick '
        'a later day.',
      ),
      findsOneWidget,
    );
  });

  test('refusals name who the agreement pays', () {
    expect(
      agreementUsersPaid(AgreementUse.both),
      'Finished shifts and confirmed leave are paid',
    );
    expect(agreementUsersPaid(AgreementUse.shifts), 'Finished shifts are paid');
    expect(
      agreementUsersPaid(null),
      'Finished shifts or confirmed leave are paid',
    );
  });

  test('a committed outcome is never explained as a problem', () {
    expect(() => agreementProblem(Committed(_agreement)), throwsStateError);
    expect(
      agreementProblem(
        const Unavailable<PayAgreement>(SafeFailureCode.storageUnavailable),
      ),
      'Local storage is unavailable. Nothing was changed.',
    );
  });

  testWidgets('End agreement… shows an overlap on its field', (tester) async {
    await _openDialog(
      tester,
      (context) => askEndAgreement(
        context,
        agreement: _agreement,
        today: const LocalDate(2026, 10, 3),
        onEnd: (_) async => const Invalid<PayAgreement>({
          'effectiveRange': [FieldIssue(FieldIssueCode.conflict)],
        }),
      ),
    );

    await tester.tap(_key('End agreement'));
    await tester.pumpAndSettle();
    expect(find.text('These dates overlap another agreement.'), findsOneWidget);
    expect(_caption('End agreement'), findsOneWidget);
  });
}

Future<void> _openDialog(
  WidgetTester tester,
  Future<bool> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

final _agreement = PayAgreement(
  id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  version: 2,
  effectiveStart: const LocalDate(2026, 9, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 18400000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026, 9, 1),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);
