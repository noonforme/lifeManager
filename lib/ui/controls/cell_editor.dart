import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import 'editor_session_controller.dart';
import 'era_combo.dart';
import 'era_editor_host.dart';
import 'era_form.dart';
import 'value_editor.dart';

/// One field's era editor under the shared [EditorSessionController]: the
/// editor of a grid or property cell ([bare]) or of a labelled action-panel
/// row. It applies the database shell keyboard (spec 4.6) through an
/// [EraEditorHostScope]:
///
/// - Enter or Tab flushes the field; only when the draft is accepted does
///   [next] name the next eligible field of the same record, which opens
///   and takes the keyboard, scrolled into view. With no next field the
///   editor closes. Nothing wraps or traverses to another region.
/// - Esc cancels this field only, back to its entry value.
/// - A rejected draft stays in the editor, red, with its reason, and the
///   editor keeps the keyboard.
///
/// The draft lives in the controller, so a recycled cell remounts with it.
/// While [field] is the open field the editor shows the draft; otherwise it
/// shows [EditField.value], and a primary click on it, typing into it or a
/// mouse change of its value opens the field first
/// ([EditorSessionController.begin]). Focus arriving by itself (requested
/// by code, restored, or a pane reparented) never opens a field or flushes
/// another. When another field's draft is rejected, the click does nothing
/// to this editor and the keyboard goes back to the rejected one.
final class CellEditor extends StatefulWidget {
  const CellEditor({
    required this.controller,
    required this.field,
    required this.label,
    this.bare = true,
    this.host,
    this.next,
    this.choices = const [],
    this.today,
    this.optional = false,
    this.enabled = true,
    this.error,
    this.fieldKey,
    super.key,
  });

  final EditorSessionController controller;

  /// The field edited: identity, kind, the caller's value and its commit.
  final EditField field;

  /// The semantic name, and the "Label:" of a labelled row.
  final String label;

  /// True in a grid or property cell (no "Label:"); false in a labelled
  /// form row.
  final bool bare;

  /// The region this editor belongs to: the token its host passes to
  /// [EditorSessionController.begin]. Of several editors of one field (a
  /// grid cell and its property row), only the host's takes the keyboard
  /// when the field opens there, and the next field opens in the same host.
  final Object? host;

  /// The next eligible field of the same record after this one, skipping
  /// derived, read-only and disabled fields (checks and choices count), or
  /// null at the last. It must name a field whose editor is mounted, or
  /// mounted by the host when the field opens, in this same [host]: that
  /// editor takes the keyboard (a debug build reports it otherwise). Called
  /// right after this field's draft is accepted, so build it from the
  /// caller's current pending values.
  final EditField? Function()? next;

  /// The choices of a [ValueKind.choice] field.
  final List<EraComboItem<Object?>> choices;

  /// Today for a date's calendar: explicit and fixed, never the wall
  /// clock. Required for [ValueKind.date].
  final LocalDate? today;

  /// A date that may be empty.
  final bool optional;

  /// False for a disabled or read-only field: greyed and locked; it never
  /// opens.
  final bool enabled;

  /// An error of the caller's, shown while no rejected draft has one.
  final String? error;

  /// The key of the editor's box, which tests and forms address.
  final Key? fieldKey;

  @override
  State<CellEditor> createState() => _CellEditorState();
}

final class _CellEditorState extends State<CellEditor> {
  final _node = FocusNode(debugLabel: 'CellEditor');
  TextEditingController? _text;
  bool _active = false;

  /// Set while the text is set from the controller rather than typed.
  bool _syncing = false;

  /// The surrounding form's enabled state, as last built.
  bool _formEnabled = true;

  EditorSessionController get _controller => widget.controller;
  EditIdentity get _id => widget.field.id;
  bool get _eligible => widget.enabled && _formEnabled;

  @override
  void initState() {
    super.initState();
    _active = _controller.isActive(_id);
    _controller.addListener(_onSession);
    _resetText();
    WidgetsBinding.instance.addPostFrameCallback((_) => _answerFocus());
  }

  @override
  void didUpdateWidget(CellEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSession);
      widget.controller.addListener(_onSession);
    }
    final active = _controller.isActive(_id);
    // Another field, another kind, or a new value of a closed field: show
    // what is current. Typing into the open field is never overwritten.
    if (oldWidget.field.id != _id ||
        oldWidget.field.kind != widget.field.kind ||
        active != _active ||
        (!active && oldWidget.field.entry != widget.field.entry)) {
      _active = active;
      _resetText();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onSession);
    _node.dispose();
    _text?.dispose();
    super.dispose();
  }

  /// The text editor's value: the open draft with its selection, or the
  /// field's entry text. A composition does not survive a remount.
  TextEditingValue _textValue() {
    final session = _controller.session;
    if (session != null && session.id == _id) {
      final editing = session.editing;
      if (editing != null && editing.text == session.draft) {
        return editing.copyWith(composing: TextRange.empty);
      }
      return _collapsed('${session.draft ?? ''}');
    }
    return _collapsed('${widget.field.entry ?? ''}');
  }

  static TextEditingValue _collapsed(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  void _resetText() {
    if (!widget.field.kind.typedAsText) {
      _text?.dispose();
      _text = null;
      return;
    }
    final text = _text ??= TextEditingController()..addListener(_onText);
    _syncing = true;
    text.value = _textValue();
    _syncing = false;
  }

  void _onText() {
    final text = _text;
    if (_syncing || text == null) return;
    final value = text.value;
    if (!_controller.isActive(_id)) {
      if (value.text == '${widget.field.entry ?? ''}') return;
      if (!_open()) {
        _resetText();
        return;
      }
    }
    _controller.update(_id, value.text, editing: value);
  }

  void _onSession() {
    if (!mounted) return;
    final active = _controller.isActive(_id);
    // Another editor of this field (a grid cell and its property row)
    // typed the draft: show it. This editor's own typing already matches.
    final typedElsewhere =
        active && _text != null && _text!.text != _controller.session!.draft;
    if (active != _active || typedElsewhere) {
      _active = active;
      _resetText();
    }
    setState(() {});
    _answerFocus();
  }

  /// Takes the keyboard when the controller asks this editor for it: once
  /// laid out, scrolled into view.
  void _answerFocus() {
    if (!mounted || !_controller.takeFocusRequest(_id, host: widget.host)) {
      return;
    }
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted || !_controller.isActive(_id)) return;
        Scrollable.ensureVisible(context);
        _node.requestFocus();
      })
      ..ensureVisualUpdate();
  }

  /// Opens this field unless it is open; false when another field's draft
  /// was rejected or this field is locked.
  bool _open() {
    if (_controller.isActive(_id)) return true;
    if (!_eligible) return false;
    return _controller.begin(widget.field, host: widget.host).isAccepted;
  }

  /// A primary click on a closed editor opens it first; when that is
  /// refused the click is kept from the editor. A click on the open field's
  /// editor in another host (its property row rather than its grid cell)
  /// moves the field there, so Enter goes on in that region. Focus alone
  /// (programmatic, restored or reparented) never opens or flushes.
  bool _onPointerDown() {
    if (!_eligible) return true;
    final session = _controller.session;
    if (session != null && session.id == _id) {
      if (session.host != widget.host) {
        _controller.begin(widget.field, host: widget.host);
      }
      return true;
    }
    return _open();
  }

  /// A mouse change of a date, time, choice or check: a draft of the
  /// open field, opening it first.
  void _change(Object? value) {
    if (!_open()) return;
    _controller.update(_id, value);
  }

  void _onKey(EraEditorKey key) {
    if (!_controller.isActive(_id)) return;
    switch (key) {
      case EraEditorKey.escape:
        _controller.cancel();
      case EraEditorKey.enter || EraEditorKey.tab:
        if (!_controller.flush().isAccepted) return;
        if (widget.next?.call() case final next?) {
          _controller.begin(next, host: widget.host);
          assert(_debugNextAnswered(next.id));
        }
    }
  }

  /// Debug check that the next field's editor in this host took the
  /// keyboard: [CellEditor.next] must name a field whose editor is mounted
  /// (or mounted by the host's rebuild) in the same host.
  bool _debugNextAnswered(EditIdentity next) {
    final controller = _controller;
    final host = widget.host;
    // Two frames: a host mounting the editor builds it in the first, and
    // the editor answers in that frame's post-frame callbacks.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        WidgetsBinding.instance
          ..addPostFrameCallback((_) {
            if (controller.isActive(next) && controller.focusRequestPending) {
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: FlutterError(
                    'CellEditor.next returned $next, but no CellEditor of '
                    'that field in host $host took the keyboard.\n'
                    'next must name a field whose editor is mounted in the '
                    'same host.',
                  ),
                  library: 'LifeOS UI library',
                ),
              );
            }
          })
          ..ensureVisualUpdate();
      })
      ..ensureVisualUpdate();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.field.kind != ValueKind.date || widget.today != null,
      'A date editor needs an explicit today.',
    );
    _formEnabled = EraFormScope.enabledOf(context);
    final session = _controller.session;
    final open = session != null && session.id == _id;
    final field = widget.field;
    return RawGestureDetector(
      gestures: {
        _BeginGate: GestureRecognizerFactoryWithHandlers<_BeginGate>(
          () => _BeginGate(debugOwner: this),
          (gate) => gate.onDown = _onPointerDown,
        ),
      },
      child: EraEditorHostScope(
        bare: widget.bare,
        onKey: _onKey,
        child: valueEditor(
          kind: field.kind,
          label: widget.label,
          value: open ? session.draft : field.value,
          controller: _text,
          onChanged: _change,
          choices: widget.choices,
          today: widget.today,
          optional: widget.optional,
          error: (open ? session.error : null) ?? widget.error,
          enabled: widget.enabled,
          focusNode: _node,
          fieldKey: widget.fieldKey,
        ),
      ),
    );
  }
}

/// Wins a primary click on a closed editor outright when [onDown] refuses
/// it, so none of the editor's own gestures run; otherwise stays out.
final class _BeginGate extends OneSequenceGestureRecognizer {
  _BeginGate({super.debugOwner});

  bool Function() onDown = _allow;

  static bool _allow() => true;

  /// Only the primary button opens a field; a secondary click neither
  /// opens nor flushes.
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.buttons == kPrimaryButton && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (onDown()) return;
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'cell editor begin gate';
}
