import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../ui/ui.dart';
import 'address_bar.dart';
import 'navigation_history.dart';
import 'quick_add.dart';
import 'shell_dialog.dart';
import 'task_pane.dart';

/// Fixed shell geometry (spec 5.1–5.2).
abstract final class ShellMetrics {
  static const menuBarHeight = 24.0;
  static const toolbarHeight = 38.0;
  static const addressBarHeight = 26.0;
  static const statusBarHeight = 22.0;
  static const taskPaneWidth = 200.0;

  /// Below this width the task pane folds into the **Tasks** key.
  static const taskPaneFoldWidth = 1024.0;
}

/// Which optional regions the owner shows (View menu).
@immutable
final class ShellView {
  const ShellView({this.showTaskPane = true});

  final bool showTaskPane;

  ShellView copyWith({bool? showTaskPane}) =>
      ShellView(showTaskPane: showTaskPane ?? this.showTaskPane);

  @override
  bool operator ==(Object other) =>
      other is ShellView && other.showTaskPane == showTaskPane;

  @override
  int get hashCode => showTaskPane.hashCode;
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
/// then only supplies its desk, tasks and dialog.
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
    this.addressTree = const [],
    this.addressIcon,
    super.key,
  });

  final Widget menuBar;

  /// Every location, for the Address drop-down.
  final List<AddressLocation> addressTree;

  /// The current area's icon in the Address field.
  final EraIconKind? addressIcon;

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
      fromLastTime != oldWidget.fromLastTime ||
      !listEquals(addressTree, oldWidget.addressTree) ||
      addressIcon != oldWidget.addressIcon;
}

/// The shell (XP-authentic shell spec 3): menu bar, toolbar, Address bar,
/// task pane and content, status bar, and the open dialog over all of it.
final class ShellFrame extends StatefulWidget {
  const ShellFrame({
    required this.desk,
    this.dialog,
    this.tasks = const [],
    this.details,
    super.key,
  });

  final Widget desk;

  /// The open Properties sheet, form or message box, if any.
  final ShellDialog? dialog;

  /// The surface's own task-pane groups, shown above Books.
  final List<Widget> tasks;

  /// The Details group's content, shown below Books.
  final Widget? details;

  @override
  State<ShellFrame> createState() => _ShellFrameState();
}

final class _ShellFrameState extends State<ShellFrame> {
  bool _tasksOpen = false;
  final _address = GlobalKey<EraComboState<int>>();

  /// The era's window keys, live while no dialog is open: Alt+Left and
  /// Alt+Right go back and forward, Alt+Home goes to Today, F5 reopens
  /// the place, Alt+D puts focus in the Address box and F4 drops its list.
  Map<ShortcutActivator, VoidCallback> _windowKeys(BuildContext context) {
    final chrome = ShellChrome.maybeOf(context);
    final history = NavigationHistoryScope.maybeOf(context);
    final here = chrome?.crumbs.lastOrNull?.route;
    return {
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
          history?.goBack(),
      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
          history?.goForward(),
      const SingleActivator(LogicalKeyboardKey.home, alt: true): () =>
          chrome?.onNavigate('/today'),
      const SingleActivator(LogicalKeyboardKey.f5): () {
        if (here != null) chrome?.onNavigate(here);
      },
      const SingleActivator(LogicalKeyboardKey.keyD, alt: true): () =>
          _address.currentState?.focus(),
      const SingleActivator(LogicalKeyboardKey.f4): () =>
          _address.currentState?.open(),
    };
  }

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
              child: TaskChoiceScope(
                onChoice: _closeTasks,
                child: TaskPane(
                  groups: [
                    ...widget.tasks,
                    TaskGroup(
                      title: 'Books',
                      child:
                          chrome?.tree(_closeTasks) ?? const SizedBox.shrink(),
                    ),
                    if (widget.details case final details?)
                      TaskGroup(title: 'Details', child: details),
                  ],
                ),
              ),
            );
            final desk = _Landmark(label: 'Desk workspace', child: widget.desk);
            final Widget body = folded
                ? Stack(
                    children: [
                      Positioned.fill(child: desk),
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
                      Expanded(child: desk),
                    ],
                  );

            return ShellDialogLayer(
              dialog: widget.dialog,
              child: CallbackShortcuts(
                bindings: _windowKeys(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Landmark(
                      label: 'Menu bar',
                      // A minimum, so 200 % text grows the bar instead of
                      // clipping it.
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: ShellMetrics.menuBarHeight,
                        ),
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
                      comboKey: _address,
                      crumbs: chrome?.crumbs ?? const [],
                      tree: chrome?.addressTree ?? const [],
                      icon: chrome?.addressIcon,
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
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: ShellMetrics.statusBarHeight,
                        ),
                        child: chrome?.status ?? const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
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
    // An etched line between bands, and the dotted gripper that starts each
    // band (XP-authentic shell spec 3).
    Widget separator() => Container(
      width: 2,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: tokens.chromeLine),
          right: BorderSide(color: tokens.paper),
        ),
      ),
    );
    Widget gripper() => const ToolbarGripper();
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
              tooltip: tasksOpen ? 'Hide the task pane' : 'Show the task pane',
              onPressed: onTasks,
            ),
          if (history != null) ...[
            gripper(),
            KeyButton(
              label: 'Back',
              kind: KeyKind.toolbar,
              tooltip: 'Go back to the last place',
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
              tooltip: 'Go forward again',
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
            gripper(),
            QuickAddMenu(entries: quickAdd),
          ],
          if (fromLastTime.isNotEmpty) ...[
            separator(),
            gripper(),
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

/// The dotted handle at the left of a toolbar band.
final class ToolbarGripper extends StatelessWidget {
  const ToolbarGripper({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 6,
    height: 24,
    child: CustomPaint(painter: _GripperPainter()),
  );
}

final class _GripperPainter extends CustomPainter {
  const _GripperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xffffffff);
    final dark = Paint()..color = MillenniumColors.sunkenEdge;
    for (var y = 3.0; y < size.height - 3; y += 4) {
      canvas
        ..drawRect(Rect.fromLTWH(2, y + 1, 2, 2), light)
        ..drawRect(Rect.fromLTWH(1, y, 2, 2), dark);
    }
  }

  @override
  bool shouldRepaint(_GripperPainter oldDelegate) => false;
}
