import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/shell/navigation_history.dart';
import '../shared/shell/shell_frame.dart';
import '../shared/workbench/cell_selection.dart';
import '../shared/workbench/lifeos_skin.dart';
import '../shared/workbench/lifeos_theme.dart';
import 'shell_host.dart';

final class LifeOsApp extends StatefulWidget {
  const LifeOsApp({required this.router, this.onQuit, super.key});

  final GoRouter router;

  /// Closes the window from File › Quit. Null disables Quit.
  final VoidCallback? onQuit;

  @override
  State<LifeOsApp> createState() => _LifeOsAppState();
}

final class _LifeOsAppState extends State<LifeOsApp> {
  final _appearance = LifeOSAppearanceController();
  final _view = ShellViewController();
  final _cells = CellSelectionController();
  final _history = NavigationHistory();

  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_recordLocation);
    _recordLocation();
  }

  @override
  void didUpdateWidget(covariant LifeOsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routeInformationProvider.removeListener(_recordLocation);
      widget.router.routeInformationProvider.addListener(_recordLocation);
    }
  }

  void _recordLocation() => _history.visit(
    widget.router.routeInformationProvider.value.uri.toString(),
  );

  void _onPointerDown(PointerDownEvent event, NavigationHistoryScope? scope) {
    if (scope == null) return;
    if (event.buttons & kBackMouseButton != 0) scope.goBack();
    if (event.buttons & kForwardMouseButton != 0) scope.goForward();
  }

  @override
  void dispose() {
    _appearance.dispose();
    _view.dispose();
    _cells.dispose();
    widget.router.routeInformationProvider.removeListener(_recordLocation);
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'LifeOS',
      theme: buildLifeOSTheme(highContrast: false),
      highContrastTheme: buildLifeOSTheme(highContrast: true),
      routerConfig: widget.router,
      // Every LifeOS-owned widget reads its skin, tokens and type from here.
      builder: (context, child) => AppQuit(
        onQuit: widget.onQuit,
        child: LifeOSAppearanceScope(
          controller: _appearance,
          child: ShellViewScope(
            controller: _view,
            child: CellSelectionScope(
              controller: _cells,
              child: NavigationHistoryScope(
                history: _history,
                onNavigate: widget.router.go,
                child: Builder(
                  // Mouse back and forward buttons travel the history.
                  builder: (context) => Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) => _onPointerDown(
                      event,
                      NavigationHistoryScope.maybeOf(context),
                    ),
                    child: LifeOSSkinScope(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
