import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../controls/cell_editor.dart';
import '../controls/editor_session_controller.dart';
import '../controls/era_combo.dart';
import '../controls/era_controls.dart';
import '../controls/era_form.dart';
import '../controls/era_scrollbar.dart';
import '../controls/keys.dart';
import '../controls/value_editor.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

/// One editable field an [ActionPanel] registers: a stable [id], the
/// owner's current [value], its [validate] check and whether it is
/// [enabled] (eligible for editing and for Enter/Tab). The panel shows it as
/// a labelled [CellEditor] on the shared controller.
@immutable
final class ActionField {
  const ActionField({
    required this.id,
    required this.label,
    required this.kind,
    this.value,
    this.text,
    this.validate,
    this.enabled = true,
    this.choices = const [],
    this.optional = false,
    this.error,
    this.fieldKey,
  });

  /// Stable within the panel: the field key of its [EditIdentity].
  final String id;
  final String label;
  final ValueKind kind;

  /// The owner's current (pending) value.
  final Object? value;

  /// The entry text of a text-typed kind, when the owner formats it itself.
  final String? text;

  /// The reason a draft is refused, or null to accept it. A text-typed
  /// kind's draft is the raw text.
  final String? Function(Object? draft)? validate;

  /// False for a derived, read-only or disabled field: greyed, never opened
  /// and skipped by Enter/Tab.
  final bool enabled;

  /// The choices of a [ValueKind.choice] field.
  final List<EraComboItem<Object?>> choices;

  /// A date that may be empty.
  final bool optional;

  /// The owner's own error for the field, such as a missing value.
  final String? error;

  /// The key of the editor's box.
  final Key? fieldKey;
}

/// A group box of an [ActionPanel]: its [legend], its registered [fields]
/// in Enter/Tab order, then any read-only [children] (a note, a count of
/// picked records). The children never take keyboard focus.
@immutable
final class ActionGroup {
  const ActionGroup({
    required this.legend,
    this.fields = const [],
    this.children = const [],
  });

  final String legend;
  final List<ActionField> fields;
  final List<Widget> children;
}

/// How one item of an action ended (database shell spec 9).
enum ActionOutcome {
  /// Committed: it stays committed whatever happens to later items.
  done,

  /// Refused or failed, with the reason; a retry submits it again.
  failed,

  /// It may have succeeded; it must be checked before any retry.
  uncertain,
}

/// One result row of an [ActionPanel]: the item's [label], its [outcome]
/// and a [detail] (the reason of a failure).
@immutable
final class ActionResult {
  const ActionResult({required this.label, required this.outcome, this.detail});

  const ActionResult.done(this.label, {this.detail})
    : outcome = ActionOutcome.done;

  const ActionResult.failed(this.label, String reason)
    : outcome = ActionOutcome.failed,
      detail = reason;

  const ActionResult.uncertain(this.label, {this.detail})
    : outcome = ActionOutcome.uncertain;

  final String label;
  final ActionOutcome outcome;
  final String? detail;
}

/// A multi-step action inline in the property column (database shell spec
/// 4.4): the action's [title] in the object box, group boxes of labelled
/// fields that scroll, an error row and result rows, and the primary verb
/// and Cancel pinned below the scroll region, primary first.
///
/// Fields are registered ([ActionGroup.fields]) and edited as labelled
/// [CellEditor]s on the owner's shared [controller], identified by
/// ([record], [ActionField.id]). Enter or Tab commits the open field and
/// opens the next enabled one, closing the last; it never presses a key.
/// [groups] is a builder the panel calls again right after a commit, so the
/// next field, its eligibility and its value come from the owner's input
/// as [onChanged] left it, before the owner rebuilds.
/// Esc throws away the open field's value only. An accepted draft reaches
/// [onChanged] synchronously, after [ActionField.validate] passes.
///
/// The keys are mouse-only. The primary key flushes the open editor first
/// and does nothing when the draft is refused; it fires once per click and
/// not again until the next frame. Cancel cancels this panel's open field,
/// then asks the owner ([onCancel]); the owner confirms, discards its input
/// and closes the panel. The panel keeps the keyboard on itself when an
/// editor closes or is locked, so a key never traverses into the keys.
///
/// Controlled: the owner keeps the input, [results], [error] and [busy].
/// While [busy], every field, the group children and both keys are locked
/// and a draft cannot be committed. The owner drives pick mode: it disables
/// its grid's pick changes while [busy] as well. Results are shown as
/// given; a later failure never changes completed rows.
final class ActionPanel extends StatefulWidget {
  const ActionPanel({
    required this.title,
    required this.record,
    required this.controller,
    required this.groups,
    required this.onChanged,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onCancel,
    this.cancelLabel = 'Cancel',
    this.results = const [],
    this.resultsLegend = 'Results',
    this.error,
    this.busy = false,
    this.enabled = true,
    this.today,
    this.labelWidth = 96,
    super.key,
  });

  static bool _uniqueIds(List<ActionGroup> groups) {
    final ids = [
      for (final group in groups)
        for (final field in group.fields) field.id,
    ];
    return ids.toSet().length == ids.length;
  }

  /// The action's title, shown in the object box.
  final String title;

  /// The identity of this action's input in [controller]: stable for as
  /// long as the action is open, and distinct from every record's.
  final Object record;

  /// The owner's editor controller, shared with the grid it drives.
  final EditorSessionController controller;

  /// The form's group boxes, built from the owner's current input. Called
  /// on every build and again whenever the panel looks up a field (the
  /// next one after a commit, a field's validator), so it must read the
  /// owner's live state rather than values captured earlier.
  final List<ActionGroup> Function() groups;

  /// An accepted draft of field [field]: the owner writes it into its
  /// pending input before returning. A text-typed kind's draft is the raw
  /// text that [ActionField.validate] accepted.
  final void Function(String field, Object? value) onChanged;

  final String primaryLabel;

  /// The action, after the open editor was flushed. Null greys the key, for
  /// example while nothing is picked.
  final VoidCallback? onPrimary;
  final String cancelLabel;

  /// Asks the owner to close the panel, after the panel's open field was
  /// cancelled.
  final VoidCallback onCancel;

  final List<ActionResult> results;
  final String resultsLegend;

  /// A failure of the action as a whole, shown above the results.
  final String? error;

  /// The action is running: everything in the panel is locked.
  final bool busy;
  final bool enabled;

  /// Today for date fields' calendars; required when there is one.
  final LocalDate? today;

  /// The "Label:" column of the form at 100 % text.
  final double labelWidth;

  @override
  State<ActionPanel> createState() => _ActionPanelState();
}

/// The region token of a panel's editors: equal for a remounted panel of
/// the same action, so its open field keeps the keyboard there.
@immutable
final class _PanelHost {
  const _PanelHost(this.record);

  final Object record;

  @override
  bool operator ==(Object other) =>
      other is _PanelHost && other.record == record;

  @override
  int get hashCode => Object.hash(_PanelHost, record);
}

final class _ActionPanelState extends State<ActionPanel> {
  /// The mounted panel of each action, per controller: an open field's
  /// commit goes to it, so a remounted panel takes over and a removed one
  /// is never called.
  static final _live = Expando<Map<Object, _ActionPanelState>>();

  final _node = FocusNode(debugLabel: 'ActionPanel', skipTraversal: true);
  final _scroll = ScrollController();
  final _footerScroll = ScrollController();
  final _errorKey = GlobalKey();

  /// Set when the primary action ran, until the frame ends.
  bool _submitted = false;

  /// The node in the panel that held the keyboard at the last focus
  /// change, or null when the keyboard was elsewhere.
  FocusNode? _lastFocus;
  bool _formEnabled = true;

  bool get _locked => widget.busy || !widget.enabled || !_formEnabled;

  _PanelHost get _host => _PanelHost(widget.record);

  /// The registered fields, from the owner's live input.
  List<ActionField> get _fields => [
    for (final group in widget.groups()) ...group.fields,
  ];

  @override
  void initState() {
    super.initState();
    _register();
    FocusManager.instance.addListener(_onPrimaryFocus);
  }

  @override
  void didUpdateWidget(ActionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.record != widget.record) {
      _unregister(oldWidget);
      _register();
    }
    if (widget.busy && !oldWidget.busy) _hold();
    if (widget.error != null && widget.error != oldWidget.error) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final context = _errorKey.currentContext;
        if (mounted && context != null) Scrollable.ensureVisible(context);
      });
    }
  }

  @override
  void dispose() {
    _unregister(widget);
    FocusManager.instance.removeListener(_onPrimaryFocus);
    _node.dispose();
    _scroll.dispose();
    _footerScroll.dispose();
    super.dispose();
  }

  void _register() => (_live[widget.controller] ??= {})[widget.record] = this;

  void _unregister(ActionPanel config) {
    final panels = _live[config.controller];
    if (panels != null && identical(panels[config.record], this)) {
      panels.remove(config.record);
    }
  }

  static EditResult _commitTo(
    EditorSessionController controller,
    EditIdentity id,
    Object? draft,
  ) {
    final panel = _live[controller]?[id.record];
    if (panel == null || !panel.mounted) {
      return const EditResult.rejected('This action was closed.');
    }
    return panel._commit(id, draft);
  }

  EditResult _commit(EditIdentity id, Object? draft) {
    final field = _fields.where((field) => field.id == id.field).firstOrNull;
    if (field == null || !field.enabled) {
      return const EditResult.rejected('This field cannot be changed.');
    }
    if (_locked) {
      return const EditResult.rejected('Wait for the action to finish.');
    }
    if (field.validate?.call(draft) case final reason?) {
      return EditResult.rejected(reason);
    }
    widget.onChanged(field.id, draft);
    return const EditResult.accepted();
  }

  EditField _editField(ActionField field) {
    final controller = widget.controller;
    return EditField(
      id: EditIdentity(record: widget.record, field: field.id),
      kind: field.kind,
      value: field.value,
      text: field.text,
      commit: (id, draft) => _commitTo(controller, id, draft),
    );
  }

  /// The next enabled field after [id], in registration order.
  EditField? _next(String id) {
    if (_locked) return null;
    final fields = _fields;
    final at = fields.indexWhere((field) => field.id == id);
    if (at < 0) return null;
    for (final field in fields.skip(at + 1)) {
      if (field.enabled) return _editField(field);
    }
    return null;
  }

  /// Keeps the keyboard on the panel itself when it is inside the panel.
  void _hold() {
    if (_node.hasFocus && !_node.hasPrimaryFocus) _node.requestFocus();
  }

  /// When an editor in the panel goes away or is locked while it holds the
  /// keyboard, the keyboard falls to the enclosing scope; the panel takes
  /// it back, so Tab cannot traverse. The application root scope is never
  /// reclaimed. A click into another region and the window going inactive
  /// (the focus manager parks the keyboard on the root scope and restores
  /// the editor on resume) are left alone. Watches the focus manager: the
  /// ancestors of a disposed editor are not told that they lost the focus.
  void _onPrimaryFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (_node.hasFocus) {
      _lastFocus = focus;
      return;
    }
    final last = _lastFocus;
    if (last == null) return;
    _lastFocus = null;
    final lifecycle = SchedulerBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    // Detached (disposed or unmounted) or no longer focusable (locked).
    final lost = last.parent == null || !last.canRequestFocus;
    if (!lost) return;
    if (focus is FocusScopeNode &&
        focus != FocusManager.instance.rootScope &&
        _node.ancestors.contains(focus)) {
      _node.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) =>
      node.hasPrimaryFocus && event is! KeyUpEvent
      ? KeyEventResult.handled
      : KeyEventResult.ignored;

  void _primary() {
    final action = widget.onPrimary;
    if (_locked || _submitted || action == null) return;
    if (!widget.controller.flush().isAccepted) return;
    _submitted = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _submitted = false)
      ..ensureVisualUpdate();
    _hold();
    action();
  }

  void _cancel() {
    if (_locked) return;
    if (widget.controller.active?.record == widget.record) {
      widget.controller.cancel();
    }
    _hold();
    widget.onCancel();
  }

  Widget _editor(ActionField field) => CellEditor(
    controller: widget.controller,
    field: _editField(field),
    label: field.label,
    bare: false,
    host: _host,
    next: () => _next(field.id),
    choices: field.choices,
    today: widget.today,
    optional: field.optional,
    enabled: field.enabled && !_locked,
    error: field.error,
    fieldKey: field.fieldKey,
  );

  @override
  Widget build(BuildContext context) {
    _formEnabled = EraFormScope.enabledOf(context);
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final locked = _locked;
    final groups = widget.groups();
    assert(
      ActionPanel._uniqueIds(groups),
      'Each field of an action panel needs its own id.',
    );

    final form = EraFormScope(
      labelWidth: widget.labelWidth,
      enabled: !locked,
      child: IgnorePointer(
        ignoring: locked,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groups)
              GroupBox(
                legend: group.legend,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final field in group.fields) _editor(field),
                    if (group.children.isNotEmpty)
                      ExcludeFocus(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: group.children,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          form,
          if (widget.error case final error?)
            KeyedSubtree(key: _errorKey, child: _ErrorRow(error)),
          if (widget.results.isNotEmpty)
            GroupBox(
              legend: widget.resultsLegend,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final result in widget.results) _ResultRow(result),
                ],
              ),
            ),
        ],
      ),
    );

    final footer = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(top: BorderSide(color: tokens.chromeLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        // Mouse only: Enter, Space or Tab never reach a key.
        child: ExcludeFocus(
          child: FormFooter(
            children: [
              KeyButton(
                label: widget.primaryLabel,
                kind: KeyKind.primary,
                wrapLabel: true,
                onPressed: locked || widget.onPrimary == null ? null : _primary,
              ),
              KeyButton(
                label: widget.cancelLabel,
                wrapLabel: true,
                onPressed: locked ? null : _cancel,
              ),
            ],
          ),
        ),
      ),
    );

    Widget scrolling(ScrollController controller, Widget child) => EraScrollbar(
      controller: controller,
      axis: Axis.vertical,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(controller: controller, child: child),
      ),
    );

    return Focus(
      focusNode: _node,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: widget.busy ? SystemMouseCursors.wait : MouseCursor.defer,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: widget.title,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: MillenniumColors.page,
              border: Border.all(color: tokens.chromeLine),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bounded = constraints.hasBoundedHeight;
                return Column(
                  mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ObjectBox(widget.title),
                    if (bounded) ...[
                      Expanded(child: scrolling(_scroll, content)),
                      // Pinned, but never more than half the height: past
                      // that the keys scroll on their own.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(0, constraints.maxHeight / 2),
                        ),
                        child: scrolling(_footerScroll, footer),
                      ),
                    ] else ...[
                      content,
                      footer,
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The object box of the property column showing the action's title: a
/// white sunken 22 px box with the title in bold.
final class _ObjectBox extends StatelessWidget {
  const _ObjectBox(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Semantics(
          header: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 22),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.paper,
              border: Border.all(color: MillenniumColors.fieldLine),
            ),
            child: Text(
              title,
              style: skin.typography.strong.copyWith(color: tokens.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// A mark, then wrapping text: the layout of the error and result rows.
final class _MarkedRow extends StatelessWidget {
  const _MarkedRow({
    required this.mark,
    required this.semantics,
    required this.children,
  });

  final Widget mark;
  final String semantics;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semantics,
    excludeSemantics: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 16, height: 16, child: Center(child: mark)),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _ErrorRow extends StatelessWidget {
  const _ErrorRow(this.error);

  final String error;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _MarkedRow(
        mark: const EraIcon(EraIconKind.warning),
        semantics: 'Error: $error',
        children: [
          Text(
            error,
            style: skin.typography.body.copyWith(color: skin.tokens.negative),
          ),
        ],
      ),
    );
  }
}

final class _ResultRow extends StatelessWidget {
  const _ResultRow(this.result);

  final ActionResult result;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final (mark, name, tone) = switch (result.outcome) {
      ActionOutcome.done => (
        EraGlyph(EraGlyphKind.tick, color: tokens.positive, size: 11),
        'Done',
        tokens.muted,
      ),
      ActionOutcome.failed => (
        const EraIcon(EraIconKind.warning),
        'Failed',
        tokens.negative,
      ),
      ActionOutcome.uncertain => (
        const EraIcon(EraIconKind.warning),
        'Uncertain',
        tokens.runInk,
      ),
    };
    final detail = result.detail;
    return _MarkedRow(
      mark: mark,
      semantics: ['$name: ${result.label}', ?detail].join(', '),
      children: [
        Text(
          result.label,
          style: skin.typography.body.copyWith(color: tokens.ink),
        ),
        if (detail != null)
          Text(detail, style: skin.typography.small.copyWith(color: tone)),
      ],
    );
  }
}
