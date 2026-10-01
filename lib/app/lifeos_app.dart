import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    _appearance.dispose();
    _view.dispose();
    _cells.dispose();
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
              child: LifeOSSkinScope(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
