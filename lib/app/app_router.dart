import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/work/presentation/work_route_state.dart';

GoRouter createAppRouter({String initialLocation = '/work'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            _NativeFrame(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/today',
            builder: (_, _) => const _UnavailableSurface(
              title: 'Today',
              message: 'Today is not available in this release.',
            ),
          ),
          GoRoute(
            path: '/work',
            builder: (_, state) => _workSurface(state.uri),
          ),
          GoRoute(
            path: '/money',
            builder: (_, _) => const _UnavailableSurface(
              title: 'Money',
              message: 'Money is not available in this release.',
            ),
          ),
          GoRoute(
            path: '/habits',
            builder: (_, _) => const _UnavailableSurface(
              title: 'Habits',
              message: 'Habits are not available in this release.',
            ),
          ),
          GoRoute(
            path: '/system/files',
            builder: (_, _) => const _UnavailableSurface(
              title: 'Backup and export',
              message: 'File tools are not available yet.',
            ),
          ),
        ],
      ),
    ],
    redirect: (_, state) => state.uri.path == '/' ? '/work' : null,
  );
}

Widget _workSurface(Uri uri) {
  final route = parseWorkRoute(uri);
  if (route is InvalidWorkRoute) {
    return _UnavailableSurface(
      title: switch (route.reason) {
        WorkRouteProblem.malformedId => 'Work record unavailable',
        WorkRouteProblem.malformedScope => 'Invalid Work scope',
        WorkRouteProblem.invalidMode => 'Invalid Work mode',
      },
      message: switch (route.reason) {
        WorkRouteProblem.malformedId =>
          'The requested Work record identifier is invalid.',
        WorkRouteProblem.malformedScope =>
          'Choose a valid period or date range to inspect Work records.',
        WorkRouteProblem.invalidMode =>
          'Choose a valid inspector mode to continue.',
      },
    );
  }
  return const _WorkSkeleton();
}

final class _NativeFrame extends StatelessWidget {
  const _NativeFrame({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 184,
            child: ColoredBox(
              color: const Color(0xff20262d),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
                      child: Text(
                        'LifeOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _RailDestination('Today', '/today', location),
                    _RailDestination('Work', '/work', location),
                    _RailDestination('Money', '/money', location),
                    _RailDestination('Habits', '/habits', location),
                    const Spacer(),
                    _RailDestination(
                      'Backup and export',
                      '/system/files',
                      location,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

final class _RailDestination extends StatelessWidget {
  const _RailDestination(this.label, this.path, this.location);

  final String label;
  final String path;
  final String location;

  @override
  Widget build(BuildContext context) {
    final selected = location == path;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => context.go(path),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? const Color(0xff79a7d3) : Colors.transparent,
                width: 3,
              ),
            ),
            color: selected ? const Color(0xff2c3843) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xffc8ced3),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

final class _WorkSkeleton extends StatelessWidget {
  const _WorkSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Work', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text('Work records will appear here.'),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Create an employment and pay agreement to begin.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        const SizedBox(
          width: 356,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text('Select a record to inspect it.'),
            ),
          ),
        ),
      ],
    );
  }
}

final class _UnavailableSurface extends StatelessWidget {
  const _UnavailableSurface({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(message),
        ],
      ),
    );
  }
}
