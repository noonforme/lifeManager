import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/shift_edit.dart';
import 'package:lifeos/app/work_shell/confirm_in_window.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

void main() {
  /// Asks [request] from a pumped page; the answer lands in [answers].
  Future<List<ConfirmAnswer>> ask(
    WidgetTester tester,
    ConfirmRequest request,
  ) async {
    final answers = <ConfirmAnswer>[];
    await tester.pumpWidget(
      GalleryHost(
        home: Builder(
          builder: (context) => KeyButton(
            label: 'Ask',
            onPressed: () async =>
                answers.add(await confirmInWindow(context, request)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    return answers;
  }

  List<String> keys(WidgetTester tester) => [
    for (final key in tester.widgetList<KeyButton>(
      find.descendant(
        of: find.byType(ConfirmWindow<ConfirmAnswer>),
        matching: find.byType(KeyButton),
      ),
    ))
      key.label,
  ];

  testWidgets('the affirmative key comes first, then the drop, then the stay', (
    tester,
  ) async {
    final answers = await ask(tester, finalizeRequest(isNew: true));
    expect(find.text('Finalize shift'), findsOneWidget);
    expect(keys(tester), ['Save and finalize', 'Discard', 'Cancel']);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(answers, [ConfirmAnswer.revert]);
  });

  testWidgets('a request without an affirmative key offers only the others', (
    tester,
  ) async {
    await ask(
      tester,
      const ConfirmRequest(
        title: 'Pending values',
        message: 'Discard them and quit?',
        proceed: null,
        revert: 'Discard and quit',
        cancel: 'Keep editing',
      ),
    );
    expect(keys(tester), ['Discard and quit', 'Keep editing']);
  });

  testWidgets('the close key answers Cancel', (tester) async {
    final answers = await ask(tester, newRecordRequest);
    await tester.tap(find.bySemanticsLabel('Close ${newRecordRequest.title}'));
    await tester.pumpAndSettle();
    expect(answers, [ConfirmAnswer.cancel]);
  });
}
