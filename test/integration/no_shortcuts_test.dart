import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell.dart';
import 'package:lifeos/ui/ui.dart';

import '../support/app_frame_harness.dart' show click;
import '../support/shifts_sheet_driver.dart';

/// The old shell's command keys: Back and Forward, menus by letter, the
/// Address list, the row menu and Save. The keyboard only enters data
/// (umbrella spec 4.6), so none of them does anything in the Work shell.
const _oldCommandKeys = <List<LogicalKeyboardKey>>[
  [LogicalKeyboardKey.altLeft, LogicalKeyboardKey.arrowLeft],
  [LogicalKeyboardKey.altLeft, LogicalKeyboardKey.arrowRight],
  [LogicalKeyboardKey.altLeft, LogicalKeyboardKey.home],
  [LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyF],
  [LogicalKeyboardKey.f4],
  [LogicalKeyboardKey.f10],
  [LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.f10],
  [LogicalKeyboardKey.contextMenu],
  [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyS],
  [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyF],
];

void main() {
  testWidgets('no command key moves, opens a menu or saves', (tester) async {
    await pumpShiftsSheet(tester);
    final shell = shellOf(tester);
    await click(
      tester,
      find.descendant(of: find.byType(TreeView), matching: find.text('Work')),
    );
    await settleSheet(tester);
    expect(shell.location, const WorkLocation.overview());
    expect(shell.canBack, isTrue);

    for (final keys in _oldCommandKeys) {
      for (final key in keys) {
        await tester.sendKeyDownEvent(key);
      }
      for (final key in keys.reversed) {
        await tester.sendKeyUpEvent(key);
      }
      await settleSheet(tester);
      expect(shell.location, const WorkLocation.overview(), reason: '$keys');
      expect(shell.canForward, isFalse, reason: '$keys');
      expect(
        find.text(WorkShellWords.newEmployment),
        findsNothing,
        reason: '$keys opened the File menu',
      );
      expect(find.byType(ConfirmWindow), findsNothing, reason: '$keys');
    }
  });
}
