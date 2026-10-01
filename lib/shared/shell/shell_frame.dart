import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../workbench/lifeos_skin.dart';
import '../workbench/office_controls.dart';
import 'formula_bar.dart';
import 'navigation_history.dart';
import 'quick_add.dart';

/// Fixed shell geometry (spec 5.1–5.2).
abstract final class ShellMetrics {
  static const menuBarHeight = 28.0;
  static const toolbarHeight = 44.0;
  static const formulaBarHeight = 34.0;
  static const statusLineHeight = 24.0;
  static const treeWidth = 228.0;
  static const inspectorWidth = 320.0;

  /// At and above this width every region is visible.
  static const fullWidth = 1280.0;

  /// Below this width the book tree folds into the **Books** button.
  static const treeFoldWidth = 1024.0;
}

/// Which optional regions the owner shows (View menu).
@immutable
final class ShellView {
  const ShellView({
    this.showTree = true,
    this.showInspector = true,
    this.showFormulaBar = true,
  });

  final bool showTree;
  final bool showInspector;
  final bool showFormulaBar;

  ShellView copyWith({
    bool? showTree,
    bool? showInspector,
    bool? showFormulaBar,
  }) => ShellView(
    showTree: showTree ?? this.showTree,
    showInspector: showInspector ?? this.showInspector,
    showFormulaBar: showFormulaBar ?? this.showFormulaBar,
  );

  @override
  bool operator ==(Object other) =>
      other is ShellView &&
      other.showTree == showTree &&
      other.showInspector == showInspector &&
      other.showFormulaBar == showFormulaBar;

  @override
  int get hashCode => Object.hash(showTree, showInspector, showFormulaBar);
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
    required this.title,
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

  /// Builds the book tree. [onOpened] is called after a node is opened, so a
  /// folded tree pane can close itself.
  final Widget Function(VoidCallback onOpened) tree;
  final Widget status;
  final String title;

  static ShellChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellChrome>();

  @override
  bool updateShouldNotify(ShellChrome oldWidget) =>
      menuBar != oldWidget.menuBar ||
      tree != oldWidget.tree ||
      status != oldWidget.status ||
      title != oldWidget.title ||
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
    required this.inspector,
    required this.inspectorOpen,
    required this.onBackToDesk,
    this.formulaBar,
    super.key,
  });

  final Widget desk;
  final Widget inspector;

  /// Whether a record is open. Below full width the inspector then replaces
  /// the desk until [onBackToDesk].
  final bool inspectorOpen;
  final VoidCallback onBackToDesk;

  /// Replaces the formula bar's content. By default it shows the selected
  /// cell and is empty when nothing is selected.
  final Widget? formulaBar;

  @override
  State<ShellFrame> createState() => _ShellFrameState();
}

final class _ShellFrameState extends State<ShellFrame> {
  bool _treeOpen = false;

  void _toggleTree() => setState(() => _treeOpen = !_treeOpen);

  void _closeTree() {
    if (_treeOpen) setState(() => _treeOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final chrome = ShellChrome.maybeOf(context);
    final view = ShellViewScope.maybeOf(context)?.value ?? const ShellView();
    return ColoredBox(
      color: tokens.ground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // A hidden region behaves like a narrower window: the tree folds
          // into Books and the inspector alternates with the desk, so
          // navigation and open records are never lost.
          final full = width >= ShellMetrics.fullWidth && view.showInspector;
          final treeFolded =
              width < ShellMetrics.treeFoldWidth || !view.showTree;
          final tree = _Landmark(
            label: 'Books',
            child: chrome?.tree(_closeTree) ?? const SizedBox.expand(),
          );
          final desk = _Landmark(label: 'Desk workspace', child: widget.desk);
          final inspector = _Landmark(
            label: 'Record inspector',
            child: _InspectorRegion(
              showBackToDesk: !full,
              onBackToDesk: widget.onBackToDesk,
              child: widget.inspector,
            ),
          );

          // Desk and inspector sit side by side at full width; otherwise
          // they alternate, both staying mounted.
          final Widget work = full
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: desk),
                    _Divider(color: tokens.chromeLine),
                    SizedBox(
                      width: ShellMetrics.inspectorWidth,
                      child: inspector,
                    ),
                  ],
                )
              : IndexedStack(
                  index: widget.inspectorOpen ? 1 : 0,
                  sizing: StackFit.expand,
                  children: [desk, inspector],
                );
          final Widget body = treeFolded
              ? IndexedStack(
                  index: _treeOpen ? 1 : 0,
                  sizing: StackFit.expand,
                  children: [work, tree],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: ShellMetrics.treeWidth, child: tree),
                    _Divider(color: tokens.chromeLine),
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
                  title: chrome?.title ?? '',
                  showBooks: treeFolded,
                  booksOpen: _treeOpen,
                  onBooks: _toggleTree,
                  quickAdd: chrome?.quickAdd ?? const [],
                  fromLastTime: chrome?.fromLastTime ?? const [],
                ),
              ),
              if (view.showFormulaBar)
                _Landmark(
                  label: 'Formula bar',
                  liveRegion: true,
                  child: _FormulaBarRegion(
                    child:
                        widget.formulaBar ??
                        FormulaBar(
                          onNavigate: (route) =>
                              chrome?.onNavigate(route.toString()),
                        ),
                  ),
                ),
              Expanded(child: body),
              _Landmark(
                label: 'Status line',
                child: SizedBox(
                  height: ShellMetrics.statusLineHeight,
                  child: chrome?.status ?? const SizedBox.shrink(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _Landmark extends StatelessWidget {
  const _Landmark({
    required this.label,
    required this.child,
    this.liveRegion = false,
  });

  final String label;
  final Widget child;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    liveRegion: liveRegion,
    label: label,
    child: FocusTraversalGroup(child: child),
  );
}

final class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 1, child: ColoredBox(color: color));
}

final class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.showBooks,
    required this.booksOpen,
    required this.onBooks,
    required this.quickAdd,
    required this.fromLastTime,
  });

  final String title;
  final List<QuickAddEntry> quickAdd;
  final List<QuickAddEntry> fromLastTime;
  final bool showBooks;
  final bool booksOpen;
  final VoidCallback onBooks;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final history = NavigationHistoryScope.maybeOf(context);
    return Container(
      constraints: const BoxConstraints(minHeight: ShellMetrics.toolbarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: Row(
        children: [
          if (history != null) ...[
            KeyButton(
              label: 'Back',
              leading: Icon(Icons.arrow_back, size: 16, color: tokens.ink),
              semanticLabel: history.canGoBack ? 'Back' : 'Back, unavailable',
              onPressed: history.canGoBack ? history.goBack : null,
            ),
            const SizedBox(width: 6),
            KeyButton(
              label: 'Forward',
              leading: Icon(Icons.arrow_forward, size: 16, color: tokens.ink),
              semanticLabel: history.canGoForward
                  ? 'Forward'
                  : 'Forward, unavailable',
              onPressed: history.canGoForward ? history.goForward : null,
            ),
            const SizedBox(width: 10),
          ],
          if (quickAdd.isNotEmpty) ...[
            QuickAddMenu(entries: quickAdd),
            const SizedBox(width: 6),
          ],
          for (final entry in fromLastTime.take(4)) ...[
            KeyButton(label: entry.label, onPressed: entry.open),
            const SizedBox(width: 6),
          ],
          if (quickAdd.isNotEmpty || fromLastTime.isNotEmpty)
            const SizedBox(width: 4),
          if (showBooks) ...[
            KeyButton(
              label: booksOpen ? 'Close books' : 'Books',
              onPressed: onBooks,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: skin.typography.body.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The formula bar's frame. It shows nothing until a value is selected; it
/// never shows placeholder text.
final class _FormulaBarRegion extends StatelessWidget {
  const _FormulaBarRegion({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Container(
      constraints: const BoxConstraints(
        minHeight: ShellMetrics.formulaBarHeight,
      ),
      decoration: BoxDecoration(
        color: tokens.paper,
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Text(
                'ƒx',
                style: skin.typography.figure.copyWith(
                  color: tokens.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          _Divider(color: tokens.rule),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

final class _InspectorRegion extends StatelessWidget {
  const _InspectorRegion({
    required this.showBackToDesk,
    required this.onBackToDesk,
    required this.child,
  });

  final bool showBackToDesk;
  final VoidCallback onBackToDesk;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return ColoredBox(
      color: tokens.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBackToDesk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.rule)),
              ),
              alignment: Alignment.centerLeft,
              child: KeyButton(
                label: 'Back to desk',
                kind: KeyKind.small,
                onPressed: onBackToDesk,
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
