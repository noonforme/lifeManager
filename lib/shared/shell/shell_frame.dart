import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../workbench/era_controls.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/office_controls.dart';
import 'address_bar.dart';
import 'navigation_history.dart';
import 'quick_add.dart';
import 'task_pane.dart';

/// Fixed shell geometry (spec 5.1–5.2).
abstract final class ShellMetrics {
  static const menuBarHeight = 24.0;
  static const toolbarHeight = 38.0;
  static const addressBarHeight = 26.0;
  static const statusBarHeight = 22.0;
  static const taskPaneWidth = 200.0;
  static const propertySheetWidth = 300.0;

  /// At and above this width every region is visible.
  static const fullWidth = 1280.0;

  /// Below this width the task pane folds into the **Tasks** key.
  static const taskPaneFoldWidth = 1024.0;
}

/// Which optional regions the owner shows (View menu).
@immutable
final class ShellView {
  const ShellView({this.showTaskPane = true, this.showPropertySheet = true});

  final bool showTaskPane;
  final bool showPropertySheet;

  ShellView copyWith({bool? showTaskPane, bool? showPropertySheet}) =>
      ShellView(
        showTaskPane: showTaskPane ?? this.showTaskPane,
        showPropertySheet: showPropertySheet ?? this.showPropertySheet,
      );

  @override
  bool operator ==(Object other) =>
      other is ShellView &&
      other.showTaskPane == showTaskPane &&
      other.showPropertySheet == showPropertySheet;

  @override
  int get hashCode => Object.hash(showTaskPane, showPropertySheet);
}

final class ShellViewController extends ValueNotifier<ShellView> {
  ShellViewController() : super(const ShellView());
}

final class ShellViewScope extends InheritedNotifier<ShellViewController> {
  const ShellViewScope({
    required ShellViewController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ShellViewController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellViewScope>()?.notifier;
}

/// The app-level parts of the shell: menu bar, book tree, status line and
/// the current location's title. The app provides them once; every surface
/// then only supplies its desk and inspector.
final class ShellChrome extends InheritedWidget {
  const ShellChrome({
    required this.menuBar,
    required this.tree,
    required this.status,
    required this.crumbs,
    required this.onNavigate,
    required super.child,
    this.quickAdd = const [],
    this.fromLastTime = const [],
    super.key,
  });

  final Widget menuBar;

  /// The toolbar's **+ Add** entries.
  final List<QuickAddEntry> quickAdd;

  /// "From last time" buttons beside + Add, at most four.
  final List<QuickAddEntry> fromLastTime;

  /// Opens a route, for example an operand's source from the formula bar.
  final ValueChanged<String> onNavigate;

  /// Builds the Books group's content. [onOpened] is called after a node is
  /// opened, so a folded task pane can close itself.
  final Widget Function(VoidCallback onOpened) tree;
  final Widget status;

  /// Where the owner is, shown in the Address bar.
  final List<AddressCrumb> crumbs;

  static ShellChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellChrome>();

  @override
  bool updateShouldNotify(ShellChrome oldWidget) =>
      menuBar != oldWidget.menuBar ||
      tree != oldWidget.tree ||
      status != oldWidget.status ||
      !listEquals(crumbs, oldWidget.crumbs) ||
      onNavigate != oldWidget.onNavigate ||
      quickAdd != oldWidget.quickAdd ||
      fromLastTime != oldWidget.fromLastTime;
}

/// The Office Machine shell: menu bar, toolbar, formula bar, book tree,
/// desk, inspector and status line, with the width behaviour of spec 5.2.
///
/// The desk and inspector stay mounted while the narrower layouts swap
/// between them, so scroll position, selection and drafts survive.
final class ShellFrame extends StatefulWidget {
  const ShellFrame({
    required this.desk,
    required this.inspectorOpen,
    required this.onBackToList,
    this.inspector,
    this.tasks = const [],
    this.details,
    super.key,
  });

  final Widget desk;

  /// Null on a surface with no records to inspect, such as a desk of
  /// tiles; the desk then takes the whole width.
  final Widget? inspector;

  /// Whether a record is open. Below full width the inspector then replaces
  /// the desk until [onBackToList].
  final bool inspectorOpen;
  final VoidCallback onBackToList;

  /// The surface's own task-pane groups, shown above Books.
  final List<Widget> tasks;

  /// The Details group's content, shown below Books.
  final Widget? details;

  @override
  State<ShellFrame> createState() => _ShellFrameState();
}

final class _ShellFrameState extends State<ShellFrame> {
  bool _tasksOpen = false;

  void _toggleTasks() => setState(() => _tasksOpen = !_tasksOpen);

  void _closeTasks() {
    if (_tasksOpen) setState(() => _tasksOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final chrome = ShellChrome.maybeOf(context);
    final view = ShellViewScope.maybeOf(context)?.value ?? const ShellView();
    // Every surface gets a text style and ink, with or without a Scaffold.
    return Material(
      type: MaterialType.transparency,
      textStyle: skin.typography.body.copyWith(color: tokens.ink),
      child: ColoredBox(
        color: tokens.ground,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final full =
                width >= ShellMetrics.fullWidth && view.showPropertySheet;
            final folded =
                width < ShellMetrics.taskPaneFoldWidth || !view.showTaskPane;
            // Widening the window docks the pane; the overlay state goes.
            if (!folded && _tasksOpen) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _closeTasks(),
              );
            }
            final pane = _Landmark(
              label: 'Task pane',
              child: TaskPane(
                groups: [
                  ...widget.tasks,
                  TaskGroup(
                    title: 'Books',
                    child: chrome?.tree(_closeTasks) ?? const SizedBox.shrink(),
                  ),
                  if (widget.details case final details?)
                    TaskGroup(title: 'Details', child: details),
                ],
              ),
            );
            final desk = _Landmark(label: 'Desk workspace', child: widget.desk);
            final inspecting = widget.inspector;
            final inspector = inspecting == null
                ? null
                : _Landmark(
                    label: 'Record inspector',
                    child: _PropertySheetRegion(
                      showBackToList: !full,
                      onBackToList: widget.onBackToList,
                      child: inspecting,
                    ),
                  );
            final Widget work = inspector == null
                ? desk
                : full
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: desk),
                      SizedBox(
                        width: ShellMetrics.propertySheetWidth,
                        child: inspector,
                      ),
                    ],
                  )
                : IndexedStack(
                    index: widget.inspectorOpen ? 1 : 0,
                    sizing: StackFit.expand,
                    children: [desk, inspector],
                  );
            final Widget body = folded
                ? Stack(
                    children: [
                      Positioned.fill(child: work),
                      if (_tasksOpen)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: ShellMetrics.taskPaneWidth,
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.escape):
                                  _closeTasks,
                            },
                            child: Focus(autofocus: true, child: pane),
                          ),
                        ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: ShellMetrics.taskPaneWidth, child: pane),
                      Expanded(child: work),
                    ],
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Landmark(
                  label: 'Menu bar',
                  child: SizedBox(
                    height: ShellMetrics.menuBarHeight,
                    child: chrome?.menuBar ?? const SizedBox.shrink(),
                  ),
                ),
                _Landmark(
                  label: 'Toolbar',
                  child: _Toolbar(
                    showTasks: folded,
                    tasksOpen: _tasksOpen,
                    onTasks: _toggleTasks,
                    quickAdd: chrome?.quickAdd ?? const [],
                    fromLastTime: chrome?.fromLastTime ?? const [],
                  ),
                ),
                AddressBar(
                  crumbs: chrome?.crumbs ?? const [],
                  onNavigate: (route) => chrome?.onNavigate(route),
                  // Go reopens the current location (its last crumb).
                  onGo: () {
                    final here = chrome?.crumbs.lastOrNull?.route;
                    if (here != null) chrome?.onNavigate(here);
                  },
                ),
                Expanded(child: body),
                _Landmark(
                  label: 'Status line',
                  child: SizedBox(
                    height: ShellMetrics.statusBarHeight,
                    child: chrome?.status ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _Landmark extends StatelessWidget {
  const _Landmark({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: label,
    child: FocusTraversalGroup(child: child),
  );
}

final class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.showTasks,
    required this.tasksOpen,
    required this.onTasks,
    required this.quickAdd,
    required this.fromLastTime,
  });

  final bool showTasks;
  final bool tasksOpen;
  final VoidCallback onTasks;
  final List<QuickAddEntry> quickAdd;
  final List<QuickAddEntry> fromLastTime;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final history = NavigationHistoryScope.maybeOf(context);
    Widget separator() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: tokens.chromeLine,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: ShellMetrics.toolbarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: skin.painters.toolbar(tokens),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          if (showTasks)
            KeyButton(
              label: tasksOpen ? 'Close tasks' : 'Tasks',
              kind: KeyKind.toolbar,
              onPressed: onTasks,
            ),
          if (history != null) ...[
            KeyButton(
              label: 'Back',
              kind: KeyKind.toolbar,
              leading: Orb(
                glyph: OrbGlyph.back,
                tone: history.canGoBack ? OrbTone.green : OrbTone.grey,
              ),
              semanticLabel: history.canGoBack ? 'Back' : 'Back, unavailable',
              onPressed: history.canGoBack ? history.goBack : null,
            ),
            KeyButton(
              label: 'Forward',
              kind: KeyKind.toolbar,
              leading: Orb(
                glyph: OrbGlyph.forward,
                tone: history.canGoForward ? OrbTone.green : OrbTone.grey,
              ),
              semanticLabel: history.canGoForward
                  ? 'Forward'
                  : 'Forward, unavailable',
              onPressed: history.canGoForward ? history.goForward : null,
            ),
          ],
          if (quickAdd.isNotEmpty) ...[
            separator(),
            QuickAddMenu(entries: quickAdd),
          ],
          if (fromLastTime.isNotEmpty) ...[
            separator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'From last time:',
                style: skin.typography.body.copyWith(color: tokens.muted),
              ),
            ),
            for (final entry in fromLastTime.take(4))
              KeyButton(
                label: entry.label,
                kind: KeyKind.toolbar,
                onPressed: entry.open,
              ),
          ],
        ],
      ),
    );
  }
}

final class _PropertySheetRegion extends StatelessWidget {
  const _PropertySheetRegion({
    required this.showBackToList,
    required this.onBackToList,
    required this.child,
  });

  final bool showBackToList;
  final VoidCallback onBackToList;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Container(
      color: tokens.chrome,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBackToList)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: KeyButton(
                  label: 'Back to list',
                  kind: KeyKind.small,
                  onPressed: onBackToList,
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
