import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_theme.dart';

final class LifeOsApp extends StatelessWidget {
  const LifeOsApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'LifeOS',
      theme: buildLifeOsTheme(),
      routerConfig: router,
    );
  }
}
