import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The production routes (3c-3 section 2, cutover spec 4g): one `/work`
/// route that builds the Work shell through [work]. The shell owns its
/// places and history; a `/work` link with a query is the place it opens
/// instead of the remembered one. Every other path, the old shell's
/// `/today`, `/journal` and area pages among them, opens bare `/work`.
GoRouter createAppRouter({
  required Widget Function(Uri? link) work,
  String initialLocation = '/work',
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/work',
      builder: (_, state) => work(state.uri.query.isEmpty ? null : state.uri),
    ),
  ],
  redirect: (_, state) => state.uri.path == '/work' ? null : '/work',
);
