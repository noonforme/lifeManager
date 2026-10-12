import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A key a hosted control hands to its editor host (database shell spec
/// 4.6). Only a plain press is one: with Shift, Ctrl, Alt or Meta held the
/// key does nothing, so a modified Enter or Tab never commits by accident.
enum EraEditorKey {
  /// Enter or numpad Enter: commit the value and open the next field.
  enter,

  /// Tab: as Enter. Shift+Tab is not one; it does nothing.
  tab,

  /// Esc: throw away the value being typed and close the editor.
  escape,
}

/// Opts the era controls below it into the database shell's keyboard
/// policy (spec 4.6) and, when [bare], drops their separate "Label:".
///
/// Inside the scope the shared controls ([EraDateField], [EraTimeField],
/// [EraMonthCalendar], [EraCombo], [EraCheckBox], [EraRadio],
/// [EraRadioGroup] and [EraField]) take from the keyboard only data entry:
/// typing, Backspace/Delete and Left/Right in a text field; digits,
/// separators, Left/Right parts and Up/Down part steps in a date or time
/// box. A plain Enter, Tab or Esc press goes to [onKey]; every other key is
/// held by the control, so no traversal, activation, menu or shortcut runs.
/// Calendars and combo lists open and operate by mouse only. While one is
/// open, Enter, Tab and Esc close it without taking its lit day or row,
/// then reach [onKey]; focus stays on the box, which is the editor.
///
/// The scope is opt-in: outside it every control keeps its legacy keys
/// and layout. It does not by itself make a form an editor sequence;
/// committing, advancing and cancelling are the host's work in [onKey].
final class EraEditorHostScope extends InheritedWidget {
  const EraEditorHostScope({
    required super.child,
    this.bare = false,
    this.onKey,
    super.key,
  });

  /// Drops the "Label:" an [EraLabelled] row would show, and the row's
  /// spacing, for an editor inside a grid or property cell. The field
  /// keeps its semantic name, error, enabled state and kind width.
  final bool bare;

  /// Told of each plain Enter, Tab or Esc press (not a key repeat) inside a
  /// hosted control, including while its calendar or list is open. The
  /// control has already held the key; the host commits, advances or
  /// cancels. Null holds those keys too.
  final ValueChanged<EraEditorKey>? onKey;

  /// The nearest scope, without making [context] depend on it: for key and
  /// pointer handlers, which read the current [onKey] when they run.
  static EraEditorHostScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EraEditorHostScope>();

  /// The nearest scope, rebuilding [context] when its [bare] changes: for
  /// build methods choosing labels, layout and focusability.
  static EraEditorHostScope? watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EraEditorHostScope>();

  /// Whether fields under [context] drop their labels; depends on the
  /// scope.
  static bool bareOf(BuildContext context) => watch(context)?.bare ?? false;

  /// The host key [event] is: a plain press of Enter, numpad Enter, Tab or
  /// Esc. Null for anything else, including a repeat or a modified press.
  static EraEditorKey? editorKeyOf(KeyEvent event) {
    if (event is! KeyDownEvent || _modified) return null;
    return switch (event.logicalKey) {
      LogicalKeyboardKey.enter ||
      LogicalKeyboardKey.numpadEnter => EraEditorKey.enter,
      LogicalKeyboardKey.tab => EraEditorKey.tab,
      LogicalKeyboardKey.escape => EraEditorKey.escape,
      _ => null,
    };
  }

  /// The scope's last word on [event] for a hosted control whose own data
  /// entry declined it: hands a host key ([editorKeyOf]) to the nearest
  /// scope's [onKey] and holds every other key down or repeat, so nothing
  /// above the control acts on it. Key releases and modifier keys alone
  /// pass, as they act on nothing.
  static KeyEventResult handleKey(BuildContext context, KeyEvent event) {
    if (event is KeyUpEvent || _modifierKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (editorKeyOf(event) case final key?) maybeOf(context)?.onKey?.call(key);
    return KeyEventResult.handled;
  }

  static bool get _modified {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed;
  }

  static final _modifierKeys = {
    ...LogicalKeyboardKey.expandSynonyms({
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.meta,
    }),
    LogicalKeyboardKey.altGraph,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.numLock,
    LogicalKeyboardKey.fn,
  };

  @override
  bool updateShouldNotify(EraEditorHostScope oldWidget) =>
      bare != oldWidget.bare;
}
