import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/workbench/lifeos_skin.dart';
import '../shared/workbench/lifeos_theme.dart';

final class LifeOsApp extends StatelessWidget {
  const LifeOsApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'LifeOS',
      theme: buildLifeOSTheme(highContrast: false),
      highContrastTheme: buildLifeOSTheme(highContrast: true),
      routerConfig: router,
      // Every LifeOS-owned widget reads its skin, tokens and type from here.
      builder: (context, child) =>
          LifeOSSkinScope(child: child ?? const SizedBox.shrink()),
    );
  }
}
