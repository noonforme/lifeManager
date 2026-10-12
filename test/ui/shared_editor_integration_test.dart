import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import '../support/shell_editor_fixture.dart';

Future<ShellEditorFixtureState> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = EditorSessionController();
  addTearDown(controller.dispose);
  final key = GlobalKey<ShellEditorFixtureState>();
  await tester.pumpWidget(
    GalleryHost(
      home: ShellEditorFixture(key: key, controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

Finder _grid(String field) => find.byKey(ValueKey('grid-cell:row:0:$field'));
Finder _property(String field) => find.byKey(ValueKey('property-value:$field'));

void main() {
  testWidgets(
    'grid and properties show one draft; first Save commits before the command',
    (tester) async {
      final host = await _pump(tester);
      await _tap(tester, _grid('note'));
      tester.testTextInput.enterText('Shared raw draft');
      await tester.pumpAndSettle();
      expect(host.values['note'], 'Note 0');
      expect(host.controller.session!.draft, 'Shared raw draft');
      final editors = tester
          .widgetList<CellEditor>(find.byType(CellEditor))
          .where((editor) => editor.field.id == host.controller.active)
          .toList();
      expect(
        editors,
        hasLength(2),
        reason: 'one grid editor and one property mirror',
      );
      expect(
        editors.map((editor) => editor.controller),
        everyElement(same(host.controller)),
      );
      final gridText = tester.widget<EditableText>(
        find.descendant(of: _grid('note'), matching: find.byType(EditableText)),
      );
      final propertyText = tester.widget<EditableText>(
        find.descendant(
          of: _property('note'),
          matching: find.byType(EditableText),
        ),
      );
      expect(gridText.controller.text, 'Shared raw draft');
      expect(propertyText.controller.text, 'Shared raw draft');
      expect(gridText.focusNode.hasFocus, isTrue);
      expect(propertyText.focusNode.hasFocus, isFalse);
      await _tap(tester, find.text('Save'));
      expect(host.values['note'], 'Shared raw draft');
      expect(host.events, ['commit:row:0:note', 'save']);
      expect(host.controller.session, isNull);
    },
  );

  testWidgets(
    'rejected draft blocks Save, panel primary, tree, area, subform and row requests',
    (tester) async {
      final host = await _pump(tester);
      await _tap(tester, _property('note'));
      tester.testTextInput.enterText('');
      await tester.pump();
      final identity = host.controller.active;
      for (final target in [
        find.text('Save'),
        find.text('Correct'),
        find.text('Pay periods'),
        find.text('People'),
        find.text('History'),
        find.byKey(const ValueKey('grid-selector:row:1')),
      ]) {
        await _tap(tester, target);
        expect(host.controller.active, identity);
        expect(host.controller.session!.draft, '');
        expect(host.controller.session!.error, 'Enter a value.');
      }
      expect(host.events, everyElement('reject:row:0:note'));
      expect(host.selected, 'row:0');
      expect(host.treeSelection, 'shifts');
      expect(host.area, 'work');
      expect(host.tab, 'children');
      tester.testTextInput.enterText('Corrected');
      await tester.pump();
      await _tap(tester, find.text('Save'));
      expect(host.events.sublist(host.events.length - 2), [
        'commit:row:0:note',
        'save',
      ]);
      expect(host.values['note'], 'Corrected');
    },
  );

  testWidgets('panel primary flushes another host before running its command', (
    tester,
  ) async {
    final host = await _pump(tester);
    await _tap(tester, _grid('note'));
    tester.testTextInput.enterText('Before panel command');
    await tester.pump();
    await _tap(tester, find.text('Correct'));
    expect(host.events, ['commit:row:0:note', 'primary']);
    expect(host.values['note'], 'Before panel command');
    expect(host.controller.session, isNull);
  });

  testWidgets('selecting another record flushes to the original identity', (
    tester,
  ) async {
    final host = await _pump(tester);
    await _tap(tester, _grid('note'));
    tester.testTextInput.enterText('For record zero');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('grid-selector:row:1')));
    expect(host.events, ['commit:row:0:note', 'select:row:1']);
    expect(host.selected, 'row:1');
    expect(host.records['row:0']!['note'], 'For record zero');
    expect(host.records['row:1']!['note'], 'Note 1');
    expect(host.controller.session, isNull);
  });

  testWidgets(
    'accepted draft reaches tree, area and subform callbacks before navigation',
    (tester) async {
      final host = await _pump(tester);
      for (final (target, command) in [
        (find.text('Pay periods'), 'tree:periods'),
        (find.text('People'), 'area:people'),
        (find.text('History'), 'subform:history'),
      ]) {
        await _tap(tester, _property('note'));
        tester.testTextInput.enterText('Before $command');
        await tester.pump();
        await _tap(tester, target);
        expect(host.events.sublist(host.events.length - 2), [
          'commit:row:0:note',
          command,
        ]);
        expect(host.values['note'], 'Before $command');
        expect(host.controller.session, isNull);
      }
      expect(host.treeSelection, 'periods');
      expect(host.area, 'people');
      expect(host.tab, 'history');
    },
  );

  testWidgets(
    'panel Cancel preserves another host draft; Undo explicitly discards it',
    (tester) async {
      final host = await _pump(tester);
      await _tap(tester, _property('note'));
      tester.testTextInput.enterText('Unaccepted grid record draft');
      await tester.pump();
      await _tap(tester, find.text('Cancel'));
      expect(host.events, ['cancel']);
      expect(host.controller.session!.draft, 'Unaccepted grid record draft');
      expect(host.controller.active!.record, 'row:0');
      await _tap(tester, find.text('Undo'));
      expect(host.events, ['cancel', 'undo']);
      expect(host.controller.session, isNull);
      expect(host.values['note'], 'Note 0');
    },
  );
}
