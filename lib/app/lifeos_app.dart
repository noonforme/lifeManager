import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/ui.dart';

/// The production app (cutover spec 4g): the LifeOS theme, skin, era
/// scrolling and cell selection around [router], whose one `/work` route
/// hosts the Work shell.
final class LifeOsApp extends StatefulWidget {
  const LifeOsApp({required this.router, super.key});

  final GoRouter router;

  @override
  State<LifeOsApp> createState() => _LifeOsAppState();
}

final class _LifeOsAppState extends State<LifeOsApp> {
  final _cells = CellSelectionController();

  @override
  void dispose() {
    _cells.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'LifeOS',
    theme: buildLifeOSTheme(),
    scrollBehavior: const EraScrollBehavior(),
    routerConfig: widget.router,
    // Every LifeOS-owned widget reads its skin, tokens and type from here.
    builder: (context, child) => CellSelectionScope(
      controller: _cells,
      child: LifeOSSkinScope(
        child: Builder(
          builder: (context) => Theme(
            data: lifeOSThemeFor(LifeOSSkinScope.of(context)),
            // Text fields need a Material ancestor; it paints nothing.
            child: Material(
              type: MaterialType.transparency,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
}
