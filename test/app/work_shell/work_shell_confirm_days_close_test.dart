import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_shell/confirm_days_action.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/manual_shift_service.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart' show click, toolbarKey;
import '../../support/shifts_sheet_driver.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_driver.dart';

/// The first finalize fails as storage would, the third waits for [gate],
/// and with [lose] set every one after the first is written and then its
/// answer is lost.
final class _Scripted implements ManualShiftRepository {
  _Scripted(this.inner, {this.lose = false});

  final ManualShiftRepository inner;
  final bool lose;
  final gate = Completer<void>();
  bool gated = false;
  int calls = 0;

  @override
  Future<MutationOutcome<WorkShift>> createAndFinalizeManual(
    WorkShift draft,
    List<ShiftBreak> breaks,
  ) async {
    calls++;
    if (lose) {
      await inner.createAndFinalizeManual(draft, breaks);
      throw StateError('The answer was lost.');
    }
    if (calls == 1) {
      return const Unavailable(SafeFailureCode.storageUnavailable);
    }
    if (gated && calls == 3) await gate.future;
    return inner.createAndFinalizeManual(draft, breaks);
  }
}

ProductionWorkProviders Function(ShiftsSheetFixture) _over(
  _Scripted Function(ManualShiftRepository inner) make,
) => (fixture) {
  final plans = fixture.work.plans;
  return fixture.work.replacing(
    plans: DayPlanService(
      repository: plans.repository,
      shifts: make(plans.shifts),
      ids: plans.ids,
      clock: plans.clock,
      zoneClocks: plans.zoneClocks,
    ),
  );
};

final _window = find.byWidgetPredicate((widget) => widget is ConfirmWindow);

Finder _windowKey(String label) =>
    find.descendant(of: _window, matching: find.text(label));

Future<void> _pressClose(WidgetTester tester, FakeWindowClose window) async {
  unawaited(window.pressClose());
  await settleSheet(tester);
}

/// Opens Confirm worked days from Shifts and confirms every day.
Future<void> _confirmAll(WidgetTester tester) async {
  await click(tester, toolbarKey('Confirm worked days…'));
  await settleSheet(tester);
  await click(tester, find.widgetWithText(KeyButton, 'Confirm 9 days'));
  await settleSheet(tester);
  await click(tester, _windowKey('Confirm 9 days'));
  await settleSheet(tester);
}

/// Quitting during and after Confirm worked days (plan 4d-2, Task 7;
/// umbrella 4.8).
void main() {
  testWidgets('closing during a bulk run waits for it, then asks about the '
      'results', (tester) async {
    final window = FakeWindowClose();
    late _Scripted scripted;
    await pumpShiftsSheet(
      tester,
      closeApi: window,
      work: _over((inner) => scripted = _Scripted(inner)..gated = true),
    );
    await _confirmAll(tester);
    expect(scripted.calls, 3, reason: 'the third day waits');
    await _pressClose(tester, window);
    expect(window.destroyed, 0);
    expect(_window, findsNothing, reason: 'the run is still going');
    scripted.gate.complete();
    await settleSheet(tester);
    expect(_windowKey(ConfirmDaysWords.closeLeft(8, 1)), findsOneWidget);
    await click(tester, _windowKey('Keep open'));
    await settleSheet(tester);
    expect(window.destroyed, 0);
    expect(find.byType(ActionPanel), findsOneWidget);
  });

  testWidgets('closing with a day not known offers Reload and check', (
    tester,
  ) async {
    final window = FakeWindowClose();
    await pumpShiftsSheet(
      tester,
      closeApi: window,
      work: _over((inner) => _Scripted(inner, lose: true)),
    );
    await _confirmAll(tester);
    expect(sheetOf(tester).confirmDays!.hasUnknown, isTrue);
    await _pressClose(tester, window);
    expect(_windowKey(uncheckedQuitRequest.message), findsOneWidget);
    await click(tester, _windowKey('Keep editing'));
    await settleSheet(tester);
    expect(window.destroyed, 0);
    expect(find.byType(ActionPanel), findsOneWidget);
  });

  testWidgets('closing with changed ticks asks Discard input and quit', (
    tester,
  ) async {
    final window = FakeWindowClose();
    await pumpShiftsSheet(tester, closeApi: window);
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    await click(tester, find.text('Tue 2026-10-06').first);
    await settleSheet(tester);
    await _pressClose(tester, window);
    expect(_windowKey(ConfirmDaysWords.discardTicks), findsOneWidget);
    await click(tester, _windowKey('Keep editing'));
    await settleSheet(tester);
    expect(window.destroyed, 0);
    await _pressClose(tester, window);
    await click(tester, _windowKey('Discard input and quit'));
    await settleSheet(tester);
    expect(window.destroyed, 1);
  });
}
