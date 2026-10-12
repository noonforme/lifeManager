import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

/// The shared editor contract (UI library phase 2a plan, "Editor contract"):
/// one caller-owned controller, one active field, synchronous flush to the
/// field's commit callback, cancel back to the entry value.

const _start = EditIdentity(record: 'shift:7', field: 'start');
const _end = EditIdentity(record: 'shift:7', field: 'end');

/// A pending record that accepts or rejects drafts, as a caller does.
final class _Pending {
  final values = <EditIdentity, Object?>{};
  final commits = <(EditIdentity, Object?)>[];

  /// Rejects a draft this returns a message for.
  String? Function(Object? draft)? reject;

  EditResult commit(EditIdentity id, Object? draft) {
    commits.add((id, draft));
    if (reject?.call(draft) case final message?) {
      return EditResult.rejected(message);
    }
    values[id] = draft;
    return const EditResult.accepted();
  }

  EditField text(EditIdentity id, String value) =>
      EditField(id: id, kind: ValueKind.text, value: value, commit: commit);
}

void main() {
  late EditorSessionController controller;
  late _Pending pending;
  late int notified;

  setUp(() {
    controller = EditorSessionController();
    pending = _Pending();
    notified = 0;
    controller.addListener(() => notified++);
  });

  tearDown(() => controller.dispose());

  group('identity', () {
    test('includes the record: the same field key of another record is '
        'another field', () {
      expect(_start, const EditIdentity(record: 'shift:7', field: 'start'));
      expect(
        _start,
        isNot(const EditIdentity(record: 'shift:8', field: 'start')),
      );
      expect(
        _start.hashCode,
        EditIdentity(record: 'shift:7', field: 'start').hashCode,
      );
    });
  });

  group('lifecycle', () {
    test('with no active field, flush succeeds without callbacks and cancel '
        'does nothing', () {
      expect(controller.flush().isAccepted, isTrue);
      controller.cancel();
      expect(pending.commits, isEmpty);
      expect(controller.session, isNull);
      expect(notified, 0);
    });

    test('begin opens one field with its entry value', () {
      expect(
        controller.begin(pending.text(_start, '07:00')).isAccepted,
        isTrue,
      );
      final session = controller.session!;
      expect(session.id, _start);
      expect(session.original, '07:00');
      expect(session.entry, '07:00');
      expect(session.draft, '07:00');
      expect(session.changed, isFalse);
      expect(controller.isActive(_start), isTrue);
      expect(controller.isActive(_end), isFalse);
      expect(notified, 1);
    });

    test('begin of the open field again is harmless and keeps its draft', () {
      controller.begin(pending.text(_start, 'a'));
      controller.update(_start, 'ab');
      expect(controller.begin(pending.text(_start, 'a')).isAccepted, isTrue);
      expect(controller.session!.draft, 'ab');
      expect(pending.commits, isEmpty);
    });

    test('an unchanged flush closes the field without a commit', () {
      controller.begin(pending.text(_start, 'Late'));
      controller.update(_start, 'Lat');
      controller.update(_start, 'Late');
      expect(controller.flush().isAccepted, isTrue);
      expect(pending.commits, isEmpty);
      expect(controller.session, isNull);
    });

    test('an accepted flush commits once and clears the field; a repeated '
        'flush is harmless', () {
      controller.begin(pending.text(_start, 'Late'));
      controller.update(_start, 'Early');
      expect(controller.flush().isAccepted, isTrue);
      expect(pending.commits, [(_start, 'Early')]);
      expect(pending.values[_start], 'Early');
      expect(controller.session, isNull);
      expect(controller.flush().isAccepted, isTrue);
      expect(controller.flush().isAccepted, isTrue);
      expect(pending.commits, hasLength(1));
    });

    test('a rejected flush keeps the draft and the error, and a corrected '
        'retry commits', () {
      pending.reject = (draft) =>
          int.tryParse('$draft') == null ? 'Enter a whole number.' : null;
      controller.begin(
        EditField(
          id: _start,
          kind: ValueKind.number,
          value: 3,
          commit: pending.commit,
        ),
      );
      expect(controller.session!.entry, '3', reason: 'number edits as text');
      controller.update(_start, '3x');
      final rejected = controller.flush();
      expect(rejected.isAccepted, isFalse);
      expect(rejected.error, 'Enter a whole number.');
      expect(controller.session!.id, _start);
      expect(controller.session!.draft, '3x', reason: 'invalid text retained');
      expect(controller.session!.error, 'Enter a whole number.');
      // Rejected again: nothing is remembered as done.
      expect(controller.flush().isAccepted, isFalse);
      controller.update(_start, '4');
      // Validation runs when the field is left: the reason stays until then.
      expect(controller.session!.error, 'Enter a whole number.');
      expect(controller.flush().isAccepted, isTrue);
      expect(pending.values[_start], '4');
      expect(pending.commits.map((c) => c.$2), ['3x', '3x', '4']);
    });

    test('begin flushes a different open field first and opens only after '
        'it is accepted', () {
      pending.reject = (draft) => draft == 'bad' ? 'No.' : null;
      controller.begin(pending.text(_start, 'a'));
      controller.update(_start, 'bad');
      final blocked = controller.begin(pending.text(_end, 'z'));
      expect(blocked.isAccepted, isFalse);
      expect(blocked.error, 'No.');
      expect(controller.session!.id, _start);
      expect(controller.session!.draft, 'bad');
      controller.update(_start, 'good');
      expect(controller.begin(pending.text(_end, 'z')).isAccepted, isTrue);
      expect(pending.values[_start], 'good');
      expect(controller.session!.id, _end);
    });

    test('cancel restores the entry value of this field only', () {
      controller.begin(pending.text(_start, 'a'));
      controller.update(_start, 'b');
      controller.flush();
      controller.begin(pending.text(_end, 'y'));
      controller.update(_end, 'zzz');
      controller.cancel();
      expect(controller.session, isNull);
      expect(pending.values, {_start: 'b'});
      expect(pending.commits, hasLength(1));
    });

    test('an update for a field that is not open is ignored', () {
      controller.begin(pending.text(_start, 'a'));
      final before = notified;
      controller.update(_end, 'stray');
      controller.update(
        const EditIdentity(record: 'shift:8', field: 'start'),
        'stray',
      );
      expect(controller.session!.draft, 'a');
      expect(notified, before);
    });

    test('a draft for a record that went away stays identifiable until the '
        'caller resolves it', () {
      controller.begin(pending.text(_start, 'a'));
      controller.update(_start, 'b');
      // The caller no longer has shift 7: its commit says so.
      pending.reject = (_) => 'This shift was removed.';
      expect(controller.flush().isAccepted, isFalse);
      expect(controller.session!.id.record, 'shift:7');
      expect(controller.session!.draft, 'b');
      controller.cancel();
      expect(controller.session, isNull);
    });

    test('a text draft keeps its selection and composition', () {
      controller.begin(pending.text(_start, 'Late'));
      const editing = TextEditingValue(
        text: 'Latek',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 4, end: 5),
      );
      controller.update(_start, 'Latek', editing: editing);
      expect(controller.session!.editing, editing);
    });

    test('a commit that flushes again does not commit twice', () {
      late EditResult inner;
      controller.begin(
        EditField(
          id: _start,
          kind: ValueKind.text,
          value: 'a',
          commit: (id, draft) {
            inner = controller.flush();
            pending.values[id] = draft;
            return const EditResult.accepted();
          },
        ),
      );
      controller.update(_start, 'b');
      expect(controller.flush().isAccepted, isTrue);
      expect(inner.isAccepted, isFalse);
      expect(controller.session, isNull);
    });
  });

  group('focus requests', () {
    test('a begin and a rejected flush each ask the open editor for focus '
        'once', () {
      pending.reject = (_) => 'No.';
      controller.begin(pending.text(_start, 'a'));
      expect(controller.takeFocusRequest(_end), isFalse);
      expect(controller.takeFocusRequest(_start), isTrue);
      expect(controller.takeFocusRequest(_start), isFalse);
      controller.update(_start, 'b');
      controller.flush();
      expect(controller.takeFocusRequest(_start), isTrue);
      expect(controller.takeFocusRequest(_start), isFalse);
      controller.requestFocus();
      expect(controller.takeFocusRequest(_start), isTrue);
    });

    test("only the opening host's editor answers, and the open field can "
        'move host', () {
      controller.begin(pending.text(_start, 'a'), host: 'grid');
      expect(controller.session!.host, 'grid');
      expect(controller.takeFocusRequest(_start, host: 'panel'), isFalse);
      expect(controller.takeFocusRequest(_start, host: 'grid'), isTrue);
      controller.update(_start, 'b');
      expect(
        controller.begin(pending.text(_start, 'a'), host: 'panel').isAccepted,
        isTrue,
      );
      expect(controller.session!.host, 'panel');
      expect(controller.session!.draft, 'b');
      expect(controller.takeFocusRequest(_start, host: 'panel'), isTrue);
    });
  });
}
